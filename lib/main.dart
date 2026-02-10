import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/animations.dart';
import 'services/notification_service.dart';
import 'services/background_sync_service.dart';
import 'services/ad_service.dart';
import 'services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  ]);

  // Non-blocking background checks
  final backgroundSyncService = BackgroundSyncService();
  backgroundSyncService.checkStreakOnAppOpen();
  backgroundSyncService.checkAotwOnAppOpen();
}
