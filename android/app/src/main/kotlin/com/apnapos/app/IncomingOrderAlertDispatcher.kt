package com.apnapos.app

import android.app.ActivityOptions
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject

/** Native notification owner, callable before a Flutter engine exists. */
internal object IncomingOrderAlertDispatcher {
    private const val RECENT = "apna_native_order_alerts"
    private const val DEDUPE_MS = 180000L

    fun cancel(context: Context, orderKey: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val id = orderKey.hashCode() and 0x7fffffff
        manager.cancel(id)
        manager.cancel("order_$orderKey", id)
    }

    fun normalize(raw: Map<String, String>): Map<String, String> {
        val result = linkedMapOf<String, String>()
        fun visit(json: JSONObject, depth: Int) {
            if (depth > 4) return
            for (key in listOf("metadata", "order", "data")) {
                val child = json.opt(key)
                val nested = if (child is JSONObject) child else try { JSONObject(child.toString()) } catch (_: Exception) { null }
                if (nested != null) visit(nested, depth + 1)
            }
            for (key in json.keys()) {
                val value = json.opt(key)?.toString().orEmpty()
                if (value.isNotBlank() && value != "null" && value != "undefined") result[key] = value
            }
        }
        visit(JSONObject(raw), 0)
        if (result["orderId"].isNullOrBlank()) {
            (result["_id"] ?: result["id"])?.let { result["orderId"] = it }
        }
        if (result["tableNumber"].isNullOrBlank()) {
            (result["tableCode"] ?: result["table_number"] ?: result["T"])?.let { result["tableNumber"] = it }
        }
        return result
    }

    /** True means Flutter must not post a second notification for this delivery. */
    @Synchronized fun dispatch(context: Context, raw: Map<String, String>): Boolean {
        val data = normalize(raw)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val key = OrderAlertPolicy.key(data) ?: return false
        if (OrderAlertPolicy.isHandled(data)) {
            // UI preferences/cache may outlive a background delivery. Keep a
            // bounded tombstone so an in-memory pending screen cannot reopen.
            val handled = try { JSONObject(prefs.getString("flutter.apna_handled_order_keys", "{}") ?: "{}") }
                catch (_: Exception) { JSONObject() }
            handled.put(key, System.currentTimeMillis())
            while (handled.length() > 128) {
                handled.keys().asSequence().minByOrNull { handled.optLong(it) }?.let { handled.remove(it) }
            }
            prefs.edit().putString("flutter.apna_handled_order_keys", handled.toString()).apply()
            OrderRingtoneService.stopMatching(context, key)
            cancel(context, key)
            for (prefKey in listOf("flutter.pending_incoming_order_payload", "pending_incoming_order_payload")) {
                val queued = prefs.getString(prefKey, null) ?: continue
                val queuedData = try {
                    val json = JSONObject(queued)
                    normalize(json.keys().asSequence().associateWith { json.opt(it).toString() })
                } catch (_: Exception) { emptyMap() }
                if (OrderAlertPolicy.key(queuedData) == key) prefs.edit().remove(prefKey).apply()
            }
            return true
        }
        if (!OrderAlertPolicy.isIncoming(data)) return false
        val recent = try { JSONObject(prefs.getString(RECENT, "{}") ?: "{}") } catch (_: Exception) { JSONObject() }
        val now = System.currentTimeMillis()
        val age = now - recent.optLong(key, 0)
        if (age in 0 until DEDUPE_MS && recent.has(key)) return true

        val payload = JSONObject(data).toString()
        // Save asynchronously without blocking the thread
        prefs.edit().putString("flutter.pending_incoming_order_payload", payload)
            .putString("pending_incoming_order_payload", payload).apply()

        if (MainActivity.isAppInForeground) {
            MainActivity.activeInstance?.let { activity ->
                activity.runOnUiThread { activity.notifyIncomingOrder(payload) }
                remember(recent, key, now, context)
                return true
            }
        }

        return try {
            ensureChannel(manager)
            val review = activityIntent(context, data, payload, "review")
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val creatorOptions = ActivityOptions.makeBasic().apply {
                if (Build.VERSION.SDK_INT >= 35) {
                    setPendingIntentCreatorBackgroundActivityStartMode(
                        if (Build.VERSION.SDK_INT >= 36) ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOW_ALWAYS
                        else ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED)
                }
            }.toBundle()
            fun pending(mode: String) = PendingIntent.getActivity(context, OrderAlertPolicy.notificationId(data),
                activityIntent(context, data, payload, mode), flags, creatorOptions)
            val reviewPending = PendingIntent.getActivity(context, OrderAlertPolicy.notificationId(data), review, flags, creatorOptions)
            val volume = prefs.all["flutter.pref_order_volume"]?.toString()
                ?.removePrefix("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu")?.toFloatOrNull() ?: 1f
            val soundEnabled = volume > 0f && prefs.getBoolean("flutter.sound_feedback_enabled", true)
            val number = data["orderNumber"].orEmpty().removePrefix("#")
            val table = data["tableNumber"]?.takeIf { it.isNotBlank() }?.let { "Table $it · " }.orEmpty()
            val title = "$table${if (number.isBlank()) "New order" else "#$number"}"
            val body = "${data["customerName"] ?: "Customer"} · ₹${data["totalAmount"] ?: "0"}"
            val builder = NotificationCompat.Builder(context, ApnaPosFirebaseMessagingService.ORDER_CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher).setContentTitle(title).setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_MAX).setCategory(NotificationCompat.CATEGORY_EVENT)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC).setContentIntent(reviewPending)
                .setAutoCancel(true).setOnlyAlertOnce(true)
                .addAction(0, "Accept", pending("accept")).addAction(0, "Reject", pending("reject"))
            // A native ringtone is not a reason to silence the notification: doing
            // so can suppress heads-up/full-screen presentation on Android.
            if (!soundEnabled) builder.setSilent(true)
            if (Build.VERSION.SDK_INT < 34 || manager.canUseFullScreenIntent()) builder.setFullScreenIntent(reviewPending, true)
            manager.notify("order_$key", OrderAlertPolicy.notificationId(data), builder.build())
            remember(recent, key, now, context)

            if (soundEnabled) {
                try {
                    val audio = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                    audio?.setStreamVolume(AudioManager.STREAM_ALARM, audio.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0)
                    audio?.setStreamVolume(AudioManager.STREAM_MUSIC, audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC), 0)
                } catch (_: Exception) { /* A restricted audio setting must not lose the order notification. */ }
                OrderRingtoneService.start(context, key)
            }

            // FSI is the normal system-controlled path. Where the user has
            // explicitly allowed display-over-apps, retain automatic presentation
            // for unlocked/background use too. Do not self-send an otherwise
            // forbidden PendingIntent and assume it bypasses Android BAL rules.
            if (Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(context)) {
                try { context.startActivity(review) } catch (error: Exception) {
                    Log.w("ApnaOrderAlert", "Direct presentation deferred to notification", error)
                }
            }
            true
        } catch (error: Exception) {
            Log.e("ApnaOrderAlert", "Could not post native order alert", error)
            false
        }
    }

    private fun activityIntent(context: Context, fields: Map<String, String>, payload: String, mode: String): Intent =
        Intent(context, MainActivity::class.java).apply {
            action = "FLUTTER_NOTIFICATION_CLICK"
            // URI identity isolates review/accept/reject, even if request-code hashes collide.
            this.data = Uri.Builder().scheme("apnapos").authority("incoming-order")
                .appendPath(OrderAlertPolicy.key(fields)).appendPath(mode).build()
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            fields.forEach { (key, value) -> putExtra(key, value) }
            putExtra("pending_incoming_order_payload", payload)
            putExtra("direct_open", true)
            removeExtra("pending_notification_action")
            if (mode != "review") putExtra("pending_notification_action", mode)
        }

    private fun remember(recent: JSONObject, key: String, now: Long, context: Context) {
        for (old in recent.keys().asSequence().toList()) {
            if (now - recent.optLong(old) !in 0 until DEDUPE_MS) recent.remove(old)
        }
        recent.put(key, now)
        while (recent.length() > 128) recent.keys().asSequence().minByOrNull { recent.optLong(it) }?.let { recent.remove(it) }
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit().putString(RECENT, recent.toString()).apply()
    }

    private fun ensureChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(ApnaPosFirebaseMessagingService.ORDER_CHANNEL_ID) != null) return
        manager.createNotificationChannel(NotificationChannel(ApnaPosFirebaseMessagingService.ORDER_CHANNEL_ID,
            ApnaPosFirebaseMessagingService.ORDER_CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH).apply {
            description = "Incoming customer orders requiring review"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500, 200, 500)
            setSound(Settings.System.DEFAULT_NOTIFICATION_URI, AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
            lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
        })
    }
}
