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

  // Notification channel IDs
  static const String _streakChannelId = 'streak_notifications';
  static const String _streakChannelName = 'Streak Notifications';
  static const String _streakChannelDesc = 'Notifications about your achievement streaks';

  // Notification IDs
  static const int streakReminderNotificationId = 1;
  static const int streakMilestoneNotificationId = 2;
  static const int streakBrokenNotificationId = 3;
  static const int dailySummaryNotificationId = 4;
  static const int aotwNotificationId = 5;
  static const int aotmNotificationId = 6;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();

    // Get the device's local timezone and set it
    try {
      final String timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (e) {
      // Fallback to UTC if timezone detection fails
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    _initialized = true;
  }

  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _streakChannelId,
      _streakChannelName,
      description: _streakChannelDesc,
      importance: Importance.high,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
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
      if (areEnabled == true) {
        return true;
      }

      // Request permission
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
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

  // Show streak at risk notification
  Future<void> showStreakAtRiskNotification(int currentStreak) async {
    await _notifications.show(
      streakReminderNotificationId,
      'Keep Your Streak Alive! 🔥',
      'Play today to maintain your $currentStreak-day streak!',
      _getNotificationDetails(),
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
      streakMilestoneNotificationId,
      '$streak-Day Streak! $emoji',
      message,
      _getNotificationDetails(),
    );
  }

  // Show streak broken notification
  Future<void> showStreakBrokenNotification(int lostStreak) async {
    await _notifications.show(
      streakBrokenNotificationId,
      'Streak Ended 😢',
      'Your $lostStreak-day streak has ended. Start a new one today!',
      _getNotificationDetails(),
    );
  }

  // Show daily summary notification
  Future<void> showDailySummaryNotification({
    required int achievementsToday,
    required int currentStreak,
  }) async {
    if (achievementsToday == 0) return;

    await _notifications.show(
      dailySummaryNotificationId,
      'Today\'s Progress 🎮',
      'You earned $achievementsToday achievement${achievementsToday == 1 ? '' : 's'} today! '
          '${currentStreak > 0 ? 'Streak: $currentStreak days 🔥' : ''}',
      _getNotificationDetails(),
    );
  }

  // Schedule evening reminder
  Future<void> scheduleEveningReminder(int currentStreak, {int hour = 19, int minute = 0}) async {
    if (currentStreak == 0) return;

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

    await _notifications.zonedSchedule(
      streakReminderNotificationId,
      'Don\'t Forget Your Streak! 🔥',
      'You have a $currentStreak-day streak. Play today to keep it going!',
      scheduledDate,
      _getNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Send test notification immediately
  Future<void> sendTestNotification() async {
    await _notifications.show(
      streakReminderNotificationId,
      'Test Notification 🔔',
      'Your streak reminder notifications are working!',
      _getNotificationDetails(),
    );
  }

  // Schedule notification for X seconds from now (for testing)
  Future<void> scheduleTestInSeconds(int seconds) async {
    await cancel(streakReminderNotificationId);

    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

    await _notifications.zonedSchedule(
      streakReminderNotificationId,
      'Scheduled Test 🔔',
      'This notification was scheduled $seconds seconds ago!',
      scheduledDate,
      _getNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Check pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  // Check if exact alarms are permitted (Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.canScheduleExactNotifications() ?? false;
    }
    return true;
  }

  // Request exact alarm permission (Android 12+)
  Future<bool> requestExactAlarmPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestExactAlarmsPermission() ?? false;
    }
    return true;
  }

  // Schedule a test notification at specific time (for testing)
  Future<DateTime> scheduleTestAtTime(int hour, int minute) async {
    await cancel(streakReminderNotificationId);

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
    if (scheduledDate.isBefore(now) || scheduledDate.difference(now).inSeconds < 30) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      streakReminderNotificationId,
      'Streak Reminder Test 🔥',
      'This is your scheduled reminder test!',
      scheduledDate,
      _getNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    return scheduledDate;
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
      dailySummaryNotificationId,
      'Today\'s Progress 🎮',
      message,
      scheduledDate,
      _getNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  // Cancel specific notification
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  // Show Achievement of the Week notification
  Future<void> showAotwNotification(String achievementTitle, String gameTitle) async {
    await _notifications.show(
      aotwNotificationId,
      'New Achievement of the Week! 🏆',
      '$achievementTitle from $gameTitle',
      _getNotificationDetails(),
      payload: 'aotw',
    );
  }

  // Show Achievement of the Month notification
  Future<void> showAotmNotification(String achievementTitle, String gameTitle) async {
    await _notifications.show(
      aotmNotificationId,
      'New Achievement of the Month! 📅',
      '$achievementTitle from $gameTitle',
      _getNotificationDetails(),
      payload: 'aotm',
    );
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
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
