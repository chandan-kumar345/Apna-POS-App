package com.apnapos.app

import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wakeAndShowOverLockScreen()
        handleIncomingOrderIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        wakeAndShowOverLockScreen()
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        wakeAndShowOverLockScreen()
        handleIncomingOrderIntent(intent)
    }

    private fun handleIncomingOrderIntent(intent: android.content.Intent?) {
        val extras = intent?.extras ?: return
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

        if (isOrder) {
            try {
                val payloadObj = JSONObject()
                for (key in extras.keySet()) {
                    val value = extras.get(key)
                    if (value != null) {
                        payloadObj.put(key, value.toString())
                    }
                }
                val payloadString = payloadObj.toString()
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit().putString("flutter.pending_incoming_order_payload", payloadString).apply()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun wakeAndShowOverLockScreen() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            val wakeLock = pm?.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "apnapos:main_activity_wake"
            )
            wakeLock?.acquire(15000)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(android.content.Context.KEYGUARD_SERVICE) as? android.app.KeyguardManager
            keyguardManager?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
