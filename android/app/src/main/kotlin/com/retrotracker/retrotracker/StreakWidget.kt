package com.retrotracker.retrotracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class StreakWidget : AppWidgetProvider() {

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
            val componentName = android.content.ComponentName(context, StreakWidget::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            onUpdate(context, appWidgetManager, appWidgetIds)
        }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        const val ACTION_REFRESH = "com.retrotracker.retrotracker.REFRESH_STREAK"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_streak)

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

            // Flutter stores ints as Longs in SharedPreferences
            val currentStreak = prefs.getLong("flutter.widget_current_streak", 0L).toInt()
            val bestStreak = prefs.getLong("flutter.widget_best_streak", 0L).toInt()

            views.setTextViewText(R.id.streak_count, currentStreak.toString())
            views.setTextViewText(R.id.best_streak, "$bestStreak days")

            // Adjust fire emoji visibility based on streak
            if (currentStreak == 0) {
                views.setTextViewText(R.id.fire_left, "💤")
                views.setTextViewText(R.id.fire_right, "💤")
            } else if (currentStreak >= 30) {
                views.setTextViewText(R.id.fire_left, "🔥")
                views.setTextViewText(R.id.fire_right, "🔥")
            } else if (currentStreak >= 7) {
                views.setTextViewText(R.id.fire_left, "🔥")
                views.setTextViewText(R.id.fire_right, "")
            } else {
                views.setTextViewText(R.id.fire_left, "✨")
                views.setTextViewText(R.id.fire_right, "")
            }

            // Click to open app
            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra("open_screen", "calendar")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId + 1000,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun refreshAllWidgets(context: Context) {
            val intent = Intent(context, StreakWidget::class.java).apply {
                action = ACTION_REFRESH
            }
            context.sendBroadcast(intent)
        }
    }
}
