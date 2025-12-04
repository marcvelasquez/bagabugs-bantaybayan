import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'ml_prediction_service.dart';

/// Online routing service using OSRM (Open Source Routing Machine)
/// Provides accurate road-following routes with flood-risk awareness
class RoutingService {
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';
  static bool _isInitialized = false;

  /// Initialize the routing service
  static Future<bool> initialize() async {
    _isInitialized = true;
    print('✅ Routing service initialized (OSRM online mode)');
    return true;
  }

  /// Calculate Haversine distance in kilometers
  static double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return R * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  /// Get route from OSRM API - follows actual roads
  static Future<RouteResult?> findRoute({
    required LatLng start,
    required LatLng destination,
    bool considerFloodRisk = true,
  }) async {
    try {
      // OSRM expects coordinates as lon,lat (not lat,lon)
      final coordinates = '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}';
      final url = '$_osrmBaseUrl/route/v1/driving/$coordinates?overview=full&geometries=geojson&steps=true';
      
      print('🗺️ Fetching route from OSRM...');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        print('❌ OSRM API error: ${response.statusCode}');
        return null;
      }
      
      final data = jsonDecode(response.body);
      
      if (data['code'] != 'Ok' || data['routes'] == null || (data['routes'] as List).isEmpty) {
        print('❌ No route found');
        return null;
      }
      
      final route = data['routes'][0];
      final geometry = route['geometry']['coordinates'] as List;
      final distanceMeters = route['distance'] as num;
      final durationSeconds = route['duration'] as num;
      
      // Convert GeoJSON coordinates [lon, lat] to LatLng list
      final coordinatesList = geometry.map<LatLng>((coord) {
        return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
      }).toList();
      
      // Calculate flood risk along the route if requested
      double averageFloodRisk = 0.0;
      if (considerFloodRisk && coordinatesList.isNotEmpty) {
        averageFloodRisk = await _calculateRouteFloodRisk(coordinatesList);
      }
      
      // Parse turn-by-turn directions
      final steps = route['legs'][0]['steps'] as List;
      final directions = _parseDirections(steps);
      
      print('✅ Route found: ${(distanceMeters / 1000).toStringAsFixed(2)} km, ${(durationSeconds / 60).toStringAsFixed(0)} min');
      
      return RouteResult(
        coordinates: coordinatesList,
        distanceKm: distanceMeters / 1000,
        durationMinutes: durationSeconds / 60,
        averageFloodRisk: averageFloodRisk,
        directions: directions,
      );
    } catch (e) {
      print('❌ Error fetching route: $e');
      return null;
    }
  }

  /// Calculate average flood risk along a route by sampling points
  static Future<double> _calculateRouteFloodRisk(List<LatLng> routeCoordinates) async {
    if (routeCoordinates.isEmpty) return 0.0;
    
    // Sample every nth point to avoid too many API calls
    final sampleInterval = max(1, routeCoordinates.length ~/ 10);
    double totalRisk = 0.0;
    int samples = 0;
    
    for (int i = 0; i < routeCoordinates.length; i += sampleInterval) {
      try {
        final point = routeCoordinates[i];
        final prediction = await MLPredictionService.predictForLocation(
          location: point,
          weatherCondition: 'rain',
          rain24hMm: 50.0, // Default moderate rain
        );
        
        if (prediction != null) {
          totalRisk += prediction.probability;
          samples++;
        }
      } catch (e) {
        // Skip failed predictions
      }
    }
    
    return samples > 0 ? totalRisk / samples : 0.0;
  }

  /// Parse OSRM directions into human-readable format
  static List<RouteDirection> _parseDirections(List steps) {
    final directions = <RouteDirection>[];
    
    for (final step in steps) {
      final maneuver = step['maneuver'];
      final name = step['name'] as String? ?? '';
      final distance = (step['distance'] as num).toDouble();
      final duration = (step['duration'] as num).toDouble();
      final type = maneuver['type'] as String;
      final modifier = maneuver['modifier'] as String?;
      final location = maneuver['location'] as List;
      
      String instruction = _buildInstruction(type, modifier, name);
      
      directions.add(RouteDirection(
        instruction: instruction,
        distanceMeters: distance,
        durationSeconds: duration,
        maneuverType: type,
        modifier: modifier,
        location: LatLng((location[1] as num).toDouble(), (location[0] as num).toDouble()),
        streetName: name,
      ));
    }
    
    return directions;
  }

  /// Build human-readable instruction from maneuver
  static String _buildInstruction(String type, String? modifier, String streetName) {
    final street = streetName.isNotEmpty ? ' onto $streetName' : '';
    
    switch (type) {
      case 'depart':
        return 'Start$street';
      case 'arrive':
        return 'Arrive at destination';
      case 'turn':
        switch (modifier) {
          case 'left':
            return 'Turn left$street';
          case 'right':
            return 'Turn right$street';
          case 'slight left':
            return 'Turn slight left$street';
          case 'slight right':
            return 'Turn slight right$street';
          case 'sharp left':
            return 'Turn sharp left$street';
          case 'sharp right':
            return 'Turn sharp right$street';
          case 'uturn':
            return 'Make a U-turn$street';
          default:
            return 'Turn$street';
        }
      case 'continue':
        return 'Continue$street';
      case 'merge':
        return 'Merge$street';
      case 'roundabout':
        return 'Enter roundabout$street';
      case 'exit roundabout':
        return 'Exit roundabout$street';
      case 'fork':
        if (modifier == 'left') return 'Keep left$street';
        if (modifier == 'right') return 'Keep right$street';
        return 'At fork$street';
      case 'end of road':
        if (modifier == 'left') return 'At end of road, turn left$street';
        if (modifier == 'right') return 'At end of road, turn right$street';
        return 'End of road$street';
      case 'new name':
        return 'Continue$street';
      case 'notification':
        return streetName.isNotEmpty ? streetName : 'Continue';
      default:
        return 'Continue$street';
    }
  }

  /// Find multiple alternative routes (safest and fastest)
  static Future<List<RouteResult>> findAlternativeRoutes({
    required LatLng start,
    required LatLng destination,
    int maxRoutes = 3,
  }) async {
    final routes = <RouteResult>[];

    // Try to get alternative routes from OSRM
    try {
      final coordinates = '${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}';
      final url = '$_osrmBaseUrl/route/v1/driving/$coordinates?overview=full&geometries=geojson&steps=true&alternatives=true';
      
      print('🗺️ Fetching routes with alternatives from OSRM...');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null) {
          final routesList = data['routes'] as List;
          
          for (int i = 0; i < routesList.length && routes.length < maxRoutes; i++) {
            final route = routesList[i];
            final geometry = route['geometry']['coordinates'] as List;
            final distanceMeters = route['distance'] as num;
            final durationSeconds = route['duration'] as num;
            
            final coords = geometry.map<LatLng>((coord) {
              return LatLng((coord[1] as num).toDouble(), (coord[0] as num).toDouble());
            }).toList();
            
            final floodRisk = await _calculateRouteFloodRisk(coords);
            
            final steps = route['legs'][0]['steps'] as List;
            final directions = _parseDirections(steps);
            
            routes.add(RouteResult(
              coordinates: coords,
              distanceKm: distanceMeters / 1000,
              durationMinutes: durationSeconds / 60,
              averageFloodRisk: floodRisk,
              directions: directions,
              isAlternative: i > 0,
            ));
          }
        }
      }
    } catch (e) {
      print('❌ Error fetching alternative routes: $e');
      
      // Fallback to single route
      final singleRoute = await findRoute(
        start: start,
        destination: destination,
        considerFloodRisk: true,
      );
      if (singleRoute != null) {
        routes.add(singleRoute);
      }
    }

    // Sort routes by flood risk (safest first)
    routes.sort((a, b) => a.averageFloodRisk.compareTo(b.averageFloodRisk));

    return routes;
  }

  /// Get route to nearest evacuation center
  static Future<RouteResult?> findRouteToEvacuationCenter({
    required LatLng currentLocation,
    required List<LatLng> evacuationCenters,
  }) async {
    if (evacuationCenters.isEmpty) return null;

    RouteResult? bestRoute;
    double bestScore = double.infinity;

    for (final center in evacuationCenters) {
      final route = await findRoute(
        start: currentLocation,
        destination: center,
        considerFloodRisk: true,
      );

      if (route != null) {
        // Score = distance * (1 + flood_risk) to balance distance and safety
        final score = route.distanceKm * (1 + route.averageFloodRisk);
        
        if (score < bestScore) {
          bestScore = score;
          bestRoute = route;
        }
      }
    }

    return bestRoute;
  }

  static bool get isReady => _isInitialized;
}

/// Result of a route calculation
class RouteResult {
  final List<LatLng> coordinates;
  final double distanceKm;
  final double durationMinutes;
  final double averageFloodRisk;
  final List<RouteDirection> directions;
  final bool isAlternative;

  RouteResult({
    required this.coordinates,
    required this.distanceKm,
    required this.durationMinutes,
    required this.averageFloodRisk,
    this.directions = const [],
    this.isAlternative = false,
  });

  String get riskLevel {
    if (averageFloodRisk < 0.2) return 'LOW';
    if (averageFloodRisk < 0.4) return 'MODERATE';
    if (averageFloodRisk < 0.6) return 'HIGH';
    if (averageFloodRisk < 0.8) return 'VERY HIGH';
    return 'EXTREME';
  }

  String get formattedDistance {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    if (durationMinutes < 1) {
      return '< 1 min';
    }
    if (durationMinutes < 60) {
      return '${durationMinutes.toStringAsFixed(0)} min';
    }
    final hours = (durationMinutes / 60).floor();
    final mins = (durationMinutes % 60).toStringAsFixed(0);
    return '${hours}h ${mins}m';
  }
}

/// Turn-by-turn direction
class RouteDirection {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final String maneuverType;
  final String? modifier;
  final LatLng location;
  final String streetName;

  RouteDirection({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.maneuverType,
    this.modifier,
    required this.location,
    required this.streetName,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}
