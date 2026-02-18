import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Global navigator key for navigation from notifications
  static GlobalKey<NavigatorState>? navigatorKey;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Notification channel ID
  static const String _streakChannelId = 'streak_notifications_v2';
  static const String _streakChannelName = 'Streak Notifications';
  static const String _streakChannelDesc = 'Notifications about your achievement streaks';

  // Notification IDs
  static const int streakReminderNotificationId = 1;
  static const int streakMilestoneNotificationId = 2;
  static const int streakBrokenNotificationId = 3;
  static const int dailySummaryNotificationId = 4;
  static const int aotwNotificationId = 5;
  static const int aotmNotificationId = 6;
  static const int aotwReminderNotificationId = 7;
  static const int aotmReminderNotificationId = 8;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();

    // Get the device's local timezone and set it
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      // Fallback to UTC if timezone detection fails
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings - include foreground presentation options
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // Show notifications even when app is in foreground
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      defaultPresentBanner: true,
      defaultPresentList: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    // Request permissions on first launch
    await requestPermissions();

    _initialized = true;
  }

  Future<void> _createNotificationChannel() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      // Delete old channel (sound can't be changed once created)
      await android.deleteNotificationChannel(channelId: 'streak_notifications');

      // Create new channel with custom sound
      const androidChannel = AndroidNotificationChannel(
        _streakChannelId,
        _streakChannelName,
        description: _streakChannelDesc,
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('achievement_unlock'),
      );

      await android.createNotificationChannel(androidChannel);
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || navigatorKey?.currentState == null) return;

    // Delay slightly to ensure app is ready
    Future.delayed(const Duration(milliseconds: 300), () {
      if (payload == 'aotw') {
        navigatorKey?.currentState?.pushNamed('/aotw');
      } else if (payload == 'aotm') {
        navigatorKey?.currentState?.pushNamed('/aotm');
      }
    });
  }

  Future<bool> requestPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      // Check if already granted
      final areEnabled = await android.areNotificationsEnabled();
      if (areEnabled != true) {
        // Request notification permission
        await android.requestNotificationsPermission();
      }

      // Check and request exact alarm permission (required for scheduled notifications on Android 12+)
      final canScheduleExact = await android.canScheduleExactNotifications();
      if (canScheduleExact != true) {
        await android.requestExactAlarmsPermission();
      }

      return true;
    }

    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    // Default to true for platforms that don't require permission
    return true;
  }

  /// Check if exact alarms can be scheduled (Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.canScheduleExactNotifications() ?? false;
    }
    return true;
  }

  /// Request exact alarm permission (opens Android settings on Android 12+)
  Future<void> requestExactAlarmPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestExactAlarmsPermission();
    }
  }

  // Show streak at risk notification
  Future<void> showStreakAtRiskNotification(int currentStreak) async {
    await _notifications.show(
      id: streakReminderNotificationId,
      title: 'Keep Your Streak Alive! 🔥',
      body: 'Play today to maintain your $currentStreak-day streak!',
      notificationDetails: _getNotificationDetails(),
    );
  }

  // Show streak milestone notification
  Future<void> showStreakMilestoneNotification(int streak) async {
    String message;
    String emoji;

    if (streak == 7) {
      message = 'One week strong! Keep it up!';
      emoji = '🎯';
    } else if (streak == 14) {
      message = 'Two weeks of dedication!';
      emoji = '💪';
    } else if (streak == 30) {
      message = 'A whole month! You\'re on fire!';
      emoji = '🏆';
    } else if (streak == 100) {
      message = 'LEGENDARY! 100 days!';
      emoji = '👑';
    } else if (streak == 365) {
      message = 'ONE YEAR STREAK! Incredible!';
      emoji = '🌟';
    } else {
      message = 'Amazing consistency!';
      emoji = '⭐';
    }

    await _notifications.show(
      id: streakMilestoneNotificationId,
      title: '$streak-Day Streak! $emoji',
      body: message,
      notificationDetails: _getNotificationDetails(),
    );
  }

  // Show streak broken notification
  Future<void> showStreakBrokenNotification(int lostStreak) async {
    await _notifications.show(
      id: streakBrokenNotificationId,
      title: 'Streak Ended 😢',
      body: 'Your $lostStreak-day streak has ended. Start a new one today!',
      notificationDetails: _getNotificationDetails(),
    );
  }

  // Show daily summary notification
  Future<void> showDailySummaryNotification({
    required int achievementsToday,
    required int currentStreak,
  }) async {
    if (achievementsToday == 0) return;

    await _notifications.show(
      id: dailySummaryNotificationId,
      title: 'Today\'s Progress 🎮',
      body: 'You earned $achievementsToday achievement${achievementsToday == 1 ? '' : 's'} today! '
          '${currentStreak > 0 ? 'Streak: $currentStreak days 🔥' : ''}',
      notificationDetails: _getNotificationDetails(),
    );
  }

  // Schedule evening reminder - works with or without an active streak
  Future<DateTime?> scheduleEveningReminder(int currentStreak, {int hour = 19, int minute = 0}) async {
    // Ensure initialized
    if (!_initialized) {
      await initialize();
    }

    // Cancel any existing reminder first
    await cancel(streakReminderNotificationId);

    // Schedule for the configured time
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If it's already past the scheduled time, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Different message based on streak status
    final String title;
    final String body;
    if (currentStreak > 0) {
      title = 'Don\'t Forget Your Streak! 🔥';
      body = 'You have a $currentStreak-day streak. Play today to keep it going!';
    } else {
      title = 'Time to Play! 🎮';
      body = 'Start a new streak today - earn an achievement!';
    }

    try {
      await _notifications.zonedSchedule(
        id: streakReminderNotificationId,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: _getNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      return scheduledDate;
    } catch (e) {
      return null;
    }
  }

  // Schedule daily summary for 9 PM
  Future<void> scheduleDailySummaryNotification({
    required int achievementsToday,
    required int currentStreak,
  }) async {
    if (achievementsToday == 0) return;

    // Schedule for 9 PM local time
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      21, // 9 PM
      0,
    );

    // If it's already past 9 PM, don't schedule (too late for today)
    if (scheduledDate.isBefore(now)) return;

    final message = 'You earned $achievementsToday achievement${achievementsToday == 1 ? '' : 's'} today! '
        '${currentStreak > 0 ? 'Streak: $currentStreak days 🔥' : ''}';

    await _notifications.zonedSchedule(
      id: dailySummaryNotificationId,
      title: 'Today\'s Progress 🎮',
      body: message,
      scheduledDate: scheduledDate,
      notificationDetails: _getNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // Cancel specific notification
  Future<void> cancel(int id) async {
    await _notifications.cancel(id: id);
  }

  // Show Achievement of the Week notification
  Future<void> showAotwNotification(String achievementTitle, String gameTitle) async {
    await _notifications.show(
      id: aotwNotificationId,
      title: 'New Achievement of the Week! 🏆',
      body: '$achievementTitle from $gameTitle',
      notificationDetails: _getNotificationDetails(),
      payload: 'aotw',
    );
  }

  // Show Achievement of the Month notification
  Future<void> showAotmNotification(String achievementTitle, String gameTitle) async {
    await _notifications.show(
      id: aotmNotificationId,
      title: 'New Achievement of the Month! 📅',
      body: '$achievementTitle from $gameTitle',
      notificationDetails: _getNotificationDetails(),
      payload: 'aotm',
    );
  }

  /// Schedule weekly AOTW reminder (every Monday at 10 AM)
  Future<void> scheduleAotwWeeklyReminder() async {
    if (!_initialized) await initialize();

    // Cancel any existing reminder
    await cancel(aotwReminderNotificationId);

    // Find next Monday at 10 AM
    final now = tz.TZDateTime.now(tz.local);
    var nextMonday = now;

    // Find next Monday
    while (nextMonday.weekday != DateTime.monday) {
      nextMonday = nextMonday.add(const Duration(days: 1));
    }

    // Set to 10 AM
    nextMonday = tz.TZDateTime(
      tz.local,
      nextMonday.year,
      nextMonday.month,
      nextMonday.day,
      10,
      0,
    );

    // If it's already past 10 AM on Monday, schedule for next Monday
    if (nextMonday.isBefore(now)) {
      nextMonday = nextMonday.add(const Duration(days: 7));
    }

    try {
      await _notifications.zonedSchedule(
        id: aotwReminderNotificationId,
        title: 'New Achievement of the Week!',
        body: 'Check out this week\'s featured achievement challenge!',
        scheduledDate: nextMonday,
        notificationDetails: _getNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'aotw',
      );
    } catch (e) {
      // Silently fail
    }
  }

  /// Cancel AOTW weekly reminder
  Future<void> cancelAotwWeeklyReminder() async {
    await cancel(aotwReminderNotificationId);
  }

  /// Schedule monthly AOTM reminder (1st of each month at 10 AM)
  Future<void> scheduleAotmMonthlyReminder() async {
    if (!_initialized) await initialize();

    // Cancel any existing reminder
    await cancel(aotmReminderNotificationId);

    // Find 1st of next month at 10 AM
    final now = tz.TZDateTime.now(tz.local);
    var nextFirst = tz.TZDateTime(
      tz.local,
      now.month == 12 ? now.year + 1 : now.year,
      now.month == 12 ? 1 : now.month + 1,
      1,
      10,
      0,
    );

    // If we're on the 1st and it's before 10 AM, use today
    if (now.day == 1 && now.hour < 10) {
      nextFirst = tz.TZDateTime(tz.local, now.year, now.month, 1, 10, 0);
    }

    try {
      await _notifications.zonedSchedule(
        id: aotmReminderNotificationId,
        title: 'New Achievement of the Month!',
        body: 'A new monthly achievement challenge is available!',
        scheduledDate: nextFirst,
        notificationDetails: _getNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        payload: 'aotm',
      );
    } catch (e) {
      // Silently fail
    }
  }

  /// Cancel AOTM monthly reminder
  Future<void> cancelAotmMonthlyReminder() async {
    await cancel(aotmReminderNotificationId);
  }

  NotificationDetails _getNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _streakChannelId,
        _streakChannelName,
        channelDescription: _streakChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        sound: RawResourceAndroidNotificationSound('achievement_unlock'),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'achievement_unlock.wav',
      ),
    );
  }
}
