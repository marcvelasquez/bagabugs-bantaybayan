import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../core/theme/theme_provider.dart';
import '../core/theme/colors.dart';
import '../services/api_service.dart';
import '../services/cached_tile_provider.dart';
import '../models/api_models.dart';

class SituationScreen extends StatefulWidget {
  const SituationScreen({super.key});

  @override
  State<SituationScreen> createState() => _SituationScreenState();
}

class _SituationScreenState extends State<SituationScreen> {
  MapController? _mapController;
  final List<Marker> _markers = [];
  final List<CircleMarker> _circles = [];
  LatLng? _userPinLocation;
  ReportStats? _reportStats;
  bool _isLoadingStats = false;
  List<ReportModel> _allReports = [];
  WeatherModel? _currentWeather;

  // Default location (Manila, Philippines)
  static const LatLng _defaultLocation = LatLng(14.5995, 120.9842);
  LatLng _currentLocation = _defaultLocation;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
    _loadReportStats();
    _loadReports();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      final weather = await ApiService.getCurrentWeather(
        latitude: _currentLocation.latitude,
        longitude: _currentLocation.longitude,
      );
      setState(() {
        _currentWeather = weather;
      });
    } catch (e) {
      debugPrint('❌ Failed to load weather: $e');
    }
  }

  Future<void> _loadReports() async {
    try {
      debugPrint('🔄 Loading reports from API...');
      final reports = await ApiService.getReports();
      debugPrint('✅ Loaded ${reports.length} reports');
      setState(() {
        _allReports = reports;
      });
      _updateReportMarkers();
      
      if (reports.isEmpty) {
        debugPrint('ℹ️ No reports available (server may be offline)');
      }
    } catch (e) {
      debugPrint('❌ Failed to load reports: $e');
      // Set empty list to prevent UI issues
      setState(() {
        _allReports = [];
      });
      _updateReportMarkers();
    }
  }

  void _updateReportMarkers() {
    debugPrint('🗺️ Updating report markers for ${_allReports.length} reports');

    // Clear existing report markers/circles but keep user pin
    _markers.removeWhere((marker) => !(marker.point == _userPinLocation && _userPinLocation != null));
    _circles.clear();

    // Cluster reports by proximity
    final clusters = _clusterReports(_allReports);

    debugPrint('📍 Created ${clusters.length} clusters');

    // Create markers and circles for each cluster
    for (var cluster in clusters) {
      final opacity = _calculateOpacity(cluster.reports.length);
      final color = _getColorForType(cluster.incidentType);

      debugPrint(
        '  Cluster at ${cluster.center.latitude}, ${cluster.center.longitude}: ${cluster.reports.length} reports, opacity: $opacity',
      );

      // Add circle for affected area
      _circles.add(
        CircleMarker(
          point: cluster.center,
          radius:
              100 +
              (cluster.reports.length * 50.0), // Larger radius for more reports
          useRadiusInMeter: true,
          color: color.withOpacity(opacity * 0.3),
          borderColor: color.withOpacity(opacity),
          borderStrokeWidth: 2,
        ),
      );

      // Add marker
      _markers.add(
        Marker(
          point: cluster.center,
          width: 40,
          height: 40,
          child: Opacity(
            opacity: opacity,
            child: Icon(
              Icons.location_on,
              color: color,
              size: 40,
            ),
          ),
        ),
      );
    }

    debugPrint(
      '✅ Added ${_markers.length} markers and ${_circles.length} circles to map',
    );

    setState(() {});
  }

  List<ReportCluster> _clusterReports(List<ReportModel> reports) {
    if (reports.isEmpty) return [];

    final clusters = <ReportCluster>[];
    final processed = <int>{};

    for (var i = 0; i < reports.length; i++) {
      if (processed.contains(i)) continue;

      final centerReport = reports[i];
      final clusterReports = <ReportModel>[centerReport];
      processed.add(i);

      // Find nearby reports of the same type
      for (var j = i + 1; j < reports.length; j++) {
        if (processed.contains(j)) continue;

        final report = reports[j];
        final distance = _calculateDistance(
          centerReport.latitude,
          centerReport.longitude,
          report.latitude,
          report.longitude,
        );

        // Cluster if within 500 meters and same type
        if (distance < 500 &&
            report.incidentType == centerReport.incidentType) {
          clusterReports.add(report);
          processed.add(j);
        }
      }

      // Calculate cluster center
      final avgLat =
          clusterReports.map((r) => r.latitude).reduce((a, b) => a + b) /
          clusterReports.length;
      final avgLng =
          clusterReports.map((r) => r.longitude).reduce((a, b) => a + b) /
          clusterReports.length;

      clusters.add(
        ReportCluster(
          center: LatLng(avgLat, avgLng),
          reports: clusterReports,
          incidentType: centerReport.incidentType,
        ),
      );
    }

    return clusters;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742000 * math.asin(math.sqrt(a)); // 2 * R * asin... (in meters)
  }

  double _calculateOpacity(int reportCount) {
    // Map report count to opacity: 1 report = 0.3, 5+ reports = 1.0
    return (0.3 + (reportCount - 1) * 0.175).clamp(0.3, 1.0);
  }

  Color _getColorForType(IncidentType type) {
    switch (type) {
      case IncidentType.flood:
        return const Color(0xFF2196F3); // Blue for flood
      case IncidentType.evacuationCenter:
        return const Color(0xFFFF9800); // Orange for evacuation
      case IncidentType.emergencyServices:
        return const Color(0xFFFF6B6B); // Red for emergency
    }
  }

  Future<void> _loadReportStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final stats = await ApiService.getReportStats();
      setState(() {
        _reportStats = stats;
        _isLoadingStats = false;
      });
      
      // Only show message if stats are empty (server unavailable)
      if (stats.totalCount == 0 && mounted) {
        debugPrint('ℹ️ No reports available (server may be offline)');
      }
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
        // Set default stats to prevent UI issues
        _reportStats = ReportStats(infoCount: 0, criticalCount: 0, warningCount: 0, totalCount: 0, date: DateTime.now().toIso8601String());
      });
      debugPrint('⚠️ Stats loading failed: $e');
    }
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

  void _recenterMap() {
    if (_mapController != null) {
      _mapController!.move(_currentLocation, 14);
    }
  }

  void _onMapTapped(TapPosition tapPosition, LatLng position) {
    setState(() {
      // Remove previous pin if exists
      _markers.removeWhere((marker) => marker.point == _userPinLocation);

      // Add new pin
      _userPinLocation = position;
      _markers.add(
        Marker(
          point: position,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40,
          ),
        ),
      );
    });
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  IconData _getWeatherIcon(int weatherCode) {
    if (weatherCode == 0 || weatherCode == 1) {
      return Icons.wb_sunny;
    } else if (weatherCode == 2 || weatherCode == 3) {
      return Icons.wb_cloudy;
    } else if (weatherCode >= 51 && weatherCode <= 67) {
      return Icons.grain;
    } else if (weatherCode >= 61 && weatherCode <= 82) {
      return Icons.water_drop;
    } else if (weatherCode >= 95) {
      return Icons.flash_on;
    } else {
      return Icons.cloud;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackgroundDeep : Colors.white,
      body: Stack(
        children: [
          // OpenStreetMap with flutter_map - dark mode support
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultLocation,
              initialZoom: 14,
              onTap: _onMapTapped,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.baga_bugs_bantaybayan_client',
                tileProvider: CachedTileProvider(),
              ),
              CircleLayer(
                circles: _circles,
              ),
              MarkerLayer(
                markers: _markers,
              ),
            ],
          ),

          // Fixed UI overlay - Combined panel
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Single combined panel - theme aware
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDarkMode 
                              ? AppColors.darkBackgroundElevated.withOpacity(0.95)
                              : Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with loading button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Active Reports',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (_isLoadingStats)
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                            isDarkMode ? Colors.white54 : Colors.grey[400]!,
                                          ),
                                    ),
                                  )
                                else
                                  GestureDetector(
                                    onTap: () {
                                      _loadReportStats();
                                      _loadReports();
                                    },
                                    child: Icon(
                                      Icons.refresh,
                                      size: 18,
                                      color: isDarkMode ? Colors.white70 : Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: _StatBox(
                                    label: 'Info',
                                    count: _reportStats?.infoCount ?? 0,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 1,
                                  child: _StatBox(
                                    label: 'Critical',
                                    count:
                                        _reportStats?.criticalCount ?? 0,
                                    color: Color(0xFFFF6B6B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  flex: 1,
                                  child: _StatBox(
                                    label: 'Warning',
                                    count:
                                        _reportStats?.warningCount ?? 0,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Report button at bottom (only show if pin is placed)
                if (_userPinLocation != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: _ReportButton(location: _userPinLocation!),
                  ),
              ],
            ),
          ),

          // Recenter Button (bottom right)
          Positioned(
            right: 16,
            bottom: 20,
            child: FloatingActionButton(
              heroTag: 'situation_recenter_btn',
              onPressed: _recenterMap,
              backgroundColor: isDarkMode ? AppColors.darkBackgroundElevated : Colors.white,
              mini: true,
              elevation: 4,
              child: Icon(Icons.my_location, color: isDarkMode ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBox({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: GoogleFonts.montserrat(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ReportButton extends StatefulWidget {
  final LatLng location;

  const _ReportButton({required this.location});

  @override
  State<_ReportButton> createState() => _ReportButtonState();
}

class _ReportButtonState extends State<_ReportButton> {
  List<ReportModel> _nearbyReports = [];
  bool _isCheckingNearby = false;

  @override
  void initState() {
    super.initState();
    _checkNearbyReports();
  }

  @override
  void didUpdateWidget(_ReportButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check when location changes
    if (oldWidget.location != widget.location) {
      debugPrint('🔄 Pin location changed, re-checking nearby reports...');
      _checkNearbyReports();
    }
  }

  Future<void> _checkNearbyReports() async {
    debugPrint(
      '🔍 Checking for nearby reports at (${widget.location.latitude}, ${widget.location.longitude})',
    );
    setState(() => _isCheckingNearby = true);
    try {
      final nearby = await ApiService.getNearbyReports(
        latitude: widget.location.latitude,
        longitude: widget.location.longitude,
        radius: 500.0, // 500 meters for easier testing
      );
      debugPrint('✅ Found ${nearby.length} nearby reports');
      setState(() {
        _nearbyReports = nearby;
        _isCheckingNearby = false;
      });
    } catch (e) {
      debugPrint('❌ Error checking nearby reports: $e');
      setState(() => _isCheckingNearby = false);
    }
  }

  Future<void> _showReportModal() async {
    await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _ReportIncidentModal(location: widget.location),
    );
  }

  Future<void> _showNearbyReportsDialog() async {
    await showDialog(
      context: context,
      builder: (context) => _NearbyReportsDialog(
        location: widget.location,
        nearbyReports: _nearbyReports,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingNearby) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Checking area...',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // If there are nearby reports, show upvote option
    if (_nearbyReports.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Material(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: _showNearbyReportsDialog,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.thumb_up, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    '${_nearbyReports.length} Report${_nearbyReports.length > 1 ? 's' : ''} Nearby - Upvote?',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // No nearby reports, show normal report button
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _showReportModal,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_alert, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Report Incident',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

class _ReportIncidentModal extends StatefulWidget {
  final LatLng location;

  const _ReportIncidentModal({required this.location});

  @override
  State<_ReportIncidentModal> createState() => _ReportIncidentModalState();
}

class _ReportIncidentModalState extends State<_ReportIncidentModal> {
  String? _selectedType;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Flood':
        return const Color(0xFF2196F3); // Blue
      case 'Evacuation Center':
        return const Color(0xFFFF9800); // Orange
      case 'Emergency Services':
        return const Color(0xFFFF6B6B); // Red
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black87.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.add_alert,
                      color: Colors.black87,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report Incident',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Help keep your community safe',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Incident Type',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: ['Flood', 'Evacuation Center', 'Emergency Services'].map((type) {
                  final isSelected = _selectedType == type;
                  final color = _getTypeColor(type);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedType = type),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withOpacity(0.15)
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                type == 'Flood'
                                    ? Icons.water_drop
                                    : type == 'Evacuation Center'
                                    ? Icons.family_restroom
                                    : Icons.emergency,
                                color: isSelected ? color : Colors.grey[600],
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                type == 'Evacuation Center' ? 'Evacuation' : (type == 'Emergency Services' ? 'Emergency' : type),
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected ? color : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text(
                'Description (Optional)',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Describe what happened...',
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedType == null
                          ? null
                          : () async {
                              // Handle report submission
                              Navigator.pop(context);

                              // Show loading
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Submitting report...',
                                        style: GoogleFonts.montserrat(),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.black87,
                                  duration: const Duration(seconds: 2),
                                ),
                              );

                              try {
                                // Convert type to IncidentType enum
                                IncidentType incidentType;
                                switch (_selectedType) {
                                  case 'Flood':
                                    incidentType = IncidentType.flood;
                                    break;
                                  case 'Evacuation Center':
                                    incidentType = IncidentType.evacuationCenter;
                                    break;
                                  case 'Emergency Services':
                                  default:
                                    incidentType = IncidentType.emergencyServices;
                                }

                                // Create report
                                final report = ReportModel(
                                  incidentType: incidentType,
                                  latitude: widget.location.latitude,
                                  longitude: widget.location.longitude,
                                  description:
                                      _descriptionController.text.isEmpty
                                      ? null
                                      : _descriptionController.text,
                                );

                                await ApiService.createReport(report);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Report submitted successfully',
                                      style: GoogleFonts.montserrat(),
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );

                                // Reload stats and reports after successful submission
                                if (context.mounted) {
                                  final situationScreenState = context
                                      .findAncestorStateOfType<
                                        _SituationScreenState
                                      >();
                                  situationScreenState?._loadReportStats();
                                  situationScreenState?._loadReports();
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to submit report: $e',
                                      style: GoogleFonts.montserrat(),
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: Text(
                        'Submit',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Location info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lat: ${widget.location.latitude.toStringAsFixed(6)}, Lng: ${widget.location.longitude.toStringAsFixed(6)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Nearby reports dialog widget
class _NearbyReportsDialog extends StatefulWidget {
  final LatLng location;
  final List<ReportModel> nearbyReports;

  const _NearbyReportsDialog({
    required this.location,
    required this.nearbyReports,
  });

  @override
  State<_NearbyReportsDialog> createState() => _NearbyReportsDialogState();
}

class _NearbyReportsDialogState extends State<_NearbyReportsDialog> {
  final Set<int> _upvotedReports = {};
  final Map<int, int> _reportUpvoteCounts = {};

  @override
  void initState() {
    super.initState();
    // Initialize upvote counts
    for (var report in widget.nearbyReports) {
      _reportUpvoteCounts[report.id!] = report.upvoteCount;
    }
  }

  Future<void> _handleUpvote(ReportModel report) async {
    final reportId = report.id!;

    try {
      await ApiService.upvoteReport(reportId);
      setState(() {
        _upvotedReports.add(reportId);
        _reportUpvoteCounts[reportId] =
            (_reportUpvoteCounts[reportId] ?? 0) + 1;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upvoted report successfully!',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('already upvoted')
                  ? 'You already upvoted this report'
                  : 'Failed to upvote: ${e.toString()}',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _createNewReport() async {
    Navigator.pop(context);
    await showDialog(
      context: context,
      builder: (context) => _ReportIncidentModal(location: widget.location),
    );
  }

  Color _getIncidentColor(IncidentType type) {
    switch (type) {
      case IncidentType.flood:
        return const Color(0xFF2196F3); // Blue
      case IncidentType.evacuationCenter:
        return const Color(0xFFFF9800); // Orange
      case IncidentType.emergencyServices:
        return const Color(0xFFFF6B6B); // Red
    }
  }

  IconData _getIncidentIcon(IncidentType type) {
    switch (type) {
      case IncidentType.flood:
        return Icons.water_drop;
      case IncidentType.evacuationCenter:
        return Icons.family_restroom;
      case IncidentType.emergencyServices:
        return Icons.emergency;
    }
  }

  String _getIncidentLabel(IncidentType type) {
    switch (type) {
      case IncidentType.flood:
        return 'Flood';
      case IncidentType.evacuationCenter:
        return 'Evacuation';
      case IncidentType.emergencyServices:
        return 'Emergency';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nearby Reports',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${widget.nearbyReports.length} report${widget.nearbyReports.length > 1 ? 's' : ''} within 100m',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.nearbyReports.length,
                itemBuilder: (context, index) {
                  final report = widget.nearbyReports[index];
                  final reportId = report.id!;
                  final isUpvoted = _upvotedReports.contains(reportId);
                  final upvoteCount =
                      _reportUpvoteCounts[reportId] ?? report.upvoteCount;
                  final color = _getIncidentColor(report.incidentType);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withOpacity(0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            _getIncidentIcon(report.incidentType),
                            color: color,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getIncidentLabel(report.incidentType),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (report.description != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    report.description!,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            children: [
                              IconButton(
                                onPressed: isUpvoted
                                    ? null
                                    : () => _handleUpvote(report),
                                icon: Icon(
                                  isUpvoted
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_outlined,
                                  color: isUpvoted ? color : Colors.grey[600],
                                  size: 20,
                                ),
                                tooltip: isUpvoted
                                    ? 'Already upvoted'
                                    : 'Upvote',
                              ),
                              Text(
                                '$upvoteCount',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _createNewReport,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Create New',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class for clustering reports
class ReportCluster {
  final LatLng center;
  final List<ReportModel> reports;
  final IncidentType incidentType;

  ReportCluster({
    required this.center,
    required this.reports,
    required this.incidentType,
  });
}
