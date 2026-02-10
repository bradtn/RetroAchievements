import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CardStyle {
  final String name;
  final List<Color> colors;

  CardStyle(this.name, this.colors);
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
