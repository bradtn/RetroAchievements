package com.retrotracker.retrotracker

import android.app.Presentation
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.Display
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.*
import androidx.core.widget.NestedScrollView

/**
 * Native presentation for secondary display showing achievements list.
 * Optimized for 4:3 aspect ratio displays on devices like Ayn Odin.
 */
class SecondaryDisplayPresentation(
    context: Context,
    display: Display
) : Presentation(context, display) {

    private lateinit var rootLayout: LinearLayout
    private lateinit var headerTitle: TextView
    private lateinit var headerSubtitle: TextView
    private lateinit var gameTitle: TextView
    private lateinit var progressText: TextView
    private lateinit var progressBar: ProgressBar
    private lateinit var achievementsList: LinearLayout
    private lateinit var scrollView: NestedScrollView
    private lateinit var emptyState: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        rootLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#121212"))
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        // Header bar
        val headerBar = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setBackgroundColor(Color.parseColor("#1e1e2e"))
            setPadding(24, 16, 24, 16)
            gravity = Gravity.CENTER_VERTICAL
        }

        headerTitle = TextView(context).apply {
            text = "Achievements"
            textSize = 18f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }

        headerSubtitle = TextView(context).apply {
            text = "0/0"
            textSize = 14f
            setTextColor(Color.parseColor("#4CAF50"))
            typeface = Typeface.DEFAULT_BOLD
        }

        headerBar.addView(headerTitle)
        headerBar.addView(headerSubtitle)
        rootLayout.addView(headerBar)

        // Game info bar
        val gameBar = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#252538"))
            setPadding(24, 12, 24, 12)
        }

        gameTitle = TextView(context).apply {
            text = "Select a game on main screen"
            textSize = 14f
            setTextColor(Color.parseColor("#cccccc"))
            maxLines = 1
        }

        val progressContainer = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 8, 0, 0)
        }

        progressBar = ProgressBar(context, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 0
            layoutParams = LinearLayout.LayoutParams(0, 8, 1f)
            progressDrawable.setColorFilter(
                Color.parseColor("#4CAF50"),
                android.graphics.PorterDuff.Mode.SRC_IN
            )
        }

        progressText = TextView(context).apply {
            text = "0%"
            textSize = 12f
            setTextColor(Color.parseColor("#4CAF50"))
            setPadding(12, 0, 0, 0)
        }

        progressContainer.addView(progressBar)
        progressContainer.addView(progressText)
        gameBar.addView(gameTitle)
        gameBar.addView(progressContainer)
        rootLayout.addView(gameBar)

        // Divider
        rootLayout.addView(View(context).apply {
            setBackgroundColor(Color.parseColor("#333344"))
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 1)
        })

        // Scrollable achievements list
        scrollView = NestedScrollView(context).apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        }

        achievementsList = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 8, 0, 8)
        }

        emptyState = TextView(context).apply {
            text = "Open a game to see achievements"
            textSize = 14f
            setTextColor(Color.parseColor("#666666"))
            gravity = Gravity.CENTER
            setPadding(24, 48, 24, 48)
        }

        achievementsList.addView(emptyState)
        scrollView.addView(achievementsList)
        rootLayout.addView(scrollView)

        setContentView(rootLayout)
    }

    /**
     * Update with full game data including achievements
     */
    fun updateGameData(data: Map<String, Any?>) {
        val title = data["gameTitle"] as? String ?: "Unknown Game"
        val console = data["consoleName"] as? String ?: ""
        val earned = (data["earnedCount"] as? Number)?.toInt() ?: 0
        val total = (data["achievementCount"] as? Number)?.toInt() ?: 0

        @Suppress("UNCHECKED_CAST")
        val achievements = data["achievements"] as? List<Map<String, Any?>> ?: emptyList()

        // Update header
        headerSubtitle.text = "$earned/$total"

        // Update game bar
        gameTitle.text = if (console.isNotEmpty()) "$title • $console" else title

        if (total > 0) {
            progressBar.max = total
            progressBar.progress = earned
            val percent = (earned * 100) / total
            progressText.text = "$percent%"
        } else {
            progressBar.max = 100
            progressBar.progress = 0
            progressText.text = "0%"
        }

        // Update achievements list
        achievementsList.removeAllViews()

        if (achievements.isEmpty()) {
            achievementsList.addView(emptyState.apply {
                text = if (total > 0) "Loading achievements..." else "No achievements data"
            })
        } else {
            // Sort: unearned first (to show what you still need), then earned
            val sorted = achievements.sortedBy { ach ->
                val isEarned = (ach["DateEarned"] as? String) != null ||
                              (ach["DateEarnedHardcore"] as? String) != null
                if (isEarned) 1 else 0
            }

            for (ach in sorted) {
                achievementsList.addView(createAchievementRow(ach))
            }
        }
    }

    private fun createAchievementRow(ach: Map<String, Any?>): View {
        val title = ach["Title"] as? String ?: "Unknown"
        val description = ach["Description"] as? String ?: ""
        val points = (ach["Points"] as? Number)?.toInt() ?: 0
        val isEarned = (ach["DateEarned"] as? String) != null ||
                      (ach["DateEarnedHardcore"] as? String) != null
        val isMissable = (ach["type"] as? String)?.contains("missable", ignoreCase = true) == true ||
                        (ach["Flags"] as? Number)?.toInt() == 4

        val row = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(16, 12, 16, 12)
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(if (isEarned) Color.parseColor("#1a2e1a") else Color.TRANSPARENT)
        }

        // Status indicator
        val statusIcon = TextView(context).apply {
            text = when {
                isEarned -> "✓"
                isMissable -> "⚠"
                else -> "○"
            }
            textSize = 16f
            setTextColor(when {
                isEarned -> Color.parseColor("#4CAF50")
                isMissable -> Color.parseColor("#FF9800")
                else -> Color.parseColor("#666666")
            })
            setPadding(0, 0, 12, 0)
        }

        // Achievement info
        val infoLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f)
        }

        val titleText = TextView(context).apply {
            text = title
            textSize = 13f
            setTextColor(if (isEarned) Color.parseColor("#888888") else Color.WHITE)
            maxLines = 1
            if (isEarned) {
                paintFlags = paintFlags or android.graphics.Paint.STRIKE_THRU_TEXT_FLAG
            }
        }

        val descText = TextView(context).apply {
            text = description
            textSize = 11f
            setTextColor(Color.parseColor("#888888"))
            maxLines = 2
        }

        infoLayout.addView(titleText)
        infoLayout.addView(descText)

        // Points
        val pointsText = TextView(context).apply {
            text = "$points"
            textSize = 12f
            setTextColor(Color.parseColor("#FFD700"))
            typeface = Typeface.DEFAULT_BOLD
            setPadding(12, 0, 0, 0)
        }

        row.addView(statusIcon)
        row.addView(infoLayout)
        row.addView(pointsText)

        // Add divider
        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
        }
        container.addView(row)
        container.addView(View(context).apply {
            setBackgroundColor(Color.parseColor("#2a2a3a"))
            layoutParams = LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 1)
        })

        return container
    }

    fun showWaiting() {
        headerSubtitle.text = "0/0"
        gameTitle.text = "Select a game on main screen"
        progressBar.progress = 0
        progressText.text = "0%"
        achievementsList.removeAllViews()
        achievementsList.addView(emptyState.apply {
            text = "Open a game to see achievements"
        })
    }

    fun getDisplayInfo(): Map<String, Any> {
        return mapOf(
            "displayId" to display.displayId,
            "name" to (display.name ?: "Secondary Display"),
            "width" to display.mode.physicalWidth,
            "height" to display.mode.physicalHeight,
            "rotation" to display.rotation,
            "refreshRate" to display.refreshRate
        )
    }
}
