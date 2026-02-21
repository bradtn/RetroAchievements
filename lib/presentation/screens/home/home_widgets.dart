import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme_utils.dart';
import '../../../core/animations.dart';
import '../game_detail_screen.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool compact;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: compact ? 22 : 32),
            SizedBox(height: compact ? 4 : 8),
            Text(value, style: (compact
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.headlineSmall)?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: compact ? 9 : null,
            )),
          ],
        ),
      ),
    );
  }
}

class GameListTile extends StatelessWidget {
  final dynamic game;
  final bool compact;

  const GameListTile({super.key, required this.game, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final imageUrl = 'https://retroachievements.org${game['ImageIcon']}';
    final earned = game['NumAchieved'] ?? 0;
    final total = game['NumPossibleAchievements'] ?? 0;
    final gameId = game['GameID'] ?? game['ID'];
    final heroTag = 'game_image_$gameId';

    final imageSize = compact ? 36.0 : 48.0;

    return TappableCard(
      onTap: gameId != null ? () {
        Navigator.push(
          context,
          SlidePageRoute(
            page: GameDetailScreen(
              gameId: int.tryParse(gameId.toString()) ?? 0,
              gameTitle: game['Title'],
              heroTag: heroTag,
            ),
          ),
        );
      } : null,
      child: Card(
        margin: EdgeInsets.only(bottom: compact ? 4 : 8),
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Row(
            children: [
              Hero(
                tag: heroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(compact ? 6 : 8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: imageSize,
                      height: imageSize,
                      color: Colors.grey[800],
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: imageSize,
                      height: imageSize,
                      color: Colors.grey[800],
                      child: Icon(Icons.games, size: imageSize / 2),
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game['Title'] ?? 'Unknown Game',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: compact ? 12 : 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: compact ? 3 : 6),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: compact ? 1 : 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            game['ConsoleName'] ?? '',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: compact ? 8 : 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (total > 0) ...[
                          SizedBox(width: compact ? 4 : 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: compact ? 1 : 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.emoji_events, size: compact ? 8 : 10, color: Colors.green),
                                SizedBox(width: compact ? 2 : 3),
                                Text(
                                  '$earned/$total',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: compact ? 8 : 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey, size: compact ? 18 : 24),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentAchievementTile extends StatelessWidget {
  final dynamic achievement;

  const RecentAchievementTile({super.key, required this.achievement});

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      var date = DateTime.parse(dateStr);
      date = DateTime.utc(date.year, date.month, date.day, date.hour, date.minute, date.second).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeUrl = 'https://retroachievements.org/Badge/${achievement['BadgeName']}.png';
    final gameId = achievement['GameID'];
    final gameTitle = achievement['GameTitle'] ?? '';
    final dateStr = achievement['Date'] ?? achievement['DateEarned'] ?? '';
    final formattedDate = _formatDate(dateStr);
    final hardcoreMode = achievement['HardcoreMode'] == 1 ||
                         achievement['HardcoreMode'] == true ||
                         achievement['Hardcore'] == 1 ||
                         achievement['Hardcore'] == true ||
                         achievement['DateEarnedHardcore'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: gameId != null ? () {
          Haptics.light();
          final id = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
          if (id > 0) {
            Navigator.push(
              context,
              SlidePageRoute(
                page: GameDetailScreen(gameId: id, gameTitle: gameTitle),
              ),
            );
          }
        } : null,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: badgeUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 48,
                height: 48,
                color: Colors.grey[800],
              ),
              errorWidget: (_, __, ___) => Container(
                width: 48,
                height: 48,
                color: Colors.grey[800],
                child: const Icon(Icons.emoji_events),
              ),
            ),
          ),
          title: Text(achievement['Title'] ?? 'Achievement'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                achievement['Description'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.stars, size: 12, color: Colors.amber[400]),
                  const SizedBox(width: 4),
                  Text(
                    '${achievement['Points'] ?? 0} pts',
                    style: TextStyle(color: Colors.amber[400], fontSize: 12),
                  ),
                  if (hardcoreMode) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'HC',
                        style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  if (formattedDate.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.access_time, size: 10, color: Colors.grey[500]),
                    const SizedBox(width: 2),
                    Text(
                      formattedDate,
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                gameTitle,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          isThreeLine: true,
        ),
      ),
    );
  }
}
