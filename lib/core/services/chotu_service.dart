import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../database/database_service.dart';
import '../models/order_model.dart';
import '../models/menu_item_model.dart';
import 'product_service.dart';
import 'speech_recognition_service.dart';

class ChotuCommandItem {
  final String? productId;
  final String productName;
  final int quantity;
  final double price;
  final double? salePrice;
  final String foodType;
  final List<String> modifiers;
  final bool matched;
  final double confidence;

  ChotuCommandItem({
    this.productId,
    required this.productName,
    this.quantity = 1,
    this.price = 0.0,
    this.salePrice,
    this.foodType = 'veg',
    this.modifiers = const [],
    this.matched = true,
    this.confidence = 1.0,
  });

  factory ChotuCommandItem.fromMap(Map<String, dynamic> map) {
    return ChotuCommandItem(
      productId: map['product_id']?.toString() ?? map['id']?.toString(),
      productName: map['product_name']?.toString() ?? map['name']?.toString() ?? 'Item',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      salePrice: (map['sale_price'] as num?)?.toDouble(),
      foodType: map['foodType']?.toString() ?? 'veg',
      modifiers: (map['modifiers'] as List?)?.map((m) => m.toString()).toList() ?? const [],
      matched: map['matched'] == true || map['product_id'] != null,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.95,
    );
  }

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'price': price,
    'sale_price': salePrice,
    'foodType': foodType,
    'modifiers': modifiers,
    'matched': matched,
    'confidence': confidence,
  };
}

class ChotuParsedCommand {
  final String intent; // ADD_ITEM, REMOVE_ITEM, UPDATE_QUANTITY, CHECK_ITEM_AVAILABILITY, VIEW_TABLE_ORDER
  final String? tableNumber;
  final bool tableContextMissing;
  final List<ChotuCommandItem> items;
  final bool ambiguity;
  final String? question;
  final double confidence;
  final String chotuResponse;
  final String? sessionId;
  final String? logId;

  ChotuParsedCommand({
    required this.intent,
    this.tableNumber,
    this.tableContextMissing = false,
    this.items = const [],
    this.ambiguity = false,
    this.question,
    required this.confidence,
    required this.chotuResponse,
    this.sessionId,
    this.logId,
  });

  factory ChotuParsedCommand.fromMap(Map<String, dynamic> map, {String? sessionId, String? logId}) {
    final rawItems = map['items'] as List?;
    final parsedItems = rawItems != null
        ? rawItems.map((i) => ChotuCommandItem.fromMap(Map<String, dynamic>.from(i as Map))).toList()
        : <ChotuCommandItem>[];

    // Handle single item in UPDATE_QUANTITY or REMOVE_ITEM
    if (parsedItems.isEmpty && map['item'] != null) {
      parsedItems.add(ChotuCommandItem.fromMap(Map<String, dynamic>.from(map['item'] as Map)));
    }

    return ChotuParsedCommand(
      intent: map['intent']?.toString() ?? 'ADD_ITEM',
      tableNumber: map['table_number']?.toString(),
      tableContextMissing: map['table_context_missing'] == true,
      items: parsedItems,
      ambiguity: map['ambiguity'] == true,
      question: map['question']?.toString(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.95,
      chotuResponse: map['chotu_response']?.toString() ?? '',
      sessionId: sessionId,
      logId: logId,
    );
  }

  Map<String, dynamic> toMap() => {
    'intent': intent,
    'table_number': tableNumber,
    'table_context_missing': tableContextMissing,
    'items': items.map((i) => i.toMap()).toList(),
    'ambiguity': ambiguity,
    'question': question,
    'confidence': confidence,
    'chotu_response': chotuResponse,
  };
}

class ChotuTranscriptionResult {
  final String transcription;
  final String originalText;
  final double confidence;
  final String language;
  final String? sessionId;
  final String? logId;
  final int durationMs;
  final bool success;
  final String message;

  ChotuTranscriptionResult({
    required this.transcription,
    required this.originalText,
    required this.confidence,
    required this.language,
    this.sessionId,
    this.logId,
    this.durationMs = 0,
    required this.success,
    required this.message,
  });

  factory ChotuTranscriptionResult.fromMap(Map<String, dynamic> map) {
    return ChotuTranscriptionResult(
      transcription: map['transcription']?.toString() ?? '',
      originalText: map['originalText']?.toString() ?? map['transcription']?.toString() ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.95,
      language: map['language']?.toString() ?? 'hinglish',
      sessionId: map['sessionId']?.toString(),
      logId: map['logId']?.toString(),
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      success: true,
      message: map['message']?.toString() ?? 'Transcription completed',
    );
  }

  factory ChotuTranscriptionResult.failure(String message) {
    return ChotuTranscriptionResult(
      transcription: '',
      originalText: '',
      confidence: 0.0,
      language: 'unknown',
      success: false,
      message: message,
    );
  }
}

class ChotuService extends ChangeNotifier {
  static final ChotuService _instance = ChotuService._internal();
  factory ChotuService() => _instance;
  ChotuService._internal();

  final ApiClient _apiClient = ApiClient();
  final SpeechRecognitionService speech = SpeechRecognitionService();

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  ChotuTranscriptionResult? _lastResult;
  ChotuTranscriptionResult? get lastResult => _lastResult;

  ChotuParsedCommand? _lastParsedCommand;
  ChotuParsedCommand? get lastParsedCommand => _lastParsedCommand;

  final List<ChotuTranscriptionResult> _history = [];
  List<ChotuTranscriptionResult> get history => List.unmodifiable(_history);

  String? _currentTableContext;
  String? get currentTableContext => _currentTableContext;

  String? _activeSessionId;
  String get activeSessionId => _activeSessionId ??= 'chotu_sess_${DateTime.now().millisecondsSinceEpoch}';

  void setTableContext(String? table) {
    _currentTableContext = table;
    notifyListeners();
  }

  /// Sends speech transcription payload to backend Chotu API
  Future<ChotuTranscriptionResult> transcribe({
    required String speechText,
    String language = 'hinglish',
    String? tableNumber,
  }) async {
    if (speechText.trim().isEmpty) {
      return ChotuTranscriptionResult.failure('Spoken text was empty');
    }

    _isProcessing = true;
    notifyListeners();

    final effectiveTable = tableNumber ?? _currentTableContext ?? '';

    try {
      final response = await _apiClient.post(
        ApiEndpoints.chotuTranscribe,
        data: {
          'audio': speechText.trim(),
          'format': 'raw_text',
          'language': language,
          'sessionId': activeSessionId,
          'tableContext': {
            'tableNumber': effectiveTable,
          },
        },
      );

      if (response != null && response['data'] != null) {
        final result = ChotuTranscriptionResult.fromMap(
          Map<String, dynamic>.from(response['data'] as Map),
        );
        _lastResult = result;
        _history.insert(0, result);
        _isProcessing = false;
        notifyListeners();
        return result;
      }

      final fallbackResult = ChotuTranscriptionResult(
        transcription: _localNormalize(speechText),
        originalText: speechText,
        confidence: 0.90,
        language: language,
        success: true,
        durationMs: 10,
        message: 'Local fallback transcription (offline)',
      );
      _lastResult = fallbackResult;
      _history.insert(0, fallbackResult);
      _isProcessing = false;
      notifyListeners();
      return fallbackResult;
    } catch (e) {
      debugPrint('[ChotuService] Backend transcription error: $e');
      final fallbackResult = ChotuTranscriptionResult(
        transcription: _localNormalize(speechText),
        originalText: speechText,
        confidence: 0.90,
        language: language,
        success: true,
        durationMs: 10,
        message: 'Local fallback transcription: $e',
      );
      _lastResult = fallbackResult;
      _history.insert(0, fallbackResult);
      _isProcessing = false;
      notifyListeners();
      return fallbackResult;
    }
  }

  /// Phase 2 & 3: Parse Spoken Natural Language into Structured POS Command
  Future<ChotuParsedCommand> parseCommand({
    required String speechText,
    String? tableNumber,
  }) async {
    final effectiveTable = tableNumber ?? _currentTableContext;
    _isProcessing = true;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        ApiEndpoints.chotuParse,
        data: {
          'text': speechText.trim(),
          'sessionId': activeSessionId,
          'currentTableContext': effectiveTable,
        },
      );

      if (response != null && response['data'] != null && response['data']['command'] != null) {
        final cmdMap = Map<String, dynamic>.from(response['data']['command'] as Map);
        final parsed = ChotuParsedCommand.fromMap(
          cmdMap,
          sessionId: response['data']['sessionId']?.toString() ?? activeSessionId,
          logId: response['data']['logId']?.toString(),
        );

        if (parsed.tableNumber != null && parsed.tableNumber!.isNotEmpty) {
          _currentTableContext = parsed.tableNumber;
        }

        _lastParsedCommand = parsed;
        _isProcessing = false;
        notifyListeners();
        return parsed;
      }

      // Offline client-side parsing fallback
      final localParsed = _localParseCommand(speechText, effectiveTable);
      _lastParsedCommand = localParsed;
      _isProcessing = false;
      notifyListeners();
      return localParsed;
    } catch (e) {
      debugPrint('[ChotuService] Backend parse error, using local fallback: $e');
      final localParsed = _localParseCommand(speechText, effectiveTable);
      _lastParsedCommand = localParsed;
      _isProcessing = false;
      notifyListeners();
      return localParsed;
    }
  }

  /// Phase 3: Execute Validated POS Command via POS Services & Cart Sync
  Future<Map<String, dynamic>> executeCommand(ChotuParsedCommand command) async {
    _isProcessing = true;
    notifyListeners();

    final commandId = 'cmd_${activeSessionId}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await _apiClient.post(
        ApiEndpoints.chotuExecute,
        data: {
          'commandId': commandId,
          'sessionId': activeSessionId,
          'command': command.toMap(),
        },
      );

      if (response != null && response['data'] != null) {
        final data = Map<String, dynamic>.from(response['data'] as Map);

        // Synchronize local DatabaseService cart in-memory
        _syncLocalCartAfterExecution(command);

        _isProcessing = false;
        notifyListeners();
        return data;
      }

      // Local execution fallback if offline
      _syncLocalCartAfterExecution(command);
      _isProcessing = false;
      notifyListeners();
      return {
        'success': true,
        'message': command.chotuResponse,
        'isOffline': true,
      };
    } catch (e) {
      debugPrint('[ChotuService] Backend execute error, falling back locally: $e');
      _syncLocalCartAfterExecution(command);
      _isProcessing = false;
      notifyListeners();
      return {
        'success': true,
        'message': command.chotuResponse,
        'isOffline': true,
      };
    }
  }

  /// Synchronize in-memory DatabaseService cart state
  void _syncLocalCartAfterExecution(ChotuParsedCommand command) {
    final db = DatabaseService();
    final tableNum = command.tableNumber ?? _currentTableContext ?? '1';
    final targetTableStr = tableNum.startsWith('T') ? tableNum : 'T-$tableNum';

    if (command.intent == 'ADD_ITEM') {
      for (final item in command.items) {
        final menuItem = db.menuItems.where((m) =>
            m.id == item.productId ||
            m.productId == item.productId ||
            m.name.toLowerCase() == item.productName.toLowerCase()
        ).firstOrNull;

        if (menuItem != null) {
          // Add to live in-memory table cart
          final existingCart = db.getLiveTableCart(targetTableStr);
          final existingIdx = existingCart.indexWhere((ci) => ci.item.id == menuItem.id);
          if (existingIdx >= 0) {
            existingCart[existingIdx].quantity += item.quantity;
          } else {
            existingCart.add(CartItemModel(item: menuItem, quantity: item.quantity));
          }
          db.setLiveTableCart(targetTableStr, existingCart);
        }
      }
    }
  }

  /// Checks if any requested item in the parsed command is not in POS or is out of stock
  ChotuCommandItem? checkUnmatchedOrOutOfStockItem(ChotuParsedCommand command) {
    final db = DatabaseService();
    for (final item in command.items) {
      if (!item.matched || item.productId == null || item.productId!.isEmpty) {
        return item;
      }
      final menuItem = db.menuItems.where((m) =>
          m.id == item.productId ||
          m.productId == item.productId ||
          m.name.toLowerCase() == item.productName.toLowerCase()
      ).firstOrNull;

      if (menuItem == null) {
        return item;
      }
      if (!menuItem.isAvailable || (menuItem.stockQuantity == 0)) {
        return item;
      }
    }
    return null;
  }

  /// Adds a missing product permanently to the POS database, then pushes to current table cart
  Future<void> addMissingProductPermanently({
    required String productName,
    required int quantity,
    String? tableNumber,
    double price = 0.0,
  }) async {
    final db = DatabaseService();
    final newId = 'prod_chotu_${DateTime.now().millisecondsSinceEpoch}';
    final newItem = MenuItemModel(
      id: newId,
      productId: newId,
      name: productName,
      category: 'General',
      price: price,
      isAvailable: true,
      description: 'Added via Chotu Voice Assistant',
    );

    // Add to in-memory menu
    db.menuItems.add(newItem);

    // Save to backend MongoDB asynchronously
    try {
      ProductService().createProduct(newItem).catchError((e) {
        debugPrint('[ChotuService] Backend product save error: $e');
        return newItem;
      });
    } catch (_) {}

    // Add to active table cart
    final tableNum = tableNumber ?? _currentTableContext ?? '1';
    final targetTableStr = tableNum.startsWith('T') ? tableNum : 'T-$tableNum';
    final cart = db.getLiveTableCart(targetTableStr);
    final existingIdx = cart.indexWhere((ci) => ci.item.name.toLowerCase() == productName.toLowerCase());
    if (existingIdx >= 0) {
      cart[existingIdx].quantity += quantity;
    } else {
      cart.add(CartItemModel(item: newItem, quantity: quantity));
    }
    db.setLiveTableCart(targetTableStr, cart);
    notifyListeners();
  }

  /// Adds a missing product temporarily for this order only (without saving to permanent menu)
  Future<void> addMissingProductTemporarily({
    required String productName,
    required int quantity,
    String? tableNumber,
    double price = 0.0,
  }) async {
    final db = DatabaseService();
    final tempItem = MenuItemModel(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      productId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      name: productName,
      category: 'Custom Item',
      price: price,
      isAvailable: true,
      description: 'Temporary Order Item (Chotu)',
    );

    final tableNum = tableNumber ?? _currentTableContext ?? '1';
    final targetTableStr = tableNum.startsWith('T') ? tableNum : 'T-$tableNum';
    final cart = db.getLiveTableCart(targetTableStr);
    final existingIdx = cart.indexWhere((ci) => ci.item.name.toLowerCase() == productName.toLowerCase());
    if (existingIdx >= 0) {
      cart[existingIdx].quantity += quantity;
    } else {
      cart.add(CartItemModel(item: tempItem, quantity: quantity));
    }
    db.setLiveTableCart(targetTableStr, cart);
    notifyListeners();
  }

  /// Fast local parsing fallback matching against in-memory DatabaseService menu
  ChotuParsedCommand _localParseCommand(String text, String? table) {
    final normalized = _localNormalize(text);
    final lower = normalized.toLowerCase();
    final db = DatabaseService();

    // Extract table number
    String? resolvedTable = table;
    final tblMatch = RegExp(r'\b(?:table|tbl|t)\s*[-#]?\s*(\d+)\b', caseSensitive: false).firstMatch(normalized);
    if (tblMatch != null) {
      resolvedTable = tblMatch.group(1);
    }

    final items = <ChotuCommandItem>[];
    for (final menu in db.menuItems) {
      final mName = menu.name.toLowerCase();
      bool isMatch = lower.contains(mName);
      if (!isMatch) {
        for (final alias in menu.aliases) {
          if (lower.contains(alias.toLowerCase())) {
            isMatch = true;
            break;
          }
        }
      }

      if (isMatch) {
        // Extract quantity preceding product name
        int qty = 1;
        final qtyRegex = RegExp('(\\d+)\\s+${RegExp.escape(mName)}', caseSensitive: false);
        final qm = qtyRegex.firstMatch(lower);
        if (qm != null) {
          qty = int.tryParse(qm.group(1)!) ?? 1;
        }

        items.add(ChotuCommandItem(
          productId: menu.id,
          productName: menu.name,
          quantity: qty,
          price: menu.price,
          salePrice: menu.salePrice,
          foodType: menu.itemType.toLowerCase(),
          matched: true,
          confidence: 0.92,
        ));
      }
    }

    // Resilient fallback when menu is empty or product not yet cached locally
    if (items.isEmpty) {
      final contentStr = normalized
          .replaceAll(RegExp(r'\b(?:table|tbl|mez)\s*[-#]?\s*\d+\s*(?:pe|mein|par|to|for)?\b', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\b(?:laga|lagao|kar|karo|bhej|rakh)\s+do\b', caseSensitive: false), ' ')
          .replaceAll(RegExp(r'\b(?:add\s+karo|add\s+kar\s+do|add)\b', caseSensitive: false), ' ')
          .trim();

      final phrases = contentStr.split(RegExp(r'\b(?:aur|and|\+|&)\b|,', caseSensitive: false));
      for (final p in phrases) {
        final phrase = p.trim();
        if (phrase.isEmpty) continue;
        final numMatch = RegExp(r'^(\d+)\s+(.+)$').firstMatch(phrase);
        if (numMatch != null) {
          final qty = int.tryParse(numMatch.group(1)!) ?? 1;
          final name = numMatch.group(2)!.trim();
          if (name.isNotEmpty) {
            items.add(ChotuCommandItem(
              productName: name,
              quantity: qty,
              matched: false,
              confidence: 0.85,
            ));
          }
        }
      }
    }

    final itemSummary = items.map((i) => '${i.productName} ${i.quantity}').join(' aur ');
    final chotuReply = items.isNotEmpty
        ? (resolvedTable != null
            ? 'Table $resolvedTable mein $itemSummary add kar diya.'
            : '$itemSummary add kar diya.')
        : 'Item samajh nahi aaya.';

    return ChotuParsedCommand(
      intent: 'ADD_ITEM',
      tableNumber: resolvedTable,
      tableContextMissing: resolvedTable == null,
      items: items,
      confidence: items.isNotEmpty ? 0.90 : 0.40,
      chotuResponse: chotuReply,
    );
  }

  /// Fast local number normalization for offline fallback
  String _localNormalize(String text) {
    String clean = text.trim();

    // Protect Hindi imperative verbs ending in 'do' (e.g. laga do, kar do, bana do, bhej do, hata do)
    final verbDoMap = <String, String>{};
    clean = clean.replaceAllMapped(
      RegExp(r'\b(laga|kar|bana|hata|de|bhej|daal|rakh|nikal|le)\s+do\b', caseSensitive: false),
      (match) {
        final placeholder = '__VERB_${verbDoMap.length}__';
        verbDoMap[placeholder] = match.group(0)!;
        return placeholder;
      },
    );

    final numberMap = {
      RegExp(r'\b(ek|ik|one)\b', caseSensitive: false): '1',
      RegExp(r'\b(do|too|two)\b', caseSensitive: false): '2',
      RegExp(r'\b(teen|tin|three)\b', caseSensitive: false): '3',
      RegExp(r'\b(chaar|char|four)\b', caseSensitive: false): '4',
      RegExp(r'\b(paanch|panch|five)\b', caseSensitive: false): '5',
      RegExp(r'\b(che|six)\b', caseSensitive: false): '6',
      RegExp(r'\b(saat|seven)\b', caseSensitive: false): '7',
      RegExp(r'\b(aath|eight)\b', caseSensitive: false): '8',
      RegExp(r'\b(nau|nine)\b', caseSensitive: false): '9',
      RegExp(r'\b(das|ten)\b', caseSensitive: false): '10',
    };
    for (final entry in numberMap.entries) {
      clean = clean.replaceAll(entry.key, entry.value);
    }

    // Restore verbal 'do' phrases
    for (final entry in verbDoMap.entries) {
      clean = clean.replaceAll(entry.key, entry.value);
    }

    return clean;
  }

  void clearHistory() {
    _history.clear();
    _lastResult = null;
    _lastParsedCommand = null;
    notifyListeners();
  }
}
