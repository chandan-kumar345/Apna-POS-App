package com.apnapos.app

import android.app.ActivityOptions
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.apnapos.app/order_alert"
        var activeInstance: MainActivity? = null
        var isAppInForeground: Boolean = false
        private var lastWakeTime: Long = 0L
        private var activeWakeLock: PowerManager.WakeLock? = null
    }

    private var userPresentReceiver: BroadcastReceiver? = null

    // RenderMode.texture (TextureView) avoids native SurfaceView GPU/raster deadlocks
    // on Android 11+ and eliminates LegacyMessageQueue freezes during screen/overlay transitions
    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        activeInstance = this
        registerUserPresentReceiver()
        wakeAndShowOverLockScreen()
        handleIncomingOrderIntent(intent)
    }

    private fun registerUserPresentReceiver() {
        if (userPresentReceiver != null) return
        userPresentReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == Intent.ACTION_USER_PRESENT) {
                    try {
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        var pendingPayload = prefs.getString("flutter.pending_incoming_order_payload", null)
                        if (pendingPayload.isNullOrEmpty()) {
                            pendingPayload = prefs.getString("pending_incoming_order_payload", null)
                        }
                        if (!pendingPayload.isNullOrEmpty()) {
                            prefs.edit()
                                .remove("flutter.pending_incoming_order_payload")
                                .remove("pending_incoming_order_payload")
                                .apply()
                            bringAppToForeground(pendingPayload)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
            }
        }
        val filter = IntentFilter(Intent.ACTION_USER_PRESENT)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(userPresentReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(userPresentReceiver, filter)
            }
        } catch (_: Exception) {
            try {
                registerReceiver(userPresentReceiver, filter)
            } catch (err: Exception) {
                err.printStackTrace()
            }
        }
    }

    private fun unregisterUserPresentReceiver() {
        try {
            if (userPresentReceiver != null) {
                unregisterReceiver(userPresentReceiver)
                userPresentReceiver = null
            }
        } catch (_: Exception) {}
    }

    override fun onResume() {
        super.onResume()
        activeInstance = this
        isAppInForeground = true
        wakeAndShowOverLockScreen()
    }

    override fun onPause() {
        super.onPause()
        isAppInForeground = false
    }

    override fun onStop() {
        super.onStop()
        isAppInForeground = false
    }

    override fun onDestroy() {
        unregisterUserPresentReceiver()
        if (activeInstance == this) {
            activeInstance = null
        }
        try {
            if (activeWakeLock?.isHeld == true) {
                activeWakeLock?.release()
            }
            activeWakeLock = null
        } catch (_: Exception) {}
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        wakeAndShowOverLockScreen()
        handleIncomingOrderIntent(intent)
    }

    fun bringAppToForeground(payload: String? = null) {
        if (!payload.isNullOrEmpty()) {
            try {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit()
                    .putString("flutter.pending_incoming_order_payload", payload)
                    .putString("pending_incoming_order_payload", payload)
                    .apply()
            } catch (_: Exception) {}
        }

        wakeAndShowOverLockScreen()

        // If the app is already in the foreground, do NOT call startActivity which causes self-pause and GPU surface deadlocks
        if (isAppInForeground && !isFinishing && !isDestroyed) {
            return
        }

        val launchIntent = (packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this@MainActivity, MainActivity::class.java)).apply {
            action = "FLUTTER_NOTIFICATION_CLICK"
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            if (!payload.isNullOrEmpty()) {
                putExtra("pending_incoming_order_payload", payload)
                putExtra("direct_open", true)
            }
        }

        val options = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ActivityOptions.makeBasic().apply {
                setPendingIntentBackgroundActivityStartMode(ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
            }
        } else {
            ActivityOptions.makeBasic()
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        try {
            val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Settings.canDrawOverlays(this@MainActivity)
            } else {
                true
            }
            if (canDraw) {
                startActivity(launchIntent, options.toBundle())
            } else {
                val pi = PendingIntent.getActivity(
                    applicationContext,
                    (System.currentTimeMillis() % 100000).toInt(),
                    launchIntent,
                    pendingIntentFlags,
                    options.toBundle()
                )
                pi.send()
            }
        } catch (_: Exception) {
            try {
                startActivity(launchIntent, options.toBundle())
            } catch (_: Exception) {}
        }
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
                        val payload = call.argument<String>("payload")
                        if (!payload.isNullOrEmpty()) {
                            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                            prefs.edit().putString("flutter.pending_incoming_order_payload", payload).apply()
                        }

                        // If app is already in the foreground, wake lock screen & return
                        if (isAppInForeground && !isFinishing && !isDestroyed) {
                            wakeAndShowOverLockScreen()
                            result.success(true)
                            return@setMethodCallHandler
                        }

                        bringAppToForeground(payload)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "checkOrderPermissions" -> {
                    try {
                        val overlayGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this@MainActivity)
                        } else {
                            true
                        }
                        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                        val batteryOptIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            powerManager?.isIgnoringBatteryOptimizations(packageName) ?: true
                        } else {
                            true
                        }
                        val notificationsEnabled = NotificationManagerCompat.from(this@MainActivity).areNotificationsEnabled()

                        val resMap = mapOf(
                            "overlayGranted" to overlayGranted,
                            "batteryOptimizationIgnored" to batteryOptIgnored,
                            "notificationsEnabled" to notificationsEnabled
                        )
                        result.success(resMap)
                    } catch (e: Exception) {
                        result.error("PERMISSION_CHECK_ERROR", e.message, null)
                    }
                }
                "requestOverlayPermission" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            if (!Settings.canDrawOverlays(this@MainActivity)) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                ).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    putExtra("package", packageName)
                                    putExtra("package_name", packageName)
                                    putExtra("extra_pkgname", packageName)
                                    putExtra("android.provider.extra.APP_PACKAGE", packageName)
                                }
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.success(true)
                            }
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                putExtra("package", packageName)
                                putExtra("package_name", packageName)
                                putExtra("extra_pkgname", packageName)
                                putExtra("android.provider.extra.APP_PACKAGE", packageName)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (err: Exception) {
                            try {
                                val appInfoIntent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(appInfoIntent)
                                result.success(true)
                            } catch (finalErr: Exception) {
                                result.error("OVERLAY_INTENT_ERROR", finalErr.message, null)
                            }
                        }
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                            if (pm != null && !pm.isIgnoringBatteryOptimizations(packageName)) {
                                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                    data = Uri.parse("package:$packageName")
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.success(true)
                            }
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("BATTERY_INTENT_ERROR", e.message, null)
                    }
                }
                "openAppInfoSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("APP_INFO_ERROR", e.message, null)
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

        val rawSource = (extras.getString("orderSource") ?: "").lowercase()
        val typeStr = (extras.getString("type") ?: "").lowercase()
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

        if (isOrder && !isLocalPosOrder) {
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
                val editor = prefs.edit()
                    .putString("flutter.pending_incoming_order_payload", payloadString)
                    .putString("pending_incoming_order_payload", payloadString)
                val action = extras.getString("pending_notification_action")
                if (!action.isNullOrEmpty()) {
                    editor.putString("flutter.pending_notification_action", action)
                    editor.putString("pending_notification_action", action)
                }
                editor.apply()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    fun wakeAndShowOverLockScreen() {
        val now = System.currentTimeMillis()
        if (now - lastWakeTime < 5000) {
            return
        }
        lastWakeTime = now

        try {
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as? android.app.KeyguardManager
            val isLocked = keyguardManager?.isKeyguardLocked ?: false

            if (isLocked) {
                if (activeWakeLock?.isHeld == true) {
                    activeWakeLock?.release()
                }
                val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                activeWakeLock = pm?.newWakeLock(
                    PowerManager.SCREEN_DIM_WAKE_LOCK or
                    PowerManager.ACQUIRE_CAUSES_WAKEUP or
                    PowerManager.ON_AFTER_RELEASE,
                    "apnapos:main_activity_wake"
                )
                activeWakeLock?.acquire(5000)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    setShowWhenLocked(true)
                    setTurnScreenOn(true)
                    keyguardManager?.requestDismissKeyguard(this, null)
                } else {
                    @Suppress("DEPRECATION")
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                    )
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
