package com.apnapos.app

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.PowerManager
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import org.json.JSONObject

class ApnaPosFirebaseMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        val type = data["type"] ?: ""
        val entityType = data["entityType"] ?: ""
        val isOrder = type == "whatsapp_order_request" ||
                type == "whatsapp_new_order" ||
                type == "whatsapp_order" ||
                type == "new_order" ||
                type == "newOrder" ||
                type == "order_created" ||
                type == "order" ||
                entityType == "whatsapp_order" ||
                entityType == "order" ||
                data.containsKey("orderNumber") ||
                data.containsKey("orderId") ||
                data.containsKey("totalAmount")

        if (isOrder) {
            try {
                // 1. Hardware Screen Wake Lock (force screen on immediately)
                val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                val wakeLock = pm?.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                    "apnapos:order_alert_wake"
                )
                wakeLock?.acquire(30000)

                // 2. Set full maximum hardware volume for alarm and media streams
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                val maxAlarm = audioManager?.getStreamMaxVolume(AudioManager.STREAM_ALARM) ?: 100
                val maxMusic = audioManager?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 100
                audioManager?.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarm, 0)
                audioManager?.setStreamVolume(AudioManager.STREAM_MUSIC, maxMusic, 0)

                // 3. Persist incoming order payload to FlutterSharedPreferences
                val payloadObj = JSONObject()
                for (entry in data.entries) {
                    payloadObj.put(entry.key, entry.value)
                }
                val payloadString = payloadObj.toString()
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit().putString("flutter.pending_incoming_order_payload", payloadString).apply()

                // 4. Directly launch MainActivity over lock screen or over other apps
                val launchIntent = Intent(applicationContext, MainActivity::class.java).apply {
                    action = "FLUTTER_NOTIFICATION_CLICK"
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                    )
                    putExtra("pending_incoming_order_payload", payloadString)
                    putExtra("direct_open", true)
                    for (entry in data.entries) {
                        putExtra(entry.key, entry.value)
                    }
                }
                applicationContext.startActivity(launchIntent)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Pass to FlutterFirebaseMessagingService so background isolates and heads-up notifications continue
        super.onMessageReceived(remoteMessage)
    }
}
