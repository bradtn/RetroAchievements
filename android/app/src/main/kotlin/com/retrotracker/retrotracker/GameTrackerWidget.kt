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

class GameTrackerWidget : AppWidgetProvider() {

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
        // Handle custom refresh action
        if (intent.action == ACTION_REFRESH) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, GameTrackerWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    override fun onEnabled(context: Context) {
        // Widget first created
    }

    override fun onDisabled(context: Context) {
        // Last widget removed
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        const val ACTION_REFRESH = "com.retrotracker.retrotracker.REFRESH_WIDGET"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_game_tracker)

            // Get data from SharedPreferences (synced from Flutter)
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val gameTitle = prefs.getString("flutter.widget_game_title", "No game pinned") ?: "No game pinned"
            val consoleName = prefs.getString("flutter.widget_console_name", "Pin a game from Favorites") ?: ""
            // Flutter stores ints as Longs
            val earned = prefs.getLong("flutter.widget_earned", 0L).toInt()
            val total = prefs.getLong("flutter.widget_total", 0L).toInt()
            val gameId = prefs.getLong("flutter.widget_game_id", 0L).toInt()
            val imageUrl = prefs.getString("flutter.widget_image_url", "") ?: ""

            // Set text
            views.setTextViewText(R.id.game_title, gameTitle)
            views.setTextViewText(R.id.console_name, consoleName)

            if (total > 0) {
                views.setTextViewText(R.id.progress_text, "$earned / $total achievements")
            } else {
                views.setTextViewText(R.id.progress_text, "No game selected")
            }

            // Set progress
            val progress = if (total > 0) (earned * 100 / total) else 0
            views.setProgressBar(R.id.progress_bar, 100, progress, false)

            // Load image async
            if (imageUrl.isNotEmpty()) {
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        val url = URL("https://retroachievements.org$imageUrl")
                        val connection = url.openConnection()
                        connection.connectTimeout = 5000
                        connection.readTimeout = 5000
                        val bitmap = BitmapFactory.decodeStream(connection.getInputStream())
                        if (bitmap != null) {
                            withContext(Dispatchers.Main) {
                                views.setImageViewBitmap(R.id.game_icon, bitmap)
                                appWidgetManager.updateAppWidget(appWidgetId, views)
                            }
                        }
                    } catch (e: Exception) {
                        // Keep default icon on error
                        e.printStackTrace()
                    }
                }
            }

            // Set click intent to open app
            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("game_id", gameId)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun refreshAllWidgets(context: Context) {
            val intent = Intent(context, GameTrackerWidget::class.java).apply {
                action = ACTION_REFRESH
            }
            context.sendBroadcast(intent)
        }
    }
}
