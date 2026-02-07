import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';

class UserCompareScreen extends ConsumerStatefulWidget {
  final String? compareUsername;

  const UserCompareScreen({super.key, this.compareUsername});

  @override
  ConsumerState<UserCompareScreen> createState() => _UserCompareScreenState();
}

class _UserCompareScreenState extends ConsumerState<UserCompareScreen> {
  final _usernameController = TextEditingController();
  Map<String, dynamic>? _myProfile;
  Map<String, dynamic>? _otherProfile;
  bool _isLoadingMe = true;
  bool _isLoadingOther = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();

    // If a username was passed, pre-fill and auto-search
    if (widget.compareUsername != null && widget.compareUsername!.isNotEmpty) {
      _usernameController.text = widget.compareUsername!;
      // Delay search until after build
      Future.microtask(() => _searchUser());
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadMyProfile() async {
    final api = ref.read(apiDataSourceProvider);
    final username = ref.read(authProvider).username;
    if (username != null) {
      final profile = await api.getUserSummary(username, recentGames: 5, recentAchievements: 10);
      setState(() {
        _myProfile = profile;
        _isLoadingMe = false;
      });
    }
  }

  Future<void> _searchUser() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _isLoadingOther = true;
      _error = null;
    });

    final api = ref.read(apiDataSourceProvider);
    final profile = await api.getUserSummary(username, recentGames: 5, recentAchievements: 10);

    setState(() {
      _isLoadingOther = false;
      if (profile == null) {
        _error = 'User "$username" not found';
        _otherProfile = null;
      } else {
        _otherProfile = profile;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Users'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Search bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: 'Enter username to compare...',
                    prefixIcon: const Icon(Icons.person_search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                  onSubmitted: (_) => _searchUser(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isLoadingOther ? null : _searchUser,
                child: _isLoadingOther
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Compare'),
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.red.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Comparison view
          if (_myProfile != null && _otherProfile != null) ...[
            _buildComparisonHeader(),
            const SizedBox(height: 24),
            _buildComparisonStats(),
          ] else if (_myProfile != null && _otherProfile == null && !_isLoadingOther) ...[
            // Show just my profile with placeholder
            _buildSingleProfileView(),
          ] else if (_isLoadingMe) ...[
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonHeader() {
    final myPic = 'https://retroachievements.org${_myProfile!['UserPic']}';
    final otherPic = 'https://retroachievements.org${_otherProfile!['UserPic']}';
    final myName = _myProfile!['User'] ?? 'Me';
    final otherName = _otherProfile!['User'] ?? 'Other';

    return Row(
      children: [
        Expanded(
          child: _ProfileAvatar(
            imageUrl: myPic,
            name: myName,
            label: 'YOU',
            color: Colors.blue,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Text(
            'VS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          child: _ProfileAvatar(
            imageUrl: otherPic,
            name: otherName,
            label: 'OPPONENT',
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonStats() {
    return Column(
      children: [
        _ComparisonRow(
          label: 'Points',
          icon: Icons.stars,
          myValue: _myProfile!['TotalPoints'] ?? 0,
          otherValue: _otherProfile!['TotalPoints'] ?? 0,
        ),
        _ComparisonRow(
          label: 'True Points',
          icon: Icons.military_tech,
          myValue: _myProfile!['TotalTruePoints'] ?? 0,
          otherValue: _otherProfile!['TotalTruePoints'] ?? 0,
        ),
        _ComparisonRow(
          label: 'Softcore Points',
          icon: Icons.star_border,
          myValue: _myProfile!['TotalSoftcorePoints'] ?? 0,
          otherValue: _otherProfile!['TotalSoftcorePoints'] ?? 0,
        ),
        const Divider(height: 32),
        _buildRecentGamesComparison(),
      ],
    );
  }

  Widget _buildRecentGamesComparison() {
    final myGames = _myProfile!['RecentlyPlayed'] as List<dynamic>? ?? [];
    final otherGames = _otherProfile!['RecentlyPlayed'] as List<dynamic>? ?? [];

    // Find common games
    final myGameIds = myGames.map((g) => g['GameID'].toString()).toSet();
    final otherGameIds = otherGames.map((g) => g['GameID'].toString()).toSet();
    final commonIds = myGameIds.intersection(otherGameIds);

    if (commonIds.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info, color: Colors.grey[400]),
              const SizedBox(width: 12),
              const Text('No recently played games in common'),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Games in Common (${commonIds.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...commonIds.take(5).map((gameId) {
          final myGame = myGames.firstWhere((g) => g['GameID'].toString() == gameId);
          final otherGame = otherGames.firstWhere((g) => g['GameID'].toString() == gameId);
          return _CommonGameTile(myGame: myGame, otherGame: otherGame);
        }),
      ],
    );
  }

  Widget _buildSingleProfileView() {
    return Column(
      children: [
        Icon(
          Icons.people_outline,
          size: 80,
          color: Colors.grey[600],
        ),
        const SizedBox(height: 16),
        Text(
          'Enter a username above to compare stats',
          style: TextStyle(color: Colors.grey[400]),
        ),
        const SizedBox(height: 32),
        // Show my stats as preview
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Stats',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _StatRow(
                  icon: Icons.stars,
                  label: 'Points',
                  value: '${_myProfile!['TotalPoints'] ?? 0}',
                  color: Colors.amber,
                ),
                _StatRow(
                  icon: Icons.military_tech,
                  label: 'True Points',
                  value: '${_myProfile!['TotalTruePoints'] ?? 0}',
                  color: Colors.purple,
                ),
                _StatRow(
                  icon: Icons.star_border,
                  label: 'Softcore Points',
                  value: '${_myProfile!['TotalSoftcorePoints'] ?? 0}',
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String label;
  final Color color;

  const _ProfileAvatar({
    required this.imageUrl,
    required this.name,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        CircleAvatar(
          radius: 40,
          backgroundImage: CachedNetworkImageProvider(imageUrl),
          onBackgroundImageError: (_, __) {},
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final dynamic myValue;
  final dynamic otherValue;

  const _ComparisonRow({
    required this.label,
    required this.icon,
    required this.myValue,
    required this.otherValue,
  });

  @override
  Widget build(BuildContext context) {
    final my = int.tryParse(myValue.toString()) ?? 0;
    final other = int.tryParse(otherValue.toString()) ?? 0;
    final diff = my - other;
    final winner = my > other ? 'me' : (other > my ? 'other' : 'tie');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // My value
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: winner == 'me'
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: winner == 'me'
                      ? Border.all(color: Colors.green.withValues(alpha: 0.3))
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      _formatNumber(my),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: winner == 'me' ? Colors.green : null,
                      ),
                    ),
                    if (winner == 'me' && diff > 0)
                      Text(
                        '+${_formatNumber(diff)}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Icon(icon, size: 20, color: Colors.grey),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Other value
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: winner == 'other'
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: winner == 'other'
                      ? Border.all(color: Colors.red.withValues(alpha: 0.3))
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      _formatNumber(other),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: winner == 'other' ? Colors.red : null,
                      ),
                    ),
                    if (winner == 'other' && -diff > 0)
                      Text(
                        '+${_formatNumber(-diff)}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    } else if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }
}

class _CommonGameTile extends StatelessWidget {
  final dynamic myGame;
  final dynamic otherGame;

  const _CommonGameTile({
    required this.myGame,
    required this.otherGame,
  });

  @override
  Widget build(BuildContext context) {
    final title = myGame['Title'] ?? 'Unknown';
    final imageIcon = myGame['ImageIcon'] ?? '';

    final myAch = myGame['NumAchieved'] ?? 0;
    final otherAch = otherGame['NumAchieved'] ?? 0;
    final total = myGame['NumPossibleAchievements'] ?? 0;

    final myPct = total > 0 ? (myAch / total * 100).toInt() : 0;
    final otherPct = total > 0 ? (otherAch / total * 100).toInt() : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: 'https://retroachievements.org$imageIcon',
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$myPct%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: myPct > otherPct ? Colors.green : null,
                              ),
                            ),
                            LinearProgressIndicator(
                              value: myPct / 100,
                              backgroundColor: Colors.grey[700],
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '$otherPct%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: otherPct > myPct ? Colors.red : null,
                              ),
                            ),
                            LinearProgressIndicator(
                              value: otherPct / 100,
                              backgroundColor: Colors.grey[700],
                              color: Colors.red,
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
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
