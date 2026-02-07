import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/game_detail_screen.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/premium_provider.dart';
import 'services/widget_service.dart';

/// Global navigator key for widget navigation
final navigatorKey = GlobalKey<NavigatorState>();

/// Main application widget
class RetroTrackerApp extends ConsumerStatefulWidget {
  const RetroTrackerApp({super.key});

  @override
  ConsumerState<RetroTrackerApp> createState() => _RetroTrackerAppState();
}

class _RetroTrackerAppState extends ConsumerState<RetroTrackerApp> {
  @override
  void initState() {
    super.initState();
    // Initialize widget service to handle widget clicks
    WidgetService.init(onGameSelected: _onWidgetGameSelected);
  }

  void _onWidgetGameSelected(int gameId) {
    // Navigate to the game detail screen
    // Use a small delay to ensure the app is fully initialized
    Future.delayed(const Duration(milliseconds: 500), () {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => GameDetailScreen(gameId: gameId),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
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
        surface: const Color(0xFFF5F5F5), // Slight grey background
        surfaceContainerHighest: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      // Improve card contrast in light mode
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      // Better list tile styling
      listTileTheme: ListTileThemeData(
        subtitleTextStyle: TextStyle(color: Colors.grey.shade700),
      ),
      // Improve text contrast
      textTheme: TextTheme(
        bodySmall: TextStyle(color: Colors.grey.shade700),
        bodyMedium: TextStyle(color: Colors.grey.shade800),
        labelSmall: TextStyle(color: Colors.grey.shade600),
        titleSmall: TextStyle(color: Colors.grey.shade800),
        titleMedium: TextStyle(color: Colors.grey.shade900),
        titleLarge: TextStyle(color: Colors.grey.shade900),
      ),
      // AppBar styling
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      // Navigation bar styling
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Colors.deepPurple.shade100,
      ),
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      // Chip styling
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade300),
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
