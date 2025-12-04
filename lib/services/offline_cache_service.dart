import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for caching map tiles, landmarks, and route data for offline use
class OfflineCacheService {
  static Database? _database;
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  // Cache settings
  static const int maxTileCacheSize = 500 * 1024 * 1024; // 500MB for tiles
  static const int maxTileAge = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds
  static const int maxRouteCacheAge = 24 * 60 * 60 * 1000; // 24 hours for routes

  /// Initialize the cache database
  Future<void> initialize() async {
    if (_database != null) return;
    
    final dbPath = await getDatabasesPath();
    final dbFile = path.join(dbPath, 'offline_cache.db');
    
    _database = await openDatabase(
      dbFile,
      version: 2,
      onCreate: (db, version) async {
        // Map tiles cache
        await db.execute('''
          CREATE TABLE map_tiles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT UNIQUE,
            tile_data BLOB,
            zoom_level INTEGER,
            x INTEGER,
            y INTEGER,
            created_at INTEGER,
            last_accessed INTEGER
          )
        ''');
        
        // Landmarks/POI cache
        await db.execute('''
          CREATE TABLE landmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            display_name TEXT,
            latitude REAL,
            longitude REAL,
            type TEXT,
            data TEXT,
            created_at INTEGER
          )
        ''');
        
        // Routes cache
        await db.execute('''
          CREATE TABLE routes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_lat REAL,
            start_lng REAL,
            end_lat REAL,
            end_lng REAL,
            route_data TEXT,
            distance REAL,
            duration REAL,
            created_at INTEGER
          )
        ''');
        
        // Search results cache
        await db.execute('''
          CREATE TABLE search_cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT,
            results TEXT,
            created_at INTEGER
          )
        ''');
        
        // Create indexes for faster lookups
        await db.execute('CREATE INDEX idx_tiles_url ON map_tiles(url)');
        await db.execute('CREATE INDEX idx_tiles_zoom ON map_tiles(zoom_level)');
        await db.execute('CREATE INDEX idx_landmarks_location ON landmarks(latitude, longitude)');
        await db.execute('CREATE INDEX idx_routes_coords ON routes(start_lat, start_lng, end_lat, end_lng)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS search_cache (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              query TEXT,
              results TEXT,
              created_at INTEGER
            )
          ''');
        }
      },
    );
    
    // Clean up old cache entries on startup
    await _cleanupOldEntries();
  }

  // ==================== MAP TILE CACHING ====================

  /// Get a cached tile or fetch and cache it
  Future<Uint8List?> getTile(String url, int zoom, int x, int y) async {
    await initialize();
    
    // Try to get from cache first
    final cached = await _database!.query(
      'map_tiles',
      where: 'url = ?',
      whereArgs: [url],
    );
    
    if (cached.isNotEmpty) {
      // Update last accessed time
      await _database!.update(
        'map_tiles',
        {'last_accessed': DateTime.now().millisecondsSinceEpoch},
        where: 'url = ?',
        whereArgs: [url],
      );
      return cached.first['tile_data'] as Uint8List?;
    }
    
    // Fetch from network and cache
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final tileData = response.bodyBytes;
        
        // Store in cache
        await _database!.insert(
          'map_tiles',
          {
            'url': url,
            'tile_data': tileData,
            'zoom_level': zoom,
            'x': x,
            'y': y,
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'last_accessed': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        return tileData;
      }
    } catch (e) {
      debugPrint('Failed to fetch tile: $e');
    }
    
    return null;
  }

  /// Pre-cache tiles for a given area and zoom levels
  Future<void> preCacheTilesForArea({
    required LatLng center,
    required double radiusKm,
    int minZoom = 12,
    int maxZoom = 16,
    Function(int, int)? onProgress,
  }) async {
    await initialize();
    
    final tileUrls = <Map<String, dynamic>>[];
    
    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      final tiles = _getTilesForArea(center, radiusKm, zoom);
      for (var tile in tiles) {
        final url = _buildTileUrl(tile['x'] as int, tile['y'] as int, zoom);
        tileUrls.add({'url': url, 'zoom': zoom, 'x': tile['x'], 'y': tile['y']});
      }
    }
    
    int completed = 0;
    for (var tile in tileUrls) {
      await getTile(tile['url'], tile['zoom'], tile['x'], tile['y']);
      completed++;
      onProgress?.call(completed, tileUrls.length);
      
      // Small delay to avoid overwhelming the server
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  List<Map<String, int>> _getTilesForArea(LatLng center, double radiusKm, int zoom) {
    final tiles = <Map<String, int>>[];
    
    // Convert radius to degrees (approximate)
    final latDelta = radiusKm / 111.0;
    final lngDelta = radiusKm / (111.0 * cos(center.latitude * pi / 180));
    
    final minLat = center.latitude - latDelta;
    final maxLat = center.latitude + latDelta;
    final minLng = center.longitude - lngDelta;
    final maxLng = center.longitude + lngDelta;
    
    final minTileX = _lngToTileX(minLng, zoom);
    final maxTileX = _lngToTileX(maxLng, zoom);
    final minTileY = _latToTileY(maxLat, zoom);
    final maxTileY = _latToTileY(minLat, zoom);
    
    for (int x = minTileX; x <= maxTileX; x++) {
      for (int y = minTileY; y <= maxTileY; y++) {
        tiles.add({'x': x, 'y': y});
      }
    }
    
    return tiles;
  }

  int _lngToTileX(double lng, int zoom) {
    return ((lng + 180) / 360 * (1 << zoom)).floor();
  }

  int _latToTileY(double lat, int zoom) {
    final latRad = lat * pi / 180;
    return ((1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * (1 << zoom)).floor();
  }

  String _buildTileUrl(int x, int y, int zoom) {
    return 'https://tile.openstreetmap.org/$zoom/$x/$y.png';
  }

  // ==================== LANDMARK CACHING ====================

  /// Cache a landmark/POI
  Future<void> cacheLandmark({
    required String name,
    required String displayName,
    required double latitude,
    required double longitude,
    required String type,
    Map<String, dynamic>? additionalData,
  }) async {
    await initialize();
    
    await _database!.insert(
      'landmarks',
      {
        'name': name,
        'display_name': displayName,
        'latitude': latitude,
        'longitude': longitude,
        'type': type,
        'data': additionalData != null ? jsonEncode(additionalData) : null,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Cache multiple landmarks at once
  Future<void> cacheLandmarks(List<Map<String, dynamic>> landmarks) async {
    await initialize();
    
    final batch = _database!.batch();
    for (var landmark in landmarks) {
      batch.insert(
        'landmarks',
        {
          'name': landmark['name'],
          'display_name': landmark['display_name'] ?? landmark['name'],
          'latitude': landmark['latitude'],
          'longitude': landmark['longitude'],
          'type': landmark['type'] ?? 'place',
          'data': landmark['data'] != null ? jsonEncode(landmark['data']) : null,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Get cached landmarks near a location
  Future<List<Map<String, dynamic>>> getLandmarksNear(
    LatLng location, {
    double radiusKm = 5.0,
  }) async {
    await initialize();
    
    // Simple bounding box query
    final latDelta = radiusKm / 111.0;
    final lngDelta = radiusKm / (111.0 * cos(location.latitude * pi / 180));
    
    final results = await _database!.query(
      'landmarks',
      where: 'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
      whereArgs: [
        location.latitude - latDelta,
        location.latitude + latDelta,
        location.longitude - lngDelta,
        location.longitude + lngDelta,
      ],
    );
    
    return results.map((row) {
      return {
        'name': row['name'],
        'display_name': row['display_name'],
        'latitude': row['latitude'],
        'longitude': row['longitude'],
        'type': row['type'],
        'data': row['data'] != null ? jsonDecode(row['data'] as String) : null,
      };
    }).toList();
  }

  /// Search cached landmarks
  Future<List<Map<String, dynamic>>> searchLandmarks(String query) async {
    await initialize();
    
    final results = await _database!.query(
      'landmarks',
      where: 'name LIKE ? OR display_name LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      limit: 20,
    );
    
    return results.map((row) {
      return {
        'name': row['name'],
        'display_name': row['display_name'],
        'latitude': row['latitude'],
        'longitude': row['longitude'],
        'type': row['type'],
        'data': row['data'] != null ? jsonDecode(row['data'] as String) : null,
      };
    }).toList();
  }

  // ==================== ROUTE CACHING ====================

  /// Cache a route
  Future<void> cacheRoute({
    required LatLng start,
    required LatLng end,
    required List<LatLng> coordinates,
    required double distance,
    required double duration,
  }) async {
    await initialize();
    
    final routeData = jsonEncode({
      'coordinates': coordinates.map((c) => {'lat': c.latitude, 'lng': c.longitude}).toList(),
    });
    
    await _database!.insert(
      'routes',
      {
        'start_lat': start.latitude,
        'start_lng': start.longitude,
        'end_lat': end.latitude,
        'end_lng': end.longitude,
        'route_data': routeData,
        'distance': distance,
        'duration': duration,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a cached route
  Future<Map<String, dynamic>?> getCachedRoute(LatLng start, LatLng end) async {
    await initialize();
    
    // Allow some tolerance for start/end positions (about 50 meters)
    const tolerance = 0.0005;
    
    final results = await _database!.query(
      'routes',
      where: '''
        start_lat BETWEEN ? AND ? AND
        start_lng BETWEEN ? AND ? AND
        end_lat BETWEEN ? AND ? AND
        end_lng BETWEEN ? AND ? AND
        created_at > ?
      ''',
      whereArgs: [
        start.latitude - tolerance,
        start.latitude + tolerance,
        start.longitude - tolerance,
        start.longitude + tolerance,
        end.latitude - tolerance,
        end.latitude + tolerance,
        end.longitude - tolerance,
        end.longitude + tolerance,
        DateTime.now().millisecondsSinceEpoch - maxRouteCacheAge,
      ],
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    
    final row = results.first;
    final routeData = jsonDecode(row['route_data'] as String);
    
    return {
      'coordinates': (routeData['coordinates'] as List)
          .map((c) => LatLng(c['lat'], c['lng']))
          .toList(),
      'distance': row['distance'],
      'duration': row['duration'],
    };
  }

  // ==================== SEARCH CACHE ====================

  /// Cache search results
  Future<void> cacheSearchResults(String query, List<Map<String, dynamic>> results) async {
    await initialize();
    
    await _database!.insert(
      'search_cache',
      {
        'query': query.toLowerCase(),
        'results': jsonEncode(results),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached search results
  Future<List<Map<String, dynamic>>?> getCachedSearchResults(String query) async {
    await initialize();
    
    final results = await _database!.query(
      'search_cache',
      where: 'query = ? AND created_at > ?',
      whereArgs: [
        query.toLowerCase(),
        DateTime.now().millisecondsSinceEpoch - maxRouteCacheAge,
      ],
      limit: 1,
    );
    
    if (results.isEmpty) return null;
    
    final data = jsonDecode(results.first['results'] as String) as List;
    return data.cast<Map<String, dynamic>>();
  }

  // ==================== CACHE MANAGEMENT ====================

  /// Clean up old cache entries
  Future<void> _cleanupOldEntries() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Remove old tiles
    await _database!.delete(
      'map_tiles',
      where: 'created_at < ?',
      whereArgs: [now - maxTileAge],
    );
    
    // Remove old routes
    await _database!.delete(
      'routes',
      where: 'created_at < ?',
      whereArgs: [now - maxRouteCacheAge],
    );
    
    // Remove old search cache
    await _database!.delete(
      'search_cache',
      where: 'created_at < ?',
      whereArgs: [now - maxRouteCacheAge],
    );
    
    // Check tile cache size and prune if needed
    await _pruneTileCacheIfNeeded();
  }

  /// Prune tile cache if it exceeds max size
  Future<void> _pruneTileCacheIfNeeded() async {
    final sizeResult = await _database!.rawQuery(
      'SELECT SUM(LENGTH(tile_data)) as total_size FROM map_tiles',
    );
    
    final totalSize = sizeResult.first['total_size'] as int? ?? 0;
    
    if (totalSize > maxTileCacheSize) {
      // Remove oldest accessed tiles until we're under the limit
      final targetSize = maxTileCacheSize * 0.8; // Remove until 80% full
      
      await _database!.rawDelete('''
        DELETE FROM map_tiles WHERE id IN (
          SELECT id FROM map_tiles ORDER BY last_accessed ASC
          LIMIT (SELECT COUNT(*) * 0.3 FROM map_tiles)
        )
      ''');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    await initialize();
    
    final tileCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM map_tiles'),
    );
    
    final tileSize = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT SUM(LENGTH(tile_data)) FROM map_tiles'),
    );
    
    final landmarkCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM landmarks'),
    );
    
    final routeCount = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM routes'),
    );
    
    return {
      'tiles': tileCount ?? 0,
      'tileSizeMB': ((tileSize ?? 0) / (1024 * 1024)).toStringAsFixed(2),
      'landmarks': landmarkCount ?? 0,
      'routes': routeCount ?? 0,
    };
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await initialize();
    
    await _database!.delete('map_tiles');
    await _database!.delete('landmarks');
    await _database!.delete('routes');
    await _database!.delete('search_cache');
  }

  /// Clear only map tiles
  Future<void> clearTileCache() async {
    await initialize();
    await _database!.delete('map_tiles');
  }
}
