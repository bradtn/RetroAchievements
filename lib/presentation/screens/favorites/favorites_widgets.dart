import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/favorites_provider.dart';

class FavoriteCard extends StatelessWidget {
  final FavoriteGame game;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback? onPin;
  final VoidCallback? onUnpin;
  final VoidCallback onRemove;

  const FavoriteCard({
    super.key,
    required this.game,
    required this.isPinned,
    required this.onTap,
    this.onPin,
    this.onUnpin,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game icon
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: 'https://retroachievements.org${game.imageIcon}',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey[800],
                        child: const Icon(Icons.games),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Game info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row with wishlist badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                game.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Console and wishlist badges
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                game.consoleName,
                                style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            ),
                            if (game.fromWishlist)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bookmark, size: 10, color: Colors.purple),
                                    SizedBox(width: 2),
                                    Text(
                                      'Wishlist',
                                      style: TextStyle(color: Colors.purple, fontSize: 10, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Stats row
                        Row(
                          children: [
                            // Achievement chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.emoji_events, size: 12, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${game.earnedAchievements}/${game.numAchievements}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Points chip
                            if (game.totalPoints > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.stars, size: 12, color: Colors.amber[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${game.earnedPoints}/${game.totalPoints} pts',
                                      style: TextStyle(
                                        color: Colors.amber[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Completion badge
                  CompletionBadge(percent: game.percent),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: game.progress,
                  minHeight: 6,
                  backgroundColor: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey[300]
                      : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isPinned && onUnpin != null)
                    TextButton.icon(
                      onPressed: onUnpin,
                      icon: const Icon(Icons.push_pin, size: 16),
                      label: const Text('Unpin'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  else if (onPin != null)
                    TextButton.icon(
                      onPressed: onPin,
                      icon: const Icon(Icons.push_pin_outlined, size: 16),
                      label: const Text('Pin'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CompletionBadge extends StatelessWidget {
  final int percent;

  const CompletionBadge({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData? icon;

    if (percent == 100) {
      color = Colors.amber;
      icon = Icons.workspace_premium;
    } else if (percent >= 75) {
      color = Colors.purple;
    } else if (percent >= 50) {
      color = Colors.blue;
    } else if (percent >= 25) {
      color = Colors.green;
    } else {
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
          ],
          Text(
            '$percent%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
