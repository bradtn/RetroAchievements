import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/cache/game_cache.dart';
import '../../services/widget_service.dart';
import '../providers/auth_provider.dart';
import '../providers/ra_status_provider.dart';
import '../widgets/ad_banner.dart';
import '../widgets/ra_status_banner.dart';
import 'settings_screen.dart';
import 'home/home_tab.dart';
import 'home/explore_tab.dart';
import 'home/achievements_tab.dart';

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

    await GameCache.instance.init();

    final api = ref.read(apiDataSourceProvider);
    final username = ref.read(authProvider).username;

    if (username != null) {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      final results = await Future.wait([
        api.getUserProfile(username),
        api.getRecentlyPlayedGames(username),
        api.getAchievementsEarnedBetween(username, thirtyDaysAgo, now),
      ]);

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

      // Report API status
      if (_profile != null) {
        ref.read(raStatusProvider.notifier).reportSuccess();
      } else {
        ref.read(raStatusProvider.notifier).reportFailure('Failed to load profile');
      }

      if (_recentGames != null) {
        GameCache.instance.putAll(
          _recentGames!.map((g) => Map<String, dynamic>.from(g)).toList(),
        );
      }

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

      // Sync streak data
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
        await prefs.setInt('widget_best_streak', currentStreak);
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
          const RAStatusBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                HomeTab(
                  profile: _profile,
                  recentGames: _recentGames,
                  isLoading: _isLoading,
                  onRefresh: _loadData,
                ),
                ExploreTab(isSelected: _currentIndex == 1),
                AchievementsTab(
                  achievements: _recentAchievements,
                  isLoading: _isLoading,
                  onRefresh: _loadData,
                ),
                const SettingsScreen(),
              ],
            ),
          ),
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
