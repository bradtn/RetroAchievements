import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';
import 'streak_provider.dart';

/// Provider for syncing data to home screen widgets
final widgetDataProvider = Provider<WidgetDataService>((ref) {
  return WidgetDataService(ref);
});

class WidgetDataService {
  final Ref _ref;

  WidgetDataService(this._ref);

  /// Sync all widget data - call this periodically or after relevant data changes
  Future<void> syncAllWidgetData() async {
    await Future.wait([
      syncRecentAchievements(),
      syncStreakData(),
      syncAotwData(),
      syncFriendActivity(),
    ]);
  }

  /// Sync recent achievements to widget
  Future<void> syncRecentAchievements() async {
    try {
      final api = _ref.read(apiDataSourceProvider);
      final username = api.username;
      if (username == null) return;

      final achievements = await api.getRecentAchievements(username, count: 10);
      if (achievements == null || achievements.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final widgetData = <Map<String, dynamic>>[];

      for (final ach in achievements.take(5)) {
        if (ach is! Map) continue;

        // Parse timestamp
        final dateStr = ach['Date']?.toString() ?? ach['DateEarned']?.toString() ?? '';
        String timestamp = '';
        if (dateStr.isNotEmpty) {
          try {
            final date = DateTime.parse(dateStr);
            final now = DateTime.now();
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
    } catch (e) {
      // Silently fail - widgets will show cached data
    }
  }

  /// Sync streak data to widget
  Future<void> syncStreakData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Try to get from streak provider if available
      final streakState = _ref.read(streakProvider);
      if (streakState.currentStreak > 0 || streakState.bestStreak > 0) {
        await prefs.setInt('widget_current_streak', streakState.currentStreak);
        await prefs.setInt('widget_best_streak', streakState.bestStreak);
        return;
      }

      // Fallback: calculate from API
      final api = _ref.read(apiDataSourceProvider);
      final username = api.username;
      if (username == null) return;

      final achievements = await api.getRecentAchievements(username, count: 365);
      if (achievements == null) return;

      // Calculate streak from achievements
      final achievementDates = <DateTime>{};
      for (final ach in achievements) {
        if (ach is! Map) continue;
        final dateStr = ach['Date']?.toString() ?? ach['DateEarned']?.toString() ?? '';
        if (dateStr.isEmpty) continue;
        try {
          final date = DateTime.parse(dateStr);
          achievementDates.add(DateTime(date.year, date.month, date.day));
        } catch (_) {}
      }

      if (achievementDates.isEmpty) {
        await prefs.setInt('widget_current_streak', 0);
        await prefs.setInt('widget_best_streak', 0);
        return;
      }

      // Calculate current streak
      final sortedDates = achievementDates.toList()..sort((a, b) => b.compareTo(a));
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final yesterday = todayDate.subtract(const Duration(days: 1));

      int currentStreak = 0;
      DateTime? checkDate;

      if (sortedDates.isNotEmpty) {
        final latestDate = sortedDates.first;
        if (latestDate == todayDate || latestDate == yesterday) {
          checkDate = latestDate;
          currentStreak = 1;

          for (int i = 1; i < sortedDates.length; i++) {
            final expectedPrev = checkDate!.subtract(const Duration(days: 1));
            if (sortedDates[i] == expectedPrev) {
              currentStreak++;
              checkDate = expectedPrev;
            } else if (sortedDates[i] != checkDate) {
              break;
            }
          }
        }
      }

      // Calculate best streak
      int bestStreak = currentStreak;
      int tempStreak = 1;
      for (int i = 1; i < sortedDates.length; i++) {
        final diff = sortedDates[i - 1].difference(sortedDates[i]).inDays;
        if (diff == 1) {
          tempStreak++;
          if (tempStreak > bestStreak) bestStreak = tempStreak;
        } else if (diff > 1) {
          tempStreak = 1;
        }
      }

      await prefs.setInt('widget_current_streak', currentStreak);
      await prefs.setInt('widget_best_streak', bestStreak);
    } catch (e) {
      // Silently fail
    }
  }

  /// Sync Achievement of the Week data to widget
  Future<void> syncAotwData() async {
    try {
      final api = _ref.read(apiDataSourceProvider);
      final aotw = await api.getAchievementOfTheWeek();
      if (aotw == null) return;

      final prefs = await SharedPreferences.getInstance();

      final achievement = aotw['Achievement'] as Map<String, dynamic>?;
      final game = aotw['Game'] as Map<String, dynamic>?;
      final console = aotw['Console'] as Map<String, dynamic>?;

      await prefs.setString('widget_aotw_title', achievement?['Title']?.toString() ?? '');
      await prefs.setString('widget_aotw_game', game?['Title']?.toString() ?? '');
      await prefs.setString('widget_aotw_console', console?['Name']?.toString() ?? '');
      await prefs.setInt('widget_aotw_points', achievement?['Points'] ?? 0);
      await prefs.setInt('widget_aotw_game_id', game?['ID'] ?? 0);

      final badgeName = achievement?['BadgeName']?.toString() ?? '';
      await prefs.setString('widget_aotw_achievement_icon',
          badgeName.isNotEmpty ? '/Badge/$badgeName.png' : '');
      await prefs.setString('widget_aotw_game_icon', game?['ImageIcon']?.toString() ?? '');
    } catch (e) {
      // Silently fail
    }
  }

  /// Sync friend activity to widget
  Future<void> syncFriendActivity() async {
    try {
      final api = _ref.read(apiDataSourceProvider);
      final username = api.username;
      if (username == null) return;

      // Get users I follow
      final following = await api.getUsersIFollow();
      if (following == null || following.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final widgetData = <Map<String, dynamic>>[];

      // Get recent achievements from first few followed users
      for (final user in following.take(5)) {
        if (user is! Map) continue;
        final friendUsername = user['User']?.toString();
        if (friendUsername == null) continue;

        final friendAchievements = await api.getRecentAchievements(friendUsername, count: 3);
        if (friendAchievements == null || friendAchievements.isEmpty) continue;

        for (final ach in friendAchievements.take(1)) {
          if (ach is! Map) continue;

          // Parse timestamp
          final dateStr = ach['Date']?.toString() ?? ach['DateEarned']?.toString() ?? '';
          String timestamp = '';
          if (dateStr.isNotEmpty) {
            try {
              final date = DateTime.parse(dateStr);
              final now = DateTime.now();
              final diff = now.difference(date);
              if (diff.inMinutes < 60) {
                timestamp = '${diff.inMinutes}m';
              } else if (diff.inHours < 24) {
                timestamp = '${diff.inHours}h';
              } else {
                timestamp = '${diff.inDays}d';
              }
            } catch (_) {}
          }

          widgetData.add({
            'username': friendUsername,
            'userAvatar': user['UserPic']?.toString() ?? '/UserPic/$friendUsername.png',
            'achievementTitle': ach['Title']?.toString() ?? 'Achievement',
            'gameTitle': ach['GameTitle']?.toString() ?? 'Unknown Game',
            'timestamp': timestamp,
            'achievementIcon': ach['BadgeName'] != null
                ? '/Badge/${ach['BadgeName']}.png'
                : '',
            'gameIcon': ach['GameIcon']?.toString() ?? '',
          });
        }

        if (widgetData.length >= 3) break;

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 200));
      }

      await prefs.setString('widget_friend_activity', jsonEncode(widgetData));
    } catch (e) {
      // Silently fail
    }
  }
}
