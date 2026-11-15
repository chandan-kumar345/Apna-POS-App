package com.apnapos.app

import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/** Google SDK service delivery and Flutter's receiver share one native dispatcher. */
class ApnaPosFirebaseMessagingService : FlutterFirebaseMessagingService() {
    companion object {
        const val ORDER_CHANNEL_ID = "apna_pos_orders_native_audio_v2"
        const val ORDER_CHANNEL_NAME = "Incoming customer orders"
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        IncomingOrderAlertDispatcher.dispatch(applicationContext, remoteMessage.data)
        super.onMessageReceived(remoteMessage)
    }
}
