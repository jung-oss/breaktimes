import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String THEME_KEY = 'theme_mode';
  late SharedPreferences _prefs;
  late ThemeMode _themeMode;

  ThemeProvider() {
    _themeMode = ThemeMode.light;
    _loadThemeMode();
  }

  ThemeMode get themeMode => _themeMode;

  Future<void> _loadThemeMode() async {
    _prefs = await SharedPreferences.getInstance();
    final isLightMode = _prefs.getBool(THEME_KEY) ?? true;
    _themeMode = isLightMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setBool(THEME_KEY, _themeMode == ThemeMode.light);
    notifyListeners();
  }
}
