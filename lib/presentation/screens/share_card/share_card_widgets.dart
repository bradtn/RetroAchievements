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
  return TextStyle(
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
        return Positioned.fill(
          child: Opacity(
            opacity: 0.15,
            child: CachedNetworkImage(
              imageUrl: gameImageUrl.startsWith('http')
                  ? gameImageUrl
                  : 'https://retroachievements.org$gameImageUrl',
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
  }
}

class PlayerTag extends StatelessWidget {
  final String username;

  const PlayerTag({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: CachedNetworkImageProvider(
              'https://retroachievements.org/UserPic/$username.png',
            ),
            backgroundColor: Colors.grey[700],
            onBackgroundImageError: (_, __) {},
          ),
          const SizedBox(width: 8),
          Text(
            username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class Branding extends StatelessWidget {
  const Branding({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.videogame_asset, color: Colors.white.withValues(alpha: 0.5), size: 16),
        const SizedBox(width: 6),
        Text(
          'RetroTrack',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          ' • ',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
        ),
        Text(
          'retroachievements.org',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
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
