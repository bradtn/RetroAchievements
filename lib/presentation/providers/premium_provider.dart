import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Premium state
class PremiumState {
  final bool isPremium;
  final bool isLoading;
  final String? error;

  const PremiumState({
    this.isPremium = false,
    this.isLoading = false,
    this.error,
  });

  PremiumState copyWith({
    bool? isPremium,
    bool? isLoading,
    String? error,
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Premium notifier
class PremiumNotifier extends StateNotifier<PremiumState> {
  PremiumNotifier() : super(const PremiumState()) {
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('is_premium') ?? false;
      state = state.copyWith(isPremium: isPremium);
    } catch (e) {
      // Stay free
    }
  }

  /// Unlock premium (after purchase)
  Future<void> unlockPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);
    state = state.copyWith(isPremium: true);
  }

  /// Toggle premium (for testing)
  Future<void> togglePremium() async {
    final prefs = await SharedPreferences.getInstance();
    final newStatus = !state.isPremium;
    await prefs.setBool('is_premium', newStatus);
    state = state.copyWith(isPremium: newStatus);
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true);
    // TODO: Implement actual restore with in_app_purchase
    await _loadStatus();
    state = state.copyWith(isLoading: false);
  }
}

/// Provider for premium state
final premiumProvider = StateNotifierProvider<PremiumNotifier, PremiumState>((ref) {
  return PremiumNotifier();
});

/// Helper provider to check if ads should be shown
final showAdsProvider = Provider<bool>((ref) {
  return !ref.watch(premiumProvider).isPremium;
});

final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(premiumProvider).isPremium;
});

/// Theme state
enum AppThemeMode { light, dark, amoled, system }

/// Theme notifier
class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString('app_theme') ?? 'dark';
      switch (theme) {
        case 'light':
          state = AppThemeMode.light;
          break;
        case 'dark':
          state = AppThemeMode.dark;
          break;
        case 'amoled':
          state = AppThemeMode.amoled;
          break;
        default:
          state = AppThemeMode.system;
      }
    } catch (e) {
      state = AppThemeMode.dark;
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', mode.name);
  }
}

/// Theme provider
final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

/// Convert AppThemeMode to Flutter ThemeMode
ThemeMode getThemeMode(AppThemeMode mode) {
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
