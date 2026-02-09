import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme_utils.dart';
import '../../core/animations.dart';
import '../providers/auth_provider.dart';
import '../providers/streak_provider.dart';
import '../widgets/premium_gate.dart';
import 'game_detail_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final _usernameController = TextEditingController();
  String? _viewingUsername;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    final username = ref.read(authProvider).username;
    if (username != null) {
      _viewingUsername = username;
      Future.microtask(() => ref.read(streakProvider.notifier).loadStreaks(username));
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _searchUser() {
    final username = _usernameController.text.trim();
    if (username.isNotEmpty) {
      setState(() => _viewingUsername = username);
      ref.read(streakProvider.notifier).loadStreaks(username);
    }
  }

  void _loadMyData() {
    final username = ref.read(authProvider).username;
    if (username != null) {
      _usernameController.clear();
      setState(() => _viewingUsername = username);
      ref.read(streakProvider.notifier).loadStreaks(username);
    }
  }

  List<dynamic> _getAchievementsForDate(DateTime date, StreakState streakState) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return streakState.achievementsByDate[dateOnly] ?? [];
  }

  int _getCountForDate(DateTime date, StreakState streakState) {
    return streakState.activityMap[DateTime(date.year, date.month, date.day)] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final streakState = ref.watch(streakProvider);
    final myUsername = ref.read(authProvider).username;
    final isViewingMyself = _viewingUsername == myUsername;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievement Calendar'),
      ),
      body: PremiumGate(
        featureName: 'Achievement Calendar',
        description: 'Track your streaks and view achievement history on a calendar.',
        icon: Icons.calendar_month,
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: 'View another user...',
                        prefixIcon: const Icon(Icons.person_search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14),
                      onSubmitted: (_) => _searchUser(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: streakState.isLoading ? null : _searchUser,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('View'),
                  ),
                ],
              ),
            ),

            // Show who we're viewing if not ourselves
            if (!isViewingMyself && _viewingUsername != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Chip(
                      avatar: const Icon(Icons.person, size: 16),
                      label: Text('Viewing: $_viewingUsername'),
                      onDeleted: _loadMyData,
                      deleteIcon: const Icon(Icons.close, size: 16),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: streakState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : streakState.error != null
                      ? _buildErrorView(streakState.error!)
                      : RefreshIndicator(
                          onRefresh: () async {
                            if (_viewingUsername != null) {
                              await ref.read(streakProvider.notifier).loadStreaks(_viewingUsername!);
                            }
                          },
                          child: _buildContent(streakState),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(error, style: TextStyle(color: context.subtitleColor)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _loadMyData,
            child: const Text('View My Calendar'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(StreakState streakState) {
    final achievements = _getAchievementsForDate(_selectedDate, streakState);

    return CustomScrollView(
      slivers: [
        // Streak cards
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _buildStreakCards(streakState),
          ),
        ),

        // Calendar
        SliverToBoxAdapter(child: _buildCalendar(streakState)),

        // Legend
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildLegend(),
          ),
        ),

        const SliverToBoxAdapter(child: Divider(height: 1)),

        // Selected day achievements
        SliverToBoxAdapter(
          child: _buildDayHeader(achievements),
        ),

        // Achievement list
        if (achievements.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyDay(),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewPadding.bottom + 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _AchievementTile(achievement: achievements[i]),
                childCount: achievements.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStreakCards(StreakState streakState) {
    return Row(
      children: [
        Expanded(
          child: _StreakCard(
            title: 'Current Streak',
            value: streakState.currentStreak,
            icon: Icons.local_fire_department,
            color: streakState.isStreakActive ? Colors.orange : Colors.grey,
            subtitle: streakState.isStreakActive
                ? (streakState.hasActivityToday ? 'Active today!' : 'Play today!')
                : 'Start a streak!',
            showFlame: streakState.isStreakActive,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StreakCard(
            title: 'Best Streak',
            value: streakState.bestStreak,
            icon: Icons.emoji_events,
            color: Colors.amber,
            subtitle: '${DateTime.now().year} record',
          ),
        ),
      ],
    );
  }

  Widget _buildCalendar(StreakState streakState) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    return Column(
      children: [
        // Month navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  final newMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                  setState(() => _focusedMonth = newMonth);
                  if (_viewingUsername != null) {
                    ref.read(streakProvider.notifier).loadMonth(
                      _viewingUsername!,
                      newMonth.year,
                      newMonth.month,
                    );
                  }
                },
              ),
              GestureDetector(
                onTap: _showMonthYearPicker,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatMonth(_focusedMonth),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 20, color: context.subtitleColor),
                    if (streakState.isLoadingMonth)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.subtitleColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _focusedMonth.isBefore(DateTime(DateTime.now().year, DateTime.now().month))
                    ? () {
                        final newMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                        setState(() => _focusedMonth = newMonth);
                        if (_viewingUsername != null) {
                          ref.read(streakProvider.notifier).loadMonth(
                            _viewingUsername!,
                            newMonth.year,
                            newMonth.month,
                          );
                        }
                      }
                    : null,
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
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),

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
              final count = _getCountForDate(date, streakState);
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, DateTime.now());
              final isFuture = date.isAfter(DateTime.now());

              return GestureDetector(
                onTap: isFuture ? null : () => setState(() => _selectedDate = date),
                child: _CalendarDay(
                  day: dayOffset + 1,
                  activityCount: count,
                  isSelected: isSelected,
                  isToday: isToday,
                  isFuture: isFuture,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.grey.shade200
              : Colors.grey.shade800,
          label: 'None',
        ),
        const SizedBox(width: 12),
        _LegendItem(color: Colors.green.shade300, label: '1-2'),
        const SizedBox(width: 12),
        _LegendItem(color: Colors.green.shade500, label: '3-5'),
        const SizedBox(width: 12),
        _LegendItem(color: Colors.green.shade700, label: '6+'),
      ],
    );
  }

  Widget _buildDayHeader(List<dynamic> achievements) {
    final dateStr = _formatDate(_selectedDate);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            dateStr,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: achievements.isNotEmpty
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${achievements.length} unlock${achievements.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: achievements.isNotEmpty ? Colors.green : context.subtitleColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No achievements on this day',
            style: TextStyle(color: context.subtitleColor),
          ),
        ],
      ),
    );
  }

  void _showMonthYearPicker() {
    int selectedYear = _focusedMonth.year;
    int selectedMonthIndex = _focusedMonth.month - 1;
    final now = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                16, 16, 16,
                16 + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Select Month & Year',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Year selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: selectedYear > 2000
                            ? () => setModalState(() => selectedYear--)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$selectedYear',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: selectedYear < now.year
                            ? () => setModalState(() => selectedYear++)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Month grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      childAspectRatio: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final isSelected = index == selectedMonthIndex;
                      final isFuture = selectedYear == now.year && index > now.month - 1;
                      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

                      return GestureDetector(
                        onTap: isFuture ? null : () => setModalState(() => selectedMonthIndex = index),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : isFuture
                                    ? Colors.grey.withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            months[index],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isFuture ? Colors.grey : null,
                              fontWeight: isSelected ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final newMonth = DateTime(selectedYear, selectedMonthIndex + 1);
                        Navigator.pop(context);
                        setState(() {
                          _focusedMonth = newMonth;
                          _selectedDate = newMonth;
                        });
                        if (_viewingUsername != null) {
                          ref.read(streakProvider.notifier).loadMonth(
                            _viewingUsername!,
                            newMonth.year,
                            newMonth.month,
                          );
                        }
                      },
                      child: const Text('Go to Month'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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

class _StreakCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final bool showFlame;

  const _StreakCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.showFlame = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.8),
              color.withValues(alpha: 0.6),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (showFlame && value > 0)
                  AnimatedStreakFlame(streakDays: value, size: 20)
                else
                  Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  value == 1 ? 'day' : 'days',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  final int day;
  final int activityCount;
  final bool isSelected;
  final bool isToday;
  final bool isFuture;

  const _CalendarDay({
    required this.day,
    required this.activityCount,
    required this.isSelected,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (isSelected) {
      bgColor = Theme.of(context).colorScheme.primary;
    } else if (isFuture) {
      bgColor = Colors.transparent;
    } else if (activityCount == 0) {
      bgColor = Theme.of(context).brightness == Brightness.light
          ? Colors.grey.shade200
          : Colors.grey.shade800;
    } else if (activityCount <= 2) {
      bgColor = Colors.green.shade300;
    } else if (activityCount <= 5) {
      bgColor = Colors.green.shade500;
    } else {
      bgColor = Colors.green.shade700;
    }

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: isToday && !isSelected
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Colors.white
                  : isFuture
                      ? Colors.grey
                      : (activityCount > 0 ? Colors.white : null),
            ),
          ),
          if (activityCount > 0 && !isSelected)
            Text(
              '$activityCount',
              style: const TextStyle(
                fontSize: 8,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: context.subtitleColor),
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final dynamic achievement;

  const _AchievementTile({required this.achievement});

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      var date = DateTime.parse(dateStr);
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
                    Text(formattedTime, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
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
