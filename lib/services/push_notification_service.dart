import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart' as fcm;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(fcm.RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushNotificationService._handleMessage(message);
}

/// Service for handling Firebase Cloud Messaging push notifications
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final fcm.FirebaseMessaging _messaging = fcm.FirebaseMessaging.instance;
  bool _initialized = false;

  /// Initialize push notifications
  Future<void> initialize() async {
    if (_initialized) return;

    // Set up background message handler
    fcm.FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS)
    await _requestPermission();

    // Get FCM token and save it
    await _getAndSaveToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_saveToken);

    // Handle foreground messages
    fcm.FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background/terminated
    fcm.FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _initialized = true;
  }

  /// Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == fcm.AuthorizationStatus.authorized) {
      // Permissions granted
    } else if (settings.authorizationStatus == fcm.AuthorizationStatus.provisional) {
      // Provisional permissions granted (iOS)
    }
  }

  /// Get FCM token and save it
  Future<String?> _getAndSaveToken() async {
    String? token;

    if (Platform.isIOS) {
      // Get APNs token first (required for iOS)
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null) {
        token = await _messaging.getToken();
      }
    } else {
      token = await _messaging.getToken();
    }

    if (token != null) {
      await _saveToken(token);
    }

    return token;
  }

  /// Save FCM token to shared preferences (for server to retrieve)
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// Get the saved FCM token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fcm_token');
  }

  /// Handle foreground messages - show local notification
  Future<void> _handleForegroundMessage(fcm.RemoteMessage message) async {
    await _handleMessage(message);
  }

  /// Handle message and show notification
  static Future<void> _handleMessage(fcm.RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      // Show local notification
      final notificationService = NotificationService();
      await notificationService.initialize();

      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      const androidDetails = AndroidNotificationDetails(
        'push_notifications',
        'Push Notifications',
        channelDescription: 'Notifications from RetroTrack server',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await flutterLocalNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: details,
        payload: data['type'],
      );
    }
  }

  /// Handle notification tap
  void _handleNotificationTap(fcm.RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    // Navigate based on notification type
    if (type == 'aotw') {
      // Navigate to AOTW screen
      NotificationService.navigatorKey?.currentState?.pushNamed('/aotw');
    } else if (type == 'aotm') {
      // Navigate to AOTM screen
      NotificationService.navigatorKey?.currentState?.pushNamed('/aotm');
    }
  }

  /// Subscribe to a topic (e.g., 'aotw_updates', 'aotm_updates')
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
