import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme_utils.dart';
import '../../../core/responsive_layout.dart';
import '../../providers/auth_provider.dart';
import '../share_card/share_card_screen.dart';
import 'milestone_data.dart';
import 'milestone_widgets.dart';

export 'milestone_data.dart';
export 'milestone_widgets.dart';

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

    final milestones = calculateMilestones(
      profile: _profile!,
      completedGames: _completedGames,
    );
    final earned = milestones.where((m) => m.isEarned).toList();
    final locked = milestones.where((m) => !m.isEarned).toList();

    // Get RA awards
    final visibleAwards = _userAwards?['VisibleUserAwards'] as List<dynamic>? ?? [];
    final totalAwardsCount = _userAwards?['TotalAwardsCount'] ?? 0;

    final isWidescreen = ResponsiveLayout.isWidescreen(context);
    // More columns and smaller badges for widescreen, also scale down for regular phones
    final gridColumns = isWidescreen ? 5 : 4;
    final gridSpacing = isWidescreen ? 8.0 : 8.0;
    final childAspectRatio = isWidescreen ? 0.9 : 0.9;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWidescreen ? 600 : double.infinity),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16, isWidescreen ? 8 : 16, 16,
            16 + MediaQuery.of(context).viewPadding.bottom,
          ),
          children: [
            // Real RA Awards Section
            if (visibleAwards.isNotEmpty) ...[
              RAAwardsSummary(
                totalAwards: totalAwardsCount,
                masteryCount: _userAwards?['MasteryAwardsCount'] ?? 0,
                beatenHardcore: _userAwards?['BeatenHardcoreAwardsCount'] ?? 0,
                beatenSoftcore: _userAwards?['BeatenSoftcoreAwardsCount'] ?? 0,
                eventAwards: _userAwards?['EventAwardsCount'] ?? 0,
                compact: true,
                onShare: () => _shareAwardsSummary(totalAwardsCount),
              ),
              SizedBox(height: isWidescreen ? 10 : 16),
              Text(
                'RetroAchievements Awards',
                style: isWidescreen
                    ? Theme.of(context).textTheme.titleSmall
                    : Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: isWidescreen ? 8 : 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: gridSpacing,
                  mainAxisSpacing: gridSpacing,
                ),
                itemCount: visibleAwards.length > 30 ? 30 : visibleAwards.length,
                itemBuilder: (ctx, i) => RAAwardBadge(
                  award: visibleAwards[i] as Map<String, dynamic>,
                  onTap: () => _showRAAwardDetail(visibleAwards[i] as Map<String, dynamic>),
                  compact: true,
                ),
              ),
              if (visibleAwards.length > 30)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '+ ${visibleAwards.length - 30} more awards',
                    style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(height: isWidescreen ? 16 : 32),
              const Divider(),
              SizedBox(height: isWidescreen ? 12 : 24),
            ],

            // App Goals Section
            GoalsSummary(
              completed: earned.length,
              total: milestones.length,
              compact: true,
              onShare: () => _shareGoalsSummary(earned.length, milestones.length),
            ),
            SizedBox(height: isWidescreen ? 8 : 12),
            Text(
              'Track your progress with app-exclusive goals',
              style: TextStyle(color: context.subtitleColor, fontSize: isWidescreen ? 11 : 13),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isWidescreen ? 12 : 24),

            // Completed goals
            if (earned.isNotEmpty) ...[
              Text(
                'Completed (${earned.length})',
                style: isWidescreen
                    ? Theme.of(context).textTheme.titleSmall
                    : Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: isWidescreen ? 8 : 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: gridSpacing,
                  mainAxisSpacing: gridSpacing,
                ),
                itemCount: earned.length,
                itemBuilder: (ctx, i) => MilestoneBadge(
                  milestone: earned[i],
                  onTap: () => _showMilestoneDetail(earned[i]),
                  compact: true,
                ),
              ),
              SizedBox(height: isWidescreen ? 16 : 32),
            ],

            // In Progress goals
            if (locked.isNotEmpty) ...[
              Text(
                'In Progress (${locked.length})',
                style: isWidescreen
                    ? Theme.of(context).textTheme.titleSmall
                    : Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: isWidescreen ? 4 : 8),
              Text(
                'Keep playing to complete these goals!',
                style: TextStyle(color: context.subtitleColor, fontSize: isWidescreen ? 11 : 13),
              ),
              SizedBox(height: isWidescreen ? 8 : 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: gridSpacing,
                  mainAxisSpacing: gridSpacing,
                ),
                itemCount: locked.length,
                itemBuilder: (ctx, i) => MilestoneBadge(
                  milestone: locked[i],
                  onTap: () => _showMilestoneDetail(locked[i]),
                  compact: true,
                ),
              ),
            ],
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

    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 340,
              maxHeight: screenHeight * 0.8,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Game icon - sized appropriately
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: awardColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: awardColor.withValues(alpha: 0.4),
                            blurRadius: 15,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(
                          'https://retroachievements.org$imageIcon',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[800],
                            child: Icon(awardIcon, size: 40, color: awardColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Award type badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: awardColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: awardColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(awardIcon, size: 14, color: awardColor),
                          const SizedBox(width: 4),
                          Text(
                            awardTypeName,
                            style: TextStyle(
                              color: awardColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Console
                    Text(
                      consoleName,
                      style: TextStyle(
                        color: context.subtitleColor,
                        fontSize: 12,
                      ),
                    ),

                    if (awardedAt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Awarded: ${_formatDate(awardedAt)}',
                        style: TextStyle(color: context.subtitleColor, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Buttons row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                                      'colorValue': awardColor.toARGB32(),
                                    },
                                  ),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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

  void _showMilestoneDetail(Milestone milestone) {
    showDialog(
      context: context,
      builder: (ctx) => MilestoneDetailDialog(
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
                  'colorValue': milestone.color.toARGB32(),
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

  void _shareAwardsSummary(int totalAwards) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareCardScreen(
          type: ShareCardType.awardsSummary,
          data: {
            'username': _viewingUsername ?? '',
            'userPic': _profile?['UserPic'] ?? '',
            'totalAwards': totalAwards,
            'masteryCount': _userAwards?['MasteryAwardsCount'] ?? 0,
            'beatenHardcore': _userAwards?['BeatenHardcoreAwardsCount'] ?? 0,
            'beatenSoftcore': _userAwards?['BeatenSoftcoreAwardsCount'] ?? 0,
            'eventAwards': _userAwards?['EventAwardsCount'] ?? 0,
          },
        ),
      ),
    );
  }

  void _shareGoalsSummary(int completed, int total) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareCardScreen(
          type: ShareCardType.goalsSummary,
          data: {
            'username': _viewingUsername ?? '',
            'userPic': _profile?['UserPic'] ?? '',
            'completed': completed,
            'total': total,
          },
        ),
      ),
    );
  }
}
