package com.apnapos.app

import org.junit.Assert.*
import org.junit.Test

class OrderAlertPolicyTest {
    private val incoming = mapOf("type" to "whatsapp_order_request", "orderId" to "order-2",
        "orderSource" to "storefront", "orderType" to "dineIn", "tableNumber" to "T02")

    @Test fun incomingQrAndWhatsappOrdersQualify() {
        assertTrue(OrderAlertPolicy.isIncoming(incoming))
        assertTrue(OrderAlertPolicy.isIncoming(incoming + ("orderSource" to "whatsapp")))
        assertTrue(OrderAlertPolicy.isIncoming(incoming + ("type" to "qr_order")))
    }

    @Test fun localPosOrdersNeverTakeOverTheScreen() {
        for (source in listOf("pos", "counter", "local")) {
            assertFalse(OrderAlertPolicy.isIncoming(incoming + ("orderSource" to source)))
        }
    }

    @Test fun handledOrdersStopInsteadOfReopening() {
        for (status in listOf("accepted", "preparing", "ready", "rejected", "completed", "cancelled")) {
            val payload = incoming + ("status" to status)
            assertTrue(OrderAlertPolicy.isHandled(payload))
            assertFalse(OrderAlertPolicy.isIncoming(payload))
        }
    }

    @Test fun chatAndPaymentMessagesWithAnOrderReferenceAreNotIncomingOrders() {
        for (type in listOf("whatsapp_message", "payment_received", "campaign_message")) {
            val payload = incoming + mapOf("type" to type, "status" to "delivered")
            assertFalse(OrderAlertPolicy.isIncoming(payload))
            assertFalse(OrderAlertPolicy.isHandled(payload))
        }
    }

    @Test fun identityIsRequiredAndOrderNumberIsAValidFallback() {
        assertFalse(OrderAlertPolicy.isIncoming(incoming - "orderId"))
        assertTrue(OrderAlertPolicy.isIncoming((incoming - "orderId") + ("orderNumber" to "ORD-2")))
        assertEquals(OrderAlertPolicy.notificationId(incoming), OrderAlertPolicy.notificationId(incoming + ("totalAmount" to "337")))
    }

    @Test fun acceptedActionsAndDismissEventsAreNeverNewOrders() {
        assertTrue(OrderAlertPolicy.isHandled(incoming + ("action" to "accepted")))
        assertTrue(OrderAlertPolicy.isHandled(incoming + ("type" to "whatsapp_order_dismiss")))
        assertFalse(OrderAlertPolicy.isIncoming(incoming + ("action" to "rejected")))
    }
}
