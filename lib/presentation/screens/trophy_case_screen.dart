import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../../core/responsive_layout.dart';
import '../providers/auth_provider.dart';
import 'game_detail_screen.dart';
import 'game_detail/game_detail_helpers.dart';
import 'share_card/share_card_screen.dart';

class TrophyCaseScreen extends ConsumerStatefulWidget {
  final String? username;

  const TrophyCaseScreen({super.key, this.username});

  @override
  ConsumerState<TrophyCaseScreen> createState() => _TrophyCaseScreenState();
}

class _TrophyCaseScreenState extends ConsumerState<TrophyCaseScreen> {
  List<dynamic> _masteredGames = [];
  bool _isLoading = true;
  String? _error;
  String _sortBy = 'recent'; // recent, title, console
  String? _filterConsole;
  String? _viewingUsername;

  @override
  void initState() {
    super.initState();
    _viewingUsername = widget.username ?? ref.read(authProvider).username;
    _loadMasteredGames();
  }

  Future<void> _loadMasteredGames() async {
    if (_viewingUsername == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiDataSourceProvider);
      final awards = await api.getUserAwards(_viewingUsername!);

      if (awards == null) {
        setState(() {
          _error = 'Failed to load awards';
          _isLoading = false;
        });
        return;
      }

      final visibleAwards = awards['VisibleUserAwards'] as List<dynamic>? ?? [];

      // Filter to only mastered games (100% completion)
      final mastered = visibleAwards.where((a) =>
        a['AwardType'] == 'Mastery/Completion' || a['AwardType'] == 'Mastery'
      ).toList();

      setState(() {
        _masteredGames = mastered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredAndSortedGames {
    var games = List<dynamic>.from(_masteredGames);

    // Filter by console
    if (_filterConsole != null) {
      games = games.where((g) => g['ConsoleName'] == _filterConsole).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'recent':
        games.sort((a, b) {
          final dateA = a['AwardedAt'] ?? '';
          final dateB = b['AwardedAt'] ?? '';
          return dateB.compareTo(dateA);
        });
        break;
      case 'title':
        games.sort((a, b) {
          final titleA = (a['Title'] ?? '').toString().toLowerCase();
          final titleB = (b['Title'] ?? '').toString().toLowerCase();
          return titleA.compareTo(titleB);
        });
        break;
      case 'console':
        games.sort((a, b) {
          final consoleA = (a['ConsoleName'] ?? '').toString();
          final consoleB = (b['ConsoleName'] ?? '').toString();
          final consoleCompare = consoleA.compareTo(consoleB);
          if (consoleCompare != 0) return consoleCompare;
          final titleA = (a['Title'] ?? '').toString().toLowerCase();
          final titleB = (b['Title'] ?? '').toString().toLowerCase();
          return titleA.compareTo(titleB);
        });
        break;
    }

    return games;
  }

  Set<String> get _availableConsoles {
    return _masteredGames
        .map((g) => g['ConsoleName'] as String? ?? 'Unknown')
        .toSet();
  }

  Map<String, int> get _consoleStats {
    final stats = <String, int>{};
    for (final game in _masteredGames) {
      final console = game['ConsoleName'] as String? ?? 'Unknown';
      stats[console] = (stats[console] ?? 0) + 1;
    }
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final myUsername = ref.read(authProvider).username;
    final isViewingSelf = _viewingUsername == myUsername;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trophy Case'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'recent',
                child: Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 20,
                        color: _sortBy == 'recent' ? Theme.of(context).colorScheme.primary : null),
                    const SizedBox(width: 12),
                    const Text('Most Recent'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'title',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha,
                        size: 20,
                        color: _sortBy == 'title' ? Theme.of(context).colorScheme.primary : null),
                    const SizedBox(width: 12),
                    const Text('Title A-Z'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'console',
                child: Row(
                  children: [
                    Icon(Icons.videogame_asset,
                        size: 20,
                        color: _sortBy == 'console' ? Theme.of(context).colorScheme.primary : null),
                    const SizedBox(width: 12),
                    const Text('By Console'),
                  ],
                ),
              ),
            ],
          ),
          if (_availableConsoles.length > 1)
            PopupMenuButton<String?>(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter',
              onSelected: (value) => setState(() => _filterConsole = value),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: null,
                  child: Row(
                    children: [
                      Icon(Icons.clear_all,
                          size: 20,
                          color: _filterConsole == null ? Theme.of(context).colorScheme.primary : null),
                      const SizedBox(width: 12),
                      const Text('All Consoles'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                ..._availableConsoles.map((console) => PopupMenuItem(
                  value: console,
                  child: Row(
                    children: [
                      Icon(Icons.videogame_asset,
                          size: 20,
                          color: _filterConsole == console ? Theme.of(context).colorScheme.primary : null),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          console,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: context.subtitleColor)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadMasteredGames,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMasteredGames,
                  child: _masteredGames.isEmpty
                      ? _buildEmptyState()
                      : _buildContent(isViewingSelf),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.workspace_premium, size: 64, color: Colors.amber),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Mastered Games Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete 100% of achievements in a game to add it to your trophy case!',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.subtitleColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isViewingSelf) {
    final games = _filteredAndSortedGames;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final isWidescreen = ResponsiveLayout.isWidescreen(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWidescreen ? 600 : double.infinity),
        child: CustomScrollView(
          slivers: [
            // Stats header
            SliverToBoxAdapter(
              child: _buildStatsHeader(),
            ),

            // Filter chip if active
            if (_filterConsole != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    children: [
                      Chip(
                        label: Text(_filterConsole!),
                        onDeleted: () => setState(() => _filterConsole = null),
                        deleteIcon: const Icon(Icons.close, size: 16),
                      ),
                    ],
                  ),
                ),
              ),

            // Trophy grid
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 16 + bottomPadding),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isWidescreen ? 4 : 3,
                  childAspectRatio: 0.72,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _TrophyTile(
                    game: games[index],
                    isViewingSelf: isViewingSelf,
                  ),
                  childCount: games.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    // Use filtered games for contextual stats
    final displayGames = _filteredAndSortedGames;
    final hardcoreCount = displayGames.where((g) => g['AwardDataExtra'] == 1).length;
    final softcoreCount = displayGames.length - hardcoreCount;
    final isFiltered = _filterConsole != null;
    final myUsername = ref.read(authProvider).username;
    final isViewingSelf = _viewingUsername == myUsername;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: isViewingSelf ? () => _showShareStatsDialog(displayGames.length, hardcoreCount, softcoreCount) : null,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.workspace_premium, color: Colors.amber, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      '${displayGames.length}',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFiltered ? _filterConsole! : (displayGames.length == 1 ? 'Game' : 'Games'),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.subtitleColor,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          'Mastered',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.subtitleColor,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!isFiltered && _consoleStats.length > 1) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Across ${_consoleStats.length} consoles',
                    style: TextStyle(color: context.subtitleColor, fontSize: 12),
                  ),
                ],
                if (isViewingSelf) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app, size: 14, color: Colors.amber.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to share',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Select icons spread across consoles, then shuffle for randomness
  List<String> _selectMosaicIcons(List<dynamic> games, int count) {
    if (games.isEmpty) return [];

    // Group games by console
    final byConsole = <String, List<String>>{};
    for (final game in games) {
      final console = game['ConsoleName'] as String? ?? 'Unknown';
      final icon = game['ImageIcon'] as String? ?? '';
      if (icon.isNotEmpty) {
        byConsole.putIfAbsent(console, () => []).add(icon);
      }
    }

    if (byConsole.isEmpty) return [];

    // Shuffle games within each console
    for (final icons in byConsole.values) {
      icons.shuffle();
    }

    // Round-robin pick from each console to spread selection
    final selected = <String>[];
    final consoles = byConsole.keys.toList()..shuffle();
    final indices = <String, int>{for (final c in consoles) c: 0};

    while (selected.length < count) {
      var addedAny = false;
      for (final console in consoles) {
        if (selected.length >= count) break;
        final icons = byConsole[console]!;
        final idx = indices[console]!;
        if (idx < icons.length) {
          selected.add(icons[idx]);
          indices[console] = idx + 1;
          addedAny = true;
        }
      }
      // If we've exhausted all consoles, stop (no repeats)
      if (!addedAny) break;
    }

    // Final shuffle so it's not console-grouped in the grid
    selected.shuffle();
    return selected;
  }

  void _showShareStatsDialog(int total, int hardcore, int softcore) {
    final isFiltered = _filterConsole != null;
    final displayGames = _filteredAndSortedGames;

    // Get game icons for mosaic - spread across consoles, then randomize
    final gameIcons = _selectMosaicIcons(displayGames, 25);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareCardScreen(
          type: ShareCardType.trophyCase,
          data: {
            'total': total,
            'hardcore': hardcore,
            'softcore': softcore,
            'consoleName': _filterConsole,
            'isFiltered': isFiltered,
            'totalConsoles': _consoleStats.length,
            'username': _viewingUsername,
            'gameIcons': gameIcons,
          },
        ),
      ),
    );
  }
}

class _TrophyTile extends StatelessWidget {
  final dynamic game;
  final bool isViewingSelf;

  const _TrophyTile({required this.game, required this.isViewingSelf});

  @override
  Widget build(BuildContext context) {
    final title = game['Title'] ?? 'Unknown';
    final consoleName = game['ConsoleName'] ?? '';
    final imageIcon = game['ImageIcon'] ?? '';
    final isHardcore = game['AwardDataExtra'] == 1;
    final awardedAt = game['AwardedAt'] ?? '';

    return GestureDetector(
      onTap: () => _showOptions(context, isViewingSelf),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Game icon with mastery badge overlay
                  Expanded(
                    flex: 3,
                    child: Stack(
                fit: StackFit.expand,
                children: [
                  // Game icon
                  CachedNetworkImage(
                    imageUrl: 'https://retroachievements.org$imageIcon',
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.games, size: 32),
                    ),
                  ),
                  // Gradient overlay at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Mastery badge overlay - gold ring effect
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isHardcore ? Colors.amber : Colors.amber.withValues(alpha: 0.6),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withValues(alpha: isHardcore ? 0.4 : 0.2),
                            blurRadius: 8,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Trophy icon in corner
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isHardcore ? Colors.amber : Colors.amber.shade300,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.workspace_premium,
                        size: 14,
                        color: isHardcore ? Colors.black : Colors.black54,
                      ),
                    ),
                  ),
                  // Hardcore badge
                  if (isHardcore)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'HC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Game info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      consoleName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      _formatDate(awardedAt),
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey[500],
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

  void _showOptions(BuildContext context, bool isViewingSelf) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with game title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      game['Title'] ?? 'Game',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.videogame_asset),
              title: const Text('View Game'),
              onTap: () {
                Navigator.pop(ctx);
                final gameId = game['AwardData'];
                if (gameId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameDetailScreen(
                        gameId: int.tryParse(gameId.toString()) ?? 0,
                        gameTitle: game['Title'] ?? 'Game',
                      ),
                    ),
                  );
                }
              },
            ),
            if (isViewingSelf)
              ListTile(
                leading: const Icon(Icons.share, color: Colors.amber),
                title: const Text('Share Mastery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    // Fetch actual game data for the share card
                    final gameId = int.tryParse(game['AwardData'].toString()) ?? 0;
                    final api = ProviderScope.containerOf(context).read(apiDataSourceProvider);
                    final gameData = await api.getGameInfoWithProgress(gameId);

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading

                      if (gameData != null) {
                        // Calculate points like game_detail_screen does
                        final achievements = gameData['Achievements'] as Map<String, dynamic>? ?? {};
                        final points = calculatePoints(achievements);

                        final shareData = Map<String, dynamic>.from(gameData);
                        shareData['PossibleScore'] = points.totalPoints;
                        shareData['ScoreAchieved'] = points.earnedPoints;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ShareCardScreen(
                              type: ShareCardType.game,
                              data: shareData,
                            ),
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to load game data')),
                      );
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final dt = DateTime.parse(date);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
