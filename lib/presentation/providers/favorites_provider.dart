import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A favorite game entry
class FavoriteGame {
  final int gameId;
  final String title;
  final String imageIcon;
  final String consoleName;
  final int numAchievements;
  final int earnedAchievements;
  final DateTime addedAt;
  final bool isPinned; // For widget

  FavoriteGame({
    required this.gameId,
    required this.title,
    required this.imageIcon,
    required this.consoleName,
    required this.numAchievements,
    required this.earnedAchievements,
    required this.addedAt,
    this.isPinned = false,
  });

  double get progress => numAchievements > 0 ? earnedAchievements / numAchievements : 0;
  int get percent => (progress * 100).toInt();

  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'title': title,
    'imageIcon': imageIcon,
    'consoleName': consoleName,
    'numAchievements': numAchievements,
    'earnedAchievements': earnedAchievements,
    'addedAt': addedAt.toIso8601String(),
    'isPinned': isPinned,
  };

  factory FavoriteGame.fromJson(Map<String, dynamic> json) => FavoriteGame(
    gameId: json['gameId'] ?? 0,
    title: json['title'] ?? '',
    imageIcon: json['imageIcon'] ?? '',
    consoleName: json['consoleName'] ?? '',
    numAchievements: json['numAchievements'] ?? 0,
    earnedAchievements: json['earnedAchievements'] ?? 0,
    addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
    isPinned: json['isPinned'] ?? false,
  );

  FavoriteGame copyWith({
    int? gameId,
    String? title,
    String? imageIcon,
    String? consoleName,
    int? numAchievements,
    int? earnedAchievements,
    DateTime? addedAt,
    bool? isPinned,
  }) => FavoriteGame(
    gameId: gameId ?? this.gameId,
    title: title ?? this.title,
    imageIcon: imageIcon ?? this.imageIcon,
    consoleName: consoleName ?? this.consoleName,
    numAchievements: numAchievements ?? this.numAchievements,
    earnedAchievements: earnedAchievements ?? this.earnedAchievements,
    addedAt: addedAt ?? this.addedAt,
    isPinned: isPinned ?? this.isPinned,
  );
}

class FavoritesState {
  final List<FavoriteGame> favorites;
  final bool isLoading;

  FavoritesState({
    this.favorites = const [],
    this.isLoading = true,
  });

  FavoritesState copyWith({
    List<FavoriteGame>? favorites,
    bool? isLoading,
  }) => FavoritesState(
    favorites: favorites ?? this.favorites,
    isLoading: isLoading ?? this.isLoading,
  );

  bool isFavorite(int gameId) => favorites.any((f) => f.gameId == gameId);
  FavoriteGame? getPinned() => favorites.where((f) => f.isPinned).firstOrNull;
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  static const _storageKey = 'favorite_games';

  FavoritesNotifier() : super(FavoritesState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List<dynamic>;
        final favorites = list.map((e) => FavoriteGame.fromJson(e)).toList();
        state = state.copyWith(favorites: favorites, isLoading: false);
      } catch (_) {
        state = state.copyWith(isLoading: false);
      }
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(state.favorites.map((f) => f.toJson()).toList());
    await prefs.setString(_storageKey, json);
    await _updateWidgetData(prefs);
  }

  Future<void> _updateWidgetData(SharedPreferences prefs) async {
    final pinned = state.getPinned();
    if (pinned != null) {
      await prefs.setString('widget_game_title', pinned.title);
      await prefs.setString('widget_console_name', pinned.consoleName);
      await prefs.setInt('widget_earned', pinned.earnedAchievements);
      await prefs.setInt('widget_total', pinned.numAchievements);
      await prefs.setInt('widget_game_id', pinned.gameId);
      await prefs.setString('widget_image_url', pinned.imageIcon);
    } else {
      await prefs.setString('widget_game_title', 'No game pinned');
      await prefs.setString('widget_console_name', 'Pin a game from Favorites');
      await prefs.setInt('widget_earned', 0);
      await prefs.setInt('widget_total', 0);
      await prefs.setInt('widget_game_id', 0);
      await prefs.setString('widget_image_url', '');
    }
  }

  Future<void> addFavorite(FavoriteGame game) async {
    if (state.isFavorite(game.gameId)) return;
    state = state.copyWith(
      favorites: [...state.favorites, game],
    );
    await _save();
  }

  Future<void> removeFavorite(int gameId) async {
    state = state.copyWith(
      favorites: state.favorites.where((f) => f.gameId != gameId).toList(),
    );
    await _save();
  }

  Future<void> toggleFavorite(FavoriteGame game) async {
    if (state.isFavorite(game.gameId)) {
      await removeFavorite(game.gameId);
    } else {
      await addFavorite(game);
    }
  }

  Future<void> updateProgress(int gameId, int earned, int total) async {
    final index = state.favorites.indexWhere((f) => f.gameId == gameId);
    if (index == -1) return;

    final updated = state.favorites[index].copyWith(
      earnedAchievements: earned,
      numAchievements: total,
    );
    final newList = [...state.favorites];
    newList[index] = updated;
    state = state.copyWith(favorites: newList);
    await _save();
  }

  Future<void> setPinned(int gameId) async {
    // Unpin all, then pin the selected one
    final newList = state.favorites.map((f) {
      return f.copyWith(isPinned: f.gameId == gameId);
    }).toList();
    state = state.copyWith(favorites: newList);
    await _save();
  }

  Future<void> unpinAll() async {
    final newList = state.favorites.map((f) => f.copyWith(isPinned: false)).toList();
    state = state.copyWith(favorites: newList);
    await _save();
  }
}

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier();
});
