package com.retrotracker.retrotracker

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.retrotracker.retrotracker/widget"
    private var methodChannel: MethodChannel? = null
    private var pendingGameId: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    updateWidget()
                    result.success(true)
                }
                "getInitialGameId" -> {
                    result.success(pendingGameId)
                    pendingGameId = null
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Check if we have a pending game ID from widget click
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val gameId = intent?.getIntExtra("game_id", 0) ?: 0
        if (gameId > 0) {
            pendingGameId = gameId
            // If Flutter is already running, send the event
            methodChannel?.invokeMethod("onWidgetGameSelected", gameId)
        }
    }

    private fun updateWidget() {
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        val componentName = ComponentName(applicationContext, GameTrackerWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

        // Update all widgets
        for (appWidgetId in appWidgetIds) {
            GameTrackerWidget.updateWidget(applicationContext, appWidgetManager, appWidgetId)
        }

        // Also send broadcast for any widgets that might have been missed
        val broadcastIntent = Intent(applicationContext, GameTrackerWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        }
        sendBroadcast(broadcastIntent)
    }
}
