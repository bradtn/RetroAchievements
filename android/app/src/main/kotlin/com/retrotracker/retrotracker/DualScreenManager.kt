package com.retrotracker.retrotracker

import android.content.Context
import android.hardware.display.DisplayManager
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
                dismissSecondaryDisplay()
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
                        dismissSecondaryDisplay()
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
        dismissSecondaryDisplay()
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

    fun dismissSecondaryDisplay() {
        mainHandler.post {
            secondaryPresentation?.dismiss()
            secondaryPresentation = null

            secondaryEngine?.destroy()
            secondaryEngine = null

            Log.d(TAG, "Secondary display dismissed")

            // Notify Flutter
            methodChannel?.invokeMethod("onSecondaryDisplayActive", false)
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
}
