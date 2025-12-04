import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:another_telephony/telephony.dart';
import '../core/theme/colors.dart';
import '../core/theme/theme_provider.dart';
import '../widgets/sos_confirmation_modal.dart';
import '../widgets/profile_dropdown.dart';
import '../services/ml_prediction_service.dart';
import '../services/scenario_service.dart';
import '../services/routing_service.dart';
import '../services/api_service.dart';
import '../services/offline_cache_service.dart';
import '../services/cached_tile_provider.dart';
import '../models/api_models.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController? _mapController;
  bool _isSOSActive = false;
  final List<Marker> _markers = [];
  final List<CircleMarker> _circles = [];
  final List<Polyline> _routeLines = [];
  
  // Offline cache service
  final OfflineCacheService _cacheService = OfflineCacheService();
  
  // ML Prediction state
  FloodPrediction? _currentPrediction;
  bool _isMLActive = false;
  bool _isCalculatingRisk = false;
  
  // Routing state
  RouteResult? _selectedRoute;
  bool _isCalculatingRoute = false;
  EmergencyLocation? _selectedDestination;
  SearchResult? _searchDestination; // For searched location navigation
  
  // Weather forecast state
  WeatherForecast? _weatherForecast;
  int _selectedForecastDay = 0;
  final List<CircleMarker> _forecastFloodZones = [];
  FloodPrediction? _forecastPrediction; // Prediction for selected forecast day
  
  // Default location (Manila, Philippines)
  static const LatLng _defaultLocation = LatLng(14.5995, 120.9842);
  LatLng _currentLocation = _defaultLocation;

  // Emergency locations (pinned)
  final List<EmergencyLocation> _emergencyLocations = [
    const EmergencyLocation(
      name: 'Evacuation Center A',
      position: LatLng(14.6020, 120.9880),
      type: EmergencyLocationType.evacuationCenter,
    ),
    const EmergencyLocation(
      name: 'Medical Station',
      position: LatLng(14.6050, 120.9900),
      type: EmergencyLocationType.medicalStation,
    ),
    const EmergencyLocation(
      name: 'Evacuation Center B',
      position: LatLng(14.5980, 120.9920),
      type: EmergencyLocationType.evacuationCenter,
    ),
    const EmergencyLocation(
      name: 'Relief Center',
      position: LatLng(14.6010, 120.9950),
      type: EmergencyLocationType.reliefCenter,
    ),
    const EmergencyLocation(
      name: 'General Hospital',
      position: LatLng(14.6040, 120.9820),
      type: EmergencyLocationType.hospital,
    ),
    const EmergencyLocation(
      name: 'Police Station 1',
      position: LatLng(14.5970, 120.9860),
      type: EmergencyLocationType.policeStation,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeCache();
    _getCurrentLocation();
    _createMarkers();
    _createFloodZones();
    _checkMLStatus();
    _initializeRouting();
    _loadWeatherForecast();
  }

  /// Initialize offline cache and pre-cache map tiles for the area
  Future<void> _initializeCache() async {
    await _cacheService.initialize();
    
    // Cache emergency locations as landmarks
    final landmarks = _emergencyLocations.map((loc) => {
      'name': loc.name,
      'display_name': loc.name,
      'latitude': loc.position.latitude,
      'longitude': loc.position.longitude,
      'type': loc.type.toString(),
    }).toList();
    
    await _cacheService.cacheLandmarks(landmarks);
    
    // Pre-cache tiles for current area in background
    _preCacheAreaTiles();
  }

  /// Pre-cache map tiles for the current area
  Future<void> _preCacheAreaTiles() async {
    // Pre-cache tiles for 5km radius around current location
    // This runs in background and doesn't block UI
    try {
      await _cacheService.preCacheTilesForArea(
        center: _currentLocation,
        radiusKm: 5.0,
        minZoom: 13,
        maxZoom: 16,
      );
      debugPrint('✅ Pre-cached map tiles for current area');
    } catch (e) {
      debugPrint('⚠️ Failed to pre-cache tiles: $e');
    }
  }

  Future<void> _loadWeatherForecast() async {
    try {
      final forecast = await ApiService.getWeatherForecast(
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
        days: 7,
      );
      
      if (mounted) {
        setState(() {
          _weatherForecast = forecast;
        });
        // Show flood zones for today by default
        _updateForecastFloodZones();
      }
    } catch (e) {
      print('Error loading weather forecast: $e');
    }
  }

  Future<void> _calculateForecastPrediction() async {
    if (_weatherForecast == null || _selectedForecastDay >= _weatherForecast!.forecast.length) return;
    
    final day = _weatherForecast!.forecast[_selectedForecastDay];
    
    // Use the weather data to calculate flood prediction
    // Map weather code to condition for better prediction
    String weatherCondition;
    if (day.weatherCode >= 95) {
      weatherCondition = 'typhoon';
    } else if (day.weatherCode >= 80 || day.precipitation >= 50) {
      weatherCondition = 'heavy_rain';
    } else if (day.weatherCode >= 61 || day.precipitation >= 20) {
      weatherCondition = 'moderate_rain';
    } else if (day.weatherCode >= 51 || day.precipitation >= 5) {
      weatherCondition = 'light_rain';
    } else if (day.weatherCode >= 45) {
      weatherCondition = 'cloudy';
    } else {
      weatherCondition = 'clear';
    }
    
    // Use the precipitation data to calculate flood prediction
    final prediction = await MLPredictionService.predictForLocation(
      location: _currentLocation,
      weatherCondition: weatherCondition,
      rain24hMm: day.precipitation,
    );
    
    if (prediction != null && mounted) {
      setState(() {
        _forecastPrediction = prediction;
      });
      _showPredictionDetails();
    } else if (mounted) {
      // Fallback: create a basic prediction based on weather data
      final fallbackPrediction = FloodPrediction(
        probability: day.precipitation > 50 ? 0.7 : day.precipitation > 20 ? 0.4 : 0.1,
        depthCm: day.precipitation > 50 ? 45.0 : day.precipitation > 20 ? 20.0 : 5.0,
        riskLevel: day.precipitation > 50 ? 'HIGH' : day.precipitation > 20 ? 'MODERATE' : 'LOW',
        action: day.precipitation > 50 
            ? 'Prepare for potential flooding. Move valuables to higher ground.'
            : day.precipitation > 20 
                ? 'Monitor weather updates. Be prepared to evacuate if needed.'
                : 'Normal conditions expected. Stay informed of weather changes.',
      );
      setState(() {
        _forecastPrediction = fallbackPrediction;
      });
      _showPredictionDetails();
    }
  }

  void _showPredictionDetails() {
    if (_forecastPrediction == null || _weatherForecast == null) return;
    
    final day = _weatherForecast!.forecast[_selectedForecastDay];
    final date = DateTime.parse(day.date);
    final dayName = _selectedForecastDay == 0 
        ? 'Today' 
        : _selectedForecastDay == 1 
            ? 'Tomorrow'
            : '${_getDayName(date.weekday)}, ${date.day}/${date.month}';
    
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDarkMode = themeProvider.isDarkMode;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkBackgroundMid : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getPredictionColorForLevel(_forecastPrediction!.riskLevel).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.water_drop,
                    color: _getPredictionColorForLevel(_forecastPrediction!.riskLevel),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Flood Prediction',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : AppColors.lightTextPrimary,
                        ),
                      ),
                      Text(
                        dayName,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _getWeatherIcon(day.weatherCode),
                  style: const TextStyle(fontSize: 36),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Risk Level Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getPredictionColorForLevel(_forecastPrediction!.riskLevel).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getPredictionColorForLevel(_forecastPrediction!.riskLevel).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _forecastPrediction!.riskLevel,
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _getPredictionColorForLevel(_forecastPrediction!.riskLevel),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Risk Level',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Stats Row
            Row(
              children: [
                Expanded(
                  child: _buildPredictionStat(
                    icon: Icons.percent,
                    value: '${(_forecastPrediction!.probability * 100).toStringAsFixed(0)}%',
                    label: 'Flood Probability',
                    color: Colors.blue,
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPredictionStat(
                    icon: Icons.straighten,
                    value: '${_forecastPrediction!.depthCm.toStringAsFixed(0)} cm',
                    label: 'Est. Depth',
                    color: Colors.orange,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPredictionStat(
                    icon: Icons.water_drop,
                    value: '${day.precipitation.toStringAsFixed(1)} mm',
                    label: 'Precipitation',
                    color: Colors.cyan,
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPredictionStat(
                    icon: Icons.air,
                    value: '${day.windSpeedMax.toStringAsFixed(0)} km/h',
                    label: 'Max Wind',
                    color: Colors.teal,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Recommended Action
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Recommended Action',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _forecastPrediction!.action,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: isDarkMode ? Colors.white60 : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getPredictionColorForLevel(String level) {
    switch (level) {
      case 'CRITICAL':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'MODERATE':
        return Colors.yellow.shade700;
      default:
        return Colors.green;
    }
  }

  void _updateForecastFloodZones() {
    if (_weatherForecast == null || _selectedForecastDay >= _weatherForecast!.forecast.length) return;
    
    final day = _weatherForecast!.forecast[_selectedForecastDay];
    _forecastFloodZones.clear();
    
    // Determine flood severity based on precipitation and weather code
    final isStormDay = _isStormyWeather(day.weatherCode) || day.precipitation > 20;
    
    if (!isStormDay) {
      setState(() {});
      return;
    }
    
    // Generate flood-prone zones based on precipitation levels
    // These would ideally come from a proper flood model, but we'll simulate
    final floodProneLocs = [
      LatLng(_currentLocation.latitude + 0.005, _currentLocation.longitude + 0.003),
      LatLng(_currentLocation.latitude - 0.003, _currentLocation.longitude + 0.006),
      LatLng(_currentLocation.latitude + 0.002, _currentLocation.longitude - 0.004),
      LatLng(_currentLocation.latitude - 0.006, _currentLocation.longitude - 0.002),
      LatLng(_currentLocation.latitude + 0.008, _currentLocation.longitude + 0.001),
    ];
    
    Color zoneColor;
    double baseRadius;
    
    // Calculate severity based on precipitation
    if (day.precipitation > 50 || day.weatherCode >= 95) {
      zoneColor = Colors.red;
      baseRadius = 400.0;
    } else if (day.precipitation > 30 || day.weatherCode >= 80) {
      zoneColor = Colors.orange;
      baseRadius = 300.0;
    } else {
      zoneColor = Colors.yellow.shade700;
      baseRadius = 200.0;
    }
    
    for (int i = 0; i < floodProneLocs.length; i++) {
      // Vary radius slightly for more natural appearance
      final radius = baseRadius * (0.8 + (i % 3) * 0.2);
      
      _forecastFloodZones.add(
        CircleMarker(
          point: floodProneLocs[i],
          radius: radius,
          color: zoneColor.withValues(alpha: 0.35),
          borderColor: zoneColor.withValues(alpha: 0.7),
          borderStrokeWidth: 2,
          useRadiusInMeter: true,
        ),
      );
    }
    
    setState(() {});
  }

  bool _isStormyWeather(int weatherCode) {
    return weatherCode >= 95 || // Thunderstorms
        (weatherCode >= 80 && weatherCode <= 82) || // Rain showers
        (weatherCode >= 61 && weatherCode <= 67); // Rain
  }

  String _getWeatherIcon(int weatherCode) {
    if (weatherCode >= 95) return '⛈️';
    if (weatherCode >= 80) return '🌧️';
    if (weatherCode >= 71) return '🌨️';
    if (weatherCode >= 61) return '🌧️';
    if (weatherCode >= 51) return '🌦️';
    if (weatherCode >= 45) return '🌫️';
    if (weatherCode >= 3) return '☁️';
    if (weatherCode >= 1) return '⛅';
    return '☀️';
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  Future<void> _initializeRouting() async {
    await RoutingService.initialize();
  }

  Future<void> _checkMLStatus() async {
    // Check if ML models are initialized (from storm scenario)
    if (MLPredictionService.isReady) {
      setState(() => _isMLActive = true);
      _calculateFloodRisk();
    } else {
      // Try to check scenario status
      final status = await ScenarioService.checkScenarioStatus();
      if (status.active) {
        await MLPredictionService.initialize();
        if (mounted) {
          setState(() => _isMLActive = true);
          _calculateFloodRisk();
        }
      }
    }
  }

  Future<void> _calculateFloodRisk() async {
    if (!_isMLActive) return;

    setState(() => _isCalculatingRisk = true);

    try {
      // Get current weather/scenario data to determine rainfall
      // For now, use storm scenario rainfall (125mm - peak intensity)
      final prediction = await MLPredictionService.predictForStorm(
        rainfall: 125.0, // Peak storm rainfall
        elevation: 100.0, // Can be customized based on location
        slope: 5.0,
        flowAccumulation: 1000.0,
        distanceToWater: 500.0,
        population: 1000.0,
      );

      if (prediction != null && mounted) {
        setState(() {
          _currentPrediction = prediction;
          _isCalculatingRisk = false;
        });
        _updateFloodZones();
      }
    } catch (e) {
      print('Error calculating flood risk: $e');
      if (mounted) {
        setState(() => _isCalculatingRisk = false);
      }
    }
  }

  void _updateFloodZones() {
    if (_currentPrediction == null) return;

    // Clear existing circles
    _circles.clear();

    // Create new flood zones based on ML predictions
    final floodZones = [
      const LatLng(14.6000, 120.9870),
      const LatLng(14.6030, 120.9900),
      const LatLng(14.5990, 120.9930),
    ];

    Color zoneColor;
    double radius;

    // Adjust zone color and size based on risk level
    switch (_currentPrediction!.riskLevel) {
      case 'CRITICAL':
        zoneColor = Colors.red;
        radius = 500.0;
        break;
      case 'HIGH':
        zoneColor = Colors.orange;
        radius = 400.0;
        break;
      case 'MODERATE':
        zoneColor = Colors.yellow;
        radius = 300.0;
        break;
      default:
        zoneColor = Colors.blue;
        radius = 200.0;
    }

    for (int i = 0; i < floodZones.length; i++) {
      _circles.add(
        CircleMarker(
          point: floodZones[i],
          radius: radius,
          color: zoneColor.withOpacity(0.3),
          borderColor: zoneColor.withOpacity(0.6),
          borderStrokeWidth: 2,
          useRadiusInMeter: true,
        ),
      );
    }

    setState(() {});
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController?.move(_currentLocation, 14);
    } catch (e) {
      // Use default location if getting current location fails
    }
  }

  void _createMarkers() {
    _markers.clear();
    for (var location in _emergencyLocations) {
      _markers.add(
        Marker(
          point: location.position,
          width: 36,
          height: 36,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: location.color,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBackgroundDeep.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                location.icon,
                color: location.color,
                size: 18,
              ),
            ),
          ),
        ),
      );
    }
  }

  void _createFloodZones() {
    // Define flood zones as circles
    final floodZones = [
      const LatLng(14.6000, 120.9870),
      const LatLng(14.6030, 120.9900),
      const LatLng(14.5990, 120.9930),
    ];

    for (int i = 0; i < floodZones.length; i++) {
      _circles.add(
        CircleMarker(
          point: floodZones[i],
          radius: 300, // 300 meters
          color: AppColors.floodZoneRed.withOpacity(0.3),
          borderColor: AppColors.floodZoneRed.withOpacity(0.6),
          borderStrokeWidth: 2,
          useRadiusInMeter: true,
        ),
      );
    }
  }

  void _recenterMap() {
    _mapController?.move(_currentLocation, 14);
  }

  Future<void> _selectLocation(EmergencyLocation location) async {
    setState(() {
      _selectedDestination = location;
      _isCalculatingRoute = true;
    });

    // Move camera to show the selected location
    _mapController?.move(location.position, 15);

    // Calculate route from current location to selected destination
    await _calculateRoutes(_currentLocation, location.position);
  }

  Future<void> _navigateToSearchResult(SearchResult result) async {
    setState(() {
      _searchDestination = result;
      _selectedDestination = null; // Clear emergency destination
      _isCalculatingRoute = true;
    });

    // Move camera to show the selected location
    _mapController?.move(result.position, 15);

    // Calculate route from current location to search result
    await _calculateRoutes(_currentLocation, result.position);
  }

  Future<void> _calculateRoutes(LatLng start, LatLng end) async {
    try {
      // Check cache first
      final cachedRoute = await _cacheService.getCachedRoute(start, end);
      
      if (cachedRoute != null) {
        debugPrint('📦 Using cached route');
        final coordinates = cachedRoute['coordinates'] as List<LatLng>;
        
        _routeLines.clear();
        _routeLines.add(
          Polyline(
            points: coordinates,
            color: Colors.blue,
            strokeWidth: 5.0,
          ),
        );
        
        setState(() {
          _selectedRoute = RouteResult(
            coordinates: coordinates,
            distanceKm: cachedRoute['distance'] as double,
            durationMinutes: cachedRoute['duration'] as double,
            averageFloodRisk: 0.1,
          );
          _isCalculatingRoute = false;
        });
        
        _zoomToRoute(coordinates);
        return;
      }
      
      // Fetch from network
      final routes = await RoutingService.findAlternativeRoutes(
        start: start,
        destination: end,
      );

      if (routes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No routes found between these locations'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() => _isCalculatingRoute = false);
        return;
      }

      // Cache the primary route for offline use
      final primaryRoute = routes[0];
      await _cacheService.cacheRoute(
        start: start,
        end: end,
        coordinates: primaryRoute.coordinates,
        distance: primaryRoute.distanceKm,
        duration: primaryRoute.durationMinutes,
      );
      debugPrint('💾 Cached route for offline use');

      // Convert routes to polylines
      _routeLines.clear();
      for (var i = 0; i < routes.length; i++) {
        final route = routes[i];
        final color = _getRouteColor(route.riskLevel, i);

        _routeLines.add(
          Polyline(
            points: route.coordinates,
            color: color,
            strokeWidth: i == 0 ? 5.0 : 3.0, // Highlight first route
          ),
        );
      }

      setState(() {
        _selectedRoute = routes[0]; // Select safest/fastest route
        _isCalculatingRoute = false;
      });

      // Zoom to show entire route
      _zoomToRoute(routes[0].coordinates);
    } catch (e) {
      print('Error calculating routes: $e');
      
      // Try to use cached route as fallback
      final cachedRoute = await _cacheService.getCachedRoute(start, end);
      if (cachedRoute != null) {
        debugPrint('📦 Using cached route as fallback');
        final coordinates = cachedRoute['coordinates'] as List<LatLng>;
        
        _routeLines.clear();
        _routeLines.add(
          Polyline(
            points: coordinates,
            color: Colors.blue,
            strokeWidth: 5.0,
          ),
        );
        
        setState(() {
          _selectedRoute = RouteResult(
            coordinates: coordinates,
            distanceKm: cachedRoute['distance'] as double,
            durationMinutes: cachedRoute['duration'] as double,
            averageFloodRisk: 0.1,
          );
          _isCalculatingRoute = false;
        });
        
        _zoomToRoute(coordinates);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Using cached route (offline mode)'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error calculating route: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      setState(() => _isCalculatingRoute = false);
    }
  }

  Color _getRouteColor(String riskLevel, int routeIndex) {
    // First route: by risk level
    // Subsequent routes: muted colors
    if (routeIndex == 0) {
      switch (riskLevel) {
        case 'CRITICAL':
          return Colors.red;
        case 'HIGH':
          return Colors.orange;
        case 'MODERATE':
          return Colors.yellow.shade700;
        default:
          return Colors.green;
      }
    } else {
      return Colors.blue.withOpacity(0.5);
    }
  }

  void _zoomToRoute(List<LatLng> coordinates) {
    if (coordinates.isEmpty) return;

    // Calculate bounds
    double minLat = coordinates[0].latitude;
    double maxLat = coordinates[0].latitude;
    double minLng = coordinates[0].longitude;
    double maxLng = coordinates[0].longitude;

    for (var point in coordinates) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;
    final center = LatLng(centerLat, centerLng);

    // Calculate appropriate zoom level
    final latDiff = maxLat - minLat;
    final lngDiff = maxLng - minLng;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    double zoom = 14;
    if (maxDiff > 0.5) {
      zoom = 10;
    } else if (maxDiff > 0.2) {
      zoom = 11;
    } else if (maxDiff > 0.1) {
      zoom = 12;
    } else if (maxDiff > 0.05) {
      zoom = 13;
    }

    _mapController?.move(center, zoom);
  }

  void _clearRoute() {
    setState(() {
      _selectedRoute = null;
      _selectedDestination = null;
      _routeLines.clear();
    });
  }

  // Telephony instance for SMS
  final Telephony _telephony = Telephony.instance;

  // Send SOS SMS
  Future<void> _sendSOS(String phone, String message) async {
    bool? permissionsGranted = await _telephony.requestSmsPermissions;

    if (permissionsGranted ?? false) {
      try {
        await _telephony.sendSms(to: phone, message: message);
        debugPrint('✅ SOS SMS sent to $phone!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('SOS sent successfully to $phone'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Failed to send SMS: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send SOS: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      debugPrint('❌ SMS permission denied');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission denied. Please enable it in settings.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _onSOSConfirmed() async {
    setState(() {
      _isSOSActive = true;
    });

    final lat = _currentLocation?.latitude ?? 15.0794;
    final lng = _currentLocation?.longitude ?? 120.6200;

    const String phone = "09925377030";
    final String message = 'ENAV|SOS|$lat|$lng|$phone|flood|.5';

    await _sendSOS(phone, message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode
          ? AppColors.darkBackgroundDeep
          : AppColors.lightBackgroundPrimary,
      body: Stack(
        children: [
          // OpenStreetMap using flutter_map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultLocation,
              initialZoom: 14,
              minZoom: 5,
              maxZoom: 18,
            ),
            children: [
              // OSM Tile Layer with offline caching
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bagabugs.bantaybayan',
                maxZoom: 19,
                tileProvider: CachedTileProvider(),
              ),
              // Flood zone circles (current + forecast)
              CircleLayer(
                circles: [..._circles, ..._forecastFloodZones],
              ),
              // Route polylines
              PolylineLayer(
                polylines: _routeLines,
              ),
              // Emergency location markers
              MarkerLayer(
                markers: _markers,
              ),
              // Search destination marker
              if (_searchDestination != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _searchDestination!.position,
                      width: 50,
                      height: 50,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _searchDestination!.color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.darkBackgroundDeep.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _searchDestination!.icon,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Search bar (full width, lower position)
          Positioned(
            left: 0,
            right: 0,
            top: 100,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkBackgroundElevated : Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () async {
                  final result = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (context) => _SearchDialog(
                      emergencyLocations: _emergencyLocations,
                      isDarkMode: isDarkMode,
                      currentLocation: _currentLocation,
                      cacheService: _cacheService,
                    ),
                  );
                  
                  if (result != null) {
                    if (result['type'] == 'emergency') {
                      // Emergency location selected
                      final location = result['location'] as EmergencyLocation;
                      await _selectLocation(location);
                    } else if (result['type'] == 'search') {
                      // Search result selected - navigate to it
                      final searchResult = result['result'] as SearchResult;
                      await _navigateToSearchResult(searchResult);
                    }
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.search, color: isDarkMode ? Colors.white70 : Colors.grey[600], size: 22),
                    const SizedBox(width: 14),
                    Text(
                      'Search any location...',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        color: isDarkMode ? Colors.white54 : Colors.grey[500],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Route info card (if route is calculated)
          if (_selectedRoute != null)
            Positioned(
              top: 180, // Below search bar
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkBackgroundElevated : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.route,
                          color: _getRouteColor(_selectedRoute!.riskLevel, 0),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedDestination?.name ?? _searchDestination?.name ?? 'Route',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                '${_selectedRoute!.distanceKm.toStringAsFixed(1)} km',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: isDarkMode ? Colors.white70 : Colors.black54),
                          onPressed: _clearRoute,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getRouteColor(_selectedRoute!.riskLevel, 0)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getRouteColor(_selectedRoute!.riskLevel, 0),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: _getRouteColor(_selectedRoute!.riskLevel, 0),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _selectedRoute!.riskLevel,
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getRouteColor(_selectedRoute!.riskLevel, 0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Flood Risk: ${(_selectedRoute!.averageFloodRisk * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Loading indicator (if calculating route)
          if (_isCalculatingRoute)
            Positioned(
              top: 180,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkBackgroundElevated : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDarkMode ? Colors.white : AppColors.darkBackgroundDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Calculating route...',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Legend box (bottom left, above SOS)
          Positioned(
            left: 16,
            bottom: 110,
            child: Container(
              width: 110,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkBackgroundMid : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : AppColors.darkBackgroundDeep.withOpacity(0.05),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkBackgroundDeep.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Forecast Prediction for selected day
                  if (_weatherForecast != null && _weatherForecast!.forecast.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final day = _weatherForecast!.forecast[_selectedForecastDay];
                        final date = DateTime.parse(day.date);
                        final dayName = _selectedForecastDay == 0 
                            ? 'Today' 
                            : _selectedForecastDay == 1 
                                ? 'Tomorrow'
                                : '${_getDayName(date.weekday)}';
                        final hasStorm = _isStormyWeather(day.weatherCode) || day.precipitation > 20;
                        final riskColor = hasStorm 
                            ? (day.precipitation > 50 ? Colors.red : Colors.orange)
                            : Colors.green;
                        final riskLevel = day.precipitation > 50 
                            ? 'HIGH' 
                            : day.precipitation > 20 
                                ? 'MODERATE' 
                                : 'LOW';
                        
                        return GestureDetector(
                          onTap: _calculateForecastPrediction,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: riskColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: riskColor.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _getWeatherIcon(day.weatherCode),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        '$dayName',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                          color: riskColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: riskColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(
                                        riskLevel,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 8,
                                          color: riskColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.water_drop, size: 8, color: Colors.blue[600]),
                                    const SizedBox(width: 1),
                                    Text(
                                      '${day.precipitation.toStringAsFixed(0)}mm',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontSize: 8,
                                      ),
                                    ),
                                  ],
                                ),
                                if (hasStorm) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to view details',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 9,
                                      color: isDarkMode ? Colors.white38 : Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 12),
                  ],
                  // Legacy ML Prediction info (if active and no forecast)
                  if (_weatherForecast == null && _isMLActive && _currentPrediction != null) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _getPredictionColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _getPredictionColor().withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 12,
                                color: _getPredictionColor(),
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  'ML Risk',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: _getPredictionColor(),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _currentPrediction!.riskLevelText,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(_currentPrediction!.probability * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  color: _getPredictionColor(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 6),
                  ],
                  if (_isCalculatingRisk) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Calculating risk...',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 12),
                  ],
                  _buildLegendItem(
                    color: AppColors.floodZoneRed,
                    label: 'Flood',
                    theme: theme,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 4),
                  _buildLegendItem(
                    color: _isSOSActive
                        ? const Color(0xFFFF6B6B)
                        : Colors.blueAccent,
                    label: 'You',
                    theme: theme,
                    isDarkMode: isDarkMode,
                    isBordered: true,
                  ),
                  const SizedBox(height: 4),
                  _buildLegendItem(
                    color: Colors.blue,
                    label: 'Hospital',
                    theme: theme,
                    isDarkMode: isDarkMode,
                    icon: Icons.local_hospital,
                  ),
                  const SizedBox(height: 4),
                  _buildLegendItem(
                    color: Colors.orange,
                    label: 'Shelter',
                    theme: theme,
                    isDarkMode: isDarkMode,
                    icon: Icons.family_restroom,
                  ),
                  const SizedBox(height: 4),
                  _buildLegendItem(
                    color: Colors.indigo,
                    label: 'Police',
                    theme: theme,
                    isDarkMode: isDarkMode,
                    icon: Icons.local_police,
                  ),
                ],
              ),
            ),
          ),

          // Recenter Button (bottom right, above SOS)
          Positioned(
            right: 16,
            bottom: 110,
            child: FloatingActionButton(
              heroTag: 'recenter_btn',
              onPressed: _recenterMap,
              backgroundColor: isDarkMode ? AppColors.darkBackgroundElevated : Colors.white,
              mini: true,
              child: Icon(
                Icons.my_location,
                color: isDarkMode ? Colors.white : AppColors.darkBackgroundDeep,
              ),
            ),
          ),

          // Weather Forecast Day Navigator (top center)
          if (_weatherForecast != null && _weatherForecast!.forecast.isNotEmpty)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: _buildDayNavigator(isDarkMode),
              ),
            ),

          // SOS Button (minimal, clean design)
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: _SOSButton(
              isDarkMode: isDarkMode,
              onSOSConfirmed: _onSOSConfirmed,
            ),
          ),

          // Top status bar (highest z-index)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkBackgroundDeep : Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : AppColors.darkBackgroundDeep.withOpacity(0.05),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkBackgroundDeep.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Offline indicator (icon only)
                    Icon(
                      Icons.wifi_off,
                      size: 20,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.5)
                          : AppColors.darkBackgroundDeep.withOpacity(0.5),
                    ),
                    const SizedBox(width: 12),
                    // GPS coordinates (stacked)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_currentLocation.latitude.toStringAsFixed(4)}° N',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '${_currentLocation.longitude.toStringAsFixed(4)}° E',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Profile dropdown
                    const ProfileDropdown(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required ThemeData theme,
    required bool isDarkMode,
    bool isBordered = false,
    IconData? icon,
  }) {
    return Row(
      children: [
        if (icon != null)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            child: Icon(icon, size: 8, color: color.withOpacity(0.7)),
          )
        else
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.2)
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isBordered
                      ? Border.all(color: Colors.white, width: 1)
                      : null,
                ),
              ),
            ),
          ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: isDarkMode
                ? Colors.white.withOpacity(0.8)
                : Colors.black.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Color _getPredictionColor() {
    if (_currentPrediction == null) return Colors.grey;
    switch (_currentPrediction!.riskLevel) {
      case 'CRITICAL':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'MODERATE':
        return Colors.yellow.shade700;
      default:
        return Colors.green;
    }
  }

  Widget _buildDayNavigator(bool isDarkMode) {
    final day = _weatherForecast!.forecast[_selectedForecastDay];
    final date = DateTime.parse(day.date);
    final dayName = _selectedForecastDay == 0 
        ? 'Today' 
        : _selectedForecastDay == 1 
            ? 'Tmrw'
            : _getDayName(date.weekday);
    final hasStorm = _isStormyWeather(day.weatherCode) || day.precipitation > 20;
    
    return GestureDetector(
      onTap: _calculateForecastPrediction,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[900]!.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: hasStorm ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left arrow
            GestureDetector(
              onTap: _selectedForecastDay > 0 
                  ? () {
                      setState(() {
                        _selectedForecastDay--;
                        _forecastPrediction = null;
                      });
                      _updateForecastFloodZones();
                    }
                  : null,
              child: Icon(
                Icons.chevron_left,
                size: 24,
                color: _selectedForecastDay > 0 
                    ? (isDarkMode ? Colors.white : Colors.black87)
                    : (isDarkMode ? Colors.grey[700] : Colors.grey[300]),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Day info
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getWeatherIcon(day.weatherCode),
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Text(
                  dayName,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasStorm 
                        ? Colors.red[700]
                        : (isDarkMode ? Colors.white : AppColors.lightTextPrimary),
                  ),
                ),
                if (day.precipitation > 0) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.water_drop, size: 12, color: Colors.blue[600]),
                  Text(
                    '${day.precipitation.toStringAsFixed(0)}mm',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.blue[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            
            const SizedBox(width: 8),
            
            // Right arrow
            GestureDetector(
              onTap: _selectedForecastDay < _weatherForecast!.forecast.length - 1 
                  ? () {
                      setState(() {
                        _selectedForecastDay++;
                        _forecastPrediction = null;
                      });
                      _updateForecastFloodZones();
                    }
                  : null,
              child: Icon(
                Icons.chevron_right,
                size: 24,
                color: _selectedForecastDay < _weatherForecast!.forecast.length - 1 
                    ? (isDarkMode ? Colors.white : Colors.black87)
                    : (isDarkMode ? Colors.grey[700] : Colors.grey[300]),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

enum EmergencyLocationType {
  evacuationCenter,
  medicalStation,
  policeStation,
  reliefCenter,
  hospital,
}

// Emergency location model
class EmergencyLocation {
  final String name;
  final LatLng position;
  final EmergencyLocationType type;

  const EmergencyLocation({
    required this.name,
    required this.position,
    required this.type,
  });

  Color get color {
    switch (type) {
      case EmergencyLocationType.evacuationCenter:
        return Colors.orange;
      case EmergencyLocationType.medicalStation:
      case EmergencyLocationType.hospital:
        return Colors.blue;
      case EmergencyLocationType.policeStation:
        return Colors.indigo;
      case EmergencyLocationType.reliefCenter:
        return Colors.green;
    }
  }

  IconData get icon {
    switch (type) {
      case EmergencyLocationType.evacuationCenter:
        return Icons.family_restroom;
      case EmergencyLocationType.medicalStation:
      case EmergencyLocationType.hospital:
        return Icons.local_hospital;
      case EmergencyLocationType.policeStation:
        return Icons.local_police;
      case EmergencyLocationType.reliefCenter:
        return Icons.volunteer_activism;
    }
  }
}

// Search result model for real locations
class SearchResult {
  final String name;
  final String displayName;
  final LatLng position;
  final String type;

  const SearchResult({
    required this.name,
    required this.displayName,
    required this.position,
    required this.type,
  });

  IconData get icon {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('hospital') || lowerType.contains('clinic') || lowerType.contains('medical')) {
      return Icons.local_hospital;
    } else if (lowerType.contains('police') || lowerType.contains('station')) {
      return Icons.local_police;
    } else if (lowerType.contains('school') || lowerType.contains('university')) {
      return Icons.school;
    } else if (lowerType.contains('restaurant') || lowerType.contains('food')) {
      return Icons.restaurant;
    } else if (lowerType.contains('shop') || lowerType.contains('store') || lowerType.contains('mall')) {
      return Icons.store;
    } else if (lowerType.contains('church') || lowerType.contains('mosque') || lowerType.contains('temple')) {
      return Icons.church;
    } else if (lowerType.contains('park') || lowerType.contains('garden')) {
      return Icons.park;
    } else if (lowerType.contains('gas') || lowerType.contains('fuel')) {
      return Icons.local_gas_station;
    } else if (lowerType.contains('bank') || lowerType.contains('atm')) {
      return Icons.account_balance;
    } else if (lowerType.contains('pharmacy') || lowerType.contains('drug')) {
      return Icons.local_pharmacy;
    } else if (lowerType.contains('hotel') || lowerType.contains('inn') || lowerType.contains('lodge')) {
      return Icons.hotel;
    } else if (lowerType.contains('bus') || lowerType.contains('terminal')) {
      return Icons.directions_bus;
    } else if (lowerType.contains('airport')) {
      return Icons.flight;
    } else if (lowerType.contains('barangay') || lowerType.contains('government') || lowerType.contains('municipal')) {
      return Icons.account_balance;
    }
    return Icons.location_on;
  }

  Color get color {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('hospital') || lowerType.contains('clinic') || lowerType.contains('medical') || lowerType.contains('pharmacy')) {
      return Colors.blue;
    } else if (lowerType.contains('police')) {
      return Colors.indigo;
    } else if (lowerType.contains('school') || lowerType.contains('university')) {
      return Colors.purple;
    } else if (lowerType.contains('restaurant') || lowerType.contains('food')) {
      return Colors.orange;
    } else if (lowerType.contains('shop') || lowerType.contains('store') || lowerType.contains('mall')) {
      return Colors.teal;
    } else if (lowerType.contains('church') || lowerType.contains('mosque') || lowerType.contains('temple')) {
      return Colors.brown;
    } else if (lowerType.contains('park') || lowerType.contains('garden')) {
      return Colors.green;
    } else if (lowerType.contains('barangay') || lowerType.contains('government') || lowerType.contains('municipal')) {
      return Colors.red;
    }
    return Colors.grey;
  }
}

// Search dialog with real location search
class _SearchDialog extends StatefulWidget {
  final List<EmergencyLocation> emergencyLocations;
  final bool isDarkMode;
  final LatLng currentLocation;
  final OfflineCacheService cacheService;

  const _SearchDialog({
    required this.emergencyLocations,
    required this.isDarkMode,
    required this.currentLocation,
    required this.cacheService,
  });

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final TextEditingController _controller = TextEditingController();
  List<SearchResult> _searchResults = [];
  List<EmergencyLocation> _emergencyResults = [];
  bool _isSearching = false;
  bool _isOffline = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _emergencyResults = widget.emergencyLocations;
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _searchLocations(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _emergencyResults = widget.emergencyLocations;
        _isSearching = false;
        _isOffline = false;
      });
      return;
    }

    // Filter emergency locations
    _emergencyResults = widget.emergencyLocations
        .where((loc) => loc.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    setState(() => _isSearching = true);

    try {
      // Try to get cached results first for instant results
      final cachedResults = await widget.cacheService.getCachedSearchResults(query);
      
      // Search using Nominatim API (OpenStreetMap)
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&limit=10'
        '&viewbox=${widget.currentLocation.longitude - 0.5},${widget.currentLocation.latitude + 0.5},${widget.currentLocation.longitude + 0.5},${widget.currentLocation.latitude - 0.5}'
        '&bounded=0'
        '&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'BantayBayan-App/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        final results = data.map((item) {
          return SearchResult(
            name: item['name'] ?? item['display_name']?.split(',')[0] ?? 'Unknown',
            displayName: item['display_name'] ?? '',
            position: LatLng(
              double.parse(item['lat']),
              double.parse(item['lon']),
            ),
            type: item['type'] ?? item['class'] ?? 'place',
          );
        }).toList();
        
        // Cache the results for offline use
        await widget.cacheService.cacheSearchResults(
          query,
          results.map((r) => {
            'name': r.name,
            'displayName': r.displayName,
            'lat': r.position.latitude,
            'lng': r.position.longitude,
            'type': r.type,
          }).toList(),
        );
        
        // Also cache as landmarks for future offline search
        await widget.cacheService.cacheLandmarks(
          results.map((r) => {
            'name': r.name,
            'display_name': r.displayName,
            'latitude': r.position.latitude,
            'longitude': r.position.longitude,
            'type': r.type,
          }).toList(),
        );
        
        setState(() {
          _searchResults = results;
          _isSearching = false;
          _isOffline = false;
        });
      } else {
        // Use cached results if available
        if (cachedResults != null) {
          _useCachedResults(cachedResults);
        } else {
          await _searchOfflineLandmarks(query);
        }
      }
    } catch (e) {
      // Network error - try cached results or offline landmarks
      final cachedResults = await widget.cacheService.getCachedSearchResults(query);
      if (cachedResults != null) {
        _useCachedResults(cachedResults);
      } else {
        await _searchOfflineLandmarks(query);
      }
    }
  }
  
  void _useCachedResults(List<Map<String, dynamic>> cachedResults) {
    setState(() {
      _searchResults = cachedResults.map((item) => SearchResult(
        name: item['name'] ?? 'Unknown',
        displayName: item['displayName'] ?? '',
        position: LatLng(item['lat'], item['lng']),
        type: item['type'] ?? 'place',
      )).toList();
      _isSearching = false;
      _isOffline = true;
    });
  }
  
  Future<void> _searchOfflineLandmarks(String query) async {
    // Search cached landmarks
    final landmarks = await widget.cacheService.searchLandmarks(query);
    
    setState(() {
      _searchResults = landmarks.map((item) => SearchResult(
        name: item['name'] ?? 'Unknown',
        displayName: item['display_name'] ?? '',
        position: LatLng(item['latitude'], item['longitude']),
        type: item['type'] ?? 'place',
      )).toList();
      _isSearching = false;
      _isOffline = true;
    });
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchLocations(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDarkMode ? AppColors.darkBackgroundDeep : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                color: AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search any location...',
                hintStyle: GoogleFonts.montserrat(
                  fontSize: 15,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_controller.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[500]),
                            onPressed: () {
                              _controller.clear();
                              _searchLocations('');
                            },
                          )
                        : null),
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
            
            // Offline indicator
            if (_isOffline) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 14, color: Colors.orange[700]),
                    const SizedBox(width: 6),
                    Text(
                      'Showing cached results (offline)',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            
            // Emergency locations section
            if (_emergencyResults.isNotEmpty && _controller.text.isEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Emergency Locations',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: [
                  // Emergency locations (show when no search or matching)
                  if (_emergencyResults.isNotEmpty) ...[
                    ..._emergencyResults.map((location) => ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: location.color, width: 2),
                        ),
                        child: Icon(location.icon, size: 18, color: location.color),
                      ),
                      title: Text(
                        location.name,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        location.type.toString().split('.').last.replaceAll(RegExp(r'([A-Z])'), ' \$1').trim(),
                        style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[600]),
                      ),
                      trailing: Icon(Icons.directions, color: location.color, size: 20),
                      onTap: () => Navigator.pop(context, {'type': 'emergency', 'location': location}),
                    )),
                  ],
                  
                  // Search results separator
                  if (_searchResults.isNotEmpty && _controller.text.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Search Results',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // Real location search results
                  ..._searchResults.map((result) => ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: result.color.withOpacity(0.5), width: 2),
                      ),
                      child: Icon(result.icon, size: 18, color: result.color),
                    ),
                    title: Text(
                      result.name,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      result.displayName,
                      style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(Icons.directions, color: result.color, size: 20),
                    onTap: () => Navigator.pop(context, {'type': 'search', 'result': result}),
                  )),
                  
                  // Empty state
                  if (_searchResults.isEmpty && _emergencyResults.isEmpty && _controller.text.isNotEmpty && !_isSearching)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            'No locations found',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SOS Button with pulsing animation (narrower height)
class _SOSButton extends StatelessWidget {
  final bool isDarkMode;
  final VoidCallback onSOSConfirmed;

  const _SOSButton({required this.isDarkMode, required this.onSOSConfirmed});

  Future<void> _showSOSModal(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const SOSConfirmationModal(),
    );

    if (result == true) {
      onSOSConfirmed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFFFF6B6B),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showSOSModal(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SOS',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.white.withOpacity(0.4),
                ),
                const SizedBox(width: 12),
                Text(
                  'Emergency Assistance',
                  style: GoogleFonts.montserrat(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
