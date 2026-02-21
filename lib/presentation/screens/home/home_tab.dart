import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/animations.dart';
import '../../../core/theme_utils.dart';
import '../../providers/auth_provider.dart';
import '../share_card/share_card_screen.dart';
import '../game_detail_screen.dart';
import 'home_widgets.dart';

class HomeTab extends ConsumerStatefulWidget {
  final Map<String, dynamic>? profile;
  final List<dynamic>? recentGames;
  final bool isLoading;
  final VoidCallback onRefresh;

  const HomeTab({
    super.key,
    required this.profile,
    required this.recentGames,
    required this.isLoading,
    required this.onRefresh,
  });

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  Map<String, dynamic>? _summary;
  List<dynamic>? _completedGames;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    final api = ref.read(apiDataSourceProvider);
    final username = ref.read(authProvider).username;

    if (username != null) {
      final results = await Future.wait([
        api.getUserSummary(username, recentGames: 50, recentAchievements: 100),
        api.getCompletedGames(username),
      ]);
      if (mounted) {
        setState(() {
          _summary = results[0] as Map<String, dynamic>?;
          _completedGames = results[1] as List<dynamic>?;
          _isLoadingStats = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return _buildShimmerLoading();
    }

    return RetroRefreshIndicator(
      onRefresh: () async {
        widget.onRefresh();
        await _loadStats();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 40),
          if (widget.profile != null) _buildProfileHeader(context),
          const SizedBox(height: 20),
          if (widget.profile != null) _buildStatsRow(context),
          const SizedBox(height: 16),
          if (_summary != null) _buildHardcoreSoftcoreBar(context),
          const SizedBox(height: 16),
          if (_summary != null) _buildCloseToMastery(context),
          if (_completedGames != null) _buildMasteredGamesCompact(context),
          const SizedBox(height: 20),
          Text('Recently Played', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (widget.recentGames != null && widget.recentGames!.isNotEmpty)
            ...widget.recentGames!.take(5).toList().asMap().entries.map((entry) =>
              AnimatedListItem(
                index: entry.key,
                child: GameListTile(game: entry.value),
              ),
            )
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No recent games'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 40),
        const ShimmerProfileHeader(),
        const SizedBox(height: 24),
        const Row(
          children: [
            Expanded(child: ShimmerCard(height: 100)),
            SizedBox(width: 12),
            Expanded(child: ShimmerCard(height: 100)),
          ],
        ),
        const SizedBox(height: 40),
        const ShimmerCard(height: 20, width: 150),
        const SizedBox(height: 12),
        ...List.generate(4, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: ShimmerGameTile(),
        )),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final picUrl = 'https://retroachievements.org${widget.profile!['UserPic']}';
    final username = widget.profile!['User'] ?? 'User';
    return Row(
      children: [
        ClipOval(
          child: CachedNetworkImage(
            imageUrl: picUrl,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 80,
              height: 80,
              color: Colors.grey[800],
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 80,
              height: 80,
              color: Colors.grey[800],
              child: Center(
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                widget.profile!['RichPresenceMsg'] ?? 'Offline',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.share),
          onPressed: () {
            Navigator.push(
              context,
              FadeScalePageRoute(
                page: ShareCardScreen(
                  type: ShareCardType.profile,
                  data: widget.profile!,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final points = widget.profile!['TotalPoints'] ?? 0;
    final truePoints = widget.profile!['TotalTruePoints'] ?? 0;
    final softcore = _summary?['TotalSoftcorePoints'] ?? widget.profile!['TotalSoftcorePoints'] ?? 0;

    // Count mastered games
    int masteredCount = 0;
    if (_completedGames != null) {
      masteredCount = _completedGames!.where((g) => g['HardcoreMode'] == 1).length;
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: StatCard(
              icon: Icons.stars,
              label: 'Hardcore',
              value: '$points',
              color: Colors.amber,
            )),
            const SizedBox(width: 8),
            Expanded(child: StatCard(
              icon: Icons.military_tech,
              label: 'True Points',
              value: '$truePoints',
              color: Colors.purple,
            )),
            const SizedBox(width: 8),
            Expanded(child: StatCard(
              icon: Icons.star_border,
              label: 'Softcore',
              value: '$softcore',
              color: Colors.blue,
            )),
          ],
        ),
        if (masteredCount > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$masteredCount Mastered Game${masteredCount == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHardcoreSoftcoreBar(BuildContext context) {
    final points = _summary!['TotalPoints'] ?? 0;
    final softcore = _summary!['TotalSoftcorePoints'] ?? 0;
    final total = points + softcore;
    if (total == 0) return const SizedBox.shrink();

    final hardcorePercent = (points / total * 100).toInt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.whatshot, color: Colors.orange, size: 18),
                const SizedBox(width: 6),
                Text('Hardcore vs Softcore', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: points / total,
                minHeight: 16,
                backgroundColor: Colors.blue.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation(Colors.orange),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Hardcore: $hardcorePercent%', style: const TextStyle(fontSize: 11, color: Colors.orange)),
                Text('Softcore: ${100 - hardcorePercent}%', style: TextStyle(fontSize: 11, color: Colors.blue[300])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseToMastery(BuildContext context) {
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

    closeToMastery.sort((a, b) => (b['progress'] as double).compareTo(a['progress'] as double));

    if (closeToMastery.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Text('Close to Mastery', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 10),
            ...closeToMastery.take(3).map((item) {
              final game = item['game'];
              final remaining = item['remaining'] as int;
              final progress = item['progress'] as double;
              final gameId = game['GameID'];

              return GestureDetector(
                onTap: () {
                  final id = gameId is int ? gameId : int.tryParse(gameId?.toString() ?? '') ?? 0;
                  if (id > 0) {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => GameDetailScreen(gameId: id),
                    ));
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: 'https://retroachievements.org${game['ImageIcon']}',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 36, height: 36,
                            color: Colors.grey[800],
                            child: const Icon(Icons.games, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game['Title'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$remaining to go!',
                              style: TextStyle(color: Colors.amber[400], fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          backgroundColor: Colors.grey[700],
                          valueColor: const AlwaysStoppedAnimation(Colors.amber),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMasteredGamesCompact(BuildContext context) {
    if (_completedGames == null || _completedGames!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter for mastered games (hardcore)
    final mastered = _completedGames!.where((g) => g['HardcoreMode'] == 1).toList();
    if (mastered.isEmpty) return const SizedBox.shrink();

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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
                const SizedBox(width: 6),
                Text('Mastered by Console', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sortedConsoles.take(6).map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[800]
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${e.key}: ${e.value}',
                  style: const TextStyle(fontSize: 11),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
