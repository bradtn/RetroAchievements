import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme_utils.dart';
import '../../data/cache/game_cache.dart';
import '../providers/auth_provider.dart';
import 'game_detail_screen.dart';
import 'profile_screen.dart';
import 'live_feed/live_feed_widgets.dart';

export 'live_feed/live_feed_widgets.dart';

class LiveFeedScreen extends ConsumerStatefulWidget {
  const LiveFeedScreen({super.key});

  @override
  ConsumerState<LiveFeedScreen> createState() => _LiveFeedScreenState();
}

class _LiveFeedScreenState extends ConsumerState<LiveFeedScreen> {
  List<Map<String, dynamic>> _feedItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _offset = 0;
  static const int _pageSize = 50;
  final ScrollController _scrollController = ScrollController();

  // Game icon cache
  final Map<int, String> _gameIcons = {};
  bool _isFetchingIcons = false;

  @override
  void initState() {
    super.initState();
    _initCache();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initCache() async {
    await GameCache.instance.init();
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && !_isLoading) {
        _loadMore();
      }
    }
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _offset = 0;
    });

    final api = ref.read(apiDataSourceProvider);
    final result = await api.getRecentGameAwards(count: _pageSize);

    if (mounted) {
      if (result != null) {
        setState(() {
          _feedItems = List<Map<String, dynamic>>.from(result);
          _isLoading = false;
        });
        // Fetch game icons in background
        _fetchMissingGameIcons();
      } else {
        setState(() {
          _error = 'Failed to load live feed';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMissingGameIcons() async {
    if (_isFetchingIcons) return;
    _isFetchingIcons = true;

    final api = ref.read(apiDataSourceProvider);
    final cache = GameCache.instance;

    // Find games we don't have icons for
    final List<int> missingIds = [];
    for (final item in _feedItems) {
      final gameId = item['GameID'] ?? item['gameId'] ?? 0;
      final id = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
      if (id > 0 && !_gameIcons.containsKey(id)) {
        // Check cache first
        final cachedIcon = cache.getImageIcon(id);
        if (cachedIcon != null && cachedIcon.isNotEmpty) {
          _gameIcons[id] = cachedIcon;
        } else if (!missingIds.contains(id)) {
          missingIds.add(id);
        }
      }
    }

    // Update UI with cached icons
    if (mounted && _gameIcons.isNotEmpty) {
      setState(() {});
    }

    // Fetch ALL missing icons from API in batches
    for (int i = 0; i < missingIds.length; i++) {
      if (!mounted) break;

      final id = missingIds[i];
      final gameInfo = await api.getGameInfo(id);
      if (gameInfo != null) {
        final icon = gameInfo['ImageIcon'] ?? '';
        if (icon.isNotEmpty) {
          _gameIcons[id] = icon;
          cache.put(id, gameInfo);
          if (mounted) setState(() {});
        }
      }

      // Small delay to be nice to the API (50ms between requests)
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _isFetchingIcons = false;
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    _offset += _pageSize;

    final api = ref.read(apiDataSourceProvider);
    final result = await api.getRecentGameAwards(count: _pageSize, offset: _offset);

    if (mounted) {
      if (result != null && result.isNotEmpty) {
        setState(() {
          _feedItems.addAll(List<Map<String, dynamic>>.from(result));
          _isLoadingMore = false;
        });
        // Fetch icons for newly loaded items
        _isFetchingIcons = false; // Reset so we can fetch again
        _fetchMissingGameIcons();
      } else {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).username;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text('Live Feed'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _feedItems.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadFeed,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          16 + MediaQuery.of(context).viewPadding.bottom,
                        ),
                        itemCount: _feedItems.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == _feedItems.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final feedUser = _feedItems[i]['User'] ?? _feedItems[i]['user'] ?? '';
                          final gameId = _feedItems[i]['GameID'] ?? _feedItems[i]['gameId'] ?? 0;
                          final gId = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
                          return FeedItemTile(
                            item: _feedItems[i],
                            gameIcon: _gameIcons[gId],
                            isCurrentUser: feedUser.toString().toLowerCase() ==
                                currentUser?.toLowerCase(),
                            onUserTap: () => _viewProfile(feedUser),
                            onGameTap: () => _viewGame(_feedItems[i]),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.subtitleColor),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadFeed,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
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
            Icon(Icons.rss_feed, size: 80, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No Recent Activity',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Recent game completions and masteries from the community will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.subtitleColor),
            ),
          ],
        ),
      ),
    );
  }

  void _viewProfile(String username) {
    if (username.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(username: username)),
    );
  }

  void _viewGame(Map<String, dynamic> item) {
    final gameId = item['GameID'] ?? item['gameId'] ?? item['game_id'] ?? 0;
    final gameTitle = item['GameTitle'] ?? item['gameTitle'] ?? item['Title'] ?? '';
    final id = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
    if (id > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameDetailScreen(
            gameId: id,
            gameTitle: gameTitle,
          ),
        ),
      );
    }
  }
}
