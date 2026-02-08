import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import '../../core/theme_utils.dart';
import '../../core/animations.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium_gate.dart';
import 'share_card_screen.dart';

class MilestonesScreen extends ConsumerStatefulWidget {
  final String? username;

  const MilestonesScreen({super.key, this.username});

  @override
  ConsumerState<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends ConsumerState<MilestonesScreen> {
  final _usernameController = TextEditingController();
  Map<String, dynamic>? _profile;
  List<dynamic>? _completedGames;
  Map<String, dynamic>? _userAwards;
  bool _isLoading = true;
  String? _viewingUsername;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Load specified user or current user's milestones by default
    final username = widget.username ?? ref.read(authProvider).username;
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
        api.getUserAwards(username),
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
        _userAwards = results[2] as Map<String, dynamic>?;
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
      body: PremiumGate(
        featureName: 'Milestones',
        description: 'Track personal achievements like total points, mastered games, and more.',
        icon: Icons.emoji_events,
        child: Column(
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
          if (!isViewingMyself && _viewingUsername != null && _profile != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // User avatar
                    ClipOval(
                      child: Image.network(
                        'https://retroachievements.org${_profile!['UserPic'] ?? ''}',
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 36,
                          height: 36,
                          color: Colors.grey[700],
                          child: Center(
                            child: Text(
                              _viewingUsername![0].toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _viewingUsername!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Viewing milestones',
                            style: TextStyle(color: context.subtitleColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loadMyMilestones,
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'View my milestones',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),

          if (!isViewingMyself && _viewingUsername != null && _profile != null)
            const SizedBox(height: 8),

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

    // Get RA awards
    final visibleAwards = _userAwards?['VisibleUserAwards'] as List<dynamic>? ?? [];
    final totalAwardsCount = _userAwards?['TotalAwardsCount'] ?? 0;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16, 16, 16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      children: [
        // Real RA Awards Section
        if (visibleAwards.isNotEmpty) ...[
          _buildRAAwradsSummary(totalAwardsCount),
          const SizedBox(height: 16),
          Text(
            'RetroAchievements Awards',
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
            itemCount: visibleAwards.length > 30 ? 30 : visibleAwards.length,
            itemBuilder: (ctx, i) => _RAAwardBadge(
              award: visibleAwards[i] as Map<String, dynamic>,
              onTap: () => _showRAAwardDetail(visibleAwards[i] as Map<String, dynamic>),
            ),
          ),
          if (visibleAwards.length > 30)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${visibleAwards.length - 30} more awards',
                style: TextStyle(color: context.subtitleColor, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
        ],

        // App Goals Section
        _buildGoalsSummary(earned.length, milestones.length),
        const SizedBox(height: 12),
        Text(
          'Track your progress with app-exclusive goals',
          style: TextStyle(color: context.subtitleColor, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Completed goals
        if (earned.isNotEmpty) ...[
          Text(
            'Completed (${earned.length})',
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

        // In Progress goals
        if (locked.isNotEmpty) ...[
          Text(
            'In Progress (${locked.length})',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Keep playing to complete these goals!',
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

  Widget _buildRAAwradsSummary(int totalAwards) {
    final masteryCount = _userAwards?['MasteryAwardsCount'] ?? 0;
    final beatenHardcore = _userAwards?['BeatenHardcoreAwardsCount'] ?? 0;
    final beatenSoftcore = _userAwards?['BeatenSoftcoreAwardsCount'] ?? 0;
    final eventAwards = _userAwards?['EventAwardsCount'] ?? 0;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade700,
              Colors.purple.shade800,
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.military_tech, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                Text(
                  '$totalAwards',
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
              'RetroAchievements Awards',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AwardStat(icon: Icons.workspace_premium, value: masteryCount, label: 'Mastery'),
                _AwardStat(icon: Icons.verified, value: beatenHardcore, label: 'Beaten HC'),
                _AwardStat(icon: Icons.check_circle, value: beatenSoftcore, label: 'Beaten'),
                if (eventAwards > 0)
                  _AwardStat(icon: Icons.celebration, value: eventAwards, label: 'Events'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRAAwardDetail(Map<String, dynamic> award) {
    final title = award['Title'] ?? 'Award';
    final consoleName = award['ConsoleName'] ?? '';
    final awardType = award['AwardType'] ?? '';
    final awardedAt = award['AwardedAt'] ?? '';
    final imageIcon = award['ImageIcon'] ?? '';

    // Determine award type name
    String awardTypeName;
    Color awardColor;
    IconData awardIcon;

    switch (awardType) {
      case 'Mastery/Completion':
        awardTypeName = 'Mastery';
        awardColor = Colors.amber;
        awardIcon = Icons.workspace_premium;
        break;
      case 'Game Beaten':
        final isHardcore = award['AwardDataExtra'] == 1;
        awardTypeName = isHardcore ? 'Beaten (Hardcore)' : 'Beaten';
        awardColor = isHardcore ? Colors.orange : Colors.green;
        awardIcon = Icons.verified;
        break;
      default:
        awardTypeName = awardType.toString();
        awardColor = Colors.blue;
        awardIcon = Icons.emoji_events;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Game icon - larger and centered
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: awardColor, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: awardColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        'https://retroachievements.org$imageIcon',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[800],
                          child: Icon(awardIcon, size: 48, color: awardColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Award type badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: awardColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: awardColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(awardIcon, size: 16, color: awardColor),
                        const SizedBox(width: 6),
                        Text(
                          awardTypeName,
                          style: TextStyle(
                            color: awardColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  // Console
                  Text(
                    consoleName,
                    style: TextStyle(
                      color: context.subtitleColor,
                      fontSize: 14,
                    ),
                  ),

                  if (awardedAt.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Awarded: ${_formatDate(awardedAt)}',
                      style: TextStyle(color: context.subtitleColor, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Buttons row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShareCardScreen(
                                  type: ShareCardType.raAward,
                                  data: {
                                    'title': title,
                                    'consoleName': consoleName,
                                    'awardType': awardTypeName,
                                    'imageIcon': imageIcon,
                                    'awardedAt': awardedAt,
                                    'username': _viewingUsername ?? '',
                                    'userPic': _profile?['UserPic'] ?? '',
                                    'colorValue': awardColor.value,
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildGoalsSummary(int completed, int total) {
    final progress = total > 0 ? completed / total : 0.0;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.teal.shade600,
              Colors.green.shade700,
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flag, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                Text(
                  '$completed / $total',
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
              'RetroTracker Goals',
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
    showDialog(
      context: context,
      builder: (ctx) => _MilestoneDetailDialog(
        milestone: milestone,
        viewingUsername: _viewingUsername,
        userPic: _profile?['UserPic'] ?? '',
        onShare: () {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShareCardScreen(
                type: ShareCardType.milestone,
                data: {
                  'title': milestone.title,
                  'description': milestone.description,
                  'category': milestone.category,
                  'username': _viewingUsername ?? '',
                  'userPic': _profile?['UserPic'] ?? '',
                  'iconCode': milestone.icon.codePoint,
                  'colorValue': milestone.color.value,
                  'isEarned': milestone.isEarned,
                  'currentValue': milestone.currentValue,
                  'requirement': milestone.requirement,
                },
              ),
            ),
          );
        },
      ),
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

class _MilestoneDetailDialog extends StatefulWidget {
  final Milestone milestone;
  final String? viewingUsername;
  final String userPic;
  final VoidCallback onShare;

  const _MilestoneDetailDialog({
    required this.milestone,
    required this.viewingUsername,
    required this.userPic,
    required this.onShare,
  });

  @override
  State<_MilestoneDetailDialog> createState() => _MilestoneDetailDialogState();
}

class _MilestoneDetailDialogState extends State<_MilestoneDetailDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));

    // Auto-trigger confetti for earned milestones
    if (widget.milestone.isEarned) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _confettiController.play();
        }
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final milestone = widget.milestone;
    final progress = milestone.requirement > 0
        ? (milestone.currentValue / milestone.requirement).clamp(0.0, 1.0)
        : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge icon with celebration animation
                  if (milestone.isEarned)
                    CelebrationBadge(
                      celebrate: true,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: milestone.color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: milestone.color.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          milestone.icon,
                          size: 36,
                          color: milestone.color,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: milestone.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: milestone.color.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        milestone.icon,
                        size: 36,
                        color: milestone.color.withValues(alpha: 0.7),
                      ),
                    ),
                  const SizedBox(height: 14),

                  // Title
                  Text(
                    milestone.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Description
                  Text(
                    milestone.description,
                    style: TextStyle(color: context.subtitleColor, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: milestone.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      milestone.category,
                      style: TextStyle(color: milestone.color, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Progress or earned status
                  if (!milestone.isEarned) ...[
                    AnimatedCounter(
                      value: milestone.currentValue,
                      suffix: ' / ${milestone.requirement}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedProgressBar(
                      progress: progress,
                      color: milestone.color,
                      backgroundColor: Colors.grey,
                      height: 8,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(progress * 100).toInt()}% complete',
                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: widget.onShare,
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'EARNED',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: widget.onShare,
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Confetti overlay for earned milestones
            if (milestone.isEarned)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    colors: [
                      milestone.color,
                      milestone.color.withValues(alpha: 0.7),
                      Colors.amber,
                      Colors.orange,
                      Colors.yellow,
                    ],
                    numberOfParticles: 20,
                    maxBlastForce: 15,
                    minBlastForce: 5,
                    emissionFrequency: 0.05,
                    gravity: 0.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
    final progress = milestone.requirement > 0
        ? (milestone.currentValue / milestone.requirement).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = (progress * 100).toInt();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: milestone.color.withValues(alpha: milestone.isEarned ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: milestone.color.withValues(alpha: milestone.isEarned ? 0.5 : 0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (milestone.isEarned) ...[
              // Earned: just show the icon
              Icon(
                milestone.icon,
                size: 32,
                color: milestone.color,
              ),
            ] else ...[
              // Not earned: show icon with circular progress
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background circle
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 3,
                      color: milestone.color.withValues(alpha: 0.15),
                    ),
                    // Progress circle
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      color: milestone.color.withValues(alpha: 0.8),
                      backgroundColor: Colors.transparent,
                    ),
                    // Icon in center
                    Icon(
                      milestone.icon,
                      size: 20,
                      color: milestone.color.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                milestone.title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: milestone.isEarned ? null : milestone.color.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!milestone.isEarned) ...[
              const SizedBox(height: 2),
              Text(
                '$progressPercent%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: milestone.color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RAAwardBadge extends StatelessWidget {
  final Map<String, dynamic> award;
  final VoidCallback onTap;

  const _RAAwardBadge({
    required this.award,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = award['Title'] ?? 'Award';
    final imageIcon = award['ImageIcon'] ?? '';
    final awardType = award['AwardType'] ?? '';

    // Determine border color based on award type
    Color borderColor;
    switch (awardType) {
      case 'Mastery/Completion':
        borderColor = Colors.amber;
        break;
      case 'Game Beaten':
        final isHardcore = award['AwardDataExtra'] == 1;
        borderColor = isHardcore ? Colors.orange : Colors.green;
        break;
      default:
        borderColor = Colors.blue;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: borderColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                'https://retroachievements.org$imageIcon',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: Colors.grey[800],
                  child: Icon(Icons.emoji_events, color: borderColor, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AwardStat extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;

  const _AwardStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
