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
            try {
                updateWidget(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        try {
            if (intent.action == ACTION_REFRESH) {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val componentName = android.content.ComponentName(context, RecentAchievementsWidget::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        const val ACTION_REFRESH = "com.retrotracker.retrotracker.REFRESH_RECENT_ACHIEVEMENTS"

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
                        // Show most recent achievement
                        val achievement = achievements.getJSONObject(0)

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
