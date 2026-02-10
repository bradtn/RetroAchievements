import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme_utils.dart';

/// Animated stat card with count-up ticker effect
class AnimatedStatCard extends StatefulWidget {
  final IconData icon;
  final int targetValue;
  final String label;
  final Color color;
  final int delay;
  final bool isRank;

  const AnimatedStatCard({
    super.key,
    required this.icon,
    required this.targetValue,
    required this.label,
    required this.color,
    this.delay = 0,
    this.isRank = false,
  });

  @override
  State<AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<AnimatedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // Start animation after delay
    Future.delayed(Duration(milliseconds: widget.delay + 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(widget.icon, color: widget.color, size: 24),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final currentValue = (_animation.value * widget.targetValue).round();
                String displayValue;

                if (widget.isRank) {
                  displayValue = widget.targetValue > 0 ? '#$currentValue' : '-';
                } else {
                  displayValue = _formatNumber(currentValue);
                }

                return Text(
                  displayValue,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: widget.color,
                  ),
                );
              },
            ),
            Text(
              widget.label,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecentGameTile extends StatelessWidget {
  final Map<String, dynamic> game;
  final VoidCallback onTap;

  const RecentGameTile({
    super.key,
    required this.game,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = game['Title'] ?? 'Unknown';
    final imageIcon = game['ImageIcon'] ?? '';
    final consoleName = game['ConsoleName'] ?? '';
    final numAchieved = game['NumAchieved'] ?? game['NumAwarded'] ?? 0;
    final numTotal = game['NumPossibleAchievements'] ?? game['AchievementsPossible'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: 'https://retroachievements.org$imageIcon',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[800],
                  child: const Icon(Icons.games, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // Console chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                consoleName,
                style: const TextStyle(color: Colors.blue, fontSize: 8, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            // Achievement chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '$numAchieved/$numTotal',
                style: const TextStyle(color: Colors.green, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecentAchievementTile extends StatelessWidget {
  final Map<String, dynamic> achievement;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const RecentAchievementTile({
    super.key,
    required this.achievement,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final title = achievement['Title'] ?? 'Achievement';
    final badgeName = achievement['BadgeName'] ?? '';
    final gameTitle = achievement['GameTitle'] ?? '';
    final points = achievement['Points'] ?? 0;
    final dateEarned = achievement['Date'] ?? achievement['DateEarned'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: badgeName.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const DefaultBadge(),
                      )
                    : const DefaultBadge(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      gameTitle,
                      style: TextStyle(fontSize: 12, color: context.subtitleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$points pts',
                            style: TextStyle(color: Colors.amber[600], fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatProfileDate(dateEarned),
                          style: TextStyle(fontSize: 10, color: context.subtitleColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.subtitleColor),
            ],
          ),
        ),
      ),
    );
  }
}

class DefaultBadge extends StatelessWidget {
  final double size;

  const DefaultBadge({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[800],
      child: Icon(Icons.emoji_events, size: size / 2),
    );
  }
}

String formatProfileDate(String dateStr) {
  if (dateStr.isEmpty) return '';
  try {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}';
  } catch (_) {
    return dateStr;
  }
}
