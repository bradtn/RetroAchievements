import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/datasources/ra_api_datasource.dart';
import 'auth_provider.dart';

/// A favorite game entry
class FavoriteGame {
  final int gameId;
  final String title;
  final String imageIcon;
  final String consoleName;
  final int numAchievements;
  final int earnedAchievements;
  final int totalPoints;
  final int earnedPoints;
  final DateTime addedAt;
  final bool isPinned; // For widget
  final bool fromWishlist; // Synced from RA wishlist

  FavoriteGame({
    required this.gameId,
    required this.title,
    required this.imageIcon,
    required this.consoleName,
    required this.numAchievements,
    required this.earnedAchievements,
    this.totalPoints = 0,
    this.earnedPoints = 0,
    required this.addedAt,
    this.isPinned = false,
    this.fromWishlist = false,
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
    'totalPoints': totalPoints,
    'earnedPoints': earnedPoints,
    'addedAt': addedAt.toIso8601String(),
    'isPinned': isPinned,
    'fromWishlist': fromWishlist,
  };

  factory FavoriteGame.fromJson(Map<String, dynamic> json) => FavoriteGame(
    gameId: json['gameId'] ?? 0,
    title: json['title'] ?? '',
    imageIcon: json['imageIcon'] ?? '',
    consoleName: json['consoleName'] ?? '',
    numAchievements: json['numAchievements'] ?? 0,
    earnedAchievements: json['earnedAchievements'] ?? 0,
    totalPoints: json['totalPoints'] ?? 0,
    earnedPoints: json['earnedPoints'] ?? 0,
    addedAt: DateTime.tryParse(json['addedAt'] ?? '') ?? DateTime.now(),
    isPinned: json['isPinned'] ?? false,
    fromWishlist: json['fromWishlist'] ?? false,
  );

  FavoriteGame copyWith({
    int? gameId,
    String? title,
    String? imageIcon,
    String? consoleName,
    int? numAchievements,
    int? earnedAchievements,
    int? totalPoints,
    int? earnedPoints,
    DateTime? addedAt,
    bool? isPinned,
    bool? fromWishlist,
  }) => FavoriteGame(
    gameId: gameId ?? this.gameId,
    title: title ?? this.title,
    imageIcon: imageIcon ?? this.imageIcon,
    consoleName: consoleName ?? this.consoleName,
    numAchievements: numAchievements ?? this.numAchievements,
    earnedAchievements: earnedAchievements ?? this.earnedAchievements,
    totalPoints: totalPoints ?? this.totalPoints,
    earnedPoints: earnedPoints ?? this.earnedPoints,
    addedAt: addedAt ?? this.addedAt,
    isPinned: isPinned ?? this.isPinned,
    fromWishlist: fromWishlist ?? this.fromWishlist,
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

class FavoritesNotifier extends Notifier<FavoritesState> {
  static const _storageKey = 'favorite_games';
  static const _widgetChannel = MethodChannel('com.retrotracker.retrotracker/widget');
  late final RAApiDataSource? _api;
  late final String? _username;

  @override
  FavoritesState build() {
    _api = ref.watch(apiDataSourceProvider);
    _username = ref.watch(authProvider).username;
    _load();
    return FavoritesState();
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

    // Sync wishlist after loading local favorites
    if (_api != null && _username != null) {
      syncFromWishlist();
    }
  }

  /// Sync games from RA wishlist into favorites
  Future<void> syncFromWishlist() async {
    final api = _api;
    final username = _username;
    if (api == null || username == null) return;

    try {
      final wishlist = await api.getUserWantToPlayList(username);
      if (wishlist == null || wishlist.isEmpty) return;

      bool hasChanges = false;
      final currentFavorites = List<FavoriteGame>.from(state.favorites);

      for (final game in wishlist) {
        final gameId = game['ID'] ?? game['GameID'];
        if (gameId == null) continue;

        final id = gameId is int ? gameId : int.tryParse(gameId.toString()) ?? 0;
        if (id == 0) continue;

        // Skip if already in favorites
        if (currentFavorites.any((f) => f.gameId == id)) continue;

        // Add to favorites with fromWishlist flag
        final favorite = FavoriteGame(
          gameId: id,
          title: game['Title'] ?? 'Unknown Game',
          imageIcon: game['ImageIcon'] ?? '',
          consoleName: game['ConsoleName'] ?? '',
          numAchievements: game['AchievementCount'] ?? game['NumAchievements'] ?? 0,
          earnedAchievements: 0,
          totalPoints: game['PointsTotal'] ?? game['Points'] ?? 0,
          earnedPoints: 0,
          addedAt: DateTime.now(),
          fromWishlist: true,
        );

        currentFavorites.add(favorite);
        hasChanges = true;
      }

      if (hasChanges) {
        state = state.copyWith(favorites: currentFavorites);
        await _save();
      }
    } catch (e) {
      // Silently fail - wishlist sync is optional
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

    // Notify Android to refresh the widget
    _refreshWidget();
  }

  Future<void> _refreshWidget() async {
    try {
      await _widgetChannel.invokeMethod('updateWidget');
    } catch (e) {
      // Widget update failed, ignore (might be on iOS or no widget)
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

  Future<void> updateProgress(int gameId, int earned, int total, {int? totalPoints, int? earnedPoints}) async {
    final index = state.favorites.indexWhere((f) => f.gameId == gameId);
    if (index == -1) return;

    final updated = state.favorites[index].copyWith(
      earnedAchievements: earned,
      numAchievements: total,
      totalPoints: totalPoints,
      earnedPoints: earnedPoints,
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

final favoritesProvider = NotifierProvider<FavoritesNotifier, FavoritesState>(FavoritesNotifier.new);
