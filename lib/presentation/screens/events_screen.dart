import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme_utils.dart';
import '../../core/responsive_layout.dart';
import '../../services/notification_service.dart';
import '../providers/auth_provider.dart';
import 'game_detail_screen.dart';
import 'profile_screen.dart';
import 'share_card/share_card_screen.dart';

/// Combined screen for Achievement of the Week and Achievement of the Month
/// Simply wraps the existing screen content with tabs
class EventsScreen extends ConsumerStatefulWidget {
  final int initialTab; // 0 = Weekly, 1 = Monthly

  const EventsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
            Tab(text: 'Roulette'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AotwTabContent(),
          _AotmTabContent(),
          _RouletteTabContent(),
        ],
      ),
    );
  }
}

// ============================================================================
// AOTW Tab Content - exact copy of AchievementOfTheWeekScreen body
// ============================================================================

class _AotwTabContent extends ConsumerStatefulWidget {
  const _AotwTabContent();

  @override
  ConsumerState<_AotwTabContent> createState() => _AotwTabContentState();
}

class _AotwTabContentState extends ConsumerState<_AotwTabContent> {
  Map<String, dynamic>? _aotwData;
  Map<String, dynamic>? _gameDetails;
  bool _isLoading = true;
  String? _error;
  bool _userHasEarned = false;
  String? _userEarnedDate;

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

    // Fetch game details with user progress to check if user earned the achievement
    Map<String, dynamic>? gameDetails;
    bool userHasEarned = false;
    String? userEarnedDate;

    if (data != null) {
      final game = data['Game'] as Map<String, dynamic>?;
      final achievement = data['Achievement'] as Map<String, dynamic>?;
      final gameId = game?['ID'];
      final achievementId = achievement?['ID']?.toString();
      final currentUsername = ref.read(authProvider).username?.toLowerCase() ?? '';

      if (gameId != null) {
        final id = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
        if (id > 0) {
          // Get game info with user progress - this tells us which achievements user has earned
          gameDetails = await api.getGameInfoWithProgress(id);

          // Check if user has earned this specific achievement
          if (gameDetails != null && achievementId != null) {
            final achievements = gameDetails['Achievements'] as Map<String, dynamic>?;
            if (achievements != null) {
              final achData = achievements[achievementId];
              if (achData is Map<String, dynamic>) {
                // Check if DateEarned or DateEarnedHardcore is set
                final dateEarned = achData['DateEarned'] ?? achData['DateEarnedHardcore'];
                if (dateEarned != null && dateEarned.toString().isNotEmpty) {
                  userHasEarned = true;
                  userEarnedDate = _formatDateTime(dateEarned.toString());
                }
              }
            }
          }
        }
      }

      // Fallback: Check AOTW Unlocks list if game progress API didn't show earned
      // (handles RA API sync issues where unlock appears in AOTW but not game progress)
      if (!userHasEarned && currentUsername.isNotEmpty) {
        final unlocks = data['Unlocks'] as List<dynamic>? ?? [];
        for (final unlock in unlocks) {
          if (unlock is Map<String, dynamic>) {
            final unlockUser = (unlock['User'] as String?)?.toLowerCase() ?? '';
            if (unlockUser == currentUsername) {
              userHasEarned = true;
              final dateAwarded = unlock['DateAwarded'];
              if (dateAwarded != null) {
                userEarnedDate = _formatDateTime(dateAwarded.toString());
              }
              break;
            }
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _aotwData = data;
        _gameDetails = gameDetails;
        _userHasEarned = userHasEarned;
        _userEarnedDate = userEarnedDate;
        _isLoading = false;
        if (data == null) _error = 'Failed to load Achievement of the Week';
      });
    }

    // Mark as viewed and clear badge/notification
    if (data != null) {
      final achievement = data['Achievement'] as Map<String, dynamic>?;
      final achievementId = achievement?['ID']?.toString() ?? '';
      if (achievementId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_viewed_aotw_id', achievementId);
        await NotificationService().clearAotwBadge();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final endAt = _calculateEndDate(_aotwData!['StartAt']);
    final unlocks = _aotwData!['Unlocks'] as List<dynamic>? ?? [];
    final totalPlayers = _aotwData!['TotalPlayers'] ?? 0;
    final unlocksCount = _aotwData!['UnlocksCount'] ?? unlocks.length;

    if (achievement == null || game == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No active Achievement of the Week'),
            const SizedBox(height: 8),
            Text('Pull down to refresh', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ],
        ),
      );
    }

    final achTitle = achievement['Title'] ?? 'Achievement';
    final achDesc = achievement['Description'] ?? '';
    final achPoints = achievement['Points'] ?? 0;
    final achTrueRatio = achievement['TrueRatio'] ?? 0;
    final badgeName = achievement['BadgeName'] ?? '';

    final gameTitle = game['Title'] ?? 'Unknown Game';
    final gameId = game['ID'];
    final gameIcon = _gameDetails?['ImageIcon'] ?? _gameDetails?['ImageBoxArt'] ?? '';
    final consoleName = console?['Title'] ?? _gameDetails?['ConsoleName'] ?? '';

    final unlockRate = totalPlayers > 0
        ? (unlocksCount / totalPlayers * 100).toStringAsFixed(1)
        : '0.0';

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final isWidescreen = ResponsiveLayout.isWidescreen(context);

    final headerPadding = isWidescreen ? 16.0 : 24.0;
    final headerIconSize = isWidescreen ? 32.0 : 48.0;
    final badgeSize = isWidescreen ? 64.0 : 96.0;
    final contentPadding = isWidescreen ? 14.0 : 20.0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWidescreen ? 600 : double.infinity),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, isWidescreen ? 8 : 16, 16, 16 + bottomPadding),
            children: [
              // Achievement Card
              Card(
                child: Column(
                  children: [
                    // Header with gradient
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(headerPadding),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        gradient: LinearGradient(
                          colors: [Colors.amber.shade700, Colors.orange.shade800],
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.emoji_events, color: Colors.white, size: headerIconSize),
                          SizedBox(height: isWidescreen ? 4 : 8),
                          Text(
                            'ACHIEVEMENT OF THE WEEK',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: isWidescreen ? 12 : 14,
                            ),
                          ),
                          if (startAt.isNotEmpty || endAt.isNotEmpty)
                            Text(
                              startAt.isNotEmpty && endAt.isNotEmpty
                                  ? '$startAt - $endAt'
                                  : startAt.isNotEmpty
                                      ? 'Started: $startAt'
                                      : 'Ends: $endAt',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isWidescreen ? 10 : 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Achievement details
                    Padding(
                      padding: EdgeInsets.all(contentPadding),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
                              width: badgeSize,
                              height: badgeSize,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: badgeSize,
                                height: badgeSize,
                                color: Colors.grey[800],
                                child: Icon(Icons.emoji_events, size: badgeSize / 2),
                              ),
                            ),
                          ),
                          SizedBox(height: isWidescreen ? 10 : 16),
                          Text(
                            achTitle,
                            style: (isWidescreen
                                    ? Theme.of(context).textTheme.titleMedium
                                    : Theme.of(context).textTheme.headlineSmall)
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isWidescreen ? 4 : 8),
                          Text(
                            achDesc,
                            style: TextStyle(
                              color: context.subtitleColor,
                              fontSize: isWidescreen ? 12 : 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isWidescreen ? 10 : 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildStatChip(Icons.stars, '$achPoints pts', Colors.amber[400]!),
                              _buildStatChip(Icons.military_tech, '$achTrueRatio RP', Colors.purple[300]!),
                              _buildStatChip(Icons.percent, '$unlockRate% unlocked', Colors.green[400]!),
                            ],
                          ),
                          // User earned status
                          SizedBox(height: isWidescreen ? 10 : 16),
                          if (_userHasEarned)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'You earned this!',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (_userEarnedDate != null)
                                        Text(
                                          _userEarnedDate!,
                                          style: TextStyle(
                                            color: Colors.green.withValues(alpha: 0.8),
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline, color: Colors.grey[400], size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Not yet earned',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Share button
                          SizedBox(height: isWidescreen ? 10 : 16),
                          FilledButton.icon(
                            onPressed: () => _shareAchievement(
                              eventType: 'Week',
                              achTitle: achTitle,
                              achDesc: achDesc,
                              badgeName: badgeName,
                              gameTitle: gameTitle,
                              gameIcon: gameIcon,
                              consoleName: consoleName,
                              achPoints: achPoints,
                              achTrueRatio: achTrueRatio,
                              unlockRate: double.tryParse(unlockRate) ?? 0.0,
                            ),
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Share'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isWidescreen ? 10 : 16),

              // Game Card
              Text(
                'From Game',
                style: TextStyle(
                  color: context.subtitleColor,
                  fontSize: isWidescreen ? 10 : 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: isWidescreen ? 4 : 8),
              _buildGameCard(
                context: context,
                gameId: gameId,
                gameTitle: gameTitle,
                gameIcon: gameIcon,
                consoleName: consoleName,
                isWidescreen: isWidescreen,
                color: Colors.blue,
              ),

              SizedBox(height: isWidescreen ? 12 : 24),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.people,
                      label: 'Total Players',
                      value: '$totalPlayers',
                      color: Colors.blue,
                      compact: isWidescreen,
                    ),
                  ),
                  SizedBox(width: isWidescreen ? 8 : 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle,
                      label: 'Unlocked',
                      value: '$unlocksCount',
                      color: Colors.green,
                      compact: isWidescreen,
                    ),
                  ),
                ],
              ),

              SizedBox(height: isWidescreen ? 12 : 24),

              // Recent Unlocks
              if (unlocks.isNotEmpty) ...[
                Text(
                  'Recent Unlocks',
                  style: isWidescreen
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: isWidescreen ? 8 : 12),
                ...unlocks.take(isWidescreen ? 10 : 20).map(
                      (unlock) => _UnlockTile(unlock: unlock, compact: isWidescreen),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required dynamic gameId,
    required String gameTitle,
    required String gameIcon,
    required String consoleName,
    required bool isWidescreen,
    required Color color,
  }) {
    final imageSize = isWidescreen ? 40.0 : 56.0;

    return Card(
      child: InkWell(
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
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isWidescreen ? 8 : 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: gameIcon.isNotEmpty
                      ? 'https://retroachievements.org${gameIcon.startsWith('/') ? '' : '/'}$gameIcon'
                      : 'https://retroachievements.org/Images/000001.png',
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: imageSize,
                    height: imageSize,
                    color: Colors.grey[800],
                    child: Icon(Icons.games, size: imageSize / 2),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gameTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (consoleName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          consoleName,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[500]),
            ],
          ),
        ),
      ),
    );
  }

  String _calculateEndDate(String? startDate) {
    if (startDate == null || startDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(startDate);
      final endDt = dt.add(const Duration(days: 6));
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[endDt.month - 1]} ${endDt.day}';
    } catch (_) {
      return '';
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final dt = DateTime.parse(date);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return date;
    }
  }

  String _formatDateTime(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final utc = DateTime.parse(date);
      final dt = utc.toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return date;
    }
  }

  void _shareAchievement({
    required String eventType,
    required String achTitle,
    required String achDesc,
    required String badgeName,
    required String gameTitle,
    required String gameIcon,
    required String consoleName,
    required dynamic achPoints,
    required dynamic achTrueRatio,
    required double unlockRate,
  }) {
    final username = ref.read(authProvider).username ?? 'Player';
    final userPic = '/UserPic/$username.png';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareCardScreen(
          type: ShareCardType.eventAchievement,
          data: {
            'username': username,
            'userPic': userPic,
            'achievementTitle': achTitle,
            'achievementDescription': achDesc,
            'badgeName': badgeName,
            'gameTitle': gameTitle,
            'gameIcon': gameIcon,
            'consoleName': consoleName,
            'eventType': eventType,
            'isEarned': _userHasEarned,
            'dateEarned': _userEarnedDate ?? '',
            'points': achPoints,
            'truePoints': achTrueRatio,
            'unlockPercent': unlockRate,
          },
        ),
      ),
    );
  }
}

// ============================================================================
// AOTM Tab Content - matches AOTW with unlock stats
// ============================================================================

class _AotmTabContent extends ConsumerStatefulWidget {
  const _AotmTabContent();

  @override
  ConsumerState<_AotmTabContent> createState() => _AotmTabContentState();
}

class _AotmTabContentState extends ConsumerState<_AotmTabContent> {
  Map<String, dynamic>? _aotmData;
  Map<String, dynamic>? _unlockData;
  bool _isLoading = true;
  String? _error;
  bool _userHasEarned = false;
  String? _userEarnedDate;

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
    final (data, errorMsg) = await api.getCurrentAchievementOfTheMonthWithError();

    // Fetch unlock stats and check if user has earned
    Map<String, dynamic>? unlockData;
    bool userHasEarned = false;
    String? userEarnedDate;

    if (data != null) {
      final achievementId = data['achievementId'];
      final gameId = data['gameId'];

      // Fetch unlock stats for display
      if (achievementId != null) {
        final id = achievementId is int ? achievementId : int.tryParse(achievementId.toString()) ?? 0;
        if (id > 0) {
          unlockData = await api.getAchievementUnlocks(id, count: 50);
        }
      }

      // Check if user has earned this achievement using game progress API
      if (gameId != null) {
        final gId = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
        if (gId > 0) {
          final gameProgress = await api.getGameInfoWithProgress(gId);
          if (gameProgress != null && achievementId != null) {
            final achievements = gameProgress['Achievements'] as Map<String, dynamic>?;
            final achIdStr = achievementId.toString();
            if (achievements != null) {
              final achData = achievements[achIdStr];
              if (achData is Map<String, dynamic>) {
                // Check if DateEarned or DateEarnedHardcore is set
                final dateEarned = achData['DateEarned'] ?? achData['DateEarnedHardcore'];
                if (dateEarned != null && dateEarned.toString().isNotEmpty) {
                  userHasEarned = true;
                  userEarnedDate = _formatDateTime(dateEarned.toString());
                }
              }
            }
          }
        }
      }

      // Fallback: Check unlock list if game progress API didn't show earned
      // (handles RA API sync issues where unlock appears in unlocks but not game progress)
      if (!userHasEarned && unlockData != null) {
        final currentUsername = ref.read(authProvider).username?.toLowerCase() ?? '';
        if (currentUsername.isNotEmpty) {
          final unlocks = unlockData['Unlocks'] as List<dynamic>? ?? [];
          for (final unlock in unlocks) {
            if (unlock is Map<String, dynamic>) {
              final unlockUser = (unlock['User'] as String?)?.toLowerCase() ?? '';
              if (unlockUser == currentUsername) {
                userHasEarned = true;
                final dateAwarded = unlock['DateAwarded'];
                if (dateAwarded != null) {
                  userEarnedDate = _formatDateTime(dateAwarded.toString());
                }
                break;
              }
            }
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _aotmData = data;
        _unlockData = unlockData;
        _userHasEarned = userHasEarned;
        _userEarnedDate = userEarnedDate;
        _isLoading = false;
        if (data == null) _error = errorMsg ?? 'Failed to load Achievement of the Month';
      });
    }

    // Mark as viewed and clear badge/notification
    if (data != null) {
      final achievementId = data['achievementId']?.toString() ?? '';
      if (achievementId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_viewed_aotm_id', achievementId);
        await NotificationService().clearAotmBadge();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _aotmData == null) {
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

    final gameId = _aotmData!['gameId'];
    final gameTitle = _aotmData!['gameTitle'] ?? 'Unknown Game';
    final gameIcon = _aotmData!['gameImageIcon'] ?? '';
    final consoleName = _aotmData!['consoleName'] ?? '';

    final achTitle = _aotmData!['achievementTitle'] ?? 'Achievement';
    final achDesc = _aotmData!['achievementDescription'] ?? '';
    final badgeName = _aotmData!['achievementBadgeName'] ?? '';
    // Get points/true ratio from unlock API response (Achievement object)
    final achievementInfo = _unlockData?['Achievement'] as Map<String, dynamic>? ?? {};
    final achPoints = achievementInfo['Points'] ?? _aotmData!['achievementPoints'] ?? 0;
    final achTrueRatio = achievementInfo['TrueRatio'] ?? _aotmData!['achievementTrueRatio'] ?? 0;

    final startAt = _formatDate(_aotmData!['achievementDateStart']);
    final endAt = _formatDate(_aotmData!['achievementDateEnd']);

    final swaps = _aotmData!['swaps'] as List<dynamic>? ?? [];

    // Unlock stats from API
    final unlocks = _unlockData?['Unlocks'] as List<dynamic>? ?? [];
    final totalPlayers = _unlockData?['TotalPlayers'] ?? 0;
    final unlocksCount = _unlockData?['UnlocksCount'] ?? unlocks.length;
    final unlockRate = totalPlayers > 0
        ? (unlocksCount / totalPlayers * 100).toStringAsFixed(1)
        : '0.0';

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final isWidescreen = ResponsiveLayout.isWidescreen(context);

    final headerPadding = isWidescreen ? 16.0 : 24.0;
    final headerIconSize = isWidescreen ? 32.0 : 48.0;
    final badgeSize = isWidescreen ? 64.0 : 96.0;
    final contentPadding = isWidescreen ? 14.0 : 20.0;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isWidescreen ? 600 : double.infinity),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, isWidescreen ? 8 : 16, 16, 16 + bottomPadding),
            children: [
              // Achievement Card
              Card(
                child: Column(
                  children: [
                    // Header with gradient - purple for month
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(headerPadding),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple.shade800, Colors.purple.shade900],
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_month, color: Colors.white, size: headerIconSize),
                          SizedBox(height: isWidescreen ? 4 : 8),
                          Text(
                            'ACHIEVEMENT OF THE MONTH',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: isWidescreen ? 12 : 14,
                            ),
                          ),
                          if (startAt.isNotEmpty || endAt.isNotEmpty)
                            Text(
                              startAt.isNotEmpty && endAt.isNotEmpty
                                  ? '$startAt - $endAt'
                                  : startAt.isNotEmpty
                                      ? 'Started: $startAt'
                                      : 'Ends: $endAt',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: isWidescreen ? 10 : 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Achievement details
                    Padding(
                      padding: EdgeInsets.all(contentPadding),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: 'https://media.retroachievements.org/Badge/$badgeName.png',
                              width: badgeSize,
                              height: badgeSize,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: badgeSize,
                                height: badgeSize,
                                color: Colors.grey[800],
                                child: Icon(Icons.calendar_month, size: badgeSize / 2),
                              ),
                            ),
                          ),
                          SizedBox(height: isWidescreen ? 10 : 16),
                          Text(
                            achTitle,
                            style: (isWidescreen
                                    ? Theme.of(context).textTheme.titleMedium
                                    : Theme.of(context).textTheme.headlineSmall)
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isWidescreen ? 4 : 8),
                          Text(
                            achDesc,
                            style: TextStyle(
                              color: context.subtitleColor,
                              fontSize: isWidescreen ? 12 : 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isWidescreen ? 10 : 16),
                          // Stat chips matching AOTW
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildStatChip(Icons.stars, '$achPoints pts', Colors.amber[400]!),
                              _buildStatChip(Icons.military_tech, '$achTrueRatio RP', Colors.purple[300]!),
                              _buildStatChip(Icons.percent, '$unlockRate% unlocked', Colors.green[400]!),
                            ],
                          ),
                          // User earned status
                          SizedBox(height: isWidescreen ? 10 : 16),
                          if (_userHasEarned)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'You earned this!',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (_userEarnedDate != null)
                                        Text(
                                          _userEarnedDate!,
                                          style: TextStyle(
                                            color: Colors.green.withValues(alpha: 0.8),
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline, color: Colors.grey[400], size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Not yet earned',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Share button
                          SizedBox(height: isWidescreen ? 10 : 16),
                          FilledButton.icon(
                            onPressed: () => _shareAchievement(
                              eventType: 'Month',
                              achTitle: achTitle,
                              achDesc: achDesc,
                              badgeName: badgeName,
                              gameTitle: gameTitle,
                              gameIcon: gameIcon,
                              consoleName: consoleName,
                              achPoints: achPoints,
                              achTrueRatio: achTrueRatio,
                              unlockRate: double.tryParse(unlockRate) ?? 0.0,
                            ),
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Share'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isWidescreen ? 10 : 16),

              // Game Card
              Text(
                'From Game',
                style: TextStyle(
                  color: context.subtitleColor,
                  fontSize: isWidescreen ? 10 : 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: isWidescreen ? 4 : 8),
              _buildGameCard(
                context: context,
                gameId: gameId,
                gameTitle: gameTitle,
                gameIcon: gameIcon,
                consoleName: consoleName,
                isWidescreen: isWidescreen,
              ),

              SizedBox(height: isWidescreen ? 12 : 24),

              // Stats row matching AOTW
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.people,
                      label: 'Total Players',
                      value: '$totalPlayers',
                      color: Colors.blue,
                      compact: isWidescreen,
                    ),
                  ),
                  SizedBox(width: isWidescreen ? 8 : 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle,
                      label: 'Unlocked',
                      value: '$unlocksCount',
                      color: Colors.green,
                      compact: isWidescreen,
                    ),
                  ),
                ],
              ),

              // Recent Unlocks
              if (unlocks.isNotEmpty) ...[
                SizedBox(height: isWidescreen ? 12 : 24),
                Text(
                  'Recent Unlocks',
                  style: isWidescreen
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: isWidescreen ? 8 : 12),
                ...unlocks.take(isWidescreen ? 10 : 20).map(
                      (unlock) => _UnlockTile(unlock: unlock, compact: isWidescreen),
                    ),
              ],

              // Swaps Section
              if (swaps.isNotEmpty) ...[
                SizedBox(height: isWidescreen ? 12 : 24),
                Text(
                  'Alternative Achievements',
                  style: isWidescreen
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: isWidescreen ? 2 : 4),
                Text(
                  'You can earn any of these instead',
                  style: TextStyle(
                    color: context.subtitleColor,
                    fontSize: isWidescreen ? 10 : 12,
                  ),
                ),
                SizedBox(height: isWidescreen ? 8 : 12),
                ...swaps.map((swap) => _SwapCard(swap: swap, compact: isWidescreen)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required dynamic gameId,
    required String gameTitle,
    required String gameIcon,
    required String consoleName,
    required bool isWidescreen,
  }) {
    final imageSize = isWidescreen ? 40.0 : 56.0;

    return Card(
      child: InkWell(
        onTap: gameId != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailScreen(
                      gameId: gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0,
                      gameTitle: gameTitle,
                    ),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isWidescreen ? 8 : 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: gameIcon.isNotEmpty
                      ? 'https://media.retroachievements.org$gameIcon'
                      : 'https://media.retroachievements.org/Images/000001.png',
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: imageSize,
                    height: imageSize,
                    color: Colors.grey[800],
                    child: Icon(Icons.games, size: imageSize / 2),
                  ),
                ),
              ),
              SizedBox(width: isWidescreen ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gameTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isWidescreen ? 13 : 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isWidescreen ? 4 : 6),
                    if (consoleName.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWidescreen ? 6 : 8,
                          vertical: isWidescreen ? 2 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          consoleName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isWidescreen ? 9 : 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[500], size: isWidescreen ? 18 : 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final dt = DateTime.parse(date);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return date;
    }
  }

  String _formatDateTime(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final utc = DateTime.parse(date);
      final dt = utc.toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return date;
    }
  }

  void _shareAchievement({
    required String eventType,
    required String achTitle,
    required String achDesc,
    required String badgeName,
    required String gameTitle,
    required String gameIcon,
    required String consoleName,
    required dynamic achPoints,
    required dynamic achTrueRatio,
    required double unlockRate,
  }) {
    final username = ref.read(authProvider).username ?? 'Player';
    final userPic = '/UserPic/$username.png';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareCardScreen(
          type: ShareCardType.eventAchievement,
          data: {
            'username': username,
            'userPic': userPic,
            'achievementTitle': achTitle,
            'achievementDescription': achDesc,
            'badgeName': badgeName,
            'gameTitle': gameTitle,
            'gameIcon': gameIcon,
            'consoleName': consoleName,
            'eventType': eventType,
            'isEarned': _userHasEarned,
            'dateEarned': _userEarnedDate ?? '',
            'points': achPoints,
            'truePoints': achTrueRatio,
            'unlockPercent': unlockRate,
          },
        ),
      ),
    );
  }
}

// ============================================================================
// Shared Widgets
// ============================================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool compact;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 10 : 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: compact ? 20 : 28),
            SizedBox(height: compact ? 4 : 8),
            Text(
              value,
              style: (compact
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.headlineSmall)
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(color: context.subtitleColor, fontSize: compact ? 10 : 12),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(String? date) {
  if (date == null || date.isEmpty) return '';
  try {
    final utc = DateTime.parse(date);
    final dt = utc.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:${dt.minute.toString().padLeft(2, '0')} $ampm';
  } catch (_) {
    return date;
  }
}

class _UnlockTile extends StatelessWidget {
  final dynamic unlock;
  final bool compact;

  const _UnlockTile({required this.unlock, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final user = unlock['User'] ?? 'Unknown';
    final dateAwarded = _formatDateTime(unlock['DateAwarded']);
    final hardcoreMode = unlock['HardcoreMode'] == 1;

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 2 : 4),
      child: ListTile(
        dense: true,
        visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        onTap: user.isNotEmpty && user != 'Unknown'
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(username: user)),
                );
              }
            : null,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          child: CachedNetworkImage(
            imageUrl: 'https://retroachievements.org/UserPic/$user.png',
            width: compact ? 24 : 32,
            height: compact ? 24 : 32,
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
        trailing: const Icon(Icons.chevron_right, size: 20),
      ),
    );
  }
}

class _SwapCard extends StatelessWidget {
  final dynamic swap;
  final bool compact;

  const _SwapCard({required this.swap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (swap is! Map<String, dynamic>) return const SizedBox.shrink();

    final data = swap as Map<String, dynamic>;
    final gameId = data['gameId'];
    final gameTitle = data['gameTitle'] ?? 'Unknown Game';
    final gameIcon = data['gameImageIcon'] ?? '';
    final consoleName = data['consoleName'] ?? '';
    final achTitle = data['achievementTitle'] ?? 'Achievement';
    final achDesc = data['achievementDescription'] ?? '';
    final badgeName = data['achievementBadgeName'] ?? '';

    final badgeSize = compact ? 36.0 : 48.0;

    return Card(
      margin: EdgeInsets.only(bottom: compact ? 4 : 8),
      child: InkWell(
        onTap: gameId != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailScreen(
                      gameId: gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0,
                      gameTitle: gameTitle,
                    ),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: 'https://media.retroachievements.org/Badge/$badgeName.png',
                  width: badgeSize,
                  height: badgeSize,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 48,
                    height: 48,
                    color: Colors.grey[800],
                    child: const Icon(Icons.emoji_events, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      achDesc,
                      style: TextStyle(color: context.subtitleColor, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: CachedNetworkImage(
                            imageUrl: gameIcon.isNotEmpty
                                ? 'https://media.retroachievements.org$gameIcon'
                                : 'https://media.retroachievements.org/Images/000001.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 20,
                              height: 20,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            gameTitle,
                            style: TextStyle(color: context.subtitleColor, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (consoleName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              consoleName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[500], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Roulette Tab Content - RA Roulette 2026
// ============================================================================

class _RouletteTabContent extends ConsumerStatefulWidget {
  const _RouletteTabContent();

  @override
  ConsumerState<_RouletteTabContent> createState() => _RouletteTabContentState();
}

class _RouletteTabContentState extends ConsumerState<_RouletteTabContent> {
  Map<String, dynamic>? _rouletteData;
  bool _isLoading = true;
  String? _error;

  // Track which achievements user has earned: achievementId -> earned date
  Map<int, String?> _earnedAchievements = {};
  int _totalPoints = 0;

  // Expanded weeks (current week is always expanded)
  Set<int> _expandedWeeks = {};

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
    final data = await api.getRoulette2026();

    if (data != null) {
      // Check which achievements user has earned
      await _checkUserProgress(api, data);
    }

    if (mounted) {
      setState(() {
        _rouletteData = data;
        _isLoading = false;
        if (data == null) _error = 'Failed to load Roulette data';
      });
    }
  }

  Future<void> _checkUserProgress(dynamic api, Map<String, dynamic> data) async {
    final weeks = data['weeks'] as List<dynamic>? ?? [];
    final earnedMap = <int, String?>{};
    int points = 0;

    // Group achievements by gameId to minimize API calls
    final gameAchievements = <int, List<int>>{};
    for (final week in weeks) {
      if (week is Map<String, dynamic>) {
        final achievements = week['achievements'] as List<dynamic>? ?? [];
        for (final ach in achievements) {
          if (ach is Map<String, dynamic>) {
            final gameId = ach['gameId'] as int? ?? 0;
            final achId = ach['achievementId'] as int? ?? 0;
            if (gameId > 0 && achId > 0) {
              gameAchievements.putIfAbsent(gameId, () => []).add(achId);
            }
          }
        }
      }
    }

    // Fetch game progress for each game
    for (final entry in gameAchievements.entries) {
      final gameId = entry.key;
      final achIds = entry.value;

      try {
        final gameDetails = await api.getGameInfoWithProgress(gameId);
        if (gameDetails != null) {
          final achievements = gameDetails['Achievements'] as Map<String, dynamic>?;
          if (achievements != null) {
            for (final achId in achIds) {
              final achData = achievements[achId.toString()];
              if (achData is Map<String, dynamic>) {
                final dateEarned = achData['DateEarned'] ?? achData['DateEarnedHardcore'];
                if (dateEarned != null && dateEarned.toString().isNotEmpty) {
                  earnedMap[achId] = dateEarned.toString();
                  points++;
                }
              }
            }
          }
        }
      } catch (_) {}

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      setState(() {
        _earnedAchievements = earnedMap;
        _totalPoints = points;
      });
    }
  }

  int _getCurrentWeekNumber() {
    final weeks = _rouletteData?['weeks'] as List<dynamic>? ?? [];
    final now = DateTime.now().toUtc();

    for (int i = 0; i < weeks.length; i++) {
      final week = weeks[i];
      if (week is Map<String, dynamic>) {
        final startStr = week['startDate'] as String?;
        final endStr = week['endDate'] as String?;
        if (startStr != null && endStr != null) {
          try {
            final start = DateTime.parse(startStr);
            final end = DateTime.parse(endStr);
            if (now.isAfter(start) && now.isBefore(end)) {
              return week['week'] as int? ?? (i + 1);
            }
          } catch (_) {}
        }
      }
    }
    return weeks.isEmpty ? 0 : (weeks.last as Map<String, dynamic>?)?['week'] ?? weeks.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _rouletteData == null) {
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

    final badgeThreshold = _rouletteData!['badgeThreshold'] as int? ?? 52;
    final maxPoints = _rouletteData!['maxPoints'] as int? ?? 156;
    final weeks = _rouletteData!['weeks'] as List<dynamic>? ?? [];
    final currentWeekNum = _getCurrentWeekNumber();
    final hasBadge = _totalPoints >= badgeThreshold;
    final isPerfect = _totalPoints >= maxPoints;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(context, currentWeekNum, 52), // 52 weeks in full event
            const SizedBox(height: 16),

            // Progress Card
            _buildProgressCard(context, badgeThreshold, maxPoints, hasBadge, isPerfect),
            const SizedBox(height: 16),

            // Share Button
            _buildShareButton(context, hasBadge, isPerfect, badgeThreshold, maxPoints),
            const SizedBox(height: 24),

            // Weeks List
            Text(
              'Weekly Achievements',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            ...weeks.reversed.map((week) {
              if (week is! Map<String, dynamic>) return const SizedBox();
              final weekNum = week['week'] as int? ?? 0;
              final isCurrentWeek = weekNum == currentWeekNum;
              final isExpanded = isCurrentWeek || _expandedWeeks.contains(weekNum);
              return _buildWeekCard(context, week, isCurrentWeek, isExpanded);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int currentWeek, int totalWeeks) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.casino, color: Colors.purple, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RA Roulette 2026',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Week $currentWeek of $totalWeeks',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard(BuildContext context, int threshold, int max, bool hasBadge, bool isPerfect) {
    final progress = _totalPoints / threshold;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Your Progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isPerfect)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('PERFECT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  )
                else if (hasBadge)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('BADGE EARNED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar to badge
            Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPerfect
                            ? [Colors.amber, Colors.orange]
                            : hasBadge
                                ? [Colors.green, Colors.teal]
                                : [Colors.purple, Colors.deepPurple],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_totalPoints / $threshold points',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hasBadge ? Colors.green : null,
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% to badge',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),

            if (_totalPoints > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Total possible: $_totalPoints / $max',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton(BuildContext context, bool hasBadge, bool isPerfect, int threshold, int max) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShareCardScreen(
                type: ShareCardType.roulette,
                data: {
                  'eventName': 'RA Roulette 2026',
                  'totalPoints': _totalPoints,
                  'badgeThreshold': threshold,
                  'maxPoints': max,
                  'hasBadge': hasBadge,
                  'isPerfect': isPerfect,
                  'username': ref.read(authProvider).username ?? '',
                },
              ),
            ),
          );
        },
        icon: const Icon(Icons.share),
        label: Text(isPerfect ? 'Share Perfect Score!' : hasBadge ? 'Share Badge!' : 'Share Progress'),
        style: FilledButton.styleFrom(
          backgroundColor: isPerfect ? Colors.amber : hasBadge ? Colors.green : null,
        ),
      ),
    );
  }

  Widget _buildWeekCard(BuildContext context, Map<String, dynamic> week, bool isCurrentWeek, bool isExpanded) {
    final weekNum = week['week'] as int? ?? 0;
    final startDate = week['startDate'] as String? ?? '';
    final achievements = week['achievements'] as List<dynamic>? ?? [];

    // Count earned in this week
    int earnedThisWeek = 0;
    for (final ach in achievements) {
      if (ach is Map<String, dynamic>) {
        final achId = ach['achievementId'] as int? ?? 0;
        if (_earnedAchievements.containsKey(achId)) {
          earnedThisWeek++;
        }
      }
    }

    String dateLabel = '';
    try {
      final date = DateTime.parse(startDate);
      dateLabel = '${date.month}/${date.day}';
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCurrentWeek ? Colors.purple.withValues(alpha: 0.1) : null,
      child: Column(
        children: [
          InkWell(
            onTap: isCurrentWeek ? null : () {
              setState(() {
                if (_expandedWeeks.contains(weekNum)) {
                  _expandedWeeks.remove(weekNum);
                } else {
                  _expandedWeeks.add(weekNum);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrentWeek
                          ? Colors.purple
                          : earnedThisWeek == 3
                              ? Colors.green
                              : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: earnedThisWeek == 3
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : Text(
                              '$weekNum',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCurrentWeek ? Colors.white : null,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Week $weekNum',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (isCurrentWeek) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CURRENT',
                                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          dateLabel,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$earnedThisWeek/3',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: earnedThisWeek == 3 ? Colors.green : null,
                    ),
                  ),
                  if (!isCurrentWeek) ...[
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[500],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expanded achievements
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: achievements.map((ach) {
                  if (ach is! Map<String, dynamic>) return const SizedBox();
                  return _buildAchievementRow(context, ach);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAchievementRow(BuildContext context, Map<String, dynamic> ach) {
    final achId = ach['achievementId'] as int? ?? 0;
    final title = ach['achievementTitle'] as String? ?? 'Unknown';
    final gameTitle = ach['gameTitle'] as String? ?? '';
    final badgeName = ach['achievementBadgeName'] as String? ?? '';
    final gameId = ach['gameId'] as int? ?? 0;
    final isEarned = _earnedAchievements.containsKey(achId);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: gameId > 0 ? () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameDetailScreen(gameId: gameId),
            ),
          );
        } : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isEarned
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isEarned
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              // Badge
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: ColorFiltered(
                  colorFilter: isEarned
                      ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                      : const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 0.5, 0,
                        ]),
                  child: CachedNetworkImage(
                    imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 32,
                      height: 32,
                      color: Colors.grey[800],
                      child: const Icon(Icons.emoji_events, size: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: isEarned ? null : Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      gameTitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Status
              if (isEarned)
                const Icon(Icons.check_circle, color: Colors.green, size: 20)
              else
                Icon(Icons.radio_button_unchecked, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
