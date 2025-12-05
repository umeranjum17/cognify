import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import '../utils/logger.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;
  
  bool get isInitialized => _isInitialized;

  ThemeData get themeData => _themeMode == ThemeMode.dark ? darkTheme : lightTheme;

  ThemeProvider() {
    Logger.debug('🎨 ThemeProvider constructor called', tag: 'ThemeProvider');
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
    Logger.debug('🎨 Starting theme loading...', tag: 'ThemeProvider');
    try {
      final prefs = await SharedPreferences.getInstance();
      Logger.debug('🎨 SharedPreferences obtained', tag: 'ThemeProvider');
      final savedTheme = prefs.getString('theme');
      Logger.debug('🎨 Saved theme: $savedTheme', tag: 'ThemeProvider');
      if (savedTheme != null) {
        final loadedTheme = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
        if (_themeMode != loadedTheme) {
          _themeMode = loadedTheme;
          Logger.debug('🎨 Theme loaded: $_themeMode', tag: 'ThemeProvider');
        }
      }
    } catch (e) {
      Logger.error('🎨 Error loading theme: $e', tag: 'ThemeProvider');
      // Handle error silently - will use default theme
    } finally {
      _isInitialized = true;
      Logger.debug('🎨 Theme provider initialized, notifying listeners', tag: 'ThemeProvider');
      // Only notify listeners once at the end
      notifyListeners();
    }
  }
  
  /// Initialize the theme provider and wait for theme to load
  static Future<ThemeProvider> create() async {
    Logger.debug('🎨 ThemeProvider.create() called', tag: 'ThemeProvider');
    final provider = ThemeProvider();
    // Wait for theme to load with shorter timeout for faster startup
    int attempts = 0;
    while (!provider._isInitialized && attempts < 20) {
      Logger.debug('🎨 Waiting for theme initialization, attempt: ${attempts + 1}', tag: 'ThemeProvider');
      await Future.delayed(const Duration(milliseconds: 5));
      attempts++;
    }
    if (provider._isInitialized) {
      Logger.debug('🎨 ThemeProvider successfully initialized after $attempts attempts', tag: 'ThemeProvider');
    } else {
      Logger.warn('🎨 ThemeProvider initialization timed out after $attempts attempts', tag: 'ThemeProvider');
    }
    return provider;
  }
}
