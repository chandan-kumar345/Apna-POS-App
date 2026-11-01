package com.apnapos.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import org.json.JSONObject

class ApnaPosFirebaseMessagingService : FlutterFirebaseMessagingService() {
    companion object {
        const val ORDER_CHANNEL_ID = "apna_pos_whatsapp_orders_v2"
        const val ORDER_CHANNEL_NAME = "WhatsApp Orders & Alerts"
    }

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
                // 1. Hardware Screen Wake Lock (force screen on immediately for 30s)
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

                // 4. Build Intent to open MainActivity and show Order Accept Screen
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

                // 5. Ensure high-priority Notification Channel with sound exists on Android 8+
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val soundUri = Uri.parse("android.resource://" + packageName + "/raw/notification_sound")

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val existingChannel = notificationManager.getNotificationChannel(ORDER_CHANNEL_ID)
                    if (existingChannel == null) {
                        val audioAttributes = AudioAttributes.Builder()
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .build()
                        val channel = NotificationChannel(
                            ORDER_CHANNEL_ID,
                            ORDER_CHANNEL_NAME,
                            NotificationManager.IMPORTANCE_HIGH
                        ).apply {
                            description = "Urgent incoming customer orders with instant alert and popup"
                            enableLights(true)
                            enableVibration(true)
                            vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                            setSound(soundUri, audioAttributes)
                            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                            setBypassDnd(true)
                        }
                        notificationManager.createNotificationChannel(channel)
                    }
                }

                // 6. Build fullScreenIntent PendingIntent so Android OS immediately displays Activity over lock screen
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val fullScreenPendingIntent = PendingIntent.getActivity(
                    applicationContext,
                    (data["orderId"]?.hashCode() ?: System.currentTimeMillis().toInt()),
                    launchIntent,
                    flags
                )

                // 7. Accept and Reject Notification Action PendingIntents
                val acceptIntent = Intent(applicationContext, MainActivity::class.java).apply {
                    action = "FLUTTER_NOTIFICATION_CLICK"
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                    )
                    putExtra("pending_incoming_order_payload", payloadString)
                    putExtra("pending_notification_action", "accept")
                    putExtra("direct_open", true)
                    for (entry in data.entries) {
                        putExtra(entry.key, entry.value)
                    }
                }
                val acceptPendingIntent = PendingIntent.getActivity(
                    applicationContext,
                    ((data["orderId"]?.hashCode() ?: 1) + 1),
                    acceptIntent,
                    flags
                )

                val rejectIntent = Intent(applicationContext, MainActivity::class.java).apply {
                    action = "FLUTTER_NOTIFICATION_CLICK"
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                    )
                    putExtra("pending_incoming_order_payload", payloadString)
                    putExtra("pending_notification_action", "reject")
                    putExtra("direct_open", true)
                    for (entry in data.entries) {
                        putExtra(entry.key, entry.value)
                    }
                }
                val rejectPendingIntent = PendingIntent.getActivity(
                    applicationContext,
                    ((data["orderId"]?.hashCode() ?: 1) + 2),
                    rejectIntent,
                    flags
                )

                // 8. Format title and body to never truncate
                val orderNum = data["orderNumber"] ?: data["orderId"] ?: ""
                val cleanNum = if (orderNum.isNotEmpty()) (if (orderNum.startsWith("#")) orderNum else "#$orderNum") else ""
                val amount = data["totalAmount"] ?: ""
                val custName = data["customerName"] ?: "Customer"
                val orderType = (data["orderType"] ?: "takeaway").uppercase()

                val notifTitle = if (cleanNum.isNotEmpty()) {
                    if (amount.isNotEmpty()) "🔔 $cleanNum • ₹$amount" else "🔔 New Order: $cleanNum"
                } else {
                    if (amount.isNotEmpty()) "🔔 New Order • ₹$amount" else "🔔 New Order Received"
                }
                val notifBody = "$custName • $orderType • Tap to Accept/Reject"

                // 9. Dispatch high-priority Notification with fullScreenIntent
                val notifId = (data["orderId"]?.hashCode() ?: System.currentTimeMillis().toInt()).let { Math.abs(it) % 100000 }
                val notifBuilder = NotificationCompat.Builder(applicationContext, ORDER_CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle(notifTitle)
                    .setContentText(notifBody)
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setSound(soundUri)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setFullScreenIntent(fullScreenPendingIntent, true)
                    .setContentIntent(fullScreenPendingIntent)
                    .setAutoCancel(true)
                    .addAction(0, "ACCEPT", acceptPendingIntent)
                    .addAction(0, "REJECT", rejectPendingIntent)

                notificationManager.notify(notifId, notifBuilder.build())

                // 10. Also attempt direct startActivity (succeeds if app has overlay permission or is in foreground)
                try {
                    applicationContext.startActivity(launchIntent)
                } catch (_: Exception) {}

            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Pass to FlutterFirebaseMessagingService so background isolates and heads-up notifications continue
        super.onMessageReceived(remoteMessage)
    }
}
