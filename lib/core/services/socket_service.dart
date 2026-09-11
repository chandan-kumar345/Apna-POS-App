import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../network/api_endpoints.dart';
import '../models/table_model.dart';
import '../security/secure_storage_service.dart';

typedef TableUpdateCallback = void Function(TableModel table);
typedef TablesBatchUpdateCallback = void Function(List<TableModel> tables);
typedef TableCreateCallback = void Function(TableModel table);
typedef TableDeleteCallback = void Function(String tableId);
typedef SocketReconnectCallback = void Function();

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _currentBusinessId;
  String? _currentToken;
  bool _isConnecting = false;

  final SecureStorageService _storage = SecureStorageService();

  // Callbacks registered by DatabaseService
  TableUpdateCallback? onTableUpdated;
  TablesBatchUpdateCallback? onTablesBatchUpdated;
  TableCreateCallback? onTableCreated;
  TableDeleteCallback? onTableDeleted;
  SocketReconnectCallback? onReconnected;

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
      final activeBusinessId = businessId ?? _currentBusinessId;

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
        if (_currentBusinessId != null && _currentBusinessId!.isNotEmpty) {
          joinBusinessRoom(_currentBusinessId!);
        }
      });

      socket.onReconnect((_) {
        debugPrint('[SocketService] Reconnected to Socket.IO server. Triggering room rejoin and resync...');
        if (_currentBusinessId != null && _currentBusinessId!.isNotEmpty) {
          joinBusinessRoom(_currentBusinessId!);
        }
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
      socket.on('table_status_updated', (data) => _handleSingleTableUpdate(data));

      // Batch tables updated (e.g., table shifting or bulk count sync)
      socket.on('tables:batch_updated', (data) => _handleBatchTablesUpdate(data));
      socket.on('tables_synced', (data) => _handleBatchTablesUpdate(data));

      // Table created
      socket.on('table:created', (data) => _handleTableCreated(data));

      // Table deleted
      socket.on('table:deleted', (data) => _handleTableDeleted(data));

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

  /// Update business ID and rejoin room if changed
  void updateBusinessId(String businessId) {
    if (businessId.trim().isEmpty) return;
    _currentBusinessId = businessId.trim();
    if (_socket != null && _socket!.connected) {
      joinBusinessRoom(_currentBusinessId!);
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
