import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppwriteConfig {
  static String get endpoint =>
      dotenv.env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';

  static String get projectId => dotenv.env['APPWRITE_PROJECT_ID'] ?? '';

  // Database configuration
  static String get databaseId => dotenv.env['APPWRITE_DATABASE_ID'] ?? '';
  static String get usersCollectionId =>
      dotenv.env['APPWRITE_USERS_COLLECTION_ID'] ?? 'users';

  // Check if configuration is valid
  static bool get isConfigured =>
      projectId.isNotEmpty &&
      projectId != 'YOUR_PROJECT_ID_HERE' &&
      endpoint.isNotEmpty;
}
