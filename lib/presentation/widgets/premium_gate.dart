import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/premium_provider.dart';

/// A widget that gates content behind premium
/// Shows an upgrade prompt for free users
class PremiumGate extends ConsumerWidget {
  final Widget child;
  final String featureName;
  final String description;
  final IconData icon;

  const PremiumGate({
    super.key,
    required this.child,
    required this.featureName,
    required this.description,
    this.icon = Icons.lock_outline,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    if (isPremium) {
      return child;
    }

    return _PremiumRequiredScreen(
      featureName: featureName,
      description: description,
      icon: icon,
      onUpgrade: () => _showPremiumSheet(context, ref),
    );
  }

  void _showPremiumSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.amber.shade400, Colors.orange.shade600],
                ),
              ),
              child: const Icon(Icons.star, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Unlock Premium',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'One-time purchase. Yours forever.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            _PremiumFeatureRow(Icons.block, 'Ad-free experience'),
            _PremiumFeatureRow(Icons.palette, 'Custom themes'),
            _PremiumFeatureRow(Icons.share, 'Share cards'),
            _PremiumFeatureRow(Icons.analytics, 'Detailed statistics'),
            _PremiumFeatureRow(Icons.calendar_month, 'Achievement calendar'),
            _PremiumFeatureRow(Icons.compare_arrows, 'Compare with friends'),
            _PremiumFeatureRow(Icons.local_fire_department, 'Streak tracking'),
            _PremiumFeatureRow(Icons.emoji_events, 'Milestones'),
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
                          content: Text('Premium unlocked! Enjoy all features.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Upgrade for \$4.99',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                await ref.read(premiumProvider.notifier).restorePurchases();
                if (context.mounted) {
                  Navigator.pop(ctx);
                  final isPremium = ref.read(isPremiumProvider);
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _PremiumRequiredScreen extends StatelessWidget {
  final String featureName;
  final String description;
  final IconData icon;
  final VoidCallback onUpgrade;

  const _PremiumRequiredScreen({
    required this.featureName,
    required this.description,
    required this.icon,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.15),
              ),
              child: Icon(
                icon,
                size: 64,
                color: Colors.amber.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'PREMIUM',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              featureName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onUpgrade,
              icon: const Icon(Icons.star),
              label: const Text('Unlock for \$4.99'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'One-time purchase',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumFeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PremiumFeatureRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 20),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

/// Helper function to check premium and show upgrade prompt
/// Returns true if user is premium, false if not (and shows prompt)
bool checkPremiumOrPrompt(BuildContext context, WidgetRef ref, String featureName) {
  final isPremium = ref.read(isPremiumProvider);

  if (isPremium) return true;

  showModalBottomSheet(
    context: context,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 48, color: Colors.amber),
          const SizedBox(height: 16),
          Text(
            '$featureName is a Premium feature',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Upgrade to unlock this and all other premium features!',
            textAlign: TextAlign.center,
          ),
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
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: const Text('Upgrade for \$4.99'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not Now'),
          ),
        ],
      ),
    ),
  );

  return false;
}
