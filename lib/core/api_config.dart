import 'dart:io';

class ApiConfig {
  // Automatically use the correct host based on platform
  static String get _host {
    if (Platform.isAndroid) {
      // Android emulator needs 10.0.2.2 to access host machine's localhost
      return '10.0.2.2';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost
      return 'localhost';
    } else {
      // Desktop (Windows/Mac/Linux) uses localhost
      return 'localhost';
    }
  }
  
  static String get baseUrl => 'http://$_host:8000/api';
  
  // For physical device testing, uncomment and set your IP:
  // static String get baseUrl => 'http://192.168.1.X:8000/api';
  
  // Endpoints
  static const String auth = '/auth';
  static const String users = '/users';
  static const String reports = '/reports';
  static const String incidents = '/incidents';
  static const String weather = '/weather';
  static const String handbook = '/handbook';
  static const String scenario = '/scenario';
  
  // Full URLs
  static String get authUrl => '$baseUrl$auth';
  static String get usersUrl => '$baseUrl$users';
  static String get reportsUrl => '$baseUrl$reports';
  static String get incidentsUrl => '$baseUrl$incidents';
  static String get weatherUrl => '$baseUrl$weather';
  static String get handbookUrl => '$baseUrl$handbook';
  static String get scenarioUrl => '$baseUrl$scenario';
}
