package com.retrotracker.retrotracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.URL

class RecentAchievementsWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_REFRESH -> {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = android.content.ComponentName(context, RecentAchievementsWidget::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
            ACTION_NEXT -> {
                val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
                if (appWidgetId != -1) {
                    cycleToNext(context, appWidgetId)
                }
            }
            ACTION_PREV -> {
                val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
                if (appWidgetId != -1) {
                    cycleToPrev(context, appWidgetId)
                }
            }
        }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val WIDGET_PREFS = "RecentAchievementsWidgetPrefs"
        const val ACTION_REFRESH = "com.retrotracker.retrotracker.REFRESH_RECENT_ACHIEVEMENTS"
        const val ACTION_NEXT = "com.retrotracker.retrotracker.RECENT_ACH_NEXT"
        const val ACTION_PREV = "com.retrotracker.retrotracker.RECENT_ACH_PREV"

        private fun getCurrentIndex(context: Context, appWidgetId: Int): Int {
            val prefs = context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
            return prefs.getInt("current_index_$appWidgetId", 0)
        }

        private fun setCurrentIndex(context: Context, appWidgetId: Int, index: Int) {
            val prefs = context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
            prefs.edit().putInt("current_index_$appWidgetId", index).apply()
        }

        private fun cycleToNext(context: Context, appWidgetId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val achievementsJson = prefs.getString("flutter.widget_recent_achievements", "[]") ?: "[]"
            val achievements = JSONArray(achievementsJson)
            val count = achievements.length().coerceAtMost(5)
            if (count == 0) return

            val currentIndex = getCurrentIndex(context, appWidgetId)
            val newIndex = (currentIndex + 1) % count
            setCurrentIndex(context, appWidgetId, newIndex)

            val appWidgetManager = AppWidgetManager.getInstance(context)
            updateWidget(context, appWidgetManager, appWidgetId)
        }

        private fun cycleToPrev(context: Context, appWidgetId: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val achievementsJson = prefs.getString("flutter.widget_recent_achievements", "[]") ?: "[]"
            val achievements = JSONArray(achievementsJson)
            val count = achievements.length().coerceAtMost(5)
            if (count == 0) return

            val currentIndex = getCurrentIndex(context, appWidgetId)
            val newIndex = if (currentIndex <= 0) count - 1 else currentIndex - 1
            setCurrentIndex(context, appWidgetId, newIndex)

            val appWidgetManager = AppWidgetManager.getInstance(context)
            updateWidget(context, appWidgetManager, appWidgetId)
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_recent_achievements)

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val achievementsJson = prefs.getString("flutter.widget_recent_achievements", "[]") ?: "[]"

            try {
                val achievements = JSONArray(achievementsJson)
                val count = achievements.length().coerceAtMost(5)

                if (count == 0) {
                    views.setTextViewText(R.id.achievement_title, "No recent achievements")
                    views.setTextViewText(R.id.game_title, "Play some games!")
                    views.setTextViewText(R.id.console_chip, "")
                    views.setTextViewText(R.id.points_chip, "")
                    views.setTextViewText(R.id.timestamp, "")
                    views.setViewVisibility(R.id.hardcore_badge, View.GONE)
                    views.setViewVisibility(R.id.dots_container, View.GONE)
                } else {
                    val currentIndex = getCurrentIndex(context, appWidgetId).coerceIn(0, count - 1)
                    val achievement = achievements.getJSONObject(currentIndex)

                    val title = achievement.optString("title", "Achievement")
                    val gameTitle = achievement.optString("gameTitle", "Unknown Game")
                    val consoleName = achievement.optString("consoleName", "")
                    val points = achievement.optInt("points", 0)
                    val isHardcore = achievement.optBoolean("hardcore", false)
                    val timestamp = achievement.optString("timestamp", "")
                    val achievementIcon = achievement.optString("achievementIcon", "")
                    val gameIcon = achievement.optString("gameIcon", "")

                    views.setTextViewText(R.id.achievement_title, title)
                    views.setTextViewText(R.id.game_title, gameTitle)
                    views.setTextViewText(R.id.console_chip, consoleName)
                    views.setTextViewText(R.id.points_chip, "$points pts")
                    views.setTextViewText(R.id.timestamp, timestamp)

                    views.setViewVisibility(R.id.hardcore_badge, if (isHardcore) View.VISIBLE else View.GONE)
                    views.setViewVisibility(R.id.dots_container, if (count > 1) View.VISIBLE else View.GONE)

                    // Update dots
                    val dotIds = listOf(R.id.dot1, R.id.dot2, R.id.dot3, R.id.dot4, R.id.dot5)
                    for (i in 0 until 5) {
                        if (i < count) {
                            views.setViewVisibility(dotIds[i], View.VISIBLE)
                            views.setInt(dotIds[i], "setBackgroundResource",
                                if (i == currentIndex) R.drawable.dot_active else R.drawable.dot_inactive)
                        } else {
                            views.setViewVisibility(dotIds[i], View.GONE)
                        }
                    }

                    // Load achievement icon
                    if (achievementIcon.isNotEmpty()) {
                        loadImageAsync(achievementIcon, views, R.id.achievement_icon, context, appWidgetManager, appWidgetId)
                    }

                    // Load game icon
                    if (gameIcon.isNotEmpty()) {
                        loadImageAsync(gameIcon, views, R.id.game_icon, context, appWidgetManager, appWidgetId)
                    }
                }
            } catch (e: Exception) {
                views.setTextViewText(R.id.achievement_title, "Error loading")
                views.setTextViewText(R.id.game_title, "Tap to refresh")
            }

            // Set click to cycle
            val nextIntent = Intent(context, RecentAchievementsWidget::class.java).apply {
                action = ACTION_NEXT
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val nextPendingIntent = PendingIntent.getBroadcast(
                context, appWidgetId, nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, nextPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun loadImageAsync(
            imageUrl: String,
            views: RemoteViews,
            viewId: Int,
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val fullUrl = if (imageUrl.startsWith("http")) imageUrl
                        else "https://retroachievements.org$imageUrl"
                    val url = URL(fullUrl)
                    val connection = url.openConnection()
                    connection.connectTimeout = 5000
                    connection.readTimeout = 5000
                    val bitmap = BitmapFactory.decodeStream(connection.getInputStream())
                    if (bitmap != null) {
                        withContext(Dispatchers.Main) {
                            views.setImageViewBitmap(viewId, bitmap)
                            appWidgetManager.updateAppWidget(appWidgetId, views)
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }

        fun refreshAllWidgets(context: Context) {
            val intent = Intent(context, RecentAchievementsWidget::class.java).apply {
                action = ACTION_REFRESH
            }
            context.sendBroadcast(intent)
        }
    }
}
