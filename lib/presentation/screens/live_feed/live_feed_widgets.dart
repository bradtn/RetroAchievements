import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FeedItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final String? gameIcon;
  final bool isCurrentUser;
  final VoidCallback onUserTap;
  final VoidCallback onGameTap;

  const FeedItemTile({
    super.key,
    required this.item,
    this.gameIcon,
    required this.isCurrentUser,
    required this.onUserTap,
    required this.onGameTap,
  });

  @override
  Widget build(BuildContext context) {
    final user = item['User'] ?? item['user'] ?? 'Unknown';
    final gameTitle = item['GameTitle'] ?? item['gameTitle'] ?? item['Title'] ?? 'Unknown Game';
    final consoleName = item['ConsoleName'] ?? item['consoleName'] ?? '';
    final awardKind = item['AwardKind'] ?? item['awardKind'] ?? item['kind'] ?? 'beaten-softcore';
    final awardDate = item['AwardedAt'] ?? item['awardedAt'] ?? item['AwardDate'] ?? '';

    // Construct user avatar URL - API doesn't return this but URL pattern is known
    final userPic = '/UserPic/$user.png';

    // Determine award type and styling
    final awardInfo = _getAwardInfo(awardKind);

    // Parse date
    String timeAgo = '';
    try {
      final date = DateTime.parse(awardDate);
      timeAgo = _formatTimeAgo(date);
    } catch (_) {
      timeAgo = awardDate;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onGameTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: isCurrentUser
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 2),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User row
                Row(
                  children: [
                    GestureDetector(
                      onTap: onUserTap,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: 'https://retroachievements.org$userPic',
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 32,
                                height: 32,
                                color: Colors.grey[800],
                                child: Center(
                                  child: Text(
                                    user.isNotEmpty ? user[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 32,
                                height: 32,
                                color: Colors.grey[800],
                                child: Center(
                                  child: Text(
                                    user.isNotEmpty ? user[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            user,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCurrentUser ? Colors.amber : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Award badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: awardInfo['color'].withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(awardInfo['icon'] as IconData, size: 12, color: awardInfo['color']),
                          const SizedBox(width: 4),
                          Text(
                            awardInfo['label'] as String,
                            style: TextStyle(
                              color: awardInfo['color'],
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Time ago
                    Text(
                      timeAgo,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[500]
                            : Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Game info row
                Row(
                  children: [
                    // Game icon - use cached icon or styled placeholder
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: gameIcon != null && gameIcon!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: 'https://retroachievements.org$gameIcon',
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _buildGamePlaceholder(awardInfo),
                              errorWidget: (_, __, ___) => _buildGamePlaceholder(awardInfo),
                            )
                          : _buildGamePlaceholder(awardInfo),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gameTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (consoleName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              consoleName,
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[500],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGamePlaceholder(Map<String, dynamic> awardInfo) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: (awardInfo['color'] as Color).withValues(alpha: 0.15),
        border: Border.all(
          color: (awardInfo['color'] as Color).withValues(alpha: 0.3),
        ),
      ),
      child: Icon(
        Icons.videogame_asset,
        color: awardInfo['color'] as Color,
        size: 24,
      ),
    );
  }

  Map<String, dynamic> _getAwardInfo(String awardKind) {
    final kind = awardKind.toLowerCase();

    if (kind.contains('mastery') || kind.contains('mastered')) {
      return {
        'label': 'MASTERED',
        'color': Colors.amber,
        'icon': Icons.emoji_events,
      };
    } else if (kind.contains('beaten-hardcore') || kind.contains('completed-hardcore')) {
      return {
        'label': 'BEATEN (HC)',
        'color': Colors.green,
        'icon': Icons.verified,
      };
    } else if (kind.contains('beaten') || kind.contains('completed')) {
      return {
        'label': 'BEATEN',
        'color': Colors.blue,
        'icon': Icons.check_circle,
      };
    } else if (kind.contains('event')) {
      return {
        'label': 'EVENT',
        'color': Colors.purple,
        'icon': Icons.celebration,
      };
    }

    return {
      'label': 'AWARD',
      'color': Colors.grey,
      'icon': Icons.military_tech,
    };
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
