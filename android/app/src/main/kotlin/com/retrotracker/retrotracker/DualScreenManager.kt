package com.retrotracker.retrotracker

import android.app.ActivityOptions
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Display
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Manages dual-screen functionality for devices like Ayn Odin.
 * Uses Flutter rendering on the secondary display to show the same UI
 * as the main screen - a true extension of the app.
 */
class DualScreenManager(
    private val context: Context,
    private val mainEngine: FlutterEngine
) {
    companion object {
        private const val TAG = "DualScreenManager"
        private const val DUAL_SCREEN_CHANNEL = "com.retrotracker.retrotracker/dual_screen"
    }

    private val displayManager: DisplayManager =
        context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

    private var secondaryPresentation: FlutterSecondaryPresentation? = null
    private var secondaryEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Cache the latest game data to send to secondary when it connects
    private var cachedGameData: Map<String, Any?>? = null

    private val displayListener = object : DisplayManager.DisplayListener {
        override fun onDisplayAdded(displayId: Int) {
            Log.d(TAG, "Display added: $displayId")
            notifyDisplayChange()
        }

        override fun onDisplayRemoved(displayId: Int) {
            Log.d(TAG, "Display removed: $displayId")
            if (secondaryPresentation?.display?.displayId == displayId) {
                dismissSecondaryPresentation()
            }
            notifyDisplayChange()
        }

        override fun onDisplayChanged(displayId: Int) {
            Log.d(TAG, "Display changed: $displayId")
            notifyDisplayChange()
        }
    }

    fun initialize() {
        // Set up method channel for communication with main Flutter app
        methodChannel = MethodChannel(
            mainEngine.dartExecutor.binaryMessenger,
            DUAL_SCREEN_CHANNEL
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDisplays" -> {
                        result.success(getAvailableDisplays())
                    }
                    "hasSecondaryDisplay" -> {
                        result.success(hasSecondaryDisplay())
                    }
                    "showOnSecondary" -> {
                        showOnSecondaryDisplay()
                        result.success(true)
                    }
                    "dismissSecondary" -> {
                        // Only dismiss the presentation, not the activity
                        dismissSecondaryPresentation()
                        result.success(true)
                    }
                    "closeSecondaryActivity" -> {
                        // Explicitly close SecondaryDisplayActivity
                        closeSecondaryActivity()
                        result.success(true)
                    }
                    "dismissAll" -> {
                        // Dismiss everything - presentation AND activity
                        dismissSecondaryPresentation()
                        closeSecondaryActivity()
                        result.success(true)
                    }
                    "finishMainActivity" -> {
                        // Close the main activity (for bottom-only mode)
                        finishMainActivity()
                        result.success(true)
                    }
                    "getSecondaryDisplayInfo" -> {
                        result.success(getSecondaryDisplayInfo())
                    }
                    "sendToSecondary" -> {
                        @Suppress("UNCHECKED_CAST")
                        val data = call.argument<Map<String, Any?>>("data")
                        updateSecondaryDisplay(data)
                        result.success(true)
                    }
                    "isSecondaryActive" -> {
                        result.success(secondaryPresentation != null)
                    }
                    "launchOnDisplay" -> {
                        val displayId = call.argument<Int>("displayId") ?: -1
                        val launchFull = call.argument<Boolean>("launchFullApp") ?: false
                        result.success(launchOnDisplay(displayId, launchFull))
                    }
                    "launchOnPrimary" -> {
                        // When called from primary, this is a no-op (we're already on primary)
                        Log.d(TAG, "launchOnPrimary called from primary - already on primary")
                        result.success(true)
                    }
                    "isRunningOnSecondary" -> {
                        // Primary activity is not on secondary
                        result.success(false)
                    }
                    "getDefaultDisplayId" -> {
                        result.success(Display.DEFAULT_DISPLAY)
                    }
                    "isMultiDisplayAvailable" -> {
                        result.success(hasSecondaryDisplay())
                    }
                    "getCurrentDisplayId" -> {
                        result.success(getCurrentDisplayId())
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Register display listener
        displayManager.registerDisplayListener(displayListener, mainHandler)

        Log.d(TAG, "DualScreenManager initialized. Displays: ${getAvailableDisplays()}")
    }

    fun dispose() {
        displayManager.unregisterDisplayListener(displayListener)
        // Only dismiss presentation, NOT the activity - activity runs in separate process
        dismissSecondaryPresentation()
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

    fun hasSecondaryDisplay(): Boolean {
        val displays = displayManager.displays
        return displays.size > 1
    }

    private fun getSecondaryDisplay(): Display? {
        return displayManager.displays.firstOrNull { it.displayId != Display.DEFAULT_DISPLAY }
    }

    private fun getSecondaryDisplayInfo(): Map<String, Any>? {
        val display = getSecondaryDisplay() ?: return null
        return mapOf(
            "displayId" to display.displayId,
            "name" to (display.name ?: "Secondary Display"),
            "width" to display.mode.physicalWidth,
            "height" to display.mode.physicalHeight,
            "rotation" to display.rotation,
            "refreshRate" to display.refreshRate
        )
    }

    fun showOnSecondaryDisplay() {
        val secondaryDisplay = getSecondaryDisplay()
        if (secondaryDisplay == null) {
            Log.w(TAG, "No secondary display available")
            return
        }

        mainHandler.post {
            try {
                // Dismiss any existing presentation
                secondaryPresentation?.dismiss()
                secondaryEngine?.destroy()

                // Create a new Flutter engine for the secondary display
                val app = context.applicationContext as RetroTrackerApp
                secondaryEngine = app.createSecondaryEngine()

                // Create and show the Flutter presentation with event callback
                secondaryPresentation = FlutterSecondaryPresentation(
                    context,
                    secondaryDisplay,
                    secondaryEngine!!
                ) { eventType, data ->
                    // Forward events from secondary to main Flutter app
                    handleEventFromSecondary(eventType, data)
                }.apply {
                    show()
                }

                Log.d(TAG, "Flutter secondary display shown on display ${secondaryDisplay.displayId}")

                // Notify main Flutter app that secondary is active
                methodChannel?.invokeMethod("onSecondaryDisplayActive", true)

                // Send cached game data if available (after a short delay for Flutter to initialize)
                cachedGameData?.let { data ->
                    mainHandler.postDelayed({
                        secondaryPresentation?.sendGameData(data)
                    }, 500)
                }

            } catch (e: Exception) {
                Log.e(TAG, "Failed to show Flutter secondary display", e)
            }
        }
    }

    /**
     * Handle events from secondary display and forward to main Flutter app
     */
    private fun handleEventFromSecondary(eventType: String, data: Map<String, Any?>) {
        Log.d(TAG, "handleEventFromSecondary: event=$eventType, methodChannel=${methodChannel != null}")
        mainHandler.post {
            Log.d(TAG, "Invoking onSecondaryEvent on main channel")
            methodChannel?.invokeMethod("onSecondaryEvent", mapOf(
                "event" to eventType,
                "data" to data
            ), object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.d(TAG, "onSecondaryEvent delivered successfully: $result")
                }
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "onSecondaryEvent error: $errorCode - $errorMessage - $errorDetails")
                }
                override fun notImplemented() {
                    Log.e(TAG, "onSecondaryEvent NOT IMPLEMENTED on Flutter side!")
                }
            })
            Log.d(TAG, "onSecondaryEvent invoked")
        }
    }

    /**
     * Dismiss only the secondary presentation (companion view).
     * Does NOT close SecondaryDisplayActivity.
     */
    fun dismissSecondaryPresentation() {
        mainHandler.post {
            // Dismiss the presentation if active
            secondaryPresentation?.dismiss()
            secondaryPresentation = null

            secondaryEngine?.destroy()
            secondaryEngine = null

            Log.d(TAG, "Secondary presentation dismissed")

            // Notify Flutter
            methodChannel?.invokeMethod("onSecondaryDisplayActive", false)
        }
    }

    /**
     * Finish the main activity (for bottom-only mode)
     */
    private fun finishMainActivity() {
        mainHandler.post {
            Log.d(TAG, "Finishing main activity")
            (context as? android.app.Activity)?.finishAndRemoveTask()
        }
    }

    /**
     * Close any running SecondaryDisplayActivity instances
     */
    private fun closeSecondaryActivity() {
        try {
            // Send a broadcast to close SecondaryDisplayActivity
            val intent = android.content.Intent("com.retrotracker.retrotracker.CLOSE_SECONDARY_ACTIVITY")
            intent.setPackage(context.packageName)
            context.sendBroadcast(intent)
            Log.d(TAG, "Sent close broadcast to SecondaryDisplayActivity")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to close SecondaryDisplayActivity", e)
        }
    }

    private fun updateSecondaryDisplay(data: Map<String, Any?>?) {
        if (data == null) return

        // Cache the data
        cachedGameData = data

        mainHandler.post {
            secondaryPresentation?.sendGameData(data)
        }
    }

    private fun notifyDisplayChange() {
        methodChannel?.invokeMethod("onDisplaysChanged", getAvailableDisplays())
    }

    /**
     * Get the display ID that the main activity is currently running on
     */
    private fun getCurrentDisplayId(): Int {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                (context as? android.app.Activity)?.display?.displayId ?: Display.DEFAULT_DISPLAY
            } else {
                @Suppress("DEPRECATION")
                (context as? android.app.Activity)?.windowManager?.defaultDisplay?.displayId ?: Display.DEFAULT_DISPLAY
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get current display ID", e)
            Display.DEFAULT_DISPLAY
        }
    }

    /**
     * Launch the app on a specific display.
     *
     * @param displayId The ID of the display to launch on (-1 for default)
     * @param launchFullApp If true, launches the full app (SecondaryDisplayActivity).
     *                      If false, shows the companion view (FlutterSecondaryPresentation).
     * @return true if launch was successful, false otherwise
     */
    fun launchOnDisplay(displayId: Int, launchFullApp: Boolean): Boolean {
        Log.d(TAG, "launchOnDisplay: displayId=$displayId, launchFullApp=$launchFullApp")

        // Find the target display
        val targetDisplay = if (displayId == -1 || displayId == Display.DEFAULT_DISPLAY) {
            getSecondaryDisplay()
        } else {
            displayManager.displays.find { it.displayId == displayId }
        }

        if (targetDisplay == null) {
            Log.w(TAG, "Target display not found: $displayId")
            return false
        }

        return if (launchFullApp) {
            launchActivityOnDisplay(targetDisplay.displayId)
        } else {
            // Use presentation mode
            showOnSecondaryDisplay()
            true
        }
    }

    /**
     * Launch the SecondaryDisplayActivity on a specific display
     */
    private fun launchActivityOnDisplay(displayId: Int): Boolean {
        return try {
            val intent = Intent(context, SecondaryDisplayActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
            }

            // Create ActivityOptions with the target display
            val options = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                ActivityOptions.makeBasic().apply {
                    launchDisplayId = displayId
                }
            } else {
                ActivityOptions.makeBasic()
            }

            Log.d(TAG, "Launching SecondaryDisplayActivity on display $displayId")
            context.startActivity(intent, options.toBundle())
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch activity on display $displayId", e)
            false
        }
    }

    /**
     * Get a specific display by ID
     */
    fun getDisplayById(displayId: Int): Display? {
        return displayManager.displays.find { it.displayId == displayId }
    }
}
