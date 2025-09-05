import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.dark;
  
  ThemeMode get themeMode => _themeMode;
  
  bool get isDarkMode => true; // Always dark mode
  bool get isLightMode => false; // Never light mode
  
  ThemeProvider() {
    _loadThemeMode();
  }
  
  /// Load saved theme mode from preferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString(_themeKey);
      
      // Always use dark mode regardless of saved preference
      _themeMode = ThemeMode.dark;
      notifyListeners();
    } catch (e) {
      print('Error loading theme mode: $e');
      // Default to dark mode on error
      _themeMode = ThemeMode.dark;
      notifyListeners();
    }
  }
  
  /// Save theme mode to preferences
  Future<void> _saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, 'dark'); // Always save dark mode
    } catch (e) {
      print('Error saving theme mode: $e');
    }
  }
  
  /// Toggle between light and dark mode (disabled - always dark)
  void toggleTheme() {
    // Do nothing - always dark mode
    _themeMode = ThemeMode.dark;
    _saveThemeMode();
    notifyListeners();
  }
  
  /// Set specific theme mode (disabled - always dark)
  void setThemeMode(ThemeMode mode) {
    // Always use dark mode regardless of input
    _themeMode = ThemeMode.dark;
    _saveThemeMode();
    notifyListeners();
  }
  
  /// Get theme data based on current mode (always dark)
  ThemeData getThemeData() {
    return AppConfig.getDarkTheme();
  }
  
  /// Get background color based on current theme (always dark)
  Color getBackgroundColor() {
    return AppConfig.darkBackground;
  }
  
  /// Get surface color based on current theme (always dark)
  Color getSurfaceColor() {
    return AppConfig.darkSurface;
  }
  
  /// Get card color based on current theme (always dark)
  Color getCardColor() {
    return AppConfig.darkCard;
  }
  
  /// Get text color based on current theme (always dark)
  Color getTextColor() {
    return AppConfig.darkText;
  }
  
  /// Get secondary text color based on current theme (always dark)
  Color getSecondaryTextColor() {
    return AppConfig.darkTextSecondary;
  }
  
  /// Get border color based on current theme (always dark)
  Color getBorderColor() {
    return AppConfig.darkBorder;
  }
}
