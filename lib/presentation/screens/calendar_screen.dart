import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';

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
      // Load a large batch of recent achievements
      final achievements = await api.getRecentAchievements(username, count: 500);
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
      final dateStr = ach['Date'] ?? ach['DateEarned'];
      if (dateStr == null) continue;

      try {
        final dt = DateTime.parse(dateStr);
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Calendar
                _buildCalendar(),
                const Divider(height: 1),
                // Selected day achievements
                Expanded(
                  child: _buildDayDetail(),
                ),
              ],
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${dayOffset + 1}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight: isToday ? FontWeight.bold : null,
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
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

  @override
  Widget build(BuildContext context) {
    final title = achievement['Title'] ?? 'Achievement';
    final description = achievement['Description'] ?? '';
    final points = achievement['Points'] ?? 0;
    final badgeName = achievement['BadgeName'] ?? '';
    final gameTitle = achievement['GameTitle'] ?? '';
    final hardcoreMode = achievement['HardcoreMode'] == 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
                const SizedBox(width: 8),
                if (hardcoreMode)
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
                const Spacer(),
                Text(
                  gameTitle,
                  style: TextStyle(color: context.subtitleColor, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
