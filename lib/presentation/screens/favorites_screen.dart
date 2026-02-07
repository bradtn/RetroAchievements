import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/favorites_provider.dart';
import 'game_detail_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favState = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          if (favState.favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: () => _showSortOptions(context),
              tooltip: 'Sort',
            ),
        ],
      ),
      body: favState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : favState.favorites.isEmpty
              ? _buildEmptyState(context)
              : _buildFavoritesList(context, ref, favState),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, size: 80, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No Favorites Yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Star games you want to track and they\'ll appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList(BuildContext context, WidgetRef ref, FavoritesState state) {
    final pinned = state.getPinned();
    final others = state.favorites.where((f) => !f.isPinned).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pinned game (for widget)
        if (pinned != null) ...[
          Row(
            children: [
              const Icon(Icons.push_pin, size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'PINNED FOR WIDGET',
                style: TextStyle(
                  color: Colors.amber[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _FavoriteCard(
            game: pinned,
            isPinned: true,
            onTap: () => _openGame(context, pinned),
            onUnpin: () => ref.read(favoritesProvider.notifier).unpinAll(),
            onRemove: () => ref.read(favoritesProvider.notifier).removeFavorite(pinned.gameId),
          ),
          const SizedBox(height: 24),
        ],

        // Other favorites
        if (others.isNotEmpty) ...[
          Text(
            'TRACKING ${others.length} GAME${others.length == 1 ? '' : 'S'}',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          ...others.map((game) => _FavoriteCard(
            game: game,
            isPinned: false,
            onTap: () => _openGame(context, game),
            onPin: () => ref.read(favoritesProvider.notifier).setPinned(game.gameId),
            onRemove: () => ref.read(favoritesProvider.notifier).removeFavorite(game.gameId),
          )),
        ],
      ],
    );
  }

  void _openGame(BuildContext context, FavoriteGame game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameDetailScreen(
          gameId: game.gameId,
          gameTitle: game.title,
        ),
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.sort_by_alpha),
            title: const Text('Sort by Name'),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            leading: const Icon(Icons.percent),
            title: const Text('Sort by Progress'),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Sort by Date Added'),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final FavoriteGame game;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback? onPin;
  final VoidCallback? onUnpin;
  final VoidCallback onRemove;

  const _FavoriteCard({
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
                children: [
                  // Game icon
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: 'https://retroachievements.org${game.imageIcon}',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
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
                        Text(
                          game.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          game.consoleName,
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Completion badge
                  _CompletionBadge(percent: game.percent),
                ],
              ),
              const SizedBox(height: 12),
              // Progress bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: game.progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${game.earnedAchievements}/${game.numAchievements}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
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
                      style: TextButton.styleFrom(foregroundColor: Colors.amber),
                    )
                  else if (onPin != null)
                    TextButton.icon(
                      onPressed: onPin,
                      icon: const Icon(Icons.push_pin_outlined, size: 16),
                      label: const Text('Pin to Widget'),
                    ),
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
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

class _CompletionBadge extends StatelessWidget {
  final int percent;

  const _CompletionBadge({required this.percent});

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
