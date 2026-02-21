import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:confetti/confetti.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';
import '../../services/purchase_service.dart';
import '../../services/sound_service.dart';
import '../../core/animations.dart';
import '../../services/notification_service.dart';
import '../../services/push_notification_service.dart';
import '../../core/services/dual_screen_service.dart';
import 'settings/settings_provider.dart';
import 'settings/settings_widgets.dart';

export 'settings/settings_provider.dart';
export 'settings/settings_widgets.dart';

const String _appVersion = '1.0.0';
const String _developerEmail = 'retrotrackdev@gmail.com';

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
        cacheExtent: 500, // Pre-render items for smoother scrolling
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
              subtitle: Text(
                premium.purchaseDate != null
                    ? 'Purchased ${DateFormat.yMMMd().format(premium.purchaseDate!)}'
                    : 'All features unlocked!',
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),

          const Divider(),

          // Appearance
          const SectionTitle('Appearance'),
          ListTile(
            leading: Icon(Icons.palette, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Theme', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text(_themeName(themeMode), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            trailing: themeMode == AppThemeMode.amoled && !premium.isPremium ? const ProBadge() : null,
            onTap: () => _showThemeDialog(context, ref, themeMode),
          ),
          _AccentColorTile(isDark: isDark, isPremium: premium.isPremium),

          const Divider(),

          // Preferences
          const SectionTitle('Preferences'),
          SwitchListTile(
            secondary: Icon(Icons.vibration, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Haptic Feedback', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Vibration on taps and actions', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            value: Haptics.isEnabled,
            onChanged: (value) async {
              Haptics.setEnabled(value);
              if (value) Haptics.selection(); // Demo the haptic feedback
              // Persist the setting
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('haptics_enabled', value);
              (context as Element).markNeedsBuild();
            },
          ),
          _SoundEffectsTile(isDark: isDark),

          const Divider(),

          // Notifications
          const SectionTitle('Notifications'),
          SwitchListTile(
            secondary: Icon(Icons.notifications_active, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Streak Notifications', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Get notified about your streaks', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            value: notificationSettings.streakNotificationsEnabled,
            onChanged: (value) async {
              HapticFeedback.selectionClick();
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
            title: Text('Daily Reminder', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Remind me at ${notificationSettings.formattedReminderTime} to play', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            value: notificationSettings.eveningReminderEnabled,
            onChanged: notificationSettings.streakNotificationsEnabled
                ? (value) {
                    HapticFeedback.selectionClick();
                    ref.read(notificationSettingsProvider.notifier).setEveningReminder(value);
                  }
                : null,
          ),
          if (notificationSettings.eveningReminderEnabled && notificationSettings.streakNotificationsEnabled)
            Padding(
              padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
              child: OutlinedButton.icon(
                onPressed: () => _showTimePickerDialog(context, ref, notificationSettings),
                icon: const Icon(Icons.schedule, size: 18),
                label: Text('Reminder Time: ${notificationSettings.formattedReminderTime}'),
              ),
            ),
          SwitchListTile(
            secondary: Icon(Icons.emoji_events, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Milestone Alerts', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Celebrate streak milestones (7, 30, 100 days)', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            value: notificationSettings.milestonesEnabled,
            onChanged: notificationSettings.streakNotificationsEnabled
                ? (value) {
                    HapticFeedback.selectionClick();
                    ref.read(notificationSettingsProvider.notifier).setMilestones(value);
                  }
                : null,
          ),
          SwitchListTile(
            secondary: Icon(Icons.summarize, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Daily Summary', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Show achievements earned today', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            value: notificationSettings.dailySummaryEnabled,
            onChanged: notificationSettings.streakNotificationsEnabled
                ? (value) {
                    HapticFeedback.selectionClick();
                    ref.read(notificationSettingsProvider.notifier).setDailySummary(value);
                  }
                : null,
          ),
          SwitchListTile(
            secondary: Icon(Icons.emoji_events, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Achievement of the Week', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Get notified about new weekly challenges', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            value: notificationSettings.aotwNotificationsEnabled,
            onChanged: (value) async {
              HapticFeedback.selectionClick();
              ref.read(notificationSettingsProvider.notifier).setAotwNotifications(value);

              final notificationService = NotificationService();
              final pushService = PushNotificationService();

              if (value) {
                await notificationService.scheduleAotwWeeklyReminder();
                await pushService.subscribeToTopic('aotw_updates');
              } else {
                await notificationService.cancelAotwWeeklyReminder();
                await pushService.unsubscribeFromTopic('aotw_updates');
              }
            },
          ),
          SwitchListTile(
            secondary: Icon(Icons.calendar_month, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Achievement of the Month', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text('Get notified about new monthly challenges', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            value: notificationSettings.aotmNotificationsEnabled,
            onChanged: (value) async {
              HapticFeedback.selectionClick();
              ref.read(notificationSettingsProvider.notifier).setAotmNotifications(value);

              final notificationService = NotificationService();
              final pushService = PushNotificationService();

              if (value) {
                await notificationService.scheduleAotmMonthlyReminder();
                await pushService.subscribeToTopic('aotm_updates');
              } else {
                await notificationService.cancelAotmMonthlyReminder();
                await pushService.unsubscribeFromTopic('aotm_updates');
              }
            },
          ),
          const Divider(),

          // Premium Features
          const SectionTitle('Premium Features'),
          const FeatureTile(Icons.block, 'Ad-Free', 'No advertisements', true),
          const FeatureTile(Icons.palette, 'Theming', 'Custom accent colors', true),
          const FeatureTile(Icons.share, 'Share Cards', 'Share achievements', true),
          const FeatureTile(Icons.local_fire_department, 'Streaks', 'Track your streaks', true),

          const Divider(),

          // Account
          const SectionTitle('Account'),
          ListTile(
            leading: Icon(Icons.person, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text('Logged in as', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text(authState.username ?? 'Unknown', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogoutDialog(context, ref),
          ),

          const Divider(),

          // Support
          const SectionTitle('Support'),
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

          // Dual-Screen (for devices like Ayn Odin)
          const SectionTitle('Dual-Screen'),
          _DualScreenTile(isDark: isDark),

          const Divider(),

          // About
          const SectionTitle('About'),
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
    final isPremium = ref.read(isPremiumProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            final isAmoled = mode == AppThemeMode.amoled;
            final isLocked = isAmoled && !isPremium;

            return RadioListTile<AppThemeMode>(
              title: Row(
                children: [
                  Text(_themeName(mode)),
                  if (isLocked) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.lock, size: 16, color: Colors.grey[500]),
                  ],
                ],
              ),
              value: mode,
              groupValue: current,
              onChanged: isLocked
                  ? null
                  : (v) {
                      if (v != null) {
                        ref.read(themeProvider.notifier).setTheme(v);
                        Navigator.pop(ctx);
                      }
                    },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPremiumSheet(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _PremiumDialogContent(parentContext: context),
    );
  }
}

/// Premium dialog content as a separate stateful widget for confetti
class _PremiumDialogContent extends ConsumerStatefulWidget {
  final BuildContext parentContext;

  const _PremiumDialogContent({required this.parentContext});

  @override
  ConsumerState<_PremiumDialogContent> createState() => _PremiumDialogContentState();
}

class _PremiumDialogContentState extends ConsumerState<_PremiumDialogContent> {
  late ConfettiController _confettiController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _handlePurchase() async {
    setState(() => _isLoading = true);

    final result = await ref.read(premiumProvider.notifier).purchasePremiumWithResult();

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.success) {
      // Play confetti
      _confettiController.play();

      // Wait for confetti then close
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(
            content: Text('Premium unlocked! Enjoy all features.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      // Show specific error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Purchase failed'),
          backgroundColor: result.errorType == PurchaseErrorType.paymentCancelled
              ? null
              : Colors.red,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);

    await ref.read(premiumProvider.notifier).restorePurchases();

    if (!mounted) return;

    setState(() => _isLoading = false);

    final isPremium = ref.read(premiumProvider).isPremium;

    if (isPremium) {
      _confettiController.play();
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(
            content: Text('Purchase restored!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No previous purchase found')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(premiumProvider.notifier);
    final priceString = notifier.priceString;
    final isOnSale = notifier.isOnSale;
    final originalPrice = notifier.originalPrice;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, size: 48, color: Colors.amber),
                ),
                const SizedBox(height: 16),
                const Text(
                  'RetroTrack Premium',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'One-time purchase. Yours forever.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                const CheckItem('Remove all ads'),
                const CheckItem('Theme customization'),
                const CheckItem('Home screen widgets'),
                const CheckItem('AMOLED dark mode'),
                const CheckItem('Share cards'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handlePurchase,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isOnSale && originalPrice != null) ...[
                                Text(
                                  originalPrice,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                'Purchase for $priceString',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : _handleRestore,
                      child: const Text('Restore'),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Maybe Later'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Confetti
          Positioned(
            top: 0,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.amber,
                Colors.orange,
                Colors.purple,
                Colors.blue,
                Colors.green,
              ],
              numberOfParticles: 30,
            ),
          ),
        ],
      ),
    );
  }
}

// Top-level helper functions for settings screen
Future<void> _showTimePickerDialog(BuildContext context, WidgetRef ref, NotificationSettings settings) async {
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Check exact alarm permission first
    final canScheduleExact = await notificationService.canScheduleExactAlarms();
    if (!canScheduleExact && context.mounted) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
            'Scheduled reminders require "Alarms & Reminders" permission.\n\n'
            'Tap "Open Settings" and enable it for RetroTrack.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      if (shouldRequest == true) {
        await notificationService.requestExactAlarmPermission();
      }
      return;
    }

    if (!context.mounted) return;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.reminderHour, minute: settings.reminderMinute),
      helpText: 'Select Reminder Time',
    );
    if (picked != null) {
      await ref.read(notificationSettingsProvider.notifier).setReminderTime(picked.hour, picked.minute);

      // Schedule the reminder at the new time
      final prefs = await SharedPreferences.getInstance();
      final currentStreak = prefs.getInt('last_known_streak') ?? 0;

      final scheduledTime = await notificationService.scheduleEveningReminder(
        currentStreak,
        hour: picked.hour,
        minute: picked.minute,
      );

      if (context.mounted && scheduledTime != null) {
        final hour = scheduledTime.hour > 12 ? scheduledTime.hour - 12 : (scheduledTime.hour == 0 ? 12 : scheduledTime.hour);
        final ampm = scheduledTime.hour >= 12 ? 'PM' : 'AM';
        final min = scheduledTime.minute.toString().padLeft(2, '0');
        final now = DateTime.now();
        final isToday = scheduledTime.year == now.year &&
                        scheduledTime.month == now.month &&
                        scheduledTime.day == now.day;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder set for $hour:$min $ampm ${isToday ? "today" : "tomorrow"}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

void _confirmLogoutDialog(BuildContext context, WidgetRef ref) {
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

    final String subject = Uri.encodeComponent('[RetroTrack] $type');
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

class _AccentColorTile extends ConsumerWidget {
  final bool isDark;
  final bool isPremium;

  const _AccentColorTile({required this.isDark, required this.isPremium});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentColor = ref.watch(accentColorProvider);
    // Non-premium users always see blue
    final displayColor = isPremium ? accentColor : AccentColor.blue;

    return ListTile(
      leading: Icon(Icons.color_lens, color: isDark ? Colors.white70 : Colors.grey.shade700),
      title: Text('Accent Color', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      subtitle: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: displayColor.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(width: 8),
          Text(displayColor.label, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          if (!isPremium) ...[
            const SizedBox(width: 8),
            Icon(Icons.lock, size: 14, color: Colors.grey[500]),
          ],
        ],
      ),
      onTap: isPremium
          ? () => _showAccentColorDialog(context, ref, accentColor)
          : () => _showPremiumRequired(context),
    );
  }

  void _showPremiumRequired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Accent colors are a premium feature')),
    );
  }

  void _showAccentColorDialog(BuildContext context, WidgetRef ref, AccentColor current) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Accent Color'),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: AccentColor.values.map((color) {
              final isSelected = color == current;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(accentColorProvider.notifier).setAccentColor(color);
                  Navigator.pop(ctx);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: color.color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 28)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _SoundEffectsTile extends StatefulWidget {
  final bool isDark;

  const _SoundEffectsTile({required this.isDark});

  @override
  State<_SoundEffectsTile> createState() => _SoundEffectsTileState();
}

class _SoundEffectsTileState extends State<_SoundEffectsTile> {
  final SoundService _soundService = SoundService();
  bool _isEnabled = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initSoundService();
  }

  Future<void> _initSoundService() async {
    await _soundService.initialize();
    if (mounted) {
      setState(() {
        _isEnabled = _soundService.isEnabled;
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(Icons.volume_up, color: widget.isDark ? Colors.white70 : Colors.grey.shade700),
          title: Text('Sound Effects', style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87)),
          subtitle: Text('8-bit sounds for achievements', style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
          value: _isEnabled,
          onChanged: (value) async {
            await _soundService.setEnabled(value);
            setState(() => _isEnabled = value);
            if (value) {
              // Play the sound as a demo
              await _soundService.playAchievementUnlock();
            }
          },
        ),
        // Test button (temporary for testing)
        Padding(
          padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
          child: OutlinedButton.icon(
            onPressed: () async {
              HapticFeedback.selectionClick();
              await _soundService.playAchievementUnlock();
            },
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Test Achievement Sound'),
          ),
        ),
      ],
    );
  }
}

/// Dual-screen settings tile for devices like Ayn Thor/Odin
class _DualScreenTile extends ConsumerStatefulWidget {
  final bool isDark;

  const _DualScreenTile({required this.isDark});

  @override
  ConsumerState<_DualScreenTile> createState() => _DualScreenTileState();
}

class _DualScreenTileState extends ConsumerState<_DualScreenTile> {
  final DualScreenService _dualScreenService = DualScreenService();
  bool _hasSecondaryDisplay = false;
  bool _isSecondaryActive = false;
  List<DisplayInfo> _displays = [];
  int _currentDisplayId = 0;
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();
    _checkDisplays();
    _dualScreenService.addDisplayChangeListener(_onDisplaysChanged);
  }

  Future<void> _checkDisplays() async {
    final hasSecondary = await _dualScreenService.hasSecondaryDisplay();
    final displays = await _dualScreenService.getDisplays();
    final currentId = await _dualScreenService.getCurrentDisplayId();
    if (mounted) {
      setState(() {
        _hasSecondaryDisplay = hasSecondary;
        _displays = displays;
        _currentDisplayId = currentId;
      });
    }
  }

  void _onDisplaysChanged(List<DisplayInfo> displays) {
    if (mounted) {
      setState(() {
        _displays = displays;
        _hasSecondaryDisplay = displays.length > 1;
      });
    }
  }

  Future<void> _toggleCompanionDisplay() async {
    if (_isSecondaryActive) {
      await _dualScreenService.dismissSecondary();
      setState(() => _isSecondaryActive = false);
    } else {
      await _dualScreenService.showOnSecondary(route: '/secondary');
      setState(() => _isSecondaryActive = true);
    }
  }

  Future<void> _launchFullAppOnSecondary() async {
    if (_isLaunching) return;

    setState(() => _isLaunching = true);
    HapticFeedback.mediumImpact();

    final success = await _dualScreenService.launchFullAppOnSecondary();

    if (mounted) {
      setState(() => _isLaunching = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Launching RetroTrack on secondary display...'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to launch on secondary display'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchOnDisplay(DisplayInfo display) async {
    if (_isLaunching) return;

    setState(() => _isLaunching = true);
    HapticFeedback.mediumImpact();

    final success = await _dualScreenService.launchOnDisplay(
      display.displayId,
      launchFullApp: true,
    );

    if (mounted) {
      setState(() => _isLaunching = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Launching on ${display.name}...'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch on ${display.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Icon(
            Icons.connected_tv,
            color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
          ),
          title: Text(
            'Multi-Display',
            style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87),
          ),
          subtitle: Text(
            _hasSecondaryDisplay
                ? '${_displays.length} display(s) detected'
                : 'No secondary display detected',
            style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          trailing: _hasSecondaryDisplay
              ? IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _checkDisplays,
                )
              : Icon(Icons.info_outline, color: Colors.grey[500]),
          onTap: _hasSecondaryDisplay ? null : _showNoDisplayInfo,
        ),

        // Display list with launch buttons
        if (_displays.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _displays.map((d) => _DisplayInfoRowWithActions(
                display: d,
                isDark: widget.isDark,
                isCurrentDisplay: d.displayId == _currentDisplayId,
                onLaunch: () => _launchOnDisplay(d),
                isLaunching: _isLaunching,
              )).toList(),
            ),
          ),

        // Quick actions for secondary display
        if (_hasSecondaryDisplay) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLaunching ? null : _launchFullAppOnSecondary,
                    icon: _isLaunching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Full App'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _toggleCompanionDisplay,
                    icon: Icon(
                      _isSecondaryActive ? Icons.close : Icons.view_sidebar,
                      size: 18,
                    ),
                    label: Text(_isSecondaryActive ? 'Close' : 'Companion'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Full App: Run RetroTrack independently on secondary display\n'
              'Companion: Show achievements list while browsing on main',
              style: TextStyle(
                fontSize: 11,
                color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ),
        ],

        const SizedBox(height: 8),
      ],
    );
  }

  void _showNoDisplayInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.connected_tv),
            SizedBox(width: 8),
            Text('Multi-Display Mode'),
          ],
        ),
        content: const Text(
          'This feature is designed for multi-display devices like the Ayn Thor.\n\n'
          'When a secondary display is detected, you can:\n'
          '• Launch the full app on either display\n'
          '• Show a companion view (achievements list) on one screen while browsing on the other\n\n'
          'No secondary display is currently connected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Display info row with launch action button
class _DisplayInfoRowWithActions extends StatelessWidget {
  final DisplayInfo display;
  final bool isDark;
  final bool isCurrentDisplay;
  final VoidCallback onLaunch;
  final bool isLaunching;

  const _DisplayInfoRowWithActions({
    required this.display,
    required this.isDark,
    required this.isCurrentDisplay,
    required this.onLaunch,
    required this.isLaunching,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentDisplay
            ? (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.1))
            : (isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(8),
        border: isCurrentDisplay
            ? Border.all(color: Colors.green.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            display.isDefault ? Icons.smartphone : Icons.tv,
            size: 20,
            color: isCurrentDisplay
                ? Colors.green
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        display.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrentDisplay ? FontWeight.bold : FontWeight.normal,
                          color: isCurrentDisplay
                              ? Colors.green
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentDisplay) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${display.width}x${display.height}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: display.isWidescreen
                            ? Colors.blue.withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        display.isWidescreen ? '16:9' : '4:3',
                        style: TextStyle(
                          fontSize: 9,
                          color: display.isWidescreen ? Colors.blue : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isCurrentDisplay)
            TextButton(
              onPressed: isLaunching ? null : onLaunch,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
              ),
              child: isLaunching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Launch', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
