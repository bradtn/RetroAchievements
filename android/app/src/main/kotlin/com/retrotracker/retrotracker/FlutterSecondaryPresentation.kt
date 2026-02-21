package com.retrotracker.retrotracker

import android.app.Presentation
import android.content.Context
import android.os.Bundle
import android.util.Log
import android.view.Display
import android.view.ViewGroup
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Presentation that displays Flutter content on a secondary display.
 * Shows the same Flutter UI as the main screen for a seamless experience.
 * Supports bidirectional communication for filter/sort sync and achievement taps.
 */
class FlutterSecondaryPresentation(
    context: Context,
    display: Display,
    private val flutterEngine: FlutterEngine,
    private val onEventFromSecondary: (String, Map<String, Any?>) -> Unit
) : Presentation(context, display) {

    companion object {
        private const val TAG = "FlutterSecondary"
        const val CHANNEL = "com.retrotracker.retrotracker/secondary_display"
    }

    private lateinit var flutterView: FlutterView
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "Creating Flutter secondary presentation on display ${display.displayId}")

        // Create FlutterView attached to our secondary engine
        flutterView = FlutterView(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }

        // Create container
        val container = FrameLayout(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            addView(flutterView)
        }

        setContentView(container)

        // Attach engine to view
        flutterView.attachToFlutterEngine(flutterEngine)

        // Set up method channel for communication
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDisplayInfo" -> {
                        result.success(getDisplayInfo())
                    }
                    "sendToMain" -> {
                        // Forward events from secondary to main
                        val eventType = call.argument<String>("event") ?: ""
                        @Suppress("UNCHECKED_CAST")
                        val data = call.argument<Map<String, Any?>>("data") ?: emptyMap()
                        Log.d(TAG, "sendToMain received: event=$eventType")
                        onEventFromSecondary(eventType, data)
                        Log.d(TAG, "sendToMain callback completed")
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // Send display info to Flutter
        sendDisplayInfo()
    }

    override fun onStart() {
        super.onStart()
        flutterEngine.lifecycleChannel.appIsResumed()
    }

    override fun onStop() {
        flutterEngine.lifecycleChannel.appIsPaused()
        super.onStop()
    }

    override fun dismiss() {
        flutterView.detachFromFlutterEngine()
        super.dismiss()
    }

    /**
     * Send game data to the secondary display Flutter app
     */
    fun sendGameData(data: Map<String, Any?>) {
        methodChannel?.invokeMethod("updateGameData", data)
    }

    private fun sendDisplayInfo() {
        methodChannel?.invokeMethod("displayInfo", getDisplayInfo())
    }

    private fun getDisplayInfo(): Map<String, Any> {
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
