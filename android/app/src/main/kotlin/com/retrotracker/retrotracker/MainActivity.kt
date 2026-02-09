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
    private var pendingScreen: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    updateGameTrackerWidget()
                    result.success(true)
                }
                "updateAllWidgets" -> {
                    updateAllWidgets()
                    result.success(true)
                }
                "updateRecentAchievementsWidget" -> {
                    updateRecentAchievementsWidget()
                    result.success(true)
                }
                "updateStreakWidget" -> {
                    updateStreakWidget()
                    result.success(true)
                }
                "updateAotwWidget" -> {
                    updateAotwWidget()
                    result.success(true)
                }
                "updateFriendActivityWidget" -> {
                    updateFriendActivityWidget()
                    result.success(true)
                }
                "getInitialIntent" -> {
                    val intentData = mutableMapOf<String, Any?>()
                    pendingGameId?.let { intentData["game_id"] = it }
                    pendingScreen?.let { intentData["open_screen"] = it }
                    result.success(intentData)
                    pendingGameId = null
                    pendingScreen = null
                }
                "getInitialGameId" -> {
                    // Legacy support
                    result.success(pendingGameId)
                    pendingGameId = null
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Check if we have pending data from widget click
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val gameId = intent?.getIntExtra("game_id", 0) ?: 0
        val openScreen = intent?.getStringExtra("open_screen")

        if (gameId > 0) {
            pendingGameId = gameId
            methodChannel?.invokeMethod("onWidgetGameSelected", gameId)
        } else if (openScreen != null) {
            pendingScreen = openScreen
            methodChannel?.invokeMethod("onOpenScreen", openScreen)
        }
    }

    private fun updateAllWidgets() {
        updateGameTrackerWidget()
        updateRecentAchievementsWidget()
        updateStreakWidget()
        updateAotwWidget()
        updateFriendActivityWidget()
    }

    private fun updateGameTrackerWidget() {
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        val componentName = ComponentName(applicationContext, GameTrackerWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

        for (appWidgetId in appWidgetIds) {
            GameTrackerWidget.updateWidget(applicationContext, appWidgetManager, appWidgetId)
        }
    }

    private fun updateRecentAchievementsWidget() {
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        val componentName = ComponentName(applicationContext, RecentAchievementsWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

        for (appWidgetId in appWidgetIds) {
            RecentAchievementsWidget.updateWidget(applicationContext, appWidgetManager, appWidgetId)
        }
    }

    private fun updateStreakWidget() {
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        val componentName = ComponentName(applicationContext, StreakWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

        for (appWidgetId in appWidgetIds) {
            StreakWidget.updateWidget(applicationContext, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAotwWidget() {
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        val componentName = ComponentName(applicationContext, AotwWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

        for (appWidgetId in appWidgetIds) {
            AotwWidget.updateWidget(applicationContext, appWidgetManager, appWidgetId)
        }
    }

    private fun updateFriendActivityWidget() {
        val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
        val componentName = ComponentName(applicationContext, FriendActivityWidget::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

        for (appWidgetId in appWidgetIds) {
            FriendActivityWidget.updateWidget(applicationContext, appWidgetManager, appWidgetId)
        }
    }
}
