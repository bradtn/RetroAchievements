import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'widget_service.dart';

/// Secure storage for credentials
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
  ),
);

class BackgroundSyncService {
  static final BackgroundSyncService _instance = BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  Future<void> initialize() async {
    // No background initialization needed for on-open checks
  }

  Future<void> registerPeriodicTasks() async {
    // Schedule local notification for evening reminder if user has a streak
    final prefs = await SharedPreferences.getInstance();
    final currentStreak = prefs.getInt('last_known_streak') ?? 0;
    final reminderHour = prefs.getInt('reminder_hour') ?? 19;
    final reminderMinute = prefs.getInt('reminder_minute') ?? 0;

    if (currentStreak > 0) {
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.scheduleEveningReminder(
        currentStreak,
        hour: reminderHour,
        minute: reminderMinute,
      );
    }
  }

  Future<void> cancelAllTasks() async {
    final notificationService = NotificationService();
    await notificationService.cancelAll();
  }

  /// Called when app opens - checks streak status and shows relevant notifications
  Future<void> checkStreakOnAppOpen() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if notifications are enabled
    final notificationsEnabled = prefs.getBool('streak_notifications_enabled') ?? true;
    if (!notificationsEnabled) return;

    // Get stored credentials from secure storage
    final username = await _secureStorage.read(key: 'ra_username');
    final apiKey = await _secureStorage.read(key: 'ra_api_key');

    if (username == null || apiKey == null || username.isEmpty || apiKey.isEmpty) return;

    // Get previous streak data
    final previousStreak = prefs.getInt('last_known_streak') ?? 0;
    final lastCheckDate = prefs.getString('last_streak_check_date');

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    // Only check once per app open session, unless it's a new day
    final lastCheckTime = prefs.getInt('last_streak_check_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check at most every 30 minutes unless it's a new day
    if (lastCheckDate == todayStr && now - lastCheckTime < 1800000) return;

    try {
      // Fetch recent achievements
      final dio = Dio(BaseOptions(
        baseUrl: 'https://retroachievements.org/API/',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

      final ninetyDaysAgo = today.subtract(const Duration(days: 90));

      final fromTimestamp = ninetyDaysAgo.millisecondsSinceEpoch ~/ 1000;
      final toTimestamp = now ~/ 1000;

      final response = await dio.get(
        'API_GetAchievementsEarnedBetween.php',
        queryParameters: {
          'z': username,
          'y': apiKey,
          'u': username,
          'f': fromTimestamp,
          't': toTimestamp,
        },
      );

      if (response.statusCode != 200 || response.data == null) return;

      final achievements = response.data as List<dynamic>;

      // Build activity map
      final activityMap = <String, int>{};
      for (final ach in achievements) {
        final dateStr = ach['Date'] ?? ach['DateEarned'] ?? '';
        if (dateStr.isEmpty) continue;
        try {
          final date = DateTime.parse(dateStr);
          final dayKey = '${date.year}-${date.month}-${date.day}';
          activityMap[dayKey] = (activityMap[dayKey] ?? 0) + 1;
        } catch (e) {
          // Skip invalid dates
        }
      }

      // Calculate current streak
      final todayKey = '${today.year}-${today.month}-${today.day}';
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayKey = '${yesterday.year}-${yesterday.month}-${yesterday.day}';

      int currentStreak = 0;
      bool hasActivityToday = activityMap.containsKey(todayKey);

      if (activityMap.containsKey(todayKey) || activityMap.containsKey(yesterdayKey)) {
        DateTime checkDate = activityMap.containsKey(todayKey) ? today : yesterday;
        while (true) {
          final key = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
          if (!activityMap.containsKey(key)) break;
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
      }

      // Get today's achievement count
      final achievementsToday = activityMap[todayKey] ?? 0;

      // Initialize notification service
      final notificationService = NotificationService();
      await notificationService.initialize();

      // Check for streak milestones (only notify once per milestone)
      final milestonesEnabled = prefs.getBool('milestone_notifications_enabled') ?? true;
      final lastMilestoneNotified = prefs.getInt('last_milestone_notified') ?? 0;
      final milestones = [7, 14, 30, 50, 100, 200, 365];

      if (milestonesEnabled && currentStreak > previousStreak) {
        for (final milestone in milestones) {
          if (currentStreak >= milestone && lastMilestoneNotified < milestone) {
            await notificationService.showStreakMilestoneNotification(milestone);
            await prefs.setInt('last_milestone_notified', milestone);
            break;
          }
        }
      }

      // Check if streak was broken (only notify once)
      final streakBrokenNotified = prefs.getBool('streak_broken_notified') ?? false;
      if (previousStreak > 0 && currentStreak == 0 && !hasActivityToday && !streakBrokenNotified) {
        await notificationService.showStreakBrokenNotification(previousStreak);
        await prefs.setBool('streak_broken_notified', true);
      }

      // Reset streak broken flag if user starts a new streak
      if (currentStreak > 0 && streakBrokenNotified) {
        await prefs.setBool('streak_broken_notified', false);
        await prefs.setInt('last_milestone_notified', 0);
      }

      // Schedule daily summary for 9 PM if user earned achievements today
      final dailySummaryEnabled = prefs.getBool('daily_summary_enabled') ?? true;
      if (dailySummaryEnabled && achievementsToday > 0) {
        final lastSummaryDate = prefs.getString('last_summary_date');
        if (lastSummaryDate != todayStr) {
          await notificationService.scheduleDailySummaryNotification(
            achievementsToday: achievementsToday,
            currentStreak: currentStreak,
          );
          await prefs.setString('last_summary_date', todayStr);
        }
      }

      // Schedule evening reminder if user has a streak but hasn't played today
      final reminderEnabled = prefs.getBool('streak_reminder_enabled') ?? true;
      if (reminderEnabled && currentStreak > 0 && !hasActivityToday) {
        final reminderHour = prefs.getInt('reminder_hour') ?? 19;
        final reminderMinute = prefs.getInt('reminder_minute') ?? 0;
        await notificationService.scheduleEveningReminder(
          currentStreak,
          hour: reminderHour,
          minute: reminderMinute,
        );
      }

      // Save current streak for next comparison
      await prefs.setInt('last_known_streak', currentStreak);
      await prefs.setString('last_streak_check_date', todayStr);
      await prefs.setInt('last_streak_check_time', now);

    } catch (e) {
      // Silently fail - we'll try again next time
    }
  }

  /// Check for new Achievement of the Week
  Future<void> checkAotwOnAppOpen() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if AOTW notifications are enabled
    final aotwNotificationsEnabled = prefs.getBool('aotw_notifications_enabled') ?? true;
    if (!aotwNotificationsEnabled) return;

    // Get stored credentials from secure storage
    final username = await _secureStorage.read(key: 'ra_username');
    final apiKey = await _secureStorage.read(key: 'ra_api_key');

    if (username == null || apiKey == null || username.isEmpty || apiKey.isEmpty) return;

    // Only check once per day
    final lastCheckDate = prefs.getString('last_aotw_check_date');
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    if (lastCheckDate == todayStr) return;

    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://retroachievements.org/API/',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ));

      final response = await dio.get(
        'API_GetAchievementOfTheWeek.php',
        queryParameters: {
          'z': username,
          'y': apiKey,
        },
      );

      if (response.statusCode != 200 || response.data == null) return;

      final data = response.data as Map<String, dynamic>;
      final achievement = data['Achievement'] as Map<String, dynamic>?;
      final game = data['Game'] as Map<String, dynamic>?;

      if (achievement == null || game == null) return;

      final achievementId = achievement['ID']?.toString() ?? '';
      final achievementTitle = achievement['Title'] ?? 'New Achievement';
      final gameTitle = game['Title'] ?? 'Unknown Game';

      // Check if this is a new AOTW
      final lastKnownAotwId = prefs.getString('last_known_aotw_id') ?? '';

      if (lastKnownAotwId.isNotEmpty && lastKnownAotwId != achievementId) {
        // New AOTW! Send notification
        final notificationService = NotificationService();
        await notificationService.initialize();
        await notificationService.showAotwNotification(achievementTitle, gameTitle);
      }

      // Save current AOTW ID
      await prefs.setString('last_known_aotw_id', achievementId);
      await prefs.setString('last_aotw_check_date', todayStr);

    } catch (e) {
      // Silently fail
    }
  }

  /// Check for new Achievement of the Month
  Future<void> checkAotmOnAppOpen() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if AotM notifications are enabled
    final aotmNotificationsEnabled = prefs.getBool('aotm_notifications_enabled') ?? true;
    if (!aotmNotificationsEnabled) return;

    // Only check once per day
    final lastCheckDate = prefs.getString('last_aotm_check_date');
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';

    if (lastCheckDate == todayStr) return;

    try {
      // Fetch AotM data from GitHub
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.plain,
      ));

      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final response = await dio.get(
        'https://raw.githubusercontent.com/bradtn/RetroAchievements/master/aotm.json?cb=$cacheBuster',
      );

      if (response.statusCode != 200 || response.data == null) return;

      final jsonString = response.data.toString();
      final decoded = jsonDecode(jsonString);
      if (decoded is! List || decoded.isEmpty) return;

      // Find current AotM by date
      final now = DateTime.now().toUtc();
      Map<String, dynamic>? currentAotm;

      for (final aotm in decoded) {
        if (aotm is Map<String, dynamic>) {
          final startStr = aotm['achievementDateStart'] as String?;
          final endStr = aotm['achievementDateEnd'] as String?;
          if (startStr != null && endStr != null) {
            try {
              final start = DateTime.parse(startStr);
              final end = DateTime.parse(endStr);
              if (now.isAfter(start) && now.isBefore(end)) {
                currentAotm = aotm;
                break;
              }
            } catch (_) {}
          }
        }
      }

      // Fallback to last entry if no current one found
      if (currentAotm == null && decoded.isNotEmpty) {
        currentAotm = decoded.last as Map<String, dynamic>?;
      }

      if (currentAotm == null) return;

      final achievementId = currentAotm['achievementId']?.toString() ?? '';
      final achievementTitle = currentAotm['achievementTitle'] ?? 'New Achievement';
      final gameTitle = currentAotm['gameTitle'] ?? 'Unknown Game';

      // Check if this is a new AotM
      final lastKnownAotmId = prefs.getString('last_known_aotm_id') ?? '';

      if (lastKnownAotmId.isNotEmpty && lastKnownAotmId != achievementId) {
        // New AotM! Send notification
        final notificationService = NotificationService();
        await notificationService.initialize();
        await notificationService.showAotmNotification(achievementTitle, gameTitle);
      }

      // Save current AotM ID
      await prefs.setString('last_known_aotm_id', achievementId);
      await prefs.setString('last_aotm_check_date', todayStr);

    } catch (e) {
      // Silently fail
    }
  }

  /// Sync all widget data on app open
  Future<void> syncWidgetDataOnAppOpen() async {
    final prefs = await SharedPreferences.getInstance();

    // Get stored credentials from secure storage
    final username = await _secureStorage.read(key: 'ra_username');
    final apiKey = await _secureStorage.read(key: 'ra_api_key');

    if (username == null || apiKey == null || username.isEmpty || apiKey.isEmpty) return;

    // Check if this is first sync (no cached widget data) - always sync if so
    final hasWidgetData = prefs.getString('widget_recent_achievements') != null;

    // Check if enough time has passed since last sync (30 minutes minimum)
    final lastSyncTime = prefs.getInt('last_widget_sync_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Skip if we have data AND less than 30 minutes have passed
    if (hasWidgetData && now - lastSyncTime < 1800000) return;

    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://retroachievements.org/API/',
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      ));

      // Sync recent achievements
      await _syncRecentAchievementsWidget(dio, username, apiKey, prefs);

      // Sync streak data
      await _syncStreakWidget(dio, username, apiKey, prefs);

      // Sync AOTW
      await _syncAotwWidget(dio, username, apiKey, prefs);

      // Sync friend activity
      await _syncFriendActivityWidget(dio, username, apiKey, prefs);

      // Update all widgets (Android)
      await WidgetService.updateAllWidgets();

      // Reload iOS widget timelines
      if (Platform.isIOS) {
        await WidgetService.reloadIOSWidgets();
      }

      await prefs.setInt('last_widget_sync_time', now);
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _syncRecentAchievementsWidget(
    Dio dio,
    String username,
    String apiKey,
    SharedPreferences prefs,
  ) async {
    try {
      final response = await dio.get(
        'API_GetUserSummary.php',
        queryParameters: {
          'z': username,
          'y': apiKey,
          'u': username,
          'g': 5,
          'a': 10,
        },
      );

      if (response.statusCode != 200 || response.data == null) return;

      final data = response.data as Map<String, dynamic>;
      final recentAch = data['RecentAchievements'];
      List<dynamic> achievements = [];

      if (recentAch is List) {
        achievements = recentAch;
      } else if (recentAch is Map) {
        achievements = recentAch.values.toList();
      }

      // Flatten if nested
      if (achievements.isNotEmpty && achievements.first is Map) {
        final first = achievements.first as Map;
        if (first.values.isNotEmpty && first.values.first is Map) {
          achievements = first.values.map((v) => v as Map<String, dynamic>).toList();
        }
      }

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

      final jsonData = jsonEncode(widgetData);
      await prefs.setString('widget_recent_achievements', jsonData);

      // Also write to iOS App Group
      if (Platform.isIOS) {
        await WidgetService.writeToAppGroup('widget_recent_achievements', jsonData);
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _syncStreakWidget(
    Dio dio,
    String username,
    String apiKey,
    SharedPreferences prefs,
  ) async {
    try {
      // First try cached values
      var currentStreak = prefs.getInt('last_known_streak') ?? 0;
      var bestStreak = prefs.getInt('best_known_streak') ?? 0;

      // If no cached streak, calculate from API
      if (currentStreak == 0) {
        final today = DateTime.now();
        final ninetyDaysAgo = today.subtract(const Duration(days: 90));
        final fromTimestamp = ninetyDaysAgo.millisecondsSinceEpoch ~/ 1000;
        final toTimestamp = today.millisecondsSinceEpoch ~/ 1000;

        final response = await dio.get(
          'API_GetAchievementsEarnedBetween.php',
          queryParameters: {
            'z': username,
            'y': apiKey,
            'u': username,
            'f': fromTimestamp,
            't': toTimestamp,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final achievements = response.data as List<dynamic>;
          final activityMap = <String, int>{};

          for (final ach in achievements) {
            final dateStr = ach['Date'] ?? ach['DateEarned'] ?? '';
            if (dateStr.toString().isEmpty) continue;
            try {
              final date = DateTime.parse(dateStr.toString());
              final dayKey = '${date.year}-${date.month}-${date.day}';
              activityMap[dayKey] = (activityMap[dayKey] ?? 0) + 1;
            } catch (e) {
              continue;
            }
          }

          // Calculate current streak
          final todayKey = '${today.year}-${today.month}-${today.day}';
          final yesterday = today.subtract(const Duration(days: 1));
          final yesterdayKey = '${yesterday.year}-${yesterday.month}-${yesterday.day}';

          if (activityMap.containsKey(todayKey) || activityMap.containsKey(yesterdayKey)) {
            DateTime checkDate = activityMap.containsKey(todayKey) ? today : yesterday;
            while (true) {
              final key = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
              if (!activityMap.containsKey(key)) break;
              currentStreak++;
              checkDate = checkDate.subtract(const Duration(days: 1));
            }
          }

          // Calculate best streak
          final sortedDates = activityMap.keys.map((k) {
            final parts = k.split('-');
            return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          }).toList()..sort((a, b) => b.compareTo(a));

          int tempStreak = 1;
          bestStreak = currentStreak;
          for (int i = 1; i < sortedDates.length; i++) {
            final diff = sortedDates[i - 1].difference(sortedDates[i]).inDays;
            if (diff == 1) {
              tempStreak++;
              if (tempStreak > bestStreak) bestStreak = tempStreak;
            } else if (diff > 1) {
              tempStreak = 1;
            }
          }

          // Cache for next time
          await prefs.setInt('last_known_streak', currentStreak);
          await prefs.setInt('best_known_streak', bestStreak);
        }
      }

      await prefs.setInt('widget_current_streak', currentStreak);
      final bestStreakValue = bestStreak > 0 ? bestStreak : currentStreak;
      await prefs.setInt('widget_best_streak', bestStreakValue);

      // Also write to iOS App Group
      if (Platform.isIOS) {
        await WidgetService.writeMultipleToAppGroup({
          'widget_current_streak': currentStreak,
          'widget_best_streak': bestStreakValue,
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _syncAotwWidget(
    Dio dio,
    String username,
    String apiKey,
    SharedPreferences prefs,
  ) async {
    try {
      final response = await dio.get(
        'API_GetAchievementOfTheWeek.php',
        queryParameters: {
          'z': username,
          'y': apiKey,
        },
      );

      if (response.statusCode != 200 || response.data == null) return;

      final data = response.data as Map<String, dynamic>;
      final achievement = data['Achievement'] as Map<String, dynamic>?;
      final game = data['Game'] as Map<String, dynamic>?;
      final console = data['Console'] as Map<String, dynamic>?;

      final aotwTitle = achievement?['Title']?.toString() ?? '';
      final aotwGame = game?['Title']?.toString() ?? '';
      final aotwConsole = console?['Name']?.toString() ?? '';
      final aotwPoints = achievement?['Points'] ?? 0;
      final aotwGameId = game?['ID'] ?? 0;
      final badgeName = achievement?['BadgeName']?.toString() ?? '';
      final aotwAchievementIcon = badgeName.isNotEmpty ? '/Badge/$badgeName.png' : '';
      final aotwGameIcon = game?['ImageIcon']?.toString() ?? '';

      await prefs.setString('widget_aotw_title', aotwTitle);
      await prefs.setString('widget_aotw_game', aotwGame);
      await prefs.setString('widget_aotw_console', aotwConsole);
      await prefs.setInt('widget_aotw_points', aotwPoints);
      await prefs.setInt('widget_aotw_game_id', aotwGameId);
      await prefs.setString('widget_aotw_achievement_icon', aotwAchievementIcon);
      await prefs.setString('widget_aotw_game_icon', aotwGameIcon);

      // Also write to iOS App Group
      if (Platform.isIOS) {
        await WidgetService.writeMultipleToAppGroup({
          'widget_aotw_title': aotwTitle,
          'widget_aotw_game': aotwGame,
          'widget_aotw_console': aotwConsole,
          'widget_aotw_points': aotwPoints,
          'widget_aotw_game_id': aotwGameId,
          'widget_aotw_achievement_icon': aotwAchievementIcon,
          'widget_aotw_game_icon': aotwGameIcon,
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _syncFriendActivityWidget(
    Dio dio,
    String username,
    String apiKey,
    SharedPreferences prefs,
  ) async {
    try {
      final response = await dio.get(
        'API_GetUsersIFollow.php',
        queryParameters: {
          'z': username,
          'y': apiKey,
        },
      );

      if (response.statusCode != 200 || response.data == null) return;

      final following = response.data as List<dynamic>;
      if (following.isEmpty) return;

      final widgetData = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (final user in following.take(5)) {
        if (user is! Map) continue;
        final friendUsername = user['User']?.toString();
        if (friendUsername == null) continue;

        try {
          final friendResponse = await dio.get(
            'API_GetUserSummary.php',
            queryParameters: {
              'z': username,
              'y': apiKey,
              'u': friendUsername,
              'g': 1,
              'a': 3,
            },
          );

          if (friendResponse.statusCode != 200 || friendResponse.data == null) continue;

          final friendData = friendResponse.data as Map<String, dynamic>;
          final recentAch = friendData['RecentAchievements'];
          List<dynamic> achievements = [];

          if (recentAch is List) {
            achievements = recentAch;
          } else if (recentAch is Map) {
            achievements = recentAch.values.toList();
          }

          if (achievements.isNotEmpty && achievements.first is Map) {
            final first = achievements.first as Map;
            if (first.values.isNotEmpty && first.values.first is Map) {
              achievements = first.values.map((v) => v as Map<String, dynamic>).toList();
            }
          }

          for (final ach in achievements.take(1)) {
            if (ach is! Map) continue;

            final dateStr = ach['Date']?.toString() ?? ach['DateEarned']?.toString() ?? '';
            String timestamp = '';
            if (dateStr.isNotEmpty) {
              try {
                final date = DateTime.parse(dateStr);
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

          // Rate limiting
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          continue;
        }
      }

      final jsonData = jsonEncode(widgetData);
      await prefs.setString('widget_friend_activity', jsonData);

      // Also write to iOS App Group
      if (Platform.isIOS) {
        await WidgetService.writeToAppGroup('widget_friend_activity', jsonData);
      }
    } catch (e) {
      // Silently fail
    }
  }
}
