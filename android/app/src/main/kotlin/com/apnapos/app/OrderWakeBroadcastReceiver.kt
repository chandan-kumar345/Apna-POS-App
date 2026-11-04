package com.apnapos.app

import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
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

            val rawSource = (extras.getString("orderSource") ?: "").lowercase()
            val typeStr = type.lowercase()
            val isExplicitExternal = rawSource == "whatsapp" ||
                    rawSource == "storefront" ||
                    rawSource == "online" ||
                    rawSource == "qr" ||
                    rawSource == "profile" ||
                    typeStr.contains("whatsapp") ||
                    typeStr == "whatsapp_order_request"

            val isLocalPosOrder = !isExplicitExternal && (
                    rawSource == "pos" ||
                    rawSource == "counter" ||
                    rawSource == "local" ||
                    typeStr == "kot_printed"
            )

            if (!isOrder || isLocalPosOrder) return

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
            val launchIntent = (context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent(context, MainActivity::class.java)).apply {
                action = "FLUTTER_NOTIFICATION_CLICK"
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                putExtra("pending_incoming_order_payload", payloadString)
                putExtra("direct_open", true)
                putExtras(extras)
            }

            val options = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ActivityOptions.makeBasic().apply {
                    setPendingIntentBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                }
            } else {
                ActivityOptions.makeBasic()
            }

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            try {
                val pi = PendingIntent.getActivity(
                    context.applicationContext,
                    (System.currentTimeMillis() % 100000).toInt(),
                    launchIntent,
                    flags,
                    options.toBundle()
                )
                pi.send()
            } catch (_: Exception) {
                try {
                    context.startActivity(launchIntent, options.toBundle())
                } catch (_: Exception) {}
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
