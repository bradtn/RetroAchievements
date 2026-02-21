import 'package:flutter/material.dart';

/// Utility class for responsive layout handling across different screen types
/// Supports widescreen (16:9), square/4:3 displays, and tablets
class ResponsiveUtils {
  /// Get the aspect ratio of the current screen
  static double getAspectRatio(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width / size.height;
  }

  /// Check if the screen is widescreen (16:9 or wider, aspect >= 1.5)
  static bool isWidescreen(BuildContext context) {
    return getAspectRatio(context) >= 1.5;
  }

  /// Check if the screen is square-ish (4:3 or closer, aspect < 1.5)
  static bool isSquareScreen(BuildContext context) {
    return getAspectRatio(context) < 1.5;
  }

  /// Check if the screen is in landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Check if the screen is a tablet (width > 600 in portrait or > 900 in landscape)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > 600;
  }

  /// Get recommended grid column count based on screen width and aspect ratio
  static int getGridColumnCount(BuildContext context, {int minColumns = 2, int maxColumns = 6}) {
    final width = MediaQuery.of(context).size.width;
    final isSquare = isSquareScreen(context);

    // Square screens need fewer columns to avoid cramped layouts
    if (isSquare) {
      if (width < 400) return minColumns.clamp(2, 3);
      if (width < 600) return 3.clamp(minColumns, maxColumns);
      if (width < 900) return 4.clamp(minColumns, maxColumns);
      return 5.clamp(minColumns, maxColumns);
    }

    // Widescreen can have more columns
    if (width < 400) return 3.clamp(minColumns, maxColumns);
    if (width < 600) return 3.clamp(minColumns, maxColumns);
    if (width < 900) return 4.clamp(minColumns, maxColumns);
    if (width < 1200) return 5.clamp(minColumns, maxColumns);
    return maxColumns;
  }

  /// Get recommended dialog max width based on screen size
  static double getDialogMaxWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return width * 0.95;
    if (width < 600) return 500;
    if (width < 900) return 600;
    return 700;
  }

  /// Get recommended dialog max height based on screen size
  static double getDialogMaxHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    if (height < 600) return height * 0.85;
    if (height < 800) return height * 0.8;
    return 600;
  }

  /// Get padding that adapts to screen size
  static EdgeInsets getAdaptivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return const EdgeInsets.all(12);
    if (width < 600) return const EdgeInsets.all(16);
    return const EdgeInsets.all(20);
  }

  /// Get appropriate card aspect ratio for square vs widescreen
  static double getCardAspectRatio(BuildContext context) {
    if (isSquareScreen(context)) {
      return 0.85; // Taller cards on square screens
    }
    return 0.95; // Standard aspect ratio for widescreen
  }

  /// Get appropriate font size scaling for screen density
  static double getFontScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 0.9;
    if (width < 400) return 0.95;
    return 1.0;
  }

  /// Returns constraints suitable for the current display
  static BoxConstraints getContentConstraints(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Cap content width on very wide screens
    if (width > 1200) {
      return const BoxConstraints(maxWidth: 1200);
    }
    return BoxConstraints(maxWidth: width);
  }
}

/// Extension on BuildContext for easier access to responsive utilities
extension ResponsiveExtension on BuildContext {
  bool get isWidescreen => ResponsiveUtils.isWidescreen(this);
  bool get isSquareScreen => ResponsiveUtils.isSquareScreen(this);
  bool get isLandscape => ResponsiveUtils.isLandscape(this);
  bool get isTablet => ResponsiveUtils.isTablet(this);
  double get screenAspectRatio => ResponsiveUtils.getAspectRatio(this);
  int gridColumns({int min = 2, int max = 6}) =>
      ResponsiveUtils.getGridColumnCount(this, minColumns: min, maxColumns: max);
  EdgeInsets get adaptivePadding => ResponsiveUtils.getAdaptivePadding(this);
}

/// Widget that adapts its child based on screen type
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, ScreenType screenType) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return builder(context, _getScreenType(context));
  }

  ScreenType _getScreenType(BuildContext context) {
    if (ResponsiveUtils.isTablet(context)) {
      if (ResponsiveUtils.isSquareScreen(context)) {
        return ScreenType.tabletSquare;
      }
      return ScreenType.tabletWide;
    }
    if (ResponsiveUtils.isSquareScreen(context)) {
      return ScreenType.phoneSquare;
    }
    return ScreenType.phoneWide;
  }
}

enum ScreenType {
  phoneWide,    // Standard phone, 16:9 or wider
  phoneSquare,  // Square-ish phone, 4:3 or closer
  tabletWide,   // Tablet in widescreen
  tabletSquare, // Tablet in square aspect (or portrait)
}
