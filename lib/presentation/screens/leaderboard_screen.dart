import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/responsive_layout.dart';
import '../providers/auth_provider.dart';
import 'profile_screen.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  List<dynamic>? _topUsers;
  Map<String, dynamic>? _myRank;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final api = ref.read(apiDataSourceProvider);
    final username = ref.read(authProvider).username;

    final results = await Future.wait([
      api.getTopUsers(),
      if (username != null) api.getUserRankAndScore(username),
    ]);

    setState(() {
      _topUsers = results[0] as List<dynamic>?;
      if (results.length > 1) {
        _myRank = results[1] as Map<String, dynamic>?;
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboards'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: ResponsiveLayout.isWidescreen(context) ? 600 : double.infinity,
                  ),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16, 16, 16,
                      16 + MediaQuery.of(context).viewPadding.bottom,
                    ),
                    children: [
                      // My Rank Card
                      if (_myRank != null) _buildMyRankCard(),
                      const SizedBox(height: 24),

                      // Top 10 Header
                      Row(
                        children: [
                          const Icon(Icons.emoji_events, color: Colors.amber),
                          const SizedBox(width: 8),
                          Text(
                            'Top 10 Players',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Top 10 List with shuffle animation
                      if (_topUsers != null && _topUsers!.isNotEmpty)
                        _AnimatedLeaderboardList(users: _topUsers!)
                      else
                        const Center(child: Text('No leaderboard data')),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMyRankCard() {
    final rankRaw = _myRank!['Rank'];
    final rank = rankRaw is int ? rankRaw : int.tryParse(rankRaw?.toString() ?? '') ?? 0;
    final score = _myRank!['Score'] ?? 0;
    final truePoints = _myRank!['TruePoints'] ?? 0;
    final isUnranked = rank == 0;
    final isLightMode = Theme.of(context).brightness == Brightness.light;

    // Determine colors based on rank tier
    List<Color> gradientColors;
    Color accentColor;
    if (isUnranked) {
      gradientColors = isLightMode
          ? [Colors.grey.shade300, Colors.grey.shade200]
          : [Colors.grey.shade800, Colors.grey.shade700];
      accentColor = Colors.grey;
    } else if (rank <= 10) {
      // Top 10 - Gold theme
      gradientColors = isLightMode
          ? [Colors.amber.shade200, Colors.amber.shade100]
          : [Colors.amber.shade900, Colors.amber.shade800];
      accentColor = Colors.amber;
    } else if (rank <= 100) {
      // Top 100 - Purple theme
      gradientColors = isLightMode
          ? [Colors.deepPurple.shade200, Colors.deepPurple.shade100]
          : [Colors.deepPurple.shade800, Colors.deepPurple.shade700];
      accentColor = Colors.deepPurple;
    } else if (rank <= 1000) {
      // Top 1000 - Blue theme
      gradientColors = isLightMode
          ? [Colors.blue.shade200, Colors.blue.shade100]
          : [Colors.blue.shade800, Colors.blue.shade700];
      accentColor = Colors.blue;
    } else {
      // Default - Teal theme
      gradientColors = isLightMode
          ? [Colors.teal.shade200, Colors.teal.shade100]
          : [Colors.teal.shade800, Colors.teal.shade700];
      accentColor = Colors.teal;
    }

    final textColor = isLightMode ? Colors.grey.shade800 : Colors.white;
    final subtleTextColor = isLightMode ? Colors.grey.shade600 : Colors.white70;

    return Card(
      elevation: isLightMode ? 2 : 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          border: isLightMode
              ? Border.all(color: accentColor.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isUnranked ? Icons.hourglass_empty : Icons.leaderboard,
                  size: 16,
                  color: subtleTextColor,
                ),
                const SizedBox(width: 6),
                Text(
                  isUnranked ? 'Not Ranked Yet' : 'Your Global Rank',
                  style: TextStyle(
                    color: subtleTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isUnranked)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Icon(Icons.emoji_events_outlined, color: subtleTextColor, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'Earn achievements to get ranked!',
                      style: TextStyle(color: subtleTextColor, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '#',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$rank',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: (isLightMode ? Colors.white : Colors.black).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ThemedStatItem(
                    icon: Icons.stars,
                    label: 'Points',
                    value: _formatNumber(score),
                    color: Colors.amber,
                    textColor: textColor,
                    subtleColor: subtleTextColor,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: subtleTextColor.withValues(alpha: 0.3),
                  ),
                  _ThemedStatItem(
                    icon: Icons.military_tech,
                    label: 'True Points',
                    value: _formatNumber(truePoints),
                    color: Colors.purple,
                    textColor: textColor,
                    subtleColor: subtleTextColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
}

class _ThemedStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color textColor;
  final Color subtleColor;

  const _ThemedStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
    required this.subtleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: subtleColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

/// Animated leaderboard list with staggered float-in effect
class _AnimatedLeaderboardList extends StatefulWidget {
  final List<dynamic> users;

  const _AnimatedLeaderboardList({required this.users});

  @override
  State<_AnimatedLeaderboardList> createState() => _AnimatedLeaderboardListState();
}

class _AnimatedLeaderboardListState extends State<_AnimatedLeaderboardList>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _slideAnimations;
  late List<Animation<double>> _fadeAnimations;
  late List<Animation<double>> _scaleAnimations;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      widget.users.length,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _slideAnimations = _controllers.map((c) =>
      Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOutBack),
      ),
    ).toList();

    _fadeAnimations = _controllers.map((c) =>
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
      ),
    ).toList();

    _scaleAnimations = _controllers.map((c) =>
      Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOutBack),
      ),
    ).toList();

    // Stagger the animations
    _startStaggeredAnimation();
  }

  void _startStaggeredAnimation() async {
    await Future.delayed(const Duration(milliseconds: 200));
    for (int i = 0; i < _controllers.length; i++) {
      if (!mounted) return;
      _controllers[i].forward();
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(widget.users.length, (index) {
        final user = widget.users[index];
        final rank = index + 1;

        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_slideAnimations[index].value * 100, 0),
              child: Transform.scale(
                scale: _scaleAnimations[index].value,
                child: Opacity(
                  opacity: _fadeAnimations[index].value,
                  child: child,
                ),
              ),
            );
          },
          child: _buildLeaderboardTile(context, rank, user),
        );
      }),
    );
  }

  Widget _buildLeaderboardTile(BuildContext context, int rank, dynamic user) {
    final username = user['1'] ?? 'Unknown';
    final points = user['2'] ?? 0;
    final truePoints = user['3'] ?? 0;

    Color? rankColor;
    IconData? rankIcon;
    if (rank == 1) {
      rankColor = Colors.amber;
      rankIcon = Icons.looks_one;
    } else if (rank == 2) {
      rankColor = Colors.grey.shade400;
      rankIcon = Icons.looks_two;
    } else if (rank == 3) {
      rankColor = Colors.orange.shade700;
      rankIcon = Icons.looks_3;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProfileScreen(username: username),
            ),
          );
        },
        leading: rank <= 3
            ? Icon(rankIcon, color: rankColor, size: 32)
            : CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade800,
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: 'https://retroachievements.org/UserPic/$username.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade700,
                  child: Text(username[0].toUpperCase()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                username,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 44),
          child: Row(
            children: [
              Icon(Icons.stars, size: 14, color: Colors.amber[400]),
              const SizedBox(width: 4),
              Text('$points'),
              const SizedBox(width: 12),
              Icon(Icons.military_tech, size: 14, color: Colors.purple[300]),
              const SizedBox(width: 4),
              Text('$truePoints'),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}
