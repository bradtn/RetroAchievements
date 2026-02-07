import 'package:dio/dio.dart';

class RAApiDataSource {
  final Dio _dio;
  String? _username;
  String? _apiKey;

  RAApiDataSource({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: 'https://retroachievements.org/API/',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  void setCredentials(String username, String apiKey) {
    _username = username;
    _apiKey = apiKey;
  }

  void clearCredentials() {
    _username = null;
    _apiKey = null;
  }

  bool get hasCredentials => _username != null && _apiKey != null;
  String? get username => _username;

  Map<String, dynamic> _authParams() {
    return {
      'z': _username,
      'y': _apiKey,
    };
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String username) async {
    try {
      final response = await _dio.get(
        'API_GetUserProfile.php',
        queryParameters: {
          ..._authParams(),
          'u': username,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get user summary with recent games and achievements
  Future<Map<String, dynamic>?> getUserSummary(String username, {int recentGames = 5, int recentAchievements = 10}) async {
    try {
      final response = await _dio.get(
        'API_GetUserSummary.php',
        queryParameters: {
          ..._authParams(),
          'u': username,
          'g': recentGames,
          'a': recentAchievements,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get recently played games
  Future<List<dynamic>?> getRecentlyPlayedGames(String username, {int count = 10}) async {
    try {
      final response = await _dio.get(
        'API_GetUserRecentlyPlayedGames.php',
        queryParameters: {
          ..._authParams(),
          'u': username,
          'c': count,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get game info with user progress
  Future<Map<String, dynamic>?> getGameInfoWithProgress(int gameId) async {
    try {
      final response = await _dio.get(
        'API_GetGameInfoAndUserProgress.php',
        queryParameters: {
          ..._authParams(),
          'u': _username,
          'g': gameId,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get user's recent achievements
  Future<List<dynamic>?> getRecentAchievements(String username, {int count = 50}) async {
    try {
      final response = await _dio.get(
        'API_GetUserRecentAchievements.php',
        queryParameters: {
          ..._authParams(),
          'u': username,
          'c': count,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get user awards/badges
  Future<Map<String, dynamic>?> getUserAwards(String username) async {
    try {
      final response = await _dio.get(
        'API_GetUserAwards.php',
        queryParameters: {
          ..._authParams(),
          'u': username,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get top users leaderboard
  Future<List<dynamic>?> getTopUsers() async {
    try {
      final response = await _dio.get(
        'API_GetTopTenUsers.php',
        queryParameters: _authParams(),
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get user completed games
  Future<List<dynamic>?> getCompletedGames(String username) async {
    try {
      final response = await _dio.get(
        'API_GetUserCompletedGames.php',
        queryParameters: {
          ..._authParams(),
          'u': username,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get all consoles
  Future<List<dynamic>?> getConsoles() async {
    try {
      final response = await _dio.get(
        'API_GetConsoleIDs.php',
        queryParameters: _authParams(),
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get games for a console
  Future<List<dynamic>?> getGameList(int consoleId, {bool onlyWithAchievements = true}) async {
    try {
      final response = await _dio.get(
        'API_GetGameList.php',
        queryParameters: {
          ..._authParams(),
          'i': consoleId,
          'f': onlyWithAchievements ? 1 : 0,
          'h': 1, // include hashes
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get game info (without user progress)
  Future<Map<String, dynamic>?> getGameInfo(int gameId) async {
    try {
      final response = await _dio.get(
        'API_GetGame.php',
        queryParameters: {
          ..._authParams(),
          'i': gameId,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get Achievement of the Week
  Future<Map<String, dynamic>?> getAchievementOfTheWeek() async {
    try {
      final response = await _dio.get(
        'API_GetAchievementOfTheWeek.php',
        queryParameters: _authParams(),
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get user points (for rank comparison)
  Future<Map<String, dynamic>?> getUserPoints(String username) async {
    try {
      final response = await _dio.get(
        'API_GetUserPoints.php',
        queryParameters: {
          ..._authParams(),
          'u': username,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get user rank and score
  Future<Map<String, dynamic>?> getUserRankAndScore(String username) async {
    try {
      final response = await _dio.get(
        'API_GetUserRankAndScore.php',
        queryParameters: {
          ..._authParams(),
          'u': username,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get game ranking for user
  Future<List<dynamic>?> getGameRankAndScore(int gameId) async {
    try {
      final response = await _dio.get(
        'API_GetGameRankAndScore.php',
        queryParameters: {
          ..._authParams(),
          'g': gameId,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get user's game progress for comparison
  Future<Map<String, dynamic>?> getUserGameProgress(String username, int gameId) async {
    try {
      final response = await _dio.get(
        'API_GetGameInfoAndUserProgress.php',
        queryParameters: {
          ..._authParams(),
          'u': username,
          'g': gameId,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get claims (games being worked on by devs)
  Future<Map<String, dynamic>?> getActiveClaims() async {
    try {
      final response = await _dio.get(
        'API_GetActiveClaims.php',
        queryParameters: _authParams(),
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get achievements earned on a specific day
  Future<List<dynamic>?> getAchievementsEarnedOnDay(String username, DateTime date) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await _dio.get(
        'API_GetAchievementsEarnedOnDay.php',
        queryParameters: {
          ..._authParams(),
          'u': username,
          'd': dateStr,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get achievements earned between two dates
  Future<List<dynamic>?> getAchievementsEarnedBetween(String username, DateTime from, DateTime to) async {
    try {
      // API expects Unix timestamps (seconds since epoch)
      final fromTimestamp = from.millisecondsSinceEpoch ~/ 1000;
      final toTimestamp = to.millisecondsSinceEpoch ~/ 1000;
      final response = await _dio.get(
        'API_GetAchievementsEarnedBetween.php',
        queryParameters: {
          ..._authParams(),
          'u': username,
          'f': fromTimestamp,
          't': toTimestamp,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data as List<dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
