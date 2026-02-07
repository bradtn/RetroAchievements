import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/premium_provider.dart';

/// Main application widget
class RetroTrackerApp extends ConsumerWidget {
  const RetroTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'RetroTracker',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: themeMode == AppThemeMode.amoled
          ? _buildAmoledTheme()
          : _buildDarkTheme(),
      themeMode: _getThemeMode(themeMode),
      home: authState.isAuthenticated
          ? const HomeScreen()
          : const LoginScreen(),
    );
  }

  ThemeMode _getThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );
  }

  ThemeData _buildAmoledTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
        surface: Colors.black,
      ),
      scaffoldBackgroundColor: Colors.black,
      cardTheme: const CardThemeData(
        color: Color(0xFF121212),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF121212),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF121212),
      ),
      useMaterial3: true,
    );
  }
}
