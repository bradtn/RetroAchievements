import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../../core/animations.dart';
import '../../data/cache/game_cache.dart';
import '../providers/auth_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/premium_provider.dart';
import 'share_card_screen.dart';

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
                titlePadding: const EdgeInsets.only(left: 56, right: 16, bottom: 16),
                title: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black.withOpacity(shadowOpacity),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

                    // User's rank on this game
                    if (_userGameRank != null) ...[
                      const SizedBox(height: 12),
                      _buildUserGameRank(),
                    ],

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
                      child: _AchievementTile(
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
                return _LeaderboardTile(
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
      builder: (ctx) => _LeaderboardDetailDialog(
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
                itemBuilder: (ctx, i) => _LeaderboardTile(
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

    return _AnimatedRarityDistribution(
      ultraRareCount: ultraRareCount,
      rareCount: rareCount,
      uncommonCount: uncommonCount,
      commonCount: commonCount,
      numDistinctPlayers: numDistinctPlayers,
    );
  }

  Widget _buildRarityLegendItem(IconData icon, Color color, String name, String percent, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          '$name ($count)',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
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
      onTap: () {
        Haptics.selection();
        onTap();
      },
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
  final String? gameTitle;
  final String? gameIcon;
  final String? consoleName;
  final String? username;
  final String? userPic;

  const _AchievementTile({
    required this.achievement,
    this.numDistinctPlayers = 0,
    this.gameTitle,
    this.gameIcon,
    this.consoleName,
    this.username,
    this.userPic,
  });

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

    final dateEarned = achievement['DateEarned'] ?? achievement['DateEarnedHardcore'];
    final isEarned = dateEarned != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          Haptics.light();
          _showAchievementDetail(context, ref);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Achievement badge with earned indicator
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ColorFiltered(
                      colorFilter: isEarned
                          ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                          : const ColorFilter.matrix(<double>[
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0.2126, 0.7152, 0.0722, 0, 0,
                              0, 0, 0, 0.6, 0,
                            ]),
                      child: CachedNetworkImage(
                        imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 52, height: 52,
                          color: Colors.grey[800],
                          child: const Icon(Icons.emoji_events),
                        ),
                      ),
                    ),
                  ),
                  if (isEarned)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row with points badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isEarned ? null : context.subtitleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 10, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                '$points',
                                style: TextStyle(color: Colors.amber[400], fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Description
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Rarity progress bar (always visible)
                    _buildRarityBar(context, unlockPercent, rarityInfo, isPremium),
                    const SizedBox(height: 6),
                    // Badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Rarity label badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (rarityInfo['color'] as Color).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (rarityInfo['color'] as Color).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(rarityInfo['icon'] as IconData, size: 10, color: rarityInfo['color'] as Color),
                              const SizedBox(width: 3),
                              Text(
                                rarityInfo['label'] as String,
                                style: TextStyle(color: rarityInfo['color'] as Color, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        // Unlock count badge
                        if (numAwarded > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people, size: 10, color: context.subtitleColor),
                                const SizedBox(width: 3),
                                Text(
                                  _formatUnlockCount(numAwarded),
                                  style: TextStyle(color: context.subtitleColor, fontSize: 9),
                                ),
                              ],
                            ),
                          ),
                        // Missable badge
                        if (isMissable)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 10, color: Colors.red),
                                SizedBox(width: 3),
                                Text(
                                  'Missable',
                                  style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRarityBar(BuildContext context, double unlockPercent, Map<String, dynamic> rarityInfo, bool isPremium) {
    final color = rarityInfo['color'] as Color;
    // Clamp percentage for bar display (0-100)
    final barPercent = unlockPercent.clamp(0.0, 100.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        Stack(
          children: [
            // Background
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Filled portion
            FractionallySizedBox(
              widthFactor: barPercent / 100,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        // Percentage label
        Row(
          children: [
            Text(
              numDistinctPlayers > 0
                  ? '${unlockPercent.toStringAsFixed(1)}% of players'
                  : 'Unlock rate unavailable',
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatUnlockCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M unlocks';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K unlocks';
    }
    return '$count unlocks';
  }

  void _showAchievementDetail(BuildContext context, WidgetRef ref) async {
    final title = achievement['Title'] ?? 'Achievement';
    final description = achievement['Description'] ?? '';
    final points = achievement['Points'] ?? 0;
    final trueRatio = achievement['TrueRatio'] ?? 0;
    final badgeName = achievement['BadgeName'] ?? '';
    final numAwarded = achievement['NumAwarded'] ?? 0;
    final dateEarned = achievement['DateEarned'] ?? achievement['DateEarnedHardcore'];
    final isEarned = dateEarned != null;
    final isPremium = ref.read(isPremiumProvider);
    final rarityInfo = _getRarityInfo(numAwarded, numDistinctPlayers);
    final unlockPercent = numDistinctPlayers > 0
        ? (numAwarded / numDistinctPlayers * 100)
        : 0.0;
    final isMissable = _isMissable(achievement);

    // Fetch user profile to get avatar
    String? fetchedUserPic = userPic;
    if (fetchedUserPic == null || fetchedUserPic.isEmpty) {
      final api = ref.read(apiDataSourceProvider);
      final profile = await api.getUserProfile(username ?? '');
      fetchedUserPic = profile?['UserPic'] ?? '';
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Achievement badge with earned/locked state
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            if (isEarned)
                              BoxShadow(
                                color: Colors.amber.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ColorFiltered(
                            colorFilter: isEarned
                                ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                                : const ColorFilter.matrix(<double>[
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0.2126, 0.7152, 0.0722, 0, 0,
                                    0, 0, 0, 0.5, 0,
                                  ]),
                            child: CachedNetworkImage(
                              imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 96,
                                height: 96,
                                color: Colors.grey[800],
                                child: const Icon(Icons.emoji_events, size: 48),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!isEarned)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock, color: Colors.white, size: 24),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Earned status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isEarned
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isEarned ? Icons.check_circle : Icons.lock_outline,
                          color: isEarned ? Colors.green : Colors.orange,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isEarned ? 'UNLOCKED' : 'LOCKED',
                          style: TextStyle(
                            color: isEarned ? Colors.green : Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    description,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[300]
                          : Colors.grey[700],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Points and rarity badges row
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '$points pts',
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (rarityInfo['color'] as Color).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (rarityInfo['color'] as Color).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(rarityInfo['icon'] as IconData, size: 14, color: rarityInfo['color'] as Color),
                            const SizedBox(width: 4),
                            Text(
                              rarityInfo['label'] as String,
                              style: TextStyle(color: rarityInfo['color'] as Color, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (isMissable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber, size: 14, color: Colors.red),
                              SizedBox(width: 4),
                              Text('Missable', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Enhanced rarity visualization
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (rarityInfo['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (rarityInfo['color'] as Color).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Rarity bar
                        Row(
                          children: [
                            Text(
                              'Rarity',
                              style: TextStyle(
                                color: rarityInfo['color'] as Color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              numDistinctPlayers > 0
                                  ? '${unlockPercent.toStringAsFixed(2)}%'
                                  : 'N/A',
                              style: TextStyle(
                                color: rarityInfo['color'] as Color,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        Stack(
                          children: [
                            Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: (rarityInfo['color'] as Color).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (unlockPercent / 100).clamp(0.0, 1.0),
                              child: Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      rarityInfo['color'] as Color,
                                      (rarityInfo['color'] as Color).withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (rarityInfo['color'] as Color).withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Stats row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people, size: 12, color: Theme.of(ctx).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '$numAwarded unlocks',
                                  style: TextStyle(
                                    color: Theme.of(ctx).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            if (numDistinctPlayers > 0)
                              Text(
                                'of $numDistinctPlayers players',
                                style: TextStyle(
                                  color: Theme.of(ctx).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User info
                  if (username != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: fetchedUserPic != null && fetchedUserPic.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: 'https://retroachievements.org$fetchedUserPic',
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 40,
                                      height: 40,
                                      color: Colors.grey[700],
                                      child: Center(
                                        child: Text(
                                          username![0].toUpperCase(),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.grey[700],
                                    child: Center(
                                      child: Text(
                                        username![0].toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(username!, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  isEarned ? 'Unlocked ${_formatDate(dateEarned)}' : 'Not yet unlocked',
                                  style: TextStyle(
                                    color: isEarned ? Colors.green : Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShareCardScreen(
                                  type: ShareCardType.achievement,
                                  data: {
                                    'Title': title,
                                    'Description': description,
                                    'Points': points,
                                    'BadgeName': badgeName,
                                    'GameTitle': gameTitle ?? '',
                                    'GameIcon': gameIcon ?? '',
                                    'ConsoleName': consoleName ?? '',
                                    'Username': username ?? '',
                                    'UserPic': fetchedUserPic ?? '',
                                    'IsEarned': isEarned,
                                    'DateEarned': dateEarned,
                                    'UnlockPercent': unlockPercent,
                                    'RarityLabel': rarityInfo['label'],
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) return 'today';
      if (diff.inDays == 1) return 'yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
      return '${(diff.inDays / 365).floor()} years ago';
    } catch (e) {
      return dateStr;
    }
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
    Haptics.medium();
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

class _LeaderboardTile extends StatelessWidget {
  final Map<String, dynamic> leaderboard;
  final VoidCallback onTap;

  const _LeaderboardTile({
    required this.leaderboard,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = leaderboard['Title'] ?? 'Leaderboard';
    final description = leaderboard['Description'] ?? '';
    final numEntries = leaderboard['NumEntries'] ?? leaderboard['NumResults'] ?? 0;
    final format = leaderboard['Format'] ?? '';

    // Determine icon based on format/type
    IconData icon = Icons.leaderboard;
    Color iconColor = Colors.amber;
    if (format.toLowerCase().contains('time') || format.toLowerCase().contains('speed')) {
      icon = Icons.timer;
      iconColor = Colors.blue;
    } else if (format.toLowerCase().contains('score') || format.toLowerCase().contains('point')) {
      icon = Icons.stars;
      iconColor = Colors.amber;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () {
          Haptics.light();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.people, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '$numEntries',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardDetailDialog extends ConsumerStatefulWidget {
  final int leaderboardId;
  final String title;
  final String description;
  final String format;

  const _LeaderboardDetailDialog({
    required this.leaderboardId,
    required this.title,
    required this.description,
    required this.format,
  });

  @override
  ConsumerState<_LeaderboardDetailDialog> createState() => _LeaderboardDetailDialogState();
}

class _LeaderboardDetailDialogState extends ConsumerState<_LeaderboardDetailDialog> {
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final api = ref.read(apiDataSourceProvider);
    final result = await api.getLeaderboardEntries(widget.leaderboardId, count: 100);

    if (mounted) {
      if (result != null) {
        // The API returns entries in a 'Results' or 'Entries' key typically
        final entries = result['Results'] ?? result['Entries'] ?? result['entries'] ?? [];
        setState(() {
          _entries = List<Map<String, dynamic>>.from(entries);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load leaderboard entries';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).username;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.leaderboard, color: Colors.amber),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.description.isNotEmpty)
                              Text(
                                widget.description,
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Entries list
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text(_error!),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _loadEntries,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _entries.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.hourglass_empty, color: Colors.grey, size: 48),
                                  SizedBox(height: 16),
                                  Text('No entries yet'),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _entries.length,
                              itemBuilder: (ctx, i) {
                                final entry = _entries[i];
                                final rank = entry['Rank'] ?? entry['rank'] ?? i + 1;
                                final user = entry['User'] ?? entry['user'] ?? 'Unknown';
                                final score = entry['Score'] ?? entry['score'] ?? 0;
                                final formattedScore = entry['FormattedScore'] ?? entry['ScoreFormatted'] ?? '$score';
                                final userPic = entry['UserPic'] ?? '';
                                final isCurrentUser = user.toString().toLowerCase() == currentUser?.toLowerCase();

                                // Rank medal colors
                                Color? medalColor;
                                IconData? medalIcon;
                                if (rank == 1) {
                                  medalColor = Colors.amber;
                                  medalIcon = Icons.emoji_events;
                                } else if (rank == 2) {
                                  medalColor = Colors.grey[400];
                                  medalIcon = Icons.emoji_events;
                                } else if (rank == 3) {
                                  medalColor = Colors.orange[700];
                                  medalIcon = Icons.emoji_events;
                                }

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isCurrentUser
                                        ? Colors.amber.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isCurrentUser
                                        ? Border.all(color: Colors.amber.withValues(alpha: 0.3))
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Rank
                                      SizedBox(
                                        width: 36,
                                        child: medalIcon != null
                                            ? Icon(medalIcon, color: medalColor, size: 22)
                                            : Text(
                                                '#$rank',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isCurrentUser ? Colors.amber : Colors.grey,
                                                ),
                                              ),
                                      ),
                                      // Avatar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: userPic.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: 'https://retroachievements.org$userPic',
                                                width: 32,
                                                height: 32,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) => _buildDefaultAvatar(user),
                                              )
                                            : _buildDefaultAvatar(user),
                                      ),
                                      const SizedBox(width: 10),
                                      // Username
                                      Expanded(
                                        child: Text(
                                          user,
                                          style: TextStyle(
                                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                                            color: isCurrentUser ? Colors.amber : null,
                                          ),
                                        ),
                                      ),
                                      // Score
                                      Text(
                                        formattedScore,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: medalColor ?? (isCurrentUser ? Colors.amber : null),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String username) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}

/// Animated rarity distribution chart
class _AnimatedRarityDistribution extends StatefulWidget {
  final int ultraRareCount;
  final int rareCount;
  final int uncommonCount;
  final int commonCount;
  final int numDistinctPlayers;

  const _AnimatedRarityDistribution({
    required this.ultraRareCount,
    required this.rareCount,
    required this.uncommonCount,
    required this.commonCount,
    required this.numDistinctPlayers,
  });

  @override
  State<_AnimatedRarityDistribution> createState() => _AnimatedRarityDistributionState();
}

class _AnimatedRarityDistributionState extends State<_AnimatedRarityDistribution>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    // Start animation after a small delay for smoother page load
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.ultraRareCount + widget.rareCount + widget.uncommonCount + widget.commonCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.grey.shade100
            : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 16, color: Colors.purple),
              const SizedBox(width: 6),
              Text(
                'Rarity Distribution',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: context.subtitleColor,
                ),
              ),
              const Spacer(),
              Text(
                '${widget.numDistinctPlayers} players',
                style: TextStyle(fontSize: 10, color: context.subtitleColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Animated stacked bar chart
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 24,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final maxWidth = constraints.maxWidth;
                      final animValue = _animation.value;

                      return Stack(
                        children: [
                          // Background
                          Container(
                            width: maxWidth,
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                          // Animated bars
                          Row(
                            children: [
                              if (widget.ultraRareCount > 0)
                                _buildAnimatedBar(
                                  width: (widget.ultraRareCount / total) * maxWidth * animValue,
                                  color: Colors.red,
                                  count: widget.ultraRareCount,
                                  animValue: animValue,
                                ),
                              if (widget.rareCount > 0)
                                _buildAnimatedBar(
                                  width: (widget.rareCount / total) * maxWidth * animValue,
                                  color: Colors.purple,
                                  count: widget.rareCount,
                                  animValue: animValue,
                                ),
                              if (widget.uncommonCount > 0)
                                _buildAnimatedBar(
                                  width: (widget.uncommonCount / total) * maxWidth * animValue,
                                  color: Colors.blue,
                                  count: widget.uncommonCount,
                                  animValue: animValue,
                                ),
                              if (widget.commonCount > 0)
                                _buildAnimatedBar(
                                  width: (widget.commonCount / total) * maxWidth * animValue,
                                  color: Colors.grey,
                                  count: widget.commonCount,
                                  animValue: animValue,
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          // Legend with counts
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildLegendItem(Icons.diamond, Colors.red, 'Ultra Rare', '<5%', widget.ultraRareCount),
              _buildLegendItem(Icons.star, Colors.purple, 'Rare', '<15%', widget.rareCount),
              _buildLegendItem(Icons.hexagon, Colors.blue, 'Uncommon', '<40%', widget.uncommonCount),
              _buildLegendItem(Icons.circle, Colors.grey, 'Common', '40%+', widget.commonCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBar({
    required double width,
    required Color color,
    required int count,
    required double animValue,
  }) {
    return Container(
      width: width,
      height: 24,
      color: color,
      child: Center(
        child: animValue > 0.7 && count >= 3
            ? Opacity(
                opacity: ((animValue - 0.7) / 0.3).clamp(0.0, 1.0),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, Color color, String name, String percent, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          '$name ($count)',
          style: TextStyle(fontSize: 10, color: context.subtitleColor),
        ),
      ],
    );
  }
}
