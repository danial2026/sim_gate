package com.example.sim_gate

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * MainActivity for SimGate.
 *
 * Registers the native platform channels (SMS, SIM, network interfaces) on
 * the Flutter engine so the Dart side can call into Android APIs.
 */
class MainActivity : FlutterActivity() {

    private var channels: SimGateChannels? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channels = SimGateChannels(applicationContext, flutterEngine)
    }

    override fun onDestroy() {
        channels = null
        super.onDestroy()
    }

    // Keep the engine configurable for tests.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
}
