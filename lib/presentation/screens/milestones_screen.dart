import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';
import 'share_card_screen.dart';

class MilestonesScreen extends ConsumerStatefulWidget {
  const MilestonesScreen({super.key});

  @override
  ConsumerState<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends ConsumerState<MilestonesScreen> {
  final _usernameController = TextEditingController();
  Map<String, dynamic>? _profile;
  List<dynamic>? _completedGames;
  bool _isLoading = true;
  String? _viewingUsername;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Load current user's milestones by default
    final username = ref.read(authProvider).username;
    if (username != null) {
      _viewingUsername = username;
      _loadData(username);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadData(String username) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final api = ref.read(apiDataSourceProvider);

    try {
      final results = await Future.wait([
        api.getUserSummary(username, recentGames: 0, recentAchievements: 0),
        api.getCompletedGames(username),
      ]);

      final profile = results[0] as Map<String, dynamic>?;

      if (profile == null) {
        setState(() {
          _error = 'User "$username" not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _profile = profile;
        _completedGames = results[1] as List<dynamic>?;
        _viewingUsername = username;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load user data';
        _isLoading = false;
      });
    }
  }

  void _searchUser() {
    final username = _usernameController.text.trim();
    if (username.isNotEmpty) {
      _loadData(username);
    }
  }

  void _loadMyMilestones() {
    final username = ref.read(authProvider).username;
    if (username != null) {
      _usernameController.clear();
      _loadData(username);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUsername = ref.read(authProvider).username;
    final isViewingMyself = _viewingUsername == myUsername;

    return Scaffold(
      appBar: AppBar(
        title: Text(isViewingMyself ? 'My Milestones' : 'Milestones'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      hintText: 'View any user\'s milestones...',
                      prefixIcon: const Icon(Icons.person_search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _searchUser(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isLoading ? null : _searchUser,
                  child: const Text('View'),
                ),
              ],
            ),
          ),

          // Show who we're viewing if not ourselves
          if (!isViewingMyself && _viewingUsername != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Chip(
                    avatar: const Icon(Icons.person, size: 16),
                    label: Text('Viewing: $_viewingUsername'),
                    onDeleted: _loadMyMilestones,
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorView()
                    : RefreshIndicator(
                        onRefresh: () => _loadData(_viewingUsername ?? myUsername ?? ''),
                        child: _buildContent(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _error ?? 'An error occurred',
            style: TextStyle(color: context.subtitleColor),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadMyMilestones,
            child: const Text('View My Milestones'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_profile == null) {
      return const Center(child: Text('Failed to load profile'));
    }

    final milestones = _calculateMilestones();
    final earned = milestones.where((m) => m.isEarned).toList();
    final locked = milestones.where((m) => !m.isEarned).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16, 16, 16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      children: [
        // Stats summary
        _buildStatsSummary(earned.length, milestones.length),
        const SizedBox(height: 24),

        // Earned milestones
        if (earned.isNotEmpty) ...[
          Text(
            'Earned Badges (${earned.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: earned.length,
            itemBuilder: (ctx, i) => _MilestoneBadge(
              milestone: earned[i],
              onTap: () => _showMilestoneDetail(earned[i]),
            ),
          ),
          const SizedBox(height: 32),
        ],

        // Locked milestones
        if (locked.isNotEmpty) ...[
          Text(
            'Locked (${locked.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Keep playing to unlock more!',
            style: TextStyle(color: context.subtitleColor, fontSize: 13),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: locked.length,
            itemBuilder: (ctx, i) => _MilestoneBadge(
              milestone: locked[i],
              onTap: () => _showMilestoneDetail(locked[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatsSummary(int earned, int total) {
    final progress = total > 0 ? earned / total : 0.0;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade700,
              Colors.orange.shade800,
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                Text(
                  '$earned / $total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Milestones Earned',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Milestone> _calculateMilestones() {
    final totalPoints = int.tryParse(_profile!['TotalPoints']?.toString() ?? '0') ?? 0;
    final totalTruePoints = int.tryParse(_profile!['TotalTruePoints']?.toString() ?? '0') ?? 0;
    final hardcorePoints = int.tryParse(_profile!['TotalPoints']?.toString() ?? '0') ?? 0;
    final rank = int.tryParse(_profile!['Rank']?.toString() ?? '0') ?? 0;

    // Count achievements from completed games
    int totalAchievements = 0;
    int masteredGames = 0;

    if (_completedGames != null) {
      for (final game in _completedGames!) {
        final earned = game['NumAwarded'] ?? 0;
        final total = game['MaxPossible'] ?? 0;
        totalAchievements += (earned as int);
        if (earned == total && total > 0) {
          masteredGames++;
        }
      }
    }

    return [
      // Achievement milestones
      Milestone(
        id: 'ach_first',
        title: 'First Steps',
        description: 'Unlock your first achievement',
        icon: Icons.star,
        color: Colors.amber,
        category: 'Achievements',
        requirement: 1,
        currentValue: totalAchievements,
        isEarned: totalAchievements >= 1,
      ),
      Milestone(
        id: 'ach_100',
        title: 'Century',
        description: 'Unlock 100 achievements',
        icon: Icons.star,
        color: Colors.amber,
        category: 'Achievements',
        requirement: 100,
        currentValue: totalAchievements,
        isEarned: totalAchievements >= 100,
      ),
      Milestone(
        id: 'ach_500',
        title: 'Collector',
        description: 'Unlock 500 achievements',
        icon: Icons.star,
        color: Colors.amber,
        category: 'Achievements',
        requirement: 500,
        currentValue: totalAchievements,
        isEarned: totalAchievements >= 500,
      ),
      Milestone(
        id: 'ach_1000',
        title: 'Veteran',
        description: 'Unlock 1,000 achievements',
        icon: Icons.stars,
        color: Colors.amber,
        category: 'Achievements',
        requirement: 1000,
        currentValue: totalAchievements,
        isEarned: totalAchievements >= 1000,
      ),
      Milestone(
        id: 'ach_2500',
        title: 'Elite',
        description: 'Unlock 2,500 achievements',
        icon: Icons.stars,
        color: Colors.orange,
        category: 'Achievements',
        requirement: 2500,
        currentValue: totalAchievements,
        isEarned: totalAchievements >= 2500,
      ),
      Milestone(
        id: 'ach_5000',
        title: 'Legend',
        description: 'Unlock 5,000 achievements',
        icon: Icons.auto_awesome,
        color: Colors.deepOrange,
        category: 'Achievements',
        requirement: 5000,
        currentValue: totalAchievements,
        isEarned: totalAchievements >= 5000,
      ),
      Milestone(
        id: 'ach_10000',
        title: 'Mythic',
        description: 'Unlock 10,000 achievements',
        icon: Icons.auto_awesome,
        color: Colors.red,
        category: 'Achievements',
        requirement: 10000,
        currentValue: totalAchievements,
        isEarned: totalAchievements >= 10000,
      ),

      // Mastery milestones
      Milestone(
        id: 'master_first',
        title: 'Completionist',
        description: 'Master your first game',
        icon: Icons.emoji_events,
        color: Colors.purple,
        category: 'Mastery',
        requirement: 1,
        currentValue: masteredGames,
        isEarned: masteredGames >= 1,
      ),
      Milestone(
        id: 'master_5',
        title: 'Dedicated',
        description: 'Master 5 games',
        icon: Icons.emoji_events,
        color: Colors.purple,
        category: 'Mastery',
        requirement: 5,
        currentValue: masteredGames,
        isEarned: masteredGames >= 5,
      ),
      Milestone(
        id: 'master_10',
        title: 'Perfectionist',
        description: 'Master 10 games',
        icon: Icons.emoji_events,
        color: Colors.purple,
        category: 'Mastery',
        requirement: 10,
        currentValue: masteredGames,
        isEarned: masteredGames >= 10,
      ),
      Milestone(
        id: 'master_25',
        title: 'Champion',
        description: 'Master 25 games',
        icon: Icons.military_tech,
        color: Colors.deepPurple,
        category: 'Mastery',
        requirement: 25,
        currentValue: masteredGames,
        isEarned: masteredGames >= 25,
      ),
      Milestone(
        id: 'master_50',
        title: 'Grandmaster',
        description: 'Master 50 games',
        icon: Icons.military_tech,
        color: Colors.deepPurple,
        category: 'Mastery',
        requirement: 50,
        currentValue: masteredGames,
        isEarned: masteredGames >= 50,
      ),
      Milestone(
        id: 'master_100',
        title: 'Immortal',
        description: 'Master 100 games',
        icon: Icons.diamond,
        color: Colors.pink,
        category: 'Mastery',
        requirement: 100,
        currentValue: masteredGames,
        isEarned: masteredGames >= 100,
      ),

      // Points milestones
      Milestone(
        id: 'pts_1k',
        title: 'Rising Star',
        description: 'Earn 1,000 points',
        icon: Icons.trending_up,
        color: Colors.green,
        category: 'Points',
        requirement: 1000,
        currentValue: totalPoints,
        isEarned: totalPoints >= 1000,
      ),
      Milestone(
        id: 'pts_5k',
        title: 'Skilled',
        description: 'Earn 5,000 points',
        icon: Icons.trending_up,
        color: Colors.green,
        category: 'Points',
        requirement: 5000,
        currentValue: totalPoints,
        isEarned: totalPoints >= 5000,
      ),
      Milestone(
        id: 'pts_10k',
        title: 'Expert',
        description: 'Earn 10,000 points',
        icon: Icons.show_chart,
        color: Colors.teal,
        category: 'Points',
        requirement: 10000,
        currentValue: totalPoints,
        isEarned: totalPoints >= 10000,
      ),
      Milestone(
        id: 'pts_25k',
        title: 'Master',
        description: 'Earn 25,000 points',
        icon: Icons.show_chart,
        color: Colors.teal,
        category: 'Points',
        requirement: 25000,
        currentValue: totalPoints,
        isEarned: totalPoints >= 25000,
      ),
      Milestone(
        id: 'pts_50k',
        title: 'Prodigy',
        description: 'Earn 50,000 points',
        icon: Icons.insights,
        color: Colors.cyan,
        category: 'Points',
        requirement: 50000,
        currentValue: totalPoints,
        isEarned: totalPoints >= 50000,
      ),
      Milestone(
        id: 'pts_100k',
        title: 'Titan',
        description: 'Earn 100,000 points',
        icon: Icons.insights,
        color: Colors.blue,
        category: 'Points',
        requirement: 100000,
        currentValue: totalPoints,
        isEarned: totalPoints >= 100000,
      ),

      // Rank milestones
      if (rank > 0 && rank <= 10000)
        Milestone(
          id: 'rank_10k',
          title: 'Top 10,000',
          description: 'Reach top 10,000 globally',
          icon: Icons.leaderboard,
          color: Colors.indigo,
          category: 'Rank',
          requirement: 10000,
          currentValue: rank,
          isEarned: rank <= 10000,
        ),
      if (rank > 0 && rank <= 5000)
        Milestone(
          id: 'rank_5k',
          title: 'Top 5,000',
          description: 'Reach top 5,000 globally',
          icon: Icons.leaderboard,
          color: Colors.indigo,
          category: 'Rank',
          requirement: 5000,
          currentValue: rank,
          isEarned: rank <= 5000,
        ),
      if (rank > 0 && rank <= 1000)
        Milestone(
          id: 'rank_1k',
          title: 'Top 1,000',
          description: 'Reach top 1,000 globally',
          icon: Icons.workspace_premium,
          color: Colors.amber,
          category: 'Rank',
          requirement: 1000,
          currentValue: rank,
          isEarned: rank <= 1000,
        ),
      if (rank > 0 && rank <= 500)
        Milestone(
          id: 'rank_500',
          title: 'Top 500',
          description: 'Reach top 500 globally',
          icon: Icons.workspace_premium,
          color: Colors.orange,
          category: 'Rank',
          requirement: 500,
          currentValue: rank,
          isEarned: rank <= 500,
        ),
      if (rank > 0 && rank <= 100)
        Milestone(
          id: 'rank_100',
          title: 'Top 100',
          description: 'Reach top 100 globally',
          icon: Icons.diamond,
          color: Colors.red,
          category: 'Rank',
          requirement: 100,
          currentValue: rank,
          isEarned: rank <= 100,
        ),

      // True Points milestones
      Milestone(
        id: 'true_10k',
        title: 'True Gamer',
        description: 'Earn 10,000 true points',
        icon: Icons.verified,
        color: Colors.blue,
        category: 'True Points',
        requirement: 10000,
        currentValue: totalTruePoints,
        isEarned: totalTruePoints >= 10000,
      ),
      Milestone(
        id: 'true_50k',
        title: 'True Master',
        description: 'Earn 50,000 true points',
        icon: Icons.verified,
        color: Colors.blue,
        category: 'True Points',
        requirement: 50000,
        currentValue: totalTruePoints,
        isEarned: totalTruePoints >= 50000,
      ),
      Milestone(
        id: 'true_100k',
        title: 'True Legend',
        description: 'Earn 100,000 true points',
        icon: Icons.verified,
        color: Colors.lightBlue,
        category: 'True Points',
        requirement: 100000,
        currentValue: totalTruePoints,
        isEarned: totalTruePoints >= 100000,
      ),
    ];
  }

  void _showMilestoneDetail(Milestone milestone) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final progress = milestone.requirement > 0
            ? (milestone.currentValue / milestone.requirement).clamp(0.0, 1.0)
            : 0.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            24, 24, 24,
            24 + MediaQuery.of(ctx).viewPadding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: milestone.isEarned
                      ? milestone.color.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  milestone.icon,
                  size: 40,
                  color: milestone.isEarned ? milestone.color : Colors.grey,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                milestone.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                milestone.description,
                style: TextStyle(color: context.subtitleColor),
              ),
              const SizedBox(height: 8),

              // Category
              Chip(
                label: Text(milestone.category),
                backgroundColor: milestone.color.withValues(alpha: 0.1),
                labelStyle: TextStyle(color: milestone.color, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Progress
              if (!milestone.isEarned) ...[
                Text(
                  '${milestone.currentValue} / ${milestone.requirement}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation(milestone.color),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toInt()}% complete',
                  style: TextStyle(color: context.subtitleColor, fontSize: 12),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'EARNED',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShareCardScreen(
                          type: ShareCardType.achievement,
                          data: {
                            'Title': milestone.title,
                            'Description': milestone.description,
                            'Points': milestone.requirement,
                            'BadgeName': '',
                            'GameTitle': 'RetroTracker Milestone',
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share Milestone'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class Milestone {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String category;
  final int requirement;
  final int currentValue;
  final bool isEarned;

  Milestone({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.category,
    required this.requirement,
    required this.currentValue,
    required this.isEarned,
  });
}

class _MilestoneBadge extends StatelessWidget {
  final Milestone milestone;
  final VoidCallback onTap;

  const _MilestoneBadge({
    required this.milestone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: milestone.isEarned
              ? milestone.color.withValues(alpha: 0.15)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: milestone.isEarned
                ? milestone.color.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              milestone.icon,
              size: 32,
              color: milestone.isEarned ? milestone.color : Colors.grey,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                milestone.title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: milestone.isEarned ? null : Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!milestone.isEarned) ...[
              const SizedBox(height: 4),
              Icon(
                Icons.lock,
                size: 12,
                color: Colors.grey[500],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
