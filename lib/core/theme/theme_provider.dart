import 'package:flutter/material.dart';

/// Theme Provider for managing theme based on system preference
/// Automatically respects system dark/light mode setting
class ThemeProvider with ChangeNotifier {
  Brightness? _systemBrightness;

  bool get isDarkMode {
    // Default to dark if not initialized
    return _systemBrightness != Brightness.light;
  }

  ThemeMode get themeMode => ThemeMode.system;

  ThemeProvider();

  /// Update system brightness from MediaQuery
  /// Call this from the app's build method to listen to system theme changes
  void updateFromMediaQuery(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    if (_systemBrightness != brightness) {
      _systemBrightness = brightness;
      notifyListeners();
    }
  }

  /// Manually update system brightness
  void updateSystemBrightness(Brightness brightness) {
    if (_systemBrightness != brightness) {
      _systemBrightness = brightness;
      notifyListeners();
    }
  }
}
