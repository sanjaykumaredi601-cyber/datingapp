import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const { Pool } = pg;

export const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  user: process.env.DB_USER || 'aura_user',
  password: process.env.DB_PASSWORD || 'aura_secret',
  database: process.env.DB_NAME || 'aura_db',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 3000,
});

let isDbConnected = false;

export async function checkDatabaseConnection(): Promise<boolean> {
  try {
    const client = await pool.connect();
    const result = await client.query('SELECT NOW()');
    client.release();
    isDbConnected = true;
    console.log('✅ PostgreSQL + PostGIS connected at:', result.rows[0].now);
    return true;
  } catch (err: any) {
    isDbConnected = false;
    console.warn('⚠️ PostgreSQL not reachable (' + err.message + '). Running in in-memory / mock development mode.');
    console.warn('💡 Tip: Run `docker compose up -d` to launch PostgreSQL + PostGIS + Redis.');
    return false;
  }
}

export function isDatabaseLive(): boolean {
  return isDbConnected;
}
