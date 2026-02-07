import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/premium_provider.dart';
import 'share_card_screen.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  final int gameId;
  final String? gameTitle;

  const GameDetailScreen({
    super.key,
    required this.gameId,
    this.gameTitle,
  });

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

enum AchievementFilter { all, earned, unearned }
enum AchievementSort { normal, points, rarity, title }

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  Map<String, dynamic>? _gameData;
  bool _isLoading = true;
  String? _error;

  // Filter state
  AchievementFilter _filter = AchievementFilter.all;
  AchievementSort _sort = AchievementSort.normal;
  bool _showMissable = false;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final api = ref.read(apiDataSourceProvider);
    final data = await api.getGameInfoWithProgress(widget.gameId);

    setState(() {
      _gameData = data;
      _isLoading = false;
      if (data == null) _error = 'Failed to load game data';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _gameData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error ?? 'Unknown error'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadGame, child: const Text('Retry')),
          ],
        ),
      );
    }

    final title = _gameData!['Title'] ?? 'Unknown Game';
    final console = _gameData!['ConsoleName'] ?? '';
    final imageIcon = _gameData!['ImageIcon'] ?? '';
    final imageTitle = _gameData!['ImageTitle'] ?? '';
    final publisher = _gameData!['Publisher'];
    final developer = _gameData!['Developer'];
    final genre = _gameData!['Genre'];
    final released = _gameData!['Released'];
    final numAchievements = _gameData!['NumAchievements'] ?? 0;
    final numAwarded = _gameData!['NumAwardedToUser'] ?? 0;
    final completion = _gameData!['UserCompletion'] ?? '0%';
    final achievements = _gameData!['Achievements'] as Map<String, dynamic>? ?? {};
    final numDistinctPlayers = _gameData!['NumDistinctPlayers'] ?? _gameData!['NumDistinctPlayersCasual'] ?? 0;

    final progress = numAchievements > 0 ? numAwarded / numAchievements : 0.0;

    return CustomScrollView(
      slivers: [
        // App bar with image
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShareCardScreen(
                      type: ShareCardType.game,
                      data: _gameData!,
                    ),
                  ),
                );
              },
            ),
            _FavoriteButton(
              gameId: widget.gameId,
              title: title,
              imageIcon: imageIcon,
              consoleName: console,
              numAchievements: numAchievements,
              earnedAchievements: numAwarded,
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              title,
              style: const TextStyle(
                shadows: [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (imageTitle.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: 'https://retroachievements.org$imageTitle',
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: Colors.deepPurple),
                  )
                else
                  Container(color: Colors.deepPurple),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Game info card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: 'https://retroachievements.org$imageIcon',
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 64, height: 64,
                              color: Colors.grey[800],
                              child: const Icon(Icons.games),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(console, style: TextStyle(color: context.subtitleColor)),
                              const SizedBox(height: 8),
                              if (numAchievements > 0) ...[
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey[700],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$numAwarded / $numAchievements achievements ($completion)',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ] else
                                Text(
                                  'No achievements yet',
                                  style: TextStyle(
                                    color: context.subtitleColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 24),

                    // Details
                    if (developer != null && developer.toString().isNotEmpty)
                      _DetailRow(Icons.code, 'Developer', developer.toString()),
                    if (publisher != null && publisher.toString().isNotEmpty)
                      _DetailRow(Icons.business, 'Publisher', publisher.toString()),
                    if (genre != null && genre.toString().isNotEmpty)
                      _DetailRow(Icons.category, 'Genre', genre.toString()),
                    if (released != null && released.toString().isNotEmpty)
                      _DetailRow(Icons.calendar_today, 'Released', released.toString()),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Achievements header (only show if game has achievements)
        if (numAchievements > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Achievements', style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$numAwarded earned',
                          style: const TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _filter == AchievementFilter.all,
                          onTap: () => setState(() => _filter = AchievementFilter.all),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Earned',
                          selected: _filter == AchievementFilter.earned,
                          onTap: () => setState(() => _filter = AchievementFilter.earned),
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Unearned',
                          selected: _filter == AchievementFilter.unearned,
                          onTap: () => setState(() => _filter = AchievementFilter.unearned),
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 16),
                        // Sort dropdown
                        PopupMenuButton<AchievementSort>(
                          onSelected: (v) => setState(() => _sort = v),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[600]!),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sort, size: 16),
                                const SizedBox(width: 4),
                                Text(_getSortLabel(_sort), style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          itemBuilder: (ctx) => [
                            _buildSortItem(AchievementSort.normal, 'Default'),
                            _buildSortItem(AchievementSort.points, 'Points'),
                            _buildSortItem(AchievementSort.rarity, 'Rarity'),
                            _buildSortItem(AchievementSort.title, 'Title'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Achievements list (only show if game has achievements)
        if (numAchievements > 0)
          SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final filtered = _getFilteredAchievements(achievements);
              if (index >= filtered.length) return null;
              return _AchievementTile(
                achievement: filtered[index],
                numDistinctPlayers: numDistinctPlayers is int ? numDistinctPlayers : int.tryParse(numDistinctPlayers.toString()) ?? 0,
              );
            },
            childCount: _getFilteredAchievements(achievements).length,
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  List<Map<String, dynamic>> _getFilteredAchievements(Map<String, dynamic> achievements) {
    var list = achievements.values.cast<Map<String, dynamic>>().toList();

    // Filter
    if (_filter == AchievementFilter.earned) {
      list = list.where((a) => a['DateEarned'] != null || a['DateEarnedHardcore'] != null).toList();
    } else if (_filter == AchievementFilter.unearned) {
      list = list.where((a) => a['DateEarned'] == null && a['DateEarnedHardcore'] == null).toList();
    }

    // Sort
    switch (_sort) {
      case AchievementSort.points:
        list.sort((a, b) => (b['Points'] ?? 0).compareTo(a['Points'] ?? 0));
        break;
      case AchievementSort.rarity:
        // Sort by TrueRatio/Points ratio (higher = rarer), then by NumAwarded as tiebreaker
        list.sort((a, b) {
          final aPoints = (a['Points'] ?? 1) as int;
          final bPoints = (b['Points'] ?? 1) as int;
          final aRatio = aPoints > 0 ? (a['TrueRatio'] ?? 0) / aPoints : 0;
          final bRatio = bPoints > 0 ? (b['TrueRatio'] ?? 0) / bPoints : 0;
          final ratioCompare = bRatio.compareTo(aRatio);
          if (ratioCompare != 0) return ratioCompare;
          return (a['NumAwarded'] ?? 0).compareTo(b['NumAwarded'] ?? 0);
        });
        break;
      case AchievementSort.title:
        list.sort((a, b) => (a['Title'] ?? '').compareTo(b['Title'] ?? ''));
        break;
      case AchievementSort.normal:
        // Keep default order
        break;
    }

    return list;
  }

  String _getSortLabel(AchievementSort sort) {
    switch (sort) {
      case AchievementSort.normal: return 'Default';
      case AchievementSort.points: return 'Points';
      case AchievementSort.rarity: return 'Rarity';
      case AchievementSort.title: return 'Title';
    }
  }

  PopupMenuItem<AchievementSort> _buildSortItem(AchievementSort value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sort == value) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Colors.blue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? chipColor.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: selected ? chipColor : Colors.grey[600]!,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? chipColor : Colors.grey[400],
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _AchievementTile extends ConsumerWidget {
  final Map<String, dynamic> achievement;
  final int numDistinctPlayers;

  const _AchievementTile({required this.achievement, this.numDistinctPlayers = 0});

  // Get rarity info based on NumAwarded (how many players unlocked it)
  // Lower number = rarer achievement
  Map<String, dynamic> _getRarityInfo(int numAwarded, int numDistinct) {
    // Calculate percentage of players who earned this achievement
    // numDistinct = total distinct players for this game
    if (numDistinct > 0) {
      final percent = (numAwarded / numDistinct) * 100;
      if (percent < 5) return {'label': 'Ultra Rare', 'color': Colors.red, 'icon': Icons.diamond};
      if (percent < 15) return {'label': 'Rare', 'color': Colors.purple, 'icon': Icons.star};
      if (percent < 40) return {'label': 'Uncommon', 'color': Colors.blue, 'icon': Icons.hexagon};
      return {'label': 'Common', 'color': Colors.grey, 'icon': Icons.circle};
    }
    // Fallback to absolute numbers if no player count
    if (numAwarded < 100) return {'label': 'Ultra Rare', 'color': Colors.red, 'icon': Icons.diamond};
    if (numAwarded < 500) return {'label': 'Rare', 'color': Colors.purple, 'icon': Icons.star};
    if (numAwarded < 2000) return {'label': 'Uncommon', 'color': Colors.blue, 'icon': Icons.hexagon};
    return {'label': 'Common', 'color': Colors.grey, 'icon': Icons.circle};
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = achievement['Title'] ?? 'Achievement';
    final description = achievement['Description'] ?? '';
    final points = achievement['Points'] ?? 0;
    final trueRatio = achievement['TrueRatio'] ?? 0;
    final badgeName = achievement['BadgeName'] ?? '';
    final numAwarded = achievement['NumAwarded'] ?? 0;
    final isPremium = ref.watch(isPremiumProvider);

    final rarityInfo = _getRarityInfo(numAwarded, numDistinctPlayers);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: 48, height: 48,
              color: Colors.grey[800],
              child: const Icon(Icons.emoji_events),
            ),
          ),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
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
                    style: TextStyle(color: Colors.amber[400], fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                // Rarity badge (Premium feature)
                if (isPremium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (rarityInfo['color'] as Color).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(rarityInfo['icon'] as IconData, size: 10, color: rarityInfo['color'] as Color),
                        const SizedBox(width: 3),
                        Text(
                          rarityInfo['label'] as String,
                          style: TextStyle(color: rarityInfo['color'] as Color, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                if (isPremium && numAwarded > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '$numAwarded unlocks',
                    style: TextStyle(color: context.subtitleColor, fontSize: 10),
                  ),
                ],
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  final int gameId;
  final String title;
  final String imageIcon;
  final String consoleName;
  final int numAchievements;
  final int earnedAchievements;

  const _FavoriteButton({
    required this.gameId,
    required this.title,
    required this.imageIcon,
    required this.consoleName,
    required this.numAchievements,
    required this.earnedAchievements,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider).isFavorite(gameId);

    return IconButton(
      icon: Icon(
        isFavorite ? Icons.star : Icons.star_border,
        color: isFavorite ? Colors.amber : Colors.white,
      ),
      onPressed: () {
        final game = FavoriteGame(
          gameId: gameId,
          title: title,
          imageIcon: imageIcon,
          consoleName: consoleName,
          numAchievements: numAchievements,
          earnedAchievements: earnedAchievements,
          addedAt: DateTime.now(),
        );
        ref.read(favoritesProvider.notifier).toggleFavorite(game);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFavorite ? 'Removed from favorites' : 'Added to favorites'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }
}
