import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium_gate.dart';
import 'compare/compare_widgets.dart';

export 'compare/compare_widgets.dart';

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
      body: PremiumGate(
        featureName: 'Compare Users',
        description: 'Go head-to-head with friends. Compare points, achievements, and rankings.',
        icon: Icons.compare_arrows,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16, 16, 16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
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
          child: ProfileAvatar(
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
          child: ProfileAvatar(
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
        ComparisonRow(
          label: 'Points',
          icon: Icons.stars,
          myValue: _myProfile!['TotalPoints'] ?? 0,
          otherValue: _otherProfile!['TotalPoints'] ?? 0,
        ),
        ComparisonRow(
          label: 'True Points',
          icon: Icons.military_tech,
          myValue: _myProfile!['TotalTruePoints'] ?? 0,
          otherValue: _otherProfile!['TotalTruePoints'] ?? 0,
        ),
        ComparisonRow(
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
          return CommonGameTile(myGame: myGame, otherGame: otherGame);
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
          style: TextStyle(color: context.subtitleColor),
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
                StatRow(
                  icon: Icons.stars,
                  label: 'Points',
                  value: '${_myProfile!['TotalPoints'] ?? 0}',
                  color: Colors.amber,
                ),
                StatRow(
                  icon: Icons.military_tech,
                  label: 'True Points',
                  value: '${_myProfile!['TotalTruePoints'] ?? 0}',
                  color: Colors.purple,
                ),
                StatRow(
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
