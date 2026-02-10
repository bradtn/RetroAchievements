import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/game_detail_screen.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/premium_provider.dart';
import 'presentation/providers/game_cache_provider.dart';
import 'presentation/screens/settings/settings_provider.dart';
import 'services/widget_service.dart';
import 'services/notification_service.dart';
import 'services/background_sync_service.dart';

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
  bool _hasTriggeredWidgetSync = false;

  @override
  void initState() {
    super.initState();
    // Initialize widget service to handle widget clicks
    WidgetService.init(
      onGameSelected: _onWidgetGameSelected,
      onOpenScreen: _onWidgetOpenScreen,
    );
  }

  void _onWidgetOpenScreen(String screen) {
    // Handle opening specific screens from widgets
    // Currently only used for streak widget -> calendar
    if (screen == 'calendar') {
      // The HomeScreen handles this navigation
    }
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

    // Wait for disk cache to be checked before deciding to build
    _waitForCacheLoadThenBuildIfNeeded();
  }

  Future<void> _waitForCacheLoadThenBuildIfNeeded() async {
    // Wait up to 5 seconds for disk cache to load
    for (int i = 0; i < 50; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      final cacheState = ref.read(gameCacheProvider);

      if (cacheState.hasLoadedFromDisk) {
        // Disk cache has been checked - only build if empty
        if (cacheState.games.isEmpty && !cacheState.isLoading) {
          ref.read(gameCacheProvider.notifier).buildCache();
        }
        return;
      }
    }

    // Timeout - check anyway
    final cacheState = ref.read(gameCacheProvider);
    if (cacheState.games.isEmpty && !cacheState.isLoading) {
      ref.read(gameCacheProvider.notifier).buildCache();
    }
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

  void _triggerWidgetDataSync() {
    if (_hasTriggeredWidgetSync) return;
    _hasTriggeredWidgetSync = true;

    // Sync widget data in the background
    BackgroundSyncService().syncWidgetDataOnAppOpen();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final accentColor = ref.watch(accentColorProvider);

    // Request notification permission and trigger background tasks after user is authenticated
    if (authState.isAuthenticated) {
      _requestNotificationPermission();
      _triggerBackgroundCacheDownload();
      _triggerWidgetDataSync();
    }

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'RetroTrack',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(accentColor.color),
      darkTheme: themeMode == AppThemeMode.amoled
          ? _buildAmoledTheme(accentColor.color)
          : _buildDarkTheme(accentColor.color),
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

  ThemeData _buildLightTheme(Color seedColor) {
    // Create base scheme then override with vibrant colors
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      surface: const Color(0xFFF5F5F5),
      surfaceContainerHighest: Colors.white,
      onSurface: Colors.black87,
    );

    // Use the actual vibrant color instead of the muted seed-generated one
    final colorScheme = baseScheme.copyWith(
      primary: seedColor,
      primaryContainer: HSLColor.fromColor(seedColor).withLightness(0.85).toColor(),
      secondary: seedColor,
      tertiary: seedColor,
    );

    return ThemeData(
      colorScheme: colorScheme,
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
            return colorScheme.primary;
          }
          return Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
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
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.primary);
          }
          return IconThemeData(color: Colors.grey.shade600);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(color: colorScheme.primary, fontSize: 12);
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

  ThemeData _buildDarkTheme(Color seedColor) {
    // Create base scheme then override with vibrant colors
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF121212),
      surfaceContainerHighest: const Color(0xFF1E1E1E),
    );

    // Use the actual vibrant color instead of the muted seed-generated one
    final colorScheme = baseScheme.copyWith(
      primary: seedColor,
      primaryContainer: HSLColor.fromColor(seedColor).withLightness(0.25).toColor(),
      secondary: seedColor,
      tertiary: seedColor,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF121212),
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E1E1E),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF1E1E1E),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFF1E1E1E),
      ),
      useMaterial3: true,
    );
  }

  ThemeData _buildAmoledTheme(Color seedColor) {
    // Create base scheme then override with vibrant colors
    final baseScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      surface: Colors.black,
      surfaceContainerHighest: const Color(0xFF121212),
    );

    // Use the actual vibrant color instead of the muted seed-generated one
    final colorScheme = baseScheme.copyWith(
      primary: seedColor,
      primaryContainer: HSLColor.fromColor(seedColor).withLightness(0.25).toColor(),
      secondary: seedColor,
      tertiary: seedColor,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.black,
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF121212),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primaryContainer,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF121212),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF121212),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color(0xFF121212),
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF121212),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFF121212),
      ),
      useMaterial3: true,
    );
  }
}
