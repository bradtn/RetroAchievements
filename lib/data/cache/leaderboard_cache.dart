/// In-memory cache for leaderboard entries with TTL
/// Prefetches entries for leaderboards the user has entries on
class LeaderboardCache {
  static LeaderboardCache? _instance;
  static LeaderboardCache get instance => _instance ??= LeaderboardCache._();

  LeaderboardCache._();

  // Cache structure: leaderboardId -> (entries, timestamp)
  final Map<int, _CachedEntries> _cache = {};

  // Cache TTL - 5 minutes (leaderboard data can change frequently)
  static const Duration _ttl = Duration(minutes: 5);

  /// Get cached entries for a leaderboard
  /// Returns null if not cached or expired
  List<Map<String, dynamic>>? get(int leaderboardId) {
    final cached = _cache[leaderboardId];
    if (cached == null) return null;

    // Check if expired
    if (DateTime.now().difference(cached.timestamp) > _ttl) {
      _cache.remove(leaderboardId);
      return null;
    }

    return cached.entries;
  }

  /// Cache entries for a leaderboard
  void put(int leaderboardId, List<Map<String, dynamic>> entries) {
    _cache[leaderboardId] = _CachedEntries(
      entries: entries,
      timestamp: DateTime.now(),
    );
  }

  /// Check if a leaderboard is cached and not expired
  bool has(int leaderboardId) {
    return get(leaderboardId) != null;
  }

  /// Remove a specific leaderboard from cache
  void remove(int leaderboardId) {
    _cache.remove(leaderboardId);
  }

  /// Clear all cached entries
  void clear() {
    _cache.clear();
  }

  /// Clear expired entries (call periodically to free memory)
  void clearExpired() {
    final now = DateTime.now();
    _cache.removeWhere((_, cached) => now.difference(cached.timestamp) > _ttl);
  }

  /// Get cache stats
  int get size => _cache.length;
}

class _CachedEntries {
  final List<Map<String, dynamic>> entries;
  final DateTime timestamp;

  _CachedEntries({required this.entries, required this.timestamp});
}
