package com.retrotracker.retrotracker

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.retrotracker.retrotracker/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    updateWidget()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
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
        val intent = Intent(applicationContext, GameTrackerWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        }
        sendBroadcast(intent)
    }
}
