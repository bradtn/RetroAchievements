import 'package:flutter/material.dart';

enum BackgroundPattern { none, diagonal, dots, grid, gameBlur }
enum CardFontStyle { modern, pixel }
enum CardBorderStyle { none, thin, thick, glow }
enum AvatarFrame { circle, roundedSquare, square }
enum CardLayout { detailed, compact }

// GIF Animation options
enum SparkleAmount { none, few, many }
enum SparkleStyle { circles, stars, hearts, diamonds, sparkles, plus, playstation, xbox, dpad, retro }
enum SparkleColor { white, gold, rainbow, gradient }
enum AnimationSpeed { slow, normal, fast }

class ShareCardSettings {
  final Color gradientStart;
  final Color gradientEnd;
  final BackgroundPattern pattern;
  final CardFontStyle fontStyle;
  final CardBorderStyle borderStyle;
  final AvatarFrame avatarFrame;
  final CardLayout layout;

  const ShareCardSettings({
    this.gradientStart = const Color(0xFF1a1a2e),
    this.gradientEnd = const Color(0xFF16213e),
    this.pattern = BackgroundPattern.diagonal,
    this.fontStyle = CardFontStyle.pixel,
    this.borderStyle = CardBorderStyle.none,
    this.avatarFrame = AvatarFrame.circle,
    this.layout = CardLayout.detailed,
  });

  ShareCardSettings copyWith({
    Color? gradientStart,
    Color? gradientEnd,
    BackgroundPattern? pattern,
    CardFontStyle? fontStyle,
    CardBorderStyle? borderStyle,
    AvatarFrame? avatarFrame,
    CardLayout? layout,
  }) {
    return ShareCardSettings(
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      pattern: pattern ?? this.pattern,
      fontStyle: fontStyle ?? this.fontStyle,
      borderStyle: borderStyle ?? this.borderStyle,
      avatarFrame: avatarFrame ?? this.avatarFrame,
      layout: layout ?? this.layout,
    );
  }

  // Preset styles matching the original
  static const List<ShareCardPreset> presets = [
    ShareCardPreset('Classic', Color(0xFF1a1a2e), Color(0xFF16213e)),
    ShareCardPreset('Retro', Color(0xFF2d132c), Color(0xFF801336)),
    ShareCardPreset('Neon', Color(0xFF0f0c29), Color(0xFF302b63)),
    ShareCardPreset('Forest', Color(0xFF134e5e), Color(0xFF71b280)),
    ShareCardPreset('Sunset', Color(0xFFff6b6b), Color(0xFFfeca57)),
    ShareCardPreset('Ocean', Color(0xFF141E30), Color(0xFF243B55)),
    ShareCardPreset('Fire', Color(0xFF200122), Color(0xFF6f0000)),
    ShareCardPreset('Custom', Colors.transparent, Colors.transparent),
  ];
}

class ShareCardPreset {
  final String name;
  final Color gradientStart;
  final Color gradientEnd;

  const ShareCardPreset(this.name, this.gradientStart, this.gradientEnd);

  bool get isCustom => name == 'Custom';
}
