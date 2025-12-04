enum IncidentType {
  flood,
  evacuationCenter,
  emergencyServices;

  String toJson() {
    switch (this) {
      case IncidentType.flood:
        return 'flood';
      case IncidentType.evacuationCenter:
        return 'evacuation_center';
      case IncidentType.emergencyServices:
        return 'emergency_services';
    }
  }
  
  static IncidentType fromJson(String json) {
    switch (json.toLowerCase()) {
      case 'flood':
        return IncidentType.flood;
      case 'evacuation_center':
        return IncidentType.evacuationCenter;
      case 'emergency_services':
        return IncidentType.emergencyServices;
      default:
        return IncidentType.flood;
    }
  }

  String get displayName {
    switch (this) {
      case IncidentType.flood:
        return 'Flood';
      case IncidentType.evacuationCenter:
        return 'Evacuation Center';
      case IncidentType.emergencyServices:
        return 'Emergency Services';
    }
  }
}

class ReportModel {
  final int? id;
  final int? userId;
  final IncidentType incidentType;
  final double latitude;
  final double longitude;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? isVerified;
  final int upvoteCount;

  ReportModel({
    this.id,
    this.userId,
    required this.incidentType,
    required this.latitude,
    required this.longitude,
    this.description,
    this.createdAt,
    this.updatedAt,
    this.isVerified,
    this.upvoteCount = 0,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'],
      userId: json['user_id'],
      incidentType: IncidentType.fromJson(json['incident_type']),
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      description: json['description'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      isVerified: json['is_verified'] ?? false,
      upvoteCount: json['upvote_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'incident_type': incidentType.toJson(),
      'latitude': latitude,
      'longitude': longitude,
      if (description != null) 'description': description,
    };
  }
}

class IncidentModel {
  final int? id;
  final String title;
  final IncidentType incidentType;
  final double latitude;
  final double longitude;
  final String? description;
  final double severityScore;
  final double affectedAreaRadius;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final int reportCount;

  IncidentModel({
    this.id,
    required this.title,
    required this.incidentType,
    required this.latitude,
    required this.longitude,
    this.description,
    this.severityScore = 0.0,
    this.affectedAreaRadius = 300.0,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.reportCount = 1,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id'],
      title: json['title'],
      incidentType: IncidentType.fromJson(json['incident_type']),
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      description: json['description'],
      severityScore: json['severity_score']?.toDouble() ?? 0.0,
      affectedAreaRadius: json['affected_area_radius']?.toDouble() ?? 300.0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
      isActive: json['is_active'] ?? true,
      reportCount: json['report_count'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'incident_type': incidentType.toJson(),
      'latitude': latitude,
      'longitude': longitude,
      if (description != null) 'description': description,
      'severity_score': severityScore,
      'affected_area_radius': affectedAreaRadius,
      'is_active': isActive,
      'report_count': reportCount,
    };
  }
}

class ReportStats {
  final int infoCount;
  final int criticalCount;
  final int warningCount;
  final int totalCount;
  final String date;

  ReportStats({
    required this.infoCount,
    required this.criticalCount,
    required this.warningCount,
    required this.totalCount,
    required this.date,
  });

  factory ReportStats.fromJson(Map<String, dynamic> json) {
    return ReportStats(
      infoCount: json['info_count'] ?? 0,
      criticalCount: json['critical_count'] ?? 0,
      warningCount: json['warning_count'] ?? 0,
      totalCount: json['total_count'] ?? 0,
      date: json['date'] ?? '',
    );
  }
}

class UserModel {
  final int? id;
  final String email;
  final String username;
  final String? password;
  final DateTime? createdAt;
  final bool? isActive;

  UserModel({
    this.id,
    required this.email,
    required this.username,
    this.password,
    this.createdAt,
    this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      username: json['username'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'email': email,
      'username': username,
      if (password != null) 'password': password,
    };
  }
}

class AuthToken {
  final String accessToken;
  final String tokenType;

  AuthToken({
    required this.accessToken,
    required this.tokenType,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
    );
  }
}

class WeatherModel {
  final double latitude;
  final double longitude;
  final double temperature;
  final double? humidity;
  final double precipitation;
  final double rain;
  final int weatherCode;
  final String description;
  final double windSpeed;
  final double? windDirection;
  final DateTime timestamp;

  WeatherModel({
    required this.latitude,
    required this.longitude,
    required this.temperature,
    this.humidity,
    required this.precipitation,
    required this.rain,
    required this.weatherCode,
    required this.description,
    required this.windSpeed,
    this.windDirection,
    required this.timestamp,
  });

  factory WeatherModel.fromJson(Map<String, dynamic> json) {
    return WeatherModel(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      temperature: json['temperature'].toDouble(),
      humidity: json['humidity']?.toDouble(),
      precipitation: json['precipitation'].toDouble(),
      rain: json['rain'].toDouble(),
      weatherCode: json['weather_code'],
      description: json['description'],
      windSpeed: json['wind_speed'].toDouble(),
      windDirection: json['wind_direction']?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class WeatherForecastDay {
  final String date;
  final double temperatureMax;
  final double temperatureMin;
  final double precipitation;
  final double rain;
  final int weatherCode;
  final String description;
  final double windSpeedMax;

  WeatherForecastDay({
    required this.date,
    required this.temperatureMax,
    required this.temperatureMin,
    required this.precipitation,
    required this.rain,
    required this.weatherCode,
    required this.description,
    required this.windSpeedMax,
  });

  factory WeatherForecastDay.fromJson(Map<String, dynamic> json) {
    return WeatherForecastDay(
      date: json['date'],
      temperatureMax: json['temperature_max'].toDouble(),
      temperatureMin: json['temperature_min'].toDouble(),
      precipitation: json['precipitation'].toDouble(),
      rain: json['rain'].toDouble(),
      weatherCode: json['weather_code'],
      description: json['description'],
      windSpeedMax: json['wind_speed_max'].toDouble(),
    );
  }
}

class WeatherForecast {
  final double latitude;
  final double longitude;
  final String timezone;
  final List<WeatherForecastDay> forecast;

  WeatherForecast({
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.forecast,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final forecastList = (json['forecast'] as List)
        .map((day) => WeatherForecastDay.fromJson(day))
        .toList();

    return WeatherForecast(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      timezone: json['timezone'],
      forecast: forecastList,
    );
  }
}

class SafetyTip {
  final String title;
  final String description;
  final String priority;

  SafetyTip({
    required this.title,
    required this.description,
    required this.priority,
  });

  factory SafetyTip.fromJson(Map<String, dynamic> json) {
    return SafetyTip(
      title: json['title'],
      description: json['description'],
      priority: json['priority'],
    );
  }
}

class HandbookResponse {
  final String weatherSummary;
  final List<SafetyTip> safetyTips;
  final String floodRiskLevel;

  HandbookResponse({
    required this.weatherSummary,
    required this.safetyTips,
    required this.floodRiskLevel,
  });

  factory HandbookResponse.fromJson(Map<String, dynamic> json) {
    final tipsList = (json['safety_tips'] as List)
        .map((tip) => SafetyTip.fromJson(tip))
        .toList();

    return HandbookResponse(
      weatherSummary: json['weather_summary'],
      safetyTips: tipsList,
      floodRiskLevel: json['flood_risk_level'],
    );
  }
}
