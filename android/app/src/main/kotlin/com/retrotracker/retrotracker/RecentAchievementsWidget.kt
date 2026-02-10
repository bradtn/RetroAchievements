package com.retrotracker.retrotracker

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.SystemClock
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
            try {
                updateWidget(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        // Schedule next cycle
        scheduleCycleUpdate(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        scheduleCycleUpdate(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancelCycleUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        try {
            when (intent.action) {
                ACTION_REFRESH, ACTION_CYCLE -> {
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val componentName = android.content.ComponentName(context, RecentAchievementsWidget::class.java)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

                    if (intent.action == ACTION_CYCLE) {
                        // Increment the cycle index
                        incrementCycleIndex(context)
                    }

                    onUpdate(context, appWidgetManager, appWidgetIds)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val WIDGET_PREFS = "RecentAchievementsWidgetPrefs"
        private const val KEY_CYCLE_INDEX = "cycle_index"
        private const val MAX_CYCLE_COUNT = 5
        private const val CYCLE_INTERVAL_MS = 30000L // 30 seconds
        const val ACTION_REFRESH = "com.retrotracker.retrotracker.REFRESH_RECENT_ACHIEVEMENTS"
        const val ACTION_CYCLE = "com.retrotracker.retrotracker.CYCLE_RECENT_ACHIEVEMENTS"

        private fun getCycleIndex(context: Context): Int {
            val prefs = context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
            return prefs.getInt(KEY_CYCLE_INDEX, 0)
        }

        private fun incrementCycleIndex(context: Context) {
            val prefs = context.getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)
            val currentIndex = prefs.getInt(KEY_CYCLE_INDEX, 0)
            val nextIndex = (currentIndex + 1) % MAX_CYCLE_COUNT
            prefs.edit().putInt(KEY_CYCLE_INDEX, nextIndex).apply()
        }

        private fun scheduleCycleUpdate(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, RecentAchievementsWidget::class.java).apply {
                action = ACTION_CYCLE
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + CYCLE_INTERVAL_MS,
                pendingIntent
            )
        }

        private fun cancelCycleUpdate(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, RecentAchievementsWidget::class.java).apply {
                action = ACTION_CYCLE
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_recent_achievements)

            try {
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val achievementsJson = prefs.getString("flutter.widget_recent_achievements", null)

                if (achievementsJson.isNullOrEmpty() || achievementsJson == "[]") {
                    views.setTextViewText(R.id.achievement_title, "Open app to sync")
                    views.setTextViewText(R.id.game_title, "Your achievements will appear here")
                    views.setTextViewText(R.id.console_chip, "")
                    views.setTextViewText(R.id.points_chip, "")
                    views.setTextViewText(R.id.timestamp, "")
                    views.setViewVisibility(R.id.hardcore_badge, View.GONE)
                } else {
                    val achievements = JSONArray(achievementsJson)
                    if (achievements.length() == 0) {
                        views.setTextViewText(R.id.achievement_title, "No recent achievements")
                        views.setTextViewText(R.id.game_title, "Play some games!")
                        views.setTextViewText(R.id.console_chip, "")
                        views.setTextViewText(R.id.points_chip, "")
                        views.setTextViewText(R.id.timestamp, "")
                        views.setViewVisibility(R.id.hardcore_badge, View.GONE)
                    } else {
                        // Get current cycle index and show that achievement
                        val cycleIndex = getCycleIndex(context)
                        val actualIndex = cycleIndex % minOf(achievements.length(), MAX_CYCLE_COUNT)
                        val achievement = achievements.getJSONObject(actualIndex)

                        views.setTextViewText(R.id.achievement_title, achievement.optString("title", "Achievement"))
                        views.setTextViewText(R.id.game_title, achievement.optString("gameTitle", "Unknown Game"))
                        views.setTextViewText(R.id.console_chip, achievement.optString("consoleName", ""))
                        views.setTextViewText(R.id.points_chip, "${achievement.optInt("points", 0)} pts")
                        views.setTextViewText(R.id.timestamp, achievement.optString("timestamp", ""))

                        val isHardcore = achievement.optBoolean("hardcore", false)
                        views.setViewVisibility(R.id.hardcore_badge, if (isHardcore) View.VISIBLE else View.GONE)

                        // Load achievement icon
                        val achievementIcon = achievement.optString("achievementIcon", "")
                        if (achievementIcon.isNotEmpty()) {
                            loadImageAsync(achievementIcon, views, R.id.achievement_icon, context, appWidgetManager, appWidgetId)
                        }

                        // Load game icon
                        val gameIcon = achievement.optString("gameIcon", "")
                        if (gameIcon.isNotEmpty()) {
                            loadImageAsync(gameIcon, views, R.id.game_icon, context, appWidgetManager, appWidgetId)
                        }
                    }
                }
            } catch (e: Exception) {
                views.setTextViewText(R.id.achievement_title, "Open app to sync")
                views.setTextViewText(R.id.game_title, "")
                views.setViewVisibility(R.id.hardcore_badge, View.GONE)
                e.printStackTrace()
            }

            // Set click to open app
            try {
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context, appWidgetId, openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
            } catch (e: Exception) {
                e.printStackTrace()
            }

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
