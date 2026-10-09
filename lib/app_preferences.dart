import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static final language = ValueNotifier<String>('en');

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode.value = switch (prefs.getString('theme_mode')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    language.value = prefs.getString('language') ?? 'en';
  }

  static Future<void> setTheme(ThemeMode value) async {
    themeMode.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', value.name);
  }

  static Future<void> setLanguage(String value) async {
    language.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', value);
  }

  static String text(String english, String bangla) =>
      language.value == 'bn' ? bangla : english;
}
