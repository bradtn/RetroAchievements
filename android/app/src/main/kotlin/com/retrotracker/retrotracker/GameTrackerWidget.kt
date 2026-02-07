package com.retrotracker.retrotracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL
import android.content.SharedPreferences

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

    override fun onEnabled(context: Context) {
        // Widget first created
    }

    override fun onDisabled(context: Context) {
        // Last widget removed
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_game_tracker)

            // Get data from SharedPreferences (synced from Flutter)
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            val gameTitle = prefs.getString("flutter.widget_game_title", "No game selected") ?: "No game selected"
            val consoleName = prefs.getString("flutter.widget_console_name", "") ?: ""
            val earned = prefs.getInt("flutter.widget_earned", 0)
            val total = prefs.getInt("flutter.widget_total", 0)
            val gameId = prefs.getInt("flutter.widget_game_id", 0)
            val imageUrl = prefs.getString("flutter.widget_image_url", "") ?: ""

            // Set text
            views.setTextViewText(R.id.game_title, gameTitle)
            views.setTextViewText(R.id.console_name, consoleName)
            views.setTextViewText(R.id.progress_text, "$earned / $total achievements")

            // Set progress
            val progress = if (total > 0) (earned * 100 / total) else 0
            views.setProgressBar(R.id.progress_bar, 100, progress, false)

            // Load image async
            if (imageUrl.isNotEmpty()) {
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        val url = URL("https://retroachievements.org$imageUrl")
                        val bitmap = BitmapFactory.decodeStream(url.openConnection().getInputStream())
                        withContext(Dispatchers.Main) {
                            views.setImageViewBitmap(R.id.game_icon, bitmap)
                            appWidgetManager.updateAppWidget(appWidgetId, views)
                        }
                    } catch (e: Exception) {
                        // Keep default icon on error
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

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = android.content.ComponentName(context, GameTrackerWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            for (id in appWidgetIds) {
                updateWidget(context, appWidgetManager, id)
            }
        }
    }
}
