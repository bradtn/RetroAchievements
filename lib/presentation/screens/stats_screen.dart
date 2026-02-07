import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  Map<String, dynamic>? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final api = ref.read(apiDataSourceProvider);
    final username = ref.read(authProvider).username;

    if (username != null) {
      final summary = await api.getUserSummary(username, recentGames: 20, recentAchievements: 50);
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);

    if (!isPremium) {
      return _buildPremiumGate(context);
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_summary == null) {
      return const Center(child: Text('Failed to load stats'));
    }

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
        children: [
          // Points Overview
          _buildPointsCard(),
          const SizedBox(height: 16),

          // Games by Console
          _buildConsoleBreakdown(),
          const SizedBox(height: 16),

          // Recent Games Progress
          _buildRecentGamesProgress(),
          const SizedBox(height: 16),

          // Activity
          _buildActivityCard(),
        ],
      ),
    );
  }

  Widget _buildPremiumGate(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 80, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'Advanced Statistics',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlock detailed stats, charts, and insights with Premium',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.read(premiumProvider.notifier).togglePremium();
              },
              icon: const Icon(Icons.star),
              label: const Text('Unlock Premium'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard() {
    final points = _summary!['TotalPoints'] ?? 0;
    final truePoints = _summary!['TotalTruePoints'] ?? 0;
    final softcore = _summary!['TotalSoftcorePoints'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Points Overview', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _PointStat(
                  label: 'Hardcore',
                  value: points.toString(),
                  icon: Icons.stars,
                  color: Colors.amber,
                )),
                Expanded(child: _PointStat(
                  label: 'True Points',
                  value: truePoints.toString(),
                  icon: Icons.military_tech,
                  color: Colors.purple,
                )),
                Expanded(child: _PointStat(
                  label: 'Softcore',
                  value: softcore.toString(),
                  icon: Icons.star_border,
                  color: Colors.blue,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsoleBreakdown() {
    final recentlyPlayed = _summary!['RecentlyPlayed'] as List<dynamic>? ?? [];

    // Group by console
    final consoleMap = <String, int>{};
    for (final game in recentlyPlayed) {
      final console = game['ConsoleName'] ?? 'Unknown';
      consoleMap[console] = (consoleMap[console] ?? 0) + 1;
    }

    if (consoleMap.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Games by Console', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...consoleMap.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(e.key, overflow: TextOverflow.ellipsis),
                  ),
                  Expanded(
                    flex: 2,
                    child: LinearProgressIndicator(
                      value: e.value / recentlyPlayed.length,
                      backgroundColor: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${e.value}'),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentGamesProgress() {
    final recentlyPlayed = _summary!['RecentlyPlayed'] as List<dynamic>? ?? [];
    final awarded = _summary!['Awarded'] as Map<String, dynamic>? ?? {};

    if (recentlyPlayed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Game Progress', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...recentlyPlayed.take(5).map((game) {
              final gameId = game['GameID'].toString();
              final gameAwards = awarded[gameId];
              final total = game['AchievementsTotal'] ?? 0;
              int earned = 0;

              if (gameAwards != null && gameAwards is Map) {
                earned = (gameAwards['NumPossibleAchievements'] ?? 0) -
                         (gameAwards['NumAchieved'] ?? gameAwards['NumPossibleAchievements'] ?? 0);
                // Actually let's calculate properly
                earned = gameAwards['NumAchieved'] ?? 0;
              }

              final progress = total > 0 ? earned / total : 0.0;
              final percent = (progress * 100).toInt();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: 'https://retroachievements.org${game['ImageIcon']}',
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 32, height: 32,
                              color: Colors.grey[800],
                              child: const Icon(Icons.games, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            game['Title'] ?? 'Unknown',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('$percent%', style: TextStyle(
                          color: percent == 100 ? Colors.green : Colors.grey,
                          fontWeight: percent == 100 ? FontWeight.bold : FontWeight.normal,
                        )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[800],
                      color: percent == 100 ? Colors.green : null,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard() {
    final memberSince = _summary!['MemberSince'] ?? '';
    final richPresence = _summary!['RichPresenceMsg'] ?? 'Offline';
    final lastGame = _summary!['LastGameID'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _InfoRow(icon: Icons.play_arrow, label: 'Currently', value: richPresence),
            _InfoRow(icon: Icons.calendar_today, label: 'Member Since', value: _formatDate(memberSince)),
            _InfoRow(icon: Icons.games, label: 'Last Game ID', value: lastGame?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(date);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return date;
    }
  }
}

class _PointStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _PointStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(
            child: Text(value, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
