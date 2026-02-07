import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_provider.dart';

// Provider for the game cache
final gameCacheProvider = StateNotifierProvider<GameCacheNotifier, GameCacheState>((ref) {
  return GameCacheNotifier(ref);
});

class GameCacheState {
  final List<CachedGame> games;
  final bool isLoading;
  final double progress;
  final String? error;
  final DateTime? lastUpdated;

  GameCacheState({
    this.games = const [],
    this.isLoading = false,
    this.progress = 0,
    this.error,
    this.lastUpdated,
  });

  GameCacheState copyWith({
    List<CachedGame>? games,
    bool? isLoading,
    double? progress,
    String? error,
    DateTime? lastUpdated,
  }) {
    return GameCacheState(
      games: games ?? this.games,
      isLoading: isLoading ?? this.isLoading,
      progress: progress ?? this.progress,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class CachedGame {
  final int id;
  final String title;
  final String consoleName;
  final int consoleId;
  final String imageIcon;
  final int numAchievements;

  CachedGame({
    required this.id,
    required this.title,
    required this.consoleName,
    required this.consoleId,
    required this.imageIcon,
    required this.numAchievements,
  });

  Map<String, dynamic> toJson() => {
    'i': id,
    't': title,
    'c': consoleName,
    'ci': consoleId,
    'ic': imageIcon,
    'n': numAchievements,
  };

  factory CachedGame.fromJson(Map<String, dynamic> json) => CachedGame(
    id: json['i'] ?? 0,
    title: json['t'] ?? '',
    consoleName: json['c'] ?? '',
    consoleId: json['ci'] ?? 0,
    imageIcon: json['ic'] ?? '',
    numAchievements: json['n'] ?? 0,
  );
}

class GameCacheNotifier extends StateNotifier<GameCacheState> {
  final Ref ref;
  static const String _gamesKey = 'game_cache_v1';
  static const String _lastUpdatedKey = 'game_cache_updated';

  GameCacheNotifier(this.ref) : super(GameCacheState()) {
    _loadFromCache();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final gamesJson = prefs.getString(_gamesKey);
      final lastUpdatedMs = prefs.getInt(_lastUpdatedKey);

      if (gamesJson != null && gamesJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(gamesJson);
        final games = decoded
            .map((g) => CachedGame.fromJson(g as Map<String, dynamic>))
            .toList();
        state = state.copyWith(
          games: games,
          lastUpdated: lastUpdatedMs != null
              ? DateTime.fromMillisecondsSinceEpoch(lastUpdatedMs)
              : null,
        );
      }
    } catch (e) {
      // Ignore cache load errors
    }
  }

  Future<void> buildCache() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, progress: 0, error: null);

    try {
      final api = ref.read(apiDataSourceProvider);

      // Get all consoles first
      final consoles = await api.getConsoles();
      if (consoles == null || consoles.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'Failed to load consoles');
        return;
      }

      // Filter to main gaming consoles (skip hubs, events, etc.)
      final gamingConsoles = consoles.where((c) {
        final id = c['ID'] as int;
        // Skip non-gaming IDs (hubs, events, etc. typically have high IDs or specific ranges)
        return id <= 100 && id != 0;
      }).toList();

      final List<CachedGame> allGames = [];
      int completed = 0;

      for (final console in gamingConsoles) {
        final consoleId = console['ID'] as int;
        final consoleName = console['Name'] as String? ?? 'Unknown';

        try {
          final games = await api.getGameList(consoleId, onlyWithAchievements: true);

          if (games != null) {
            for (final game in games) {
              final numAch = game['NumAchievements'] ?? 0;
              // Only include games that have achievements
              if (numAch > 0) {
                allGames.add(CachedGame(
                  id: game['ID'] ?? 0,
                  title: game['Title'] ?? '',
                  consoleName: consoleName,
                  consoleId: consoleId,
                  imageIcon: game['ImageIcon'] ?? '',
                  numAchievements: numAch,
                ));
              }
            }
          }
        } catch (e) {
          // Continue with next console on error
        }

        completed++;
        state = state.copyWith(progress: completed / gamingConsoles.length);
      }

      // Sort by title
      allGames.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

      // Save to cache
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(allGames.map((g) => g.toJson()).toList());
      await prefs.setString(_gamesKey, jsonString);
      await prefs.setInt(_lastUpdatedKey, DateTime.now().millisecondsSinceEpoch);

      state = GameCacheState(
        games: allGames,
        isLoading: false,
        progress: 1,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to build cache: $e');
    }
  }

  List<CachedGame> search(String query) {
    if (query.isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    return state.games
        .where((g) => g.title.toLowerCase().contains(lowerQuery))
        .take(50)
        .toList();
  }
}
