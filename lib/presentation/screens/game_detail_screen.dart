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

  // Scroll controller for scroll-to-top button
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _loadGame();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Show button after scrolling down 300 pixels
    final shouldShow = _scrollController.offset > 300;
    if (shouldShow != _showScrollToTop) {
      setState(() => _showScrollToTop = shouldShow);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
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
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              onPressed: _scrollToTop,
              tooltip: 'Scroll to top',
              child: const Icon(Icons.arrow_upward),
            )
          : null,
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

    final isLightMode = Theme.of(context).brightness == Brightness.light;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // App bar with image - no action buttons here to avoid overlap
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          // Set colors for collapsed state based on theme
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: isLightMode ? Colors.grey[900] : Colors.white,
          flexibleSpace: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate how collapsed the app bar is (0 = expanded, 1 = collapsed)
              final expandedHeight = 200.0;
              final collapsedHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
              final currentHeight = constraints.maxHeight;
              final collapseRatio = ((expandedHeight - currentHeight) / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);

              // Transition text color: white when expanded, theme color when collapsed
              final titleColor = isLightMode
                  ? Color.lerp(Colors.white, Colors.grey[900], collapseRatio)!
                  : Colors.white;

              // Fade shadow as we collapse (shadow not needed on solid bg)
              final shadowOpacity = (1.0 - collapseRatio).clamp(0.0, 1.0);

              return FlexibleSpaceBar(
                title: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black.withOpacity(shadowOpacity),
                      ),
                    ],
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
              );
            },
          ),
        ),

        // Action buttons row - separate from app bar to avoid overlap
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                // Share button
                Expanded(
                  child: OutlinedButton.icon(
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
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Favorite button
                Expanded(
                  child: _FavoriteButtonLarge(
                    gameId: widget.gameId,
                    title: title,
                    imageIcon: imageIcon,
                    consoleName: console,
                    numAchievements: numAchievements,
                    earnedAchievements: numAwarded,
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
                  // Title row with earned count and sort
                  Row(
                    children: [
                      Text('Achievements', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$numAwarded/$numAchievements',
                          style: const TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      // Sort dropdown
                      PopupMenuButton<AchievementSort>(
                        onSelected: (v) => setState(() => _sort = v),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[600]!),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort, size: 14),
                              const SizedBox(width: 4),
                              Text(_getSortLabel(_sort), style: const TextStyle(fontSize: 11)),
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
                  const SizedBox(height: 10),
                  // Filter chips - using Wrap for better layout
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _filter == AchievementFilter.all && !_showMissable,
                        onTap: () => setState(() {
                          _filter = AchievementFilter.all;
                          _showMissable = false;
                        }),
                      ),
                      _FilterChip(
                        label: 'Earned',
                        selected: _filter == AchievementFilter.earned,
                        onTap: () => setState(() {
                          _filter = AchievementFilter.earned;
                          _showMissable = false;
                        }),
                        color: Colors.green,
                      ),
                      _FilterChip(
                        label: 'Unearned',
                        selected: _filter == AchievementFilter.unearned,
                        onTap: () => setState(() {
                          _filter = AchievementFilter.unearned;
                          _showMissable = false;
                        }),
                        color: Colors.orange,
                      ),
                      _FilterChip(
                        label: 'Missable',
                        selected: _showMissable,
                        onTap: () => setState(() {
                          _showMissable = true;
                          _filter = AchievementFilter.all;
                        }),
                        color: Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Static rarity legend
                  _buildStaticRarityLegend(),
                ],
              ),
            ),
          ),

        // Achievements list (only show if game has achievements)
        if (numAchievements > 0)
          Builder(
            builder: (context) {
              final filtered = _getFilteredAchievements(achievements);

              // Show message if filtering returns no results
              if (filtered.isEmpty && _showMissable) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.info_outline, size: 48, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          'No missable achievements found',
                          style: TextStyle(color: context.subtitleColor, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This game may not have any achievements marked as missable by the developers.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.subtitleColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= filtered.length) return null;
                    return _AchievementTile(
                      achievement: filtered[index],
                      numDistinctPlayers: numDistinctPlayers is int ? numDistinctPlayers : int.tryParse(numDistinctPlayers.toString()) ?? 0,
                    );
                  },
                  childCount: filtered.length,
                ),
              );
            },
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  List<Map<String, dynamic>> _getFilteredAchievements(Map<String, dynamic> achievements) {
    var list = achievements.values.cast<Map<String, dynamic>>().toList();

    // Filter by earned/unearned
    if (_filter == AchievementFilter.earned) {
      list = list.where((a) => a['DateEarned'] != null || a['DateEarnedHardcore'] != null).toList();
    } else if (_filter == AchievementFilter.unearned) {
      list = list.where((a) => a['DateEarned'] == null && a['DateEarnedHardcore'] == null).toList();
    }

    // Filter by missable achievements
    // RetroAchievements API uses "Type" field with value "missable"
    if (_showMissable) {
      list = list.where((a) {
        // Check various possible field names and formats
        final type = (a['Type'] ?? a['type'] ?? '').toString().toLowerCase();
        final flags = a['Flags'] ?? a['flags'] ?? 0;
        final isMissable = type == 'missable' ||
                          type.contains('missable') ||
                          flags == 4 ||
                          (flags is int && (flags & 4) != 0);
        return isMissable;
      }).toList();
    }

    // Sort
    switch (_sort) {
      case AchievementSort.points:
        list.sort((a, b) => (b['Points'] ?? 0).compareTo(a['Points'] ?? 0));
        break;
      case AchievementSort.rarity:
        // Sort by NumAwarded (fewer unlocks = rarer, shows first)
        list.sort((a, b) => (a['NumAwarded'] ?? 0).compareTo(b['NumAwarded'] ?? 0));
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

  Widget _buildStaticRarityLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.grey.shade100
            : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem(Icons.diamond, Colors.red, '<5%'),
          _buildLegendItem(Icons.star, Colors.purple, '<15%'),
          _buildLegendItem(Icons.hexagon, Colors.blue, '<40%'),
          _buildLegendItem(Icons.circle, Colors.grey, '40%+'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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

  // Check if achievement is missable
  bool _isMissable(Map<String, dynamic> achievement) {
    final type = (achievement['Type'] ?? achievement['type'] ?? '').toString().toLowerCase();
    final flags = achievement['Flags'] ?? achievement['flags'] ?? 0;
    return type == 'missable' ||
           type.contains('missable') ||
           flags == 4 ||
           (flags is int && (flags & 4) != 0);
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
    final isMissable = _isMissable(achievement);

    final rarityInfo = _getRarityInfo(numAwarded, numDistinctPlayers);

    // Calculate unlock percentage
    final unlockPercent = numDistinctPlayers > 0
        ? (numAwarded / numDistinctPlayers * 100)
        : 0.0;

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
                // Rarity badge with percentage (Premium feature)
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
                          numDistinctPlayers > 0
                              ? '${unlockPercent.toStringAsFixed(1)}%'
                              : rarityInfo['label'] as String,
                          style: TextStyle(color: rarityInfo['color'] as Color, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                if (isPremium && numAwarded > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$numAwarded unlocks',
                    style: TextStyle(color: context.subtitleColor, fontSize: 10),
                  ),
                ],
                // Missable badge
                if (isMissable) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 10, color: Colors.red),
                        SizedBox(width: 3),
                        Text(
                          'Missable',
                          style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
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

class _FavoriteButtonLarge extends ConsumerWidget {
  final int gameId;
  final String title;
  final String imageIcon;
  final String consoleName;
  final int numAchievements;
  final int earnedAchievements;

  const _FavoriteButtonLarge({
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

    return isFavorite
        ? FilledButton.icon(
            onPressed: () => _toggleFavorite(context, ref, isFavorite),
            icon: const Icon(Icons.star, size: 18),
            label: const Text('Favorited'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          )
        : OutlinedButton.icon(
            onPressed: () => _toggleFavorite(context, ref, isFavorite),
            icon: const Icon(Icons.star_border, size: 18),
            label: const Text('Favorite'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          );
  }

  void _toggleFavorite(BuildContext context, WidgetRef ref, bool isFavorite) {
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
  }
}
