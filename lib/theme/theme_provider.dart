import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;
  
  bool get isInitialized => _isInitialized;

  ThemeData get themeData => _themeMode == ThemeMode.dark ? darkTheme : lightTheme;

  ThemeProvider() {
    _loadTheme();
  }

  void toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    await _saveTheme();
  }
  
  void setTheme(ThemeMode themeMode) async {
    if (_themeMode != themeMode) {
      _themeMode = themeMode;
      notifyListeners();
      await _saveTheme();
    }
  }
  
  Future<void> _saveTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme', _themeMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (e) {
      // Handle error silently - theme will still work in current session
    }
  }

  void _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('theme');
      if (savedTheme != null) {
        final loadedTheme = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
        if (_themeMode != loadedTheme) {
          _themeMode = loadedTheme;
        }
      }
    } catch (e) {
      // Handle error silently - will use default theme
    } finally {
      _isInitialized = true;
      // Only notify listeners once at the end
      notifyListeners();
    }
  }
  
  /// Initialize the theme provider and wait for theme to load
  static Future<ThemeProvider> create() async {
    final provider = ThemeProvider();
    // Wait for theme to load with shorter timeout for faster startup
    int attempts = 0;
    while (!provider._isInitialized && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 5));
      attempts++;
    }
    return provider;
  }
}
