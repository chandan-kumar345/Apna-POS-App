import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../network/api_endpoints.dart';
import '../models/table_model.dart';
import '../models/order_model.dart';
import '../security/secure_storage_service.dart';
import 'local_notification_service.dart';
import 'sound_service.dart';
import '../../features/chat/meta_whatsapp_chat_screen.dart';
import '../../features/notifications/models/notification_model.dart';
import '../../features/orders/whatsapp_order_action_dialog.dart';

typedef TableUpdateCallback = void Function(TableModel table);
typedef TablesBatchUpdateCallback = void Function(List<TableModel> tables);
typedef TableCreateCallback = void Function(TableModel table);
typedef TableDeleteCallback = void Function(String tableId);
typedef SocketReconnectCallback = void Function();
typedef OrderSettledCallback = void Function(Map<String, dynamic> data);
typedef OrderUpdatedCallback = void Function(Map<String, dynamic> data);
typedef OrderCreatedCallback = void Function(OrderModel order);
typedef OrderDeletedCallback = void Function(Map<String, dynamic> data);
typedef SubscriptionUpdateCallback = void Function(Map<String, dynamic> data);
typedef WhatsAppMessageCallback = void Function(Map<String, dynamic> data);
typedef WhatsAppChatUpdateCallback = void Function(Map<String, dynamic> data);
typedef WhatsAppMessageUpdatedCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _currentBusinessId;
  String? _currentToken;
  bool _isConnecting = false;

  final SecureStorageService _storage = SecureStorageService();
  bool? _lastHandledSubscriptionState;
  DateTime? _lastHandledSubscriptionTime;

  // Callbacks registered by DatabaseService
  TableUpdateCallback? onTableUpdated;
  TablesBatchUpdateCallback? onTablesBatchUpdated;
  TableCreateCallback? onTableCreated;
  TableDeleteCallback? onTableDeleted;
  SocketReconnectCallback? onReconnected;
  OrderSettledCallback? onOrderSettled;
  OrderUpdatedCallback? onOrderUpdated;
  OrderCreatedCallback? onOrderCreated;
  OrderDeletedCallback? onOrderDeleted;
  SubscriptionUpdateCallback? onSubscriptionUpdated;
  WhatsAppMessageCallback? onWhatsAppMessage;
  WhatsAppChatUpdateCallback? onWhatsAppChatUpdated;
  WhatsAppMessageUpdatedCallback? onWhatsAppMessageUpdated;

  bool get isConnected => _socket?.connected == true;

  /// Clean server origin URL for Socket.IO connection (strips /api/v1)
  String get _socketBaseUrl {
    final baseUrl = ApiEndpoints.baseUrl;
    var clean = baseUrl.trim();
    if (clean.endsWith('/api/v1')) {
      clean = clean.substring(0, clean.length - 7);
    } else if (clean.endsWith('/api/v1/')) {
      clean = clean.substring(0, clean.length - 8);
    }
    if (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  /// Initialize and connect socket client
  Future<void> connect({String? businessId, String? token}) async {
    if (_isConnecting) return;

    try {
      _isConnecting = true;

      // Extract stored token / businessId if not provided
      final activeToken = token ?? _currentToken ?? await _storage.getAccessToken();
      final activeBusinessId = businessId ?? _currentBusinessId ?? await _storage.getBusinessId();

      _currentToken = activeToken;
      _currentBusinessId = activeBusinessId;

      final serverUrl = _socketBaseUrl;
      debugPrint('[SocketService] Connecting to Socket server: $serverUrl (Business: $activeBusinessId)');

      // If existing socket is connected to the same server, just rejoin room
      if (_socket != null && _socket!.connected) {
        if (activeBusinessId != null && activeBusinessId.isNotEmpty) {
          joinBusinessRoom(activeBusinessId);
        }
        _isConnecting = false;
        return;
      }

      // Dispose any stale socket instance
      _socket?.dispose();

      final options = io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setTimeout(15000)
          .setAuth({
            if (activeToken != null && activeToken.isNotEmpty) 'token': activeToken,
            if (activeBusinessId != null && activeBusinessId.isNotEmpty) 'businessId': activeBusinessId,
          })
          .setQuery({
            if (activeToken != null && activeToken.isNotEmpty) 'token': activeToken,
            if (activeBusinessId != null && activeBusinessId.isNotEmpty) 'businessId': activeBusinessId,
          })
          .build();

      final socket = io.io(serverUrl, options);
      _socket = socket;

      // Setup Lifecycle Event Listeners
      socket.onConnect((_) {
        debugPrint('[SocketService] Connected successfully to Socket.IO server: $serverUrl');
        joinAllRelevantRooms();
      });

      socket.onReconnect((_) {
        debugPrint('[SocketService] Reconnected to Socket.IO server. Triggering room rejoin and resync...');
        joinAllRelevantRooms();
        // Notify listeners of reconnection so they can reconcile any missed state
        onReconnected?.call();
      });

      socket.onDisconnect((reason) {
        debugPrint('[SocketService] Disconnected from Socket.IO server: $reason');
      });

      socket.onConnectError((err) {
        debugPrint('[SocketService] Connection error: $err');
      });

      socket.onError((err) {
        debugPrint('[SocketService] Socket error: $err');
      });

      // --- REAL-TIME BUSINESS EVENT HANDLERS ---
      
      // Single table updated (status, order total, occupancy, etc.)
      socket.on('table:updated', (data) => _handleSingleTableUpdate(data));

      // Batch tables updated (e.g., table shifting or bulk count sync)
      socket.on('tables:batch_updated', (data) => _handleBatchTablesUpdate(data));

      // Table created
      socket.on('table:created', (data) => _handleTableCreated(data));

      // Table deleted
      socket.on('table:deleted', (data) => _handleTableDeleted(data));

      // Order created, settled & updated events
      socket.on('order:created', (data) => _handleOrderCreated(data));
      socket.on('order:settled', (data) => _handleOrderSettled(data));
      socket.on('order:updated', (data) => _handleOrderUpdated(data));
      socket.on('order:deleted', (data) => _handleOrderDeleted(data));

      // Subscription updated events (real-time toggle from MongoDB Compass or API)
      socket.on('subscription:updated', (data) => _handleSubscriptionUpdated(data));

      // Instant push notification delivery (<50ms)
      socket.on('notification:new', (data) => _handleNotificationNew(data));

      // Real-time WhatsApp messages & chat updates (<50ms)
      socket.on('whatsapp:message', (data) => _handleWhatsAppMessage(data));
      socket.on('whatsapp:chat_updated', (data) => _handleWhatsAppChatUpdated(data));
      socket.on('whatsapp:message:updated', (data) => _handleWhatsAppMessageUpdated(data));
            socket.on('whatsapp:order:request', (data) => _handleWhatsAppOrderRequest(data));
      socket.on('whatsapp:order:dismiss', (data) => _handleWhatsAppOrderDismiss(data));
      socket.on('whatsapp:order:accepted', (data) => _handleWhatsAppOrderAccepted(data));
      socket.on('whatsapp:order:rejected', (data) => _handleWhatsAppOrderRejected(data));

      socket.connect();
    } catch (e) {
      debugPrint('[SocketService] Failed to initialize socket: $e');
    } finally {
      _isConnecting = false;
    }
  }

  /// Explicitly join business tenant room
  void joinBusinessRoom(String businessId) {
    _currentBusinessId = businessId;
    if (_socket != null && _socket!.connected) {
      debugPrint('[SocketService] Joining room for business: $businessId');
      _socket!.emit('join_business', {'businessId': businessId});
    }
  }

  /// Join all applicable tenant, user, and POS rooms for 100% real-time notification reliability
  Future<void> joinAllRelevantRooms({String? businessId, String? userId}) async {
    try {
      final activeBiz = businessId ?? _currentBusinessId ?? await _storage.getBusinessId();
      final activeUser = userId ?? await _storage.getUserId();

      if (_socket != null && _socket!.connected) {
        if (activeBiz != null && activeBiz.isNotEmpty) {
          debugPrint('[SocketService] Joining room for business: $activeBiz');
          _socket!.emit('join_business', {'businessId': activeBiz});
        }
        if (activeUser != null && activeUser.isNotEmpty && activeUser != activeBiz) {
          debugPrint('[SocketService] Joining room for user: $activeUser');
          _socket!.emit('join_business', {'businessId': activeUser});
        }
        _socket!.emit('join_business', {'businessId': 'rest_001'});
        _socket!.emit('join_business', {'businessId': 'default'});
      }
    } catch (e) {
      debugPrint('[SocketService] Error joining rooms: $e');
    }
  }

  /// Update business ID and rejoin room if changed
  void updateBusinessId(String businessId) {
    if (businessId.trim().isEmpty) return;
    _currentBusinessId = businessId.trim();
    if (_socket != null && _socket!.connected) {
      joinAllRelevantRooms(businessId: _currentBusinessId);
    }
  }

  void _handleSingleTableUpdate(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      final tableMap = rawMap['table'] is Map
          ? Map<String, dynamic>.from(rawMap['table'] as Map)
          : rawMap;

      if (tableMap.isNotEmpty) {
        final tableModel = TableModel.fromJson(tableMap);
        debugPrint('[SocketService] Received table update for: ${tableModel.name} (Status: ${tableModel.status.name})');
        onTableUpdated?.call(tableModel);
      }
    } catch (e) {
      debugPrint('[SocketService] Error processing table:updated event: $e');
    }
  }

  void _handleBatchTablesUpdate(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      final rawList = rawMap['tables'] as List<dynamic>?;
      if (rawList != null && rawList.isNotEmpty) {
        final tables = rawList
            .whereType<Map>()
            .map((m) => TableModel.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        debugPrint('[SocketService] Received batch tables update for ${tables.length} tables');
        onTablesBatchUpdated?.call(tables);
      }
    } catch (e) {
      debugPrint('[SocketService] Error processing tables:batch_updated event: $e');
    }
  }

  void _handleTableCreated(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      if (rawMap['tables'] is List) {
        final rawList = rawMap['tables'] as List<dynamic>;
        for (final item in rawList.whereType<Map>()) {
          final t = TableModel.fromJson(Map<String, dynamic>.from(item));
          onTableCreated?.call(t);
        }
      } else if (rawMap['table'] is Map) {
        final t = TableModel.fromJson(Map<String, dynamic>.from(rawMap['table'] as Map));
        onTableCreated?.call(t);
      }
    } catch (e) {
      debugPrint('[SocketService] Error processing table:created event: $e');
    }
  }

  void _handleTableDeleted(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      final tableId = rawMap['tableId']?.toString() ?? rawMap['id']?.toString() ?? '';
      if (tableId.isNotEmpty) {
        debugPrint('[SocketService] Received table:deleted event for table ID: $tableId');
        onTableDeleted?.call(tableId);
      }
    } catch (e) {
      debugPrint('[SocketService] Error processing table:deleted event: $e');
    }
  }

  void _handleOrderSettled(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      debugPrint('[SocketService] Received order:settled event for: ${rawMap['orderNumber'] ?? rawMap['orderId']} (Table: ${rawMap['tableNumber']})');
      onOrderSettled?.call(rawMap);
    } catch (e) {
      debugPrint('[SocketService] Error processing order:settled event: $e');
    }
  }

    void _handleOrderUpdated(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      final orderId = (rawMap['orderId'] ?? rawMap['_id'] ?? rawMap['id'] ?? '').toString();
      final orderNumber = rawMap['orderNumber']?.toString();
      final status = rawMap['status']?.toString().toLowerCase();

      debugPrint('[SocketService] Received order:updated event for: ${orderNumber ?? orderId} (Status: $status)');

      // If order transitioned out of pending, dismiss modal and stop ringtone on all devices
      if (status != null && status != 'pending') {
        SoundService.stopOrderRingtone();
        WhatsAppOrderActionDialog.dismissIfShowing(
          orderId: orderId,
          orderNumber: orderNumber,
          action: status,
        );
        if (orderId.isNotEmpty) {
          LocalNotificationService().cancelNotificationForOrder(orderId);
        }
      }

      onOrderUpdated?.call(rawMap);
    } catch (e) {
      debugPrint('[SocketService] Error processing order:updated event: $e');
    }
  }

  void _handleOrderDeleted(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      debugPrint('[SocketService] Received order:deleted event for: ${rawMap['orderNumber'] ?? rawMap['orderId']}');
      onOrderDeleted?.call(rawMap);
    } catch (e) {
      debugPrint('[SocketService] Error processing order:deleted event: $e');
    }
  }

  void _handleOrderCreated(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      final orderMap = rawMap['order'] is Map ? Map<String, dynamic>.from(rawMap['order'] as Map) : rawMap;
      if (orderMap.isNotEmpty) {
        final orderModel = OrderModel.fromJson(orderMap);
        debugPrint('[SocketService] 🛒 Received order:created event for: #${orderModel.orderNumber} (Status: ${orderModel.status.name})');
        onOrderCreated?.call(orderModel);

        // If order is PENDING, trigger instant sound, notification, and Accept / Reject popup dialog!
        if (orderModel.status == OrderStatus.pending) {
          final isWhatsApp = (orderModel.orderSource?.toLowerCase() == 'whatsapp') ||
              rawMap['source']?.toString().toLowerCase() == 'whatsapp' ||
              rawMap['type'] == 'whatsapp_order_request' ||
              rawMap['type'] == 'whatsapp_new_order';

          // 1. Play incoming order ringtone
          SoundService.playOrderRingtone();

          // 2. High priority notification in native notification bar
          LocalNotificationService().showPushNotification(
            id: orderModel.id.isNotEmpty ? orderModel.id.hashCode.abs().remainder(100000) : 0,
            title: isWhatsApp
                ? '🔔 New WhatsApp Order: #${orderModel.orderNumber}'
                : '🔔 New Order Received: #${orderModel.orderNumber}',
            body: '${orderModel.customerName ?? "Customer"} ordered ₹${orderModel.totalAmount.toStringAsFixed(0)} • Tap to Accept/Reject',
            payload: jsonEncode({
              'type': 'whatsapp_order_request',
              'orderId': orderModel.id,
              'orderNumber': orderModel.orderNumber,
              'customerPhone': orderModel.customerPhone,
              'customerName': orderModel.customerName,
              'totalAmount': orderModel.totalAmount.toString(),
              'orderType': orderModel.orderType.name,
              'deliveryAddress': orderModel.deliveryAddress,
              'items': orderModel.items.map((i) => i.toJson()).toList(),
            }),
            type: NotificationType.whatsappOrderRequest,
            channelId: 'apna_pos_whatsapp_orders_v1',
            playSound: true,
          );

          // 3. Trigger interactive Accept / Reject screen modal
          LocalNotificationService.handlePayloadDirectly({
            'type': 'whatsapp_order_request',
            'orderId': orderModel.id,
            'orderNumber': orderModel.orderNumber,
            'customerPhone': orderModel.customerPhone,
            'customerName': orderModel.customerName,
            'totalAmount': orderModel.totalAmount.toString(),
            'orderType': orderModel.orderType.name,
            'deliveryAddress': orderModel.deliveryAddress,
            'items': orderModel.items.map((i) => i.toJson()).toList(),
          });
        }
      }
    } catch (e) {
      debugPrint('[SocketService] Error processing order:created event: $e');
    }
  }

  void _handleSubscriptionUpdated(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};

      bool? newState;
      if (rawMap['isSubscriptionActive'] != null) {
        newState = rawMap['isSubscriptionActive'] == true;
      } else if (rawMap['isActive'] != null) {
        newState = rawMap['isActive'] == true;
      } else if (rawMap['isSubscribed'] != null) {
        newState = rawMap['isSubscribed'] == true;
      } else if (rawMap['status'] != null) {
        newState = rawMap['status'] == 'active';
      }

      final now = DateTime.now();
      if (_lastHandledSubscriptionState == newState &&
          _lastHandledSubscriptionTime != null &&
          now.difference(_lastHandledSubscriptionTime!).inMilliseconds < 1500) {
        // Drop identical duplicate subscription events within 1.5s
        return;
      }

      _lastHandledSubscriptionState = newState;
      _lastHandledSubscriptionTime = now;

      debugPrint('[SocketService] Received subscription:updated event: $rawMap');
      onSubscriptionUpdated?.call(rawMap);
    } catch (e) {
      debugPrint('[SocketService] Error processing subscription:updated event: $e');
    }
  }

  void _handleNotificationNew(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      final notifData = rawMap['notification'] is Map
          ? Map<String, dynamic>.from(rawMap['notification'] as Map)
          : rawMap;
      if (notifData.isEmpty) return;

      final type = notifData['type']?.toString() ?? 'system';
      final title = notifData['title']?.toString() ?? 'Notification';
      final message = notifData['message']?.toString() ?? '';
      final metadata = notifData['metadata'] is Map
          ? Map<String, dynamic>.from(notifData['metadata'] as Map)
          : <String, dynamic>{};

      // Suppress new order push notifications
      if (type == 'new_order' || type == 'newOrder') return;

      debugPrint('[SocketService] 🔔 Instant notification received via socket: "$title"');

      LocalNotificationService().showPushNotification(
        title: title,
        body: message,
        payload: jsonEncode(notifData),
        type: LocalNotificationService().resolveNotificationType(type),
        entityType: notifData['entityType']?.toString(),
        entityId: notifData['entityId']?.toString(),
        metadata: metadata,
        playSound: true,
      );
    } catch (e) {
      debugPrint('[SocketService] Error handling notification:new: $e');
    }
  }

  void _handleWhatsAppMessage(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      debugPrint('[SocketService] 💬 WhatsApp message event received via socket');

      final msgMap = rawMap['message'] is Map ? Map<String, dynamic>.from(rawMap['message'] as Map) : null;
      final chatMap = rawMap['chat'] is Map ? Map<String, dynamic>.from(rawMap['chat'] as Map) : null;

      // 1. Forward directly to in-app stream listeners for 0ms chat screen rendering
      onWhatsAppMessage?.call(rawMap);

      // 2. Trigger high-priority push notification for incoming WhatsApp messages
      if (msgMap != null && (msgMap['direction']?.toString().toUpperCase() == 'INCOMING')) {
        final chatId = msgMap['chatId']?.toString() ?? chatMap?['_id']?.toString() ?? chatMap?['id']?.toString() ?? '';
        final customerPhone = msgMap['customerPhone']?.toString() ?? chatMap?['customerPhone']?.toString() ?? '';
        final customerName = chatMap?['customerName']?.toString() ?? '';
        final text = msgMap['text']?.toString() ?? '';
        final messageType = msgMap['messageType']?.toString() ?? 'text';
        final isImage = messageType == 'image' || (msgMap['mediaUrl'] != null && msgMap['mediaUrl'].toString().isNotEmpty);

        final senderDisplay = customerName.isNotEmpty && !customerName.startsWith('Customer ')
            ? customerName
            : (customerPhone.startsWith('91') && customerPhone.length == 12
                ? '+91 ${customerPhone.substring(2, 7)} ${customerPhone.substring(7)}'
                : customerPhone);

        final body = isImage
            ? (text.isNotEmpty && text != '[Photo]' ? '📷 $text' : '📷 Photo')
            : (text.isNotEmpty ? text : 'New WhatsApp message');

        final isCurrentlyViewingChat = MetaWhatsAppChatScreen.activeChatId != null &&
            MetaWhatsAppChatScreen.activeChatId == chatId;

        if (isCurrentlyViewingChat) {
          // Play in-chat audio chime without blocking screen
          SoundService.playNotificationSound();
        } else {
          // Trigger instant floating push notification banner with sound and vibration
          LocalNotificationService().showPushNotification(
            title: 'WhatsApp: $senderDisplay',
            body: body,
            payload: jsonEncode({
              'type': 'whatsapp_message',
              'entityType': 'whatsapp_chat',
              'entityId': chatId,
              'metadata': {
                'chatId': chatId,
                'customerPhone': customerPhone,
                'customerName': customerName,
                'messageType': messageType,
              },
            }),
            type: NotificationType.whatsappMessage,
            entityType: 'whatsapp_chat',
            entityId: chatId,
            metadata: {
              'chatId': chatId,
              'customerPhone': customerPhone,
              'customerName': customerName,
            },
            playSound: true,
          );
        }
      }
    } catch (e) {
      debugPrint('[SocketService] Error processing whatsapp:message: $e');
    }
  }

  void _handleWhatsAppChatUpdated(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      debugPrint('[SocketService] 💬 WhatsApp chat update event received via socket');
      onWhatsAppChatUpdated?.call(rawMap);
    } catch (e) {
      debugPrint('[SocketService] Error processing whatsapp:chat_updated: $e');
    }
  }

  void _handleWhatsAppMessageUpdated(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      debugPrint('[SocketService] 💬 WhatsApp media update event received via socket');
      onWhatsAppMessageUpdated?.call(rawMap);
    } catch (e) {
      debugPrint('[SocketService] Error processing whatsapp:message:updated: $e');
    }
  }

  void _handleWhatsAppOrderRequest(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      debugPrint('[SocketService] 🔔 Urgent WhatsApp order request received via socket');

      final orderData = rawMap['order'] is Map ? Map<String, dynamic>.from(rawMap['order'] as Map) : rawMap;
      final orderId = orderData['_id']?.toString() ?? orderData['id']?.toString() ?? '';
      final orderNumber = orderData['orderNumber']?.toString() ?? '';
      final customerPhone = rawMap['customerPhone']?.toString() ?? orderData['customerPhone']?.toString() ?? '';
      final customerName = rawMap['customerName']?.toString() ?? orderData['customerName']?.toString() ?? 'Customer';
      final totalAmount = double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0;
      final orderType = orderData['orderType']?.toString() ?? 'takeaway';
      final deliveryAddress = orderData['deliveryAddress']?.toString() ?? '';
      final items = orderData['items'];

      // 1. Play loud notification chime
      SoundService.playNotificationSound();

      // 2. Trigger high-priority floating push notification in native notification tray
      LocalNotificationService().showPushNotification(
        id: orderId.isNotEmpty ? orderId.hashCode.abs().remainder(100000) : 0,
        title: '🔔 New WhatsApp Order: #$orderNumber',
        body: '$customerName ordered ₹${totalAmount.toStringAsFixed(0)} • Tap to Accept/Reject',
        payload: jsonEncode({
          'type': 'whatsapp_order_request',
          'orderId': orderId,
          'orderNumber': orderNumber,
          'customerPhone': customerPhone,
          'customerName': customerName,
          'totalAmount': totalAmount.toString(),
          'orderType': orderType,
          'deliveryAddress': deliveryAddress,
          'items': items,
        }),
        type: NotificationType.whatsappOrderRequest,
        channelId: 'apna_pos_whatsapp_orders_v1',
        playSound: true,
      );

      // 3. Resiliently trigger the incoming WhatsApp order action dialog
      LocalNotificationService.handlePayloadDirectly({
        'type': 'whatsapp_order_request',
        'orderId': orderId,
        'orderNumber': orderNumber,
        'customerPhone': customerPhone,
        'customerName': customerName,
        'totalAmount': totalAmount.toString(),
        'orderType': orderType,
        'deliveryAddress': deliveryAddress,
        'items': items,
      });
    } catch (e) {
      debugPrint('[SocketService] Error processing whatsapp:order:request: $e');
    }
  }

  void _handleWhatsAppOrderDismiss(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      final orderId = (rawMap['orderId'] ?? rawMap['id'] ?? rawMap['_id'] ?? '').toString();
      final orderNumber = rawMap['orderNumber']?.toString();
      final action = rawMap['action']?.toString() ?? 'handled';
      final reason = rawMap['reason']?.toString();

      debugPrint('[SocketService] 🔔 Received whatsapp:order:dismiss for order: $orderId (#$orderNumber, Action: $action)');

      // 1. Immediately halt incoming order ringtone on this device
      SoundService.stopOrderRingtone();

      // 2. Programmatically close the dialog if currently visible on this device
      WhatsAppOrderActionDialog.dismissIfShowing(
        orderId: orderId,
        orderNumber: orderNumber,
        action: action,
        reason: reason,
      );

      // 3. Clear any lingering system push notification for this order
      if (orderId.isNotEmpty) {
        LocalNotificationService().cancelNotificationForOrder(orderId);
      }
    } catch (e) {
      debugPrint('[SocketService] Error processing whatsapp:order:dismiss: $e');
    }
  }

  void _handleWhatsAppOrderAccepted(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      final orderMap = rawMap['order'] is Map ? Map<String, dynamic>.from(rawMap['order'] as Map) : rawMap;
      final orderId = (orderMap['_id'] ?? orderMap['id'] ?? rawMap['orderId'] ?? '').toString();
      final orderNumber = (orderMap['orderNumber'] ?? rawMap['orderNumber'])?.toString();

      debugPrint('[SocketService] 🔔 Received whatsapp:order:accepted for order: $orderId (#$orderNumber)');
      SoundService.stopOrderRingtone();
      WhatsAppOrderActionDialog.dismissIfShowing(
        orderId: orderId,
        orderNumber: orderNumber,
        action: 'accepted',
      );
      if (orderId.isNotEmpty) {
        LocalNotificationService().cancelNotificationForOrder(orderId);
      }
    } catch (e) {
      debugPrint('[SocketService] Error processing whatsapp:order:accepted: $e');
    }
  }

  void _handleWhatsAppOrderRejected(dynamic data) {
    try {
      if (data == null) return;
      final Map<String, dynamic> rawMap = data is Map ? Map<String, dynamic>.from(data) : {};
      final orderMap = rawMap['order'] is Map ? Map<String, dynamic>.from(rawMap['order'] as Map) : rawMap;
      final orderId = (orderMap['_id'] ?? orderMap['id'] ?? rawMap['orderId'] ?? '').toString();
      final orderNumber = (orderMap['orderNumber'] ?? rawMap['orderNumber'])?.toString();
      final reason = rawMap['reason']?.toString();

      debugPrint('[SocketService] 🔔 Received whatsapp:order:rejected for order: $orderId (#$orderNumber)');
      SoundService.stopOrderRingtone();
      WhatsAppOrderActionDialog.dismissIfShowing(
        orderId: orderId,
        orderNumber: orderNumber,
        action: 'rejected',
        reason: reason,
      );
      if (orderId.isNotEmpty) {
        LocalNotificationService().cancelNotificationForOrder(orderId);
      }
    } catch (e) {
      debugPrint('[SocketService] Error processing whatsapp:order:rejected: $e');
    }
  }

  /// Broadcast interactive order modal action (accept/reject) to all other devices in real-time (<15ms)
  void emitOrderModalAction({
    required String orderId,
    String? orderNumber,
    required String action,
    int? prepTimeMinutes,
    String? reason,
  }) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('order:modal_action', {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'action': action,
        'prepTimeMinutes': prepTimeMinutes,
        'reason': reason,
        'businessId': _currentBusinessId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      debugPrint('[SocketService] ⚡ Emitted order:modal_action for order: $orderId ($action)');
    }
  }

  /// Disconnect socket cleanly (e.g. on user logout)
  void disconnect() {
    try {
      if (_socket != null) {
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
      }
      _currentBusinessId = null;
      _currentToken = null;
      debugPrint('[SocketService] Socket disconnected and cleaned up');
    } catch (e) {
      debugPrint('[SocketService] Error during disconnect: $e');
    }
  }
}
