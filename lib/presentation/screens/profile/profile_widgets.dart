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
  final bool compact;

  const AnimatedStatCard({
    super.key,
    required this.icon,
    required this.targetValue,
    required this.label,
    required this.color,
    this.delay = 0,
    this.isRank = false,
    this.compact = false,
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
    final iconSize = widget.compact ? 18.0 : 24.0;
    final valueFontSize = widget.compact ? 13.0 : 16.0;
    final labelFontSize = widget.compact ? 9.0 : 11.0;
    final cardPadding = widget.compact ? 8.0 : 12.0;
    final spacing = widget.compact ? 4.0 : 8.0;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          children: [
            Icon(widget.icon, color: widget.color, size: iconSize),
            SizedBox(height: spacing),
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
                    fontSize: valueFontSize,
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
                fontSize: labelFontSize,
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
  final bool compact;

  const RecentGameTile({
    super.key,
    required this.game,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = game['Title'] ?? 'Unknown';
    final imageIcon = game['ImageIcon'] ?? '';
    final consoleName = game['ConsoleName'] ?? '';
    final numAchieved = game['NumAchieved'] ?? game['NumAwarded'] ?? 0;
    final numTotal = game['NumPossibleAchievements'] ?? game['AchievementsPossible'] ?? 0;

    final imageSize = compact ? 60.0 : 80.0;
    final tileWidth = compact ? 85.0 : 110.0;
    final titleFontSize = compact ? 9.0 : 11.0;
    final chipFontSize = compact ? 7.0 : 8.0;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: tileWidth,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(compact ? 8 : 12),
              child: CachedNetworkImage(
                imageUrl: 'https://retroachievements.org$imageIcon',
                width: imageSize,
                height: imageSize,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: imageSize,
                  height: imageSize,
                  color: Colors.grey[800],
                  child: Icon(Icons.games, size: imageSize / 2.5),
                ),
              ),
            ),
            SizedBox(height: compact ? 4 : 6),
            Text(
              title,
              style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: compact ? 2 : 4),
            // Console chip
            Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                consoleName,
                style: TextStyle(color: Colors.blue, fontSize: chipFontSize, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: compact ? 1 : 2),
            // Achievement chip
            Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '$numAchieved/$numTotal',
                style: TextStyle(color: Colors.green, fontSize: chipFontSize, fontWeight: FontWeight.bold),
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
  final bool compact;

  const RecentAchievementTile({
    super.key,
    required this.achievement,
    required this.onTap,
    required this.onLongPress,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = achievement['Title'] ?? 'Achievement';
    final badgeName = achievement['BadgeName'] ?? '';
    final gameTitle = achievement['GameTitle'] ?? '';
    final points = achievement['Points'] ?? 0;
    final dateEarned = achievement['Date'] ?? achievement['DateEarned'] ?? '';

    final badgeSize = compact ? 36.0 : 44.0;
    final cardPadding = compact ? 8.0 : 12.0;
    final titleFontSize = compact ? 13.0 : 14.0;
    final subtitleFontSize = compact ? 10.0 : 12.0;
    final chipFontSize = compact ? 8.0 : 10.0;

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 4 : 8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 6 : 8),
                child: badgeName.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
                        width: badgeSize,
                        height: badgeSize,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => DefaultBadge(size: badgeSize),
                      )
                    : DefaultBadge(size: badgeSize),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: titleFontSize),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      gameTitle,
                      style: TextStyle(fontSize: subtitleFontSize, color: context.subtitleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: compact ? 2 : 4),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: compact ? 1 : 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$points pts',
                            style: TextStyle(color: Colors.amber[600], fontSize: chipFontSize),
                          ),
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        Text(
                          formatProfileDate(dateEarned),
                          style: TextStyle(fontSize: chipFontSize, color: context.subtitleColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.subtitleColor, size: compact ? 18 : 24),
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
