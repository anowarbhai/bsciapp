import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:bsciapp/api/api_service.dart';
import 'package:bsciapp/app_preferences.dart';
import 'package:bsciapp/screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiService = ApiService();
  final hasSession = await apiService.hasValidSession();
  await AppPreferences.load();

  runApp(MyApp(hasToken: hasSession));
}

class MyApp extends StatefulWidget {
  final bool hasToken;

  const MyApp({super.key, required this.hasToken});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _links = AppLinks();
  Uri? _deepLink;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _links.getInitialLink().then((uri) {
      if (mounted && uri != null) setState(() => _deepLink = uri);
    });
    _linkSubscription = _links.uriLinkStream.listen((uri) {
      if (mounted) setState(() => _deepLink = uri);
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppPreferences.themeMode,
      builder: (context, themeMode, _) => ValueListenableBuilder<String>(
        valueListenable: AppPreferences.language,
        builder: (context, language, _) => MaterialApp(
          title: 'BSCI Portal',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          locale: Locale(language),
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFFD32F2F),
            scaffoldBackgroundColor: const Color(0xFFF7F8FC),
            fontFamily: 'Inter',
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD32F2F),
              secondary: Color(0xFF0B2A67),
              surface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              titleTextStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B1739),
              ),
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF5964),
              secondary: Color(0xFF8EB4FF),
              surface: Color(0xFF16213B),
            ),
            scaffoldBackgroundColor: const Color(0xFF0B1730),
            cardTheme: const CardThemeData(color: Color(0xFF16213B)),
            appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF101B34)),
          ),
          home: DashboardScreen(deepLink: _deepLink),
        ),
      ),
    );
  }
}
