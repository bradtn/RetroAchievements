import 'package:flutter/material.dart';

/// Screen type based on size and orientation
enum ScreenType {
  phone,        // Portrait phone (< 600dp width)
  tablet,       // Tablet portrait
  widescreen,   // Landscape widescreen (gaming handheld, tablet landscape)
}

/// Helper class for responsive layouts
class ResponsiveLayout {
  /// Get the screen type based on context
  static ScreenType getScreenType(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;
    final shortestSide = size.shortestSide;

    // Widescreen: landscape orientation with good width
    if (orientation == Orientation.landscape && size.width > 600) {
      return ScreenType.widescreen;
    }

    // Tablet: large screen in portrait
    if (shortestSide >= 600) {
      return ScreenType.tablet;
    }

    // Phone: default
    return ScreenType.phone;
  }

  /// Check if current layout should use widescreen mode
  static bool isWidescreen(BuildContext context) {
    return getScreenType(context) == ScreenType.widescreen;
  }

  /// Check if we're on a phone
  static bool isPhone(BuildContext context) {
    return getScreenType(context) == ScreenType.phone;
  }

  /// Get ideal column count for grids
  static int getGridColumns(BuildContext context, {int phoneColumns = 1, int wideColumns = 2}) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.widescreen:
        return wideColumns;
      case ScreenType.tablet:
        return wideColumns;
      case ScreenType.phone:
        return phoneColumns;
    }
  }

  /// Get content padding based on screen type
  static EdgeInsets getContentPadding(BuildContext context) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.widescreen:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
      case ScreenType.tablet:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
      case ScreenType.phone:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
    }
  }
}

/// Widget that builds different layouts based on screen type
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context) phoneBuilder;
  final Widget Function(BuildContext context)? widescreenBuilder;
  final Widget Function(BuildContext context)? tabletBuilder;

  const ResponsiveBuilder({
    super.key,
    required this.phoneBuilder,
    this.widescreenBuilder,
    this.tabletBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final type = ResponsiveLayout.getScreenType(context);

    switch (type) {
      case ScreenType.widescreen:
        return widescreenBuilder?.call(context) ?? phoneBuilder(context);
      case ScreenType.tablet:
        return tabletBuilder?.call(context) ??
               widescreenBuilder?.call(context) ??
               phoneBuilder(context);
      case ScreenType.phone:
        return phoneBuilder(context);
    }
  }
}

/// Two-column layout for widescreen displays
class WidescreenTwoColumnLayout extends StatelessWidget {
  final Widget leftColumn;
  final Widget rightColumn;
  final double leftFlex;
  final double rightFlex;
  final double dividerWidth;

  const WidescreenTwoColumnLayout({
    super.key,
    required this.leftColumn,
    required this.rightColumn,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.dividerWidth = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: (leftFlex * 10).toInt(),
          child: leftColumn,
        ),
        if (dividerWidth > 0)
          VerticalDivider(
            width: dividerWidth,
            thickness: dividerWidth,
            color: Theme.of(context).dividerColor,
          ),
        Expanded(
          flex: (rightFlex * 10).toInt(),
          child: rightColumn,
        ),
      ],
    );
  }
}
