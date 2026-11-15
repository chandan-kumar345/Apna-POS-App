package com.apnapos.app

/** Pure classification shared by both native Firebase entry points. */
internal object OrderAlertPolicy {
    private val incomingTypes = setOf("whatsapp_order_request", "whatsapp_new_order", "whatsapp_order",
        "new_order", "neworder", "order_created", "order", "table_order", "qr_order")
    private val handledStatuses = setOf("preparing", "ready", "completed", "cancelled", "canceled",
        "rejected", "accepted", "confirmed", "delivered", "settled", "paid")
    private val localSources = setOf("pos", "counter", "local")

    fun key(data: Map<String, String>): String? =
        data["orderId"]?.takeIf { it.isNotBlank() }
            ?: data["orderNumber"]?.takeIf { it.isNotBlank() }

    fun isHandled(data: Map<String, String>): Boolean {
        val type = data["type"].orEmpty().lowercase()
        val status = (data["status"] ?: data["orderStatus"]).orEmpty().lowercase()
        val action = data["action"].orEmpty().lowercase()
        val entity = data["entityType"].orEmpty().lowercase()
        val source = (data["orderSource"] ?: data["source"]).orEmpty().lowercase()
        val orderEnvelope = type in incomingTypes || type.startsWith("order_") ||
            type.startsWith("whatsapp_order_") || entity in setOf("order", "whatsapp_order") ||
            (type.isBlank() && source in setOf("whatsapp", "storefront", "online", "profile", "qr", "table"))
        return key(data) != null && orderEnvelope && (status in handledStatuses ||
            action in setOf("accepted", "rejected", "dismissed", "cancelled", "handled") ||
            type.contains("dismiss"))
    }

    fun isIncoming(data: Map<String, String>): Boolean {
        if (key(data) == null || isHandled(data)) return false
        val source = (data["orderSource"] ?: data["source"]).orEmpty().lowercase()
        if (source in localSources) return false
        val type = data["type"].orEmpty().lowercase()
        if (type.isNotBlank()) return type in incomingTypes
        val entity = data["entityType"].orEmpty().lowercase()
        return entity in setOf("order", "whatsapp_order") ||
            source in setOf("whatsapp", "storefront", "online", "profile", "qr", "table")
    }

    fun notificationId(data: Map<String, String>): Int = key(data).orEmpty().hashCode() and 0x7fffffff
}
