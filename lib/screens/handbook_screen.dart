import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/gemini_service.dart';
import '../models/api_models.dart';

class HandbookScreen extends StatefulWidget {
  const HandbookScreen({Key? key}) : super(key: key);

  @override
  State<HandbookScreen> createState() => _HandbookScreenState();
}

class _HandbookScreenState extends State<HandbookScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  HandbookResponse? _handbookData;
  WeatherModel? _currentWeather;
  WeatherForecast? _weatherForecast;
  final Map<String, bool> _checkedItems = {};

  @override
  void initState() {
    super.initState();
    _loadHandbook();
  }

  Future<void> _loadHandbook() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get current weather
      final weather = await ApiService.getCurrentWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      // Get weather forecast
      final forecast = await ApiService.getWeatherForecast(
        latitude: position.latitude,
        longitude: position.longitude,
        days: 7,
      );

      setState(() {
        _currentWeather = weather;
        _weatherForecast = forecast;
      });

      // Generate handbook using Gemini AI directly (no server needed)
      final handbook = await GeminiService.generateHandbook(
        weatherDescription: weather.description,
        temperature: weather.temperature,
        precipitation: weather.precipitation,
        rain: weather.rain,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      setState(() {
        _handbookData = handbook;
        _isLoading = false;
        // Initialize checkbox states for each tip
        _checkedItems.clear();
        for (var i = 0; i < handbook.safetyTips.length; i++) {
          _checkedItems['tip_$i'] = false;
        }
      });
    } catch (e) {
      print('❌ Error loading handbook: $e');
      // Try to load static tips as fallback
      try {
        final staticTips = GeminiService.getStaticTips();
        setState(() {
          _handbookData = HandbookResponse(
            weatherSummary: _currentWeather != null
                ? 'Current weather: ${_currentWeather!.description} at ${_currentWeather!.temperature.toStringAsFixed(1)}°C'
                : 'Weather data unavailable. Here are general safety tips.',
            safetyTips: staticTips,
            floodRiskLevel: 'moderate',
          );
          _errorMessage = 'Using offline safety tips';
          _isLoading = false;
          // Initialize checkbox states
          _checkedItems.clear();
          for (var i = 0; i < staticTips.length; i++) {
            _checkedItems['tip_$i'] = false;
          }
        });
      } catch (fallbackError) {
        setState(() {
          _errorMessage = 'Failed to load safety tips: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow[700]!;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Icons.warning;
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.info;
      case 'low':
        return Icons.tips_and_updates;
      default:
        return Icons.check_circle;
    }
  }

  String _getRiskLevelDescription(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return 'Severe weather conditions detected';
      case 'moderate':
        return 'Moderate flood risk in your area';
      case 'low':
        return 'Weather conditions are currently favorable';
      default:
        return 'Unknown risk level';
    }
  }

  Color _getRiskLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Storm detection based on weather codes
  // Weather codes 95-99 are thunderstorms, 61-67 are rain, 71-77 are snow
  bool _isStormyWeather(int weatherCode) {
    return weatherCode >= 95 || // Thunderstorms
        (weatherCode >= 80 && weatherCode <= 82) || // Rain showers
        (weatherCode >= 61 && weatherCode <= 67); // Rain
  }

  bool _hasStormWarning() {
    if (_weatherForecast == null) return false;
    return _weatherForecast!.forecast.any((day) => 
      _isStormyWeather(day.weatherCode) || 
      day.precipitation > 20 || 
      day.windSpeedMax > 50
    );
  }

  List<WeatherForecastDay> _getStormDays() {
    if (_weatherForecast == null) return [];
    return _weatherForecast!.forecast.where((day) => 
      _isStormyWeather(day.weatherCode) || 
      day.precipitation > 20 || 
      day.windSpeedMax > 50
    ).toList();
  }

  String _getWeatherIcon(int weatherCode) {
    if (weatherCode >= 95) return '⛈️'; // Thunderstorm
    if (weatherCode >= 80) return '🌧️'; // Rain showers
    if (weatherCode >= 71) return '🌨️'; // Snow
    if (weatherCode >= 61) return '🌧️'; // Rain
    if (weatherCode >= 51) return '🌦️'; // Drizzle
    if (weatherCode >= 45) return '🌫️'; // Fog
    if (weatherCode >= 3) return '☁️'; // Cloudy
    if (weatherCode >= 1) return '⛅'; // Partly cloudy
    return '☀️'; // Clear
  }

  Color _getWeatherSeverityColor(WeatherForecastDay day) {
    if (day.weatherCode >= 95 || day.windSpeedMax > 80) return Colors.red;
    if (day.precipitation > 30 || day.windSpeedMax > 50) return Colors.orange;
    if (day.precipitation > 10) return Colors.yellow[700]!;
    return Colors.green;
  }

  Widget _buildForecastSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  '7-Day Weather Forecast',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _weatherForecast!.forecast.length,
                itemBuilder: (context, index) {
                  final day = _weatherForecast!.forecast[index];
                  final date = DateTime.parse(day.date);
                  final dayName = index == 0 
                      ? 'Today' 
                      : index == 1 
                          ? 'Tomorrow'
                          : _getDayName(date.weekday);
                  final isStormDay = _isStormyWeather(day.weatherCode) || 
                                    day.precipitation > 20 || 
                                    day.windSpeedMax > 50;
                  
                  return Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isStormDay 
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isStormDay ? Colors.red : Colors.blue.withValues(alpha: 0.2),
                        width: isStormDay ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          dayName,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isStormDay ? Colors.red[700] : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getWeatherIcon(day.weatherCode),
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.temperatureMax.toStringAsFixed(0)}°',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${day.temperatureMin.toStringAsFixed(0)}°',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (day.precipitation > 0)
                          Text(
                            '${day.precipitation.toStringAsFixed(0)}mm',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color: Colors.blue[700],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildStormAlertCard() {
    final stormDays = _getStormDays();
    if (stormDays.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[700]!, Colors.orange[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚠️ STORM ALERT',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Severe weather expected in your area:',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 12),
              ...stormDays.map((day) {
                final date = DateTime.parse(day.date);
                final dateStr = '${_getDayName(date.weekday)}, ${date.day}/${date.month}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _getWeatherIcon(day.weatherCode),
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dateStr,
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                day.description,
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (day.precipitation > 0)
                              Text(
                                '💧 ${day.precipitation.toStringAsFixed(0)}mm',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            if (day.windSpeedMax > 30)
                              Text(
                                '💨 ${day.windSpeedMax.toStringAsFixed(0)}km/h',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Areas that may be affected: Your current location and surrounding barangays within 10km radius',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkedCount = _checkedItems.values.where((v) => v).length;
    final totalCount = _checkedItems.length;
    final progress = totalCount > 0 ? checkedCount / totalCount : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Handbook'),
        backgroundColor: Colors.blue[700],
        actions: [
          if (totalCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '$checkedCount/$totalCount',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () => _loadHandbook(),
            tooltip: 'Refresh tips',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _handbookData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadHandbook(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHandbook,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Progress bar
                      if (totalCount > 0) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Preparation Progress',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Text(
                              '$checkedCount/$totalCount',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: progress == 1.0 ? Colors.green : Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress == 1.0 ? Colors.green : Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Weather Summary Card
                      if (_currentWeather != null)
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.wb_sunny,
                                      color: Colors.orange[700],
                                      size: 32,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Current Weather',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (_handbookData?.weatherSummary != null)
                                            Text(
                                              _handbookData!.weatherSummary,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _WeatherDetail(
                                      icon: Icons.thermostat,
                                      label: 'Temp',
                                      value: '${_currentWeather!.temperature.toStringAsFixed(1)}°C',
                                    ),
                                    _WeatherDetail(
                                      icon: Icons.water_drop,
                                      label: 'Rain',
                                      value: '${_currentWeather!.precipitation.toStringAsFixed(1)}mm',
                                    ),
                                    _WeatherDetail(
                                      icon: Icons.air,
                                      label: 'Wind',
                                      value: '${_currentWeather!.windSpeed.toStringAsFixed(1)}km/h',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Weather Forecast Section
                      if (_weatherForecast != null) ...[                        
                        const SizedBox(height: 24),
                        _buildForecastSection(),
                      ],

                      // Storm Alert Section
                      if (_weatherForecast != null && _hasStormWarning())
                        _buildStormAlertCard(),

                      const SizedBox(height: 24),

                      // Flood Risk Level Badge
                      if (_handbookData?.floodRiskLevel != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getRiskLevelColor(_handbookData!.floodRiskLevel).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getRiskLevelColor(_handbookData!.floodRiskLevel),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.shield,
                                color: _getRiskLevelColor(_handbookData!.floodRiskLevel),
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_handbookData!.floodRiskLevel.toUpperCase()} RISK',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _getRiskLevelColor(_handbookData!.floodRiskLevel),
                                      ),
                                    ),
                                    Text(
                                      _getRiskLevelDescription(_handbookData!.floodRiskLevel),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Error message banner (if any)
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: Colors.orange),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_errorMessage!)),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Safety Tips Header
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Safety Checklist',
                              style: GoogleFonts.montserrat(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_handbookData?.weatherSummary != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 14, color: Colors.blue[700]),
                                  const SizedBox(width: 4),
                                  Text(
                                    'AI',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _handbookData?.weatherSummary != null
                            ? 'AI-generated tasks based on current weather conditions'
                            : 'General flood safety preparation tasks',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Safety Tips List as Checkboxes
                      if (_handbookData?.safetyTips != null && _handbookData!.safetyTips.isNotEmpty)
                        ...(_handbookData!.safetyTips.asMap().entries.map((entry) {
                          final index = entry.key;
                          final tip = entry.value;
                          final key = 'tip_$index';
                          final isChecked = _checkedItems[key] ?? false;
                          return _ChecklistTipCard(
                            tip: tip,
                            number: index + 1,
                            isChecked: isChecked,
                            onChanged: (value) {
                              setState(() {
                                _checkedItems[key] = value ?? false;
                              });
                            },
                            priorityColor: _getPriorityColor(tip.priority),
                            priorityIcon: _getPriorityIcon(tip.priority),
                          );
                        }).toList()),

                      if (_handbookData?.safetyTips == null || _handbookData!.safetyTips.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('No safety tips available'),
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Footer
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Check off items as you complete them. Pull down to refresh with latest weather conditions.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                color: Colors.blue[700],
                                fontSize: 12,
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

class _WeatherDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue[700], size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _ChecklistTipCard extends StatelessWidget {
  final SafetyTip tip;
  final int number;
  final bool isChecked;
  final ValueChanged<bool?> onChanged;
  final Color priorityColor;
  final IconData priorityIcon;

  const _ChecklistTipCard({
    required this.tip,
    required this.number,
    required this.isChecked,
    required this.onChanged,
    required this.priorityColor,
    required this.priorityIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: isChecked ? Colors.green[50] : Colors.white,
      child: InkWell(
        onTap: () => onChanged(!isChecked),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: isChecked ? Colors.green : priorityColor,
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: isChecked,
                    onChanged: onChanged,
                    activeColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Number badge
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isChecked 
                                  ? Colors.green.withOpacity(0.2)
                                  : priorityColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$number',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isChecked ? Colors.green : priorityColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Priority badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isChecked 
                                  ? Colors.green.withOpacity(0.1)
                                  : priorityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isChecked ? Colors.green : priorityColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  priorityIcon,
                                  size: 12,
                                  color: isChecked ? Colors.green : priorityColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tip.priority.toUpperCase(),
                                  style: GoogleFonts.montserrat(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isChecked ? Colors.green : priorityColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tip.title,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                          color: isChecked ? Colors.grey[600] : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tip.description,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: isChecked ? Colors.grey[500] : Colors.grey[700],
                          height: 1.5,
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
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
