import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme_utils.dart';
import '../../core/animations.dart';
import '../providers/auth_provider.dart';
import '../providers/streak_provider.dart';
import '../widgets/premium_gate.dart';
import 'share_card_screen.dart';

class StreaksScreen extends ConsumerStatefulWidget {
  const StreaksScreen({super.key});

  @override
  ConsumerState<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends ConsumerState<StreaksScreen> {
  final _usernameController = TextEditingController();
  String? _viewingUsername;
  DateTime _selectedMonth = DateTime.now();

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

  void _loadMyStreaks() {
    final username = ref.read(authProvider).username;
    if (username != null) {
      _usernameController.clear();
      setState(() => _viewingUsername = username);
      ref.read(streakProvider.notifier).loadStreaks(username);
    }
  }

  @override
  Widget build(BuildContext context) {
    final streakState = ref.watch(streakProvider);
    final myUsername = ref.read(authProvider).username;
    final isViewingMyself = _viewingUsername == myUsername;

    return Scaffold(
      appBar: AppBar(
        title: Text(isViewingMyself ? 'My Streaks' : 'Streaks'),
      ),
      body: PremiumGate(
        featureName: 'Streak Tracking',
        description: 'Track your daily gaming streaks. Keep the fire burning and share your progress.',
        icon: Icons.local_fire_department,
        child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      hintText: 'View any user\'s streaks...',
                      prefixIcon: const Icon(Icons.person_search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _searchUser(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: streakState.isLoading ? null : _searchUser,
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
                    onDeleted: _loadMyStreaks,
                    deleteIcon: const Icon(Icons.close, size: 16),
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
            onPressed: _loadMyStreaks,
            child: const Text('View My Streaks'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(StreakState streakState) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16, 0, 16,
        16 + MediaQuery.of(context).viewPadding.bottom,
      ),
      children: [
        // Streak summary cards
        _buildStreakCards(streakState),
        const SizedBox(height: 24),

        // Calendar header
        _buildCalendarHeader(),
        const SizedBox(height: 8),

        // Month stats
        _buildMonthStats(streakState),
        const SizedBox(height: 12),

        // Activity calendar
        _buildActivityCalendar(streakState),
        const SizedBox(height: 24),

        // Legend
        _buildLegend(),
        const SizedBox(height: 24),

        // Recent activity stats
        _buildActivityStats(streakState),
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
                ? (streakState.hasActivityToday ? 'Active today!' : 'Play today to continue!')
                : 'Start a new streak!',
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

  Widget _buildCalendarHeader() {
    final streakState = ref.watch(streakProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final newMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
            setState(() {
              _selectedMonth = newMonth;
            });
            // Load this month's data if not already loaded
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
                _getMonthName(_selectedMonth),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: context.subtitleColor),
              if (streakState.isLoadingMonth)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: SizedBox(
                    width: 16,
                    height: 16,
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
          onPressed: _selectedMonth.isBefore(DateTime(DateTime.now().year, DateTime.now().month))
              ? () {
                  final newMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                  setState(() {
                    _selectedMonth = newMonth;
                  });
                  // Load this month's data if not already loaded
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
    );
  }

  void _showMonthYearPicker() {
    int selectedYear = _selectedMonth.year;
    int selectedMonthIndex = _selectedMonth.month - 1;
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
                  // Drag handle
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
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
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
                        onTap: isFuture ? null : () {
                          setModalState(() => selectedMonthIndex = index);
                        },
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
                                  : isFuture
                                      ? Colors.grey
                                      : null,
                              fontWeight: isSelected ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final newMonth = DateTime(selectedYear, selectedMonthIndex + 1);
                        Navigator.pop(context);
                        setState(() {
                          _selectedMonth = newMonth;
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

  String _getMonthName(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildMonthStats(StreakState streakState) {
    // Count achievements for the currently selected month
    int monthAchievements = 0;
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    for (final entry in streakState.activityMap.entries) {
      if (entry.key.isAfter(firstDay.subtract(const Duration(days: 1))) &&
          entry.key.isBefore(lastDay.add(const Duration(days: 1)))) {
        monthAchievements += entry.value;
      }
    }

    final monthKey = '${_selectedMonth.year}-${_selectedMonth.month}';
    final isLoaded = streakState.loadedMonths.contains(monthKey);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.blue.shade50
            : Colors.blue.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isLoaded ? Icons.check_circle : Icons.cloud_download,
            size: 16,
            color: isLoaded ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            isLoaded
                ? '$monthAchievements achievements this month'
                : 'Data not loaded - navigate here to load',
            style: TextStyle(
              fontSize: 12,
              color: context.subtitleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCalendar(StreakState streakState) {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final firstWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.grey.shade100
            : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => SizedBox(
                      width: 36,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.subtitleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: 42, // 6 weeks max
            itemBuilder: (context, index) {
              final dayNumber = index - firstWeekday + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox();
              }

              final date = DateTime(_selectedMonth.year, _selectedMonth.month, dayNumber);
              final activityCount = streakState.activityMap[date] ?? 0;
              final isToday = _isToday(date);
              final isFuture = date.isAfter(DateTime.now());

              return _CalendarDay(
                day: dayNumber,
                activityCount: activityCount,
                isToday: isToday,
                isFuture: isFuture,
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: Colors.grey.shade300, label: 'No activity'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.green.shade300, label: '1-2'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.green.shade500, label: '3-5'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.green.shade700, label: '6+'),
      ],
    );
  }

  Widget _buildActivityStats(StreakState streakState) {
    final totalDays = streakState.activityMap.length;
    final totalAchievements = streakState.activityMap.values.fold<int>(0, (a, b) => a + b);
    final avgPerDay = totalDays > 0 ? (totalAchievements / totalDays).toStringAsFixed(1) : '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last 90 Days',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(value: '$totalDays', label: 'Active Days'),
                _StatItem(value: '$totalAchievements', label: 'Achievements'),
                _StatItem(value: avgPerDay, label: 'Avg/Day'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _shareStreak(StreakState streakState) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShareCardScreen(
          type: ShareCardType.streak,
          data: {
            'currentStreak': streakState.currentStreak,
            'bestStreak': streakState.bestStreak,
            'username': _viewingUsername ?? '',
            'isActive': streakState.isStreakActive,
          },
        ),
      ),
    );
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
    final isMilestone = StreakMilestoneBadge.isMilestone(value);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
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
                  AnimatedStreakFlame(streakDays: value, size: 24)
                else
                  Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isMilestone) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: StreakMilestoneBadge(streakDays: value),
                  ),
                ],
              ],
            ),
            Text(
              value == 1 ? 'day' : 'days',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
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
  final bool isToday;
  final bool isFuture;

  const _CalendarDay({
    required this.day,
    required this.activityCount,
    required this.isToday,
    required this.isFuture,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    if (isFuture) {
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
        border: isToday
            ? Border.all(color: Colors.orange, width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: isFuture
                ? Colors.grey
                : (activityCount > 0 ? Colors.white : null),
          ),
        ),
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
          style: TextStyle(
            fontSize: 10,
            color: context.subtitleColor,
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.subtitleColor,
          ),
        ),
      ],
    );
  }
}
