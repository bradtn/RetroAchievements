import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../core/theme_utils.dart';
import '../../core/animations.dart';
import '../../data/cache/game_cache.dart';
import '../providers/auth_provider.dart';
import 'share_card/share_card_screen.dart';
import 'game_detail/achievement_tile.dart';
import 'game_detail/leaderboard_widgets.dart';
import 'game_detail/game_detail_widgets.dart';

class GameDetailScreen extends ConsumerStatefulWidget {
  final int gameId;
  final String? gameTitle;
  final String? heroTag;

  const GameDetailScreen({
    super.key,
    required this.gameId,
    this.gameTitle,
    this.heroTag,
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

  // Leaderboards
  List<Map<String, dynamic>> _leaderboards = [];
  bool _isLoadingLeaderboards = false;

  // User's game rank
  Map<String, dynamic>? _userGameRank;

  // Filter state
  AchievementFilter _filter = AchievementFilter.all;
  AchievementSort _sort = AchievementSort.normal;
  bool _showMissable = false;

  // Scroll controller for scroll-to-top button
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  // Track if page transition is complete to avoid shimmer jank
  bool _transitionComplete = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Defer loading until after the page transition completes (250ms)
    // This prevents API calls and setState during the slide animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) {
          setState(() => _transitionComplete = true);
          _loadGame();
        }
      });
    });
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

    // Cache game data for future use
    if (data != null) {
      GameCache.instance.init().then((_) {
        GameCache.instance.put(widget.gameId, data);
      });
      _loadLeaderboards();
      _loadUserGameRank();
    }
  }

  Future<void> _loadLeaderboards() async {
    setState(() => _isLoadingLeaderboards = true);
    final api = ref.read(apiDataSourceProvider);
    final result = await api.getGameLeaderboards(widget.gameId);
    if (mounted) {
      setState(() {
        _leaderboards = result != null
            ? List<Map<String, dynamic>>.from(result)
            : [];
        _isLoadingLeaderboards = false;
      });
    }
  }

  Future<void> _loadUserGameRank() async {
    final api = ref.read(apiDataSourceProvider);
    final username = ref.read(authProvider).username;
    if (username == null) return;
    final result = await api.getUserGameRankAndScore(username, widget.gameId);
    if (mounted && result != null) {
      setState(() => _userGameRank = result);
    }
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
      return _buildLoadingShimmer();
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

    // Calculate total and earned points from achievements
    int totalPoints = 0;
    int earnedPoints = 0;
    for (final entry in achievements.entries) {
      final ach = entry.value as Map<String, dynamic>;
      final pts = ach['Points'] ?? 0;
      final pointValue = (pts is int) ? pts : int.tryParse(pts.toString()) ?? 0;
      totalPoints += pointValue;
      final dateEarned = ach['DateEarned'] ?? ach['DateEarnedHardcore'];
      if (dateEarned != null && dateEarned.toString().isNotEmpty) {
        earnedPoints += pointValue;
      }
    }

    final progress = numAchievements > 0 ? numAwarded / numAchievements : 0.0;

    final isLightMode = Theme.of(context).brightness == Brightness.light;

    return RefreshIndicator(
      onRefresh: _loadGame,
      child: CustomScrollView(
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

              return FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 56, right: 16, bottom: 10),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Game icon that fades in when collapsed
                    Opacity(
                      opacity: collapseRatio,
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: collapseRatio > 0.5 ? null : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: 'https://retroachievements.org$imageIcon',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.deepPurple,
                              child: const Icon(Icons.games, size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: collapseRatio > 0.5 ? 0 : 12,
                          vertical: collapseRatio > 0.5 ? 0 : 8,
                        ),
                        decoration: collapseRatio > 0.5
                            ? null
                            : BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF6366F1).withOpacity(0.85),
                                    const Color(0xFF8B5CF6).withOpacity(0.85),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6366F1).withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                        child: AutoSizeText(
                          title,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            height: 1.2,
                            shadows: collapseRatio > 0.5
                                ? null
                                : [
                                    Shadow(
                                      blurRadius: 2,
                                      color: Colors.black.withOpacity(0.5),
                                    ),
                                  ],
                          ),
                          maxLines: 1,
                          minFontSize: 10,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageTitle.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: 'https://retroachievements.org$imageTitle',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
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
                    // Hero game icon
                    if (widget.heroTag != null)
                      Positioned(
                        left: 16,
                        bottom: 60,
                        child: Hero(
                          tag: widget.heroTag!,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: 'https://retroachievements.org$imageIcon',
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.games, size: 32),
                                ),
                              ),
                            ),
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
                      // Add calculated points to the data
                      final shareData = Map<String, dynamic>.from(_gameData!);
                      shareData['PossibleScore'] = totalPoints;
                      shareData['ScoreAchieved'] = earnedPoints;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShareCardScreen(
                            type: ShareCardType.game,
                            data: shareData,
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
                  child: FavoriteButtonLarge(
                    gameId: widget.gameId,
                    title: title,
                    imageIcon: imageIcon,
                    consoleName: console,
                    numAchievements: numAchievements,
                    earnedAchievements: numAwarded,
                    totalPoints: totalPoints,
                    earnedPoints: earnedPoints,
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
                              // Console chip
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  console,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (numAchievements > 0) ...[
                                // Achievement chip
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.emoji_events, size: 14, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$numAwarded/$numAchievements',
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Points chip
                                    if (totalPoints > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.stars, size: 14, color: Colors.amber[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$earnedPoints/$totalPoints pts',
                                              style: TextStyle(
                                                color: Colors.amber[600],
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Theme.of(context).brightness == Brightness.light
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  completion,
                                  style: TextStyle(color: context.subtitleColor, fontSize: 12),
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

                    // User's rank on this game
                    if (_userGameRank != null) ...[
                      const SizedBox(height: 12),
                      _buildUserGameRank(),
                    ],

                    const Divider(height: 24),

                    // Details
                    if (developer != null && developer.toString().isNotEmpty)
                      DetailRow(Icons.code, 'Developer', developer.toString()),
                    if (publisher != null && publisher.toString().isNotEmpty)
                      DetailRow(Icons.business, 'Publisher', publisher.toString()),
                    if (genre != null && genre.toString().isNotEmpty)
                      DetailRow(Icons.category, 'Genre', genre.toString()),
                    if (released != null && released.toString().isNotEmpty)
                      DetailRow(Icons.calendar_today, 'Released', released.toString()),
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
                  // Title row with sort dropdown
                  Row(
                    children: [
                      Text('Achievements', style: Theme.of(context).textTheme.titleLarge),
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
                      GameFilterChip(
                        label: 'All',
                        selected: _filter == AchievementFilter.all && !_showMissable,
                        onTap: () => setState(() {
                          _filter = AchievementFilter.all;
                          _showMissable = false;
                        }),
                      ),
                      GameFilterChip(
                        label: 'Earned',
                        selected: _filter == AchievementFilter.earned,
                        onTap: () => setState(() {
                          _filter = AchievementFilter.earned;
                          _showMissable = false;
                        }),
                        color: Colors.green,
                      ),
                      GameFilterChip(
                        label: 'Unearned',
                        selected: _filter == AchievementFilter.unearned,
                        onTap: () => setState(() {
                          _filter = AchievementFilter.unearned;
                          _showMissable = false;
                        }),
                        color: Colors.orange,
                      ),
                      GameFilterChip(
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
                  const SizedBox(height: 8),
                  // Show stats row with badges
                  Builder(
                    builder: (context) {
                      final filtered = _getFilteredAchievements(achievements);
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$numAwarded/${achievements.length}',
                              style: const TextStyle(color: Colors.green, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 12, color: Colors.amber[700]),
                                const SizedBox(width: 3),
                                Text(
                                  '$earnedPoints/$totalPoints pts',
                                  style: TextStyle(color: Colors.amber[700], fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Showing ${filtered.length}',
                            style: TextStyle(color: context.subtitleColor, fontSize: 11),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // Rarity distribution chart and legend
                  _buildRarityDistributionCard(achievements, numDistinctPlayers),
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

              // Get user info for achievement details
              final username = ref.watch(authProvider).username;
              final userPic = _gameData?['UserPic'] ?? '';

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= filtered.length) return null;
                    return ScrollAnimatedItem(
                      index: index,
                      delay: const Duration(milliseconds: 10),
                      duration: const Duration(milliseconds: 150),
                      beginOffset: const Offset(0.08, 0.0),
                      initialOpacity: 0.6,
                      child: AchievementTile(
                        achievement: filtered[index],
                        numDistinctPlayers: numDistinctPlayers is int ? numDistinctPlayers : int.tryParse(numDistinctPlayers.toString()) ?? 0,
                        gameTitle: title,
                        gameIcon: imageIcon,
                        consoleName: console,
                        username: username,
                        userPic: userPic is String ? userPic : '',
                      ),
                    );
                  },
                  childCount: filtered.length,
                ),
              );
            },
          ),

        // Leaderboards section
        if (_leaderboards.isNotEmpty || _isLoadingLeaderboards)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.leaderboard, size: 22, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text('Leaderboards', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  if (_leaderboards.isNotEmpty)
                    Text(
                      '${_leaderboards.length} ${_leaderboards.length == 1 ? 'leaderboard' : 'leaderboards'}',
                      style: TextStyle(color: context.subtitleColor, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),

        if (_isLoadingLeaderboards)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_leaderboards.isNotEmpty)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= _leaderboards.length) return null;
                return LeaderboardTile(
                  leaderboard: _leaderboards[index],
                  onTap: () => _showLeaderboardDetail(_leaderboards[index]),
                );
              },
              childCount: _leaderboards.length > 5 ? 5 : _leaderboards.length,
            ),
          ),

        // Show more leaderboards button
        if (_leaderboards.length > 5)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton(
                onPressed: () => _showAllLeaderboards(),
                child: Text('View All ${_leaderboards.length} Leaderboards'),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
      ),
    );
  }

  Widget _buildUserGameRank() {
    if (_userGameRank == null) return const SizedBox.shrink();

    // Parse the rank data - API returns a list with user's position
    // The structure varies, try to extract rank info
    final rankData = _userGameRank!;
    final rank = rankData['Rank'] ?? rankData['UserRank'] ?? 0;
    final score = rankData['Score'] ?? rankData['TotalScore'] ?? 0;
    final totalRanked = rankData['TotalRanked'] ?? rankData['NumEntries'] ?? 0;

    if (rank == 0 && score == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.withValues(alpha: 0.15),
            Colors.orange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Rank',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  totalRanked > 0
                      ? 'Rank $rank of $totalRanked players'
                      : 'Rank #$rank',
                  style: TextStyle(color: context.subtitleColor, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '$score',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLeaderboardDetail(Map<String, dynamic> leaderboard) async {
    final id = leaderboard['ID'] ?? leaderboard['LeaderboardId'] ?? 0;
    final title = leaderboard['Title'] ?? 'Leaderboard';
    final description = leaderboard['Description'] ?? '';
    final format = leaderboard['Format'] ?? '';

    // Load entries for this leaderboard
    showDialog(
      context: context,
      builder: (ctx) => LeaderboardDetailDialog(
        leaderboardId: id is int ? id : int.tryParse(id.toString()) ?? 0,
        title: title,
        description: description,
        format: format,
      ),
    );
  }

  void _showAllLeaderboards() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.leaderboard, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'All Leaderboards (${_leaderboards.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _leaderboards.length,
                itemBuilder: (ctx, i) => LeaderboardTile(
                  leaderboard: _leaderboards[i],
                  onTap: () {
                    Navigator.pop(context);
                    _showLeaderboardDetail(_leaderboards[i]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;

    // Use static placeholders during page transition to avoid animation jank,
    // then switch to shimmer after transition completes
    if (!_transitionComplete) {
      return CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: placeholderColor),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: placeholderColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        // Shimmer app bar
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: ShimmerCard(
              height: 200,
              borderRadius: 0,
            ),
          ),
        ),
        // Shimmer game info card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ShimmerCard(height: 180),
          ),
        ),
        // Shimmer achievement header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ShimmerCard(height: 40, width: 150),
          ),
        ),
        // Shimmer achievement tiles
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ShimmerAchievementTile(),
            ),
            childCount: 8,
          ),
        ),
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

  // Calculate rarity tier for an achievement
  Map<String, dynamic> _getRarityTier(int numAwarded, int numDistinct) {
    if (numDistinct > 0) {
      final percent = (numAwarded / numDistinct) * 100;
      if (percent < 5) return {'label': 'Ultra Rare', 'color': Colors.red, 'icon': Icons.diamond, 'tier': 0};
      if (percent < 15) return {'label': 'Rare', 'color': Colors.purple, 'icon': Icons.star, 'tier': 1};
      if (percent < 40) return {'label': 'Uncommon', 'color': Colors.blue, 'icon': Icons.hexagon, 'tier': 2};
      return {'label': 'Common', 'color': Colors.grey, 'icon': Icons.circle, 'tier': 3};
    }
    // Fallback to absolute numbers
    if (numAwarded < 100) return {'label': 'Ultra Rare', 'color': Colors.red, 'icon': Icons.diamond, 'tier': 0};
    if (numAwarded < 500) return {'label': 'Rare', 'color': Colors.purple, 'icon': Icons.star, 'tier': 1};
    if (numAwarded < 2000) return {'label': 'Uncommon', 'color': Colors.blue, 'icon': Icons.hexagon, 'tier': 2};
    return {'label': 'Common', 'color': Colors.grey, 'icon': Icons.circle, 'tier': 3};
  }

  Widget _buildRarityDistributionCard(Map<String, dynamic> achievements, int numDistinctPlayers) {
    // Count achievements per rarity tier
    int ultraRareCount = 0;
    int rareCount = 0;
    int uncommonCount = 0;
    int commonCount = 0;

    for (final entry in achievements.entries) {
      final ach = entry.value as Map<String, dynamic>;
      final numAwarded = ach['NumAwarded'] ?? 0;
      final tier = _getRarityTier(numAwarded, numDistinctPlayers);
      switch (tier['tier'] as int) {
        case 0: ultraRareCount++; break;
        case 1: rareCount++; break;
        case 2: uncommonCount++; break;
        case 3: commonCount++; break;
      }
    }

    final total = achievements.length;
    if (total == 0) return const SizedBox.shrink();

    return AnimatedRarityDistribution(
      ultraRareCount: ultraRareCount,
      rareCount: rareCount,
      uncommonCount: uncommonCount,
      commonCount: commonCount,
      numDistinctPlayers: numDistinctPlayers,
    );
  }
}

