import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/background_sync_service.dart';
import '../../../services/notification_service.dart';

/// Available accent colors for the app
enum AccentColor {
  blue('Blue', Colors.blue),
  teal('Teal', Colors.teal),
  cyan('Cyan', Colors.cyan),
  green('Green', Colors.green),
  orange('Orange', Colors.orange),
  amber('Amber', Colors.amber),
  red('Red', Colors.red),
  pink('Pink', Colors.pink),
  purple('Purple', Colors.deepPurple),
  indigo('Indigo', Colors.indigo);

  final String label;
  final Color color;

  const AccentColor(this.label, this.color);
}

class AccentColorNotifier extends Notifier<AccentColor> {
  @override
  AccentColor build() {
    _loadAccentColor();
    return AccentColor.blue;
  }

  Future<void> _loadAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorName = prefs.getString('accent_color') ?? 'blue';
    state = AccentColor.values.firstWhere(
      (c) => c.name == colorName,
      orElse: () => AccentColor.blue,
    );
  }

  Future<void> setAccentColor(AccentColor color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accent_color', color.name);
    state = color;
  }
}

final accentColorProvider = NotifierProvider<AccentColorNotifier, AccentColor>(AccentColorNotifier.new);

class NotificationSettings {
  final bool streakNotificationsEnabled;
  final bool eveningReminderEnabled;
  final bool milestonesEnabled;
  final bool dailySummaryEnabled;
  final bool aotwNotificationsEnabled;
  final bool aotmNotificationsEnabled;
  final int reminderHour;
  final int reminderMinute;

  NotificationSettings({
    this.streakNotificationsEnabled = false,
    this.eveningReminderEnabled = false,
    this.milestonesEnabled = false,
    this.dailySummaryEnabled = false,
    this.aotwNotificationsEnabled = true,
    this.aotmNotificationsEnabled = true,
    this.reminderHour = 19,
    this.reminderMinute = 0,
  });

  String get formattedReminderTime {
    final hour = reminderHour > 12 ? reminderHour - 12 : (reminderHour == 0 ? 12 : reminderHour);
    final ampm = reminderHour >= 12 ? 'PM' : 'AM';
    final min = reminderMinute.toString().padLeft(2, '0');
    return '$hour:$min $ampm';
  }

  NotificationSettings copyWith({
    bool? streakNotificationsEnabled,
    bool? eveningReminderEnabled,
    bool? milestonesEnabled,
    bool? dailySummaryEnabled,
    bool? aotwNotificationsEnabled,
    bool? aotmNotificationsEnabled,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return NotificationSettings(
      streakNotificationsEnabled: streakNotificationsEnabled ?? this.streakNotificationsEnabled,
      eveningReminderEnabled: eveningReminderEnabled ?? this.eveningReminderEnabled,
      milestonesEnabled: milestonesEnabled ?? this.milestonesEnabled,
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
      aotwNotificationsEnabled: aotwNotificationsEnabled ?? this.aotwNotificationsEnabled,
      aotmNotificationsEnabled: aotmNotificationsEnabled ?? this.aotmNotificationsEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() {
    _loadSettings();
    return NotificationSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      streakNotificationsEnabled: prefs.getBool('streak_notifications_enabled') ?? false,
      eveningReminderEnabled: prefs.getBool('streak_reminder_enabled') ?? false,
      milestonesEnabled: prefs.getBool('milestone_notifications_enabled') ?? false,
      dailySummaryEnabled: prefs.getBool('daily_summary_enabled') ?? false,
      aotwNotificationsEnabled: prefs.getBool('aotw_notifications_enabled') ?? true,
      aotmNotificationsEnabled: prefs.getBool('aotm_notifications_enabled') ?? true,
      reminderHour: prefs.getInt('reminder_hour') ?? 19,
      reminderMinute: prefs.getInt('reminder_minute') ?? 0,
    );
  }

  Future<void> setStreakNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('streak_notifications_enabled', enabled);
    state = state.copyWith(streakNotificationsEnabled: enabled);

    final backgroundSync = BackgroundSyncService();
    if (enabled) {
      await backgroundSync.registerPeriodicTasks();
    } else {
      await backgroundSync.cancelAllTasks();
    }
  }

  Future<void> setEveningReminder(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('streak_reminder_enabled', enabled);
    state = state.copyWith(eveningReminderEnabled: enabled);

    final backgroundSync = BackgroundSyncService();
    if (enabled) {
      // Schedule the reminder with current settings
      await backgroundSync.registerPeriodicTasks();
    } else {
      // Cancel the evening reminder notification
      final notificationService = NotificationService();
      await notificationService.cancel(NotificationService.streakReminderNotificationId);
    }
  }

  Future<void> setMilestones(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('milestone_notifications_enabled', enabled);
    state = state.copyWith(milestonesEnabled: enabled);
  }

  Future<void> setDailySummary(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_summary_enabled', enabled);
    state = state.copyWith(dailySummaryEnabled: enabled);
  }

  Future<void> setAotwNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('aotw_notifications_enabled', enabled);
    state = state.copyWith(aotwNotificationsEnabled: enabled);
  }

  Future<void> setAotmNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('aotm_notifications_enabled', enabled);
    state = state.copyWith(aotmNotificationsEnabled: enabled);
  }

  Future<void> setReminderTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_hour', hour);
    await prefs.setInt('reminder_minute', minute);
    state = state.copyWith(reminderHour: hour, reminderMinute: minute);

    // Reschedule the notification with the new time
    final backgroundSync = BackgroundSyncService();
    await backgroundSync.registerPeriodicTasks();
  }
}

final notificationSettingsProvider = NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(NotificationSettingsNotifier.new);
