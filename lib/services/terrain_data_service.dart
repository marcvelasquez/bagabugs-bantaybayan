import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Service to provide terrain data for ML predictions
/// Uses interpolated values from known elevation points in Pampanga
class TerrainDataService {
  // Known elevation reference points in Pampanga
  static const List<_ElevationPoint> _referencePoints = [
    // Mount Arayat region (high elevation)
    _ElevationPoint(15.2000, 120.7500, 1026), // Peak
    _ElevationPoint(15.2100, 120.7400, 800),
    _ElevationPoint(15.1900, 120.7600, 700),
    
    // Central plains (low elevation)
    _ElevationPoint(15.0500, 120.6500, 15),
    _ElevationPoint(15.0000, 120.7000, 12),
    _ElevationPoint(14.9500, 120.6500, 8),
    
    // Candaba Swamp area (very low)
    _ElevationPoint(15.0833, 120.8333, 5),
    _ElevationPoint(15.1000, 120.8500, 4),
    
    // Angeles-San Fernando area
    _ElevationPoint(15.1450, 120.5887, 150), // Angeles
    _ElevationPoint(15.0285, 120.6897, 50),  // San Fernando
    
    // Eastern foothills
    _ElevationPoint(15.2500, 120.8000, 300),
    _ElevationPoint(15.2000, 120.8500, 200),
  ];

  /// Get terrain data for a specific location
  static TerrainData getTerrainData(LatLng location) {
    final elevation = _interpolateElevation(location.latitude, location.longitude);
    final slope = _calculateSlope(location.latitude, location.longitude);
    final flowAccumulation = _estimateFlowAccumulation(
      location.latitude,
      location.longitude,
      elevation,
      slope,
    );
    final population = _estimatePopulation(location.latitude, location.longitude);

    return TerrainData(
      elevation: elevation,
      slope: slope,
      flowAccumulation: flowAccumulation,
      population: population,
    );
  }

  /// Calculate distance between two points in meters
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in meters
    
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lon2 - lon1) * pi / 180;
    
    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return R * c;
  }

  /// Interpolate elevation using inverse distance weighting
  static double _interpolateElevation(double lat, double lon, {double power = 2.0}) {
    double totalWeight = 0.0;
    double weightedSum = 0.0;

    for (final point in _referencePoints) {
      final dist = _haversineDistance(lat, lon, point.lat, point.lon);
      
      if (dist < 1) {
        // Very close to reference point
        return point.elevation;
      }
      
      final weight = 1 / pow(dist, power);
      totalWeight += weight;
      weightedSum += weight * point.elevation;
    }

    if (totalWeight == 0) return 50.0; // Default elevation
    return weightedSum / totalWeight;
  }

  /// Calculate slope based on nearby elevation changes
  static double _calculateSlope(double lat, double lon) {
    const sampleDistance = 0.01; // ~1km
    
    // Get elevations at cardinal directions
    final eNorth = _interpolateElevation(lat + sampleDistance, lon);
    final eSouth = _interpolateElevation(lat - sampleDistance, lon);
    final eEast = _interpolateElevation(lat, lon + sampleDistance);
    final eWest = _interpolateElevation(lat, lon - sampleDistance);
    
    // Calculate gradients
    final dx = (eEast - eWest) / (2 * sampleDistance * 111000); // degrees to meters
    final dy = (eNorth - eSouth) / (2 * sampleDistance * 111000);
    
    // Slope in degrees
    final slopeRadians = atan(sqrt(dx * dx + dy * dy));
    return slopeRadians * 180 / pi;
  }

  /// Estimate flow accumulation based on elevation and slope
  static double _estimateFlowAccumulation(double lat, double lon, double elevation, double slope) {
    const baseFlow = 1000.0;
    
    // Lower elevation = more accumulation
    final elevationFactor = max(0.0, (200 - elevation) / 200) * 5000;
    
    // Lower slope = more accumulation
    final slopeFactor = max(0.0, (10 - slope) / 10) * 3000;
    
    // Candaba swamp area (known wetland)
    if (lat >= 15.05 && lat <= 15.15 && lon >= 120.80 && lon <= 120.90) {
      return baseFlow + elevationFactor + slopeFactor + 10000;
    }
    
    return baseFlow + elevationFactor + slopeFactor;
  }

  /// Estimate population density based on urban centers
  static double _estimatePopulation(double lat, double lon) {
    // Urban centers with population density
    const urbanCenters = [
      _PopulationCenter(15.1450, 120.5887, 5000.0), // Angeles City
      _PopulationCenter(15.0285, 120.6897, 4000.0), // San Fernando
      _PopulationCenter(15.2267, 120.5714, 3000.0), // Mabalacat
    ];
    
    double minDist = double.infinity;
    double maxPop = 0.0;
    
    for (final center in urbanCenters) {
      final dist = _haversineDistance(lat, lon, center.lat, center.lon);
      if (dist < minDist) {
        minDist = dist;
        maxPop = center.population;
      }
    }
    
    // Population decreases with distance
    if (minDist < 1000) {
      return maxPop;
    } else if (minDist < 5000) {
      return maxPop * (1 - (minDist - 1000) / 4000) * 0.8;
    } else if (minDist < 15000) {
      return maxPop * 0.2 * (1 - (minDist - 5000) / 10000);
    } else {
      return 100.0; // Rural baseline
    }
  }
}

/// Terrain data for a specific location
class TerrainData {
  final double elevation;
  final double slope;
  final double flowAccumulation;
  final double population;

  const TerrainData({
    required this.elevation,
    required this.slope,
    required this.flowAccumulation,
    required this.population,
  });

  @override
  String toString() {
    return 'TerrainData(elevation: ${elevation.toStringAsFixed(1)}m, '
        'slope: ${slope.toStringAsFixed(1)}°, '
        'flow: ${flowAccumulation.toStringAsFixed(0)}, '
        'pop: ${population.toStringAsFixed(0)})';
  }
}

class _ElevationPoint {
  final double lat;
  final double lon;
  final double elevation;

  const _ElevationPoint(this.lat, this.lon, this.elevation);
}

class _PopulationCenter {
  final double lat;
  final double lon;
  final double population;

  const _PopulationCenter(this.lat, this.lon, this.population);
}
