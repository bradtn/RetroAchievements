import 'package:flutter/services.dart';

/// Service to handle communication with the Android home screen widget
class WidgetService {
  static const _channel = MethodChannel('com.retrotracker.retrotracker/widget');
  static Function(int gameId)? _onGameSelected;

  /// Initialize the widget service and set up listeners
  static void init({Function(int gameId)? onGameSelected}) {
    _onGameSelected = onGameSelected;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetGameSelected') {
        final gameId = call.arguments as int?;
        if (gameId != null && gameId > 0 && _onGameSelected != null) {
          _onGameSelected!(gameId);
        }
      }
    });

    // Check for any initial game ID (app opened from widget)
    _checkInitialGameId();
  }

  static Future<void> _checkInitialGameId() async {
    try {
      final gameId = await _channel.invokeMethod<int>('getInitialGameId');
      if (gameId != null && gameId > 0 && _onGameSelected != null) {
        _onGameSelected!(gameId);
      }
    } catch (e) {
      // Ignore - might not be on Android
    }
  }

  /// Update the home screen widget
  static Future<void> updateWidget() async {
    try {
      await _channel.invokeMethod('updateWidget');
    } catch (e) {
      // Widget update failed, ignore
    }
  }
}
