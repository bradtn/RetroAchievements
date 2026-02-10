import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/streak_provider.dart';
import '../widgets/premium_gate.dart';
import 'streaks/streaks_widgets.dart';

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
        _buildStreakCards(streakState),
        const SizedBox(height: 24),
        _buildCalendarHeader(),
        const SizedBox(height: 8),
        _buildMonthStats(streakState),
        const SizedBox(height: 12),
        _buildActivityCalendar(streakState),
        const SizedBox(height: 24),
        _buildLegend(),
        const SizedBox(height: 24),
        _buildActivityStats(streakState),
      ],
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
                ? (streakState.hasActivityToday ? 'Active today!' : 'Play today to continue!')
                : 'Start a new streak!',
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

  Widget _buildCalendarHeader() {
    final streakState = ref.watch(streakProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final newMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
            setState(() => _selectedMonth = newMonth);
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
                getMonthName(_selectedMonth),
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
                  setState(() => _selectedMonth = newMonth);
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
                        setState(() => _selectedMonth = newMonth);
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

  Widget _buildMonthStats(StreakState streakState) {
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
    final firstWeekday = firstDayOfMonth.weekday % 7;

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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final dayNumber = index - firstWeekday + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox();
              }

              final date = DateTime(_selectedMonth.year, _selectedMonth.month, dayNumber);
              final activityCount = streakState.activityMap[date] ?? 0;
              final isTodayDate = isToday(date);
              final isFuture = date.isAfter(DateTime.now());

              return CalendarDay(
                day: dayNumber,
                activityCount: activityCount,
                isToday: isTodayDate,
                isFuture: isFuture,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        LegendItem(color: Colors.grey.shade300, label: 'No activity'),
        const SizedBox(width: 16),
        LegendItem(color: Colors.green.shade300, label: '1-2'),
        const SizedBox(width: 16),
        LegendItem(color: Colors.green.shade500, label: '3-5'),
        const SizedBox(width: 16),
        LegendItem(color: Colors.green.shade700, label: '6+'),
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
                StatItem(value: '$totalDays', label: 'Active Days'),
                StatItem(value: '$totalAchievements', label: 'Achievements'),
                StatItem(value: avgPerDay, label: 'Avg/Day'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
