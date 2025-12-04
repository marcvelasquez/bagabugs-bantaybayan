import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'offline_cache_service.dart';

/// Custom tile provider that caches tiles for offline use
class CachedTileProvider extends TileProvider {
  final OfflineCacheService _cacheService = OfflineCacheService();
  final http.Client _httpClient = http.Client();
  
  CachedTileProvider() {
    _cacheService.initialize();
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return CachedNetworkImageProvider(
      url,
      coordinates.z.toInt(),
      coordinates.x.toInt(),
      coordinates.y.toInt(),
      _cacheService,
      _httpClient,
    );
  }
  
  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }
}

/// Custom image provider that checks cache before network
class CachedNetworkImageProvider extends ImageProvider<CachedNetworkImageProvider> {
  final String url;
  final int zoom;
  final int x;
  final int y;
  final OfflineCacheService cacheService;
  final http.Client httpClient;

  CachedNetworkImageProvider(
    this.url,
    this.zoom,
    this.x,
    this.y,
    this.cacheService,
    this.httpClient,
  );

  @override
  Future<CachedNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      informationCollector: () sync* {
        yield DiagnosticsProperty<ImageProvider>('Image provider', this);
        yield DiagnosticsProperty<CachedNetworkImageProvider>('Image key', key);
      },
    );
  }

  Future<ui.Codec> _loadAsync(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      // Try to get from cache first
      final cachedData = await cacheService.getTile(url, zoom, x, y);
      
      if (cachedData != null && cachedData.isNotEmpty) {
        final buffer = await ui.ImmutableBuffer.fromUint8List(cachedData);
        return decode(buffer);
      }
      
      // If not in cache, fetch from network (getTile already caches it)
      // This shouldn't happen normally as getTile fetches and caches
      final response = await httpClient.get(
        Uri.parse(url),
        headers: {'User-Agent': 'BantayBayan-App/1.0'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      }
      
      throw Exception('Failed to load tile: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error loading tile $url: $e');
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is CachedNetworkImageProvider && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'CachedNetworkImageProvider("$url")';
}
