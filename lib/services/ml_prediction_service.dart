import 'package:latlong2/latlong.dart';
import 'terrain_data_service.dart';
import 'flood_risk_calculator.dart';

class FloodPrediction {
  final double probability;
  final double depthCm;
  final String riskLevel;
  final String action;

  FloodPrediction({
    required this.probability,
    required this.depthCm,
    required this.riskLevel,
    required this.action,
  });

  String get riskLevelText {
    if (riskLevel == 'EXTREME') return '🔴 EXTREME';
    if (riskLevel == 'VERY HIGH') return '🔴 VERY HIGH';
    if (riskLevel == 'HIGH') return '🟠 HIGH';
    if (riskLevel == 'MODERATE') return '🟡 MODERATE';
    return '🟢 LOW';
  }
}

class MLPredictionService {
  static bool _isInitialized = true; // Always ready with rule-based model

  /// Initialize ML models (no-op for rule-based model)
  static Future<bool> initialize() async {
    _isInitialized = true;
    print('✅ Flood risk calculator initialized (rule-based model)');
    return true;
  }

  /// Dispose of models (no-op for rule-based model)
  static void dispose() {
    // Nothing to dispose
  }

  /// Make flood prediction using rule-based model
  static Future<FloodPrediction?> predictForLocation({
    required LatLng location,
    required String weatherCondition,
    double rain24hMm = 0.0,
  }) async {
    try {
      // Get terrain data for this location
      final terrain = TerrainDataService.getTerrainData(location);
      
      // Calculate flood risk using rule-based model
      final result = FloodRiskCalculator.calculateFloodRisk(
        elevationM: terrain.elevation,
        weatherCondition: weatherCondition,
        rain24hMm: rain24hMm,
      );
      
      // Estimate depth based on risk level and elevation
      double estimatedDepth;
      if (terrain.elevation < 5) {
        estimatedDepth = result['risk'] * 100; // Up to 100cm in very low areas
      } else if (terrain.elevation < 10) {
        estimatedDepth = result['risk'] * 60; // Up to 60cm in low areas
      } else {
        estimatedDepth = result['risk'] * 30; // Up to 30cm in elevated areas
      }
      
      return FloodPrediction(
        probability: result['risk'],
        depthCm: estimatedDepth,
        riskLevel: result['level'],
        action: result['action'],
      );
    } catch (e) {
      print('Error making prediction: $e');
      return null;
    }
  }

  /// Make predictions for storm scenario (backwards compatibility)
  /// Maps rainfall to weather condition
  static Future<FloodPrediction?> predictForStorm({
    required double rainfall,
    double elevation = 100.0,
    double slope = 5.0,
    double flowAccumulation = 1000.0,
    double distanceToWater = 500.0,
    double population = 1000.0,
  }) async {
    // Map rainfall to weather condition
    String weatherCondition;
    if (rainfall >= 125) {
      weatherCondition = 'typhoon';
    } else if (rainfall >= 50) {
      weatherCondition = 'heavy_rain';
    } else if (rainfall >= 20) {
      weatherCondition = 'moderate_rain';
    } else if (rainfall >= 5) {
      weatherCondition = 'light_rain';
    } else {
      weatherCondition = 'cloudy';
    }
    
    // Calculate using rule-based model
    final result = FloodRiskCalculator.calculateFloodRisk(
      elevationM: elevation,
      weatherCondition: weatherCondition,
      rain24hMm: rainfall,
    );
    
    // Estimate depth based on risk and elevation
    double estimatedDepth;
    if (elevation < 5) {
      estimatedDepth = result['risk'] * 100;
    } else if (elevation < 10) {
      estimatedDepth = result['risk'] * 60;
    } else {
      estimatedDepth = result['risk'] * 30;
    }
    
    return FloodPrediction(
      probability: result['risk'],
      depthCm: estimatedDepth,
      riskLevel: result['level'],
      action: result['action'],
    );
  }

  /// Check if models are ready
  static bool get isReady => _isInitialized;
}
