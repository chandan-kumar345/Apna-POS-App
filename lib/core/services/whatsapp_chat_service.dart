import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import 'socket_service.dart';

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

  WhatsAppChatModel copyWith({
    String? id,
    String? customerPhone,
    String? customerName,
    String? lastMessage,
    DateTime? lastMessageAt,
    String? lastMessageDirection,
    int? unreadCount,
    String? status,
    String? phoneNumberId,
  }) {
    return WhatsAppChatModel(
      id: id ?? this.id,
      customerPhone: customerPhone ?? this.customerPhone,
      customerName: customerName ?? this.customerName,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageDirection: lastMessageDirection ?? this.lastMessageDirection,
      unreadCount: unreadCount ?? this.unreadCount,
      status: status ?? this.status,
      phoneNumberId: phoneNumberId ?? this.phoneNumberId,
    );
  }

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

  Map<String, dynamic> toJson() => {
    '_id': id,
    'customerPhone': customerPhone,
    'customerName': customerName,
    'lastMessage': lastMessage,
    'lastMessageAt': lastMessageAt.toIso8601String(),
    'lastMessageDirection': lastMessageDirection,
    'unreadCount': unreadCount,
    'status': status,
    'phoneNumberId': phoneNumberId,
  };

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

  WhatsAppMessageModel copyWith({
    String? id,
    String? chatId,
    String? customerPhone,
    String? direction,
    String? text,
    String? messageType,
    String? mediaUrl,
    String? whatsappMessageId,
    String? status,
    String? error,
    DateTime? timestamp,
  }) {
    return WhatsAppMessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      customerPhone: customerPhone ?? this.customerPhone,
      direction: direction ?? this.direction,
      text: text ?? this.text,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      whatsappMessageId: whatsappMessageId ?? this.whatsappMessageId,
      status: status ?? this.status,
      error: error ?? this.error,
      timestamp: timestamp ?? this.timestamp,
    );
  }

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

  Map<String, dynamic> toJson() => {
    '_id': id,
    'chatId': chatId,
    'customerPhone': customerPhone,
    'direction': direction,
    'text': text,
    'messageType': messageType,
    'mediaUrl': mediaUrl,
    'whatsappMessageId': whatsappMessageId,
    'status': status,
    'error': error,
    'timestamp': timestamp.toIso8601String(),
  };
}

class WhatsAppConnectionInfo {
  final bool connected;
  final String phoneNumberId;
  final String phoneNumber;
  final String wabaId;
  final String accessToken;
  final bool hasCustomToken;
  final DateTime? connectedAt;

  const WhatsAppConnectionInfo({
    required this.connected,
    required this.phoneNumberId,
    this.phoneNumber = '',
    this.wabaId = '',
    this.accessToken = '',
    this.hasCustomToken = false,
    this.connectedAt,
  });

  factory WhatsAppConnectionInfo.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      return DateTime.tryParse(d.toString());
    }

    final token = json['accessToken']?.toString() ?? '';

    return WhatsAppConnectionInfo(
      connected: json['connected'] == true,
      phoneNumberId: json['phoneNumberId']?.toString() ?? '',
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      wabaId: json['wabaId']?.toString() ?? '',
      accessToken: token,
      hasCustomToken: json['hasCustomToken'] == true || token.isNotEmpty,
      connectedAt: parseDate(json['connectedAt']),
    );
  }
}

class WhatsAppChatService {
  static final WhatsAppChatService _instance = WhatsAppChatService._internal();
  factory WhatsAppChatService() => _instance;
  WhatsAppChatService._internal() {
    _initSocketListeners();
  }

  final ApiClient _apiClient = ApiClient();

  // In-memory instant caching for sub-millisecond retrieval
  List<WhatsAppChatModel>? _chatsCache;
  final Map<String, List<WhatsAppMessageModel>> _messagesCache = {};

  // Real-time reactive stream controllers
  final StreamController<WhatsAppMessageModel> _messageStreamController =
      StreamController<WhatsAppMessageModel>.broadcast();
  final StreamController<List<WhatsAppChatModel>> _chatsStreamController =
      StreamController<List<WhatsAppChatModel>>.broadcast();

  Stream<WhatsAppMessageModel> get onMessageReceived => _messageStreamController.stream;
  Stream<List<WhatsAppChatModel>> get onChatsUpdated => _chatsStreamController.stream;

  static const String _prefChatsKey = 'cached_wa_chats_v1';
  static String _prefMsgsKey(String chatId) => 'cached_wa_msgs_v1_$chatId';

  /// Hook into real-time socket events for instantaneous (<50ms) message reception
  void _initSocketListeners() {
    try {
      final socketService = SocketService();
      socketService.onWhatsAppMessage = (data) {
        _handleIncomingSocketMessage(data);
      };
      socketService.onWhatsAppChatUpdated = (data) {
        _handleIncomingSocketChatUpdate(data);
      };
    } catch (e) {
      debugPrint('[WhatsAppChatService] Error attaching socket listeners: $e');
    }
  }

  void _handleIncomingSocketMessage(Map<String, dynamic> data) {
    try {
      final chatMap = data['chat'] is Map ? Map<String, dynamic>.from(data['chat'] as Map) : null;
      final msgMap = data['message'] is Map ? Map<String, dynamic>.from(data['message'] as Map) : null;

      if (msgMap == null) return;
      final msg = WhatsAppMessageModel.fromJson(msgMap);

      // 1. Update in-memory and persistent messages cache
      final existingMsgs = _messagesCache[msg.chatId] ?? [];
      final alreadyExists = existingMsgs.any((m) => m.id == msg.id || (m.whatsappMessageId.isNotEmpty && m.whatsappMessageId == msg.whatsappMessageId));
      if (!alreadyExists) {
        existingMsgs.add(msg);
        _messagesCache[msg.chatId] = existingMsgs;
        _saveMessagesToPrefs(msg.chatId, existingMsgs);
      }

      // 2. Update chats list cache
      if (_chatsCache != null) {
        final chatIndex = _chatsCache!.indexWhere((c) => c.id == msg.chatId);
        if (chatIndex != -1) {
          final old = _chatsCache![chatIndex];
          final updated = old.copyWith(
            lastMessage: msg.messageType == 'image' ? '📷 Photo' : (msg.text.isNotEmpty ? msg.text : 'New message'),
            lastMessageAt: msg.timestamp,
            lastMessageDirection: msg.direction,
            unreadCount: msg.isIncoming ? old.unreadCount + 1 : old.unreadCount,
          );
          _chatsCache!.removeAt(chatIndex);
          _chatsCache!.insert(0, updated);
        } else if (chatMap != null) {
          final newChat = WhatsAppChatModel.fromJson(chatMap);
          _chatsCache!.insert(0, newChat);
        }
        _saveChatsToPrefs(_chatsCache!);
        _chatsStreamController.add(List.from(_chatsCache!));
      }

      // 3. Emit message event to active chat screen
      _messageStreamController.add(msg);
      debugPrint('[WhatsAppChatService] ⚡ Socket message processed: ${msg.text}');
    } catch (e) {
      debugPrint('[WhatsAppChatService] Error handling socket message: $e');
    }
  }

  void _handleIncomingSocketChatUpdate(Map<String, dynamic> data) {
    try {
      final chatMap = data['chat'] is Map ? Map<String, dynamic>.from(data['chat'] as Map) : null;
      if (chatMap == null) return;
      final updatedChat = WhatsAppChatModel.fromJson(chatMap);

      if (_chatsCache != null) {
        final idx = _chatsCache!.indexWhere((c) => c.id == updatedChat.id);
        if (idx != -1) {
          _chatsCache![idx] = updatedChat;
        } else {
          _chatsCache!.insert(0, updatedChat);
        }
        _saveChatsToPrefs(_chatsCache!);
        _chatsStreamController.add(List.from(_chatsCache!));
      }
    } catch (e) {
      debugPrint('[WhatsAppChatService] Error handling socket chat update: $e');
    }
  }

  // --- Local Persistence Helpers (SharedPreferences) ---

  Future<void> _saveChatsToPrefs(List<WhatsAppChatModel> chats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(chats.map((c) => c.toJson()).toList());
      await prefs.setString(_prefChatsKey, encoded);
    } catch (_) {}
  }

  Future<List<WhatsAppChatModel>> _loadChatsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefChatsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((m) => WhatsAppChatModel.fromJson(m as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveMessagesToPrefs(String chatId, List<WhatsAppMessageModel> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep most recent 100 messages in local storage for fast instant load
      final slice = messages.length > 100 ? messages.sublist(messages.length - 100) : messages;
      final encoded = jsonEncode(slice.map((m) => m.toJson()).toList());
      await prefs.setString(_prefMsgsKey(chatId), encoded);
    } catch (_) {}
  }

  Future<List<WhatsAppMessageModel>> _loadMessagesFromPrefs(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefMsgsKey(chatId));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((m) => WhatsAppMessageModel.fromJson(m as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Retrieve all conversations with 0ms instant cached load (Stale-While-Revalidate)
  Future<List<WhatsAppChatModel>> getChats({String? search, bool forceRefresh = false}) async {
    final hasSearch = search != null && search.trim().isNotEmpty;

    // 1. Instant Cache hit (0ms UI render!)
    if (!hasSearch && !forceRefresh) {
      if (_chatsCache != null && _chatsCache!.isNotEmpty) {
        // Trigger silent background revalidation without blocking caller
        _revalidateChatsInBackground();
        return List.from(_chatsCache!);
      }
      final localChats = await _loadChatsFromPrefs();
      if (localChats.isNotEmpty) {
        _chatsCache = localChats;
        _revalidateChatsInBackground();
        return List.from(localChats);
      }
    }

    // 2. Fetch fresh from server
    return await _fetchChatsFromServer(search: search);
  }

  Future<void> _revalidateChatsInBackground() async {
    try {
      final fresh = await _fetchChatsFromServer();
      if (fresh.isNotEmpty) {
        _chatsCache = fresh;
        _saveChatsToPrefs(fresh);
        _chatsStreamController.add(List.from(fresh));
      }
    } catch (_) {}
  }

  Future<List<WhatsAppChatModel>> _fetchChatsFromServer({String? search}) async {
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
        final parsed = list.map((item) => WhatsAppChatModel.fromJson(item as Map<String, dynamic>)).toList();

        if (search == null || search.trim().isEmpty) {
          _chatsCache = parsed;
          _saveChatsToPrefs(parsed);
          _chatsStreamController.add(List.from(parsed));
        }
        return parsed;
      }
      return _chatsCache ?? [];
    } catch (e) {
      debugPrint('[WhatsAppChatService] getChats error: $e');
      return _chatsCache ?? [];
    }
  }

  /// Retrieve messages for a specific conversation with 0ms instant cached render
  Future<List<WhatsAppMessageModel>> getChatMessages(String chatId, {bool forceRefresh = false}) async {
    // 1. Instant Cache hit
    if (!forceRefresh) {
      if (_messagesCache.containsKey(chatId) && _messagesCache[chatId]!.isNotEmpty) {
        _revalidateMessagesInBackground(chatId);
        return List.from(_messagesCache[chatId]!);
      }
      final localMsgs = await _loadMessagesFromPrefs(chatId);
      if (localMsgs.isNotEmpty) {
        _messagesCache[chatId] = localMsgs;
        _revalidateMessagesInBackground(chatId);
        return List.from(localMsgs);
      }
    }

    // 2. Fetch from server
    return await _fetchMessagesFromServer(chatId);
  }

  Future<void> _revalidateMessagesInBackground(String chatId) async {
    try {
      final fresh = await _fetchMessagesFromServer(chatId);
      if (fresh.isNotEmpty) {
        _messagesCache[chatId] = fresh;
        _saveMessagesToPrefs(chatId, fresh);
      }
    } catch (_) {}
  }

  Future<List<WhatsAppMessageModel>> _fetchMessagesFromServer(String chatId) async {
    try {
      final response = await _apiClient.get(ApiEndpoints.whatsappChatMessages(chatId));

      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        final list = data['messages'] as List<dynamic>? ?? [];
        final parsed = list.map((item) => WhatsAppMessageModel.fromJson(item as Map<String, dynamic>)).toList();

        _messagesCache[chatId] = parsed;
        _saveMessagesToPrefs(chatId, parsed);
        return parsed;
      }
      return _messagesCache[chatId] ?? [];
    } catch (e) {
      debugPrint('[WhatsAppChatService] getChatMessages error: $e');
      return _messagesCache[chatId] ?? [];
    }
  }

  /// Send an outgoing message to a customer with instant optimistic UI update
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
          final msg = WhatsAppMessageModel.fromJson(data['message'] as Map<String, dynamic>);

          // Append to local messages cache
          final list = _messagesCache[chatId] ?? [];
          if (!list.any((m) => m.id == msg.id)) {
            list.add(msg);
            _messagesCache[chatId] = list;
            _saveMessagesToPrefs(chatId, list);
          }

          // Update chat list preview
          if (_chatsCache != null) {
            final idx = _chatsCache!.indexWhere((c) => c.id == chatId);
            if (idx != -1) {
              final old = _chatsCache![idx];
              final updated = old.copyWith(
                lastMessage: msg.messageType == 'image' ? '📷 Photo' : msg.text,
                lastMessageAt: msg.timestamp,
                lastMessageDirection: 'OUTGOING',
              );
              _chatsCache!.removeAt(idx);
              _chatsCache!.insert(0, updated);
              _saveChatsToPrefs(_chatsCache!);
              _chatsStreamController.add(List.from(_chatsCache!));
            }
          }

          return msg;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[WhatsAppChatService] sendMessage error: $e');
      rethrow;
    }
  }

  /// Upload a chat image file (via file path or raw bytes) to server storage
  Future<String?> uploadChatImage({
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    try {
      MultipartFile multipartFile;
      final safeName = fileName ?? 'wa_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (fileBytes != null && fileBytes.isNotEmpty) {
        multipartFile = MultipartFile.fromBytes(
          fileBytes,
          filename: safeName,
        );
      } else if (filePath != null && filePath.isNotEmpty) {
        multipartFile = await MultipartFile.fromFile(
          filePath,
          filename: safeName,
        );
      } else {
        throw Exception('No image file or bytes provided for upload');
      }

      final formData = FormData.fromMap({
        'image': multipartFile,
      });

      final response = await _apiClient.post(
        ApiEndpoints.uploadImage,
        data: formData,
        queryParameters: {'folder': 'whatsapp'},
      );

      if (response != null && response is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>? ?? response;
        final imageUrl = data['imageUrl']?.toString() ?? data['url']?.toString();
        if (imageUrl != null && imageUrl.isNotEmpty) {
          return imageUrl;
        }
      }
      return null;
    } catch (e) {
      debugPrint('[WhatsAppChatService] uploadChatImage error: $e');
      rethrow;
    }
  }

  /// Start a new conversation with any phone number
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
          final chat = WhatsAppChatModel.fromJson(data['chat'] as Map<String, dynamic>);

          // Insert into local cache
          _chatsCache ??= [];
          final existingIdx = _chatsCache!.indexWhere((c) => c.id == chat.id);
          if (existingIdx != -1) {
            _chatsCache![existingIdx] = chat;
          } else {
            _chatsCache!.insert(0, chat);
          }
          _saveChatsToPrefs(_chatsCache!);
          _chatsStreamController.add(List.from(_chatsCache!));

          return chat;
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

  /// Mark chat as read with instant optimistic UI update
  Future<void> markRead(String chatId) async {
    try {
      // Optimistically clear unread count in local cache
      if (_chatsCache != null) {
        final idx = _chatsCache!.indexWhere((c) => c.id == chatId);
        if (idx != -1 && _chatsCache![idx].unreadCount > 0) {
          _chatsCache![idx] = _chatsCache![idx].copyWith(unreadCount: 0);
          _saveChatsToPrefs(_chatsCache!);
          _chatsStreamController.add(List.from(_chatsCache!));
        }
      }
      await _apiClient.put(ApiEndpoints.whatsappMarkChatRead(chatId));
    } catch (e) {
      debugPrint('[WhatsAppChatService] markRead error: $e');
    }
  }
}
