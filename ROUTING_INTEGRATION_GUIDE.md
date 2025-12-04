# Routing Integration Guide

## Quick Start: Add Route Display to Map

### Step 1: Add Routing Service to map_screen.dart

```dart
import '../services/routing_service.dart';

class _MapScreenState extends State<MapScreen> {
  // Add routing state
  List<Polyline> _routeLines = [];
  RouteResult? _selectedRoute;
  bool _isCalculatingRoute = false;
  
  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
    _createMarkers();
    _createFloodZones();
    _checkMLStatus();
    _initializeRouting(); // Add this
  }
  
  Future<void> _initializeRouting() async {
    await RoutingService.initialize();
  }
}
```

### Step 2: Add Route Calculation Function

```dart
Future<void> _calculateRoutes(LatLng start, LatLng end) async {
  setState(() => _isCalculatingRoute = true);
  
  try {
    final routes = await RoutingService.findAlternativeRoutes(
      start: start,
      end: end,
    );
    
    if (routes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No routes found')),
        );
      }
      return;
    }
    
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
  if (maxDiff > 0.5) zoom = 10;
  else if (maxDiff > 0.2) zoom = 11;
  else if (maxDiff > 0.1) zoom = 12;
  else if (maxDiff > 0.05) zoom = 13;
  
  _mapController?.move(center, zoom);
}
```

### Step 3: Update FlutterMap Widget

```dart
FlutterMap(
  mapController: _mapController,
  options: MapOptions(
    initialCenter: _defaultLocation,
    initialZoom: 14,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.bagabugs.bantaybayan',
    ),
    CircleLayer(circles: _circles),
    
    // ADD THIS: Route polylines
    PolylineLayer(polylines: _routeLines),
    
    MarkerLayer(markers: _markers),
  ],
)
```

### Step 4: Add Route Info Card

```dart
// In the Stack, add this positioned widget
if (_selectedRoute != null)
  Positioned(
    top: 180, // Below search bar
    left: 20,
    right: 20,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              ),
              const SizedBox(width: 8),
              Text(
                'Route: ${_selectedRoute!.distanceKm.toStringAsFixed(1)} km',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _selectedRoute = null;
                    _routeLines.clear();
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRouteColor(_selectedRoute!.riskLevel, 0)
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedRoute!.riskLevel,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getRouteColor(_selectedRoute!.riskLevel, 0),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Risk: ${(_selectedRoute!.averageFloodRisk * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.montserrat(fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    ),
  ),

// Add loading indicator
if (_isCalculatingRoute)
  Positioned(
    top: 180,
    left: 20,
    right: 20,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Calculating routes...',
            style: GoogleFonts.montserrat(fontSize: 14),
          ),
        ],
      ),
    ),
  ),
```

### Step 5: Connect to Search Dialog

Update the `_SearchDialog` to trigger routing when a location is selected:

```dart
@override
Widget build(BuildContext context) {
  return Dialog(
    // ... existing dialog code ...
    child: Container(
      // ... existing container code ...
      child: Column(
        children: [
          // ... existing search field ...
          
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final location = _results[index];
                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black.withOpacity(0.1)),
                    ),
                    child: Icon(
                      location.icon,
                      size: 16,
                      color: location.color.withOpacity(0.7),
                    ),
                  ),
                  title: Text(
                    location.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context, location); // Return the location
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
```

Then in `map_screen.dart`, update the search bar tap handler:

```dart
onTap: () async {
  final selectedLocation = await showDialog<EmergencyLocation>(
    context: context,
    builder: (context) => _SearchDialog(
      locations: _emergencyLocations,
      isDarkMode: isDarkMode,
    ),
  );
  
  if (selectedLocation != null) {
    // Calculate route from current location to selected location
    await _calculateRoutes(_currentLocation, selectedLocation.position);
  }
},
```

## Testing the Integration

1. **Load the app** - Map should show OSM tiles
2. **Tap search bar** - Dialog appears
3. **Select a location** - Routes appear on map
4. **Route info card shows** - Distance, risk level, flood risk %
5. **Tap X to close** - Route disappears
6. **Multiple routes** - Safest route highlighted, alternatives in blue

## Road Network Coverage

Current nodes cover:
- **Angeles City** (15.145°N, 120.585°E)
- **San Fernando** (15.029°N, 120.643°E)
- **Mabalacat** (15.227°N, 120.597°E)
- **Candaba** (15.083°N, 120.843°E)
- **Guagua** (14.965°N, 120.637°E)

To add more locations, edit `assets/routing/pampanga_road_grid.json`.

## Troubleshooting

**"No routes found"**
- Check if start/end coordinates are near road network nodes
- Expand road network coverage in JSON file

**Routes look jagged**
- Add intermediate nodes between major cities
- Current network has 30 nodes - can expand to 100+ for smoother routes

**Flood risk always 0%**
- Ensure MLPredictionService is initialized
- Check that weather data is available (storm scenario active)

**App crashes on route calculation**
- Verify `assets/routing/pampanga_road_grid.json` in pubspec.yaml
- Run `flutter pub get` to register asset

## Example: Pampanga Locations

Update `_emergencyLocations` with real Pampanga coordinates:

```dart
final List<EmergencyLocation> _emergencyLocations = [
  const EmergencyLocation(
    name: 'Angeles City Hall',
    position: LatLng(15.1450, 120.5850),
    type: EmergencyLocationType.reliefCenter,
  ),
  const EmergencyLocation(
    name: 'San Fernando City Hall',
    position: LatLng(15.0290, 120.6430),
    type: EmergencyLocationType.reliefCenter,
  ),
  const EmergencyLocation(
    name: 'Mabalacat Emergency Center',
    position: LatLng(15.2270, 120.5970),
    type: EmergencyLocationType.evacuationCenter,
  ),
  // Add more real locations
];
```

---

**Integration Status: Ready to implement**

Next: Run `flutter run` and test on device!
