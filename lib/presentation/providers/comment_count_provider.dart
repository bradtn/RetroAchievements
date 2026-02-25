import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

/// Provider that caches achievement comment counts
/// Key: achievementId, Value: comment count
final commentCountCacheProvider = NotifierProvider<CommentCountNotifier, Map<int, int>>(
  CommentCountNotifier.new,
);

class CommentCountNotifier extends Notifier<Map<int, int>> {
  final Set<int> _fetching = {};

  @override
  Map<int, int> build() => {};

  /// Get cached count for an achievement, or null if not cached
  int? getCount(int achievementId) => state[achievementId];

  /// Check if we have a cached count
  bool hasCount(int achievementId) => state.containsKey(achievementId);

  /// Fetch and cache comment count for an achievement
  Future<int> fetchCount(int achievementId) async {
    // Return cached value if available
    if (state.containsKey(achievementId)) {
      return state[achievementId]!;
    }

    // Avoid duplicate fetches
    if (_fetching.contains(achievementId)) {
      // Wait for existing fetch to complete
      while (_fetching.contains(achievementId)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return state[achievementId] ?? 0;
    }

    _fetching.add(achievementId);

    try {
      final api = ref.read(apiDataSourceProvider);
      final comments = await api.getAchievementComments(achievementId);
      final count = comments.length;

      state = {...state, achievementId: count};
      return count;
    } finally {
      _fetching.remove(achievementId);
    }
  }

  /// Fetch counts for multiple achievements in parallel (with throttling)
  Future<void> fetchCountsForAchievements(List<int> achievementIds) async {
    // Filter out already cached
    final toFetch = achievementIds.where((id) => !state.containsKey(id) && !_fetching.contains(id)).toList();

    if (toFetch.isEmpty) return;

    // Fetch in batches of 5 to avoid overwhelming the API
    const batchSize = 5;
    for (var i = 0; i < toFetch.length; i += batchSize) {
      final batch = toFetch.skip(i).take(batchSize).toList();
      await Future.wait(batch.map((id) => fetchCount(id)));
      // Small delay between batches
      if (i + batchSize < toFetch.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  /// Update cache with a known count (e.g., from modal fetch)
  void setCount(int achievementId, int count) {
    state = {...state, achievementId: count};
  }
}
