import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/background_sync_service.dart';
import 'services/ad_service.dart';
import 'services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob
  await AdService().initialize();

  // Initialize in-app purchases
  await PurchaseService().initialize();

  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Initialize background sync service and check streak status
  final backgroundSyncService = BackgroundSyncService();
  await backgroundSyncService.initialize();

  // Check streak status on app open (runs in background, doesn't block)
  backgroundSyncService.checkStreakOnAppOpen();

  // Check for new Achievement of the Week
  backgroundSyncService.checkAotwOnAppOpen();

  runApp(
    const ProviderScope(
      child: RetroTrackerApp(),
    ),
  );
}
