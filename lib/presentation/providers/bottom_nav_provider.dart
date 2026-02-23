import 'package:flutter/material.dart';

/// Global notifier for bottom navigation bar visibility
/// Used by DualScreenFAB to position itself correctly
class BottomNavNotifier extends ValueNotifier<bool> {
  BottomNavNotifier() : super(false);

  static final BottomNavNotifier instance = BottomNavNotifier();

  /// Set whether the bottom nav bar is currently visible
  void setVisible(bool visible) {
    if (value != visible) {
      value = visible;
    }
  }
}
