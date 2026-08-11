package com.example.sim_gate

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface

/**
 * Native platform channel handlers for SimGate.
 *
 * Exposes three methods to Dart:
 *   - sendSms(simId, recipient, message)          -> sends an SMS via a SIM
 *   - detectSims()                                 -> lists SIM cards + metadata
 *   - networkInterfaces()                          -> lists local IPv4 addresses
 *
 * The channel name must match MethodChannelPlatformService in Dart:
 *   com.example.sim_gate/platform
 */
class SimGateChannels(
    private val context: Context,
    engine: FlutterEngine,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "SimGateChannels"
        private const val CHANNEL = "com.example.sim_gate/platform"
    }

    private val channel: MethodChannel = MethodChannel(
        engine.dartExecutor.binaryMessenger,
        CHANNEL,
    ).also { it.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sendSms" -> sendSms(call, result)
            "detectSims" -> detectSims(result)
            "networkInterfaces" -> networkInterfaces(result)
            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // SMS sending
    // -------------------------------------------------------------------------

    /** Sends [message] to [recipient] using the SIM identified by [simId]. */
    private fun sendSms(call: MethodCall, result: MethodChannel.Result) {
        val simId = call.argument<String>("simId")
        val recipient = call.argument<String>("recipient")
        val message = call.argument<String>("message")

        if (recipient == null || message == null) {
            result.error("INVALID_ARGS", "recipient and message are required", null)
            return
        }
        if (!recipient.matches(Regex("^\\+?[0-9]{7,15}$"))) {
            result.error("INVALID_RECIPIENT", "Malformed phone number: $recipient", null)
            return
        }
        try {
            val smsManager = SmsManagerFactory.create(context, simId)
            smsManager.sendTextMessage(recipient, null, message, null, null)
            Log.i(TAG, "SMS sent to $recipient via sim=$simId")
            result.success(true)
        } catch (e: SecurityException) {
            Log.e(TAG, "SMS permission missing", e)
            result.error("SMS_PERMISSION", "SEND_SMS permission not granted", null)
        } catch (e: Exception) {
            Log.e(TAG, "sendSms failed", e)
            result.error("SEND_FAILED", e.message ?: "Unknown send error", null)
        }
    }

    // -------------------------------------------------------------------------
    // SIM detection
    // -------------------------------------------------------------------------

    /**
     * Enumerates all SIM cards via SubscriptionManager and returns a list of
     * maps with: simId, slotNumber, name, phoneNumber, carrier, signalStrength,
     * networkType, isActive, isRoaming, state.
     */
    private fun detectSims(result: MethodChannel.Result) {
        try {
            val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
            val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

            val subscriptions: List<SubscriptionInfo> =
                subscriptionManager.activeSubscriptionInfoList ?: emptyList()

            val list = mutableListOf<Map<String, Any?>>()
            for (sub in subscriptions) {
                val phoneId = sub.simSlotIndex
                val simId = "${sub.simSlotIndex}_${sub.subscriptionId}"
                list.add(
                    mapOf(
                        "simId" to simId,
                        "slotNumber" to sub.simSlotIndex,
                        "name" to sub.displayName?.toString(),
                        "phoneNumber" to sub.number,
                        "carrier" to sub.carrierName?.toString(),
                        "signalStrength" to readSignalStrength(telephony, phoneId),
                        "networkType" to readNetworkType(telephony, phoneId),
                        "isActive" to true,
                        "isRoaming" to readRoaming(telephony, phoneId),
                    ),
                )
            }
            Log.i(TAG, "Detected ${list.size} SIM(s)")
            result.success(list)
        } catch (e: SecurityException) {
            Log.e(TAG, "READ_PHONE_STATE missing", e)
            result.error("PHONE_STATE_PERMISSION", "READ_PHONE_STATE not granted", null)
        } catch (e: Exception) {
            Log.e(TAG, "detectSims failed", e)
            result.error("DETECT_FAILED", e.message ?: "Unknown detection error", null)
        }
    }

    private fun readSignalStrength(telephony: TelephonyManager, phoneId: Int): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val signal = telephony.signalStrength
                if (signal == null) 0 else signal.level.coerceIn(0, 4)
            } else {
                0
            }
        } catch (e: Exception) {
            0
        }
    }

    private fun readNetworkType(telephony: TelephonyManager, phoneId: Int): String {
        return try {
            when (telephony.dataNetworkType) {
                TelephonyManager.NETWORK_TYPE_GPRS,
                TelephonyManager.NETWORK_TYPE_EDGE,
                -> "2G"
                TelephonyManager.NETWORK_TYPE_UMTS,
                TelephonyManager.NETWORK_TYPE_HSDPA,
                TelephonyManager.NETWORK_TYPE_HSPA,
                -> "3G"
                TelephonyManager.NETWORK_TYPE_LTE -> "4G"
                TelephonyManager.NETWORK_TYPE_NR -> "5G"
                else -> "None"
            }
        } catch (e: Exception) {
            "None"
        }
    }

    private fun readRoaming(telephony: TelephonyManager, phoneId: Int): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) telephony.isNetworkRoaming else false
        } catch (e: Exception) {
            false
        }
    }

    // -------------------------------------------------------------------------
    // Network interfaces
    // -------------------------------------------------------------------------

    /** Returns the device's non-loopback IPv4 addresses (e.g. 192.168.x.x). */
    private fun networkInterfaces(result: MethodChannel.Result) {
        try {
            val interfaces = mutableListOf<Map<String, String>>()
            NetworkInterface.getNetworkInterfaces()?.toList()?.forEach { iface ->
                if (!iface.isLoopback && iface.isUp) {
                    iface.inetAddresses?.toList()?.forEach { addr ->
                        if (addr is Inet4Address) {
                            interfaces.add(mapOf("name" to iface.name, "address" to addr.hostAddress.orEmpty()))
                        }
                    }
                }
            }
            result.success(interfaces)
        } catch (e: Exception) {
            Log.e(TAG, "networkInterfaces failed", e)
            result.error("IFACE_FAILED", e.message ?: "Unknown error", null)
        }
    }
}

/** Helper that picks the per-SIM SmsManager (API 23+) or the default one. */
private class SmsManagerFactory {
    companion object {
        @Suppress("DEPRECATION")
        fun create(context: Context, simId: String?): android.telephony.SmsManager {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // SIM ids from detectSims are "<slot>_<subId>"; parse the subId.
                val subId = simId?.substringAfter('_')?.toIntOrNull()
                if (subId != null) {
                    android.telephony.SmsManager.getSmsManagerForSubscriptionId(subId)
                } else {
                    android.telephony.SmsManager.getDefault()
                }
            } else {
                android.telephony.SmsManager.getDefault()
            }
        }
    }
}

@Suppress("unused")
fun wifiIp(context: Context): String {
    val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    return wifi.connectionInfo.ipAddress.toString()
}
