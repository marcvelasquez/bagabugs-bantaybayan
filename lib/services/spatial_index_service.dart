import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:math' as math;
import '../utils/coordinate_utils.dart';

/// Types of rasters available for sampling
enum RasterType {
  elevation,
  slope,
  flowAccumulation,
  population,
}

/// Result of nearest neighbor search
class NearestNeighborResult {
  final int id;
  final LatLng coordinate;
  final double distance;
  final Map<String, dynamic>? properties;

  NearestNeighborResult({
    required this.id,
    required this.coordinate,
    required this.distance,
    this.properties,
  });
}

/// Service for spatial indexing and raster sampling
/// Handles roads, landslides, and GeoTIFF raster data
class SpatialIndexService {
  Database? _database;
  
  // Raster metadata (loaded from files)
  final Map<RasterType, RasterMetadata> _rasterMetadata = {};
  
  // In-memory tile cache for fast lookups
  final Map<String, Map<int, Map<int, double>>> _rasterCache = {};
  
  static const String _dbName = 'spatial_index.db';
  
  bool _isInitialized = false;

  /// Initialize the spatial index database
  Future<void> initialize() async {
    if (_isInitialized) {
      print('SpatialIndexService already initialized');
      return;
    }

    try {
      print('Initializing SpatialIndexService...');

      // Open/create SQLite database
      _database = await _openDatabase();

      // Load raster metadata
      await _loadRasterMetadata();

      // Create spatial indices if needed
      await _createSpatialIndices();

      _isInitialized = true;
      print('SpatialIndexService initialized successfully');
    } catch (e) {
      print('Error initializing SpatialIndexService: $e');
      rethrow;
    }
  }

  /// Open SQLite database
  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  /// Create database tables
  Future<void> _createTables(Database db, int version) async {
    // Roads table with spatial index
    await db.execute('''
      CREATE TABLE roads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        road_type TEXT,
        name TEXT,
        geom_wkt TEXT
      )
    ''');

    // Create R-tree virtual table for spatial indexing (SQLite FTS5)
    // Note: For production, use a proper R-tree implementation
    await db.execute('''
      CREATE INDEX idx_roads_latlon ON roads(latitude, longitude)
    ''');

    // Landslides table
    await db.execute('''
      CREATE TABLE landslides (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        date TEXT,
        magnitude REAL,
        fatalities INTEGER
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_landslides_latlon ON landslides(latitude, longitude)
    ''');

    print('Database tables created');
  }

  /// Create spatial indices
  Future<void> _createSpatialIndices() async {
    // Check if roads table has data
    final roadCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM roads'),
    );

    if (roadCount == 0) {
      print('Roads table is empty. Import road data first.');
      // In production, you would import OSM road data here
    }

    // Check if landslides table has data
    final landslideCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM landslides'),
    );

    if (landslideCount == 0) {
      print('Landslides table is empty. Import landslide data first.');
      // In production, you would import NASA landslide CSV here
    }
  }

  /// Load raster metadata from files
  Future<void> _loadRasterMetadata() async {
    // In production, this would read actual GeoTIFF metadata
    // For now, we'll use placeholder values for Philippines region
    
    _rasterMetadata[RasterType.elevation] = RasterMetadata(
      type: RasterType.elevation,
      width: 10000,
      height: 10000,
      noDataValue: -9999.0,
      geoTransform: [
        116.0,  // Top-left X (longitude)
        0.00027778,  // Pixel width (~30m at equator)
        0.0,  // Rotation
        22.0,  // Top-left Y (latitude)
        0.0,  // Rotation
        -0.00027778,  // Pixel height (negative = north-up)
      ],
    );

    _rasterMetadata[RasterType.slope] = _rasterMetadata[RasterType.elevation]!;
    _rasterMetadata[RasterType.flowAccumulation] = _rasterMetadata[RasterType.elevation]!;
    _rasterMetadata[RasterType.population] = _rasterMetadata[RasterType.elevation]!;

    print('Raster metadata loaded');
  }

  /// Sample value from raster at given coordinate
  /// Returns null if out of bounds or no data
  Future<double?> sampleRaster({
    required LatLng coordinate,
    required RasterType rasterType,
  }) async {
    try {
      final metadata = _rasterMetadata[rasterType];
      if (metadata == null) {
        print('No metadata for raster type: $rasterType');
        return null;
      }

      // Convert geographic coordinate to pixel coordinate
      final pixel = CoordinateUtils.geoToPixel(
        coordinate: coordinate,
        geoTransform0: metadata.geoTransform[0],
        geoTransform1: metadata.geoTransform[1],
        geoTransform2: metadata.geoTransform[2],
        geoTransform3: metadata.geoTransform[3],
        geoTransform4: metadata.geoTransform[4],
        geoTransform5: metadata.geoTransform[5],
      );

      final x = pixel['x']!;
      final y = pixel['y']!;

      // Check bounds
      if (x < 0 || x >= metadata.width || y < 0 || y >= metadata.height) {
        return null;
      }

      // Check cache first
      final cacheKey = rasterType.toString();
      if (_rasterCache.containsKey(cacheKey) &&
          _rasterCache[cacheKey]!.containsKey(x) &&
          _rasterCache[cacheKey]![x]!.containsKey(y)) {
        return _rasterCache[cacheKey]![x]![y];
      }

      // In production, read from actual GeoTIFF file
      // For now, return simulated data based on coordinate
      final value = _simulateRasterValue(coordinate, rasterType);

      // Cache the value
      _rasterCache.putIfAbsent(cacheKey, () => {});
      _rasterCache[cacheKey]!.putIfAbsent(x, () => {});
      _rasterCache[cacheKey]![x]![y] = value;

      return value;
    } catch (e) {
      print('Error sampling raster: $e');
      return null;
    }
  }

  /// Simulate raster values (replace with actual GeoTIFF reading in production)
  double _simulateRasterValue(LatLng coordinate, RasterType type) {
    // Simple simulation based on coordinate
    final lat = coordinate.latitude;
    final lon = coordinate.longitude;
    final random = math.Random(lat.hashCode ^ lon.hashCode);

    switch (type) {
      case RasterType.elevation:
        // Elevation: 0-500m with some variation
        return 50.0 + random.nextDouble() * 200.0;

      case RasterType.slope:
        // Slope: 0-30 degrees
        return random.nextDouble() * 30.0;

      case RasterType.flowAccumulation:
        // Flow accumulation: 0-10000
        return random.nextDouble() * 10000.0;

      case RasterType.population:
        // Population density: 0-5000 people/km²
        return random.nextDouble() * 5000.0;
    }
  }

  /// Find nearest road to given coordinate
  Future<NearestNeighborResult?> findNearestRoad(LatLng coordinate) async {
    if (_database == null) {
      throw Exception('Database not initialized');
    }

    try {
      // Simple bounding box query (in production, use R-tree)
      final searchRadius = 0.1; // ~11km
      
      final results = await _database!.query(
        'roads',
        where: '''
          latitude BETWEEN ? AND ?
          AND longitude BETWEEN ? AND ?
        ''',
        whereArgs: [
          coordinate.latitude - searchRadius,
          coordinate.latitude + searchRadius,
          coordinate.longitude - searchRadius,
          coordinate.longitude + searchRadius,
        ],
        limit: 50,
      );

      if (results.isEmpty) {
        return null;
      }

      // Find nearest among results
      NearestNeighborResult? nearest;
      double minDistance = double.infinity;

      for (final row in results) {
        final roadCoord = LatLng(
          row['latitude'] as double,
          row['longitude'] as double,
        );

        final distance = CoordinateUtils.calculateDistance(coordinate, roadCoord);

        if (distance < minDistance) {
          minDistance = distance;
          nearest = NearestNeighborResult(
            id: row['id'] as int,
            coordinate: roadCoord,
            distance: distance,
            properties: {
              'road_type': row['road_type'],
              'name': row['name'],
            },
          );
        }
      }

      return nearest;
    } catch (e) {
      print('Error finding nearest road: $e');
      return null;
    }
  }

  /// Find nearest landslide to given coordinate
  Future<NearestNeighborResult?> findNearestLandslide(LatLng coordinate) async {
    if (_database == null) {
      throw Exception('Database not initialized');
    }

    try {
      final searchRadius = 1.0; // ~111km

      final results = await _database!.query(
        'landslides',
        where: '''
          latitude BETWEEN ? AND ?
          AND longitude BETWEEN ? AND ?
        ''',
        whereArgs: [
          coordinate.latitude - searchRadius,
          coordinate.latitude + searchRadius,
          coordinate.longitude - searchRadius,
          coordinate.longitude + searchRadius,
        ],
        limit: 50,
      );

      if (results.isEmpty) {
        return null;
      }

      // Find nearest
      NearestNeighborResult? nearest;
      double minDistance = double.infinity;

      for (final row in results) {
        final landslideCoord = LatLng(
          row['latitude'] as double,
          row['longitude'] as double,
        );

        final distance = CoordinateUtils.calculateDistance(coordinate, landslideCoord);

        if (distance < minDistance) {
          minDistance = distance;
          nearest = NearestNeighborResult(
            id: row['id'] as int,
            coordinate: landslideCoord,
            distance: distance,
            properties: {
              'date': row['date'],
              'magnitude': row['magnitude'],
              'fatalities': row['fatalities'],
            },
          );
        }
      }

      return nearest;
    } catch (e) {
      print('Error finding nearest landslide: $e');
      return null;
    }
  }

  /// Import road data from OSM shapefile (helper method)
  /// This would be called during app setup
  Future<void> importRoadData(String shapefilePath) async {
    // In production, parse OSM shapefile and insert into database
    // For now, this is a placeholder
    print('Import road data from: $shapefilePath');
    
    // Example insert:
    // await _database!.insert('roads', {
    //   'latitude': lat,
    //   'longitude': lon,
    //   'road_type': 'primary',
    //   'name': 'Highway 1',
    // });
  }

  /// Import landslide data from CSV (helper method)
  Future<void> importLandslideData(String csvPath) async {
    print('Import landslide data from: $csvPath');
    
    // Example insert:
    // await _database!.insert('landslides', {
    //   'latitude': lat,
    //   'longitude': lon,
    //   'date': '2023-01-15',
    //   'magnitude': 3.2,
    //   'fatalities': 0,
    // });
  }

  /// Clear raster cache
  void clearRasterCache() {
    _rasterCache.clear();
    print('Raster cache cleared');
  }

  /// Get cache statistics
  Map<String, int> getCacheStats() {
    int totalCachedValues = 0;
    for (final rasterCache in _rasterCache.values) {
      for (final row in rasterCache.values) {
        totalCachedValues += row.length;
      }
    }

    return {
      'raster_types': _rasterCache.length,
      'cached_values': totalCachedValues,
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
    _rasterCache.clear();
    _isInitialized = false;
  }
}

/// Metadata for a raster dataset
class RasterMetadata {
  final RasterType type;
  final int width;
  final int height;
  final double noDataValue;
  final List<double> geoTransform;

  RasterMetadata({
    required this.type,
    required this.width,
    required this.height,
    required this.noDataValue,
    required this.geoTransform,
  });
}
