import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/purchase_service.dart';

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
  final PurchaseService _purchaseService = PurchaseService();

  PremiumNotifier() : super(const PremiumState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadStatus();

    // Set up purchase callback
    _purchaseService.onPurchaseComplete = (success) {
      if (success) {
        unlockPremium();
      }
    };
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

  /// Unlock premium (after purchase verified)
  Future<void> unlockPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);
    state = state.copyWith(isPremium: true, isLoading: false);
  }

  /// Purchase premium
  Future<bool> purchasePremium() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final success = await _purchaseService.purchasePremium();
      if (!success) {
        state = state.copyWith(isLoading: false, error: 'Purchase failed');
      }
      // If successful, the callback will handle unlocking
      return success;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _purchaseService.restorePurchases();
      // Give it a moment for the stream to process
      await Future.delayed(const Duration(seconds: 2));
      await _loadStatus();
    } catch (e) {
      state = state.copyWith(error: 'Restore failed');
    }

    state = state.copyWith(isLoading: false);
  }

  /// Get price string from store
  String get priceString => _purchaseService.premiumPrice;
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
