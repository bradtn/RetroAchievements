package com.retrotracker.retrotracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL

class AotwWidget : AppWidgetProvider() {

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
        if (intent.action == ACTION_REFRESH) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, AotwWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        const val ACTION_REFRESH = "com.retrotracker.retrotracker.REFRESH_AOTW"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_aotw)

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val achievementTitle = prefs.getString("flutter.widget_aotw_title", "No AOTW Available") ?: "No AOTW Available"
            val gameTitle = prefs.getString("flutter.widget_aotw_game", "") ?: ""
            val consoleName = prefs.getString("flutter.widget_aotw_console", "") ?: ""
            val points = prefs.getLong("flutter.widget_aotw_points", 0L).toInt()
            val achievementIcon = prefs.getString("flutter.widget_aotw_achievement_icon", "") ?: ""
            val gameIcon = prefs.getString("flutter.widget_aotw_game_icon", "") ?: ""
            val gameId = prefs.getLong("flutter.widget_aotw_game_id", 0L).toInt()

            views.setTextViewText(R.id.achievement_title, achievementTitle)
            views.setTextViewText(R.id.game_title, gameTitle)
            views.setTextViewText(R.id.console_chip, consoleName)
            views.setTextViewText(R.id.points_chip, if (points > 0) "$points pts" else "")

            // Load achievement icon
            if (achievementIcon.isNotEmpty()) {
                loadImageAsync(achievementIcon, views, R.id.achievement_icon, context, appWidgetManager, appWidgetId)
            }

            // Load game icon
            if (gameIcon.isNotEmpty()) {
                loadImageAsync(gameIcon, views, R.id.game_icon, context, appWidgetManager, appWidgetId)
            }

            // Click to open game
            val intent = Intent(context, MainActivity::class.java).apply {
                if (gameId > 0) {
                    putExtra("game_id", gameId)
                }
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 2000,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

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
            val intent = Intent(context, AotwWidget::class.java).apply {
                action = ACTION_REFRESH
            }
            context.sendBroadcast(intent)
        }
    }
}
