import 'dart:convert';
import 'package:dio/dio.dart';

class RAApiDataSource {
  final Dio _dio;
  String? _username;
  String? _apiKey;

  RAApiDataSource({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: 'https://retroachievements.org/API/',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Retry helper for transient failures
  Future<T?> _withRetry<T>(Future<T?> Function() request, {int maxRetries = 2}) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final result = await request();
        if (result != null) return result;
        // If null result and we have retries left, wait and try again
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        }
      } catch (e) {
        if (attempt == maxRetries) return null;
        await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
      }
    }
    return null;
  }

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

  /// Verify that the API key belongs to the specified username
  /// The RA API validates that z (username) matches the API key owner
  Future<bool> verifyApiKeyOwner(String username) async {
    try {
      // Call API_GetUsersIFollow - this endpoint requires valid z/y credentials
      // If the API key doesn't belong to the specified username, RA returns an error
      final response = await _dio.get(
        'API_GetUsersIFollow.php',
        queryParameters: {
          'z': username,
          'y': _apiKey,
        },
      );

      // Check for HTTP errors
      if (response.statusCode != 200) {
        return false;
      }

      final data = response.data;

      // Check for auth/validation errors in response
      if (data is Map<String, dynamic>) {
        // RA API returns errors like {"Success": false, "Error": "..."}
        // or {"error": "Invalid API Key"}
        final error = data['Error'] ?? data['error'];
        final success = data['Success'] ?? data['success'];

        if (error != null && error.toString().isNotEmpty) {
          return false;
        }
        if (success == false) {
          return false;
        }
      }

      // If we got a valid response (even empty results), credentials are valid
      return true;
    } catch (e) {
      // Network errors shouldn't block login - let the main flow handle it
      return true;
    }
  }

  Map<String, dynamic> _authParams() {
    return {
      'z': _username,
      'y': _apiKey,
    };
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String username) async {
    return _withRetry(() async {
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
    });
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
    return _withRetry(() async {
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
    });
  }

  /// Get game info with user progress
  Future<Map<String, dynamic>?> getGameInfoWithProgress(int gameId) async {
    return _withRetry(() async {
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
    });
  }

  /// Get user's recent achievements using UserSummary endpoint
  /// The RecentAchievements endpoint only returns last X minutes, so we use Summary instead
  Future<List<dynamic>?> getRecentAchievements(String username, {int count = 50}) async {
    return _withRetry(() async {
      try {
        final response = await _dio.get(
          'API_GetUserSummary.php',
          queryParameters: {
            ..._authParams(),
            'u': username,
            'g': 5, // number of recent games
            'a': count, // number of recent achievements
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data is Map<String, dynamic>) {
            final recentAch = data['RecentAchievements'];
            List<dynamic> achievements = [];

            if (recentAch is List) {
              achievements = recentAch;
            } else if (recentAch is Map) {
              achievements = recentAch.values.toList();
            }

            // Handle nested structure where first item contains all achievements
            if (achievements.isNotEmpty && achievements.first is Map) {
              final first = achievements.first as Map;
              if (first.values.isNotEmpty && first.values.first is Map) {
                // Flatten - achievements are nested inside
                achievements = first.values.map((v) => v as Map<String, dynamic>).toList();
              }
            }

            return achievements;
          }
        }
        return null;
      } catch (e) {
        return null;
      }
    });
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
    return _withRetry(() async {
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
    });
  }

  /// Get games for a console
  Future<List<dynamic>?> getGameList(int consoleId, {bool onlyWithAchievements = true}) async {
    return _withRetry(() async {
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
    });
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

  /// GitHub URL for Achievement of the Month data
  /// This is hosted separately since RA doesn't have an official AotM API
  static const String _aotmGitHubUrl =
      'https://raw.githubusercontent.com/bradtn/RetroAchievements/master/aotm.json';

  /// Get Achievement of the Month (fetched from GitHub)
  /// Always fetches fresh data with cache-busting to ensure latest content
  /// Returns tuple of (data, errorMessage) for debugging
  Future<(List<dynamic>?, String?)> getAchievementOfTheMonthWithError() async {
    try {
      final githubDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.plain,
      ));
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final response = await githubDio.get('$_aotmGitHubUrl?cb=$cacheBuster');
      if (response.statusCode == 200 && response.data != null) {
        final jsonString = response.data.toString();
        final decoded = jsonDecode(jsonString);
        if (decoded is List) {
          return (decoded, null);
        }
        return (null, 'Response is not a list: ${decoded.runtimeType}');
      }
      return (null, 'HTTP ${response.statusCode}');
    } catch (e) {
      return (null, e.toString());
    }
  }

  Future<List<dynamic>?> getAchievementOfTheMonth() async {
    final (data, _) = await getAchievementOfTheMonthWithError();
    return data;
  }

  /// Get the current active Achievement of the Month
  /// Returns tuple of (data, errorMessage) for debugging
  Future<(Map<String, dynamic>?, String?)> getCurrentAchievementOfTheMonthWithError() async {
    final (allAotm, fetchError) = await getAchievementOfTheMonthWithError();
    if (allAotm == null || allAotm.isEmpty) {
      return (null, fetchError ?? 'No AotM data available');
    }

    final now = DateTime.now().toUtc();
    for (final aotm in allAotm) {
      if (aotm is Map<String, dynamic>) {
        final startStr = aotm['achievementDateStart'] as String?;
        final endStr = aotm['achievementDateEnd'] as String?;
        if (startStr != null && endStr != null) {
          try {
            final start = DateTime.parse(startStr);
            final end = DateTime.parse(endStr);
            if (now.isAfter(start) && now.isBefore(end)) {
              return (aotm, null);
            }
          } catch (_) {}
        }
      }
    }
    // If no current one found, return the most recent (last in list)
    final last = allAotm.last;
    if (last is Map<String, dynamic>) {
      return (last, null);
    }
    return (null, 'Could not find valid AotM entry');
  }

  Future<Map<String, dynamic>?> getCurrentAchievementOfTheMonth() async {
    final allAotm = await getAchievementOfTheMonth();
    if (allAotm == null || allAotm.isEmpty) return null;

    final now = DateTime.now().toUtc();
    for (final aotm in allAotm) {
      if (aotm is Map<String, dynamic>) {
        final startStr = aotm['achievementDateStart'] as String?;
        final endStr = aotm['achievementDateEnd'] as String?;
        if (startStr != null && endStr != null) {
          try {
            final start = DateTime.parse(startStr);
            final end = DateTime.parse(endStr);
            if (now.isAfter(start) && now.isBefore(end)) {
              return aotm;
            }
          } catch (_) {}
        }
      }
    }
    // If no current one found, return the most recent (last in list)
    return allAotm.last as Map<String, dynamic>?;
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
    return _withRetry(() async {
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
    });
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

  /// Get users that the current user follows
  Future<List<dynamic>?> getUsersIFollow() async {
    try {
      final response = await _dio.get(
        'API_GetUsersIFollow.php',
        queryParameters: _authParams(),
      );
      if (response.statusCode == 200 && response.data != null) {
        // API returns { Count, Total, Results: [...] } (PascalCase)
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data['Results'] as List<dynamic>? ??
                 data['results'] as List<dynamic>? ?? [];
        } else if (data is List) {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get users following the current user
  Future<List<dynamic>?> getUsersFollowingMe() async {
    try {
      final response = await _dio.get(
        'API_GetUsersFollowingMe.php',
        queryParameters: _authParams(),
      );
      if (response.statusCode == 200 && response.data != null) {
        // API returns { Count, Total, Results: [...] } (PascalCase)
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data['Results'] as List<dynamic>? ??
                 data['results'] as List<dynamic>? ?? [];
        } else if (data is List) {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get recent game awards (live feed of community unlocks)
  Future<List<dynamic>?> getRecentGameAwards({int count = 50, int? offset}) async {
    try {
      final params = {
        ..._authParams(),
        'c': count,
      };
      if (offset != null) params['o'] = offset;

      final response = await _dio.get(
        'API_GetRecentGameAwards.php',
        queryParameters: params,
      );
      if (response.statusCode == 200 && response.data != null) {
        // API returns { Count, Total, Results: [...] } (PascalCase)
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data['Results'] as List<dynamic>? ??
                 data['results'] as List<dynamic>? ?? [];
        } else if (data is List) {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get game leaderboards
  Future<List<dynamic>?> getGameLeaderboards(int gameId) async {
    try {
      final response = await _dio.get(
        'API_GetGameLeaderboards.php',
        queryParameters: {
          ..._authParams(),
          'i': gameId,
          'c': 500, // Request up to 500 to get all leaderboards
        },
      );
      print('getGameLeaderboards raw response type: ${response.data.runtimeType}');
      print('getGameLeaderboards raw response: ${response.data}');
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        // Handle both List and Map responses
        if (data is List) {
          return data;
        } else if (data is Map) {
          final mapData = Map<String, dynamic>.from(data);
          // API might return { Count, Total, Results: [...] }
          final results = mapData['Results'] as List<dynamic>?;
          if (results != null) return results;
          // Or it might be a map of leaderboards by ID
          return mapData.values.toList();
        }
        return null;
      }
      return null;
    } catch (e) {
      print('getGameLeaderboards error: $e');
      return null;
    }
  }

  /// Get leaderboard entries
  Future<Map<String, dynamic>?> getLeaderboardEntries(int leaderboardId, {int count = 50, int? offset}) async {
    try {
      final params = {
        ..._authParams(),
        'i': leaderboardId,
        'c': count,
      };
      if (offset != null) params['o'] = offset;

      final response = await _dio.get(
        'API_GetLeaderboardEntries.php',
        queryParameters: params,
      );
      print('getLeaderboardEntries raw response: ${response.data}');
      if (response.statusCode == 200 && response.data != null) {
        if (response.data is Map) {
          return Map<String, dynamic>.from(response.data);
        }
        return null;
      }
      return null;
    } catch (e) {
      print('getLeaderboardEntries error: $e');
      return null;
    }
  }

  /// Get user's rank on a specific game
  Future<Map<String, dynamic>?> getUserGameRankAndScore(String username, int gameId) async {
    try {
      final response = await _dio.get(
        'API_GetUserGameRankAndScore.php',
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

  /// Get comments for a game or achievement
  Future<List<dynamic>?> getComments(int type, int id, {int count = 50}) async {
    try {
      // type: 1 = game, 2 = achievement, 3 = user
      final response = await _dio.get(
        'API_GetComments.php',
        queryParameters: {
          ..._authParams(),
          't': type,
          'i': id,
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

  /// Get user's "Want to Play" list (wishlist)
  Future<List<dynamic>?> getUserWantToPlayList(String username) async {
    return _withRetry(() async {
      try {
        final response = await _dio.get(
          'API_GetUserWantToPlayList.php',
          queryParameters: {
            ..._authParams(),
            'u': username,
          },
        );
        if (response.statusCode == 200 && response.data != null) {
          // API returns { Count, Total, Results: [...] }
          final data = response.data;
          if (data is Map<String, dynamic>) {
            return data['Results'] as List<dynamic>? ?? [];
          } else if (data is List) {
            return data;
          }
        }
        return null;
      } catch (e) {
        return null;
      }
    });
  }

  /// Get user's friend list from RetroAchievements
  Future<List<dynamic>?> getFriendList(String username) async {
    return _withRetry(() async {
      try {
        final response = await _dio.get(
          'API_GetFriendList.php',
          queryParameters: {
            ..._authParams(),
            'u': username,
          },
        );
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data is List) {
            return data;
          } else if (data is Map<String, dynamic>) {
            // Some endpoints return { Results: [...] }
            return data['Results'] as List<dynamic>? ?? data['Friends'] as List<dynamic>? ?? [];
          }
        }
        return null;
      } catch (e) {
        return null;
      }
    });
  }

  /// Get user's leaderboard entries for a specific game
  /// Returns the user's scores, ranks, and positions on all leaderboards for a game
  /// Response format:
  /// {
  ///   "Count": 1,
  ///   "Total": 1,
  ///   "Results": [
  ///     {
  ///       "LeaderboardId": 84859,
  ///       "Title": "Speed Run",
  ///       "Description": "Complete in fastest time",
  ///       "Rank": 1,
  ///       "Score": 8334,
  ///       "FormattedScore": "1:23.34",
  ///       "DateUpdated": "2025-06-02 04:32:38"
  ///     }
  ///   ]
  /// }
  Future<Map<String, dynamic>?> getUserGameLeaderboards(String username, int gameId) async {
    try {
      final response = await _dio.get(
        'API_GetUserGameLeaderboards.php',
        queryParameters: {
          ..._authParams(),
          'u': username,
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
}
