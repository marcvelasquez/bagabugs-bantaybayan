import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/flood_risk_service.dart';
import '../services/tflite_inference_service.dart';
import '../services/spatial_index_service.dart';
import '../models/route_risk_calculator.dart';
import '../models/flood_risk_result.dart';

/// Example integration of flood risk ML models with routing
/// 
/// This demonstrates how to:
/// 1. Initialize ML services
/// 2. Get flood risk for a location
/// 3. Analyze a route for flood risk
/// 4. Calculate route costs with risk factors
class FloodRiskIntegrationExample extends StatefulWidget {
  const FloodRiskIntegrationExample({super.key});

  @override
  State<FloodRiskIntegrationExample> createState() =>
      _FloodRiskIntegrationExampleState();
}

class _FloodRiskIntegrationExampleState
    extends State<FloodRiskIntegrationExample> {
  late FloodRiskService _floodRiskService;
  late RouteRiskCalculator _routeCalculator;
  bool _isInitialized = false;
  FloodRiskResult? _currentLocationRisk;
  RouteRiskAnalysis? _routeAnalysis;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initialize all ML and spatial services
  Future<void> _initializeServices() async {
    try {
      // Initialize TFLite inference service
      final tfliteService = TFLiteInferenceService();
      await tfliteService.initialize();

      // Initialize spatial index service
      final spatialService = SpatialIndexService();
      await spatialService.initialize();

      // Initialize flood risk service
      _floodRiskService = FloodRiskService(
        inferenceService: tfliteService,
        spatialService: spatialService,
      );
      await _floodRiskService.initialize();

      // Initialize route calculator
      _routeCalculator = RouteRiskCalculator(
        floodRiskService: _floodRiskService,
      );

      setState(() {
        _isInitialized = true;
      });

      print('✅ All services initialized successfully');
    } catch (e) {
      print('❌ Error initializing services: $e');
    }
  }

  /// Example 1: Get flood risk for current location
  Future<void> _checkCurrentLocationRisk() async {
    if (!_isInitialized) return;

    try {
      // Example location (Manila, Philippines)
      final currentLocation = const LatLng(14.5995, 120.9842);

      print('📍 Checking flood risk for: $currentLocation');

      // Get flood risk prediction
      final risk = await _floodRiskService.getFloodRisk(currentLocation);

      setState(() {
        _currentLocationRisk = risk;
      });

      print('📊 Flood Risk Results:');
      print('   Probability: ${(risk.floodProbability * 100).toStringAsFixed(1)}%');
      print('   Estimated Depth: ${risk.floodDepth.toStringAsFixed(2)}m');
      print('   Risk Level: ${risk.riskLevel.displayName}');
      print('   Safe to travel: ${risk.isSafe}');

      // Show user notification based on risk
      if (risk.shouldAvoid) {
        _showRiskWarning(
          'High flood risk detected at your location! '
          'Consider moving to higher ground.',
        );
      }
    } catch (e) {
      print('Error checking location risk: $e');
    }
  }

  /// Example 2: Analyze a route for flood risk
  Future<void> _analyzeRoute() async {
    if (!_isInitialized) return;

    try {
      // Example route (simulated path from point A to point B)
      final route = _generateExampleRoute(
        start: const LatLng(14.60, 120.98),
        end: const LatLng(14.65, 121.05),
        numPoints: 20,
      );

      print('🛣️ Analyzing route with ${route.length} points...');

      // Analyze route risk
      final analysis = await _routeCalculator.calculateRouteRisk(route);

      setState(() {
        _routeAnalysis = analysis;
      });

      print('📊 Route Analysis Results:');
      print('   Overall Risk: ${(analysis.overallRisk * 100).toStringAsFixed(1)}%');
      print('   Max Risk: ${(analysis.maxRisk * 100).toStringAsFixed(1)}%');
      print('   Average Risk: ${(analysis.averageRisk * 100).toStringAsFixed(1)}%');
      print('   Distance: ${(analysis.totalDistance / 1000).toStringAsFixed(2)} km');
      print('   Estimated Time: ${(analysis.estimatedTime / 60).toStringAsFixed(0)} minutes');
      print('   Recommended: ${analysis.isRecommended ? "✅" : "⚠️"}');
      print('   High-risk segments: ${analysis.highRiskSegments.length}');

      // Get route suggestions
      final suggestions = await _routeCalculator.generateRouteSuggestions(analysis);
      print('\n💡 Suggestions:');
      for (final suggestion in suggestions) {
        print('   $suggestion');
      }

      if (!analysis.isRecommended) {
        _showRiskWarning(
          'This route passes through high-risk flood areas. '
          'Consider an alternative route.',
        );
      }
    } catch (e) {
      print('Error analyzing route: $e');
    }
  }

  /// Example 3: Calculate edge cost for routing algorithm (Dijkstra/A*)
  Future<void> _calculateEdgeCost() async {
    if (!_isInitialized) return;

    try {
      final start = const LatLng(14.60, 120.98);
      final end = const LatLng(14.61, 120.99);

      // Calculate cost without rain
      final normalCost = await _routeCalculator.calculateEdgeCost(
        start: start,
        end: end,
        trafficSpeed: 40.0, // km/h
        rainMultiplier: 1.0, // No rain
      );

      // Calculate cost with heavy rain
      final rainyCost = await _routeCalculator.calculateEdgeCost(
        start: start,
        end: end,
        trafficSpeed: 40.0,
        rainMultiplier: 2.5, // Heavy rain
      );

      print('⚡ Edge Cost Calculation:');
      print('   Normal conditions: ${normalCost.toStringAsFixed(4)} hours');
      print('   Heavy rain: ${rainyCost.toStringAsFixed(4)} hours');
      print('   Rain impact: ${((rainyCost / normalCost - 1) * 100).toStringAsFixed(1)}% increase');

      // Use this cost in your routing algorithm
      // Example: Dijkstra's algorithm would use this as edge weight
    } catch (e) {
      print('Error calculating edge cost: $e');
    }
  }

  /// Example 4: Find safe edge if destination is flooded
  Future<void> _findSafeAlternative() async {
    if (!_isInitialized) return;

    try {
      // Flooded destination
      final floodedDestination = const LatLng(14.62, 121.00);

      print('🔍 Finding safe alternative to flooded destination...');

      final safeLocation = await _floodRiskService.findSafeEdge(
        destination: floodedDestination,
        maxRiskThreshold: 0.3, // Maximum acceptable risk
        maxSearchRadius: 2000.0, // Search within 2km
      );

      if (safeLocation != null) {
        print('✅ Found safe alternative location:');
        print('   ${safeLocation.latitude}, ${safeLocation.longitude}');

        // Guide user to safe location instead
        _showSuccessMessage(
          'Destination is flooded. Redirecting to nearest safe location.',
        );
      } else {
        print('❌ No safe location found within search radius');
        _showRiskWarning(
          'Destination area is heavily flooded. No safe alternative found nearby.',
        );
      }
    } catch (e) {
      print('Error finding safe alternative: $e');
    }
  }

  /// Example 5: Batch processing for multiple locations
  Future<void> _batchProcessing() async {
    if (!_isInitialized) return;

    try {
      // Multiple locations to check
      final locations = [
        const LatLng(14.60, 120.98),
        const LatLng(14.61, 120.99),
        const LatLng(14.62, 121.00),
        const LatLng(14.63, 121.01),
        const LatLng(14.64, 121.02),
      ];

      print('📦 Batch processing ${locations.length} locations...');

      final results = await _floodRiskService.getFloodRiskBatch(locations);

      print('📊 Batch Results:');
      for (int i = 0; i < results.length; i++) {
        final risk = results[i];
        print('   Location ${i + 1}: ${(risk.floodProbability * 100).toStringAsFixed(1)}% risk');
      }

      // Find safest location
      final safest = results.reduce(
        (a, b) => a.floodProbability < b.floodProbability ? a : b,
      );
      print('\n✅ Safest location: ${safest.coordinate}');
    } catch (e) {
      print('Error in batch processing: $e');
    }
  }

  /// Generate example route between two points
  List<LatLng> _generateExampleRoute({
    required LatLng start,
    required LatLng end,
    required int numPoints,
  }) {
    final route = <LatLng>[];
    for (int i = 0; i < numPoints; i++) {
      final fraction = i / (numPoints - 1);
      final lat = start.latitude + (end.latitude - start.latitude) * fraction;
      final lng = start.longitude + (end.longitude - start.longitude) * fraction;
      route.add(LatLng(lat, lng));
    }
    return route;
  }

  void _showRiskWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flood Risk ML Integration Example'),
      ),
      body: _isInitialized
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Flood Risk ML Model Examples',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Current location risk
                  _buildExampleCard(
                    title: '1. Check Current Location Risk',
                    description: 'Get flood risk prediction for a specific location',
                    onPressed: _checkCurrentLocationRisk,
                    result: _currentLocationRisk != null
                        ? 'Risk: ${(_currentLocationRisk!.floodProbability * 100).toStringAsFixed(1)}% '
                            '(${_currentLocationRisk!.riskLevel.displayName})'
                        : null,
                  ),

                  // Route analysis
                  _buildExampleCard(
                    title: '2. Analyze Route',
                    description: 'Analyze flood risk along an entire route',
                    onPressed: _analyzeRoute,
                    result: _routeAnalysis != null
                        ? 'Overall Risk: ${(_routeAnalysis!.overallRisk * 100).toStringAsFixed(1)}% '
                            '| ${_routeAnalysis!.isRecommended ? "✅ Recommended" : "⚠️ Not Recommended"}'
                        : null,
                  ),

                  // Edge cost calculation
                  _buildExampleCard(
                    title: '3. Calculate Routing Cost',
                    description: 'Get edge cost for routing algorithms (Dijkstra/A*)',
                    onPressed: _calculateEdgeCost,
                  ),

                  // Find safe alternative
                  _buildExampleCard(
                    title: '4. Find Safe Alternative',
                    description: 'Find nearest safe location if destination is flooded',
                    onPressed: _findSafeAlternative,
                  ),

                  // Batch processing
                  _buildExampleCard(
                    title: '5. Batch Processing',
                    description: 'Process multiple locations at once',
                    onPressed: _batchProcessing,
                  ),
                ],
              ),
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing ML models...'),
                ],
              ),
            ),
    );
  }

  Widget _buildExampleCard({
    required String title,
    required String description,
    required VoidCallback onPressed,
    String? result,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (result != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  result,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onPressed,
              child: const Text('Run Example'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _floodRiskService.dispose();
    super.dispose();
  }
}
