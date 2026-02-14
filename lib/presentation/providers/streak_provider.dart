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
  late final RAApiDataSource _api;
  String? _currentUsername;

  @override
  StreakState build() {
    _api = ref.watch(apiDataSourceProvider);
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

      // Get achievements from the start of the calendar year for streak calculation
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);

      final achievements = await _api.getAchievementsEarnedBetween(
        username,
        startOfYear,
        now,
      );

      if (achievements == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load achievement history',
        );
        return;
      }

      // Build activity map and achievements by date
      final activityMap = <DateTime, int>{};
      final achievementsByDate = <DateTime, List<dynamic>>{};
      DateTime? lastActivityDate;
      final loadedMonths = <String>{};

      // Mark all months in the year range as loaded (even if no achievements)
      DateTime checkDate = startOfYear;
      while (!checkDate.isAfter(now)) {
        loadedMonths.add('${checkDate.year}-${checkDate.month}');
        // Move to next month
        checkDate = DateTime(checkDate.year, checkDate.month + 1, 1);
      }

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

      final achievements = await _api.getAchievementsEarnedBetween(
        username,
        firstDay,
        lastDay,
      );

      if (achievements == null) {
        state = state.copyWith(isLoadingMonth: false);
        return;
      }

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

      state = state.copyWith(
        activityMap: activityMap,
        achievementsByDate: achievementsByDate,
        loadedMonths: loadedMonths,
        isLoadingMonth: false,
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
