package com.apnapos.app

import android.app.*
import android.content.*
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.*
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.File

/** Owns one order-alert player independently of the Flutter UI/lock screen. */
class OrderRingtoneService : Service() {
    private var player: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { stopSelf() }
    companion object {
        private const val CHANNEL = "apna_pos_order_playback"
        private const val STOP = "com.apnapos.app.STOP_ORDER_RINGTONE"
        @Volatile private var activeOrderKey: String? = null
        fun stopMatching(context: Context, key: String?) {
            if (key != null && key == activeOrderKey) stop(context)
        }
        fun start(context: Context, orderKey: String? = null): Boolean {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean("flutter.sound_feedback_enabled", true)
            val volume = prefs.all["flutter.pref_order_volume"]?.toString()?.removePrefix("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu")?.toFloatOrNull() ?: 1f
            if (!enabled || volume <= 0f) return false
            return try {
                if (orderKey != null) activeOrderKey = orderKey
                ContextCompat.startForegroundService(context, Intent(context, OrderRingtoneService::class.java))
                true
            } catch (_: Exception) { false }
        }
        fun stop(context: Context) { context.stopService(Intent(context, OrderRingtoneService::class.java)) }
    }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == STOP) { stopSelf(); return START_NOT_STICKY }
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "Order ringtone playback", NotificationManager.IMPORTANCE_LOW).apply { setSound(null, null) })
        val mute = PendingIntent.getService(this, 9002, Intent(this, OrderRingtoneService::class.java).setAction(STOP), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        startForeground(9001, NotificationCompat.Builder(this, CHANNEL).setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Incoming order").setContentText("Review the order in Apna POS")
            .setOngoing(true).setSilent(true).addAction(0, "Mute", mute).build())
        handler.removeCallbacks(timeout)
        handler.postDelayed(timeout, 180000) // Bound alerts if the UI cannot open.
        if (player != null) return START_NOT_STICKY
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val volume = (prefs.all["flutter.pref_order_volume"]?.toString()?.removePrefix("VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu")?.toFloatOrNull() ?: 1f).coerceIn(0f, 1f)
        if (!prefs.getBoolean("flutter.sound_feedback_enabled", true) || volume == 0f) { stopSelf(); return START_NOT_STICKY }
        val source = prefs.getString("flutter.pref_order_native_source", null)
            ?: prefs.getString("flutter.pref_order_ringtone_url", "sounds/order_recieve_ringtone.mp3")!!
        play(source, volume)
        return START_NOT_STICKY
    }
    private fun play(source: String, volume: Float, fallback: Boolean = false) {
        try {
            val audio = MediaPlayer()
            player = audio
            audio.setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            audio.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            audio.isLooping = true
            audio.setVolume(volume, volume)
            if (File(source).isFile) audio.setDataSource(source)
            else {
                val asset = source.removePrefix("assets/").takeIf { it.startsWith("sounds/") } ?: "sounds/order_recieve_ringtone.mp3"
                val file = File(cacheDir, "order_alert_" + asset.substringAfterLast('/'))
                assets.open("flutter_assets/assets/$asset").use { input -> file.outputStream().use { input.copyTo(it) } }
                audio.setDataSource(file.absolutePath)
            }
            audio.setOnPreparedListener { it.start() }
            audio.setOnErrorListener { _, _, _ ->
                player?.release(); player = null
                if (!fallback) play("sounds/order_recieve_ringtone.mp3", volume, true) else stopSelf()
                true
            }
            audio.prepareAsync()
        } catch (_: Exception) {
            player?.release(); player = null
            if (!fallback) play("sounds/order_recieve_ringtone.mp3", volume, true) else stopSelf()
        }
    }
    override fun onDestroy() {
        activeOrderKey = null
        handler.removeCallbacksAndMessages(null)
        player?.release(); player = null
        super.onDestroy()
    }
}
