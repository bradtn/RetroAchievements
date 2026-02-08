import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';
import 'game_detail_screen.dart';

String _formatDateTime(String? date) {
  if (date == null || date.isEmpty) return '';
  try {
    final dt = DateTime.parse(date);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
  } catch (_) {
    return date;
  }
}

class AchievementOfTheWeekScreen extends ConsumerStatefulWidget {
  const AchievementOfTheWeekScreen({super.key});

  @override
  ConsumerState<AchievementOfTheWeekScreen> createState() => _AchievementOfTheWeekScreenState();
}

class _AchievementOfTheWeekScreenState extends ConsumerState<AchievementOfTheWeekScreen> {
  Map<String, dynamic>? _aotwData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final api = ref.read(apiDataSourceProvider);
    final data = await api.getAchievementOfTheWeek();

    setState(() {
      _aotwData = data;
      _isLoading = false;
      if (data == null) _error = 'Failed to load Achievement of the Week';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievement of the Week'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _aotwData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error ?? 'Unknown error'),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    final achievement = _aotwData!['Achievement'] as Map<String, dynamic>?;
    final game = _aotwData!['Game'] as Map<String, dynamic>?;
    final console = _aotwData!['Console'] as Map<String, dynamic>?;
    final startAt = _formatDate(_aotwData!['StartAt']);
    final endAt = _formatDate(_aotwData!['EndAt']);
    final unlocks = _aotwData!['Unlocks'] as List<dynamic>? ?? [];
    final totalPlayers = _aotwData!['TotalPlayers'] ?? 0;
    final unlocksCount = _aotwData!['UnlocksCount'] ?? unlocks.length;

    if (achievement == null || game == null) {
      return const Center(child: Text('No active Achievement of the Week'));
    }

    final achTitle = achievement['Title'] ?? 'Achievement';
    final achDesc = achievement['Description'] ?? '';
    final achPoints = achievement['Points'] ?? 0;
    final achTrueRatio = achievement['TrueRatio'] ?? 0;
    final badgeName = achievement['BadgeName'] ?? '';

    final gameTitle = game['Title'] ?? 'Unknown Game';
    final gameId = game['ID'];
    final gameIcon = game['ImageIcon'] ?? '';

    final consoleName = console?['Name'] ?? '';

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
        children: [
          // Achievement Card
          Card(
            child: Column(
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade700, Colors.orange.shade800],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ACHIEVEMENT OF THE WEEK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (startAt.isNotEmpty || endAt.isNotEmpty)
                        Text(
                          startAt.isNotEmpty && endAt.isNotEmpty
                              ? '$startAt - $endAt'
                              : startAt.isNotEmpty
                                  ? 'Started: $startAt'
                                  : 'Ends: $endAt',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // Achievement details
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Badge
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 96,
                            height: 96,
                            color: Colors.grey[800],
                            child: const Icon(Icons.emoji_events, size: 48),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      Text(
                        achTitle,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Description
                      Text(
                        achDesc,
                        style: TextStyle(color: context.subtitleColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Points
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.stars, color: Colors.amber[400], size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  '$achPoints pts',
                                  style: TextStyle(
                                    color: Colors.amber[400],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.military_tech, color: Colors.purple[300], size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'RP: $achTrueRatio',
                                  style: TextStyle(
                                    color: Colors.purple[300],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Game Card
          Text(
            'From Game',
            style: TextStyle(
              color: context.subtitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: gameIcon.isNotEmpty
                      ? 'https://retroachievements.org${gameIcon.startsWith('/') ? '' : '/'}$gameIcon'
                      : 'https://retroachievements.org/Images/000001.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[800],
                    child: const Icon(Icons.games),
                  ),
                ),
              ),
              title: Text(gameTitle),
              subtitle: Text(consoleName),
              trailing: const Icon(Icons.chevron_right),
              onTap: gameId != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GameDetailScreen(
                            gameId: int.tryParse(gameId.toString()) ?? 0,
                            gameTitle: gameTitle,
                          ),
                        ),
                      );
                    }
                  : null,
            ),
          ),

          const SizedBox(height: 24),

          // Stats
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people,
                  label: 'Total Players',
                  value: '$totalPlayers',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle,
                  label: 'Unlocked',
                  value: '$unlocksCount',
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Unlocks
          if (unlocks.isNotEmpty) ...[
            Text(
              'Recent Unlocks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...unlocks.take(20).map((unlock) => _UnlockTile(unlock: unlock)),
          ],
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final dt = DateTime.parse(date);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return date;
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: context.subtitleColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlockTile extends StatelessWidget {
  final dynamic unlock;

  const _UnlockTile({required this.unlock});

  @override
  Widget build(BuildContext context) {
    final user = unlock['User'] ?? 'Unknown';
    final dateAwarded = _formatDateTime(unlock['DateAwarded']);
    final hardcoreMode = unlock['HardcoreMode'] == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: 'https://retroachievements.org/UserPic/$user.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade700,
              child: Text(user.isNotEmpty ? user[0].toUpperCase() : '?'),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(user, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (hardcoreMode) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HC',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          dateAwarded,
          style: TextStyle(color: context.subtitleColor, fontSize: 12),
        ),
      ),
    );
  }
}
