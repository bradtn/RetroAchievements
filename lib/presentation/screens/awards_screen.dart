import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import 'game_detail_screen.dart';

class AwardsScreen extends ConsumerStatefulWidget {
  const AwardsScreen({super.key});

  @override
  ConsumerState<AwardsScreen> createState() => _AwardsScreenState();
}

class _AwardsScreenState extends ConsumerState<AwardsScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _awardsData;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAwards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAwards() async {
    setState(() => _isLoading = true);
    final api = ref.read(apiDataSourceProvider);
    final username = ref.read(authProvider).username;

    if (username != null) {
      final awards = await api.getUserAwards(username);
      setState(() {
        _awardsData = awards;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Awards'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Mastery'),
            Tab(text: 'Completed'),
            Tab(text: 'Events'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _awardsData == null
              ? const Center(child: Text('Failed to load awards'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMasteryTab(),
                    _buildCompletedTab(),
                    _buildEventsTab(),
                  ],
                ),
    );
  }

  Widget _buildMasteryTab() {
    final visibleAwards = _awardsData!['VisibleUserAwards'] as List<dynamic>? ?? [];
    final masteryAwards = visibleAwards.where((a) =>
      a['AwardType'] == 'Mastery' || a['AwardType'] == 'Game Beaten'
    ).toList();

    // Separate mastery (100%) from beaten
    final mastered = masteryAwards.where((a) => a['AwardType'] == 'Mastery').toList();
    final beaten = masteryAwards.where((a) => a['AwardType'] == 'Game Beaten').toList();

    if (mastered.isEmpty && beaten.isEmpty) {
      return _buildEmptyState('No mastery awards yet', 'Complete all achievements in a game to earn mastery!');
    }

    return RefreshIndicator(
      onRefresh: _loadAwards,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Stats summary
          _buildAwardsSummary(),
          const SizedBox(height: 24),

          // Mastered games
          if (mastered.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.workspace_premium,
              title: 'Mastered',
              count: mastered.length,
              color: Colors.amber,
            ),
            const SizedBox(height: 12),
            ...mastered.map((award) => _AwardTile(award: award, type: 'mastery')),
            const SizedBox(height: 24),
          ],

          // Beaten games
          if (beaten.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.check_circle,
              title: 'Beaten',
              count: beaten.length,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            ...beaten.map((award) => _AwardTile(award: award, type: 'beaten')),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletedTab() {
    final completedGames = _awardsData!['VisibleUserAwards'] as List<dynamic>? ?? [];
    final completed = completedGames.where((a) =>
      a['AwardType'] == 'Mastery' || a['AwardType'] == 'Game Beaten'
    ).toList();

    // Group by console
    final byConsole = <String, List<dynamic>>{};
    for (final award in completed) {
      final console = award['ConsoleName'] ?? 'Unknown';
      byConsole.putIfAbsent(console, () => []).add(award);
    }

    if (byConsole.isEmpty) {
      return _buildEmptyState('No completed games', 'Beat games to see them here!');
    }

    return RefreshIndicator(
      onRefresh: _loadAwards,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...byConsole.entries.map((entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                icon: Icons.videogame_asset,
                title: entry.key,
                count: entry.value.length,
                color: Colors.blue,
              ),
              const SizedBox(height: 8),
              ...entry.value.map((award) => _CompactAwardTile(award: award)),
              const SizedBox(height: 16),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    final visibleAwards = _awardsData!['VisibleUserAwards'] as List<dynamic>? ?? [];
    final eventAwards = visibleAwards.where((a) =>
      a['AwardType'] != 'Mastery' && a['AwardType'] != 'Game Beaten'
    ).toList();

    if (eventAwards.isEmpty) {
      return _buildEmptyState('No event awards', 'Participate in events to earn special awards!');
    }

    return RefreshIndicator(
      onRefresh: _loadAwards,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: eventAwards.map((award) => _EventAwardTile(award: award)).toList(),
      ),
    );
  }

  Widget _buildAwardsSummary() {
    final totalPoints = _awardsData!['TotalAwardsCount'] ?? 0;
    final masteryCount = _awardsData!['MasteryAwardsCount'] ?? 0;
    final beatenCount = _awardsData!['BeatenHardcoreAwardsCount'] ??
                        _awardsData!['CompletionAwardsCount'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _SummaryItem(
                icon: Icons.workspace_premium,
                label: 'Mastered',
                value: '$masteryCount',
                color: Colors.amber,
              ),
            ),
            Container(width: 1, height: 50, color: Colors.grey[700]),
            Expanded(
              child: _SummaryItem(
                icon: Icons.check_circle,
                label: 'Beaten',
                value: '$beatenCount',
                color: Colors.green,
              ),
            ),
            Container(width: 1, height: 50, color: Colors.grey[700]),
            Expanded(
              child: _SummaryItem(
                icon: Icons.emoji_events,
                label: 'Total',
                value: '$totalPoints',
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }
}

class _AwardTile extends StatelessWidget {
  final dynamic award;
  final String type;

  const _AwardTile({required this.award, required this.type});

  @override
  Widget build(BuildContext context) {
    final title = award['Title'] ?? 'Unknown Game';
    final consoleName = award['ConsoleName'] ?? '';
    final gameId = award['AwardData'];
    final imageIcon = award['ImageIcon'] ?? '';
    final awardedAt = award['AwardedAt'] ?? '';
    final isHardcore = award['AwardDataExtra'] == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: 'https://retroachievements.org$imageIcon',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey[800],
                  child: const Icon(Icons.games),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: type == 'mastery' ? Colors.amber : Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  type == 'mastery' ? Icons.workspace_premium : Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(consoleName, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            Row(
              children: [
                if (isHardcore)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'HARDCORE',
                      style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                Text(
                  _formatDate(awardedAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: gameId != null ? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameDetailScreen(
                gameId: int.tryParse(gameId.toString()) ?? 0,
                gameTitle: title,
              ),
            ),
          );
        } : null,
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

class _CompactAwardTile extends StatelessWidget {
  final dynamic award;

  const _CompactAwardTile({required this.award});

  @override
  Widget build(BuildContext context) {
    final title = award['Title'] ?? 'Unknown';
    final gameId = award['AwardData'];
    final imageIcon = award['ImageIcon'] ?? '';
    final isMastery = award['AwardType'] == 'Mastery';

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: 'https://retroachievements.org$imageIcon',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: 32,
              height: 32,
              color: Colors.grey[800],
              child: const Icon(Icons.games, size: 16),
            ),
          ),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(
          isMastery ? Icons.workspace_premium : Icons.check_circle,
          color: isMastery ? Colors.amber : Colors.green,
          size: 20,
        ),
        onTap: gameId != null ? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameDetailScreen(
                gameId: int.tryParse(gameId.toString()) ?? 0,
                gameTitle: title,
              ),
            ),
          );
        } : null,
      ),
    );
  }
}

class _EventAwardTile extends StatelessWidget {
  final dynamic award;

  const _EventAwardTile({required this.award});

  @override
  Widget build(BuildContext context) {
    final awardType = award['AwardType'] ?? 'Event';
    final awardedAt = award['AwardedAt'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.withValues(alpha: 0.2),
          child: const Icon(Icons.celebration, color: Colors.purple),
        ),
        title: Text(awardType),
        subtitle: Text(_formatDate(awardedAt)),
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
