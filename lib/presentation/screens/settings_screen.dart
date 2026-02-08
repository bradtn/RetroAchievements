import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';
import '../../services/notification_service.dart';
import '../../services/background_sync_service.dart';

const String _appVersion = '1.0.0';
const String _developerEmail = 'your.email@gmail.com'; // TODO: Replace with your email

// Provider for notification settings
final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>((ref) {
  return NotificationSettingsNotifier();
});

class NotificationSettings {
  final bool streakNotificationsEnabled;
  final bool eveningReminderEnabled;
  final bool milestonesEnabled;
  final bool dailySummaryEnabled;

  NotificationSettings({
    this.streakNotificationsEnabled = true,
    this.eveningReminderEnabled = true,
    this.milestonesEnabled = true,
    this.dailySummaryEnabled = true,
  });

  NotificationSettings copyWith({
    bool? streakNotificationsEnabled,
    bool? eveningReminderEnabled,
    bool? milestonesEnabled,
    bool? dailySummaryEnabled,
  }) {
    return NotificationSettings(
      streakNotificationsEnabled: streakNotificationsEnabled ?? this.streakNotificationsEnabled,
      eveningReminderEnabled: eveningReminderEnabled ?? this.eveningReminderEnabled,
      milestonesEnabled: milestonesEnabled ?? this.milestonesEnabled,
      dailySummaryEnabled: dailySummaryEnabled ?? this.dailySummaryEnabled,
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
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final premium = ref.watch(premiumProvider);
    final themeMode = ref.watch(themeProvider);
    final notificationSettings = ref.watch(notificationSettingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: isDark ? null : Colors.white,
        title: Text(
          'Settings',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          listTileTheme: ListTileThemeData(
            textColor: isDark ? Colors.white : Colors.black87,
            iconColor: isDark ? Colors.white70 : Colors.grey.shade700,
            subtitleTextStyle: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        child: ListView(
        children: [
          // Premium Banner (if not premium)
          if (!premium.isPremium)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple.shade700, Colors.deepPurple.shade900],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Remove ads, unlock themes & more!',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _showPremiumSheet(context, ref),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Upgrade for \$4.99'),
                    ),
                  ),
                ],
              ),
            )
          else
            ListTile(
              leading: const Icon(Icons.verified, color: Colors.amber),
              title: Text('Premium Active', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              subtitle: Text('All features unlocked!', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ),

          const Divider(),

          // Appearance
          _SectionTitle('Appearance'),
          ListTile(
            leading: Icon(Icons.palette, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Theme', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text(_themeName(themeMode), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            trailing: premium.isPremium ? null : _ProBadge(),
            onTap: premium.isPremium
                ? () => _showThemeDialog(context, ref, themeMode)
                : () => _showPremiumRequired(context),
          ),

          const Divider(),

          // Notifications
          _SectionTitle('Notifications'),
          SwitchListTile(
            secondary: Icon(Icons.notifications_active, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Streak Notifications', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Get notified about your streaks', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            value: notificationSettings.streakNotificationsEnabled,
            onChanged: (value) async {
              if (value) {
                final granted = await NotificationService().requestPermissions();
                if (!granted) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enable notifications in system settings')),
                    );
                  }
                  return;
                }
              }
              ref.read(notificationSettingsProvider.notifier).setStreakNotifications(value);
            },
          ),
          SwitchListTile(
            secondary: Icon(Icons.access_time, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Evening Reminder', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Remind me at 7 PM if I haven\'t played', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            value: notificationSettings.eveningReminderEnabled,
            onChanged: notificationSettings.streakNotificationsEnabled
                ? (value) => ref.read(notificationSettingsProvider.notifier).setEveningReminder(value)
                : null,
          ),
          SwitchListTile(
            secondary: Icon(Icons.emoji_events, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Milestone Alerts', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Celebrate streak milestones (7, 30, 100 days)', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            value: notificationSettings.milestonesEnabled,
            onChanged: notificationSettings.streakNotificationsEnabled
                ? (value) => ref.read(notificationSettingsProvider.notifier).setMilestones(value)
                : null,
          ),
          SwitchListTile(
            secondary: Icon(Icons.summarize, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Daily Summary', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Show achievements earned today', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            value: notificationSettings.dailySummaryEnabled,
            onChanged: notificationSettings.streakNotificationsEnabled
                ? (value) => ref.read(notificationSettingsProvider.notifier).setDailySummary(value)
                : null,
          ),
          ListTile(
            leading: Icon(Icons.notifications, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Test Notification', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Send a test streak notification', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            onTap: () async {
              final notificationService = NotificationService();
              await notificationService.initialize();

              // Request permission first
              final granted = await notificationService.requestPermissions();

              if (!granted) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please allow notifications in your device settings'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
                return;
              }

              // Show the test notification
              await notificationService.showStreakMilestoneNotification(7);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test notification sent! Check your notification shade.')),
                );
              }
            },
          ),

          const Divider(),

          // Premium Features
          _SectionTitle('Premium Features'),
          _FeatureTile(Icons.block, 'Ad-Free', 'No advertisements', !premium.isPremium),
          _FeatureTile(Icons.analytics, 'Statistics', 'Charts & insights', !premium.isPremium),
          _FeatureTile(Icons.offline_bolt, 'Offline Mode', 'Cache for offline', !premium.isPremium),
          _FeatureTile(Icons.people, 'Multi-Account', 'Switch accounts', !premium.isPremium),

          const Divider(),

          // Account
          _SectionTitle('Account'),
          ListTile(
            leading: Icon(Icons.person, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Logged in as', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text(authState.username ?? 'Unknown', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(context, ref),
          ),

          const Divider(),

          // Support
          _SectionTitle('Support'),
          ListTile(
            leading: Icon(Icons.bug_report_outlined, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Report a Bug', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Something not working right?', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _sendFeedbackEmail(context, 'Bug Report', authState.username),
          ),
          ListTile(
            leading: Icon(Icons.lightbulb_outline, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Request a Feature', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Have an idea? Let me know!', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _sendFeedbackEmail(context, 'Feature Request', authState.username),
          ),
          ListTile(
            leading: Icon(Icons.star_outline, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Rate on Play Store', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Enjoying the app? Leave a review!', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openPlayStore(context),
          ),

          const Divider(),

          // About
          _SectionTitle('About'),
          ListTile(
            leading: Icon(Icons.info, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Version', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text(_appVersion, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),

          const SizedBox(height: 32),
        ],
      ),
      ),
    );
  }

  String _themeName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light: return 'Light';
      case AppThemeMode.dark: return 'Dark';
      case AppThemeMode.amoled: return 'AMOLED Black';
      case AppThemeMode.system: return 'System';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, AppThemeMode current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) => RadioListTile<AppThemeMode>(
            title: Text(_themeName(mode)),
            value: mode,
            groupValue: current,
            onChanged: (v) {
              if (v != null) {
                ref.read(themeProvider.notifier).setTheme(v);
                Navigator.pop(ctx);
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showPremiumRequired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Premium feature - upgrade to unlock!')),
    );
  }

  void _showPremiumSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'RetroTracker Premium',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('One-time purchase. Yours forever.'),
            const SizedBox(height: 24),
            const _CheckItem('Remove all ads'),
            const _CheckItem('Theme customization'),
            const _CheckItem('Advanced statistics'),
            const _CheckItem('Offline mode'),
            const _CheckItem('Multiple accounts'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final success = await ref.read(premiumProvider.notifier).purchasePremium();
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Premium unlocked!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Purchase for \$4.99', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await ref.read(premiumProvider.notifier).restorePurchases();
                if (context.mounted) {
                  Navigator.pop(ctx);
                  final isPremium = ref.read(premiumProvider).isPremium;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isPremium ? 'Purchase restored!' : 'No previous purchase found'),
                      backgroundColor: isPremium ? Colors.green : null,
                    ),
                  );
                }
              },
              child: const Text('Restore Purchase'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Maybe Later'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFeedbackEmail(BuildContext context, String type, String? username) async {
    final String platform = Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : 'Unknown';
    final String osVersion = Platform.operatingSystemVersion;

    final String subject = Uri.encodeComponent('[RetroTracker] $type');
    final String body = Uri.encodeComponent('''
Hi,

[Please describe your $type here]




---
App Info (please don't delete):
- App Version: $_appVersion
- Platform: $platform
- OS Version: $osVersion
- Username: ${username ?? 'Not logged in'}
''');

    final Uri emailUri = Uri.parse('mailto:$_developerEmail?subject=$subject&body=$body');

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open email app. Email me at: $_developerEmail'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _openPlayStore(BuildContext context) async {
    // TODO: Replace with your actual Play Store URL
    const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.retrotracker.retrotracker';
    final Uri uri = Uri.parse(playStoreUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Play Store')),
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ProBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('PRO', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;

  const _FeatureTile(this.icon, this.title, this.subtitle, this.locked);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return ListTile(
      leading: Icon(icon, color: locked ? Colors.grey : Colors.green),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: Text(subtitle, style: TextStyle(color: subtitleColor)),
      trailing: locked
          ? const Icon(Icons.lock, size: 18, color: Colors.grey)
          : const Icon(Icons.check_circle, size: 18, color: Colors.green),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  const _CheckItem(this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          ),
        ],
      ),
    );
  }
}
