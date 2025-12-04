# BantayBayan Flood Risk ML Model Integration Guide

## Overview
This guide explains how to integrate the flood risk machine learning models into the BantayBayan Flutter application for offline disaster routing.

---

## Part 1: Model Conversion (Python)

### Prerequisites
```bash
pip install scikit-learn tensorflow numpy joblib
```

### Step 1: Convert Models to TensorFlow Lite

Run the conversion script:
```bash
cd scripts
python convert_models_to_tflite.py
```

**What this does:**
- Loads your RandomForest models (.pkl files)
- Trains a neural network to approximate the RandomForest predictions
- Converts to TensorFlow Lite format with quantization
- Reduces model size from ~15MB to <5MB per model
- Saves scaler parameters as JSON

**Output files:**
```
assets/ml_models/
├── flood_probability_model.tflite (~3-5MB)
├── flood_depth_model.tflite (~3-5MB)
└── scaler_params.json (<1KB)
```

---

## Part 2: Raster Data Preparation

### GeoTIFF Compression

Your raster files are large. Compress them:

```bash
# Install GDAL
# Windows: Download from https://gdal.org/
# macOS: brew install gdal
# Linux: apt-get install gdal-bin

# Compress elevation raster
gdal_translate -co COMPRESS=LZW -co TILED=YES \
  philippines_elevation_merged.tif \
  assets/rasters/elevation/philippines_elevation_compressed.tif

# Compress slope raster
gdal_translate -co COMPRESS=LZW -co TILED=YES \
  philippines_slope_merged.tif \
  assets/rasters/slope/philippines_slope_compressed.tif

# Compress flow accumulation
gdal_translate -co COMPRESS=LZW -co TILED=YES \
  pampanga_flow_accumulation.tif \
  assets/rasters/flow_accumulation/pampanga_flow_compressed.tif

# Compress population raster
gdal_translate -co COMPRESS=LZW -co TILED=YES \
  phl_ppp_2020.tif \
  assets/rasters/population/philippines_population_compressed.tif
```

### Alternative: MBTiles Format (Recommended)

For better performance, convert rasters to MBTiles format:

```bash
# Convert elevation to MBTiles (faster lookups)
gdal_translate -of MBTiles \
  philippines_elevation_merged.tif \
  assets/rasters/elevation.mbtiles

# Repeat for other rasters...
```

**Benefits of MBTiles:**
- Faster random access (tiled format)
- Better compression
- Easier to work with in Flutter
- SQLite-based (can use sqflite package)

---

## Part 3: Road and Landslide Data

### Import OSM Roads to SQLite

```python
# Import roads from OSM shapefile to SQLite
import geopandas as gpd
import sqlite3

# Read OSM roads
roads = gpd.read_file('philippines-251202-free.shp/gis_osm_roads_free_1.shp')

# Filter to major roads only (reduce size)
major_roads = roads[roads['fclass'].isin(['motorway', 'trunk', 'primary', 'secondary'])]

# Extract points along roads (sample every 100m)
road_points = []
for idx, road in major_roads.iterrows():
    geom = road.geometry
    length = geom.length
    num_points = int(length / 0.001)  # ~100m at equator
    
    for i in range(num_points):
        point = geom.interpolate(i / num_points, normalized=True)
        road_points.append({
            'latitude': point.y,
            'longitude': point.x,
            'road_type': road['fclass'],
            'name': road.get('name', '')
        })

# Save to SQLite
conn = sqlite3.connect('assets/spatial_index.db')
road_df = pd.DataFrame(road_points)
road_df.to_sql('roads', conn, if_exists='replace', index=False)

# Create spatial index
conn.execute('CREATE INDEX idx_roads_latlon ON roads(latitude, longitude)')
conn.close()

print(f"Imported {len(road_points)} road points")
```

### Import Landslide Data

```python
# Import NASA landslide CSV to SQLite
import pandas as pd
import sqlite3

# Read landslide data
landslides = pd.read_csv('philippines_landslides.csv')

# Filter to Philippines only
philippines = landslides[
    (landslides['latitude'] >= 5) & (landslides['latitude'] <= 21) &
    (landslides['longitude'] >= 116) & (landslides['longitude'] <= 127)
]

# Save to SQLite
conn = sqlite3.connect('assets/spatial_index.db')
philippines.to_sql('landslides', conn, if_exists='replace', index=False)

conn.execute('CREATE INDEX idx_landslides_latlon ON landslides(latitude, longitude)')
conn.close()

print(f"Imported {len(philippines)} landslide points")
```

---

## Part 4: Flutter Asset Setup

### Create Asset Directories

```bash
mkdir -p assets/ml_models
mkdir -p assets/rasters/elevation
mkdir -p assets/rasters/slope
mkdir -p assets/rasters/flow_accumulation
mkdir -p assets/rasters/population
```

### Copy Files

```bash
# Copy TFLite models
cp scripts/assets/ml_models/*.tflite assets/ml_models/
cp scripts/assets/ml_models/scaler_params.json assets/ml_models/

# Copy compressed rasters
cp path/to/compressed/rasters/* assets/rasters/

# Copy SQLite database
cp spatial_index.db assets/
```

### Update pubspec.yaml

Already done! The assets are declared in pubspec.yaml.

---

## Part 5: Flutter Integration

### Initialize Services in main.dart

```dart
import 'package:flutter/material.dart';
import 'services/tflite_inference_service.dart';
import 'services/spatial_index_service.dart';
import 'services/flood_risk_service.dart';
import 'models/route_risk_calculator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize ML services
  final tfliteService = TFLiteInferenceService();
  final spatialService = SpatialIndexService();
  
  await tfliteService.initialize();
  await spatialService.initialize();
  
  final floodRiskService = FloodRiskService(
    inferenceService: tfliteService,
    spatialService: spatialService,
  );
  
  await floodRiskService.initialize();
  
  runApp(MyApp(floodRiskService: floodRiskService));
}
```

### Example Usage

```dart
// Get flood risk for current location
final currentLocation = LatLng(14.5995, 120.9842);
final risk = await floodRiskService.getFloodRisk(currentLocation);

print('Flood Probability: ${(risk.floodProbability * 100).toStringAsFixed(1)}%');
print('Estimated Depth: ${risk.floodDepth.toStringAsFixed(2)}m');
print('Risk Level: ${risk.riskLevel.displayName}');

// Analyze a route
final routePath = [/* list of LatLng coordinates */];
final calculator = RouteRiskCalculator(floodRiskService: floodRiskService);
final analysis = await calculator.calculateRouteRisk(routePath);

if (!analysis.isRecommended) {
  print('⚠️ Route not recommended due to flood risk');
}

// Calculate edge cost for Dijkstra
final edgeCost = await calculator.calculateEdgeCost(
  start: LatLng(14.60, 120.98),
  end: LatLng(14.61, 120.99),
  trafficSpeed: 40.0,
  rainMultiplier: 1.5, // Light rain
);
```

---

## Part 6: Performance Optimization

### Tile-Based Raster Loading

Instead of loading entire rasters, implement tile-based loading:

```dart
// Load only tiles for current viewport
class RasterTileLoader {
  Future<void> loadTilesForBounds(LatLngBounds bounds) async {
    // Calculate which tiles are needed
    // Load only those tiles into memory
    // Cache tiles for quick access
  }
}
```

### Spatial Caching

Pre-compute flood risk for a grid:

```python
# Pre-compute 1km grid of flood risk for Philippines
import numpy as np

lat_min, lat_max = 5.0, 21.0
lon_min, lon_max = 116.0, 127.0
resolution = 0.01  # ~1km

lats = np.arange(lat_min, lat_max, resolution)
lons = np.arange(lon_min, lon_max, resolution)

risk_grid = {}

for lat in lats:
    for lon in lons:
        # Extract features and predict
        features = extract_features(lat, lon)
        prob = model.predict([features])[0]
        
        risk_grid[f"{lat:.2f},{lon:.2f}"] = prob

# Save to JSON
import json
with open('assets/risk_grid.json', 'w') as f:
    json.dump(risk_grid, f)
```

Then in Flutter, use nearest grid point for quick lookups.

---

## Part 7: APK Size Management

### Expected Sizes
- TFLite models: ~6-10MB
- Raster data (compressed): ~200-300MB
- SQLite database: ~50MB
- **Total: ~250-360MB**

### Optimization Strategies

#### 1. Use Android App Bundles
```bash
flutter build appbundle --release
```
This allows Google Play to deliver only the assets needed for specific regions.

#### 2. On-Demand Downloads
Download raster data after app install:

```dart
// Download rasters on first launch
Future<void> downloadRasterData() async {
  final dio = Dio();
  await dio.download(
    'https://yourdomain.com/assets/rasters.zip',
    '/path/to/local/storage/rasters.zip',
    onReceiveProgress: (received, total) {
      print('Download: ${(received / total * 100).toStringAsFixed(0)}%');
    },
  );
  
  // Extract zip file
  await extractZip('/path/to/rasters.zip');
}
```

#### 3. Regional Data Only
Ship only data for user's region (e.g., Pampanga only):
- Reduces APK to ~50MB
- Download other regions on-demand

---

## Part 8: Testing

### Unit Tests

```dart
// test/flood_risk_service_test.dart
void main() {
  late FloodRiskService service;
  
  setUp(() async {
    final tflite = TFLiteInferenceService();
    final spatial = SpatialIndexService();
    await tflite.initialize();
    await spatial.initialize();
    
    service = FloodRiskService(
      inferenceService: tflite,
      spatialService: spatial,
    );
    await service.initialize();
  });
  
  test('Extract features for valid coordinate', () async {
    final features = await service.extractFeatures(
      LatLng(15.0, 120.5),
    );
    
    expect(features.length, 6);
    expect(features.every((f) => f.isFinite), true);
  });
  
  test('Predict flood risk', () async {
    final risk = await service.getFloodRisk(LatLng(15.0, 120.5));
    
    expect(risk.floodProbability, greaterThanOrEqualTo(0.0));
    expect(risk.floodProbability, lessThanOrEqualTo(1.0));
  });
}
```

---

## Part 9: Troubleshooting

### Issue: Models not loading
**Solution:** Ensure TFLite models are in `assets/ml_models/` and declared in pubspec.yaml

### Issue: Out of memory
**Solution:** Implement tile-based loading and limit cache size

### Issue: Slow inference
**Solution:** 
- Enable NNAPI delegate on Android
- Use batch predictions
- Implement spatial caching

### Issue: Inaccurate predictions
**Solution:**
- Verify scaler parameters match training
- Check feature extraction (especially raster sampling)
- Validate coordinate transformations

---

## Part 10: Future Enhancements

1. **Live Rainfall Integration**
   - Connect to PAGASA API
   - Adjust risk multipliers in real-time

2. **Community Reports**
   - Users report actual flood conditions
   - Update risk model with real data

3. **Historical Flood Data**
   - Train on actual flood events
   - Improve prediction accuracy

4. **Route Optimization**
   - Implement A* algorithm with risk costs
   - Multi-objective optimization (time + safety)

---

## Summary Checklist

- [ ] Convert models to TFLite
- [ ] Compress raster files
- [ ] Import roads to SQLite
- [ ] Import landslides to SQLite
- [ ] Copy assets to Flutter project
- [ ] Update pubspec.yaml
- [ ] Initialize services in main.dart
- [ ] Test on device
- [ ] Optimize APK size
- [ ] Deploy to production

---

## Support

For issues or questions:
1. Check logs: `flutter run --verbose`
2. Verify asset paths in pubspec.yaml
3. Test model loading separately
4. Review coordinate transformations

Good luck with your integration! 🚀
