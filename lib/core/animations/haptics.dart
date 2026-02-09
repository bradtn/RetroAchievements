import 'package:flutter/services.dart';

/// Utility class for consistent haptic feedback throughout the app
class Haptics {
  Haptics._();

  /// Global flag to enable/disable haptic feedback
  static bool _enabled = true;

  /// Check if haptics are enabled
  static bool get isEnabled => _enabled;

  /// Enable or disable haptic feedback globally
  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Light tap feedback - for button presses, list item taps
  static void light() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  /// Medium feedback - for toggles, selections, confirmations
  static void medium() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  /// Heavy feedback - for important actions, deletions
  static void heavy() {
    if (_enabled) HapticFeedback.heavyImpact();
  }

  /// Selection feedback - for picker changes, tab switches
  static void selection() {
    if (_enabled) HapticFeedback.selectionClick();
  }

  /// Vibrate feedback - for errors, warnings
  static void vibrate() {
    if (_enabled) HapticFeedback.vibrate();
  }

  /// Success feedback - for achievements, completions
  static void success() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.lightImpact();
    });
  }

  /// Celebration feedback - for milestones, big achievements
  static void celebration() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 160), () {
      HapticFeedback.lightImpact();
    });
  }
}
