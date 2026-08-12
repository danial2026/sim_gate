package com.danials.sim_gate

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * MainActivity for SimGate.
 *
 * Attaches to the process-wide [SimGateApplication.flutterEngine] instead of
 * creating its own, so the Dart isolate (HTTP server + SMS queue) survives
 * activity destruction. Platform channels are registered once by
 * [SimGateApplication].
 */
class MainActivity : FlutterActivity() {

    override fun getCachedEngineId(): String? = SimGateApplication.ENGINE_ID

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return FlutterEngineCache.getInstance().get(SimGateApplication.ENGINE_ID)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
}