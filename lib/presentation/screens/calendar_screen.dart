import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/streak_provider.dart';
import '../widgets/premium_gate.dart';
import 'calendar/calendar_helpers.dart';
import 'calendar/calendar_widgets.dart';

export 'calendar/calendar_helpers.dart';
export 'calendar/calendar_widgets.dart';

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
        title: const Text('Streaks'),
      ),
      body: PremiumGate(
        featureName: 'Streaks',
        description: 'Track your streaks and view achievement history.',
        icon: Icons.local_fire_department,
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
                      ? CalendarErrorView(
                          error: streakState.error!,
                          onRetry: _loadMyData,
                        )
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

  Widget _buildContent(StreakState streakState) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          // Streak cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _buildStreakCards(streakState),
          ),

          // Calendar
          _buildCalendar(streakState),

          // Legend
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CalendarLegend(),
          ),

          // Tip text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text(
              'Tap a day to see achievements',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDayAchievements(DateTime date, List<dynamic> achievements) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DayAchievementsModal(
        date: date,
        achievements: achievements,
      ),
    );
  }

  Widget _buildStreakCards(StreakState streakState) {
    return Row(
      children: [
        Expanded(
          child: StreakCard(
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
          child: StreakCard(
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
                      formatMonth(_focusedMonth),
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
              final isSelected = isSameDay(date, _selectedDate);
              final isToday = isSameDay(date, DateTime.now());
              final isFuture = date.isAfter(DateTime.now());

              return GestureDetector(
                onTap: isFuture ? null : () {
                  setState(() => _selectedDate = date);
                  final achievements = _getAchievementsForDate(date, streakState);
                  if (achievements.isNotEmpty) {
                    _showDayAchievements(date, achievements);
                  }
                },
                child: CalendarDay(
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
                            monthNamesShort[index],
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
}
