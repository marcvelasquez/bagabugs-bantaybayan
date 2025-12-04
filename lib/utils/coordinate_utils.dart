import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Utility functions for coordinate transformations and calculations
class CoordinateUtils {
  /// Earth's radius in meters
  static const double earthRadius = 6371000.0;

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in meters
  static double calculateDistance(LatLng point1, LatLng point2) {
    final lat1 = _toRadians(point1.latitude);
    final lat2 = _toRadians(point2.latitude);
    final dLat = _toRadians(point2.latitude - point1.latitude);
    final dLon = _toRadians(point2.longitude - point1.longitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  /// Convert radians to degrees
  static double _toDegrees(double radians) {
    return radians * 180.0 / pi;
  }

  /// Calculate bearing between two points (in degrees)
  static double calculateBearing(LatLng start, LatLng end) {
    final lat1 = _toRadians(start.latitude);
    final lat2 = _toRadians(end.latitude);
    final dLon = _toRadians(end.longitude - start.longitude);

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final bearing = atan2(y, x);

    return (_toDegrees(bearing) + 360) % 360;
  }

  /// Get point at given distance and bearing from start point
  static LatLng pointAtDistanceAndBearing(
    LatLng start,
    double distance,
    double bearing,
  ) {
    final lat1 = _toRadians(start.latitude);
    final lon1 = _toRadians(start.longitude);
    final bearingRad = _toRadians(bearing);
    final angularDistance = distance / earthRadius;

    final lat2 = asin(
      sin(lat1) * cos(angularDistance) +
          cos(lat1) * sin(angularDistance) * cos(bearingRad),
    );

    final lon2 = lon1 +
        atan2(
          sin(bearingRad) * sin(angularDistance) * cos(lat1),
          cos(angularDistance) - sin(lat1) * sin(lat2),
        );

    return LatLng(_toDegrees(lat2), _toDegrees(lon2));
  }

  /// Convert WGS84 lat/lon to UTM coordinates
  /// Returns {easting, northing, zone, hemisphere}
  static Map<String, dynamic> latLonToUTM(LatLng coordinate) {
    final lat = coordinate.latitude;
    final lon = coordinate.longitude;

    // Calculate UTM zone
    final zone = ((lon + 180) / 6).floor() + 1;

    // Calculate central meridian
    final lonOrigin = (zone - 1) * 6 - 180 + 3;

    // Convert to radians
    final latRad = _toRadians(lat);
    final lonRad = _toRadians(lon);
    final lonOriginRad = _toRadians(lonOrigin.toDouble());

    // WGS84 ellipsoid parameters
    const a = 6378137.0; // Semi-major axis
    const e = 0.081819190842622; // Eccentricity
    const k0 = 0.9996; // Scale factor

    final N = a / sqrt(1 - pow(e * sin(latRad), 2));
    final T = pow(tan(latRad), 2);
    final C = (pow(e, 2) / (1 - pow(e, 2))) * pow(cos(latRad), 2);
    final A = (lonRad - lonOriginRad) * cos(latRad);

    final M = a *
        ((1 - pow(e, 2) / 4 - 3 * pow(e, 4) / 64 - 5 * pow(e, 6) / 256) *
                latRad -
            (3 * pow(e, 2) / 8 + 3 * pow(e, 4) / 32 + 45 * pow(e, 6) / 1024) *
                sin(2 * latRad) +
            (15 * pow(e, 4) / 256 + 45 * pow(e, 6) / 1024) * sin(4 * latRad) -
            (35 * pow(e, 6) / 3072) * sin(6 * latRad));

    final easting = k0 *
            N *
            (A +
                (1 - T + C) * pow(A, 3) / 6 +
                (5 - 18 * T + pow(T, 2) + 72 * C - 58 * (pow(e, 2) / (1 - pow(e, 2)))) *
                    pow(A, 5) /
                    120) +
        500000.0;

    final northing = k0 *
        (M +
            N *
                tan(latRad) *
                (pow(A, 2) / 2 +
                    (5 - T + 9 * C + 4 * pow(C, 2)) * pow(A, 4) / 24 +
                    (61 - 58 * T + pow(T, 2) + 600 * C - 330 * (pow(e, 2) / (1 - pow(e, 2)))) *
                        pow(A, 6) /
                        720));

    final finalNorthing = lat < 0 ? northing + 10000000.0 : northing;
    final hemisphere = lat >= 0 ? 'N' : 'S';

    return {
      'easting': easting,
      'northing': finalNorthing,
      'zone': zone,
      'hemisphere': hemisphere,
    };
  }

  /// Convert geographic coordinates to raster pixel coordinates
  /// Used for sampling GeoTIFF rasters
  static Map<String, int> geoToPixel({
    required LatLng coordinate,
    required double geoTransform0, // Top-left X
    required double geoTransform1, // Pixel width (W-E)
    required double geoTransform2, // Rotation (usually 0)
    required double geoTransform3, // Top-left Y
    required double geoTransform4, // Rotation (usually 0)
    required double geoTransform5, // Pixel height (N-S, usually negative)
  }) {
    final lon = coordinate.longitude;
    final lat = coordinate.latitude;

    // Affine transformation: (lon, lat) → (pixel_x, pixel_y)
    final det = geoTransform1 * geoTransform5 - geoTransform2 * geoTransform4;

    final pixelX = ((geoTransform5 * (lon - geoTransform0) -
                geoTransform2 * (lat - geoTransform3)) /
            det)
        .round();

    final pixelY = ((-geoTransform4 * (lon - geoTransform0) +
                geoTransform1 * (lat - geoTransform3)) /
            det)
        .round();

    return {'x': pixelX, 'y': pixelY};
  }

  /// Create a bounding box around a point with given radius (in meters)
  /// Note: LatLngBounds not available in latlong2, use flutter_map's LatLngBounds if needed
  /*
  static LatLngBounds createBoundingBox(LatLng center, double radiusMeters) {
    // Calculate approximate degrees offset
    final latOffset = radiusMeters / 111320; // ~111.32 km per degree latitude
    final lonOffset = radiusMeters / (111320 * cos(_toRadians(center.latitude)));

    final southwest = LatLng(
      center.latitude - latOffset,
      center.longitude - lonOffset,
    );

    final northeast = LatLng(
      center.latitude + latOffset,
      center.longitude + lonOffset,
    );

    return LatLngBounds(southwest: southwest, northeast: northeast);
  }
  */

  /// Interpolate between two coordinates
  static LatLng interpolate(LatLng start, LatLng end, double fraction) {
    final lat = start.latitude + (end.latitude - start.latitude) * fraction;
    final lon = start.longitude + (end.longitude - start.longitude) * fraction;
    return LatLng(lat, lon);
  }

  /// Simplify a path using Douglas-Peucker algorithm
  /// Reduces number of points while preserving shape
  static List<LatLng> simplifyPath(List<LatLng> points, double tolerance) {
    if (points.length < 3) return points;

    // Find point with maximum distance from line between first and last
    double maxDistance = 0;
    int maxIndex = 0;

    final start = points.first;
    final end = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final distance = _perpendicularDistance(points[i], start, end);
      if (distance > maxDistance) {
        maxDistance = distance;
        maxIndex = i;
      }
    }

    // If max distance is greater than tolerance, recursively simplify
    if (maxDistance > tolerance) {
      final leftSegment = simplifyPath(points.sublist(0, maxIndex + 1), tolerance);
      final rightSegment = simplifyPath(points.sublist(maxIndex), tolerance);

      return [...leftSegment.sublist(0, leftSegment.length - 1), ...rightSegment];
    } else {
      return [start, end];
    }
  }

  /// Calculate perpendicular distance from point to line segment
  static double _perpendicularDistance(LatLng point, LatLng lineStart, LatLng lineEnd) {
    final area = ((lineEnd.longitude - lineStart.longitude) *
                (point.latitude - lineStart.latitude) -
            (lineEnd.latitude - lineStart.latitude) *
                (point.longitude - lineStart.longitude))
        .abs();

    final bottom = calculateDistance(lineStart, lineEnd);

    return area / bottom;
  }

  /// Check if a point is within a polygon
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersections = 0;
    for (int i = 0; i < polygon.length; i++) {
      final vertex1 = polygon[i];
      final vertex2 = polygon[(i + 1) % polygon.length];

      if (_rayIntersectsSegment(point, vertex1, vertex2)) {
        intersections++;
      }
    }

    return intersections % 2 == 1;
  }

  /// Check if a ray from point intersects line segment
  static bool _rayIntersectsSegment(LatLng point, LatLng vertex1, LatLng vertex2) {
    if (vertex1.latitude > vertex2.latitude) {
      final temp = vertex1;
      vertex1 = vertex2;
      vertex2 = temp;
    }

    if (point.latitude == vertex1.latitude || point.latitude == vertex2.latitude) {
      point = LatLng(point.latitude + 0.00000001, point.longitude);
    }

    if (point.latitude < vertex1.latitude || point.latitude > vertex2.latitude) {
      return false;
    }

    if (point.longitude >= max(vertex1.longitude, vertex2.longitude)) {
      return false;
    }

    if (point.longitude < min(vertex1.longitude, vertex2.longitude)) {
      return true;
    }

    final red = (point.latitude - vertex1.latitude) /
        (point.longitude - vertex1.longitude);
    final blue = (vertex2.latitude - vertex1.latitude) /
        (vertex2.longitude - vertex1.longitude);

    return red >= blue;
  }
}
