import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/api_models.dart';

/// Service for interacting with Google Gemini AI API directly via REST API
class GeminiService {
  static String? _apiKey;
  static bool _isInitialized = false;
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1/models/gemini-2.0-flash:generateContent';

  /// Initialize the Gemini service with API key from environment
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    _apiKey = dotenv.env['GEMINI_API_KEY'];
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('❌ Gemini API key not found in environment');
      return false;
    }

    _isInitialized = true;
    debugPrint('✅ Gemini service initialized');
    return true;
  }

  /// Check if service is ready
  static bool get isReady => _isInitialized && _apiKey != null && _apiKey!.isNotEmpty;

  /// Generate contextual safety handbook based on weather conditions
  static Future<HandbookResponse> generateHandbook({
    required String weatherDescription,
    required double temperature,
    required double precipitation,
    required double rain,
    required double latitude,
    required double longitude,
    bool isEmergency = false,
    bool isPostStorm = false,
  }) async {
    if (!isReady) {
      final initialized = await initialize();
      if (!initialized) {
        return _getFallbackResponse(weatherDescription, temperature, rain);
      }
    }

    String emergencyContext = '';
    if (isEmergency) {
      emergencyContext = '''

🚨 EMERGENCY ALERT: A severe tropical storm is currently approaching and expected to make landfall soon.
Expected conditions:
- Peak rainfall: 125mm/hour
- Wind speeds: 110 km/h with gusts up to 145 km/h
- Severe flood risk across low-lying areas
- Multiple municipalities under evacuation orders

This is an ACTIVE EMERGENCY SITUATION. Focus on IMMEDIATE life-saving actions.
''';
    } else if (isPostStorm) {
      emergencyContext = '''

✅ POST-STORM UPDATE: The storm has passed the area. Weather conditions are improving.
Current situation:
- Rain has stopped or significantly reduced
- Winds are calming
- Some areas may still have standing water
- Flood waters are receding

Focus on POST-DISASTER recovery and safety.
''';
    }

    final prompt = '''You are a flood safety expert in the Philippines. Based on the current weather conditions, generate a safety handbook with actionable tips.

Current Weather:
- Description: $weatherDescription
- Temperature: ${temperature.toStringAsFixed(1)}°C
- Precipitation: ${precipitation.toStringAsFixed(1)}mm
- Rain: ${rain.toStringAsFixed(1)}mm
- Location: ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}
$emergencyContext

Please provide:
1. A very brief description (a single sentence)${isEmergency ? " - EMPHASIZE EMERGENCY SEVERITY" : (isPostStorm ? " - EMPHASIZE STORM HAS PASSED" : "")}
2. ${isEmergency ? "3-5 CRITICAL EMERGENCY ACTIONS" : (isPostStorm ? "6-8 POST-STORM RECOVERY ACTIONS" : "5-7 specific safety tips")} based on these conditions
3. Flood risk assessment (low/moderate/high/severe)

IMPORTANT: Each safety tip description must be exactly ONE SENTENCE - brief and actionable.

Format your response as JSON with this structure:
{
  "weather_summary": "Brief summary here",
  "flood_risk_level": "low/moderate/high/severe",
  "safety_tips": [
    {
      "title": "Tip title",
      "description": "Detailed description",
      "priority": "high/medium/low"
    }
  ]
}

Focus on:
${isEmergency ? "- IMMEDIATE EVACUATION procedures" : (isPostStorm ? "- Damage assessment procedures" : "- Flood preparedness and prevention")}
${isEmergency ? "- Life-threatening hazards to avoid" : (isPostStorm ? "- Post-flood health and safety hazards" : "- Immediate actions to take")}
${isEmergency ? "- Emergency shelter locations" : (isPostStorm ? "- When it's safe to return home" : "- What to avoid")}
${isEmergency ? "- Critical supplies needed NOW" : (isPostStorm ? "- Recovery resources and assistance" : "- Emergency contacts and resources")}
- Specific concerns for the Philippines (monsoon, typhoons, etc.)

Make it ${isEmergency ? "URGENT, DIRECTIVE, and potentially life-saving" : (isPostStorm ? "REASSURING but cautious, focused on safe recovery" : "practical, actionable, and relevant to the current weather conditions")}.''';

    try {
      final url = Uri.parse('$_baseUrl?key=$_apiKey');
      
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 2048,
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('❌ Gemini API error: ${response.statusCode} - ${response.body}');
        return _getFallbackResponse(weatherDescription, temperature, rain);
      }

      final responseData = json.decode(response.body) as Map<String, dynamic>;
      
      // Extract text from Gemini response
      final candidates = responseData['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return _getFallbackResponse(weatherDescription, temperature, rain);
      }

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        return _getFallbackResponse(weatherDescription, temperature, rain);
      }

      final responseText = parts[0]['text'] as String? ?? '';

      // Try to extract JSON from response
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(responseText);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final data = json.decode(jsonStr) as Map<String, dynamic>;

        final tipsList = (data['safety_tips'] as List?)
            ?.map((tip) => SafetyTip(
                  title: tip['title'] ?? 'Safety Tip',
                  description: tip['description'] ?? '',
                  priority: tip['priority'] ?? 'medium',
                ))
            .toList() ?? [];

        return HandbookResponse(
          weatherSummary: data['weather_summary'] ?? 'Weather conditions monitored',
          safetyTips: tipsList,
          floodRiskLevel: data['flood_risk_level'] ?? 'moderate',
        );
      }

      // Fallback if JSON parsing fails
      return _getFallbackResponse(weatherDescription, temperature, rain);
    } on SocketException catch (e) {
      debugPrint('❌ Network error (no connection): $e');
      return _getFallbackResponse(weatherDescription, temperature, rain);
    } on TimeoutException catch (e) {
      debugPrint('❌ Request timed out: $e');
      return _getFallbackResponse(weatherDescription, temperature, rain);
    } on http.ClientException catch (e) {
      debugPrint('❌ HTTP client error: $e');
      return _getFallbackResponse(weatherDescription, temperature, rain);
    } catch (e) {
      debugPrint('❌ Gemini generation error: $e');
      return _getFallbackResponse(weatherDescription, temperature, rain);
    }
  }

  /// Get static safety tips (fallback)
  static List<SafetyTip> getStaticTips() {
    return [
      SafetyTip(
        title: 'Monitor Weather Updates',
        description: 'Stay tuned to PAGASA weather bulletins and local news for flood warnings and advisories.',
        priority: 'high',
      ),
      SafetyTip(
        title: 'Prepare Emergency Kit',
        description: 'Keep a waterproof bag with essential items: flashlight, battery-powered radio, first aid kit, important documents, cash, non-perishable food, and drinking water.',
        priority: 'high',
      ),
      SafetyTip(
        title: 'Know Your Evacuation Plan',
        description: 'Identify the nearest evacuation center and plan multiple routes to get there. Keep emergency contact numbers handy.',
        priority: 'high',
      ),
      SafetyTip(
        title: 'Never Walk or Drive Through Floods',
        description: 'Just 15cm (6 inches) of moving water can knock you down. 60cm (2 feet) of water can sweep away most vehicles. Turn around, don\'t drown!',
        priority: 'high',
      ),
      SafetyTip(
        title: 'Secure Your Property',
        description: 'Clear gutters and drains. Store valuables on higher floors. Move furniture and electronics away from windows and potential flood areas.',
        priority: 'medium',
      ),
      SafetyTip(
        title: 'Avoid Electrocution Hazards',
        description: 'Stay away from downed power lines. Turn off electricity if flooding is imminent. Don\'t use electrical appliances if you\'re wet or standing in water.',
        priority: 'high',
      ),
      SafetyTip(
        title: 'Store Safe Drinking Water',
        description: 'Fill clean containers with water before a flood. Flood water is contaminated and unsafe to drink. Boil water if supplies run low.',
        priority: 'medium',
      ),
      SafetyTip(
        title: 'Help Your Community',
        description: 'Check on elderly neighbors and those with special needs. Share verified information through barangay channels.',
        priority: 'low',
      ),
    ];
  }

  /// Fallback response when AI generation fails
  static HandbookResponse _getFallbackResponse(
    String weatherDescription,
    double temperature,
    double rain,
  ) {
    return HandbookResponse(
      weatherSummary: 'Current weather: $weatherDescription at ${temperature.toStringAsFixed(1)}°C',
      safetyTips: [
        SafetyTip(
          title: 'Stay Informed',
          description: 'Monitor weather updates and official advisories from PAGASA.',
          priority: 'high',
        ),
        SafetyTip(
          title: 'Prepare Emergency Kit',
          description: 'Keep food, water, flashlight, radio, and first aid supplies ready.',
          priority: 'high',
        ),
        SafetyTip(
          title: 'Know Evacuation Routes',
          description: 'Familiarize yourself with local evacuation centers and routes.',
          priority: 'medium',
        ),
        SafetyTip(
          title: 'Avoid Flooded Areas',
          description: 'Do not walk or drive through floodwaters. Just 6 inches can knock you down.',
          priority: 'high',
        ),
        SafetyTip(
          title: 'Secure Your Home',
          description: 'Clear drainage systems and secure outdoor items that could be swept away.',
          priority: 'medium',
        ),
      ],
      floodRiskLevel: rain > 10 ? 'high' : (rain > 5 ? 'moderate' : 'low'),
    );
  }

  /// Dispose of resources
  static void dispose() {
    _apiKey = null;
    _isInitialized = false;
  }
}
