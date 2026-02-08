import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

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

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

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
    // Handle notification tap - could navigate to streaks screen
    // This would require passing context or using a navigation key
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
  Future<void> scheduleEveningReminder(int currentStreak) async {
    if (currentStreak == 0) return;

    // Schedule for 7 PM local time
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      19, // 7 PM
      0,
    );

    // If it's already past 7 PM, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      streakReminderNotificationId,
      'Don\'t Forget Your Streak! 🔥',
      'You have a $currentStreak-day streak. Play today to keep it going!',
      scheduledDate,
      _getNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
