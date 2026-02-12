import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  Map<String, dynamic>? _gameData;
  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _leaderboards = [];
  bool _isLoadingLeaderboards = false;
  Map<String, dynamic>? _userGameRank;

  AchievementFilter _filter = AchievementFilter.all;
  AchievementSort _sort = AchievementSort.normal;
  bool _showMissable = false;

  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  bool _transitionComplete = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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
      return GameDetailShimmer(transitionComplete: _transitionComplete);
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
    final numDistinctPlayersRaw = _gameData!['NumDistinctPlayers'] ?? _gameData!['NumDistinctPlayersCasual'] ?? 0;
    final numDistinctPlayers = numDistinctPlayersRaw is int ? numDistinctPlayersRaw : int.tryParse(numDistinctPlayersRaw.toString()) ?? 0;

    final points = calculatePoints(achievements);
    final totalPoints = points.totalPoints;
    final earnedPoints = points.earnedPoints;
    final progress = numAchievements > 0 ? numAwarded / numAchievements : 0.0;
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    return RefreshIndicator(
      onRefresh: _loadGame,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildAppBar(title, imageIcon, imageTitle, isLightMode),
          _buildActionButtons(title, console, imageIcon, totalPoints, earnedPoints, numAchievements, numAwarded),
          _buildGameInfoCard(title, console, imageIcon, developer, publisher, genre, released, numAchievements, numAwarded, totalPoints, earnedPoints, progress, completion),
          if (numAchievements > 0)
            _buildRarityDistribution(achievements, numDistinctPlayers),
          if (numAchievements > 0)
            _buildAchievementsHeader(achievements, numAwarded, earnedPoints, totalPoints),
          if (numAchievements > 0)
            _buildAchievementsList(achievements, numDistinctPlayers, title, imageIcon, console),
          _buildLeaderboardsSection(),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildAppBar(String title, String imageIcon, String imageTitle, bool isLightMode) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      foregroundColor: isLightMode ? Colors.grey[900] : Colors.white,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final expandedHeight = 220.0;
          final collapsedHeight = kToolbarHeight + MediaQuery.of(context).padding.top;
          final currentHeight = constraints.maxHeight;
          final collapseRatio = ((expandedHeight - currentHeight) / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);

          final titleColor = isLightMode
              ? Color.lerp(Colors.white, Colors.grey[900], collapseRatio)!
              : Colors.white;

          return FlexibleSpaceBar(
            titlePadding: EdgeInsets.only(
              left: collapseRatio > 0.7 ? 56 : 16,
              right: 16,
              bottom: collapseRatio > 0.7 ? 13 : 16,
            ),
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Game icon - only visible when collapsed
                if (collapseRatio > 0.7)
                  Opacity(
                    opacity: ((collapseRatio - 0.7) / 0.3).clamp(0.0, 1.0),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: 'https://retroachievements.org$imageIcon',
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[700],
                            child: const Icon(Icons.games, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Title text
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: collapseRatio > 0.7 ? 16 : 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      height: 1.2,
                      shadows: collapseRatio > 0.7
                          ? null
                          : [
                              Shadow(
                                blurRadius: 8,
                                color: Colors.black.withValues(alpha: 0.8),
                              ),
                              Shadow(
                                blurRadius: 16,
                                color: Colors.black.withValues(alpha: 0.5),
                              ),
                            ],
                    ),
                    maxLines: collapseRatio > 0.7 ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                if (imageTitle.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: 'https://retroachievements.org$imageTitle',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorWidget: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey[900]!,
                            Colors.grey[800]!,
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey[900]!,
                          Colors.grey[800]!,
                        ],
                      ),
                    ),
                  ),
                // Gradient overlay for text readability
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.5, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
                // Hero game icon (when coming from another screen)
                if (widget.heroTag != null)
                  Positioned(
                    left: 16,
                    bottom: 56,
                    child: Hero(
                      tag: widget.heroTag!,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: 'https://retroachievements.org$imageIcon',
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: Colors.grey[800],
                              child: const Icon(Icons.games, size: 28),
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
    );
  }

  Widget _buildActionButtons(String title, String console, String imageIcon, int totalPoints, int earnedPoints, int numAchievements, int numAwarded) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
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
    );
  }

  Widget _buildGameInfoCard(
    String title, String console, String imageIcon,
    dynamic developer, dynamic publisher, dynamic genre, dynamic released,
    int numAchievements, int numAwarded, int totalPoints, int earnedPoints,
    double progress, String completion,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (_userGameRank != null) ...[
                  const SizedBox(height: 12),
                  UserGameRankCard(rankData: _userGameRank!),
                ],
                const Divider(height: 24),
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
    );
  }

  Widget _buildRarityDistribution(Map<String, dynamic> achievements, int numDistinctPlayers) {
    final rarityCounts = calculateRarityDistribution(achievements, numDistinctPlayers);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.diamond_outlined, size: 20, color: Colors.purple[300]),
                    const SizedBox(width: 8),
                    Text(
                      'Rarity Distribution',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AnimatedRarityDistribution(
                  ultraRareCount: rarityCounts.ultraRare,
                  rareCount: rarityCounts.rare,
                  uncommonCount: rarityCounts.uncommon,
                  commonCount: rarityCounts.common,
                  numDistinctPlayers: numDistinctPlayers,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementsHeader(
    Map<String, dynamic> achievements,
    int numAwarded,
    int earnedPoints,
    int totalPoints,
  ) {
    final filtered = getFilteredAchievements(achievements, _filter, _sort, _showMissable);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Achievements', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                SortMenuButton(
                  currentSort: _sort,
                  onSortChanged: (v) => setState(() => _sort = v),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
            AchievementStatsRow(
              numAwarded: numAwarded,
              totalAchievements: achievements.length,
              earnedPoints: earnedPoints,
              totalPoints: totalPoints,
              filteredCount: filtered.length,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsList(
    Map<String, dynamic> achievements,
    int numDistinctPlayers,
    String title,
    String imageIcon,
    String console,
  ) {
    final filtered = getFilteredAchievements(achievements, _filter, _sort, _showMissable);

    if (filtered.isEmpty && _showMissable) {
      return const SliverToBoxAdapter(child: NoMissableMessage());
    }

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
              numDistinctPlayers: numDistinctPlayers,
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
  }

  Widget _buildLeaderboardsSection() {
    if (_leaderboards.isEmpty && !_isLoadingLeaderboards) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.leaderboard, size: 22, color: Colors.amber),
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
        else
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
        if (_leaderboards.length > 5)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton(
                onPressed: _showAllLeaderboards,
                child: Text('View All ${_leaderboards.length} Leaderboards'),
              ),
            ),
          ),
      ],
    );
  }

  void _showLeaderboardDetail(Map<String, dynamic> leaderboard) {
    final id = leaderboard['ID'] ?? leaderboard['LeaderboardId'] ?? 0;
    final title = leaderboard['Title'] ?? 'Leaderboard';
    final description = leaderboard['Description'] ?? '';
    final format = leaderboard['Format'] ?? '';

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
}
