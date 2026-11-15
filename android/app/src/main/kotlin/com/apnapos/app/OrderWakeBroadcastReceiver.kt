package com.apnapos.app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingReceiver
import java.util.concurrent.Executors

/** Native background delivery followed by FlutterFire's ordinary message path. */
class OrderWakeBroadcastReceiver : FlutterFirebaseMessagingReceiver() {
    companion object {
        private const val FORWARDED = "com.apnapos.app.internal.ORDER_FORWARDED"
        private val executor = Executors.newSingleThreadExecutor()
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.getBooleanExtra(FORWARDED, false)) {
            super.onReceive(context, intent)
            return
        }
        val data = intent.extras?.let { RemoteMessage(it).data }.orEmpty()
        val normalized = IncomingOrderAlertDispatcher.normalize(data)
        if (!OrderAlertPolicy.isIncoming(normalized) && !OrderAlertPolicy.isHandled(normalized)) {
            super.onReceive(context, intent)
            return
        }
        // The explicit re-entry gets its own Android PendingResult. Calling
        // goAsync() twice in one invocation would break the plugin's receiver.
        val pending = goAsync()
        val application = context.applicationContext
        executor.execute {
            try {
                val handled = IncomingOrderAlertDispatcher.dispatch(application, normalized)
                forward(application, intent, handled)
            } catch (error: Exception) {
                Log.e("ApnaOrderAlert", "Native receiver dispatch failed", error)
                forward(application, intent, false)
            } finally { pending.finish() }
        }
    }

    private fun forward(context: Context, original: Intent, handled: Boolean) {
        context.sendBroadcast(Intent(original).apply {
            component = ComponentName(context, OrderWakeBroadcastReceiver::class.java)
            putExtra(FORWARDED, true)
            putExtra("apna_native_order_handled", handled.toString())
        })
    }
}
