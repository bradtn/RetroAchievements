import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme_utils.dart';

class ProfileAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String label;
  final Color color;

  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 40,
          backgroundImage: CachedNetworkImageProvider(imageUrl),
          onBackgroundImageError: (_, __) {},
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class ComparisonRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final dynamic myValue;
  final dynamic otherValue;

  const ComparisonRow({
    super.key,
    required this.label,
    required this.icon,
    required this.myValue,
    required this.otherValue,
  });

  @override
  Widget build(BuildContext context) {
    final my = int.tryParse(myValue.toString()) ?? 0;
    final other = int.tryParse(otherValue.toString()) ?? 0;
    final diff = my - other;
    final winner = my > other ? 'me' : (other > my ? 'other' : 'tie');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // My value
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: winner == 'me'
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: winner == 'me'
                      ? Border.all(color: Colors.green.withValues(alpha: 0.3))
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      _formatNumber(my),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: winner == 'me' ? Colors.green : null,
                      ),
                    ),
                    if (winner == 'me' && diff > 0)
                      Text(
                        '+${_formatNumber(diff)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Icon(icon, size: 20, color: Colors.grey),
                  Text(
                    label,
                    style: TextStyle(
                      color: context.subtitleColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Other value
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: winner == 'other'
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: winner == 'other'
                      ? Border.all(color: Colors.red.withValues(alpha: 0.3))
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      _formatNumber(other),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: winner == 'other' ? Colors.red : null,
                      ),
                    ),
                    if (winner == 'other' && -diff > 0)
                      Text(
                        '+${_formatNumber(-diff)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }
}

class CommonGameTile extends StatelessWidget {
  final dynamic myGame;
  final dynamic otherGame;

  const CommonGameTile({
    super.key,
    required this.myGame,
    required this.otherGame,
  });

  @override
  Widget build(BuildContext context) {
    final title = myGame['Title'] ?? 'Unknown';
    final imageIcon = myGame['ImageIcon'] ?? '';

    final myAch = myGame['NumAchieved'] ?? 0;
    final otherAch = otherGame['NumAchieved'] ?? 0;
    final total = myGame['NumPossibleAchievements'] ?? 0;

    final myPct = total > 0 ? (myAch / total * 100).toInt() : 0;
    final otherPct = total > 0 ? (otherAch / total * 100).toInt() : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: 'https://retroachievements.org$imageIcon',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[800],
                  child: const Icon(Icons.games),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$myPct%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: myPct > otherPct ? Colors.green : null,
                              ),
                            ),
                            LinearProgressIndicator(
                              value: myPct / 100,
                              backgroundColor: Colors.grey[700],
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$otherPct%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: otherPct > myPct ? Colors.red : null,
                              ),
                            ),
                            LinearProgressIndicator(
                              value: otherPct / 100,
                              backgroundColor: Colors.grey[700],
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
