import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import '../providers/premium_provider.dart';
import '../../services/purchase_service.dart';
import '../screens/settings/settings_widgets.dart';

/// A widget that gates content behind premium
/// Shows an upgrade prompt for free users
/// Optionally shows a preview of the content with a blur overlay
class PremiumGate extends ConsumerWidget {
  final Widget child;
  final String featureName;
  final String description;
  final IconData icon;
  /// Optional preview widget to show instead of the generic locked screen
  /// When provided, shows the preview with a blur overlay and upgrade button
  final Widget? preview;

  const PremiumGate({
    super.key,
    required this.child,
    required this.featureName,
    required this.description,
    this.icon = Icons.lock_outline,
    this.preview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    if (isPremium) {
      return child;
    }

    // If preview is provided, show it with overlay
    if (preview != null) {
      return _PremiumPreviewScreen(
        featureName: featureName,
        preview: preview!,
        onUpgrade: () => _showPremiumSheet(context, ref),
      );
    }

    return _PremiumRequiredScreen(
      featureName: featureName,
      description: description,
      icon: icon,
      onUpgrade: () => _showPremiumSheet(context, ref),
    );
  }

  void _showPremiumSheet(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _PremiumDialogContent(parentContext: context),
    );
  }
}

/// Shows a preview of premium content with the actual content visible
class _PremiumPreviewScreen extends StatelessWidget {
  final String featureName;
  final Widget preview;
  final VoidCallback onUpgrade;

  const _PremiumPreviewScreen({
    required this.featureName,
    required this.preview,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Stack(
      children: [
        // The actual preview content - fully visible!
        Positioned.fill(
          child: preview,
        ),
        // Gradient overlay at bottom for the unlock button
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.95),
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
            padding: EdgeInsets.fromLTRB(20, 40, 20, 16 + bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.black),
                          SizedBox(width: 4),
                          Text(
                            'PREMIUM',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock $featureName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Share your achievements on social media!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onUpgrade,
                    icon: const Icon(Icons.lock_open, size: 18),
                    label: const Text('Unlock for \$4.99'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Premium dialog content with confetti celebration
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
      _confettiController.play();
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
    final size = MediaQuery.of(context).size;
    final isWidescreen = size.width > size.height && size.width > 600;

    // Compact layout for widescreen
    if (isWidescreen) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withValues(alpha: 0.15),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: Colors.amber.shade600,
                ),
              ),
              const SizedBox(width: 24),
              // Content
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'PREMIUM',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        featureName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              // Button
              FilledButton.icon(
                onPressed: onUpgrade,
                icon: const Icon(Icons.star, size: 16),
                label: const Text('Unlock \$4.99'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Normal portrait layout
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

  showDialog(
    context: context,
    builder: (ctx) => _QuickPremiumDialog(
      parentContext: context,
      featureName: featureName,
    ),
  );

  return false;
}

/// Simpler premium dialog for quick prompts (used by checkPremiumOrPrompt)
class _QuickPremiumDialog extends ConsumerStatefulWidget {
  final BuildContext parentContext;
  final String featureName;

  const _QuickPremiumDialog({
    required this.parentContext,
    required this.featureName,
  });

  @override
  ConsumerState<_QuickPremiumDialog> createState() => _QuickPremiumDialogState();
}

class _QuickPremiumDialogState extends ConsumerState<_QuickPremiumDialog> {
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
      _confettiController.play();
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

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(premiumProvider.notifier);
    final priceString = notifier.priceString;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
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
                Text(
                  '${widget.featureName} is Premium',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Upgrade to unlock this and all other premium features!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
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
                        : Text(
                            'Purchase for $priceString',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Not Now'),
                ),
              ],
            ),
          ),
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
