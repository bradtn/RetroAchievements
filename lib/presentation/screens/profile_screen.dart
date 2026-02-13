import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/ra_status_provider.dart';
import 'game_detail_screen.dart';
import 'user_compare_screen.dart';
import 'milestones/milestones_screen.dart';
import 'share_card/share_card_screen.dart';
import 'profile/profile_widgets.dart';
import 'friends/friends_provider.dart';

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
      final profile = results[0] as Map<String, dynamic>?;

      // Report API status
      if (profile != null) {
        ref.read(raStatusProvider.notifier).reportSuccess();
      } else {
        ref.read(raStatusProvider.notifier).reportFailure('Profile load failed');
      }

      setState(() {
        _profile = profile;
        _recentGames = results[1] as List<dynamic>?;
        _recentAchievements = results[2] as List<dynamic>?;
        _rankData = results[3] as Map<String, dynamic>?;
        _isLoading = false;
        if (_profile == null) {
          _error = ref.read(raStatusProvider.notifier).getErrorMessage(
            'Unable to load profile for ${widget.username}',
          );
        }
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
    final rankRaw = _rankData?['Rank'] ?? _rankData?['rank'] ?? 0;
    final rank = rankRaw is int ? rankRaw : int.tryParse(rankRaw?.toString() ?? '') ?? 0;

    final pointsInt = points is int ? points : int.tryParse(points.toString()) ?? 0;
    final truePointsInt = truePoints is int ? truePoints : int.tryParse(truePoints.toString()) ?? 0;

    return Row(
      children: [
        Expanded(
          child: AnimatedStatCard(
            icon: Icons.stars,
            targetValue: pointsInt,
            label: 'Points',
            color: Colors.amber,
            delay: 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedStatCard(
            icon: Icons.military_tech,
            targetValue: truePointsInt,
            label: 'True Points',
            color: Colors.purple,
            delay: 100,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedStatCard(
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
    final friendsState = ref.watch(friendsProvider);
    final isFriend = friendsState.isFriend(widget.username);

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
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserCompareScreen(compareUsername: widget.username),
                    ),
                  ),
                  icon: const Icon(Icons.compare_arrows, size: 18),
                  label: const Text('Compare'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: isFriend
                    ? OutlinedButton.icon(
                        onPressed: () => _removeFriend(),
                        icon: const Icon(Icons.person_remove, size: 18),
                        label: const Text('Remove Friend'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      )
                    : FilledButton.icon(
                        onPressed: () => _addFriend(),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Add Friend'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _addFriend() async {
    await ref.read(friendsProvider.notifier).addFriend(
      widget.username,
      userPic: _profile?['UserPic'],
      points: _profile?['TotalPoints'] is int
          ? _profile!['TotalPoints']
          : int.tryParse(_profile?['TotalPoints']?.toString() ?? ''),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${widget.username} to friends')),
      );
    }
  }

  void _removeFriend() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Remove ${widget.username} from your friends list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(friendsProvider.notifier).removeFriend(widget.username);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed ${widget.username} from friends')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
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

          return Padding(
            padding: EdgeInsets.only(right: i < _recentGames!.length - 1 ? 12 : 0),
            child: RecentGameTile(
              game: game,
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
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentAchievements() {
    final toShow = _recentAchievements!.take(5).toList();

    return Column(
      children: toShow.map((ach) {
        final achievement = ach as Map<String, dynamic>;
        final gameTitle = achievement['GameTitle'] ?? '';
        final gameId = achievement['GameID'] ?? 0;

        return RecentAchievementTile(
          achievement: achievement,
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
          onLongPress: () => _showAchievementDetails(achievement),
        );
      }).toList(),
    );
  }

  void _showAchievementDetails(Map<String, dynamic> achievement) {
    final title = achievement['Title'] ?? 'Achievement';
    final description = achievement['Description'] ?? '';
    final badgeName = achievement['BadgeName'] ?? '';
    final gameTitle = achievement['GameTitle'] ?? '';
    final gameId = achievement['GameID'] ?? 0;
    final points = achievement['Points'] ?? 0;
    final dateEarned = achievement['Date'] ?? achievement['DateEarned'] ?? '';

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
                      : const DefaultBadge(size: 64),
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
              Text(description, style: const TextStyle(fontSize: 15)),
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
                  'Earned ${formatProfileDate(dateEarned)}',
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
  }
}
