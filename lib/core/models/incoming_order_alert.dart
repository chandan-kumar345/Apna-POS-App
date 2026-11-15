import 'incoming_order_payload.dart';

/// Shared incoming-vs-handled decision for foreground, background and launch.
class IncomingOrderAlert {
  IncomingOrderAlert(Map<String, dynamic> payload)
    : data = IncomingOrderPayload.normalize(payload);
  final Map<String, dynamic> data;
  String _text(String key) => (data[key] ?? '').toString().trim().toLowerCase();
  String get orderId =>
      (data['orderId'] ?? data['_id'] ?? data['id'] ?? '').toString().trim();
  String get orderNumber => (data['orderNumber'] ?? '').toString().trim();
  bool get isChat =>
      const [
        'whatsapp_message',
        'whatsappmessage',
        'chat_message',
      ].contains(_text('type')) ||
      const ['whatsapp_chat', 'whatsapp_message'].contains(_text('entityType'));
  String get _source =>
      _text('orderSource').isEmpty ? _text('source') : _text('orderSource');
  bool get isLocal =>
      const ['pos', 'counter', 'local'].contains(_source) ||
      _text('type') == 'kot_printed';
  bool get isExternal => const [
    'whatsapp',
    'profile',
    'storefront',
    'online',
    'qr',
    'table',
  ].contains(_source);
  bool get _incomingType =>
      const [
        'whatsapp_order_request',
        'whatsapp_new_order',
        'whatsapp_order',
        'new_order',
        'neworder',
        'order_created',
        'order',
        'table_order',
        'qr_order',
      ].contains(_text('type')) ||
      (_text('type').isEmpty &&
          (isExternal ||
              const ['whatsapp_order', 'order'].contains(_text('entityType'))));
  bool get isOrder =>
      !isChat &&
      (orderId.isNotEmpty || orderNumber.isNotEmpty) &&
      (_incomingType ||
          _text('type').startsWith('order_') ||
          _text('type').startsWith('whatsapp_order_') ||
          const ['whatsapp_order', 'order'].contains(_text('entityType')));
  bool get isHandled =>
      isOrder &&
      (const [
            'accepted',
            'confirmed',
            'preparing',
            'ready',
            'completed',
            'cancelled',
            'canceled',
            'rejected',
            'delivered',
            'settled',
            'paid',
            'dismissed',
            'expired',
          ].contains(
            _text('status').isEmpty ? _text('orderStatus') : _text('status'),
          ) ||
          const [
            'accepted',
            'rejected',
            'dismissed',
            'handled',
            'cancelled',
            'canceled',
          ].contains(_text('action')) ||
          _text('type').contains('dismiss'));
  bool get isIncoming =>
      isOrder &&
      _incomingType &&
      !isLocal &&
      !isHandled &&
      _text('isKot') != 'true' &&
      (isExternal || !_text('paymentMethod').contains('kot'));
}
