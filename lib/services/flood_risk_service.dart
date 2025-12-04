import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../models/flood_risk_result.dart';
import '../utils/coordinate_utils.dart';
import 'tflite_inference_service.dart';
import 'spatial_index_service.dart';

/// Main service for flood risk calculation and feature extraction
/// Combines raster sampling, spatial queries, and ML inference
class FloodRiskService {
  final TFLiteInferenceService _inferenceService;
  final SpatialIndexService _spatialService;

  // Cache for risk predictions (to avoid redundant calculations)
  final Map<String, FloodRiskResult> _riskCache = {};

  // Cache expiry time (5 minutes)
  static const Duration _cacheExpiry = Duration(minutes: 5);

  FloodRiskService({
    required TFLiteInferenceService inferenceService,
    required SpatialIndexService spatialService,
  })  : _inferenceService = inferenceService,
        _spatialService = spatialService;

  /// Initialize the service
  Future<void> initialize() async {
    print('Initializing FloodRiskService...');
    
    await _inferenceService.initialize();
    await _spatialService.initialize();
    
    print('FloodRiskService initialized successfully');
  }

  /// Extract all 6 features for a given coordinate
  /// Returns features in order: [elevation, slope, flow_accumulation, dist_to_road, population, dist_to_landslide]
  Future<List<double>> extractFeatures(LatLng coordinate) async {
    try {
      // Extract all features in parallel for better performance
      final results = await Future.wait([
        getElevation(coordinate),
        getSlope(coordinate),
        getFlowAccumulation(coordinate),
        getDistanceToRoad(coordinate),
        getPopulation(coordinate),
        getDistanceToLandslide(coordinate),
      ]);

      return results;
    } catch (e) {
      print('Error extracting features for $coordinate: $e');
      rethrow;
    }
  }

  /// Get elevation at coordinate (from NASADEM raster)
  Future<double> getElevation(LatLng coordinate) async {
    try {
      // Sample from elevation raster
      final elevation = await _spatialService.sampleRaster(
        coordinate: coordinate,
        rasterType: RasterType.elevation,
      );

      return elevation ?? 0.0; // Return 0 if out of bounds
    } catch (e) {
      print('Error getting elevation: $e');
      return 0.0;
    }
  }

  /// Get slope at coordinate (from slope raster)
  Future<double> getSlope(LatLng coordinate) async {
    try {
      final slope = await _spatialService.sampleRaster(
        coordinate: coordinate,
        rasterType: RasterType.slope,
      );

      return slope ?? 0.0;
    } catch (e) {
      print('Error getting slope: $e');
      return 0.0;
    }
  }

  /// Get flow accumulation at coordinate (from HydroSHEDS)
  Future<double> getFlowAccumulation(LatLng coordinate) async {
    try {
      final flowAcc = await _spatialService.sampleRaster(
        coordinate: coordinate,
        rasterType: RasterType.flowAccumulation,
      );

      return flowAcc ?? 0.0;
    } catch (e) {
      print('Error getting flow accumulation: $e');
      return 0.0;
    }
  }

  /// Calculate distance to nearest road (from OSM data)
  Future<double> getDistanceToRoad(LatLng coordinate) async {
    try {
      final nearestRoad = await _spatialService.findNearestRoad(coordinate);
      
      if (nearestRoad == null) {
        return 10000.0; // Default to 10km if no road found
      }

      return nearestRoad.distance;
    } catch (e) {
      print('Error getting distance to road: $e');
      return 10000.0;
    }
  }

  /// Get population density at coordinate (from WorldPop)
  Future<double> getPopulation(LatLng coordinate) async {
    try {
      final population = await _spatialService.sampleRaster(
        coordinate: coordinate,
        rasterType: RasterType.population,
      );

      return population ?? 0.0;
    } catch (e) {
      print('Error getting population: $e');
      return 0.0;
    }
  }

  /// Calculate distance to nearest landslide point (from NASA data)
  Future<double> getDistanceToLandslide(LatLng coordinate) async {
    try {
      final nearestLandslide = await _spatialService.findNearestLandslide(coordinate);
      
      if (nearestLandslide == null) {
        return 100000.0; // Default to 100km if no landslide found
      }

      return nearestLandslide.distance;
    } catch (e) {
      print('Error getting distance to landslide: $e');
      return 100000.0;
    }
  }

  /// Get flood risk prediction for a single location
  Future<FloodRiskResult> getFloodRisk(LatLng coordinate) async {
    // Check cache first
    final cacheKey = _getCacheKey(coordinate);
    final cached = _riskCache[cacheKey];
    
    if (cached != null && 
        DateTime.now().difference(cached.timestamp) < _cacheExpiry) {
      return cached;
    }

    try {
      // Extract features
      final features = await extractFeatures(coordinate);

      // Validate features
      if (!_inferenceService.validateFeatures(features)) {
        throw Exception('Invalid features extracted for $coordinate');
      }

      // Run predictions
      final predictions = await _inferenceService.predictBoth(features);

      // Create result
      final result = FloodRiskResult.fromPrediction(
        coordinate: coordinate,
        floodProbability: predictions['probability']!,
        floodDepth: predictions['depth']!,
        features: {
          'elevation': features[0],
          'slope': features[1],
          'flow_accumulation': features[2],
          'dist_to_road': features[3],
          'population': features[4],
          'dist_to_landslide': features[5],
        },
      );

      // Cache the result
      _riskCache[cacheKey] = result;

      return result;
    } catch (e) {
      print('Error getting flood risk for $coordinate: $e');
      rethrow;
    }
  }

  /// Get flood risk for multiple locations (batch processing)
  Future<List<FloodRiskResult>> getFloodRiskBatch(List<LatLng> coordinates) async {
    final results = <FloodRiskResult>[];

    // Process in chunks to avoid overwhelming the system
    const chunkSize = 10;
    
    for (int i = 0; i < coordinates.length; i += chunkSize) {
      final end = (i + chunkSize < coordinates.length) 
          ? i + chunkSize 
          : coordinates.length;
      
      final chunk = coordinates.sublist(i, end);
      
      // Process chunk in parallel
      final chunkResults = await Future.wait(
        chunk.map((coord) => getFloodRisk(coord)),
      );
      
      results.addAll(chunkResults);
    }

    return results;
  }

  /// Adjust risk based on live rainfall data
  /// rainMultiplier is from PAGASA API: 1.0 (no rain) to 3.0 (heavy rain)
  double applyRainMultiplier(double baseRisk, double rainMultiplier) {
    // Clamp rain multiplier to reasonable range
    final multiplier = rainMultiplier.clamp(1.0, 3.0);
    
    // Apply non-linear scaling (risk increases faster with rain)
    final adjustedRisk = baseRisk * multiplier;
    
    return adjustedRisk.clamp(0.0, 1.0);
  }

  /// Find nearest safe location if destination is flooded
  /// Searches in expanding circles until safe location found
  Future<LatLng?> findSafeEdge({
    required LatLng destination,
    double maxRiskThreshold = 0.3,
    double maxSearchRadius = 5000.0, // 5km
    int numDirections = 8,
  }) async {
    // Define search radii (meters)
    final searchRadii = [100.0, 250.0, 500.0, 1000.0, 2000.0, 5000.0];

    for (final radius in searchRadii) {
      if (radius > maxSearchRadius) break;

      // Search in multiple directions
      for (int i = 0; i < numDirections; i++) {
        final bearing = (360.0 / numDirections) * i;
        
        final candidatePoint = CoordinateUtils.pointAtDistanceAndBearing(
          destination,
          radius,
          bearing,
        );

        // Check risk at this point
        final risk = await getFloodRisk(candidatePoint);
        
        if (risk.floodProbability <= maxRiskThreshold) {
          print('Found safe edge at ${radius}m from destination (bearing: $bearing°)');
          return candidatePoint;
        }
      }
    }

    print('No safe edge found within ${maxSearchRadius}m of destination');
    return null;
  }

  /// Calculate aggregate risk along a route path
  /// Returns statistics about the route
  Future<Map<String, double>> calculateRouteRiskStats(
    List<LatLng> routePath,
  ) async {
    if (routePath.isEmpty) {
      return {'max': 0.0, 'average': 0.0, 'total': 0.0};
    }

    // Get risk for each point
    final risks = await getFloodRiskBatch(routePath);

    // Calculate statistics
    final probabilities = risks.map((r) => r.floodProbability).toList();
    
    final maxRisk = probabilities.reduce(max);
    final averageRisk = probabilities.reduce((a, b) => a + b) / probabilities.length;
    final totalRisk = probabilities.reduce((a, b) => a + b);

    // Count high-risk segments
    final highRiskCount = risks.where((r) => r.shouldAvoid).length;
    final highRiskPercentage = (highRiskCount / risks.length) * 100;

    return {
      'max': maxRisk,
      'average': averageRisk,
      'total': totalRisk,
      'high_risk_count': highRiskCount.toDouble(),
      'high_risk_percentage': highRiskPercentage,
    };
  }

  /// Generate a cache key for a coordinate (rounded to ~100m precision)
  String _getCacheKey(LatLng coordinate) {
    // Round to 3 decimal places (~111m precision)
    final lat = (coordinate.latitude * 1000).round() / 1000;
    final lon = (coordinate.longitude * 1000).round() / 1000;
    return '$lat,$lon';
  }

  /// Clear the risk cache
  void clearCache() {
    _riskCache.clear();
    print('Risk cache cleared');
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    return {
      'size': _riskCache.length,
      'max_size': 1000, // Limit cache to 1000 entries
    };
  }

  /// Prune old entries from cache
  void pruneCache() {
    final now = DateTime.now();
    _riskCache.removeWhere((key, value) {
      return now.difference(value.timestamp) > _cacheExpiry;
    });
    
    // Also limit total cache size
    if (_riskCache.length > 1000) {
      final entries = _riskCache.entries.toList();
      entries.sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
      
      // Remove oldest 20%
      final removeCount = (_riskCache.length * 0.2).round();
      for (int i = 0; i < removeCount; i++) {
        _riskCache.remove(entries[i].key);
      }
    }
    
    print('Cache pruned: ${_riskCache.length} entries remaining');
  }

  /// Dispose resources
  void dispose() {
    _inferenceService.dispose();
    _spatialService.dispose();
    _riskCache.clear();
  }
}
