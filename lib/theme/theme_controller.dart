// theme_controller.dart - ThemeMode persistence via SharedPreferences;
// light / dark / system selection surfaced to MaterialApp.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _prefKey = 'app_theme_mode';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = _parse(prefs.getString(_prefKey) ?? 'light');
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode m) async {
    if (_mode == m) return;
    _mode = m;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, _serialize(m));
    } catch (_) {}
  }

  static ThemeMode _parse(String s) => switch (s) {
    'dark'   => ThemeMode.dark,
    'system' => ThemeMode.system,
    _        => ThemeMode.light,
  };

  static String _serialize(ThemeMode m) => switch (m) {
    ThemeMode.dark   => 'dark',
    ThemeMode.system => 'system',
    _                => 'light',
  };
}

final appThemeCtrl = ThemeController();
