import 'package:flutter/material.dart';

/// Extension to provide consistent secondary text colors based on theme brightness
extension ThemeColorExtension on BuildContext {
  /// Returns appropriate color for secondary/subtitle text
  /// Darker in light mode, lighter in dark mode for proper contrast
  Color get subtitleColor {
    return Theme.of(this).brightness == Brightness.light
        ? Colors.grey.shade700
        : Colors.grey.shade400;
  }

  /// Returns appropriate color for tertiary/hint text
  Color get hintColor {
    return Theme.of(this).brightness == Brightness.light
        ? Colors.grey.shade600
        : Colors.grey.shade500;
  }

  /// Returns appropriate color for icons in secondary positions
  Color get secondaryIconColor {
    return Theme.of(this).brightness == Brightness.light
        ? Colors.grey.shade600
        : Colors.grey.shade400;
  }

  /// Check if current theme is light mode
  bool get isLightMode => Theme.of(this).brightness == Brightness.light;
}
