import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'share_card_settings.dart';

class CardStyle {
  final String name;
  final List<Color> colors;

  CardStyle(this.name, this.colors);
}

// Helper to get text style based on font setting
TextStyle getCardTextStyle({
  required CardFontStyle fontStyle,
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.normal,
  Color color = Colors.white,
  double? letterSpacing,
}) {
  if (fontStyle == CardFontStyle.pixel) {
    return GoogleFonts.pressStart2p(
      fontSize: fontSize * 0.7, // Pixel font is larger, scale down
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
  // Use Roboto explicitly for modern style to avoid inheriting global pixel font
  return GoogleFonts.roboto(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

// Helper to get avatar decoration based on frame setting
BoxDecoration getAvatarDecoration({
  required AvatarFrame frame,
  required double size,
  Color borderColor = Colors.white,
  double borderWidth = 3,
  List<BoxShadow>? boxShadow,
}) {
  final borderRadius = switch (frame) {
    AvatarFrame.circle => BorderRadius.circular(size),
    AvatarFrame.roundedSquare => BorderRadius.circular(size * 0.25),
    AvatarFrame.square => BorderRadius.circular(4),
  };

  return BoxDecoration(
    borderRadius: frame == AvatarFrame.circle ? null : borderRadius,
    shape: frame == AvatarFrame.circle ? BoxShape.circle : BoxShape.rectangle,
    border: Border.all(color: borderColor, width: borderWidth),
    boxShadow: boxShadow,
  );
}

// Helper to clip avatar based on frame setting
Widget clipAvatar({
  required AvatarFrame frame,
  required double size,
  required Widget child,
}) {
  return switch (frame) {
    AvatarFrame.circle => ClipOval(child: child),
    AvatarFrame.roundedSquare => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: child,
      ),
    AvatarFrame.square => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: child,
      ),
  };
}

// Helper to get card border decoration
BoxDecoration getCardBorderDecoration({
  required CardBorderStyle borderStyle,
  required List<Color> gradientColors,
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(20)),
}) {
  final baseShadow = BoxShadow(
    color: gradientColors.first.withValues(alpha: 0.5),
    blurRadius: 20,
    offset: const Offset(0, 10),
  );

  return switch (borderStyle) {
    CardBorderStyle.none => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: borderRadius,
        boxShadow: [baseShadow],
      ),
    CardBorderStyle.thin => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: borderRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        boxShadow: [baseShadow],
      ),
    CardBorderStyle.thick => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: borderRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
        boxShadow: [baseShadow],
      ),
    CardBorderStyle.glow => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: borderRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          baseShadow,
          BoxShadow(
            color: gradientColors.first.withValues(alpha: 0.8),
            blurRadius: 30,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
    // Frame style is handled separately in _buildCard with double-container structure
    CardBorderStyle.frame => BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [baseShadow],
      ),
  };
}

class StyleButton extends StatelessWidget {
  final CardStyle style;
  final bool isSelected;
  final VoidCallback onTap;

  const StyleButton({
    super.key,
    required this.style,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: style.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.white, width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            style.name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const StatBadge({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class ComparisonStatRow extends StatelessWidget {
  final String label;
  final String myValue;
  final String otherValue;
  final bool myWins;
  final bool otherWins;

  const ComparisonStatRow({
    super.key,
    required this.label,
    required this.myValue,
    required this.otherValue,
    required this.myWins,
    required this.otherWins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              myValue,
              style: TextStyle(
                color: myWins ? Colors.green : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              otherValue,
              style: TextStyle(
                color: otherWins ? Colors.red : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    // Draw diagonal lines
    for (var i = -size.height; i < size.width + size.height; i += 20) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DotsPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    const spacing = 24.0;
    const radius = 2.0;

    for (var y = spacing / 2; y < size.height; y += spacing) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const spacing = 30.0;

    // Vertical lines
    for (var x = 0.0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (var y = 0.0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Widget to render the appropriate pattern based on settings
Widget buildPatternOverlay(BackgroundPattern pattern, {String? gameImageUrl}) {
  switch (pattern) {
    case BackgroundPattern.none:
      return const SizedBox.shrink();
    case BackgroundPattern.diagonal:
      return Positioned.fill(
        child: CustomPaint(painter: PatternPainter()),
      );
    case BackgroundPattern.dots:
      return Positioned.fill(
        child: CustomPaint(painter: DotsPatternPainter()),
      );
    case BackgroundPattern.grid:
      return Positioned.fill(
        child: CustomPaint(painter: GridPatternPainter()),
      );
    case BackgroundPattern.gameBlur:
      if (gameImageUrl != null && gameImageUrl.isNotEmpty) {
        final imageUrl = gameImageUrl.startsWith('http')
            ? gameImageUrl
            : 'https://retroachievements.org$gameImageUrl';
        return Positioned.fill(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Blurred game image at higher opacity
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              // Dark gradient overlay for text readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
  }
}

class PlayerTag extends StatelessWidget {
  final String username;
  final AvatarFrame frame;
  final CardFontStyle fontStyle;

  const PlayerTag({
    super.key,
    required this.username,
    this.frame = AvatarFrame.circle,
    this.fontStyle = CardFontStyle.modern,
  });

  @override
  Widget build(BuildContext context) {
    const size = 20.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: getAvatarDecoration(frame: frame, size: size, borderWidth: 0),
            child: clipAvatar(
              frame: frame,
              size: size,
              child: CachedNetworkImage(
                imageUrl: 'https://retroachievements.org/UserPic/$username.png',
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: Colors.grey[700], child: const Icon(Icons.person, size: 12, color: Colors.white54)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(username, style: getCardTextStyle(fontStyle: fontStyle, fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white)),
        ],
      ),
    );
  }
}

class Branding extends StatelessWidget {
  final CardFontStyle fontStyle;
  final double logoSize;

  const Branding({super.key, this.fontStyle = CardFontStyle.modern, this.logoSize = 70});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/RetroTrack.png',
            height: logoSize,
            width: logoSize,
            fit: BoxFit.contain,
          ),
        ),
        Text(
          'retroachievements.org',
          textAlign: TextAlign.center,
          style: getCardTextStyle(
            fontStyle: fontStyle,
            fontSize: 8,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

String formatNumber(dynamic num) {
  if (num == null) return '0';
  final n = int.tryParse(num.toString()) ?? 0;
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(1)}M';
  } else if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(1)}K';
  }
  return n.toString();
}

/// Smart text wrapper that prevents awkward line breaks in pixel fonts.
/// Uses non-breaking spaces to keep phrases together.
///
/// Protects:
/// - Phrases after delimiters (–, -, vs., vs, :)
/// - Short trailing words (prevents orphans)
/// - Common multi-word game terms
String smartWrapText(String text) {
  if (text.isEmpty) return text;

  const nbsp = '\u00A0'; // Non-breaking space
  var result = text;

  // 1. Protect phrases after common delimiters
  // Pattern: "– Something Here" or "- Something Here"
  result = result.replaceAllMapped(
    RegExp(r'([–\-])\s+(\S+(?:\s+\S+){0,3})$'),
    (m) => '${m[1]}$nbsp${m[2]!.replaceAll(' ', nbsp)}',
  );

  // 2. Protect "vs." or "vs" phrases: "vs. Cut Man" -> "vs.\u00A0Cut\u00A0Man"
  result = result.replaceAllMapped(
    RegExp(r'\b(vs\.?)\s+(\S+(?:\s+\S+){0,2})', caseSensitive: false),
    (m) => '${m[1]}$nbsp${m[2]!.replaceAll(' ', nbsp)}',
  );

  // 3. Protect phrases after colons at end: ": Final Score"
  result = result.replaceAllMapped(
    RegExp(r':\s+(\S+(?:\s+\S+){0,2})$'),
    (m) => ':$nbsp${m[1]!.replaceAll(' ', nbsp)}',
  );

  // 4. Protect short orphan words at end (2-4 chars)
  // "Record Score vs. Cut Man" - if "Man" would be alone, keep "Cut Man"
  result = result.replaceAllMapped(
    RegExp(r'\s(\S{1,4})$'),
    (m) => '$nbsp${m[1]}',
  );

  // 5. Protect common game terms that shouldn't break
  final protectedPhrases = [
    'Cut Man', 'Ice Man', 'Fire Man', 'Bomb Man', 'Guts Man', 'Elec Man',
    'Air Man', 'Metal Man', 'Flash Man', 'Quick Man', 'Crash Man', 'Heat Man',
    'Wood Man', 'Bubble Man', 'Dr. Wily', 'Dr. Light', 'Mega Man', 'Proto Man',
    'Bass Man', 'Roll Call', 'Stage Select', 'Boss Rush', 'Time Attack',
    'High Score', 'Best Time', 'Record Time', 'Final Boss', 'True Ending',
    'Normal Mode', 'Hard Mode', 'Easy Mode', 'Expert Mode', 'Speedrun',
    'No Damage', 'No Death', 'All Clear', 'Full Clear', '100%',
  ];

  for (final phrase in protectedPhrases) {
    if (result.contains(phrase)) {
      result = result.replaceAll(phrase, phrase.replaceAll(' ', nbsp));
    }
  }

  return result;
}
