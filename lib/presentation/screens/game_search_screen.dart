import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../providers/game_cache_provider.dart';
import 'game_detail_screen.dart';

class GameSearchScreen extends ConsumerStatefulWidget {
  const GameSearchScreen({super.key});

  @override
  ConsumerState<GameSearchScreen> createState() => _GameSearchScreenState();
}

class _GameSearchScreenState extends ConsumerState<GameSearchScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cacheState = ref.watch(gameCacheProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Games'),
        actions: [
          if (cacheState.lastUpdated != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: cacheState.isLoading
                  ? null
                  : () => ref.read(gameCacheProvider.notifier).buildCache(),
              tooltip: 'Refresh game database',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for any game...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
              autofocus: true,
            ),
          ),

          // Content
          Expanded(
            child: _buildContent(cacheState),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(GameCacheState cacheState) {
    // If cache is empty and not loading, show build prompt
    if (cacheState.games.isEmpty && !cacheState.isLoading) {
      return _buildEmptyCacheView();
    }

    // If loading, show progress
    if (cacheState.isLoading) {
      return _buildLoadingView(cacheState);
    }

    // If we have games, show search results
    if (_searchQuery.isEmpty) {
      return _buildEmptySearchView(cacheState);
    }

    final results = ref.read(gameCacheProvider.notifier).search(_searchQuery);

    if (results.isEmpty) {
      return _buildNoResultsView();
    }

    return _buildResultsList(results);
  }

  Widget _buildEmptyCacheView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_download, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 24),
            Text(
              'Game Database',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'The game database downloads automatically in the background. If it hasn\'t started yet, tap the button below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.subtitleColor),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => ref.read(gameCacheProvider.notifier).buildCache(),
              icon: const Icon(Icons.download),
              label: const Text('Download Now'),
            ),
            const SizedBox(height: 12),
            Text(
              'This may take a minute',
              style: TextStyle(color: context.subtitleColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(GameCacheState cacheState) {
    final percent = (cacheState.progress * 100).toInt();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: cacheState.progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[800],
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Building game database...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Downloading games from all consoles',
              style: TextStyle(color: context.subtitleColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchView(GameCacheState cacheState) {
    final gameCount = cacheState.games.length;
    final lastUpdated = cacheState.lastUpdated;
    final daysAgo = lastUpdated != null
        ? DateTime.now().difference(lastUpdated).inDays
        : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 24),
            Text(
              'Search $gameCount games',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Type to search across all platforms',
              style: TextStyle(color: context.subtitleColor),
            ),
            const SizedBox(height: 16),
            Text(
              daysAgo == 0
                  ? 'Database updated today'
                  : 'Last updated $daysAgo days ago',
              style: TextStyle(color: context.subtitleColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No games found for "$_searchQuery"',
            style: TextStyle(color: context.subtitleColor),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(List<CachedGame> results) {
    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final game = results[index];
        return _GameTile(game: game);
      },
    );
  }
}

class _GameTile extends StatelessWidget {
  final CachedGame game;

  const _GameTile({required this.game});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameDetailScreen(
                gameId: game.id,
                gameTitle: game.title,
              ),
            ),
          );
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: 'https://retroachievements.org${game.imageIcon}',
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
        title: Text(
          game.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                game.consoleName,
                style: TextStyle(color: context.subtitleColor, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (game.numAchievements > 0) ...[
              Icon(Icons.emoji_events, size: 12, color: Colors.amber[400]),
              const SizedBox(width: 4),
              Text(
                '${game.numAchievements}',
                style: TextStyle(color: context.subtitleColor, fontSize: 12),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}
