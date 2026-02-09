import 'package:flutter/services.dart';

/// Service to handle communication with Android home screen widgets
class WidgetService {
  static const _channel = MethodChannel('com.retrotracker.retrotracker/widget');
  static Function(int gameId)? _onGameSelected;
  static Function(String screen)? _onOpenScreen;

  /// Initialize the widget service and set up listeners
  static void init({
    Function(int gameId)? onGameSelected,
    Function(String screen)? onOpenScreen,
  }) {
    _onGameSelected = onGameSelected;
    _onOpenScreen = onOpenScreen;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onWidgetGameSelected':
          final gameId = call.arguments as int?;
          if (gameId != null && gameId > 0 && _onGameSelected != null) {
            _onGameSelected!(gameId);
          }
          break;
        case 'onOpenScreen':
          final screen = call.arguments as String?;
          if (screen != null && _onOpenScreen != null) {
            _onOpenScreen!(screen);
          }
          break;
      }
    });

    // Check for any initial intent data
    _checkInitialIntent();
  }

  static Future<void> _checkInitialIntent() async {
    try {
      final result = await _channel.invokeMethod<Map>('getInitialIntent');
      if (result != null) {
        final gameId = result['game_id'] as int?;
        final screen = result['open_screen'] as String?;

        if (gameId != null && gameId > 0 && _onGameSelected != null) {
          _onGameSelected!(gameId);
        } else if (screen != null && _onOpenScreen != null) {
          _onOpenScreen!(screen);
        }
      }
    } catch (e) {
      // Ignore - might not be on Android or method not implemented
    }
  }

  /// Update the Game Tracker widget
  static Future<void> updateGameTrackerWidget() async {
    try {
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      // Widget update failed, ignore
    }
  }

  /// Update all widgets
  static Future<void> updateAllWidgets() async {
    try {
      await _channel.invokeMethod('updateAllWidgets');
    } catch (e) {
      // Fallback to individual updates
      await Future.wait([
        updateGameTrackerWidget(),
        updateRecentAchievementsWidget(),
        updateStreakWidget(),
        updateAotwWidget(),
        updateFriendActivityWidget(),
      ]);
    }
  }

  /// Update Recent Achievements widget
  static Future<void> updateRecentAchievementsWidget() async {
    try {
      await _channel.invokeMethod('updateRecentAchievementsWidget');
    } catch (e) {
      // Widget update failed, ignore
    }
  }

  /// Update Streak widget
  static Future<void> updateStreakWidget() async {
    try {
      await _channel.invokeMethod('updateStreakWidget');
    } catch (e) {
      // Widget update failed, ignore
    }
  }

  /// Update AOTW widget
  static Future<void> updateAotwWidget() async {
    try {
      await _channel.invokeMethod('updateAotwWidget');
    } catch (e) {
      // Widget update failed, ignore
    }
  }

  /// Update Friend Activity widget
  static Future<void> updateFriendActivityWidget() async {
    try {
      await _channel.invokeMethod('updateFriendActivityWidget');
    } catch (e) {
      // Widget update failed, ignore
    }
  }

  /// Legacy method for backwards compatibility
  static Future<void> updateWidget() => updateGameTrackerWidget();
}
