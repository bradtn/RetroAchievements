package com.retrotracker.retrotracker

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Application class that manages FlutterEngineGroup for multi-display support.
 * Allows spawning additional Flutter engines that share resources with the main engine.
 */
class RetroTrackerApp : Application() {
    lateinit var engineGroup: FlutterEngineGroup
        private set

    override fun onCreate() {
        super.onCreate()
        engineGroup = FlutterEngineGroup(this)
    }

    /**
     * Create the main Flutter engine
     */
    fun createMainEngine(): FlutterEngine {
        return engineGroup.createAndRunDefaultEngine(this)
    }

    /**
     * Create a secondary engine for the secondary display
     * Uses a specific entry point for the secondary display UI
     */
    fun createSecondaryEngine(): FlutterEngine {
        val dartEntrypoint = DartExecutor.DartEntrypoint(
            "lib/main.dart",
            "secondaryDisplayMain"
        )
        return engineGroup.createAndRunEngine(this, dartEntrypoint)
    }
}
