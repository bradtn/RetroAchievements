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
  final bool hasLoadedFromDisk; // Track if we've checked disk cache
  final double progress;
  final String? error;
  final DateTime? lastUpdated;

  GameCacheState({
    this.games = const [],
    this.isLoading = false,
    this.hasLoadedFromDisk = false,
    this.progress = 0,
    this.error,
    this.lastUpdated,
  });

  GameCacheState copyWith({
    List<CachedGame>? games,
    bool? isLoading,
    bool? hasLoadedFromDisk,
    double? progress,
    String? error,
    DateTime? lastUpdated,
  }) {
    return GameCacheState(
      games: games ?? this.games,
      isLoading: isLoading ?? this.isLoading,
      hasLoadedFromDisk: hasLoadedFromDisk ?? this.hasLoadedFromDisk,
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
          hasLoadedFromDisk: true,
        );
      } else {
        // No cache found, but we've checked
        state = state.copyWith(hasLoadedFromDisk: true);
      }
    } catch (e) {
      // Error loading cache, but we've checked
      state = state.copyWith(hasLoadedFromDisk: true);
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
      final List<Map<String, dynamic>> failedConsoles = [];
      int completed = 0;

      // First pass - fetch all consoles with delay to avoid rate limiting
      for (final console in gamingConsoles) {
        final consoleId = console['ID'] as int;
        final consoleName = console['Name'] as String? ?? 'Unknown';

        try {
          final games = await api.getGameList(consoleId, onlyWithAchievements: true);

          if (games != null && games.isNotEmpty) {
            for (final game in games) {
              final numAch = game['NumAchievements'] ?? 0;
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
          } else {
            // Mark for retry
            failedConsoles.add(console);
          }
        } catch (e) {
          failedConsoles.add(console);
        }

        completed++;
        state = state.copyWith(progress: completed / (gamingConsoles.length + failedConsoles.length));

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Retry failed consoles with longer delays
      if (failedConsoles.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 2)); // Wait before retries

        for (final console in failedConsoles) {
          final consoleId = console['ID'] as int;
          final consoleName = console['Name'] as String? ?? 'Unknown';

          try {
            final games = await api.getGameList(consoleId, onlyWithAchievements: true);

            if (games != null) {
              for (final game in games) {
                final numAch = game['NumAchievements'] ?? 0;
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
            // Give up on this console
          }

          completed++;
          state = state.copyWith(progress: completed / (gamingConsoles.length + failedConsoles.length));

          // Longer delay for retries
          await Future.delayed(const Duration(milliseconds: 500));
        }
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

    final normalizedQuery = _normalizeString(query.toLowerCase());
    return state.games
        .where((g) => _normalizeString(g.title.toLowerCase()).contains(normalizedQuery))
        .take(50)
        .toList();
  }

  /// Remove accents/diacritics from string for better search matching
  /// e.g., "Pokémon" -> "pokemon", "Señor" -> "senor"
  String _normalizeString(String input) {
    const accents = 'àáâãäåæçèéêëìíîïðñòóôõöøùúûüýÿ';
    const normalized = 'aaaaaaaceeeeiiiidnoooooouuuuyy';

    var result = input;
    for (var i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], normalized[i]);
    }
    return result;
  }
}
