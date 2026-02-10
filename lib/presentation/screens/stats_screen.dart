import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';
import 'stats/stats_widgets.dart';

export 'stats/stats_widgets.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  Map<String, dynamic>? _summary;
  List<dynamic>? _completedGames;
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
      final results = await Future.wait([
        api.getUserSummary(username, recentGames: 50, recentAchievements: 100),
        api.getCompletedGames(username),
      ]);
      setState(() {
        _summary = results[0] as Map<String, dynamic>?;
        _completedGames = results[1] as List<dynamic>?;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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

          // Hardcore vs Softcore Breakdown
          _buildHardcoreBreakdown(),
          const SizedBox(height: 16),

          // Close to Mastery
          _buildMasteryTracker(),
          const SizedBox(height: 16),

          // Games by Console
          _buildConsoleBreakdown(),
          const SizedBox(height: 16),

          // Mastered Games
          _buildMasteredGames(),
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

  Widget _buildHardcoreBreakdown() {
    final points = _summary!['TotalPoints'] ?? 0;
    final softcore = _summary!['TotalSoftcorePoints'] ?? 0;
    final total = points + softcore;
    final hardcorePercent = total > 0 ? (points / total * 100).toInt() : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.whatshot, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Hardcore vs Softcore', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: total > 0 ? points / total : 0,
                minHeight: 24,
                backgroundColor: Colors.blue.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation(Colors.orange),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text('Hardcore: $points pts ($hardcorePercent%)'),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text('Softcore: $softcore pts'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasteryTracker() {
    final recentlyPlayed = _summary!['RecentlyPlayed'] as List<dynamic>? ?? [];
    final awarded = _summary!['Awarded'] as Map<String, dynamic>? ?? {};

    // Find games close to mastery (70%+ but not 100%)
    final closeToMastery = <Map<String, dynamic>>[];

    for (final game in recentlyPlayed) {
      final gameId = game['GameID'].toString();
      final gameAwards = awarded[gameId];
      final total = game['AchievementsTotal'] ?? 0;

      if (gameAwards != null && gameAwards is Map && total > 0) {
        final earned = gameAwards['NumAchieved'] ?? 0;
        final progress = earned / total;

        if (progress >= 0.7 && progress < 1.0) {
          closeToMastery.add({
            'game': game,
            'earned': earned,
            'total': total,
            'progress': progress,
            'remaining': total - earned,
          });
        }
      }
    }

    // Sort by closest to completion
    closeToMastery.sort((a, b) => (b['progress'] as double).compareTo(a['progress'] as double));

    if (closeToMastery.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber),
                const SizedBox(width: 8),
                Text('Close to Mastery', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Just a few more achievements!',
              style: TextStyle(color: context.subtitleColor, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...closeToMastery.take(5).map((item) {
              final game = item['game'];
              final remaining = item['remaining'] as int;
              final progress = item['progress'] as double;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: 'https://retroachievements.org${game['ImageIcon']}',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 40, height: 40,
                          color: Colors.grey[800],
                          child: const Icon(Icons.games, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            game['Title'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$remaining achievement${remaining == 1 ? '' : 's'} to go!',
                            style: TextStyle(color: Colors.amber[400], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: Colors.grey[700],
                      valueColor: const AlwaysStoppedAnimation(Colors.amber),
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

  Widget _buildMasteredGames() {
    if (_completedGames == null || _completedGames!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter for mastered games (100% hardcore)
    final mastered = _completedGames!.where((g) {
      final hardcoreMode = g['HardcoreMode'] == 1;
      return hardcoreMode;
    }).toList();

    // Group by console
    final consoleStats = <String, int>{};
    for (final game in mastered) {
      final console = game['ConsoleName'] ?? 'Unknown';
      consoleStats[console] = (consoleStats[console] ?? 0) + 1;
    }

    final sortedConsoles = consoleStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium, color: Colors.amber),
                const SizedBox(width: 8),
                Text('Mastered Games', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${mastered.length} Total',
                    style: TextStyle(color: Colors.amber[400], fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('By Console:', style: TextStyle(color: context.subtitleColor, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sortedConsoles.take(8).map((e) => Chip(
                avatar: Text('${e.value}', style: TextStyle(color: Colors.amber[400], fontWeight: FontWeight.bold)),
                label: Text(e.key, style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
              )).toList(),
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
                Expanded(child: PointStat(
                  label: 'Hardcore',
                  value: points.toString(),
                  icon: Icons.stars,
                  color: Colors.amber,
                )),
                Expanded(child: PointStat(
                  label: 'True Points',
                  value: truePoints.toString(),
                  icon: Icons.military_tech,
                  color: Colors.purple,
                )),
                Expanded(child: PointStat(
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
            InfoRow(icon: Icons.play_arrow, label: 'Currently', value: richPresence),
            InfoRow(icon: Icons.calendar_today, label: 'Member Since', value: formatStatsDate(memberSince)),
            InfoRow(icon: Icons.games, label: 'Last Game ID', value: lastGame?.toString() ?? 'N/A'),
          ],
        ),
      ),
    );
  }
}
