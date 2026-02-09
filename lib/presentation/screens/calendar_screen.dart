import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../../core/animations.dart';
import '../providers/auth_provider.dart';
import '../widgets/premium_gate.dart';
import 'game_detail_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  List<dynamic>? _achievements;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);
    final api = ref.read(apiDataSourceProvider);
    final username = ref.read(authProvider).username;

    if (username != null) {
      // Use API that returns HardcoreMode field
      // Get achievements from last 365 days
      final now = DateTime.now();
      final oneYearAgo = now.subtract(const Duration(days: 365));
      final achievements = await api.getAchievementsEarnedBetween(username, oneYearAgo, now);
      setState(() {
        _achievements = achievements;
        _isLoading = false;
      });
    }
  }

  Map<DateTime, List<dynamic>> _groupByDate() {
    if (_achievements == null) return {};

    final grouped = <DateTime, List<dynamic>>{};
    for (final ach in _achievements!) {
      // Try all possible date field names from the API
      final dateStr = ach['Date'] ?? ach['DateEarned'] ?? ach['DateEarnedHardcore'] ?? ach['DateAwarded'];
      if (dateStr == null || dateStr.toString().isEmpty) continue;

      try {
        // RA API returns dates in UTC but without 'Z' suffix
        // Parse as UTC then convert to local for proper day grouping
        var dt = DateTime.parse(dateStr.toString());
        // Treat as UTC and convert to local time
        dt = DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second).toLocal();
        final dateOnly = DateTime(dt.year, dt.month, dt.day);
        grouped.putIfAbsent(dateOnly, () => []).add(ach);
      } catch (_) {}
    }
    return grouped;
  }

  List<dynamic> _getAchievementsForDate(DateTime date) {
    final grouped = _groupByDate();
    final dateOnly = DateTime(date.year, date.month, date.day);
    return grouped[dateOnly] ?? [];
  }

  int _getCountForDate(DateTime date) {
    return _getAchievementsForDate(date).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievement Calendar'),
      ),
      body: PremiumGate(
        featureName: 'Achievement Calendar',
        description: 'View your achievement history on a calendar. See what you unlocked on any day.',
        icon: Icons.calendar_month,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RetroRefreshIndicator(
                onRefresh: _loadAchievements,
                child: CustomScrollView(
                  slivers: [
                    // Calendar
                    SliverToBoxAdapter(child: _buildCalendar()),
                    const SliverToBoxAdapter(child: Divider(height: 1)),
                    // Selected day achievements
                    SliverFillRemaining(
                      child: _buildDayDetail(),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCalendar() {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    return Column(
      children: [
        // Month navigation
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                  });
                },
              ),
              Text(
                _formatMonth(_focusedMonth),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                  });
                },
              ),
            ],
          ),
        ),
        // Day headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: 42, // 6 weeks
            itemBuilder: (ctx, index) {
              final dayOffset = index - startingWeekday;
              if (dayOffset < 0 || dayOffset >= daysInMonth) {
                return const SizedBox();
              }

              final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayOffset + 1);
              final count = _getCountForDate(date);
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, DateTime.now());

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : count > 0
                            ? Colors.green.withValues(alpha: 0.2)
                            : null,
                    border: isToday
                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${dayOffset + 1}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight: isToday ? FontWeight.bold : null,
                          fontSize: 14,
                        ),
                      ),
                      if (count > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayDetail() {
    final achievements = _getAchievementsForDate(_selectedDate);
    final dateStr = _formatDate(_selectedDate);

    if (achievements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No achievements on $dateStr',
              style: TextStyle(color: context.subtitleColor),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                dateStr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${achievements.length} unlock${achievements.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.green, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: achievements.length,
            itemBuilder: (ctx, i) => _AchievementTile(achievement: achievements[i]),
          ),
        ),
      ],
    );
  }

  String _formatMonth(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _AchievementTile extends StatelessWidget {
  final dynamic achievement;

  const _AchievementTile({required this.achievement});

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      var date = DateTime.parse(dateStr);
      // Treat as UTC and convert to local
      date = DateTime.utc(date.year, date.month, date.day, date.hour, date.minute, date.second).toLocal();
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute $amPm';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = achievement['Title'] ?? 'Achievement';
    final description = achievement['Description'] ?? '';
    final points = achievement['Points'] ?? 0;
    final badgeName = achievement['BadgeName'] ?? '';
    final gameTitle = achievement['GameTitle'] ?? '';
    final gameId = achievement['GameID'];
    final dateStr = achievement['Date'] ?? achievement['DateEarned'] ?? '';
    final formattedTime = _formatTime(dateStr);
    // Check various possible hardcore field names and values
    final hardcoreMode = achievement['HardcoreMode'] == 1 ||
                         achievement['HardcoreMode'] == true ||
                         achievement['Hardcore'] == 1 ||
                         achievement['Hardcore'] == true ||
                         achievement['DateEarnedHardcore'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: gameId != null ? () {
          Haptics.light();
          final id = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
          if (id > 0) {
            Navigator.push(
              context,
              SlidePageRoute(
                page: GameDetailScreen(gameId: id, gameTitle: gameTitle),
              ),
            );
          }
        } : null,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: 'https://retroachievements.org/Badge/$badgeName.png',
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: 48,
              height: 48,
              color: Colors.grey[800],
              child: const Icon(Icons.emoji_events),
            ),
          ),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.subtitleColor, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.stars, size: 12, color: Colors.amber[400]),
                const SizedBox(width: 4),
                Text('$points pts', style: TextStyle(color: Colors.amber[400], fontSize: 11)),
                if (hardcoreMode) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'HC',
                      style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                if (formattedTime.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.access_time, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Text(
                    formattedTime,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              gameTitle,
              style: TextStyle(color: context.subtitleColor, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        isThreeLine: true,
        ),
      ),
    );
  }
}
