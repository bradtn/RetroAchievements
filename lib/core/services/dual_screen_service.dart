import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for managing dual-screen functionality on devices like Ayn Odin
/// Uses singleton pattern to ensure only one method channel handler exists
class DualScreenService {
  static const _channel = MethodChannel('com.retrotracker.retrotracker/dual_screen');

  // Singleton instance
  static final DualScreenService _instance = DualScreenService._internal();
  factory DualScreenService() => _instance;

  bool _isSecondaryScreen = false;
  bool get isSecondaryScreen => _isSecondaryScreen;

  // Companion mode state - when active, nav bar moves to secondary display
  bool _isCompanionModeActive = false;
  bool get isCompanionModeActive => _isCompanionModeActive;

  final List<void Function(List<DisplayInfo>)> _displayChangeListeners = [];
  final List<void Function(Map<String, dynamic>)> _dataFromSecondaryListeners = [];
  final List<void Function(Map<String, dynamic>)> _dataFromMainListeners = [];
  final List<void Function(String, Map<String, dynamic>)> _secondaryEventListeners = [];
  final List<void Function(bool)> _companionModeListeners = [];

  DualScreenService._internal() {
    debugPrint('DualScreenService: Singleton created, setting up method channel handler');
    _channel.setMethodCallHandler(_handleMethodCall);
    debugPrint('DualScreenService: Method channel handler registered on channel: com.retrotracker.retrotracker/dual_screen');
    _checkIfSecondaryScreen();
  }

  Future<void> _checkIfSecondaryScreen() async {
    try {
      // Try the new method first, fall back to old method
      _isSecondaryScreen = await _channel.invokeMethod<bool>('isRunningOnSecondary') ?? false;
      if (!_isSecondaryScreen) {
        _isSecondaryScreen = await _channel.invokeMethod<bool>('isSecondaryScreen') ?? false;
      }
      debugPrint('DualScreenService: Running on secondary display: $_isSecondaryScreen');
    } catch (e) {
      _isSecondaryScreen = false;
    }
  }

  /// Check if the app is running on the secondary display
  Future<bool> isRunningOnSecondary() async {
    try {
      return await _channel.invokeMethod<bool>('isRunningOnSecondary') ?? false;
    } catch (e) {
      return _isSecondaryScreen;
    }
  }

  /// Launch the app on the primary display (when running on secondary)
  Future<bool> launchOnPrimary() async {
    try {
      return await _channel.invokeMethod<bool>('launchOnPrimary') ?? false;
    } catch (e) {
      debugPrint('DualScreenService: Error launching on primary: $e');
      return false;
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('DualScreenService: _handleMethodCall received method=${call.method}');
    switch (call.method) {
      case 'onDisplaysChanged':
        final displays = _parseDisplayList(call.arguments);
        for (final listener in _displayChangeListeners) {
          listener(displays);
        }
        return true;
      case 'onSecondaryEvent':
        // Events from secondary display (filter changes, achievement taps, etc.)
        final args = Map<String, dynamic>.from(call.arguments ?? {});
        final event = args['event'] as String? ?? '';
        final data = Map<String, dynamic>.from(args['data'] ?? {});
        debugPrint('DualScreenService: Received onSecondaryEvent - event=$event, listeners=${_secondaryEventListeners.length}');
        for (final listener in _secondaryEventListeners) {
          debugPrint('DualScreenService: Calling listener for event=$event');
          listener(event, data);
        }
        debugPrint('DualScreenService: Finished processing onSecondaryEvent');
        return true;
      case 'onDataFromSecondary':
        final data = Map<String, dynamic>.from(call.arguments ?? {});
        for (final listener in _dataFromSecondaryListeners) {
          listener(data);
        }
        return true;
      case 'onDataFromMain':
        final data = Map<String, dynamic>.from(call.arguments ?? {});
        for (final listener in _dataFromMainListeners) {
          listener(data);
        }
        return true;
      case 'navigateTo':
        final route = call.arguments['route'] as String?;
        if (route != null) {
          // Handle navigation on secondary screen
          // This would be handled by the app's navigation system
        }
        return true;
      case 'onSecondaryDisplayActive':
        // Notification that secondary display is now active/inactive
        debugPrint('DualScreenService: Secondary display active=${call.arguments}');
        return true;
      default:
        debugPrint('DualScreenService: Unhandled method call: ${call.method}');
        return null;
    }
  }

  /// Check if a secondary display is available
  Future<bool> hasSecondaryDisplay() async {
    try {
      return await _channel.invokeMethod<bool>('hasSecondaryDisplay') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get list of all available displays
  Future<List<DisplayInfo>> getDisplays() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getDisplays');
      return _parseDisplayList(result);
    } catch (e) {
      return [];
    }
  }

  /// Show content on the secondary display
  Future<bool> showOnSecondary({String route = '/secondary'}) async {
    try {
      return await _channel.invokeMethod<bool>('showOnSecondary', {'route': route}) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Dismiss the secondary presentation (companion view only)
  Future<bool> dismissSecondary() async {
    try {
      return await _channel.invokeMethod<bool>('dismissSecondary') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Close the SecondaryDisplayActivity (full app on secondary)
  Future<bool> closeSecondaryActivity() async {
    try {
      return await _channel.invokeMethod<bool>('closeSecondaryActivity') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Dismiss everything - both presentation AND activity
  Future<bool> dismissAll() async {
    try {
      return await _channel.invokeMethod<bool>('dismissAll') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Finish the main activity (for bottom-only mode)
  Future<bool> finishMainActivity() async {
    try {
      return await _channel.invokeMethod<bool>('finishMainActivity') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get info about the secondary display
  Future<DisplayInfo?> getSecondaryDisplayInfo() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSecondaryDisplayInfo');
      if (result != null) {
        return DisplayInfo.fromMap(Map<String, dynamic>.from(result));
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Send data to the secondary screen
  Future<bool> sendToSecondary(Map<String, dynamic> data) async {
    try {
      return await _channel.invokeMethod<bool>('sendToSecondary', {'data': data}) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Send data to the main screen (called from secondary)
  Future<bool> sendToMain(Map<String, dynamic> data) async {
    try {
      return await _channel.invokeMethod<bool>('sendToMain', {'data': data}) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Launch the app on a specific display
  /// [displayId] - The display ID to launch on (-1 for auto-select secondary)
  /// [launchFullApp] - If true, launches the full app. If false, shows companion view.
  Future<bool> launchOnDisplay(int displayId, {bool launchFullApp = true}) async {
    try {
      return await _channel.invokeMethod<bool>('launchOnDisplay', {
        'displayId': displayId,
        'launchFullApp': launchFullApp,
      }) ?? false;
    } catch (e) {
      debugPrint('DualScreenService: Error launching on display: $e');
      return false;
    }
  }

  /// Get the default display ID
  Future<int> getDefaultDisplayId() async {
    try {
      return await _channel.invokeMethod<int>('getDefaultDisplayId') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Check if multi-display is available
  Future<bool> isMultiDisplayAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isMultiDisplayAvailable') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get the current display ID the app is running on
  Future<int> getCurrentDisplayId() async {
    try {
      return await _channel.invokeMethod<int>('getCurrentDisplayId') ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Launch the full app on the secondary display
  Future<bool> launchFullAppOnSecondary() async {
    return launchOnDisplay(-1, launchFullApp: true);
  }

  /// Launch companion view on the secondary display
  Future<bool> launchCompanionOnSecondary() async {
    return launchOnDisplay(-1, launchFullApp: false);
  }

  /// Add listener for display changes
  void addDisplayChangeListener(void Function(List<DisplayInfo>) listener) {
    _displayChangeListeners.add(listener);
  }

  /// Remove display change listener
  void removeDisplayChangeListener(void Function(List<DisplayInfo>) listener) {
    _displayChangeListeners.remove(listener);
  }

  /// Add listener for data from secondary screen
  void addDataFromSecondaryListener(void Function(Map<String, dynamic>) listener) {
    _dataFromSecondaryListeners.add(listener);
  }

  /// Add listener for data from main screen (used on secondary)
  void addDataFromMainListener(void Function(Map<String, dynamic>) listener) {
    _dataFromMainListeners.add(listener);
  }

  /// Add listener for events from secondary display (filter changes, taps, etc.)
  void addSecondaryEventListener(void Function(String event, Map<String, dynamic> data) listener) {
    _secondaryEventListeners.add(listener);
  }

  /// Remove secondary event listener
  void removeSecondaryEventListener(void Function(String event, Map<String, dynamic> data) listener) {
    _secondaryEventListeners.remove(listener);
  }

  /// Set companion mode active state
  void setCompanionModeActive(bool active) {
    if (_isCompanionModeActive != active) {
      _isCompanionModeActive = active;
      debugPrint('DualScreenService: Companion mode ${active ? "activated" : "deactivated"}');
      for (final listener in _companionModeListeners) {
        listener(active);
      }
      // Notify secondary display about companion mode change
      sendToSecondary({
        'type': 'companionModeChanged',
        'active': active,
      });
    }
  }

  /// Add listener for companion mode changes
  void addCompanionModeListener(void Function(bool) listener) {
    _companionModeListeners.add(listener);
  }

  /// Remove companion mode listener
  void removeCompanionModeListener(void Function(bool) listener) {
    _companionModeListeners.remove(listener);
  }

  /// Send navigation event to secondary (for bottom nav sync)
  Future<bool> sendNavigationEvent(int tabIndex) async {
    return sendToSecondary({
      'type': 'navigationChanged',
      'tabIndex': tabIndex,
    });
  }

  List<DisplayInfo> _parseDisplayList(dynamic data) {
    if (data == null) return [];
    final list = data as List<dynamic>;
    return list.map((e) => DisplayInfo.fromMap(Map<String, dynamic>.from(e))).toList();
  }
}

/// Information about a display
class DisplayInfo {
  final int displayId;
  final String name;
  final int width;
  final int height;
  final bool isDefault;
  final int state;
  final int rotation;
  final double? refreshRate;

  DisplayInfo({
    required this.displayId,
    required this.name,
    required this.width,
    required this.height,
    required this.isDefault,
    required this.state,
    required this.rotation,
    this.refreshRate,
  });

  factory DisplayInfo.fromMap(Map<String, dynamic> map) {
    return DisplayInfo(
      displayId: map['displayId'] as int? ?? 0,
      name: map['name'] as String? ?? 'Unknown',
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
      isDefault: map['isDefault'] as bool? ?? false,
      state: map['state'] as int? ?? 0,
      rotation: map['rotation'] as int? ?? 0,
      refreshRate: (map['refreshRate'] as num?)?.toDouble(),
    );
  }

  /// Aspect ratio (always as landscape - wider dimension / narrower)
  double get aspectRatio {
    if (width <= 0 || height <= 0) return 1.0;
    final wider = width > height ? width : height;
    final narrower = width > height ? height : width;
    return wider / narrower;
  }

  /// 16:9 or wider (1.77+)
  bool get isWidescreen => aspectRatio >= 1.7;

  /// Closer to 4:3 (1.33) or square
  bool get isSquarish => aspectRatio < 1.7;

  @override
  String toString() => 'DisplayInfo($name: ${width}x$height, id=$displayId)';
}

/// Provider for dual screen service
final dualScreenServiceProvider = Provider<DualScreenService>((ref) {
  return DualScreenService();
});

/// Provider for checking if secondary display is available
final hasSecondaryDisplayProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(dualScreenServiceProvider);
  return service.hasSecondaryDisplay();
});

/// Provider for list of displays
final displaysProvider = FutureProvider<List<DisplayInfo>>((ref) async {
  final service = ref.watch(dualScreenServiceProvider);
  return service.getDisplays();
});
