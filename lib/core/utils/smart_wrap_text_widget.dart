import 'package:flutter/material.dart';
import 'smart_text_wrapper.dart';

/// A Text widget that uses smart layout-aware wrapping.
/// Measures available width and inserts line breaks at optimal positions.
///
/// Use this for pixel fonts where you need precise control over line breaks.
class SmartWrapText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;
  final TextOverflow overflow;
  final List<RegExp> noBreakPatterns;

  /// Optional fixed width. If null, uses LayoutBuilder to measure.
  final double? fixedWidth;

  /// Horizontal padding to subtract from available width
  final double horizontalPadding;

  const SmartWrapText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.noBreakPatterns = const [],
    this.fixedWidth,
    this.horizontalPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;

    if (fixedWidth != null) {
      // Use fixed width directly
      final wrappedText = SmartTextWrapper.smartWrapMeasured(
        text: text,
        style: effectiveStyle,
        maxWidth: fixedWidth! - horizontalPadding,
        maxLines: maxLines,
        noBreakPatterns: noBreakPatterns,
      );

      return Text(
        wrappedText,
        style: effectiveStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    // Use LayoutBuilder to get actual available width
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - horizontalPadding;

        if (availableWidth <= 0 || availableWidth == double.infinity) {
          // Fallback to regular text if constraints are invalid
          return Text(
            text,
            style: effectiveStyle,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          );
        }

        final wrappedText = SmartTextWrapper.smartWrapMeasured(
          text: text,
          style: effectiveStyle,
          maxWidth: availableWidth,
          maxLines: maxLines,
          noBreakPatterns: noBreakPatterns,
        );

        return Text(
          wrappedText,
          style: effectiveStyle,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}

/// Builder version for more control over the wrapped text
class SmartWrapTextBuilder extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  final List<RegExp> noBreakPatterns;
  final double horizontalPadding;
  final Widget Function(BuildContext context, String wrappedText) builder;

  const SmartWrapTextBuilder({
    super.key,
    required this.text,
    required this.style,
    required this.builder,
    this.maxLines = 2,
    this.noBreakPatterns = const [],
    this.horizontalPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - horizontalPadding;

        if (availableWidth <= 0 || availableWidth == double.infinity) {
          return builder(context, text);
        }

        final wrappedText = SmartTextWrapper.smartWrapMeasured(
          text: text,
          style: style,
          maxWidth: availableWidth,
          maxLines: maxLines,
          noBreakPatterns: noBreakPatterns,
        );

        return builder(context, wrappedText);
      },
    );
  }
}
