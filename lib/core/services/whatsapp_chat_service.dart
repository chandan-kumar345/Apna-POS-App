import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class WhatsAppChatModel {
  final String id;
  final String customerPhone;
  final String customerName;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastMessageDirection; // 'INCOMING' | 'OUTGOING'
  final int unreadCount;
  final String status;
  final String phoneNumberId;

  const WhatsAppChatModel({
    required this.id,
    required this.customerPhone,
    required this.customerName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastMessageDirection,
    this.unreadCount = 0,
    this.status = 'ACTIVE',
    this.phoneNumberId = '',
  });

  factory WhatsAppChatModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is DateTime) return d;
      return DateTime.tryParse(d.toString()) ?? DateTime.now();
    }

    return WhatsAppChatModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
      lastMessage: json['lastMessage']?.toString() ?? '',
      lastMessageAt: parseDate(json['lastMessageAt']),
      lastMessageDirection: (json['lastMessageDirection']?.toString() ?? 'INCOMING').toUpperCase(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'ACTIVE',
      phoneNumberId: json['phoneNumberId']?.toString() ?? '',
    );
  }

  String get displayName {
    if (customerName.isNotEmpty && !customerName.startsWith('Customer ')) {
      return customerName;
    }
    if (customerPhone.isNotEmpty) {
      if (customerPhone.startsWith('91') && customerPhone.length == 12) {
        return '+91 ${customerPhone.substring(2, 7)} ${customerPhone.substring(7)}';
      }
      return customerPhone;
    }
    return 'Customer';
  }

  String get avatarInitials {
    if (customerName.isNotEmpty && !customerName.startsWith('Customer ')) {
      final parts = customerName.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }
    if (customerPhone.isNotEmpty) {
      return customerPhone.substring(customerPhone.length - 2).toUpperCase();
    }
    return 'WA';
  }
}

class WhatsAppMessageModel {
  final String id;
  final String chatId;
  final String customerPhone;
  final String direction; // 'INCOMING' | 'OUTGOING'
  final String text;
  final String messageType;
  final String mediaUrl;
  final String whatsappMessageId;
  final String status; // 'SENT' | 'DELIVERED' | 'READ' | 'FAILED'
  final String? error;
  final DateTime timestamp;

  const WhatsAppMessageModel({
    required this.id,
    required this.chatId,
    required this.customerPhone,
    required this.direction,
    required this.text,
    this.messageType = 'text',
    this.mediaUrl = '',
    this.whatsappMessageId = '',
    this.status = 'SENT',
    this.error,
    required this.timestamp,
  });

  bool get isOutgoing => direction.toUpperCase() == 'OUTGOING';
  bool get isIncoming => direction.toUpperCase() == 'INCOMING';

  factory WhatsAppMessageModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is DateTime) return d;
      return DateTime.tryParse(d.toString()) ?? DateTime.now();
    }

    return WhatsAppMessageModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      chatId: json['chatId']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      direction: (json['direction']?.toString() ?? 'OUTGOING').toUpperCase(),
      text: json['text']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'text',
      mediaUrl: json['mediaUrl']?.toString() ?? '',
      whatsappMessageId: json['whatsappMessageId']?.toString() ?? '',
      status: (json['status']?.toString() ?? 'SENT').toUpperCase(),
      error: json['error']?.toString(),
      timestamp: parseDate(json['timestamp']),
    );
  }
}

class WhatsAppConnectionInfo {
  final bool connected;
  final String phoneNumberId;
  final String phoneNumber;
  final String wabaId;
  final bool hasCustomToken;
  final DateTime? connectedAt;

  const WhatsAppConnectionInfo({
    required this.connected,
    required this.phoneNumberId,
    this.phoneNumber = '',
    this.wabaId = '',
    this.hasCustomToken = false,
    this.connectedAt,
  });

  factory WhatsAppConnectionInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      return DateTime.tryParse(d.toString());
    }

    return WhatsAppConnectionInfo(
      connected: json['connected'] == true,
      phoneNumberId: json['phoneNumberId']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      wabaId: json['wabaId']?.toString() ?? '',
      hasCustomToken: json['hasCustomToken'] == true,
      connectedAt: parseDate(json['connectedAt']),
    );
  }
}

class WhatsAppChatService {
  static final WhatsAppChatService _instance = WhatsAppChatService._internal();
  factory WhatsAppChatService() => _instance;
  WhatsAppChatService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Retrieve all conversations for the business
  Future<List<WhatsAppChatModel>> getChats({String? search}) async {
    try {
      final queryParams = <String, dynamic>{
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      };

      final response = await _apiClient.get(
        ApiEndpoints.whatsappChats,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        final list = data['chats'] as List<dynamic>? ?? [];
        return list.map((item) => WhatsAppChatModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[WhatsAppChatService] getChats error: $e');
      return [];
    }
  }

  /// Retrieve messages for a specific conversation
  Future<List<WhatsAppMessageModel>> getChatMessages(String chatId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.whatsappChatMessages(chatId));

      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        final list = data['messages'] as List<dynamic>? ?? [];
        return list.map((item) => WhatsAppMessageModel.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[WhatsAppChatService] getChatMessages error: $e');
      return [];
    }
  }

  /// Send an outgoing message to a customer
  Future<WhatsAppMessageModel?> sendMessage(
    String chatId,
    String text, {
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    try {
      final payload = <String, dynamic>{
        'text': text.trim(),
        if (messageType != 'text') 'messageType': messageType,
        if (mediaUrl != null && mediaUrl.isNotEmpty) 'mediaUrl': mediaUrl,
      };

      final response = await _apiClient.post(
        ApiEndpoints.whatsappSendMessage(chatId),
        data: payload,
      );

      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        if (data['message'] != null) {
          return WhatsAppMessageModel.fromJson(data['message'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[WhatsAppChatService] sendMessage error: $e');
      rethrow;
    }
  }

  /// Start a new conversation with a phone number
  Future<WhatsAppChatModel?> startNewChat({
    required String customerPhone,
    String? customerName,
    String? initialMessage,
  }) async {
    try {
      final payload = {
        'customerPhone': customerPhone.trim(),
        if (customerName != null && customerName.isNotEmpty) 'customerName': customerName.trim(),
        if (initialMessage != null && initialMessage.isNotEmpty) 'initialMessage': initialMessage.trim(),
      };

      final response = await _apiClient.post(
        ApiEndpoints.whatsappNewChat,
        data: payload,
      );

      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        if (data['chat'] != null) {
          return WhatsAppChatModel.fromJson(data['chat'] as Map<String, dynamic>);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[WhatsAppChatService] startNewChat error: $e');
      rethrow;
    }
  }

  /// Save and verify Phone Number ID connection
  Future<WhatsAppConnectionInfo> saveConnection({
    required String phoneNumberId,
    String? phoneNumber,
    String? wabaId,
    String? accessToken,
  }) async {
    try {
      final payload = {
        'phoneNumberId': phoneNumberId.trim(),
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber.trim(),
        if (wabaId != null && wabaId.isNotEmpty) 'wabaId': wabaId.trim(),
        if (accessToken != null && accessToken.isNotEmpty) 'accessToken': accessToken.trim(),
      };

      final response = await _apiClient.post(
        ApiEndpoints.whatsappConnect,
        data: payload,
      );

      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        return WhatsAppConnectionInfo.fromJson(data);
      }
      return WhatsAppConnectionInfo(connected: true, phoneNumberId: phoneNumberId);
    } catch (e) {
      debugPrint('[WhatsAppChatService] saveConnection error: $e');
      rethrow;
    }
  }

  /// Get current connection status from server
  Future<WhatsAppConnectionInfo?> getConnectionStatus() async {
    try {
      final response = await _apiClient.get(ApiEndpoints.whatsappConnectionStatus);
      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        return WhatsAppConnectionInfo.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('[WhatsAppChatService] getConnectionStatus error: $e');
      return null;
    }
  }

  /// Mark chat as read
  Future<void> markRead(String chatId) async {
    try {
      await _apiClient.put(ApiEndpoints.whatsappMarkChatRead(chatId));
    } catch (e) {
      debugPrint('[WhatsAppChatService] markRead error: $e');
    }
  }
}
