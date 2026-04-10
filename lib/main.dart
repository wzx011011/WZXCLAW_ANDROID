import 'package:flutter/material.dart';

import 'config/app_colors.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'services/session_sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize session sync service early so it starts listening
  SessionSyncService.instance;
  runApp(const WzxClawApp());
}

/// Root widget for wzxClaw Android.
class WzxClawApp extends StatelessWidget {
  const WzxClawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'wzxClaw',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgPrimary,
        primaryColor: AppColors.accent,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bgSecondary,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accent,
          surface: AppColors.bgSecondary,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.bgElevated,
          contentTextStyle: TextStyle(color: AppColors.textPrimary),
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
