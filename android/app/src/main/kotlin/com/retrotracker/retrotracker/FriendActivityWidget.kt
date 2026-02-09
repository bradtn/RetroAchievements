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

class FriendActivityWidget : AppWidgetProvider() {

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
                val componentName = android.content.ComponentName(context, FriendActivityWidget::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
            ACTION_NEXT -> {
                val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
                if (appWidgetId != -1) {
                    cycleToNext(context, appWidgetId)
                }
            }
        }
    }

    companion object {
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val WIDGET_PREFS = "FriendActivityWidgetPrefs"
        const val ACTION_REFRESH = "com.retrotracker.retrotracker.REFRESH_FRIEND_ACTIVITY"
        const val ACTION_NEXT = "com.retrotracker.retrotracker.FRIEND_ACTIVITY_NEXT"

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
            val activityJson = prefs.getString("flutter.widget_friend_activity", "[]") ?: "[]"
            val activity = JSONArray(activityJson)
            val count = activity.length().coerceAtMost(3)
            if (count == 0) return

            val currentIndex = getCurrentIndex(context, appWidgetId)
            val newIndex = (currentIndex + 1) % count
            setCurrentIndex(context, appWidgetId, newIndex)

            val appWidgetManager = AppWidgetManager.getInstance(context)
            updateWidget(context, appWidgetManager, appWidgetId)
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_friend_activity)

            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val activityJson = prefs.getString("flutter.widget_friend_activity", "[]") ?: "[]"

            try {
                val activity = JSONArray(activityJson)
                val count = activity.length().coerceAtMost(3)

                if (count == 0) {
                    views.setTextViewText(R.id.friend_name, "No friend activity")
                    views.setTextViewText(R.id.achievement_title, "Follow users to see their unlocks")
                    views.setTextViewText(R.id.game_title, "")
                    views.setTextViewText(R.id.timestamp, "")
                    views.setViewVisibility(R.id.dots_container, View.GONE)
                } else {
                    val currentIndex = getCurrentIndex(context, appWidgetId).coerceIn(0, count - 1)
                    val entry = activity.getJSONObject(currentIndex)

                    val friendName = entry.optString("username", "Unknown")
                    val achievementTitle = entry.optString("achievementTitle", "Achievement")
                    val gameTitle = entry.optString("gameTitle", "Unknown Game")
                    val timestamp = entry.optString("timestamp", "")
                    val friendAvatar = entry.optString("userAvatar", "")
                    val achievementIcon = entry.optString("achievementIcon", "")
                    val gameIcon = entry.optString("gameIcon", "")

                    views.setTextViewText(R.id.friend_name, friendName)
                    views.setTextViewText(R.id.achievement_title, achievementTitle)
                    views.setTextViewText(R.id.game_title, gameTitle)
                    views.setTextViewText(R.id.timestamp, timestamp)

                    views.setViewVisibility(R.id.dots_container, if (count > 1) View.VISIBLE else View.GONE)

                    // Update dots
                    val dotIds = listOf(R.id.dot1, R.id.dot2, R.id.dot3)
                    for (i in 0 until 3) {
                        if (i < count) {
                            views.setViewVisibility(dotIds[i], View.VISIBLE)
                            views.setInt(dotIds[i], "setBackgroundResource",
                                if (i == currentIndex) R.drawable.dot_active else R.drawable.dot_inactive)
                        } else {
                            views.setViewVisibility(dotIds[i], View.GONE)
                        }
                    }

                    // Load friend avatar
                    if (friendAvatar.isNotEmpty()) {
                        loadImageAsync(friendAvatar, views, R.id.friend_avatar, context, appWidgetManager, appWidgetId)
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
                views.setTextViewText(R.id.friend_name, "Error loading")
                views.setTextViewText(R.id.achievement_title, "Tap to refresh")
            }

            // Set click to cycle
            val nextIntent = Intent(context, FriendActivityWidget::class.java).apply {
                action = ACTION_NEXT
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val nextPendingIntent = PendingIntent.getBroadcast(
                context, appWidgetId + 3000, nextIntent,
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
            val intent = Intent(context, FriendActivityWidget::class.java).apply {
                action = ACTION_REFRESH
            }
            context.sendBroadcast(intent)
        }
    }
}
