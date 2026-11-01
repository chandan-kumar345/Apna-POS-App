package com.apnapos.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import org.json.JSONObject

class OrderWakeBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val extras = intent.extras ?: return

            val type = extras.getString("type") ?: ""
            val entityType = extras.getString("entityType") ?: ""
            val orderId = extras.getString("orderId") ?: ""

            val isOrder = type == "whatsapp_order_request" ||
                    type == "whatsapp_new_order" ||
                    type == "whatsapp_order" ||
                    type == "new_order" ||
                    type == "newOrder" ||
                    type == "order_created" ||
                    type == "order" ||
                    entityType == "whatsapp_order" ||
                    entityType == "order" ||
                    extras.containsKey("orderNumber") ||
                    extras.containsKey("orderId") ||
                    extras.containsKey("totalAmount") ||
                    orderId.isNotEmpty()

            if (!isOrder) return

            // 1. Force hardware screen wake up
            val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
            val wakeLock = pm?.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "apnapos:order_direct_wake"
            )
            wakeLock?.acquire(15000)

            // 2. Build JSON payload of the incoming order and write to FlutterSharedPreferences
            val payloadObj = JSONObject()
            for (key in extras.keySet()) {
                val value = extras.get(key)
                if (value != null) {
                    payloadObj.put(key, value.toString())
                }
            }
            val payloadString = payloadObj.toString()
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit().putString("flutter.pending_incoming_order_payload", payloadString).apply()
            } catch (e: Exception) {
                e.printStackTrace()
            }

            // 3. Immediately launch MainActivity so the screen takes over
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = "FLUTTER_NOTIFICATION_CLICK"
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                putExtra("pending_incoming_order_payload", payloadString)
                putExtra("direct_open", true)
                putExtras(extras)
            }
            context.startActivity(launchIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
