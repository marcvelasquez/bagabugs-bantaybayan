import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/api_config.dart';
import '../models/api_models.dart';

class ApiService {
  static String? _authToken;

  static void setAuthToken(String token) {
    _authToken = token;
  }

  static void clearAuthToken() {
    _authToken = null;
  }

  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  static Future<http.Response> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    } else {
      throw Exception(
          'API Error: ${response.statusCode} - ${response.body}');
    }
  }

  // Auth endpoints
  static Future<AuthToken> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.authUrl}/register'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'username': username,
        'password': password,
      }),
    );

    await _handleResponse(response);
    return AuthToken.fromJson(jsonDecode(response.body));
  }

  static Future<AuthToken> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.authUrl}/login'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    final responseData = await _handleResponse(response);
    final token = AuthToken.fromJson(jsonDecode(responseData.body));
    setAuthToken(token.accessToken);
    return token;
  }

  // Report endpoints
  // Note: These require the Python server to be running. Falls back gracefully if unavailable.
  
  static Future<ReportModel> createReport(ReportModel report) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.reportsUrl}/'),
        headers: _headers,
        body: jsonEncode(report.toJson()),
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      return ReportModel.fromJson(jsonDecode(responseData.body));
    } on SocketException {
      debugPrint('⚠️ Server unavailable - report not saved to server');
      // Return the report with a mock ID for local use
      return ReportModel(
        id: DateTime.now().millisecondsSinceEpoch,
        incidentType: report.incidentType,
        latitude: report.latitude,
        longitude: report.longitude,
        description: report.description,
        createdAt: DateTime.now(),
        upvoteCount: 0,
      );
    } on TimeoutException {
      debugPrint('⚠️ Server timeout - report not saved to server');
      return ReportModel(
        id: DateTime.now().millisecondsSinceEpoch,
        incidentType: report.incidentType,
        latitude: report.latitude,
        longitude: report.longitude,
        description: report.description,
        createdAt: DateTime.now(),
        upvoteCount: 0,
      );
    }
  }

  static Future<List<ReportModel>> getReports({
    int skip = 0,
    int limit = 100,
    String? incidentType,
  }) async {
    try {
      var url = '${ApiConfig.reportsUrl}/?skip=$skip&limit=$limit';
      if (incidentType != null) {
        url += '&incident_type=$incidentType';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      final List<dynamic> data = jsonDecode(responseData.body);
      return data.map((json) => ReportModel.fromJson(json)).toList();
    } on SocketException {
      debugPrint('⚠️ Server unavailable - returning empty reports list');
      return [];
    } on TimeoutException {
      debugPrint('⚠️ Server timeout - returning empty reports list');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching reports: $e');
      return [];
    }
  }

  static Future<ReportStats> getReportStats() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.reportsUrl}/stats'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      return ReportStats.fromJson(jsonDecode(responseData.body));
    } on SocketException {
      debugPrint('⚠️ Server unavailable - returning default stats');
      return ReportStats(infoCount: 0, criticalCount: 0, warningCount: 0, totalCount: 0, date: DateTime.now().toIso8601String());
    } on TimeoutException {
      debugPrint('⚠️ Server timeout - returning default stats');
      return ReportStats(infoCount: 0, criticalCount: 0, warningCount: 0, totalCount: 0, date: DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('❌ Error fetching report stats: $e');
      return ReportStats(infoCount: 0, criticalCount: 0, warningCount: 0, totalCount: 0, date: DateTime.now().toIso8601String());
    }
  }

  static Future<ReportModel?> getReport(int reportId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.reportsUrl}/$reportId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      return ReportModel.fromJson(jsonDecode(responseData.body));
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return null;
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching report: $e');
      return null;
    }
  }

  static Future<ReportModel?> updateReport(int reportId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.reportsUrl}/$reportId'),
        headers: _headers,
        body: jsonEncode(updates),
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      return ReportModel.fromJson(jsonDecode(responseData.body));
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return null;
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return null;
    } catch (e) {
      debugPrint('❌ Error updating report: $e');
      return null;
    }
  }

  static Future<bool> deleteReport(int reportId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.reportsUrl}/$reportId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      await _handleResponse(response);
      return true;
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return false;
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting report: $e');
      return false;
    }
  }

  static Future<List<ReportModel>> getNearbyReports({
    required double latitude,
    required double longitude,
    double radius = 100.0,
    String? incidentType,
  }) async {
    try {
      var url = '${ApiConfig.reportsUrl}/nearby/$latitude/$longitude?radius=$radius';
      if (incidentType != null) {
        url += '&incident_type=$incidentType';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      final List<dynamic> data = jsonDecode(responseData.body);
      return data.map((json) => ReportModel.fromJson(json)).toList();
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return [];
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching nearby reports: $e');
      return [];
    }
  }

  static Future<ReportModel?> upvoteReport(int reportId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.reportsUrl}/$reportId/upvote'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      return ReportModel.fromJson(jsonDecode(responseData.body));
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return null;
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return null;
    } catch (e) {
      debugPrint('❌ Error upvoting report: $e');
      return null;
    }
  }

  static Future<ReportModel?> removeUpvote(int reportId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.reportsUrl}/$reportId/upvote'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      return ReportModel.fromJson(jsonDecode(responseData.body));
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return null;
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return null;
    } catch (e) {
      debugPrint('❌ Error removing upvote: $e');
      return null;
    }
  }

  // Incident endpoints
  // Note: These require the Python server to be running. Falls back gracefully if unavailable.
  
  static Future<IncidentModel?> createIncident(IncidentModel incident) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.incidentsUrl}/'),
        headers: _headers,
        body: jsonEncode(incident.toJson()),
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      return IncidentModel.fromJson(jsonDecode(responseData.body));
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return null;
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return null;
    } catch (e) {
      debugPrint('❌ Error creating incident: $e');
      return null;
    }
  }

  static Future<List<IncidentModel>> getIncidents({
    int skip = 0,
    int limit = 100,
    bool? isActive,
    String? incidentType,
  }) async {
    try {
      var url = '${ApiConfig.incidentsUrl}/?skip=$skip&limit=$limit';
      if (isActive != null) {
        url += '&is_active=$isActive';
      }
      if (incidentType != null) {
        url += '&incident_type=$incidentType';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      final List<dynamic> data = jsonDecode(responseData.body);
      return data.map((json) => IncidentModel.fromJson(json)).toList();
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return [];
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching incidents: $e');
      return [];
    }
  }

  static Future<List<IncidentModel>> getActiveIncidents() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.incidentsUrl}/active'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      final List<dynamic> data = jsonDecode(responseData.body);
      return data.map((json) => IncidentModel.fromJson(json)).toList();
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return [];
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching active incidents: $e');
      return [];
    }
  }

  static Future<IncidentModel?> getIncident(int incidentId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.incidentsUrl}/$incidentId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      return IncidentModel.fromJson(jsonDecode(responseData.body));
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return null;
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching incident: $e');
      return null;
    }
  }

  static Future<IncidentModel?> updateIncident(
      int incidentId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.incidentsUrl}/$incidentId'),
        headers: _headers,
        body: jsonEncode(updates),
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      return IncidentModel.fromJson(jsonDecode(responseData.body));
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return null;
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return null;
    } catch (e) {
      debugPrint('❌ Error updating incident: $e');
      return null;
    }
  }

  static Future<bool> deleteIncident(int incidentId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.incidentsUrl}/$incidentId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      await _handleResponse(response);
      return true;
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return false;
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting incident: $e');
      return false;
    }
  }

  // User endpoints
  static Future<List<UserModel>> getUsers({
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.usersUrl}/?skip=$skip&limit=$limit'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      final List<dynamic> data = jsonDecode(responseData.body);
      return data.map((json) => UserModel.fromJson(json)).toList();
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return [];
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching users: $e');
      return [];
    }
  }

  static Future<UserModel?> getUser(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.usersUrl}/$userId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      return UserModel.fromJson(jsonDecode(responseData.body));
    } on SocketException {
      debugPrint('⚠️ Server unavailable');
      return null;
    } on TimeoutException {
      debugPrint('⚠️ Server timeout');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching user: $e');
      return null;
    }
  }

  // Weather endpoints - using Open-Meteo API directly (no server needed)
  static Future<WeatherModel> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Try server first
      final response = await http.get(
        Uri.parse('${ApiConfig.weatherUrl}/current?latitude=$latitude&longitude=$longitude'),
        headers: _headers,
      ).timeout(const Duration(seconds: 3));

      final responseData = await _handleResponse(response);
      return WeatherModel.fromJson(jsonDecode(responseData.body));
    } catch (e) {
      // Fallback to Open-Meteo API directly
      debugPrint('⚠️ Server unavailable, using Open-Meteo directly');
      return _getWeatherFromOpenMeteo(latitude, longitude);
    }
  }
  
  static Future<WeatherModel> _getWeatherFromOpenMeteo(double latitude, double longitude) async {
    try {
      final url = 'https://api.open-meteo.com/v1/forecast'
          '?latitude=$latitude'
          '&longitude=$longitude'
          '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,precipitation'
          '&timezone=auto';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        
        return WeatherModel(
          latitude: latitude,
          longitude: longitude,
          temperature: (current['temperature_2m'] ?? 25.0).toDouble(),
          humidity: (current['relative_humidity_2m'] ?? 70).toDouble(),
          description: _getWeatherDescription(current['weather_code'] ?? 0),
          weatherCode: current['weather_code'] ?? 0,
          windSpeed: (current['wind_speed_10m'] ?? 0.0).toDouble(),
          precipitation: (current['precipitation'] ?? 0.0).toDouble(),
          rain: (current['precipitation'] ?? 0.0).toDouble(),
          timestamp: DateTime.now(),
        );
      }
      throw Exception('Failed to fetch weather');
    } catch (e) {
      debugPrint('❌ Open-Meteo error: $e');
      // Return default weather if all fails
      return WeatherModel(
        latitude: latitude,
        longitude: longitude,
        temperature: 28.0,
        humidity: 75.0,
        description: 'Weather data unavailable',
        weatherCode: 0,
        windSpeed: 10.0,
        precipitation: 0.0,
        rain: 0.0,
        timestamp: DateTime.now(),
      );
    }
  }
  
  static String _getWeatherDescription(int code) {
    if (code == 0) return 'Clear sky';
    if (code <= 3) return 'Partly cloudy';
    if (code <= 49) return 'Fog';
    if (code <= 59) return 'Drizzle';
    if (code <= 69) return 'Rain';
    if (code <= 79) return 'Snow';
    if (code <= 84) return 'Rain showers';
    if (code <= 94) return 'Snow showers';
    return 'Thunderstorm';
  }

  static Future<WeatherForecast> getWeatherForecast({
    required double latitude,
    required double longitude,
    int days = 7,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.weatherUrl}/forecast?latitude=$latitude&longitude=$longitude&days=$days'),
        headers: _headers,
      ).timeout(const Duration(seconds: 3));

      final responseData = await _handleResponse(response);
      return WeatherForecast.fromJson(jsonDecode(responseData.body));
    } catch (e) {
      // Fallback to Open-Meteo API directly
      debugPrint('⚠️ Server unavailable, using Open-Meteo directly for forecast');
      return _getForecastFromOpenMeteo(latitude, longitude, days);
    }
  }
  
  static Future<WeatherForecast> _getForecastFromOpenMeteo(double latitude, double longitude, int days) async {
    try {
      final url = 'https://api.open-meteo.com/v1/forecast'
          '?latitude=$latitude'
          '&longitude=$longitude'
          '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max'
          '&timezone=auto'
          '&forecast_days=$days';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final daily = data['daily'];
        
        final List<WeatherForecastDay> forecastDays = [];
        final dates = daily['time'] as List;
        
        for (int i = 0; i < dates.length; i++) {
          final code = daily['weather_code'][i] ?? 0;
          final precipValue = (daily['precipitation_sum'][i] ?? 0.0).toDouble();
          forecastDays.add(WeatherForecastDay(
            date: dates[i],
            weatherCode: code,
            temperatureMax: (daily['temperature_2m_max'][i] ?? 30.0).toDouble(),
            temperatureMin: (daily['temperature_2m_min'][i] ?? 20.0).toDouble(),
            precipitation: precipValue,
            rain: precipValue, // Open-Meteo doesn't separate rain from precipitation
            description: _getWeatherDescription(code),
            windSpeedMax: (daily['wind_speed_10m_max'][i] ?? 0.0).toDouble(),
          ));
        }
        
        return WeatherForecast(
          latitude: latitude,
          longitude: longitude,
          timezone: data['timezone'] ?? 'Asia/Manila',
          forecast: forecastDays,
        );
      }
      throw Exception('Failed to fetch forecast');
    } catch (e) {
      debugPrint('❌ Open-Meteo forecast error: $e');
      // Return empty forecast if all fails
      return WeatherForecast(
        latitude: latitude,
        longitude: longitude,
        timezone: 'Asia/Manila',
        forecast: [],
      );
    }
  }

  // Handbook endpoints - Now handled by GeminiService directly
  // These methods are kept for backward compatibility but are deprecated
  @Deprecated('Use GeminiService.generateHandbook() instead')
  static Future<HandbookResponse> generateHandbook({
    required String weatherDescription,
    required double temperature,
    required double precipitation,
    required double rain,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.handbookUrl}/generate'),
        headers: _headers,
        body: jsonEncode({
          'weather_description': weatherDescription,
          'temperature': temperature,
          'precipitation': precipitation,
          'rain': rain,
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(const Duration(seconds: 10));

      final responseData = await _handleResponse(response);
      return HandbookResponse.fromJson(jsonDecode(responseData.body));
    } catch (e) {
      debugPrint('⚠️ Handbook server unavailable: $e');
      // Return fallback response
      return HandbookResponse(
        weatherSummary: 'Current weather: $weatherDescription at ${temperature.toStringAsFixed(1)}°C',
        safetyTips: [],
        floodRiskLevel: 'moderate',
      );
    }
  }

  @Deprecated('Use GeminiService.getStaticTips() instead')
  static Future<List<SafetyTip>> getStaticTips() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.handbookUrl}/static-tips'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      final responseData = await _handleResponse(response);
      final List<dynamic> data = jsonDecode(responseData.body);
      return data.map((tip) => SafetyTip.fromJson(tip)).toList();
    } catch (e) {
      debugPrint('⚠️ Static tips unavailable: $e');
      return [];
    }
  }
}
