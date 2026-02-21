import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/dual_screen_service.dart';
import '../providers/auth_provider.dart';

/// Secondary screen widget for dual-screen devices
/// Optimized for 4:3 aspect ratio displays
class SecondaryScreen extends ConsumerStatefulWidget {
  const SecondaryScreen({super.key});

  @override
  ConsumerState<SecondaryScreen> createState() => _SecondaryScreenState();
}

class _SecondaryScreenState extends ConsumerState<SecondaryScreen> {
  final DualScreenService _dualScreenService = DualScreenService();
  Map<String, dynamic>? _lastDataFromMain;

  @override
  void initState() {
    super.initState();
    _dualScreenService.addDataFromMainListener(_onDataFromMain);
  }

  void _onDataFromMain(Map<String, dynamic> data) {
    setState(() {
      _lastDataFromMain = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(12),
              color: theme.primaryColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.tv, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'RetroTrack - Secondary Display',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: _buildContent(context, authState),
            ),

            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: theme.cardColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    authState.isAuthenticated
                        ? 'User: ${authState.username}'
                        : 'Not logged in',
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    '4:3 Display Mode',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AuthState authState) {
    if (!authState.isAuthenticated) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Please log in on the main screen'),
          ],
        ),
      );
    }

    // Show last received data from main screen
    if (_lastDataFromMain != null) {
      return _buildGameInfo(_lastDataFromMain!);
    }

    return _buildDefaultView();
  }

  Widget _buildDefaultView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_esports,
            size: 64,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Select a game on the main screen',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Game details will appear here',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 32),
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          Text(
            'Dual-Screen Mode Active',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(icon: Icons.gamepad, label: 'Games', value: '--'),
              _StatItem(icon: Icons.emoji_events, label: 'Achievements', value: '--'),
              _StatItem(icon: Icons.star, label: 'Points', value: '--'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameInfo(Map<String, dynamic> data) {
    final gameTitle = data['gameTitle'] as String? ?? 'Unknown Game';
    final consoleName = data['consoleName'] as String? ?? '';
    final achievementCount = data['achievementCount'] as int? ?? 0;
    final earnedCount = data['earnedCount'] as int? ?? 0;
    final imageUrl = data['imageUrl'] as String?;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Game header
          Row(
            children: [
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[800],
                      child: const Icon(Icons.gamepad),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gameTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (consoleName.isNotEmpty)
                      Text(
                        consoleName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Achievements'),
                    Text(
                      '$earnedCount / $achievementCount',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: achievementCount > 0 ? earnedCount / achievementCount : 0,
                  backgroundColor: Colors.grey[700],
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Hint
          Center(
            child: Text(
              'Navigate on the main screen to update this view',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
