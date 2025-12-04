import 'package:latlong2/latlong.dart';

/// Result of flood risk prediction for a single location
class FloodRiskResult {
  /// Geographic coordinate
  final LatLng coordinate;
  
  /// Predicted flood probability (0.0 - 1.0)
  final double floodProbability;
  
  /// Predicted flood depth in meters (0.0 - 3.0+)
  final double floodDepth;
  
  /// Risk level categorization
  final FloodRiskLevel riskLevel;
  
  /// Timestamp of prediction
  final DateTime timestamp;
  
  /// Input features used for prediction (for debugging)
  final Map<String, double>? features;

  FloodRiskResult({
    required this.coordinate,
    required this.floodProbability,
    required this.floodDepth,
    required this.riskLevel,
    DateTime? timestamp,
    this.features,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Calculate risk level from probability
  factory FloodRiskResult.fromPrediction({
    required LatLng coordinate,
    required double floodProbability,
    required double floodDepth,
    Map<String, double>? features,
  }) {
    return FloodRiskResult(
      coordinate: coordinate,
      floodProbability: floodProbability,
      floodDepth: floodDepth,
      riskLevel: _getRiskLevel(floodProbability),
      features: features,
    );
  }

  /// Determine risk level from probability
  static FloodRiskLevel _getRiskLevel(double probability) {
    if (probability < 0.1) return FloodRiskLevel.minimal;
    if (probability < 0.3) return FloodRiskLevel.low;
    if (probability < 0.6) return FloodRiskLevel.moderate;
    if (probability < 0.8) return FloodRiskLevel.high;
    return FloodRiskLevel.severe;
  }

  /// Get color representation of risk level
  int get colorCode {
    switch (riskLevel) {
      case FloodRiskLevel.minimal:
        return 0xFF4CAF50; // Green
      case FloodRiskLevel.low:
        return 0xFFFFEB3B; // Yellow
      case FloodRiskLevel.moderate:
        return 0xFFFF9800; // Orange
      case FloodRiskLevel.high:
        return 0xFFFF5722; // Deep Orange
      case FloodRiskLevel.severe:
        return 0xFFF44336; // Red
    }
  }

  /// Check if location is safe for routing
  bool get isSafe => riskLevel == FloodRiskLevel.minimal || 
                     riskLevel == FloodRiskLevel.low;

  /// Check if location requires warning
  bool get requiresWarning => riskLevel.index >= FloodRiskLevel.moderate.index;

  /// Check if location should be avoided
  bool get shouldAvoid => riskLevel.index >= FloodRiskLevel.high.index;

  @override
  String toString() {
    return 'FloodRiskResult(coord: ${coordinate.latitude.toStringAsFixed(4)}, '
           '${coordinate.longitude.toStringAsFixed(4)}, '
           'prob: ${(floodProbability * 100).toStringAsFixed(1)}%, '
           'depth: ${floodDepth.toStringAsFixed(2)}m, '
           'level: ${riskLevel.name})';
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'latitude': coordinate.latitude,
      'longitude': coordinate.longitude,
      'flood_probability': floodProbability,
      'flood_depth': floodDepth,
      'risk_level': riskLevel.index,
      'timestamp': timestamp.toIso8601String(),
      'features': features,
    };
  }

  /// Create from JSON
  factory FloodRiskResult.fromJson(Map<String, dynamic> json) {
    return FloodRiskResult(
      coordinate: LatLng(json['latitude'], json['longitude']),
      floodProbability: json['flood_probability'],
      floodDepth: json['flood_depth'],
      riskLevel: FloodRiskLevel.values[json['risk_level']],
      timestamp: DateTime.parse(json['timestamp']),
      features: json['features'] != null 
          ? Map<String, double>.from(json['features']) 
          : null,
    );
  }
}

/// Flood risk severity levels
enum FloodRiskLevel {
  minimal,   // < 10% probability
  low,       // 10-30% probability
  moderate,  // 30-60% probability
  high,      // 60-80% probability
  severe,    // > 80% probability
}

extension FloodRiskLevelExtension on FloodRiskLevel {
  String get displayName {
    switch (this) {
      case FloodRiskLevel.minimal:
        return 'Minimal Risk';
      case FloodRiskLevel.low:
        return 'Low Risk';
      case FloodRiskLevel.moderate:
        return 'Moderate Risk';
      case FloodRiskLevel.high:
        return 'High Risk';
      case FloodRiskLevel.severe:
        return 'Severe Risk';
    }
  }

  String get description {
    switch (this) {
      case FloodRiskLevel.minimal:
        return 'Area is safe for travel';
      case FloodRiskLevel.low:
        return 'Monitor weather conditions';
      case FloodRiskLevel.moderate:
        return 'Exercise caution, consider alternative route';
      case FloodRiskLevel.high:
        return 'Avoid this area if possible';
      case FloodRiskLevel.severe:
        return 'Do not proceed - high flood danger';
    }
  }
}

/// Result of route risk analysis
class RouteRiskAnalysis {
  /// List of coordinates along the route
  final List<LatLng> routePath;
  
  /// Risk assessment for each point on the route
  final List<FloodRiskResult> pointRisks;
  
  /// Overall route risk score (0.0 - 1.0)
  final double overallRisk;
  
  /// Maximum risk encountered on route
  final double maxRisk;
  
  /// Average risk along route
  final double averageRisk;
  
  /// Total route distance in meters
  final double totalDistance;
  
  /// Estimated travel time in seconds (accounting for flood risk)
  final double estimatedTime;
  
  /// Whether route is recommended
  final bool isRecommended;
  
  /// High-risk segments (start index, end index, risk level)
  final List<RouteSegment> highRiskSegments;

  RouteRiskAnalysis({
    required this.routePath,
    required this.pointRisks,
    required this.overallRisk,
    required this.maxRisk,
    required this.averageRisk,
    required this.totalDistance,
    required this.estimatedTime,
    required this.isRecommended,
    required this.highRiskSegments,
  });

  /// Number of high-risk points on route
  int get highRiskPointCount => 
      pointRisks.where((r) => r.shouldAvoid).length;

  /// Percentage of route that is high risk
  double get highRiskPercentage => 
      (highRiskPointCount / pointRisks.length) * 100;

  @override
  String toString() {
    return 'RouteRiskAnalysis(points: ${routePath.length}, '
           'overall: ${(overallRisk * 100).toStringAsFixed(1)}%, '
           'max: ${(maxRisk * 100).toStringAsFixed(1)}%, '
           'recommended: $isRecommended)';
  }
}

/// Represents a segment of a route with specific risk level
class RouteSegment {
  final int startIndex;
  final int endIndex;
  final FloodRiskLevel riskLevel;
  final double segmentDistance;

  RouteSegment({
    required this.startIndex,
    required this.endIndex,
    required this.riskLevel,
    required this.segmentDistance,
  });

  int get length => endIndex - startIndex + 1;
}
