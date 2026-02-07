import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final premium = ref.watch(premiumProvider);
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
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
                      child: const Text('Upgrade for \$6.99'),
                    ),
                  ),
                ],
              ),
            )
          else
            ListTile(
              leading: const Icon(Icons.verified, color: Colors.amber),
              title: const Text('Premium Active'),
              subtitle: const Text('All features unlocked!'),
            ),

          const Divider(),

          // Appearance
          _SectionTitle('Appearance'),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: Text(_themeName(themeMode)),
            trailing: premium.isPremium ? null : _ProBadge(),
            onTap: premium.isPremium
                ? () => _showThemeDialog(context, ref, themeMode)
                : () => _showPremiumRequired(context),
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
            leading: const Icon(Icons.person),
            title: const Text('Logged in as'),
            subtitle: Text(authState.username ?? 'Unknown'),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () => _confirmLogout(context, ref),
          ),

          const Divider(),

          // Dev Tools
          _SectionTitle('Developer'),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Toggle Premium (Dev)'),
            subtitle: Text(premium.isPremium ? 'Currently: Premium' : 'Currently: Free'),
            onTap: () {
              ref.read(premiumProvider.notifier).togglePremium();
            },
          ),

          const Divider(),

          // About
          _SectionTitle('About'),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),

          const SizedBox(height: 32),
        ],
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
                onPressed: () {
                  ref.read(premiumProvider.notifier).unlockPremium();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Premium unlocked!')),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Purchase for \$6.99', style: TextStyle(fontSize: 18)),
                ),
              ),
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
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
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
    return ListTile(
      leading: Icon(icon, color: locked ? Colors.grey : Colors.green),
      title: Text(title),
      subtitle: Text(subtitle),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Text(text),
        ],
      ),
    );
  }
}
