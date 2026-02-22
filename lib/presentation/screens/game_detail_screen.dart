import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../../core/theme_utils.dart';
import '../../core/animations.dart';
import '../../core/services/dual_screen_service.dart';
import '../../core/responsive_layout.dart';
import '../../data/cache/game_cache.dart';
import '../../data/cache/leaderboard_cache.dart';
import '../providers/auth_provider.dart';
import '../providers/ra_status_provider.dart';
import '../providers/premium_provider.dart';
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

  // User's personal leaderboard entries for this game
  List<Map<String, dynamic>> _userGameLeaderboards = [];
  bool _isLoadingUserLeaderboards = false;

  AchievementFilter _filter = AchievementFilter.all;
  AchievementSort _sort = AchievementSort.normal;
  bool _showMissable = false;

  // Toggle between achievements and leaderboards view
  bool _showLeaderboards = false;

  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  bool _transitionComplete = false;

  // Dual screen support
  final DualScreenService _dualScreen = DualScreenService();
  bool _isShowingSecondaryDialog = false; // Prevent stacking dialogs from secondary taps

  // Title typewriter animation
  bool _titleAnimationComplete = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _dualScreen.addSecondaryEventListener(_handleSecondaryEvent);
    debugPrint('GameDetailScreen: Registered secondary event listener');
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
    _dualScreen.removeSecondaryEventListener(_handleSecondaryEvent);
    super.dispose();
  }

  /// Handle events from secondary display
  void _handleSecondaryEvent(String event, Map<String, dynamic> data) {
    debugPrint('GameDetailScreen: _handleSecondaryEvent called - event=$event, mounted=$mounted');
    if (!mounted) return;

    switch (event) {
      case 'filterChanged':
        // Sync filter from secondary
        setState(() {
          _filter = AchievementFilter.values[data['filter'] as int? ?? 0];
          _showMissable = data['showMissable'] as bool? ?? false;
        });
        break;
      case 'sortChanged':
        // Sync sort from secondary
        setState(() {
          _sort = AchievementSort.values[data['sort'] as int? ?? 0];
        });
        break;
      case 'achievementTapped':
        // Show achievement detail dialog on main screen
        // Convert nested map properly (Kotlin returns Map<Object?, Object?>)
        Map<String, dynamic>? achievement;
        final rawAchievement = data['achievement'];
        if (rawAchievement is Map) {
          achievement = Map<String, dynamic>.from(rawAchievement);
        }

        if (achievement != null) {
          _showAchievementFromSecondary(achievement);
        } else {
          // Fallback: try to find by achievementId
          final achievementId = data['achievementId'];
          if (achievementId != null && _gameData != null) {
            final achievements = _gameData!['Achievements'] as Map<String, dynamic>? ?? {};
            for (final entry in achievements.entries) {
              if (entry.value is Map && entry.value['ID'] == achievementId) {
                _showAchievementFromSecondary(Map<String, dynamic>.from(entry.value));
                break;
              }
            }
          }
        }
        break;
    }
  }

  /// Show achievement detail triggered from secondary display
  void _showAchievementFromSecondary(Map<String, dynamic> achievement) async {
    // Prevent stacking multiple dialogs
    if (_isShowingSecondaryDialog) {
      return;
    }
    _isShowingSecondaryDialog = true;

    // Find the full achievement data from our game data
    final achievements = _gameData?['Achievements'] as Map<String, dynamic>? ?? {};
    final numDistinctPlayersRaw = _gameData?['NumDistinctPlayers'] ?? _gameData?['NumDistinctPlayersCasual'] ?? 0;
    final numDistinctPlayers = numDistinctPlayersRaw is int ? numDistinctPlayersRaw : int.tryParse(numDistinctPlayersRaw.toString()) ?? 0;

    // Try to find full achievement data by ID
    Map<String, dynamic>? fullAchievement;
    final targetId = achievement['ID']?.toString();
    for (final entry in achievements.entries) {
      if (entry.value is Map) {
        final entryId = entry.value['ID']?.toString();
        if (entryId == targetId) {
          fullAchievement = Map<String, dynamic>.from(entry.value);
          break;
        }
      }
    }

    // Use the full data or fall back to what we received
    final achData = fullAchievement ?? achievement;

    // Get user info for the dialog
    final username = ref.read(authProvider).username;
    final gameTitle = _gameData?['Title'] ?? widget.gameTitle ?? 'Game';
    final gameIcon = _gameData?['ImageIcon'] ?? '';
    final consoleName = _gameData?['ConsoleName'] ?? '';

    // Fetch user profile to get avatar (like AchievementTile does)
    String userPic = _gameData?['UserPic'] ?? '';
    if (userPic.isEmpty && username != null) {
      final api = ref.read(apiDataSourceProvider);
      final profile = await api.getUserProfile(username);
      userPic = profile?['UserPic'] ?? '';
    }

    if (!mounted) {
      _isShowingSecondaryDialog = false;
      return;
    }

    // Show the full dialog (same as AchievementTile)
    await showDialog(
      context: context,
      builder: (ctx) => _buildFullAchievementDialog(
        ctx,
        achData,
        numDistinctPlayers,
        username: username,
        userPic: userPic,
        gameTitle: gameTitle,
        gameIcon: gameIcon,
        consoleName: consoleName,
      ),
    );

    _isShowingSecondaryDialog = false;
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

    // Report API status
    if (data != null) {
      ref.read(raStatusProvider.notifier).reportSuccess();
    } else {
      ref.read(raStatusProvider.notifier).reportFailure('Game data load failed');
    }

    setState(() {
      _gameData = data;
      _isLoading = false;
      if (data == null) {
        _error = ref.read(raStatusProvider.notifier).getErrorMessage(
          'Unable to load game data. Pull down to retry.',
        );
      }
    });

    if (data != null) {
      GameCache.instance.init().then((_) {
        GameCache.instance.put(widget.gameId, data);
      });
      _loadLeaderboards();
      _loadUserGameRank();
      _loadUserGameLeaderboards();
      _updateSecondaryDisplay(data);
    }
  }

  /// Send game data to secondary display (for dual-screen devices)
  void _updateSecondaryDisplay(Map<String, dynamic> data) {
    final authState = ref.read(authProvider);

    final achievements = data['Achievements'];
    int totalAchievements = 0;
    int earnedAchievements = 0;
    int totalPoints = 0;
    List<Map<String, dynamic>> achievementsList = [];

    // Get numDistinctPlayers for rarity calculation
    final numDistinctPlayersRaw = data['NumDistinctPlayers'] ?? data['NumDistinctPlayersCasual'] ?? 0;
    final numDistinctPlayers = numDistinctPlayersRaw is int ? numDistinctPlayersRaw : int.tryParse(numDistinctPlayersRaw.toString()) ?? 0;

    if (achievements is Map) {
      totalAchievements = achievements.length;
      for (final entry in achievements.entries) {
        final ach = entry.value;
        if (ach is Map) {
          final dateEarned = ach['DateEarned'] ?? ach['DateEarnedHardcore'];
          if (dateEarned != null) {
            earnedAchievements++;
          }
          totalPoints += (ach['Points'] as int?) ?? 0;

          // Add to achievements list for secondary display
          // Include both Type/type and Flags/flags for compatibility
          achievementsList.add({
            'ID': ach['ID'],
            'Title': ach['Title'],
            'Description': ach['Description'],
            'Points': ach['Points'],
            'BadgeName': ach['BadgeName'],
            'DateEarned': ach['DateEarned'],
            'DateEarnedHardcore': ach['DateEarnedHardcore'],
            'Flags': ach['Flags'] ?? ach['flags'],
            'flags': ach['flags'] ?? ach['Flags'],
            'Type': ach['Type'] ?? ach['type'],
            'type': ach['type'] ?? ach['Type'],
            'NumAwarded': ach['NumAwarded'],
          });
        }
      }
    }

    _dualScreen.sendToSecondary({
      'gameTitle': data['Title'] ?? widget.gameTitle ?? 'Unknown Game',
      'consoleName': data['ConsoleName'] ?? '',
      'achievementCount': totalAchievements,
      'earnedCount': earnedAchievements,
      'points': totalPoints,
      'numDistinctPlayers': numDistinctPlayers,
      'username': authState.username,
      'imageUrl': data['ImageIcon'] != null
          ? 'https://retroachievements.org${data['ImageIcon']}'
          : null,
      'achievements': achievementsList,
      // Include current filter/sort state
      'filter': _filter.index,
      'sort': _sort.index,
      'showMissable': _showMissable,
    });
  }

  Future<void> _loadLeaderboards() async {
    setState(() => _isLoadingLeaderboards = true);
    final api = ref.read(apiDataSourceProvider);
    final result = await api.getGameLeaderboards(widget.gameId);
    debugPrint('GameLeaderboards API response for game ${widget.gameId}: $result');
    debugPrint('GameLeaderboards count: ${result?.length ?? 0}');
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

  Future<void> _loadUserGameLeaderboards() async {
    final api = ref.read(apiDataSourceProvider);
    final username = ref.read(authProvider).username;
    if (username == null) return;

    setState(() => _isLoadingUserLeaderboards = true);
    final result = await api.getUserGameLeaderboards(username, widget.gameId);
    debugPrint('UserGameLeaderboards API response for game ${widget.gameId}: $result');
    if (mounted) {
      setState(() {
        _isLoadingUserLeaderboards = false;
        if (result != null) {
          final results = result['Results'] as List<dynamic>? ?? [];
          debugPrint('UserGameLeaderboards parsed ${results.length} entries');
          _userGameLeaderboards = List<Map<String, dynamic>>.from(
            results.map((e) => Map<String, dynamic>.from(e)),
          );
        }
      });

      // Prefetch leaderboard entries AFTER setState completes
      if (result != null && _userGameLeaderboards.isNotEmpty) {
        _prefetchUserLeaderboardEntries();
      }
    }
  }

  /// Prefetch leaderboard entries for leaderboards where user has entries
  /// This runs in the background and caches results for faster dialog loads
  Future<void> _prefetchUserLeaderboardEntries() async {
    if (_userGameLeaderboards.isEmpty) return;

    final api = ref.read(apiDataSourceProvider);
    final cache = LeaderboardCache.instance;

    // Only prefetch first 5 leaderboards to avoid too many API calls
    final leaderboardsToFetch = _userGameLeaderboards.take(5).toList();

    for (final entry in leaderboardsToFetch) {
      final leaderboardId = entry['LeaderboardID'] ?? entry['ID'];
      if (leaderboardId == null) continue;

      final id = leaderboardId is int ? leaderboardId : int.tryParse(leaderboardId.toString());
      if (id == null) continue;

      // Skip if already cached
      if (cache.has(id)) continue;

      // Fetch in background - don't await each one, fire and forget
      _fetchAndCacheLeaderboard(api, id);
    }
  }

  /// Fetch a single leaderboard's entries and cache them
  Future<void> _fetchAndCacheLeaderboard(dynamic api, int leaderboardId) async {
    try {
      final result = await api.getLeaderboardEntries(leaderboardId, count: 100)
          .timeout(const Duration(seconds: 10), onTimeout: () => null);

      if (result != null) {
        final entries = result['Results'] ?? result['Entries'] ?? result['entries'] ?? [];
        LeaderboardCache.instance.put(
          leaderboardId,
          List<Map<String, dynamic>>.from(entries),
        );
        debugPrint('Prefetched leaderboard $leaderboardId: ${entries.length} entries');
      }
    } catch (e) {
      // Silent fail for prefetch - dialog will fetch fresh if needed
      debugPrint('Prefetch failed for leaderboard $leaderboardId: $e');
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
    final isWidescreen = ResponsiveLayout.isWidescreen(context);

    return RefreshIndicator(
      onRefresh: _loadGame,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Hero/AppBar spans full width
          _buildAppBar(title, imageIcon, imageTitle, isLightMode),
          // All other content is containerized on widescreen
          _buildGameInfoCard(title, console, imageIcon, developer, publisher, genre, released, numAchievements, numAwarded, totalPoints, earnedPoints, progress, completion, isWidescreen),
          // Toggle between Achievements and Leaderboards
          if (numAchievements > 0 || _leaderboards.isNotEmpty)
            _buildViewToggle(numAchievements, _leaderboards.length, isWidescreen),
          // Show either Achievements or Leaderboards based on toggle
          if (!_showLeaderboards) ...[
            if (numAchievements > 0)
              _buildRarityDistribution(achievements, numDistinctPlayers, isWidescreen),
            if (numAchievements > 0)
              _buildAchievementsHeader(achievements, numAwarded, earnedPoints, totalPoints, isWidescreen),
            if (numAchievements > 0)
              _buildAchievementsList(achievements, numDistinctPlayers, title, imageIcon, console, isWidescreen),
          ] else ...[
            _buildLeaderboardsHeader(isWidescreen),
            _buildLeaderboardsListView(isWidescreen),
          ],
          SliverToBoxAdapter(child: _wrapForWidescreen(const SizedBox(height: 32), isWidescreen)),
        ],
      ),
    );
  }

  /// Wraps a widget in a centered container for widescreen displays
  Widget _wrapForWidescreen(Widget child, bool isWidescreen) {
    if (!isWidescreen) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: child,
      ),
    );
  }

  Widget _buildAppBar(String title, String imageIcon, String imageTitle, bool isLightMode) {
    // Content is constrained to 600px on widescreen, so use standard phone height
    // Tablet portrait: taller header
    // Phone: standard header
    final screenWidth = MediaQuery.of(context).size.width;
    final double expandedHeight;
    if (screenWidth > 600) {
      expandedHeight = 320.0; // Tablet
    } else {
      expandedHeight = 220.0; // Phone (also used for constrained widescreen)
    }

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      foregroundColor: isLightMode ? Colors.grey[900] : Colors.white,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
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
                // Title text with typewriter animation
                Expanded(
                  child: _buildAnimatedTitle(title, titleColor, collapseRatio),
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

  /// Build animated title with typewriter effect on first load
  Widget _buildAnimatedTitle(String title, Color titleColor, double collapseRatio) {
    final baseStyle = TextStyle(
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
    );

    // Show static text when collapsed or animation complete
    if (collapseRatio > 0.5 || _titleAnimationComplete) {
      return Text(
        title,
        style: baseStyle,
        maxLines: collapseRatio > 0.7 ? 1 : 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Typewriter animation when expanded and not yet complete
    return AnimatedTextKit(
      animatedTexts: [
        TypewriterAnimatedText(
          title,
          textStyle: baseStyle,
          speed: Duration(milliseconds: (40 + (800 ~/ title.length)).clamp(30, 80)),
        ),
      ],
      totalRepeatCount: 1,
      displayFullTextOnTap: true,
      onFinished: () {
        if (mounted) {
          setState(() => _titleAnimationComplete = true);
        }
      },
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildGameInfoCard(
    String title, String console, String imageIcon,
    dynamic developer, dynamic publisher, dynamic genre, dynamic released,
    int numAchievements, int numAwarded, int totalPoints, int earnedPoints,
    double progress, String completion, bool isWidescreen,
  ) {
    return SliverToBoxAdapter(
      child: _wrapForWidescreen(Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                          Row(
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
                              const Spacer(),
                              // Share button
                              _buildIconButton(
                                icon: Icons.share,
                                color: Colors.blue,
                                onTap: () {
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
                              ),
                              const SizedBox(width: 8),
                              // Favorite button
                              FavoriteIconButton(
                                gameId: widget.gameId,
                                title: title,
                                imageIcon: imageIcon,
                                consoleName: console,
                                numAchievements: numAchievements,
                                earnedAchievements: numAwarded,
                                totalPoints: totalPoints,
                                earnedPoints: earnedPoints,
                              ),
                            ],
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
                                      AnimatedCounter(
                                        value: numAwarded,
                                        duration: const Duration(milliseconds: 800),
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '/$numAchievements',
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
                                        AnimatedCounter(
                                          value: earnedPoints,
                                          duration: const Duration(milliseconds: 800),
                                          style: TextStyle(
                                            color: Colors.amber[600],
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '/$totalPoints pts',
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
                            AnimatedProgressBar(
                              progress: progress,
                              height: 6,
                              duration: const Duration(milliseconds: 1000),
                              color: Theme.of(context).colorScheme.primary,
                              backgroundColor: Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey[300]!
                                  : Colors.grey[700]!,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                AnimatedCounter(
                                  value: (progress * 100).round(),
                                  duration: const Duration(milliseconds: 1000),
                                  suffix: '% complete',
                                  style: TextStyle(color: context.subtitleColor, fontSize: 12),
                                ),
                              ],
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
      ), isWidescreen),
    );
  }

  /// Build toggle between Achievements and Leaderboards view
  Widget _buildViewToggle(int achievementCount, int leaderboardCount, bool isWidescreen) {
    return SliverToBoxAdapter(
      child: _wrapForWidescreen(Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[850]
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Haptics.light();
                    setState(() => _showLeaderboards = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_showLeaderboards
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 18,
                          color: !_showLeaderboards ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Achievements ($achievementCount)',
                          style: TextStyle(
                            color: !_showLeaderboards ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Haptics.light();
                    setState(() => _showLeaderboards = true);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _showLeaderboards
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.leaderboard,
                          size: 18,
                          color: _showLeaderboards ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Leaderboards ($leaderboardCount)',
                          style: TextStyle(
                            color: _showLeaderboards ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ), isWidescreen),
    );
  }

  Widget _buildRarityDistribution(Map<String, dynamic> achievements, int numDistinctPlayers, bool isWidescreen) {
    final rarityCounts = calculateRarityDistribution(achievements, numDistinctPlayers);

    return SliverToBoxAdapter(
      child: _wrapForWidescreen(Padding(
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
      ), isWidescreen),
    );
  }

  Widget _buildAchievementsHeader(
    Map<String, dynamic> achievements,
    int numAwarded,
    int earnedPoints,
    int totalPoints,
    bool isWidescreen,
  ) {
    final filtered = getFilteredAchievements(achievements, _filter, _sort, _showMissable);

    return SliverToBoxAdapter(
      child: _wrapForWidescreen(Padding(
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
      ), isWidescreen),
    );
  }

  Widget _buildAchievementsList(
    Map<String, dynamic> achievements,
    int numDistinctPlayers,
    String title,
    String imageIcon,
    String console,
    bool isWidescreen,
  ) {
    final filtered = getFilteredAchievements(achievements, _filter, _sort, _showMissable);

    if (filtered.isEmpty && _showMissable) {
      return SliverToBoxAdapter(child: _wrapForWidescreen(const NoMissableMessage(), isWidescreen));
    }

    final username = ref.watch(authProvider).username;
    final userPic = _gameData?['UserPic'] ?? '';

    // For widescreen, content is already constrained to 600px, use single column
    // For tablets/phones, use appropriate layout
    if (isWidescreen) {
      // Single column list wrapped in container
      return SliverPadding(
        padding: EdgeInsets.zero,
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _wrapForWidescreen(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: AchievementTile(
                  achievement: filtered[index],
                  numDistinctPlayers: numDistinctPlayers,
                  gameTitle: title,
                  gameIcon: imageIcon,
                  consoleName: console,
                  username: username,
                  userPic: userPic,
                ),
              ),
              isWidescreen,
            ),
            childCount: filtered.length,
          ),
        ),
      );
    }

    // Original grid layout for tablets
    if (MediaQuery.of(context).size.width > 600) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.8, // Wider tiles for landscape
            crossAxisSpacing: 8,
            mainAxisSpacing: 4,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= filtered.length) return null;
              return AchievementTile(
                achievement: filtered[index],
                numDistinctPlayers: numDistinctPlayers,
                gameTitle: title,
                gameIcon: imageIcon,
                consoleName: console,
                username: username,
                userPic: userPic is String ? userPic : '',
                compact: true, // Use compact mode for grid
              );
            },
            childCount: filtered.length,
          ),
        ),
      );
    }

    // Standard list layout for phone/tablet portrait
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

  /// Build unified leaderboards header with user entry count
  Widget _buildLeaderboardsHeader(bool isWidescreen) {
    if (_isLoadingLeaderboards && _isLoadingUserLeaderboards) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final userEntryCount = _userGameLeaderboards.length;
    final totalCount = _leaderboards.length;

    return SliverToBoxAdapter(
      child: _wrapForWidescreen(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            const Icon(Icons.leaderboard, size: 22, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Leaderboards', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            if (userEntryCount > 0 && totalCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      '$userEntryCount of $totalCount',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else if (totalCount > 0)
              Text(
                '$totalCount ${totalCount == 1 ? 'leaderboard' : 'leaderboards'}',
                style: TextStyle(color: context.subtitleColor, fontSize: 12),
              ),
          ],
        ),
      ), isWidescreen),
    );
  }

  /// Build full leaderboards list view (when toggled to leaderboards)
  Widget _buildLeaderboardsListView(bool isWidescreen) {
    if (_isLoadingLeaderboards) {
      return SliverToBoxAdapter(
        child: _wrapForWidescreen(const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ), isWidescreen),
      );
    }

    if (_leaderboards.isEmpty) {
      return SliverToBoxAdapter(
        child: _wrapForWidescreen(Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.leaderboard_outlined, size: 48, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'No leaderboards available',
                style: TextStyle(color: context.subtitleColor),
              ),
            ],
          ),
        ), isWidescreen),
      );
    }

    // Build a lookup map of user's leaderboard entries by ID
    final userEntryMap = <int, Map<String, dynamic>>{};
    for (final entry in _userGameLeaderboards) {
      final id = entry['ID'] ?? entry['LeaderboardId'];
      if (id != null) {
        userEntryMap[id is int ? id : int.tryParse(id.toString()) ?? 0] = entry;
      }
    }

    // Sort leaderboards: user's entries first, then the rest
    final sortedLeaderboards = List<Map<String, dynamic>>.from(_leaderboards);
    sortedLeaderboards.sort((a, b) {
      final aId = a['ID'] ?? a['LeaderboardId'] ?? 0;
      final bId = b['ID'] ?? b['LeaderboardId'] ?? 0;
      final aHasEntry = userEntryMap.containsKey(aId is int ? aId : int.tryParse(aId.toString()) ?? 0);
      final bHasEntry = userEntryMap.containsKey(bId is int ? bId : int.tryParse(bId.toString()) ?? 0);
      if (aHasEntry && !bHasEntry) return -1;
      if (!aHasEntry && bHasEntry) return 1;
      return 0;
    });

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= sortedLeaderboards.length) return null;
          final leaderboard = sortedLeaderboards[index];
          final leaderboardId = leaderboard['ID'] ?? leaderboard['LeaderboardId'] ?? 0;
          final userEntry = userEntryMap[leaderboardId is int ? leaderboardId : int.tryParse(leaderboardId.toString()) ?? 0];

          return _wrapForWidescreen(LeaderboardTile(
            leaderboard: leaderboard,
            userEntry: userEntry,
            onTap: () => _showLeaderboardDetail(leaderboard, userEntry: userEntry),
          ), isWidescreen);
        },
        childCount: sortedLeaderboards.length,
      ),
    );
  }

  Widget _buildLeaderboardsSection() {
    // Always show the section header for debugging
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
        else if (_leaderboards.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No leaderboards available for this game',
                style: TextStyle(color: context.subtitleColor, fontStyle: FontStyle.italic),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= _leaderboards.length) return null;
                final leaderboard = _leaderboards[index];
                final leaderboardId = leaderboard['ID'] ?? leaderboard['LeaderboardId'] ?? 0;

                // Find user's entry for this leaderboard
                Map<String, dynamic>? userEntry;
                for (final entry in _userGameLeaderboards) {
                  final entryId = entry['ID'] ?? entry['LeaderboardId'];
                  if (entryId != null) {
                    final entryIdInt = entryId is int ? entryId : int.tryParse(entryId.toString()) ?? 0;
                    final lbIdInt = leaderboardId is int ? leaderboardId : int.tryParse(leaderboardId.toString()) ?? 0;
                    if (entryIdInt == lbIdInt) {
                      userEntry = entry;
                      break;
                    }
                  }
                }

                return LeaderboardTile(
                  leaderboard: leaderboard,
                  userEntry: userEntry,
                  onTap: () => _showLeaderboardDetail(leaderboard, userEntry: userEntry),
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

  void _showLeaderboardDetail(Map<String, dynamic> leaderboard, {Map<String, dynamic>? userEntry}) {
    final id = leaderboard['ID'] ?? leaderboard['LeaderboardId'] ?? 0;
    final title = leaderboard['Title'] ?? 'Leaderboard';
    final description = leaderboard['Description'] ?? '';
    final format = leaderboard['Format'] ?? '';
    final gameTitle = _gameData?['Title'] ?? 'Unknown Game';
    final gameIcon = _gameData?['ImageIcon'] ?? '';
    final username = ref.read(authProvider).username ?? '';

    showDialog(
      context: context,
      builder: (ctx) => LeaderboardDetailDialog(
        leaderboardId: id is int ? id : int.tryParse(id.toString()) ?? 0,
        title: title,
        description: description,
        format: format,
        userEntry: userEntry,
        gameTitle: gameTitle,
        gameIcon: gameIcon,
        onShare: userEntry != null ? () {
          Navigator.pop(ctx);
          final nestedUserEntry = userEntry['UserEntry'] as Map<String, dynamic>? ?? userEntry;
          final rank = nestedUserEntry['Rank'] ?? userEntry['Rank'] ?? 0;
          final formattedScore = nestedUserEntry['FormattedScore'] ??
                                 nestedUserEntry['Score']?.toString() ??
                                 userEntry['FormattedScore'] ??
                                 userEntry['Score']?.toString() ?? '';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShareCardScreen(
                type: ShareCardType.leaderboard,
                data: {
                  'username': username,
                  'userPic': '/UserPic/$username.png',
                  'gameTitle': gameTitle,
                  'gameIcon': gameIcon,
                  'leaderboardTitle': title,
                  'leaderboardDescription': description,
                  'rank': rank,
                  'formattedScore': formattedScore,
                },
              ),
            ),
          );
        } : null,
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
                itemBuilder: (ctx, i) {
                  // Look up user entry for this leaderboard
                  final leaderboard = _leaderboards[i];
                  final leaderboardId = leaderboard['ID'] ?? leaderboard['LeaderboardId'] ?? 0;
                  final userEntry = _userGameLeaderboards.firstWhere(
                    (e) {
                      final id = e['ID'] ?? e['LeaderboardId'];
                      return (id is int ? id : int.tryParse(id.toString()) ?? 0) ==
                             (leaderboardId is int ? leaderboardId : int.tryParse(leaderboardId.toString()) ?? 0);
                    },
                    orElse: () => <String, dynamic>{},
                  );
                  final hasUserEntry = userEntry.isNotEmpty;

                  return LeaderboardTile(
                    leaderboard: leaderboard,
                    userEntry: hasUserEntry ? userEntry : null,
                    onTap: () {
                      Navigator.pop(context);
                      _showLeaderboardDetail(leaderboard, userEntry: hasUserEntry ? userEntry : null);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build full achievement detail dialog (triggered from secondary display tap)
  /// Matches AchievementTile dialog but more compact
  Widget _buildFullAchievementDialog(
    BuildContext ctx,
    Map<String, dynamic> achievement,
    int numDistinctPlayers, {
    String? username,
    String? userPic,
    String? gameTitle,
    String? gameIcon,
    String? consoleName,
  }) {
    final title = achievement['Title'] ?? 'Achievement';
    final description = achievement['Description'] ?? '';
    final points = achievement['Points'] ?? 0;
    final badgeName = achievement['BadgeName'] ?? '';
    final numAwarded = achievement['NumAwarded'] ?? 0;
    final dateEarned = achievement['DateEarned'] ?? achievement['DateEarnedHardcore'];
    final isEarned = dateEarned != null;

    // Check if missable
    final type = (achievement['Type'] ?? achievement['type'] ?? '').toString().toLowerCase();
    final flags = achievement['Flags'] ?? achievement['flags'] ?? 0;
    final isMissable = type == 'missable' || type.contains('missable') || flags == 4 || (flags is int && (flags & 4) != 0);

    // Calculate rarity
    double unlockPercent = 0.0;
    String rarityLabel = 'Common';
    Color rarityColor = Colors.blueGrey;
    IconData rarityIcon = Icons.circle;

    if (numDistinctPlayers > 0) {
      unlockPercent = (numAwarded / numDistinctPlayers * 100);
      if (unlockPercent < 5) {
        rarityLabel = 'Ultra Rare';
        rarityColor = Colors.red;
        rarityIcon = Icons.diamond;
      } else if (unlockPercent < 15) {
        rarityLabel = 'Rare';
        rarityColor = Colors.purple;
        rarityIcon = Icons.star;
      } else if (unlockPercent < 40) {
        rarityLabel = 'Uncommon';
        rarityColor = Colors.blue;
        rarityIcon = Icons.hexagon;
      }
    }

    final isPremium = ref.read(isPremiumProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360, maxHeight: 480),
        child: Stack(
          children: [
            // Main content
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 16), // Extra top padding for X button
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge with earned/locked state - compact size
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              if (isEarned)
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
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
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.emoji_events, size: 32),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!isEarned)
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock, color: Colors.white, size: 16),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Earned status badge - compact
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isEarned ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isEarned ? Icons.check_circle : Icons.lock_outline,
                            color: isEarned ? Colors.green : Colors.orange,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isEarned ? 'UNLOCKED' : 'LOCKED',
                            style: TextStyle(
                              color: isEarned ? Colors.green : Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                // Title - compact
                Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Description - compact
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(ctx).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[700],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // Points, rarity, missable badges - single row
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildCompactBadge(Icons.star, '$points pts', Colors.amber),
                    _buildCompactBadge(rarityIcon, rarityLabel, rarityColor),
                    if (isMissable) _buildCompactBadge(Icons.warning_amber, 'Missable', Colors.red),
                  ],
                ),
                const SizedBox(height: 10),

                // Rarity bar - compact
                if (numDistinctPlayers > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: rarityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Rarity', style: TextStyle(color: rarityColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text('${unlockPercent.toStringAsFixed(1)}%', style: TextStyle(color: rarityColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (unlockPercent / 100).clamp(0.0, 1.0),
                            backgroundColor: rarityColor.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(rarityColor),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$numAwarded of $numDistinctPlayers players',
                          style: TextStyle(color: Colors.grey[400], fontSize: 9),
                        ),
                      ],
                    ),
                  ),

                // User info section - compact
                if (username != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: userPic != null && userPic.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: 'https://retroachievements.org$userPic',
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _buildAvatarPlaceholder(username, 28),
                                )
                              : _buildAvatarPlaceholder(username, 28),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              if (isEarned && dateEarned != null)
                                Text(
                                  'Earned: $dateEarned',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 9),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Share button (for all achievements)
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Navigate to share card screen
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
                              'UserPic': userPic ?? '',
                              'IsEarned': isEarned,
                              'DateEarned': dateEarned,
                              'UnlockPercent': unlockPercent,
                              'RarityLabel': rarityLabel,
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.share, size: 14),
                    label: const Text('Share', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // X button in top right
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.close),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              padding: const EdgeInsets.all(4),
              minimumSize: const Size(32, 32),
            ),
            iconSize: 20,
          ),
        ),
          ],
        ),
      ),
    );
  }

  /// Build compact badge widget
  Widget _buildCompactBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  /// Build avatar placeholder
  Widget _buildAvatarPlaceholder(String username, double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[700],
      child: Center(
        child: Text(
          username[0].toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: size * 0.5),
        ),
      ),
    );
  }
}
