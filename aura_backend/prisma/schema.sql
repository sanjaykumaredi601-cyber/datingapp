-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Enums
DO $$ BEGIN
    CREATE TYPE auth_provider_enum AS ENUM ('phone', 'google', 'apple');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE gender_enum AS ENUM ('man', 'woman', 'non_binary', 'trans_man', 'trans_woman', 'other');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE subscription_tier_enum AS ENUM ('free', 'explorer', 'vip');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE message_content_type_enum AS ENUM ('text', 'image', 'gif', 'sticker');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE echo_status_enum AS ENUM ('pending', 'liked', 'passed', 'matched');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE report_reason_enum AS ENUM ('fake_profile', 'inappropriate_content', 'harassment', 'spam', 'other');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE report_status_enum AS ENUM ('open', 'under_review', 'resolved', 'dismissed');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE payment_provider_enum AS ENUM ('razorpay', 'apple_iap', 'google_play');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 1. users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone VARCHAR(20) UNIQUE,
    email VARCHAR(255) UNIQUE,
    auth_provider auth_provider_enum NOT NULL DEFAULT 'phone',
    is_phone_verified BOOLEAN DEFAULT FALSE,
    is_email_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    consent_version VARCHAR(20) NOT NULL DEFAULT 'v1.0',
    consent_given_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_active_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. profiles table
CREATE TABLE IF NOT EXISTS profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    display_name VARCHAR(50) NOT NULL,
    bio TEXT,
    birth_date DATE,
    gender gender_enum DEFAULT 'other',
    seeking_genders gender_enum[] DEFAULT '{}',
    city VARCHAR(100),
    country VARCHAR(2) DEFAULT 'IN',
    photos JSONB DEFAULT '[]'::JSONB,
    interest_tags TEXT[] DEFAULT '{}',
    looking_for VARCHAR(20) DEFAULT 'open',
    selfie_verified BOOLEAN DEFAULT FALSE,
    verification_score NUMERIC(4,3) DEFAULT 0.0,
    min_age_preference INT DEFAULT 18,
    max_age_preference INT DEFAULT 45,
    discovery_radius_km INT DEFAULT 25,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. user_locations table with PostGIS
CREATE TABLE IF NOT EXISTS user_locations (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    raw_location GEOGRAPHY(Point, 4326) NOT NULL,
    grid_location GEOGRAPHY(Point, 4326) NOT NULL,
    accuracy_meters NUMERIC(8,2),
    recorded_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '48 hours'
);

-- 4. location_zones table
CREATE TABLE IF NOT EXISTS location_zones (
    zone_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center GEOGRAPHY(Point, 4326) NOT NULL,
    radius_meters INT NOT NULL DEFAULT 500,
    activity_count INT DEFAULT 0,
    last_updated_at TIMESTAMPTZ DEFAULT NOW(),
    zone_name VARCHAR(100),
    city VARCHAR(100),
    country VARCHAR(2) DEFAULT 'IN'
);

-- 5. echoes table
CREATE TABLE IF NOT EXISTS echoes (
    echo_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_a UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_b UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    crossed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    zone_id UUID REFERENCES location_zones(zone_id),
    proximity_meters NUMERIC(8,2),
    status echo_status_enum DEFAULT 'pending',
    user_a_action_at TIMESTAMPTZ,
    user_b_action_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '7 days',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. matches table
CREATE TABLE IF NOT EXISTS matches (
    match_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_a UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_b UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    matched_at TIMESTAMPTZ DEFAULT NOW(),
    echo_id UUID REFERENCES echoes(echo_id),
    is_active BOOLEAN DEFAULT TRUE
);

-- 7. messages table
CREATE TABLE IF NOT EXISTS messages (
    message_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id UUID NOT NULL REFERENCES matches(match_id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content_type message_content_type_enum NOT NULL DEFAULT 'text',
    content_encrypted TEXT,
    media_url TEXT,
    is_flagged BOOLEAN DEFAULT FALSE,
    flag_reason TEXT,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    is_deleted_by_sender BOOLEAN DEFAULT FALSE,
    is_deleted_by_receiver BOOLEAN DEFAULT FALSE
);

-- 8. subscriptions table
CREATE TABLE IF NOT EXISTS subscriptions (
    sub_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tier subscription_tier_enum NOT NULL DEFAULT 'free',
    started_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    payment_provider payment_provider_enum,
    payment_reference VARCHAR(255),
    amount_paid NUMERIC(10,2),
    currency VARCHAR(3) DEFAULT 'INR',
    auto_renew BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 9. Spatial function: obfuscate_to_grid
CREATE OR REPLACE FUNCTION obfuscate_to_grid(
    point GEOGRAPHY,
    grid_meters FLOAT DEFAULT 500.0
) RETURNS GEOGRAPHY AS $$
DECLARE
    lng FLOAT;
    lat FLOAT;
    grid_lng FLOAT;
    grid_lat FLOAT;
BEGIN
    lng := ST_X(point::GEOMETRY);
    lat := ST_Y(point::GEOMETRY);
    grid_lat := grid_meters / 111320.0;
    grid_lng := grid_meters / (111320.0 * COS(RADIANS(lat)));
    lng := ROUND(lng / grid_lng) * grid_lng;
    lat := ROUND(lat / grid_lat) * grid_lat;
    RETURN ST_SetSRID(ST_MakePoint(lng, lat), 4326)::GEOGRAPHY;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 10. Spatial query: get_radar_heatmap
CREATE OR REPLACE FUNCTION get_radar_heatmap(
    center_lat FLOAT,
    center_lng FLOAT,
    radius_km FLOAT DEFAULT 25.0,
    time_window_hours INT DEFAULT 3
) RETURNS TABLE (
    zone_lat FLOAT,
    zone_lng FLOAT,
    density_level INT,
    activity_count INT
) AS $$
DECLARE
    center_point GEOGRAPHY;
BEGIN
    center_point := ST_SetSRID(ST_MakePoint(center_lng, center_lat), 4326)::GEOGRAPHY;
    RETURN QUERY
    SELECT
        ST_Y(grid_location::GEOMETRY) AS zone_lat,
        ST_X(grid_location::GEOMETRY) AS zone_lng,
        CASE
            WHEN COUNT(DISTINCT user_id) >= 10 THEN 3
            WHEN COUNT(DISTINCT user_id) >= 4 THEN 2
            ELSE 1
        END AS density_level,
        COUNT(DISTINCT user_id)::INT AS activity_count
    FROM user_locations
    WHERE is_active = TRUE
        AND recorded_at >= NOW() - (time_window_hours || ' hours')::INTERVAL
        AND ST_DWithin(grid_location, center_point, radius_km * 1000)
    GROUP BY ST_Y(grid_location::GEOMETRY), ST_X(grid_location::GEOMETRY)
    HAVING COUNT(DISTINCT user_id) >= 1;
END;
$$ LANGUAGE plpgsql;
