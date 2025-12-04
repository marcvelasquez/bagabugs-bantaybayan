import 'package:latlong2/latlong.dart';
import 'dart:math';
import '../models/flood_risk_result.dart';
import '../utils/coordinate_utils.dart';
import '../services/flood_risk_service.dart';

/// Calculator for route risk assessment and cost optimization
/// Integrates flood risk into routing algorithms (Dijkstra, A*)
class RouteRiskCalculator {
  final FloodRiskService _floodRiskService;

  // Configuration
  static const double _defaultTrafficSpeed = 40.0; // km/h
  static const double _minSpeed = 5.0; // km/h
  static const double _maxSpeed = 100.0; // km/h

  RouteRiskCalculator({
    required FloodRiskService floodRiskService,
  }) : _floodRiskService = floodRiskService;

  /// Calculate total risk along a route path
  /// Returns detailed analysis of the route
  Future<RouteRiskAnalysis> calculateRouteRisk(List<LatLng> routePath) async {
    if (routePath.isEmpty) {
      throw ArgumentError('Route path cannot be empty');
    }

    // Sample points along route (every ~100m)
    final sampledPath = _sampleRoutePath(routePath, 100.0);

    // Get flood risk for each sampled point
    final pointRisks = await _floodRiskService.getFloodRiskBatch(sampledPath);

    // Calculate distance
    final totalDistance = _calculatePathDistance(routePath);

    // Calculate statistics
    final probabilities = pointRisks.map((r) => r.floodProbability).toList();
    final maxRisk = probabilities.reduce(max);
    final averageRisk = probabilities.reduce((a, b) => a + b) / probabilities.length;
    final overallRisk = _calculateOverallRisk(probabilities, totalDistance);

    // Identify high-risk segments
    final highRiskSegments = _identifyHighRiskSegments(pointRisks);

    // Estimate travel time
    final estimatedTime = _calculateEstimatedTime(
      distance: totalDistance,
      risks: pointRisks,
    );

    // Determine if route is recommended
    final isRecommended = _isRouteRecommended(overallRisk, maxRisk, highRiskSegments);

    return RouteRiskAnalysis(
      routePath: routePath,
      pointRisks: pointRisks,
      overallRisk: overallRisk,
      maxRisk: maxRisk,
      averageRisk: averageRisk,
      totalDistance: totalDistance,
      estimatedTime: estimatedTime,
      isRecommended: isRecommended,
      highRiskSegments: highRiskSegments,
    );
  }

  /// Calculate edge cost for routing algorithms
  /// Formula: Cost = (Distance / TrafficSpeed) × (1 + FloodSeverity) × RainMultiplier
  /// 
  /// - distance: Distance in meters
  /// - trafficSpeed: Speed in km/h (default 40 km/h)
  /// - floodProbability: 0.0 to 1.0
  /// - rainMultiplier: 1.0 (no rain) to 3.0 (heavy rain)
  Future<double> calculateEdgeCost({
    required LatLng start,
    required LatLng end,
    double? distance,
    double trafficSpeed = _defaultTrafficSpeed,
    double rainMultiplier = 1.0,
  }) async {
    // Calculate distance if not provided
    final edgeDistance = distance ?? CoordinateUtils.calculateDistance(start, end);

    // Get flood risk at midpoint of edge
    final midpoint = CoordinateUtils.interpolate(start, end, 0.5);
    final floodRisk = await _floodRiskService.getFloodRisk(midpoint);

    // Calculate flood severity (0.0 to infinity)
    // Maps probability to severity multiplier
    final floodSeverity = _calculateFloodSeverity(floodRisk.floodProbability);

    // Clamp speed to reasonable range
    final speed = trafficSpeed.clamp(_minSpeed, _maxSpeed);

    // Calculate base time cost (in hours)
    final baseTimeCost = (edgeDistance / 1000.0) / speed;

    // Apply flood and rain multipliers
    final totalCost = baseTimeCost * (1.0 + floodSeverity) * rainMultiplier;

    return totalCost;
  }

  /// Calculate flood severity multiplier from probability
  /// Uses exponential curve to heavily penalize high-risk areas
  double _calculateFloodSeverity(double probability) {
    // Exponential curve: severity increases rapidly above 0.5 probability
    if (probability < 0.1) return 0.0; // Minimal impact
    if (probability < 0.3) return probability * 0.5; // Low impact
    if (probability < 0.6) return probability * 2.0; // Moderate impact
    
    // High impact - exponential growth
    return pow(probability, 2) * 10.0;
  }

  /// Sample points along a route path at regular intervals
  List<LatLng> _sampleRoutePath(
    List<LatLng> path,
    double intervalMeters,
  ) {
    if (path.length < 2) return path;

    final sampledPoints = <LatLng>[path.first];

    for (int i = 0; i < path.length - 1; i++) {
      final start = path[i];
      final end = path[i + 1];
      final segmentDistance = CoordinateUtils.calculateDistance(start, end);

      // Determine number of sample points for this segment
      final numSamples = (segmentDistance / intervalMeters).ceil();

      for (int j = 1; j <= numSamples; j++) {
        final fraction = j / numSamples;
        final samplePoint = CoordinateUtils.interpolate(start, end, fraction);
        sampledPoints.add(samplePoint);
      }
    }

    return sampledPoints;
  }

  /// Calculate total distance of a path
  double _calculatePathDistance(List<LatLng> path) {
    double totalDistance = 0.0;

    for (int i = 0; i < path.length - 1; i++) {
      totalDistance += CoordinateUtils.calculateDistance(path[i], path[i + 1]);
    }

    return totalDistance;
  }

  /// Calculate overall risk score for entire route
  /// Weighted by distance (longer segments in high-risk areas = higher overall risk)
  double _calculateOverallRisk(List<double> risks, double totalDistance) {
    if (risks.isEmpty) return 0.0;

    // Weight risk by distance
    // Use max risk as a safety factor
    final maxRisk = risks.reduce(max);
    final avgRisk = risks.reduce((a, b) => a + b) / risks.length;

    // Combine max and average (60% max, 40% average)
    return (maxRisk * 0.6) + (avgRisk * 0.4);
  }

  /// Identify continuous high-risk segments along route
  List<RouteSegment> _identifyHighRiskSegments(List<FloodRiskResult> risks) {
    final segments = <RouteSegment>[];

    if (risks.isEmpty) return segments;

    int? segmentStart;
    FloodRiskLevel? currentLevel;

    for (int i = 0; i < risks.length; i++) {
      final risk = risks[i];

      if (risk.requiresWarning) {
        // Start new segment or continue existing
        if (segmentStart == null) {
          segmentStart = i;
          currentLevel = risk.riskLevel;
        } else if (currentLevel != risk.riskLevel) {
          // Risk level changed, close previous segment
          segments.add(RouteSegment(
            startIndex: segmentStart,
            endIndex: i - 1,
            riskLevel: currentLevel!,
            segmentDistance: _calculateSegmentDistance(risks, segmentStart, i - 1),
          ));
          segmentStart = i;
          currentLevel = risk.riskLevel;
        }
      } else {
        // End of high-risk segment
        if (segmentStart != null) {
          segments.add(RouteSegment(
            startIndex: segmentStart,
            endIndex: i - 1,
            riskLevel: currentLevel!,
            segmentDistance: _calculateSegmentDistance(risks, segmentStart, i - 1),
          ));
          segmentStart = null;
          currentLevel = null;
        }
      }
    }

    // Close final segment if still open
    if (segmentStart != null) {
      segments.add(RouteSegment(
        startIndex: segmentStart,
        endIndex: risks.length - 1,
        riskLevel: currentLevel!,
        segmentDistance: _calculateSegmentDistance(risks, segmentStart, risks.length - 1),
      ));
    }

    return segments;
  }

  /// Calculate distance for a segment of the route
  double _calculateSegmentDistance(
    List<FloodRiskResult> risks,
    int startIndex,
    int endIndex,
  ) {
    double distance = 0.0;

    for (int i = startIndex; i < endIndex; i++) {
      distance += CoordinateUtils.calculateDistance(
        risks[i].coordinate,
        risks[i + 1].coordinate,
      );
    }

    return distance;
  }

  /// Calculate estimated travel time accounting for flood risk
  double _calculateEstimatedTime({
    required double distance,
    required List<FloodRiskResult> risks,
    double baseSpeed = _defaultTrafficSpeed,
  }) {
    if (risks.isEmpty) {
      return (distance / 1000.0) / baseSpeed * 3600; // seconds
    }

    // Calculate time for each segment with speed adjusted by risk
    double totalTime = 0.0;
    
    for (int i = 0; i < risks.length - 1; i++) {
      final segmentDist = CoordinateUtils.calculateDistance(
        risks[i].coordinate,
        risks[i + 1].coordinate,
      );

      final risk = risks[i].floodProbability;
      
      // Reduce speed based on flood risk
      // High risk = much slower travel
      final speedMultiplier = 1.0 - (risk * 0.7); // Up to 70% slower
      final adjustedSpeed = baseSpeed * speedMultiplier.clamp(0.3, 1.0);

      // Time = distance / speed
      final segmentTime = (segmentDist / 1000.0) / adjustedSpeed * 3600; // seconds
      totalTime += segmentTime;
    }

    return totalTime;
  }

  /// Determine if route is recommended based on risk analysis
  bool _isRouteRecommended(
    double overallRisk,
    double maxRisk,
    List<RouteSegment> highRiskSegments,
  ) {
    // Don't recommend if overall risk is high
    if (overallRisk > 0.6) return false;

    // Don't recommend if max risk is severe
    if (maxRisk > 0.8) return false;

    // Don't recommend if there are many high-risk segments
    final severeSegments = highRiskSegments
        .where((s) => s.riskLevel == FloodRiskLevel.severe)
        .toList();
    if (severeSegments.isNotEmpty) return false;

    // Don't recommend if more than 30% of route is high risk
    // This is a simplified check - in production, compare to total distance
    if (highRiskSegments.length > 3) return false;

    return true;
  }

  /// Compare two routes and return the safer one
  RouteRiskAnalysis selectSaferRoute(
    RouteRiskAnalysis route1,
    RouteRiskAnalysis route2,
  ) {
    // Prefer route with lower overall risk
    if (route1.overallRisk < route2.overallRisk) return route1;
    if (route2.overallRisk < route1.overallRisk) return route2;

    // If overall risk is similar, prefer route with lower max risk
    if (route1.maxRisk < route2.maxRisk) return route1;
    if (route2.maxRisk < route1.maxRisk) return route2;

    // If risks are similar, prefer shorter route
    if (route1.totalDistance < route2.totalDistance) return route1;

    return route2;
  }

  /// Generate alternative route suggestions based on risk
  Future<List<String>> generateRouteSuggestions(RouteRiskAnalysis analysis) async {
    final suggestions = <String>[];

    if (!analysis.isRecommended) {
      suggestions.add('⚠️ This route passes through high-risk flood areas');
    }

    if (analysis.maxRisk > 0.8) {
      suggestions.add('🚨 Severe flood risk detected on this route');
      suggestions.add('Consider delaying travel or finding an alternative route');
    } else if (analysis.maxRisk > 0.6) {
      suggestions.add('⚠️ High flood risk areas ahead');
      suggestions.add('Proceed with caution and monitor weather conditions');
    } else if (analysis.maxRisk > 0.3) {
      suggestions.add('⚡ Moderate flood risk on some segments');
      suggestions.add('Stay alert for weather updates');
    }

    if (analysis.highRiskSegments.isNotEmpty) {
      final totalHighRiskDist = analysis.highRiskSegments
          .fold<double>(0.0, (sum, seg) => sum + seg.segmentDistance);
      
      if (totalHighRiskDist > 1000) {
        suggestions.add(
          '📍 ${(totalHighRiskDist / 1000).toStringAsFixed(1)} km of high-risk segments',
        );
      }
    }

    final estimatedMinutes = (analysis.estimatedTime / 60).ceil();
    suggestions.add('🕐 Estimated travel time: $estimatedMinutes minutes');

    return suggestions;
  }
}
