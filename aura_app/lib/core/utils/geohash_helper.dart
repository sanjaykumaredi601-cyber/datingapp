import 'dart:math' as math;

/// Production-ready Geohash utility for spatial indexing, bounding box query generation,
/// and accurate Haversine distance calculations for Cloud Firestore proximity radar queries.
class GeoHashHelper {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encodes latitude and longitude into a geohash string
  static String encode(double latitude, double longitude, {int precision = 9}) {
    if (latitude < -90.0 || latitude > 90.0) {
      throw ArgumentError('Latitude must be between -90 and 90');
    }
    if (longitude < -180.0 || longitude > 180.0) {
      throw ArgumentError('Longitude must be between -180 and 180');
    }

    double minLat = -90.0, maxLat = 90.0;
    double minLon = -180.0, maxLon = 180.0;

    final buffer = StringBuffer();
    bool isEven = true;
    int bit = 0;
    int ch = 0;

    while (buffer.length < precision) {
      if (isEven) {
        final mid = (minLon + maxLon) / 2;
        if (longitude >= mid) {
          ch |= (1 << (4 - bit));
          minLon = mid;
        } else {
          maxLon = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (latitude >= mid) {
          ch |= (1 << (4 - bit));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }

  /// Calculates Earth surface distance between two coordinates using the Haversine formula (km)
  static double haversineDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  /// Calculates query range bounds `[startGeohash, endGeohash]` for a given center & radius.
  /// Suitable for Firestore range queries:
  /// `.where('geohash', isGreaterThanOrEqualTo: start).where('geohash', isLessThanOrEqualTo: end)`
  static List<List<String>> geohashQueryBounds(
    double latitude,
    double longitude,
    double radiusKm,
  ) {
    // Determine required geohash length based on radius
    int precision = 9;
    if (radiusKm > 2500) {
      precision = 1;
    } else if (radiusKm > 630) {
      precision = 2;
    } else if (radiusKm > 78) {
      precision = 3;
    } else if (radiusKm > 20) {
      precision = 4;
    } else if (radiusKm > 2.4) {
      precision = 5;
    } else if (radiusKm > 0.61) {
      precision = 6;
    } else if (radiusKm > 0.076) {
      precision = 7;
    } else {
      precision = 8;
    }

    final centerHash = encode(latitude, longitude, precision: precision);
    final start = centerHash;
    final end = '$centerHash~'; // ~ has ASCII value 126, greater than any base32 char

    return [
      [start, end]
    ];
  }

  /// Obfuscates exact GPS coordinates to a 500m geohash cell (precision 6).
  /// Privacy Guarantee: Never broadcasts raw latitude/longitude to other users or public feeds.
  static String obfuscateTo500mGeohash(double latitude, double longitude) {
    return encode(latitude, longitude, precision: 6);
  }

  /// Calculates the approximate center coordinates of a geohash bounding box
  /// Used for rendering privacy-safe zone markers without revealing exact GPS pinpoints.
  static Map<String, double> decodeCenter(String geohash) {
    double minLat = -90.0, maxLat = 90.0;
    double minLon = -180.0, maxLon = 180.0;
    bool isEven = true;

    for (int i = 0; i < geohash.length; i++) {
      final c = geohash[i];
      final cd = _base32.indexOf(c);
      if (cd == -1) continue;

      for (int mask = 16; mask > 0; mask >>= 1) {
        if (isEven) {
          final mid = (minLon + maxLon) / 2;
          if ((cd & mask) != 0) {
            minLon = mid;
          } else {
            maxLon = mid;
          }
        } else {
          final mid = (minLat + maxLat) / 2;
          if ((cd & mask) != 0) {
            minLat = mid;
          } else {
            maxLat = mid;
          }
        }
        isEven = !isEven;
      }
    }

    return {
      'latitude': (minLat + maxLat) / 2,
      'longitude': (minLon + maxLon) / 2,
    };
  }
}

