import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/appwrite_config.dart';

class AuthService extends ChangeNotifier {
  late Client _client;
  late Account _account;
  late Databases _databases;

  User? _currentUser;
  String? _currentPhone; // Store current phone for session management
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;

  AuthService() {
    _initializeAppwrite();
  }

  void _initializeAppwrite() {
    if (!AppwriteConfig.isConfigured) {
      print('⚠️  WARNING: Appwrite is not configured!');
      print(
        'Please update lib/core/config/appwrite_config.dart with your project details.',
      );
      print('Get your Project ID from: https://cloud.appwrite.io');
      return;
    }

    _client = Client()
      ..setEndpoint(AppwriteConfig.endpoint)
      ..setProject(AppwriteConfig.projectId);

    _account = Account(_client);
    _databases = Databases(_client);

    print('✓ Appwrite initialized with endpoint: ${AppwriteConfig.endpoint}');
    print('✓ Project ID: ${AppwriteConfig.projectId}');

    // Check if user is already logged in
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if user has active session
      _currentUser = await _account.get();

      // Also check stored phone session
      await _getStoredPhoneSession();

      notifyListeners();
    } catch (e) {
      // No active session is normal on first launch
      if (e is AppwriteException && e.code != 401) {
        debugPrint('⚠️  Auth state check error: ${e.message} (${e.code})');
      }
      _currentUser = null;
      _currentPhone = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String fullName,
    required String phone,
    required String gender,
    required DateTime birthday,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final age = _calculateAge(birthday);

      // Check if phone number already exists
      final existingUser = await _checkPhoneExists(phone);
      if (existingUser) {
        _showErrorToUser('Phone number already registered. Please use login.');
        return false;
      }

      // Delete any existing session first
      try {
        await _account.deleteSession(sessionId: 'current');
        debugPrint('Deleted existing session before registration');
      } catch (e) {
        // No existing session, which is fine
        debugPrint('No existing session to delete before registration');
      }

      // Create anonymous user session
      final user = await _account.createAnonymousSession();

      // Store user data in database with phone as identifier
      await _databases.createDocument(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.usersCollectionId,
        documentId: ID.unique(),
        data: {
          'user_id': user.userId,
          'full_name': fullName,
          'phone_number': phone,
          'gender': gender,
          'birthday': birthday.toIso8601String(),
          'age': age,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      // Update current user
      _currentUser = await _account.get();

      // Store phone number for session identification
      await _storePhoneSession(phone);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Registration error: $e');
      if (e is AppwriteException && e.code == 401) {
        _showErrorToUser(
          'Cannot connect to server. Please check your internet connection and try again.',
        );
      } else {
        _showErrorToUser(e);
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String phone}) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if user exists with this phone number
      final userData = await _getUserByPhone(phone);
      if (userData == null) {
        _showErrorToUser('Phone number not registered. Please register first.');
        return false;
      }

      // Delete any existing session first
      try {
        await _account.deleteSession(sessionId: 'current');
        debugPrint('Deleted existing session');
      } catch (e) {
        // No existing session, which is fine
        debugPrint('No existing session to delete');
      }

      // Create anonymous session for this user
      await _account.createAnonymousSession();

      // Update current user
      _currentUser = await _account.get();

      // Store phone number for session identification
      await _storePhoneSession(phone);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      _showErrorToUser(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      if (_currentUser == null) return null;

      // Get phone number from session storage
      final phone = await _getStoredPhoneSession();
      if (phone == null) return null;

      // Query the database for user data by phone
      final userData = await _getUserByPhone(phone);
      return userData;
    } catch (e) {
      debugPrint('Get user data error: $e');
      return null;
    }
  }

  Future<bool> _checkPhoneExists(String phone) async {
    try {
      final documents = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.usersCollectionId,
        queries: [Query.equal('phone_number', phone)],
      );
      return documents.documents.isNotEmpty;
    } catch (e) {
      if (e is AppwriteException) {
        debugPrint('❌ Appwrite Error (${e.code}): ${e.message}');
        debugPrint('   Database: ${AppwriteConfig.databaseId}');
        debugPrint('   Collection: ${AppwriteConfig.usersCollectionId}');
        debugPrint('   Endpoint: ${AppwriteConfig.endpoint}');
        debugPrint('   Project: ${AppwriteConfig.projectId}');
      } else {
        debugPrint('Check phone exists error: $e');
      }
      throw e; // Throw to show user-friendly error
    }
  }

  Future<Map<String, dynamic>?> _getUserByPhone(String phone) async {
    try {
      final documents = await _databases.listDocuments(
        databaseId: AppwriteConfig.databaseId,
        collectionId: AppwriteConfig.usersCollectionId,
        queries: [Query.equal('phone_number', phone)],
      );

      if (documents.documents.isNotEmpty) {
        return documents.documents.first.data;
      }
      return null;
    } catch (e) {
      debugPrint('Get user by phone error: $e');
      return null;
    }
  }

  Future<void> _storePhoneSession(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', phone);
      _currentPhone = phone;
    } catch (e) {
      debugPrint('Store phone session error: $e');
    }
  }

  Future<String?> _getStoredPhoneSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('user_phone');
      _currentPhone = phone;
      return phone;
    } catch (e) {
      debugPrint('Get stored phone session error: $e');
      return null;
    }
  }

  Future<void> _clearStoredPhoneSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_phone');
      _currentPhone = null;
    } catch (e) {
      debugPrint('Clear stored phone session error: $e');
    }
  }

  Future<void> logout() async {
    try {
      await _account.deleteSession(sessionId: 'current');
      await _clearStoredPhoneSession();
      _currentUser = null;
      _currentPhone = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
      // Even if logout fails, clear local user state
      await _clearStoredPhoneSession();
      _currentUser = null;
      _currentPhone = null;
      notifyListeners();
    }
  }

  String _phoneToEmail(String phone) {
    // Convert phone number to email format for Appwrite
    // Remove any special characters and spaces
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$cleanPhone@bagabugs.local';
  }

  String _generatePassword(String phone) {
    // Generate a simple password based on phone number
    // In production, you should use a more secure method
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return 'BagaBugs_$cleanPhone';
  }

  void _showErrorToUser(dynamic error) {
    // Handle specific Appwrite errors
    String errorMessage = 'An error occurred';

    if (error is AppwriteException) {
      switch (error.code) {
        case 409:
          errorMessage = 'User already exists with this phone number';
          break;
        case 401:
          errorMessage = 'Invalid phone number or user not registered';
          break;
        case 429:
          errorMessage = 'Too many attempts. Please try again later';
          break;
        default:
          errorMessage = error.message ?? 'Authentication failed';
      }
    } else {
      errorMessage = error.toString();
    }

    debugPrint('Auth Error: $errorMessage');
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
