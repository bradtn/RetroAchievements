import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme_utils.dart';
import '../../core/animations.dart';
import '../../data/cache/game_cache.dart';
import '../../services/widget_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/ad_banner.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'game_detail_screen.dart';
import 'console_browser_screen.dart';
import 'leaderboard_screen.dart';
import 'aotw_screen.dart';
import 'favorites_screen.dart';
import 'friends_screen.dart';
import 'calendar_screen.dart';
import 'share_card/share_card_screen.dart';
import 'game_search_screen.dart';
import 'milestones/milestones_screen.dart';
import 'live_feed_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _profile;
  List<dynamic>? _recentGames;
  List<dynamic>? _recentAchievements;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Initialize cache
    await GameCache.instance.init();

    final api = ref.read(apiDataSourceProvider);
    final username = ref.read(authProvider).username;

    if (username != null) {
      // Use API that returns HardcoreMode field for achievements
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final results = await Future.wait([
        api.getUserProfile(username),
        api.getRecentlyPlayedGames(username),
        api.getAchievementsEarnedBetween(username, thirtyDaysAgo, now),
      ]);

      // Limit to 20 most recent and sort by date descending
      var achievements = results[2] as List<dynamic>?;
      if (achievements != null && achievements.isNotEmpty) {
        achievements = List<dynamic>.from(achievements);
        achievements.sort((a, b) {
          final dateA = a['Date'] ?? '';
          final dateB = b['Date'] ?? '';
          return dateB.compareTo(dateA);
        });
        if (achievements.length > 20) {
          achievements = achievements.sublist(0, 20);
        }
      }

      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _recentGames = results[1] as List<dynamic>?;
        _recentAchievements = achievements;
        _isLoading = false;
      });

      // Cache recently played games
      if (_recentGames != null) {
        GameCache.instance.putAll(
          _recentGames!.map((g) => Map<String, dynamic>.from(g)).toList(),
        );
      }

      // Sync widget data in background
      _syncWidgetData(achievements);
    }
  }

  Future<void> _syncWidgetData(List<dynamic>? achievements) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final api = ref.read(apiDataSourceProvider);
      final username = ref.read(authProvider).username;
      if (username == null) return;

      // Sync recent achievements to widget
      if (achievements != null && achievements.isNotEmpty) {
        final widgetData = <Map<String, dynamic>>[];
        final now = DateTime.now();

        for (final ach in achievements.take(5)) {
          if (ach is! Map) continue;

          final dateStr = ach['Date']?.toString() ?? ach['DateEarned']?.toString() ?? '';
          String timestamp = '';
          if (dateStr.isNotEmpty) {
            try {
              final date = DateTime.parse(dateStr);
              final diff = now.difference(date);
              if (diff.inMinutes < 60) {
                timestamp = '${diff.inMinutes}m ago';
              } else if (diff.inHours < 24) {
                timestamp = '${diff.inHours}h ago';
              } else if (diff.inDays < 7) {
                timestamp = '${diff.inDays}d ago';
              } else {
                timestamp = '${date.month}/${date.day}';
              }
            } catch (_) {}
          }

          widgetData.add({
            'title': ach['Title']?.toString() ?? 'Achievement',
            'gameTitle': ach['GameTitle']?.toString() ?? 'Unknown Game',
            'consoleName': ach['ConsoleName']?.toString() ?? '',
            'points': ach['Points'] ?? 0,
            'hardcore': (ach['HardcoreMode'] ?? 0) == 1,
            'timestamp': timestamp,
            'achievementIcon': ach['BadgeName'] != null
                ? '/Badge/${ach['BadgeName']}.png'
                : '',
            'gameIcon': ach['GameIcon']?.toString() ?? '',
          });
        }

        await prefs.setString('widget_recent_achievements', jsonEncode(widgetData));
      }

      // Sync streak data - calculate from achievements
      if (achievements != null && achievements.isNotEmpty) {
        final activityMap = <String, int>{};
        for (final ach in achievements) {
          if (ach is! Map) continue;
          final dateStr = ach['Date']?.toString() ?? '';
          if (dateStr.isEmpty) continue;
          try {
            final date = DateTime.parse(dateStr);
            final dayKey = '${date.year}-${date.month}-${date.day}';
            activityMap[dayKey] = (activityMap[dayKey] ?? 0) + 1;
          } catch (_) {}
        }

        final today = DateTime.now();
        final todayKey = '${today.year}-${today.month}-${today.day}';
        final yesterday = today.subtract(const Duration(days: 1));
        final yesterdayKey = '${yesterday.year}-${yesterday.month}-${yesterday.day}';

        int currentStreak = 0;
        if (activityMap.containsKey(todayKey) || activityMap.containsKey(yesterdayKey)) {
          DateTime checkDate = activityMap.containsKey(todayKey) ? today : yesterday;
          while (true) {
            final key = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
            if (!activityMap.containsKey(key)) break;
            currentStreak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          }
        }

        await prefs.setInt('widget_current_streak', currentStreak);
        await prefs.setInt('widget_best_streak', currentStreak); // Use current as best for now
      }

      // Sync AOTW
      final aotw = await api.getAchievementOfTheWeek();
      if (aotw != null) {
        final achievement = aotw['Achievement'] as Map<String, dynamic>?;
        final game = aotw['Game'] as Map<String, dynamic>?;
        final console = aotw['Console'] as Map<String, dynamic>?;

        await prefs.setString('widget_aotw_title', achievement?['Title']?.toString() ?? '');
        await prefs.setString('widget_aotw_game', game?['Title']?.toString() ?? '');
        await prefs.setInt('widget_aotw_points', achievement?['Points'] ?? 0);

        final gameId = game?['ID'];
        final gameIdInt = gameId is int ? gameId : int.tryParse(gameId?.toString() ?? '') ?? 0;
        await prefs.setInt('widget_aotw_game_id', gameIdInt);

        final badgeName = achievement?['BadgeName']?.toString() ?? '';
        await prefs.setString('widget_aotw_achievement_icon',
            badgeName.isNotEmpty ? '/Badge/$badgeName.png' : '');

        // Fetch game details to get ImageIcon and ConsoleName (not included in AOTW response)
        String gameIcon = '';
        String consoleName = console?['Name']?.toString() ?? '';
        if (gameIdInt > 0) {
          final gameDetails = await api.getGameInfo(gameIdInt);
          gameIcon = gameDetails?['ImageIcon']?.toString() ?? '';
          if (consoleName.isEmpty) {
            consoleName = gameDetails?['ConsoleName']?.toString() ?? '';
          }
        }
        await prefs.setString('widget_aotw_game_icon', gameIcon);
        await prefs.setString('widget_aotw_console', consoleName);

        // Date range and unlocks
        final startDate = aotw['StartAt']?.toString() ?? '';
        String dateRange = '';
        if (startDate.isNotEmpty) {
          try {
            final start = DateTime.parse(startDate);
            final end = start.add(const Duration(days: 6));
            final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            dateRange = '${months[start.month - 1]} ${start.day} - ${months[end.month - 1]} ${end.day}';
          } catch (_) {}
        }
        await prefs.setString('widget_aotw_date_range', dateRange);

        final unlocks = aotw['UnlocksCount'] ?? aotw['TotalUnlocks'] ?? 0;
        await prefs.setInt('widget_aotw_unlocks', unlocks is int ? unlocks : 0);
      }

      // Update all widgets
      await WidgetService.updateAllWidgets();
    } catch (e) {
      // Silently fail - widgets will use cached data
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                _HomeTab(
                  profile: _profile,
                  recentGames: _recentGames,
                  isLoading: _isLoading,
                  onRefresh: _loadData,
                ),
                _ExploreTab(isSelected: _currentIndex == 1),
                _AchievementsTab(
                  achievements: _recentAchievements,
                  isLoading: _isLoading,
                  onRefresh: _loadData,
                ),
                const SettingsScreen(),
              ],
            ),
          ),
          // Banner ad (hidden for premium users)
          const AdBanner(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Colors.grey.shade600),
            selectedIcon: Icon(Icons.home, color: Theme.of(context).colorScheme.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined, color: Colors.grey.shade600),
            selectedIcon: Icon(Icons.explore, color: Theme.of(context).colorScheme.primary),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined, color: Colors.grey.shade600),
            selectedIcon: Icon(Icons.emoji_events, color: Theme.of(context).colorScheme.primary),
            label: 'Achievements',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: Colors.grey.shade600),
            selectedIcon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// ============ HOME TAB ============
class _HomeTab extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final List<dynamic>? recentGames;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _HomeTab({
    required this.profile,
    required this.recentGames,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildShimmerLoading();
    }

    return RetroRefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 40),
          // Profile header
          if (profile != null) _buildProfileHeader(context),
          const SizedBox(height: 24),
          // Stats cards
          if (profile != null) _buildStatsRow(context),
          const SizedBox(height: 16),
          // View detailed stats button
          AnimatedListItem(
            index: 0,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    SlidePageRoute(page: const StatsScreen()),
                  );
                },
                icon: const Icon(Icons.analytics),
                label: const Text('View Detailed Stats'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Recent games
          Text('Recently Played', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (recentGames != null && recentGames!.isNotEmpty)
            ...recentGames!.take(5).toList().asMap().entries.map((entry) =>
              AnimatedListItem(
                index: entry.key,
                child: _GameListTile(game: entry.value),
              ),
            )
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No recent games'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 40),
        const ShimmerProfileHeader(),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: ShimmerCard(height: 100)),
            const SizedBox(width: 12),
            const Expanded(child: ShimmerCard(height: 100)),
          ],
        ),
        const SizedBox(height: 40),
        const ShimmerCard(height: 20, width: 150),
        const SizedBox(height: 12),
        ...List.generate(4, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: ShimmerGameTile(),
        )),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final picUrl = 'https://retroachievements.org${profile!['UserPic']}';
    final username = profile!['User'] ?? 'User';
    return Row(
      children: [
        ClipOval(
          child: CachedNetworkImage(
            imageUrl: picUrl,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 80,
              height: 80,
              color: Colors.grey[800],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 80,
              height: 80,
              color: Colors.grey[800],
              child: Center(
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                profile!['RichPresenceMsg'] ?? 'Offline',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {
            Navigator.push(
              context,
              FadeScalePageRoute(
                page: ShareCardScreen(
                  type: ShareCardType.profile,
                  data: profile!,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(
          icon: Icons.stars,
          label: 'Points',
          value: '${profile!['TotalPoints'] ?? 0}',
          color: Colors.amber,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          icon: Icons.military_tech,
          label: 'True Points',
          value: '${profile!['TotalTruePoints'] ?? 0}',
          color: Colors.purple,
        )),
      ],
    );
  }
}

// ============ EXPLORE TAB ============
class _ExploreTab extends StatefulWidget {
  final bool isSelected;

  const _ExploreTab({required this.isSelected});

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> with TickerProviderStateMixin {
  bool _hasNewAotw = false;
  late AnimationController _animationController;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _checkForNewAotw();
  }

  @override
  void didUpdateWidget(_ExploreTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger animation when tab becomes selected for the first time
    if (widget.isSelected && !oldWidget.isSelected && !_hasAnimated) {
      _hasAnimated = true;
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkForNewAotw() async {
    final prefs = await SharedPreferences.getInstance();
    final lastKnownId = prefs.getString('last_known_aotw_id') ?? '';
    final lastViewedId = prefs.getString('last_viewed_aotw_id') ?? '';

    if (mounted && lastKnownId.isNotEmpty && lastKnownId != lastViewedId) {
      setState(() => _hasNewAotw = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _ExploreItem(
        icon: Icons.search,
        title: 'Search',
        color: Colors.pink,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const GameSearchScreen())),
      ),
      _ExploreItem(
        icon: Icons.rss_feed,
        title: 'Live Feed',
        color: Colors.red,
        hasLiveIndicator: true,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const LiveFeedScreen())),
      ),
      _ExploreItem(
        icon: Icons.military_tech,
        title: 'Awards',
        color: Colors.purple,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const MilestonesScreen())),
      ),
      _ExploreItem(
        icon: Icons.star,
        title: 'Favorites',
        color: Colors.amber,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const FavoritesScreen())),
      ),
      _ExploreItem(
        icon: Icons.emoji_events,
        title: 'AOTW',
        color: Colors.orange,
        showNewBadge: _hasNewAotw,
        onTap: () {
          setState(() => _hasNewAotw = false);
          Navigator.push(context, SlidePageRoute(page: const AchievementOfTheWeekScreen()));
        },
      ),
      _ExploreItem(
        icon: Icons.videogame_asset,
        title: 'Consoles',
        color: Colors.blue,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const ConsoleBrowserScreen())),
      ),
      _ExploreItem(
        icon: Icons.leaderboard,
        title: 'Leaderboard',
        color: Colors.green,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const LeaderboardScreen())),
      ),
      _ExploreItem(
        icon: Icons.people,
        title: 'Friends',
        color: Colors.teal,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const FriendsScreen())),
      ),
      _ExploreItem(
        icon: Icons.calendar_month,
        title: 'Calendar',
        color: Colors.indigo,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const CalendarScreen())),
      ),
      _ExploreItem(
        icon: Icons.analytics,
        title: 'Stats',
        color: Colors.pink,
        isPremium: true,
        onTap: () => Navigator.push(context, SlidePageRoute(page: const StatsScreen())),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                // If animation complete or hasn't started, show items normally
                if (!_hasAnimated || _animationController.isCompleted) {
                  return _ExploreGridItem(item: items[index]);
                }

                // Staggered animation - each item starts slightly after the previous
                final itemDelay = index * 0.06; // 60ms stagger per item
                final itemEnd = (itemDelay + 0.5).clamp(0.0, 1.0); // 500ms animation duration per item
                final progress = ((_animationController.value - itemDelay) / (itemEnd - itemDelay)).clamp(0.0, 1.0);

                // Scale from 0.6 to 1.0 with bounce
                final scale = Curves.elasticOut.transform(progress);
                // Fade from 0 to 1
                final opacity = Curves.easeOut.transform(progress);

                return Transform.scale(
                  scale: 0.6 + (0.4 * scale),
                  child: Opacity(
                    opacity: opacity,
                    child: _ExploreGridItem(item: items[index]),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ExploreItem {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool isPremium;
  final bool showNewBadge;
  final bool hasLiveIndicator;
  final bool isFireIcon;

  const _ExploreItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.isPremium = false,
    this.showNewBadge = false,
    this.hasLiveIndicator = false,
    this.isFireIcon = false,
  });
}

class _ExploreGridItem extends StatelessWidget {
  final _ExploreItem item;

  const _ExploreGridItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return TappableCard(
      onTap: item.onTap,
      child: Card(
        child: Stack(
          children: [
            // Centered content
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildIcon(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            // Badges
            if (item.isPremium)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (item.showNewBadge)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEW',
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
    );
  }

  Widget _buildIcon() {
    if (item.isFireIcon) {
      return AnimatedFireIcon(size: 24, color: item.color);
    }
    if (item.hasLiveIndicator) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(item.icon, color: item.color, size: 24),
        ],
      );
    }
    return Icon(item.icon, color: item.color, size: 24);
  }
}

// ============ ACHIEVEMENTS TAB ============
class _AchievementsTab extends StatelessWidget {
  final List<dynamic>? achievements;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _AchievementsTab({
    required this.achievements,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Achievements'),
      ),
      body: isLoading
          ? _buildShimmerLoading()
          : RetroRefreshIndicator(
              onRefresh: () async => onRefresh(),
              child: achievements == null || achievements!.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 100),
                        EmptyStateWidget(
                          icon: Icons.emoji_events_outlined,
                          title: 'No achievements yet',
                          subtitle: 'Start playing to earn achievements!',
                          iconColor: Colors.amber,
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: achievements!.length,
                      itemBuilder: (ctx, i) {
                        return AnimatedListItem(
                          index: i,
                          child: _AchievementTile(achievement: achievements![i]),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(6, (_) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: ShimmerAchievementTile(),
      )),
    );
  }
}


// ============ HELPER WIDGETS ============
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            )),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _GameListTile extends StatelessWidget {
  final dynamic game;

  const _GameListTile({required this.game});

  @override
  Widget build(BuildContext context) {
    final imageUrl = 'https://retroachievements.org${game['ImageIcon']}';
    final earned = game['NumAchieved'] ?? 0;
    final total = game['NumPossibleAchievements'] ?? 0;
    final gameId = game['GameID'] ?? game['ID'];
    final heroTag = 'game_image_$gameId';

    return TappableCard(
      onTap: gameId != null ? () {
        Navigator.push(
          context,
          SlidePageRoute(
            page: GameDetailScreen(
              gameId: int.tryParse(gameId.toString()) ?? 0,
              gameTitle: game['Title'],
              heroTag: heroTag,
            ),
          ),
        );
      } : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: heroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey[800],
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey[800],
                      child: const Icon(Icons.games),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game['Title'] ?? 'Unknown Game',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Console chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        game['ConsoleName'] ?? '',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (total > 0) ...[
                      Row(
                        children: [
                          // Achievement chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events, size: 10, color: Colors.green),
                                const SizedBox(width: 3),
                                Text(
                                  '$earned/$total',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Text(
                        'No achievements yet',
                        style: TextStyle(color: context.subtitleColor, fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final dynamic achievement;

  const _AchievementTile({required this.achievement});

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      var date = DateTime.parse(dateStr);
      // Treat as UTC and convert to local
      date = DateTime.utc(date.year, date.month, date.day, date.hour, date.minute, date.second).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      // Format as date
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final badgeUrl = 'https://retroachievements.org/Badge/${achievement['BadgeName']}.png';
    final gameId = achievement['GameID'];
    final gameTitle = achievement['GameTitle'] ?? '';
    final dateStr = achievement['Date'] ?? achievement['DateEarned'] ?? '';
    final formattedDate = _formatDate(dateStr);
    // Check various possible hardcore field names and values
    final hardcoreMode = achievement['HardcoreMode'] == 1 ||
                         achievement['HardcoreMode'] == true ||
                         achievement['Hardcore'] == 1 ||
                         achievement['Hardcore'] == true ||
                         achievement['DateEarnedHardcore'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: gameId != null ? () {
          Haptics.light();
          final id = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
          if (id > 0) {
            Navigator.push(
              context,
              SlidePageRoute(
                page: GameDetailScreen(gameId: id, gameTitle: gameTitle),
              ),
            );
          }
        } : null,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: badgeUrl,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 48,
              height: 48,
              color: Colors.grey[800],
            ),
            errorWidget: (_, __, ___) => Container(
              width: 48,
              height: 48,
              color: Colors.grey[800],
              child: const Icon(Icons.emoji_events),
            ),
          ),
        ),
        title: Text(achievement['Title'] ?? 'Achievement'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              achievement['Description'] ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.stars, size: 12, color: Colors.amber[400]),
                const SizedBox(width: 4),
                Text(
                  '${achievement['Points'] ?? 0} pts',
                  style: TextStyle(color: Colors.amber[400], fontSize: 12),
                ),
                if (hardcoreMode) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'HC',
                      style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                if (formattedDate.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.access_time, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              gameTitle,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        isThreeLine: true,
        ),
      ),
    );
  }
}

