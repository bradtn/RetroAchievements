import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/animations.dart';
import 'services/notification_service.dart';
import 'services/background_sync_service.dart';
import 'services/ad_service.dart';
import 'services/purchase_service.dart';
import 'services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (required before runApp for push notifications)
  await Firebase.initializeApp();

  // Start the app immediately - don't block on service initialization
  runApp(
    const ProviderScope(
      child: RetroTrackerApp(),
    ),
  );

  // Initialize services in the background (non-blocking)
  _initializeServices();
}

/// Initialize all services in the background without blocking the UI
Future<void> _initializeServices() async {
  // Load user preferences (fast, can await)
  final prefs = await SharedPreferences.getInstance();
  Haptics.setEnabled(prefs.getBool('haptics_enabled') ?? true);

  // Initialize services in parallel for speed
  await Future.wait([
    AdService().initialize(),
    PurchaseService().initialize(),
    NotificationService().initialize(),
    BackgroundSyncService().initialize(),
    PushNotificationService().initialize(),
  ]);

  // Subscribe to push notification topics based on user preferences
  final pushService = PushNotificationService();
  if (prefs.getBool('aotw_notifications_enabled') ?? true) {
    pushService.subscribeToTopic('aotw_updates');
  }
  if (prefs.getBool('aotm_notifications_enabled') ?? true) {
    pushService.subscribeToTopic('aotm_updates');
  }

  // Non-blocking background checks and scheduled notifications
  final backgroundSyncService = BackgroundSyncService();
  backgroundSyncService.registerPeriodicTasks();
  backgroundSyncService.checkStreakOnAppOpen();
  backgroundSyncService.checkAotwOnAppOpen();
  backgroundSyncService.checkAotmOnAppOpen();
}
