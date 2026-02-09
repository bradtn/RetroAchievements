import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/game_detail_screen.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/premium_provider.dart';
import 'presentation/providers/game_cache_provider.dart';
import 'services/widget_service.dart';
import 'services/notification_service.dart';

/// Global navigator key for widget navigation
final navigatorKey = GlobalKey<NavigatorState>();

/// Main application widget
class RetroTrackerApp extends ConsumerStatefulWidget {
  const RetroTrackerApp({super.key});

  @override
  ConsumerState<RetroTrackerApp> createState() => _RetroTrackerAppState();
}

class _RetroTrackerAppState extends ConsumerState<RetroTrackerApp> {
  bool _hasRequestedPermission = false;
  bool _hasTriggeredCacheDownload = false;

  @override
  void initState() {
    super.initState();
    // Initialize widget service to handle widget clicks
    WidgetService.init(onGameSelected: _onWidgetGameSelected);
  }

  Future<void> _requestNotificationPermission() async {
    if (_hasRequestedPermission) return;
    _hasRequestedPermission = true;

    final prefs = await SharedPreferences.getInstance();
    final hasAsked = prefs.getBool('notification_permission_asked') ?? false;

    if (!hasAsked) {
      await prefs.setBool('notification_permission_asked', true);
      final notificationService = NotificationService();
      await notificationService.requestPermissions();
    }
  }

  /// Automatically download game database in the background if not already cached
  void _triggerBackgroundCacheDownload() {
    if (_hasTriggeredCacheDownload) return;
    _hasTriggeredCacheDownload = true;

    // Use a small delay to let the app fully initialize first
    Future.delayed(const Duration(seconds: 2), () {
      final cacheState = ref.read(gameCacheProvider);
      // Only build cache if it's empty and not already loading
      if (cacheState.games.isEmpty && !cacheState.isLoading) {
        // Fire and forget - runs in background
        ref.read(gameCacheProvider.notifier).buildCache();
      }
    });
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

    // Request notification permission and trigger background cache after user is authenticated
    if (authState.isAuthenticated) {
      _requestNotificationPermission();
      _triggerBackgroundCacheDownload();
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'RetroTracker',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: themeMode == AppThemeMode.amoled
          ? _buildAmoledTheme()
          : _buildDarkTheme(),
      themeMode: _getThemeMode(themeMode),
      // Smooth theme transition animation
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeInOut,
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
        onSurface: Colors.black87,
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
        textColor: Colors.black87,
        iconColor: Colors.grey.shade700,
        subtitleTextStyle: TextStyle(color: Colors.grey.shade600),
      ),
      // Icon theme for light mode
      iconTheme: IconThemeData(
        color: Colors.grey.shade700,
      ),
      // Switch styling
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.deepPurple;
          }
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.deepPurple.shade200;
          }
          return Colors.grey.shade300;
        }),
      ),
      // Improve text contrast
      textTheme: TextTheme(
        bodySmall: TextStyle(color: Colors.grey.shade700),
        bodyMedium: TextStyle(color: Colors.grey.shade800),
        bodyLarge: TextStyle(color: Colors.grey.shade900),
        labelSmall: TextStyle(color: Colors.grey.shade600),
        labelMedium: TextStyle(color: Colors.grey.shade700),
        labelLarge: TextStyle(color: Colors.grey.shade800),
        titleSmall: TextStyle(color: Colors.grey.shade800),
        titleMedium: TextStyle(color: Colors.grey.shade900),
        titleLarge: TextStyle(color: Colors.grey.shade900),
      ),
      // Divider styling
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade300,
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
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: Colors.deepPurple.shade700);
          }
          return IconThemeData(color: Colors.grey.shade600);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: Colors.deepPurple.shade700, fontSize: 12);
          }
          return TextStyle(color: Colors.grey.shade600, fontSize: 12);
        }),
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
