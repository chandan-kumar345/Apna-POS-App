package com.apnapos.app

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.apnapos.app/order_alert"
        var activeInstance: MainActivity? = null
    }

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activeInstance = this
        wakeAndShowOverLockScreen()
        handleIncomingOrderIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        activeInstance = this
        wakeAndShowOverLockScreen()
    }

    override fun onDestroy() {
        if (activeInstance == this) {
            activeInstance = null
        }
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        wakeAndShowOverLockScreen()
        handleIncomingOrderIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setMaxVolume" -> {
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        val maxAlarm = audioManager?.getStreamMaxVolume(AudioManager.STREAM_ALARM) ?: 100
                        val maxMusic = audioManager?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 100
                        audioManager?.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarm, 0)
                        audioManager?.setStreamVolume(AudioManager.STREAM_MUSIC, maxMusic, 0)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "bringToFront" -> {
                    try {
                        wakeAndShowOverLockScreen()
                        val bringToFrontIntent = Intent(this@MainActivity, MainActivity::class.java).apply {
                            addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP
                            )
                        }
                        startActivity(bringToFrontIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun handleIncomingOrderIntent(intent: Intent?) {
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

    fun wakeAndShowOverLockScreen() {
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
            val wakeLock = pm?.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                PowerManager.ACQUIRE_CAUSES_WAKEUP or
                PowerManager.ON_AFTER_RELEASE,
                "apnapos:main_activity_wake"
            )
            wakeLock?.acquire(30000)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? android.app.KeyguardManager
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
