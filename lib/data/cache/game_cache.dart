import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple local cache for game data to reduce API calls
class GameCache {
  static const String _cacheKey = 'game_cache';
  static const String _cacheTimestampKey = 'game_cache_timestamp';
  static const Duration _maxAge = Duration(days: 7); // Cache for a week

  static GameCache? _instance;
  static GameCache get instance => _instance ??= GameCache._();

  GameCache._();

  Map<int, Map<String, dynamic>> _memoryCache = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_cacheKey);
    final timestamp = prefs.getInt(_cacheTimestampKey) ?? 0;

    // Check if cache is still valid
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(cacheTime) > _maxAge) {
      // Cache expired, clear it
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
      _memoryCache = {};
    } else if (json != null) {
      try {
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        _memoryCache = decoded.map((key, value) =>
          MapEntry(int.parse(key), Map<String, dynamic>.from(value)));
      } catch (_) {
        _memoryCache = {};
      }
    }

    _initialized = true;
  }

  /// Get cached game data by ID
  Map<String, dynamic>? get(int gameId) {
    return _memoryCache[gameId];
  }

  /// Get just the image icon path for a game
  String? getImageIcon(int gameId) {
    final game = _memoryCache[gameId];
    return game?['ImageIcon'] as String?;
  }

  /// Cache game data
  Future<void> put(int gameId, Map<String, dynamic> data) async {
    // Only cache essential fields to save space
    _memoryCache[gameId] = {
      'ID': gameId,
      'Title': data['Title'] ?? data['GameTitle'] ?? '',
      'ImageIcon': data['ImageIcon'] ?? '',
      'ConsoleName': data['ConsoleName'] ?? '',
      'ConsoleID': data['ConsoleID'] ?? data['ConsoleId'] ?? 0,
    };
    await _save();
  }

  /// Cache multiple games at once
  Future<void> putAll(List<Map<String, dynamic>> games) async {
    for (final game in games) {
      final id = game['ID'] ?? game['GameID'] ?? game['gameId'];
      if (id != null) {
        final gameId = id is int ? id : int.tryParse(id.toString()) ?? 0;
        if (gameId > 0) {
          _memoryCache[gameId] = {
            'ID': gameId,
            'Title': game['Title'] ?? game['GameTitle'] ?? '',
            'ImageIcon': game['ImageIcon'] ?? '',
            'ConsoleName': game['ConsoleName'] ?? '',
            'ConsoleID': game['ConsoleID'] ?? game['ConsoleId'] ?? 0,
          };
        }
      }
    }
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _memoryCache.map((key, value) => MapEntry(key.toString(), value));
    await prefs.setString(_cacheKey, jsonEncode(encoded));
    await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get cache stats
  int get size => _memoryCache.length;

  /// Clear the cache
  Future<void> clear() async {
    _memoryCache = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimestampKey);
  }
}
