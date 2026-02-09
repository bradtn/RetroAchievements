import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';
import 'game_detail_screen.dart';
import 'user_compare_screen.dart';
import 'milestones_screen.dart';
import 'share_card_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String username;

  const ProfileScreen({super.key, required this.username});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _rankData;
  List<dynamic>? _recentGames;
  List<dynamic>? _recentAchievements;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final api = ref.read(apiDataSourceProvider);
    final results = await Future.wait([
      api.getUserProfile(widget.username),
      api.getRecentlyPlayedGames(widget.username, count: 10),
      api.getRecentAchievements(widget.username, count: 20),
      api.getUserRankAndScore(widget.username),
    ]);

    if (mounted) {
      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _recentGames = results[1] as List<dynamic>?;
        _recentAchievements = results[2] as List<dynamic>?;
        _rankData = results[3] as Map<String, dynamic>?;
        _isLoading = false;
        if (_profile == null) _error = 'Failed to load profile';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).username;
    final isOwnProfile = widget.username.toLowerCase() == currentUser?.toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwnProfile ? 'My Profile' : widget.username),
        actions: [
          if (!isOwnProfile)
            IconButton(
              icon: const Icon(Icons.compare_arrows),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserCompareScreen(compareUsername: widget.username),
                ),
              ),
              tooltip: 'Compare',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 16),
                      _buildStatsCards(),
                      const SizedBox(height: 16),
                      _buildActionButtons(isOwnProfile),
                      const SizedBox(height: 24),
                      if (_recentGames != null && _recentGames!.isNotEmpty) ...[
                        _buildSectionHeader('Recent Games', Icons.games),
                        const SizedBox(height: 8),
                        _buildRecentGames(),
                        const SizedBox(height: 24),
                      ],
                      if (_recentAchievements != null && _recentAchievements!.isNotEmpty) ...[
                        _buildSectionHeader('Recent Achievements', Icons.emoji_events),
                        const SizedBox(height: 8),
                        _buildRecentAchievements(),
                      ],
                      SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 16),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.subtitleColor),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final userPic = _profile?['UserPic'] ?? '';
    final motto = _profile?['Motto'] ?? '';
    final memberSince = _profile?['MemberSince'] ?? '';
    final richPresence = _profile?['RichPresenceMsg'] ?? 'Offline';
    final isOnline = !richPresence.toLowerCase().contains('offline');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: userPic.isNotEmpty
                          ? CachedNetworkImageProvider('https://retroachievements.org$userPic')
                          : null,
                      backgroundColor: Colors.grey[800],
                      child: userPic.isEmpty
                          ? Text(
                              widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).cardColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.username,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        richPresence,
                        style: TextStyle(
                          color: isOnline ? Colors.green : context.subtitleColor,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (motto.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '"$motto"',
                  style: TextStyle(
                    color: context.subtitleColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            if (memberSince.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Member since $memberSince',
                style: TextStyle(color: context.subtitleColor, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final points = _profile?['TotalPoints'] ?? 0;
    final truePoints = _profile?['TotalTruePoints'] ?? 0;
    // Rank comes from separate API call
    final rankRaw = _rankData?['Rank'] ?? _rankData?['rank'] ?? 0;
    final rank = rankRaw is int ? rankRaw : int.tryParse(rankRaw?.toString() ?? '') ?? 0;

    final pointsInt = points is int ? points : int.tryParse(points.toString()) ?? 0;
    final truePointsInt = truePoints is int ? truePoints : int.tryParse(truePoints.toString()) ?? 0;

    return Row(
      children: [
        Expanded(
          child: _AnimatedStatCard(
            icon: Icons.stars,
            targetValue: pointsInt,
            label: 'Points',
            color: Colors.amber,
            delay: 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AnimatedStatCard(
            icon: Icons.military_tech,
            targetValue: truePointsInt,
            label: 'True Points',
            color: Colors.purple,
            delay: 100,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AnimatedStatCard(
            icon: Icons.leaderboard,
            targetValue: rank,
            label: 'Rank',
            color: Colors.blue,
            delay: 200,
            isRank: true,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isOwnProfile) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MilestonesScreen(username: widget.username),
                  ),
                ),
                icon: const Icon(Icons.emoji_events, size: 18),
                label: const Text('Awards'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShareCardScreen(
                      type: ShareCardType.profile,
                      data: {
                        'Username': widget.username,
                        'UserPic': _profile?['UserPic'] ?? '',
                        'TotalPoints': _profile?['TotalPoints'] ?? 0,
                        'TotalTruePoints': _profile?['TotalTruePoints'] ?? 0,
                        'Rank': _rankData?['Rank'] ?? 0,
                        'Motto': _profile?['Motto'] ?? '',
                      },
                    ),
                  ),
                ),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
        if (!isOwnProfile) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserCompareScreen(compareUsername: widget.username),
                ),
              ),
              icon: const Icon(Icons.compare_arrows, size: 18),
              label: const Text('Compare With Me'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildRecentGames() {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recentGames!.length,
        itemBuilder: (ctx, i) {
          final game = _recentGames![i] as Map<String, dynamic>;
          final gameId = game['GameID'] ?? 0;
          final title = game['Title'] ?? 'Unknown';
          final imageIcon = game['ImageIcon'] ?? '';
          final consoleName = game['ConsoleName'] ?? '';
          final numAchieved = game['NumAchieved'] ?? game['NumAwarded'] ?? 0;
          final numTotal = game['NumPossibleAchievements'] ?? game['AchievementsPossible'] ?? 0;

          return GestureDetector(
            onTap: () {
              final id = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
              if (id > 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailScreen(gameId: id, gameTitle: title),
                  ),
                );
              }
            },
            child: Container(
              width: 110,
              margin: EdgeInsets.only(right: i < _recentGames!.length - 1 ? 12 : 0),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: 'https://retroachievements.org$imageIcon',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[800],
                        child: const Icon(Icons.games, size: 32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '$numAchieved / $numTotal',
                    style: TextStyle(fontSize: 10, color: context.subtitleColor),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentAchievements() {
    // Show first 5 achievements
    final toShow = _recentAchievements!.take(5).toList();

    return Column(
      children: toShow.map((ach) {
        final achievement = ach as Map<String, dynamic>;
        final title = achievement['Title'] ?? 'Achievement';
        final description = achievement['Description'] ?? '';
        final badgeName = achievement['BadgeName'] ?? '';
        final gameTitle = achievement['GameTitle'] ?? '';
        final gameId = achievement['GameID'] ?? 0;
        final points = achievement['Points'] ?? 0;
        final dateEarned = achievement['Date'] ?? achievement['DateEarned'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              final id = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
              if (id > 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailScreen(gameId: id, gameTitle: gameTitle),
                  ),
                );
              }
            },
            onLongPress: () {
              // Show achievement details on long press
              showModalBottomSheet(
                context: context,
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: badgeName.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 64,
                                    height: 64,
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.emoji_events, size: 32),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  gameTitle,
                                  style: TextStyle(
                                    color: context.subtitleColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          description,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$points points',
                              style: TextStyle(
                                color: Colors.amber[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Earned ${_formatDate(dateEarned)}',
                            style: TextStyle(color: context.subtitleColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            final id = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
                            if (id > 0) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GameDetailScreen(gameId: id, gameTitle: gameTitle),
                                ),
                              );
                            }
                          },
                          child: const Text('View Game'),
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(ctx).viewPadding.bottom),
                    ],
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: badgeName.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildDefaultBadge(),
                          )
                        : _buildDefaultBadge(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          gameTitle,
                          style: TextStyle(fontSize: 12, color: context.subtitleColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$points pts',
                                style: TextStyle(color: Colors.amber[600], fontSize: 10),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(dateEarned),
                              style: TextStyle(fontSize: 10, color: context.subtitleColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.subtitleColor),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDefaultBadge() {
    return Container(
      width: 44,
      height: 44,
      color: Colors.grey[800],
      child: const Icon(Icons.emoji_events, size: 22),
    );
  }

  String _formatNumber(dynamic num) {
    if (num == null) return '0';
    final n = int.tryParse(num.toString()) ?? 0;
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.month}/${date.day}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated stat card with count-up ticker effect
class _AnimatedStatCard extends StatefulWidget {
  final IconData icon;
  final int targetValue;
  final String label;
  final Color color;
  final int delay;
  final bool isRank;

  const _AnimatedStatCard({
    required this.icon,
    required this.targetValue,
    required this.label,
    required this.color,
    this.delay = 0,
    this.isRank = false,
  });

  @override
  State<_AnimatedStatCard> createState() => _AnimatedStatCardState();
}

class _AnimatedStatCardState extends State<_AnimatedStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // Start animation after delay
    Future.delayed(Duration(milliseconds: widget.delay + 300), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(widget.icon, color: widget.color, size: 24),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final currentValue = (_animation.value * widget.targetValue).round();
                String displayValue;

                if (widget.isRank) {
                  displayValue = widget.targetValue > 0 ? '#$currentValue' : '-';
                } else {
                  displayValue = _formatNumber(currentValue);
                }

                return Text(
                  displayValue,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: widget.color,
                  ),
                );
              },
            ),
            Text(
              widget.label,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
