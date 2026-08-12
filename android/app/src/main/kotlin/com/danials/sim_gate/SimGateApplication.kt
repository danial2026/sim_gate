package com.danials.sim_gate

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.loader.FlutterInjector

/**
 * Application entry point.
 *
 * Creates a single [FlutterEngine] that lives for the whole process instead of
 * being tied to an activity. The Dart isolate (which hosts the HTTP server and
 * the SMS queue) therefore keeps running when the activity is destroyed —
 * e.g. when the user locks the phone or swipes the app away — and only dies
 * when [SimGateService] is stopped and the process is removed.
 *
 * [SimGateChannels] is registered here once so the platform channels stay
 * available for the lifetime of the engine.
 */
class SimGateApplication : Application() {

    companion object {
        const val ENGINE_ID = "sim_gate_engine"
    }

    lateinit var flutterEngine: FlutterEngine
        private set

    override fun onCreate() {
        super.onCreate()
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader, "main"),
        )
        SimGateChannels(applicationContext, flutterEngine)
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
    }
}