package com.retrotracker.retrotracker

import android.app.ActivityOptions
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Activity that can be launched on a secondary display (e.g., Ayn Thor bottom screen).
 * Runs the full RetroTrack app, allowing the user to use the app entirely on the secondary display.
 *
 * This is different from FlutterSecondaryPresentation which shows a companion view.
 * This activity runs the full app, just on a different display.
 */
class SecondaryDisplayActivity : FlutterActivity() {
    companion object {
        private const val TAG = "SecondaryDisplayActivity"
        private const val DISPLAY_CHANNEL = "com.retrotracker.retrotracker/display_info"
        private const val DUAL_SCREEN_CHANNEL = "com.retrotracker.retrotracker/dual_screen"
        private const val CLOSE_ACTION = "com.retrotracker.retrotracker.CLOSE_SECONDARY_ACTIVITY"
    }

    private var displayChannel: MethodChannel? = null
    private var dualScreenChannel: MethodChannel? = null
    private val displayManager: DisplayManager by lazy {
        getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
    }

    private val closeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            android.util.Log.d(TAG, "Received close broadcast, finishing activity")
            finish()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Set up display info channel
        displayChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISPLAY_CHANNEL)
        displayChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDisplayInfo" -> {
                    result.success(getCurrentDisplayInfo())
                }
                "isSecondaryDisplay" -> {
                    // This activity is always on a secondary display
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Set up dual screen channel - same methods as DualScreenManager but from secondary's perspective
        dualScreenChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DUAL_SCREEN_CHANNEL)
        dualScreenChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDisplays" -> {
                    result.success(getAvailableDisplays())
                }
                "hasSecondaryDisplay" -> {
                    // From secondary's perspective, "secondary" is the primary display
                    result.success(displayManager.displays.size > 1)
                }
                "getCurrentDisplayId" -> {
                    result.success(getCurrentDisplayId())
                }
                "getDefaultDisplayId" -> {
                    result.success(Display.DEFAULT_DISPLAY)
                }
                "isRunningOnSecondary" -> {
                    result.success(true)
                }
                "launchOnDisplay" -> {
                    val displayId = call.argument<Int>("displayId") ?: Display.DEFAULT_DISPLAY
                    val launchFull = call.argument<Boolean>("launchFullApp") ?: true
                    result.success(launchOnPrimaryDisplay(displayId, launchFull))
                }
                "launchOnPrimary" -> {
                    result.success(launchOnPrimaryDisplay(Display.DEFAULT_DISPLAY, true))
                }
                "finishMainActivity" -> {
                    // When running on secondary, this finishes THIS activity
                    android.util.Log.d(TAG, "finishMainActivity called - finishing secondary activity")
                    finishAndRemoveTask()
                    result.success(true)
                }
                "dismissSecondary", "dismissAll", "closeSecondaryActivity" -> {
                    // These don't apply when we ARE the secondary - just finish ourselves
                    android.util.Log.d(TAG, "${call.method} called on secondary - finishing")
                    finishAndRemoveTask()
                    result.success(true)
                }
                "showOnSecondary", "sendToSecondary", "isSecondaryActive" -> {
                    // These don't make sense when running on secondary
                    result.success(false)
                }
                else -> result.notImplemented()
            }
        }

        // Send display info to Flutter after engine is ready
        flutterEngine.dartExecutor.binaryMessenger.let {
            displayChannel?.invokeMethod("onDisplayInfo", getCurrentDisplayInfo())
        }
    }

    private fun getCurrentDisplayInfo(): Map<String, Any> {
        val display = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }

        return mapOf(
            "displayId" to (display?.displayId ?: 0),
            "name" to (display?.name ?: "Secondary Display"),
            "width" to (display?.mode?.physicalWidth ?: 0),
            "height" to (display?.mode?.physicalHeight ?: 0),
            "rotation" to (display?.rotation ?: 0),
            "refreshRate" to (display?.refreshRate ?: 60f),
            "isSecondary" to true
        )
    }

    private fun getAvailableDisplays(): List<Map<String, Any>> {
        return displayManager.displays.map { display ->
            mapOf(
                "displayId" to display.displayId,
                "name" to (display.name ?: "Display ${display.displayId}"),
                "width" to display.mode.physicalWidth,
                "height" to display.mode.physicalHeight,
                "isDefault" to (display.displayId == Display.DEFAULT_DISPLAY),
                "state" to display.state,
                "rotation" to display.rotation
            )
        }
    }

    private fun getCurrentDisplayId(): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display?.displayId ?: Display.DEFAULT_DISPLAY
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay?.displayId ?: Display.DEFAULT_DISPLAY
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to get current display ID", e)
            Display.DEFAULT_DISPLAY
        }
    }

    /**
     * Launch the main app on the primary display (or specified display)
     */
    private fun launchOnPrimaryDisplay(displayId: Int, launchFullApp: Boolean): Boolean {
        return try {
            val targetDisplayId = if (displayId == -1) Display.DEFAULT_DISPLAY else displayId

            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
            }

            // Create ActivityOptions with the target display
            val options = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ActivityOptions.makeBasic().apply {
                    launchDisplayId = targetDisplayId
                }
            } else {
                ActivityOptions.makeBasic()
            }

            android.util.Log.d(TAG, "Launching MainActivity on display $targetDisplayId")
            startActivity(intent, options.toBundle())
            true
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to launch on primary display", e)
            false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Register receiver to listen for close broadcasts
        val filter = IntentFilter(CLOSE_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(closeReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(closeReceiver, filter)
        }

        // Log which display we're on
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        }
        android.util.Log.d("SecondaryDisplayActivity", "Started on display: ${display?.displayId} (${display?.name})")
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(closeReceiver)
        } catch (e: Exception) {
            // Receiver might not be registered
        }
        super.onDestroy()
    }
}
