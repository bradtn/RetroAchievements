import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RAStatus {
  online,
  offline,
  checking,
}

class RAStatusState {
  final RAStatus status;
  final int consecutiveFailures;
  final DateTime? lastSuccessfulCall;
  final String? lastError;
  final bool bannerDismissed;

  RAStatusState({
    this.status = RAStatus.online,
    this.consecutiveFailures = 0,
    this.lastSuccessfulCall,
    this.lastError,
    this.bannerDismissed = false,
  });

  RAStatusState copyWith({
    RAStatus? status,
    int? consecutiveFailures,
    DateTime? lastSuccessfulCall,
    String? lastError,
    bool? bannerDismissed,
  }) {
    return RAStatusState(
      status: status ?? this.status,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastSuccessfulCall: lastSuccessfulCall ?? this.lastSuccessfulCall,
      lastError: lastError ?? this.lastError,
      bannerDismissed: bannerDismissed ?? this.bannerDismissed,
    );
  }

  bool get shouldShowBanner => status == RAStatus.offline && !bannerDismissed;
}

class RAStatusNotifier extends StateNotifier<RAStatusState> {
  static const int _failureThreshold = 3; // Show banner after 3 consecutive failures

  RAStatusNotifier() : super(RAStatusState());

  /// Call this when an API call succeeds
  void reportSuccess() {
    state = state.copyWith(
      status: RAStatus.online,
      consecutiveFailures: 0,
      lastSuccessfulCall: DateTime.now(),
      lastError: null,
      bannerDismissed: false, // Reset dismissal on success
    );
  }

  /// Call this when an API call fails
  void reportFailure(String? error) {
    final newFailures = state.consecutiveFailures + 1;
    final newStatus = newFailures >= _failureThreshold ? RAStatus.offline : state.status;

    state = state.copyWith(
      status: newStatus,
      consecutiveFailures: newFailures,
      lastError: error ?? 'Connection error',
    );
  }

  /// Dismiss the banner temporarily (will reappear if more failures occur)
  void dismissBanner() {
    state = state.copyWith(bannerDismissed: true);
  }

  /// Reset status (e.g., when user manually refreshes)
  void reset() {
    state = RAStatusState();
  }

  /// Get a user-friendly error message based on current state
  String getErrorMessage(String defaultMessage) {
    if (state.status == RAStatus.offline) {
      return 'RetroAchievements appears to be unreachable. Please check your internet connection or try again later.';
    }
    if (state.consecutiveFailures > 0) {
      return 'Having trouble connecting to RetroAchievements. Retrying...';
    }
    return defaultMessage;
  }
}

final raStatusProvider = StateNotifierProvider<RAStatusNotifier, RAStatusState>((ref) {
  return RAStatusNotifier();
});

/// Helper extension for common error message formatting
extension RAErrorMessages on String {
  static String connectionError() =>
    'Unable to reach RetroAchievements. Check your connection or try again later.';

  static String serverError() =>
    'RetroAchievements is experiencing issues. Please try again later.';

  static String timeoutError() =>
    'Request timed out. RetroAchievements may be slow or unreachable.';

  static String genericError(String context) =>
    'Failed to load $context. Pull down to retry.';
}
