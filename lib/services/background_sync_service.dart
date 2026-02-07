import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

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

    if (currentStreak > 0) {
      final notificationService = NotificationService();
      await notificationService.initialize();
      await notificationService.scheduleEveningReminder(currentStreak);
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

    // Get stored credentials
    final username = prefs.getString('ra_username');
    final apiKey = prefs.getString('ra_api_key');

    if (username == null || apiKey == null) return;

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

      // Show daily summary if user earned achievements today (once per day)
      final dailySummaryEnabled = prefs.getBool('daily_summary_enabled') ?? true;
      if (dailySummaryEnabled && achievementsToday > 0) {
        final lastSummaryDate = prefs.getString('last_summary_date');
        if (lastSummaryDate != todayStr) {
          await notificationService.showDailySummaryNotification(
            achievementsToday: achievementsToday,
            currentStreak: currentStreak,
          );
          await prefs.setString('last_summary_date', todayStr);
        }
      }

      // Schedule evening reminder if user has a streak but hasn't played today
      final reminderEnabled = prefs.getBool('streak_reminder_enabled') ?? true;
      if (reminderEnabled && currentStreak > 0 && !hasActivityToday) {
        await notificationService.scheduleEveningReminder(currentStreak);
      }

      // Save current streak for next comparison
      await prefs.setInt('last_known_streak', currentStreak);
      await prefs.setString('last_streak_check_date', todayStr);
      await prefs.setInt('last_streak_check_time', now);

    } catch (e) {
      // Silently fail - we'll try again next time
    }
  }
}
