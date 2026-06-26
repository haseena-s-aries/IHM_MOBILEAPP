import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeColors {
  final Color bg;
  final Color bgCard;
  final Color bgCardAlt;
  final Color textPrimary;
  final Color textSecond;
  final Color divider;
  final Color primary;

  const AppThemeColors({
    required this.bg,
    required this.bgCard,
    required this.bgCardAlt,
    required this.textPrimary,
    required this.textSecond,
    required this.divider,
    required this.primary,
  });
}

class ThemeNotifier extends ChangeNotifier {
  static const _prefKey = 'isDarkMode';

  bool _isDarkMode;

  ThemeNotifier({bool isDarkMode = false}) : _isDarkMode = isDarkMode;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  AppThemeColors get colors => _isDarkMode
      ? const AppThemeColors(
          bg: Color(0xFF0D1B2A),
          bgCard: Color(0xFF152235),
          bgCardAlt: Color(0xFF1A2C42),
          textPrimary: Color(0xFFE8F0FE),
          textSecond: Color(0xFF8FA8C4),
          divider: Color(0xFF1E3A55),
          primary: Color(0xFF4BA3F5),
        )
      : const AppThemeColors(
          bg: Color(0xFFF0F4FA),
          bgCard: Colors.white,
          bgCardAlt: Color(0xFFEAF0F9),
          textPrimary: Color(0xFF0D1B2A),
          textSecond: Color(0xFF4A6580),
          divider: Color(0xFFCDD9E8),
          primary: Color(0xFF6A5ACD),
        );

  Future<void> toggleTheme() async {
    await setDarkMode(!_isDarkMode);
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;

    _isDarkMode = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  static Future<bool> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }
}
