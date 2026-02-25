import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';

/// Provider that caches achievement comment counts
/// Key: achievementId, Value: comment count
/// Persists to disk so counts are available instantly on subsequent visits
final commentCountCacheProvider = NotifierProvider<CommentCountNotifier, Map<int, int>>(
  CommentCountNotifier.new,
);

class CommentCountNotifier extends Notifier<Map<int, int>> {
  static const _cacheKey = 'comment_counts_cache';
  bool _isFetching = false;
  final List<int> _queue = [];
  Completer<void>? _diskLoadCompleter;

  @override
  Map<int, int> build() {
    // Load from disk asynchronously on first access
    _diskLoadCompleter = Completer<void>();
    _loadFromDisk();
    return {};
  }

  /// Wait for disk cache to be loaded
  Future<void> _ensureDiskLoaded() async {
    if (_diskLoadCompleter != null && !_diskLoadCompleter!.isCompleted) {
      await _diskLoadCompleter!.future;
    }
  }

  /// Load cached counts from SharedPreferences
  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr != null) {
        final Map<String, dynamic> decoded = json.decode(jsonStr);
        final loaded = <int, int>{};
        for (final entry in decoded.entries) {
          final id = int.tryParse(entry.key);
          final count = entry.value as int?;
          if (id != null && count != null) {
            loaded[id] = count;
          }
        }
        if (loaded.isNotEmpty) {
          state = {...state, ...loaded};
        }
      }
    } catch (_) {
      // Ignore errors loading cache
    } finally {
      _diskLoadCompleter?.complete();
    }
  }

  /// Save current cache to SharedPreferences
  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convert int keys to string keys for JSON
      final toSave = <String, int>{};
      for (final entry in state.entries) {
        toSave[entry.key.toString()] = entry.value;
      }
      await prefs.setString(_cacheKey, json.encode(toSave));
    } catch (_) {
      // Ignore errors saving cache
    }
  }

  /// Get cached count for an achievement, or null if not cached
  int? getCount(int achievementId) => state[achievementId];

  /// Check if we have a cached count
  bool hasCount(int achievementId) => state.containsKey(achievementId);

  /// Queue achievements for fetching (called when game page loads)
  void queueAchievements(List<int> achievementIds) {
    // Wait for disk cache to load before deciding what to queue
    _ensureDiskLoaded().then((_) {
      for (final id in achievementIds) {
        if (!state.containsKey(id) && !_queue.contains(id)) {
          _queue.add(id);
        }
      }
      _processQueue();
    });
  }

  /// Process queue one at a time with delays
  Future<void> _processQueue() async {
    if (_isFetching || _queue.isEmpty) return;

    _isFetching = true;
    int fetchedCount = 0;

    while (_queue.isNotEmpty) {
      final achievementId = _queue.removeAt(0);

      // Skip if already cached
      if (state.containsKey(achievementId)) continue;

      try {
        final api = ref.read(apiDataSourceProvider);
        final comments = await api.getAchievementComments(achievementId);

        if (comments != null) {
          state = {...state, achievementId: comments.length};
          fetchedCount++;

          // Save to disk every 5 fetches to avoid excessive writes
          if (fetchedCount % 5 == 0) {
            _saveToDisk();
          }
        }
      } catch (_) {
        // Ignore errors, just don't cache
      }

      // Wait 200ms between requests (tested: 5 req/sec is safe)
      if (_queue.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    // Save remaining to disk when done
    if (fetchedCount > 0) {
      _saveToDisk();
    }

    _isFetching = false;
  }

  /// Fetch a single achievement's count (for modal - higher priority)
  Future<int?> fetchSingle(int achievementId) async {
    // Return cached value if available
    if (state.containsKey(achievementId)) {
      return state[achievementId];
    }

    try {
      final api = ref.read(apiDataSourceProvider);
      final comments = await api.getAchievementComments(achievementId);

      if (comments != null) {
        final count = comments.length;
        state = {...state, achievementId: count};
        // Remove from queue if it was there
        _queue.remove(achievementId);
        // Save to disk
        _saveToDisk();
        return count;
      }
    } catch (_) {
      // Ignore errors
    }

    return null;
  }

  /// Update cache with a known count (e.g., from tips sheet)
  void setCount(int achievementId, int count) {
    state = {...state, achievementId: count};
    _queue.remove(achievementId);
    _saveToDisk();
  }
}
