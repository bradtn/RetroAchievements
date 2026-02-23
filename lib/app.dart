import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/game_detail_screen.dart';
import 'presentation/screens/aotw_screen.dart';
import 'presentation/screens/aotm_screen.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/premium_provider.dart';
import 'presentation/providers/game_cache_provider.dart';
import 'presentation/screens/settings/settings_provider.dart';
import 'presentation/widgets/dual_screen_fab.dart';
import 'services/widget_service.dart';
import 'services/notification_service.dart';
import 'services/background_sync_service.dart';

/// Global navigator key for widget navigation
final navigatorKey = GlobalKey<NavigatorState>();

void _initNavigatorKey() {
  NotificationService.navigatorKey = navigatorKey;
}

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
    // Set up navigator key for notification taps
    _initNavigatorKey();
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
    // CRITICAL: Disable focus highlight for gamepad/d-pad navigation FIRST
    // This must happen at the very start of build to prevent yellow focus borders
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;

    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeProvider);
    final accentColor = ref.watch(accentColorProvider);
    final isPremium = ref.watch(isPremiumProvider);
    final usePixelFont = ref.watch(pixelFontProvider);

    // Non-premium users get default blue accent (accent color is premium-only)
    final effectiveColor = isPremium ? accentColor.color : Colors.blue;
    // Pixel font is available to all users
    final effectivePixelFont = usePixelFont;

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
      // Use iOS-style scrolling on all platforms for smoother feel
      scrollBehavior: const _SmoothScrollBehavior(),
      theme: _buildLightTheme(effectiveColor, effectivePixelFont),
      darkTheme: themeMode == AppThemeMode.amoled
          ? _buildAmoledTheme(effectiveColor, effectivePixelFont)
          : _buildDarkTheme(effectiveColor, effectivePixelFont),
      themeMode: _getThemeMode(themeMode),
      // Smooth theme transition animation
      themeAnimationDuration: const Duration(milliseconds: 300),
      themeAnimationCurve: Curves.easeInOut,
      routes: {
        '/aotw': (context) => const AchievementOfTheWeekScreen(),
        '/aotm': (context) => const AchievementOfTheMonthScreen(),
      },
      // Overlay DualScreenFAB on all screens when authenticated
      // Also wrap with focus scope to disable yellow focus indicators
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }

        // Apply text scaling for pixel font mode
        // The pixel font renders larger, so we scale it down proportionally
        Widget result = child;
        if (effectivePixelFont) {
          result = MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(0.65), // Scale down pixel font
            ),
            child: result,
          );
        }

        // Wrap with widget that removes focus highlight decorations
        result = _FocusDisabler(child: result);

        // Apply pixel font to all text by wrapping with DefaultTextStyle
        if (effectivePixelFont) {
          result = DefaultTextStyle(
            style: GoogleFonts.pressStart2p(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            child: result,
          );
        }

        if (authState.isAuthenticated) {
          result = Stack(
            children: [
              result,
              // DualScreenFAB on right side (scroll-to-top FABs are now on left)
              const Positioned(
                right: 16,
                bottom: 16,
                child: DualScreenFAB(),
              ),
            ],
          );
        }
        return result;
      },
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

  ThemeData _buildLightTheme(Color seedColor, bool usePixelFont) {
    final textTheme = usePixelFont
        ? GoogleFonts.pressStart2pTextTheme(ThemeData.light().textTheme)
        : null;
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
      // Disable yellow focus border for gamepad/d-pad navigation
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      // Disable focus overlay on all buttons
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
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
      // Improve text contrast (with optional pixel font)
      textTheme: usePixelFont
          ? textTheme?.apply(
              bodyColor: Colors.grey.shade800,
              displayColor: Colors.grey.shade900,
            )
          : TextTheme(
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

  ThemeData _buildDarkTheme(Color seedColor, bool usePixelFont) {
    final textTheme = usePixelFont
        ? GoogleFonts.pressStart2pTextTheme(ThemeData.dark().textTheme)
        : null;
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
      // Disable yellow focus border for gamepad/d-pad navigation
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      // Disable focus overlay on all buttons
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
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
      // Apply pixel font if enabled
      textTheme: textTheme,
      useMaterial3: true,
    );
  }

  ThemeData _buildAmoledTheme(Color seedColor, bool usePixelFont) {
    final textTheme = usePixelFont
        ? GoogleFonts.pressStart2pTextTheme(ThemeData.dark().textTheme)
        : null;
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
      // Disable yellow focus border for gamepad/d-pad navigation
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      // Disable focus overlay on all buttons
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
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
      // Apply pixel font if enabled
      textTheme: textTheme,
      useMaterial3: true,
    );
  }
}

/// Custom scroll behavior for smoother iOS-style scrolling
class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use bouncing physics everywhere for smoother feel
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
      decelerationRate: ScrollDecelerationRate.fast,
    );
  }
}

/// Widget that disables focus highlight decorations globally
/// This removes the yellow border that appears on gamepad/d-pad navigation
class _FocusDisabler extends StatefulWidget {
  final Widget child;

  const _FocusDisabler({required this.child});

  @override
  State<_FocusDisabler> createState() => _FocusDisablerState();
}

class _FocusDisablerState extends State<_FocusDisabler> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enforceTouchMode();
    // Listen for highlight mode changes and force back to touch
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called when highlight mode changes - force it back to touch mode
  void _onHighlightModeChange(FocusHighlightMode mode) {
    // Always stay in touch mode to prevent yellow borders
    if (mode == FocusHighlightMode.traditional) {
      // Schedule a microtask to avoid modification during notification
      Future.microtask(() {
        FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
      });
    }
  }

  /// Enforce touch mode to prevent yellow focus borders
  void _enforceTouchMode() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-enforce touch mode when app resumes to prevent focus highlight
    if (state == AppLifecycleState.resumed) {
      _enforceTouchMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Force touch mode strategy on every build to prevent yellow focus borders
    _enforceTouchMode();

    // Wrap with FocusScope that clears any accidental focus
    return FocusScope(
      // Prevent default focus traversal from highlighting
      skipTraversal: false,
      canRequestFocus: true,
      child: Theme(
        data: Theme.of(context).copyWith(
          // Override focus decoration to be invisible
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          // Disable all ink effects
          splashFactory: NoSplash.splashFactory,
          // Override card focus behavior
          cardTheme: Theme.of(context).cardTheme.copyWith(
            surfaceTintColor: Colors.transparent,
          ),
          // Override list tile focus
          listTileTheme: Theme.of(context).listTileTheme.copyWith(
            selectedTileColor: Colors.transparent,
          ),
          // Override action icon theme
          actionIconTheme: ActionIconThemeData(
            backButtonIconBuilder: (context) => const Icon(Icons.arrow_back),
            closeButtonIconBuilder: (context) => const Icon(Icons.close),
            drawerButtonIconBuilder: (context) => const Icon(Icons.menu),
            endDrawerButtonIconBuilder: (context) => const Icon(Icons.menu),
          ),
          // Override navigation bar
          navigationBarTheme: Theme.of(context).navigationBarTheme.copyWith(
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          ),
          // Override bottom nav bar
          bottomNavigationBarTheme: Theme.of(context).bottomNavigationBarTheme.copyWith(
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
          ),
          // Override floating action button focus
          floatingActionButtonTheme: Theme.of(context).floatingActionButtonTheme.copyWith(
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            focusElevation: 0,
            hoverElevation: 0,
          ),
          // Override menu button theme
          menuButtonTheme: MenuButtonThemeData(
            style: ButtonStyle(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
          // Override dropdown menu theme
          dropdownMenuTheme: DropdownMenuThemeData(
            inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
            ),
          ),
          // Override segmented button theme
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: ButtonStyle(
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
          // Override toggle buttons theme
          toggleButtonsTheme: ToggleButtonsThemeData(
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
          ),
          // Override search bar theme
          searchBarTheme: SearchBarThemeData(
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          ),
          // Override tab bar theme
          tabBarTheme: Theme.of(context).tabBarTheme.copyWith(
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
