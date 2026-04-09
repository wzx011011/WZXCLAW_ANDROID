import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WzxClawApp());
}

/// Root widget for wzxClaw Android.
class WzxClawApp extends StatelessWidget {
  const WzxClawApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF1A1A2E);
    const surfaceColor = Color(0xFF16213E);
    const accentColor = Color(0xFF6366F1);

    return MaterialApp(
      title: 'wzxClaw',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgColor,
        primaryColor: accentColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: surfaceColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: accentColor,
          secondary: accentColor,
          surface: surfaceColor,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}
