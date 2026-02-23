import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/ra_api_datasource.dart';
import 'auth_provider.dart';

// Provider for streak data
final streakProvider = NotifierProvider<StreakNotifier, StreakState>(StreakNotifier.new);

class StreakState {
  final int currentStreak;
  final int bestStreak;
  final Map<DateTime, int> activityMap; // date -> achievement count
  final Map<DateTime, List<dynamic>> achievementsByDate; // date -> achievements list
  final DateTime? lastActivityDate;
  final bool isLoading;
  final bool isLoadingMonth;
  final String? error;
  final DateTime? lastUpdated;
  final Set<String> loadedMonths; // track which months have been loaded

  StreakState({
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.activityMap = const {},
    this.achievementsByDate = const {},
    this.lastActivityDate,
    this.isLoading = false,
    this.isLoadingMonth = false,
    this.error,
    this.lastUpdated,
    this.loadedMonths = const {},
  });

  StreakState copyWith({
    int? currentStreak,
    int? bestStreak,
    Map<DateTime, int>? activityMap,
    Map<DateTime, List<dynamic>>? achievementsByDate,
    DateTime? lastActivityDate,
    bool? isLoading,
    bool? isLoadingMonth,
    String? error,
    DateTime? lastUpdated,
    Set<String>? loadedMonths,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      activityMap: activityMap ?? this.activityMap,
      achievementsByDate: achievementsByDate ?? this.achievementsByDate,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMonth: isLoadingMonth ?? this.isLoadingMonth,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      loadedMonths: loadedMonths ?? this.loadedMonths,
    );
  }

  bool get isStreakActive {
    if (lastActivityDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastDate = DateTime(lastActivityDate!.year, lastActivityDate!.month, lastActivityDate!.day);
    return lastDate == today || lastDate == yesterday;
  }

  bool get hasActivityToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return activityMap.containsKey(today) && activityMap[today]! > 0;
  }
}

class StreakNotifier extends Notifier<StreakState> {
  // Use getter to safely access the API data source without late initialization issues
  RAApiDataSource get _api => ref.read(apiDataSourceProvider);
  String? _currentUsername;

  @override
  StreakState build() {
    return StreakState();
  }

  Future<void> loadStreaks(String username) async {
    if (state.isLoading) return;

    // Reset if switching users
    if (_currentUsername != username) {
      _currentUsername = username;
      state = StreakState(isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    try {
      final now = DateTime.now();

      // Load current month and previous month for streak calculation
      // (streak might span month boundary)
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final prevMonthStart = DateTime(now.year, now.month - 1, 1);

      // Fetch both months with recursive splitting to handle power users
      final currentMonthAchievements = await _fetchAchievementsWithSplitting(
        username, currentMonthStart, now,
      );
      final prevMonthEnd = currentMonthStart.subtract(const Duration(days: 1));
      final prevMonthAchievements = await _fetchAchievementsWithSplitting(
        username, prevMonthStart, prevMonthEnd,
      );

      // Combine achievements
      final achievements = [...prevMonthAchievements, ...currentMonthAchievements];

      // Build activity map and achievements by date
      final activityMap = <DateTime, int>{};
      final achievementsByDate = <DateTime, List<dynamic>>{};
      DateTime? lastActivityDate;
      final loadedMonths = <String>{
        '${currentMonthStart.year}-${currentMonthStart.month}',
        '${prevMonthStart.year}-${prevMonthStart.month}',
      };

      for (final ach in achievements) {
        final dateStr = ach['Date'] ?? ach['DateEarned'] ?? '';
        if (dateStr.isEmpty) continue;

        try {
          final date = DateTime.parse(dateStr);
          final dayOnly = DateTime(date.year, date.month, date.day);
          activityMap[dayOnly] = (activityMap[dayOnly] ?? 0) + 1;
          achievementsByDate.putIfAbsent(dayOnly, () => []).add(ach);

          if (lastActivityDate == null || dayOnly.isAfter(lastActivityDate)) {
            lastActivityDate = dayOnly;
          }
        } catch (e) {
          // Skip invalid dates
        }
      }

      // Calculate current streak
      final currentStreak = _calculateCurrentStreak(activityMap);
      final bestStreak = _calculateBestStreak(activityMap);

      state = StreakState(
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        activityMap: activityMap,
        achievementsByDate: achievementsByDate,
        lastActivityDate: lastActivityDate,
        isLoading: false,
        lastUpdated: DateTime.now(),
        loadedMonths: loadedMonths,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to calculate streaks: $e',
      );
    }
  }

  /// Fetches achievements for a date range, recursively splitting if we hit the 500 cap
  Future<List<dynamic>> _fetchAchievementsWithSplitting(
    String username,
    DateTime from,
    DateTime to,
  ) async {
    final achievements = await _api.getAchievementsEarnedBetween(username, from, to);

    if (achievements == null) return [];

    // If we got exactly 500, we likely hit the API cap - split and recurse
    if (achievements.length == 500) {
      final midpoint = from.add(Duration(days: to.difference(from).inDays ~/ 2));

      // Don't split if range is already 1 day (can't split further)
      if (midpoint.isAfter(from) && midpoint.isBefore(to)) {
        final firstHalf = await _fetchAchievementsWithSplitting(username, from, midpoint);
        final secondHalf = await _fetchAchievementsWithSplitting(
          username,
          midpoint.add(const Duration(days: 1)),
          to,
        );
        return [...firstHalf, ...secondHalf];
      }
    }

    return achievements;
  }

  Future<void> loadMonth(String username, int year, int month) async {
    final monthKey = '$year-$month';

    // Skip if already loaded or currently loading
    if (state.loadedMonths.contains(monthKey) || state.isLoadingMonth) {
      return;
    }

    state = state.copyWith(isLoadingMonth: true);

    try {
      final firstDay = DateTime(year, month, 1);
      final lastDay = DateTime(year, month + 1, 0);

      // Use recursive splitting to handle power users
      final achievements = await _fetchAchievementsWithSplitting(
        username,
        firstDay,
        lastDay,
      );

      // Merge with existing activity map and achievements
      final activityMap = Map<DateTime, int>.from(state.activityMap);
      final achievementsByDate = Map<DateTime, List<dynamic>>.from(
        state.achievementsByDate.map((k, v) => MapEntry(k, List<dynamic>.from(v))),
      );

      for (final ach in achievements) {
        final dateStr = ach['Date'] ?? ach['DateEarned'] ?? '';
        if (dateStr.isEmpty) continue;

        try {
          final date = DateTime.parse(dateStr);
          final dayOnly = DateTime(date.year, date.month, date.day);
          activityMap[dayOnly] = (activityMap[dayOnly] ?? 0) + 1;
          achievementsByDate.putIfAbsent(dayOnly, () => []).add(ach);
        } catch (e) {
          // Skip invalid dates
        }
      }

      final loadedMonths = Set<String>.from(state.loadedMonths)..add(monthKey);

      // Recalculate streaks with new data
      final currentStreak = _calculateCurrentStreak(activityMap);
      final bestStreak = _calculateBestStreak(activityMap);

      DateTime? lastActivityDate = state.lastActivityDate;
      for (final date in activityMap.keys) {
        if (lastActivityDate == null || date.isAfter(lastActivityDate)) {
          lastActivityDate = date;
        }
      }

      state = state.copyWith(
        activityMap: activityMap,
        achievementsByDate: achievementsByDate,
        loadedMonths: loadedMonths,
        isLoadingMonth: false,
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        lastActivityDate: lastActivityDate,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMonth: false);
    }
  }

  int _calculateCurrentStreak(Map<DateTime, int> activityMap) {
    if (activityMap.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Streak must include today or yesterday to be "current"
    if (!activityMap.containsKey(today) && !activityMap.containsKey(yesterday)) {
      return 0;
    }

    // Start from today or yesterday, count backwards
    DateTime checkDate = activityMap.containsKey(today) ? today : yesterday;
    int streak = 0;

    while (activityMap.containsKey(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  int _calculateBestStreak(Map<DateTime, int> activityMap) {
    if (activityMap.isEmpty) return 0;

    // Sort dates
    final sortedDates = activityMap.keys.toList()..sort();

    int bestStreak = 1;
    int currentStreak = 1;

    for (int i = 1; i < sortedDates.length; i++) {
      final prevDate = sortedDates[i - 1];
      final currDate = sortedDates[i];
      final diff = currDate.difference(prevDate).inDays;

      if (diff == 1) {
        currentStreak++;
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
        }
      } else {
        currentStreak = 1;
      }
    }

    return bestStreak;
  }

  void clear() {
    state = StreakState();
  }
}
