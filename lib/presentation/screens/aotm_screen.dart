import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';
import 'game_detail_screen.dart';

class AchievementOfTheMonthScreen extends ConsumerStatefulWidget {
  const AchievementOfTheMonthScreen({super.key});

  @override
  ConsumerState<AchievementOfTheMonthScreen> createState() =>
      _AchievementOfTheMonthScreenState();
}

class _AchievementOfTheMonthScreenState
    extends ConsumerState<AchievementOfTheMonthScreen> {
  Map<String, dynamic>? _aotmData;
  bool _isLoading = true;
  String? _error;

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

    setState(() {
      _aotmData = data;
      _isLoading = false;
      if (data == null) _error = errorMsg ?? 'Failed to load Achievement of the Month';
    });

    // Mark as viewed
    if (data != null) {
      final achievementId = data['achievementId']?.toString() ?? '';
      if (achievementId.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_viewed_aotm_id', achievementId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievement of the Month'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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

    final startAt = _formatDate(_aotmData!['achievementDateStart']);
    final endAt = _formatDate(_aotmData!['achievementDateEnd']);

    final swaps = _aotmData!['swaps'] as List<dynamic>? ?? [];

    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
        children: [
          // Achievement Card
          Card(
            child: Column(
              children: [
                // Header with gradient - using a different color scheme for month
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(12)),
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple.shade800, Colors.purple.shade900],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        color: Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ACHIEVEMENT OF THE MONTH',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (startAt.isNotEmpty || endAt.isNotEmpty)
                        Text(
                          startAt.isNotEmpty && endAt.isNotEmpty
                              ? '$startAt - $endAt'
                              : startAt.isNotEmpty
                                  ? 'Started: $startAt'
                                  : 'Ends: $endAt',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                // Achievement details
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Badge
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl:
                              'https://media.retroachievements.org/Badge/$badgeName.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 96,
                            height: 96,
                            color: Colors.grey[800],
                            child: const Icon(Icons.calendar_month, size: 48),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Title
                      Text(
                        achTitle,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Description
                      Text(
                        achDesc,
                        style: TextStyle(color: context.subtitleColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Game Card
          Text(
            'From Game',
            style: TextStyle(
              color: context.subtitleColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _buildGameCard(
            gameId: gameId,
            gameTitle: gameTitle,
            gameIcon: gameIcon,
            consoleName: consoleName,
          ),

          // Swaps Section
          if (swaps.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Alternative Achievements',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'You can earn any of these instead',
              style: TextStyle(
                color: context.subtitleColor,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            ...swaps.map((swap) => _SwapCard(swap: swap)),
          ],
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required dynamic gameId,
    required String gameTitle,
    required String gameIcon,
    required String consoleName,
  }) {
    return Card(
      child: InkWell(
        onTap: gameId != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailScreen(
                      gameId: gameId is int
                          ? gameId
                          : int.tryParse(gameId.toString()) ?? 0,
                      gameTitle: gameTitle,
                    ),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: gameIcon.isNotEmpty
                      ? 'https://media.retroachievements.org$gameIcon'
                      : 'https://media.retroachievements.org/Images/000001.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey[800],
                    child: const Icon(Icons.games, size: 28),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (consoleName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          consoleName,
                          style: const TextStyle(
                            color: Colors.white,
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

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '';
    try {
      final dt = DateTime.parse(date);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (_) {
      return date;
    }
  }
}

class _SwapCard extends StatelessWidget {
  final dynamic swap;

  const _SwapCard({required this.swap});

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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: gameId != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameDetailScreen(
                      gameId: gameId is int
                          ? gameId
                          : int.tryParse(gameId.toString()) ?? 0,
                      gameTitle: gameTitle,
                    ),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Achievement badge
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl:
                      'https://media.retroachievements.org/Badge/$badgeName.png',
                  width: 48,
                  height: 48,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      achDesc,
                      style: TextStyle(
                        color: context.subtitleColor,
                        fontSize: 12,
                      ),
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
                            style: TextStyle(
                              color: context.subtitleColor,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (consoleName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
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
