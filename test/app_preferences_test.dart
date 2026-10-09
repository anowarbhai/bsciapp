import 'package:bsciapp/app_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'theme and language preferences persist and translate app chrome',
    () async {
      SharedPreferences.setMockInitialValues({});

      await AppPreferences.setTheme(ThemeMode.dark);
      await AppPreferences.setLanguage('bn');

      expect(AppPreferences.themeMode.value, ThemeMode.dark);
      expect(AppPreferences.text('Events', 'ইভেন্ট'), 'ইভেন্ট');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
      expect(prefs.getString('language'), 'bn');
    },
  );
}
