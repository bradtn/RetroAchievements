import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/purchase_service.dart';

/// DEBUG: Set to true to force premium unlock for testing/screenshots
/// REMOVE BEFORE SUBMITTING TO APP STORE
const bool kDebugForcePremium = false;

/// Premium state
class PremiumState {
  final bool isPremium;
  final bool isLoading;
  final String? error;
  final DateTime? purchaseDate;
  final bool wasRefunded;

  const PremiumState({
    this.isPremium = false,
    this.isLoading = false,
    this.error,
    this.purchaseDate,
    this.wasRefunded = false,
  });

  PremiumState copyWith({
    bool? isPremium,
    bool? isLoading,
    String? error,
    DateTime? purchaseDate,
    bool? wasRefunded,
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      wasRefunded: wasRefunded ?? this.wasRefunded,
    );
  }
}

/// Premium notifier
class PremiumNotifier extends Notifier<PremiumState> {
  final PurchaseService _purchaseService = PurchaseService();

  @override
  PremiumState build() {
    _initialize();
    return const PremiumState();
  }

  Future<void> _initialize() async {
    await _purchaseService.initialize();
    await _loadStatus();

    // Set up purchase callback
    _purchaseService.onPurchaseComplete = (success) {
      if (success) {
        unlockPremium();
      }
    };

    // Set up refund callback
    _purchaseService.onPurchaseRefunded = () {
      _handleRefund();
    };
  }

  Future<void> _loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool('is_premium') ?? false;
      final purchaseDate = await _purchaseService.getPurchaseDate();
      state = state.copyWith(isPremium: isPremium, purchaseDate: purchaseDate);
    } catch (e) {
      // Stay free
    }
  }

  /// Handle refund - revoke premium
  void _handleRefund() {
    state = state.copyWith(isPremium: false, wasRefunded: true, purchaseDate: null);
  }

  /// Unlock premium (after purchase verified)
  Future<void> unlockPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);
    state = state.copyWith(
      isPremium: true,
      isLoading: false,
      purchaseDate: DateTime.now(),
      wasRefunded: false,
    );
  }

  /// Purchase premium with detailed result
  Future<PurchaseResult> purchasePremiumWithResult() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _purchaseService.purchasePremiumWithResult();
      if (!result.success) {
        state = state.copyWith(isLoading: false, error: result.errorMessage);
      }
      // If successful, the callback will handle unlocking
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return PurchaseResult.error(PurchaseErrorType.unknown, e.toString());
    }
  }

  /// Purchase premium (simple bool for backwards compatibility)
  Future<bool> purchasePremium() async {
    final result = await purchasePremiumWithResult();
    return result.success;
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

  /// Check if on sale
  bool get isOnSale => _purchaseService.isOnSale;

  /// Get original price if on sale
  String? get originalPrice => _purchaseService.originalPrice;

  /// Clear refund flag after showing message
  void clearRefundFlag() {
    state = state.copyWith(wasRefunded: false);
  }
}

/// Provider for premium state
final premiumProvider = NotifierProvider<PremiumNotifier, PremiumState>(PremiumNotifier.new);

/// Helper provider to check if ads should be shown
final showAdsProvider = Provider<bool>((ref) {
  if (kDebugForcePremium) return false; // DEBUG: Remove before release
  return !ref.watch(premiumProvider).isPremium;
});

final isPremiumProvider = Provider<bool>((ref) {
  if (kDebugForcePremium) return true; // DEBUG: Remove before release
  return ref.watch(premiumProvider).isPremium;
});

/// Theme state
enum AppThemeMode { light, dark, amoled, system }

/// Theme notifier
class ThemeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    _loadTheme();
    return AppThemeMode.dark;
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
final themeProvider = NotifierProvider<ThemeNotifier, AppThemeMode>(ThemeNotifier.new);

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
