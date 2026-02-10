import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/background_sync_service.dart';

class NotificationSettings {
  final bool streakNotificationsEnabled;
  final bool eveningReminderEnabled;
  final bool milestonesEnabled;
  final bool dailySummaryEnabled;
  final bool aotwNotificationsEnabled;

  NotificationSettings({
    this.streakNotificationsEnabled = true,
    this.eveningReminderEnabled = true,
    this.milestonesEnabled = true,
    this.dailySummaryEnabled = true,
    this.aotwNotificationsEnabled = true,
  });

  NotificationSettings copyWith({
    bool? streakNotificationsEnabled,
    bool? eveningReminderEnabled,
    bool? milestonesEnabled,
    bool? dailySummaryEnabled,
    bool? aotwNotificationsEnabled,
  }) {
    return NotificationSettings(
      streakNotificationsEnabled: streakNotificationsEnabled ?? this.streakNotificationsEnabled,
      eveningReminderEnabled: eveningReminderEnabled ?? this.eveningReminderEnabled,
      milestonesEnabled: milestonesEnabled ?? this.milestonesEnabled,
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
      aotwNotificationsEnabled: aotwNotificationsEnabled ?? this.aotwNotificationsEnabled,
    );
  }
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(NotificationSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      streakNotificationsEnabled: prefs.getBool('streak_notifications_enabled') ?? true,
      eveningReminderEnabled: prefs.getBool('streak_reminder_enabled') ?? true,
      milestonesEnabled: prefs.getBool('milestone_notifications_enabled') ?? true,
      dailySummaryEnabled: prefs.getBool('daily_summary_enabled') ?? true,
      aotwNotificationsEnabled: prefs.getBool('aotw_notifications_enabled') ?? true,
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
}

final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((ref) {
  return NotificationSettingsNotifier();
});
