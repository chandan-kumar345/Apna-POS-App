import 'package:flutter/foundation.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../database/database_service.dart';
import '../models/order_model.dart';
import '../models/menu_item_model.dart';
import '../models/table_model.dart';
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
  final String intent; // ADD_ITEM, REMOVE_ITEM, UPDATE_QUANTITY, SEND_KOT, GENERATE_BILL, CLEAR_CART, APPLY_DISCOUNT, SWITCH_TABLE, SET_CUSTOMER_DETAILS, SET_ORDER_TYPE, CHECK_ITEM_AVAILABILITY, VIEW_TABLE_ORDER
  final String? tableNumber;
  final bool tableContextMissing;
  final List<ChotuCommandItem> items;
  final int? quantity;
  final double? discountValue;
  final String? discountType;
  final bool isRemoveDiscount;
  final String? customerName;
  final String? customerPhone;
  final String? orderType;
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
    this.quantity,
    this.discountValue,
    this.discountType,
    this.isRemoveDiscount = false,
    this.customerName,
    this.customerPhone,
    this.orderType,
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
      quantity: (map['quantity'] as num?)?.toInt(),
      discountValue: (map['discount_value'] as num?)?.toDouble() ?? (map['discountValue'] as num?)?.toDouble(),
      discountType: map['discount_type']?.toString() ?? map['discountType']?.toString(),
      isRemoveDiscount: map['is_remove'] == true || map['isRemove'] == true,
      customerName: map['customer_name']?.toString() ?? map['customerName']?.toString(),
      customerPhone: map['customer_phone']?.toString() ?? map['customerPhone']?.toString(),
      orderType: map['order_type']?.toString() ?? map['orderType']?.toString(),
      ambiguity: map['ambiguity'] == true,
      question: map['question']?.toString(),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.95,
      chotuResponse: map['chotu_response']?.toString() ?? map['chotuResponse']?.toString() ?? '',
      sessionId: sessionId,
      logId: logId,
    );
  }

  Map<String, dynamic> toMap() => {
    'intent': intent,
    'table_number': tableNumber,
    'table_context_missing': tableContextMissing,
    'items': items.map((i) => i.toMap()).toList(),
    'quantity': quantity,
    'discount_value': discountValue,
    'discount_type': discountType,
    'is_remove': isRemoveDiscount,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'order_type': orderType,
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

  final List<void Function(ChotuParsedCommand command)> _actionListeners = [];

  void addActionListener(void Function(ChotuParsedCommand command) listener) {
    if (!_actionListeners.contains(listener)) {
      _actionListeners.add(listener);
    }
  }

  void removeActionListener(void Function(ChotuParsedCommand command) listener) {
    _actionListeners.remove(listener);
  }

  void dispatchAction(ChotuParsedCommand command) {
    for (final listener in List.from(_actionListeners)) {
      try {
        listener(command);
      } catch (e) {
        debugPrint('[ChotuService] Error dispatching action: $e');
      }
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
        dispatchAction(command);

        _isProcessing = false;
        notifyListeners();
        return data;
      }

      // Local execution fallback if offline
      _syncLocalCartAfterExecution(command);
      dispatchAction(command);
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
      dispatchAction(command);
      _isProcessing = false;
      notifyListeners();
      return {
        'success': true,
        'message': command.chotuResponse,
        'isOffline': true,
      };
    }
  }

  /// Synchronize in-memory DatabaseService state for all order intents
  void _syncLocalCartAfterExecution(ChotuParsedCommand command) {
    final db = DatabaseService();
    final tableNum = command.tableNumber ?? _currentTableContext ?? '1';
    final targetTableStr = tableNum.startsWith('T') ? tableNum : 'T-$tableNum';

    switch (command.intent) {
      case 'ADD_ITEM':
        for (final item in command.items) {
          var menuItem = db.menuItems.where((m) =>
              m.id == item.productId ||
              m.productId == item.productId ||
              m.name.toLowerCase() == item.productName.toLowerCase()
          ).firstOrNull;

          // If not in standard menu, create dynamic item so order proceeds seamlessly
          menuItem ??= MenuItemModel(
            id: item.productId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
            productId: item.productId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
            name: item.productName,
            category: 'Custom Item',
            price: item.price,
            isAvailable: true,
            description: 'Dynamic item added via Chotu Voice',
          );

          final existingCart = db.getLiveTableCart(targetTableStr);
          final existingIdx = existingCart.indexWhere((ci) =>
              ci.item.id == menuItem!.id ||
              ci.item.name.toLowerCase() == menuItem.name.toLowerCase());
          if (existingIdx >= 0) {
            existingCart[existingIdx].quantity += item.quantity;
          } else {
            existingCart.add(CartItemModel(item: menuItem, quantity: item.quantity));
          }
          db.setLiveTableCart(targetTableStr, existingCart);

          // Update table occupied state if table was free
          final tbl = db.tables.where((t) => isSameTable(t.name, targetTableStr) || t.tableNumber.toString() == tableNum).firstOrNull;
          if (tbl != null && (tbl.status == TableStatus.free || tbl.occupiedSince == null)) {
            db.updateTableStatus(tbl.id, TableStatus.occupied, occupiedSince: tbl.occupiedSince ?? DateTime.now().toIso8601String());
          }
        }
        break;

      case 'REMOVE_ITEM':
        final existingCart = db.getLiveTableCart(targetTableStr);
        for (final item in command.items) {
          final idx = existingCart.indexWhere((ci) =>
              ci.item.id == item.productId ||
              ci.item.name.toLowerCase().contains(item.productName.toLowerCase()) ||
              item.productName.toLowerCase().contains(ci.item.name.toLowerCase()));
          if (idx >= 0) {
            existingCart[idx].quantity -= (command.quantity ?? item.quantity);
            if (existingCart[idx].quantity <= 0) {
              existingCart.removeAt(idx);
            }
          }
        }
        db.setLiveTableCart(targetTableStr, existingCart);
        break;

      case 'UPDATE_QUANTITY':
        final existingCart = db.getLiveTableCart(targetTableStr);
        for (final item in command.items) {
          final idx = existingCart.indexWhere((ci) =>
              ci.item.id == item.productId ||
              ci.item.name.toLowerCase().contains(item.productName.toLowerCase()) ||
              item.productName.toLowerCase().contains(ci.item.name.toLowerCase()));
          if (idx >= 0) {
            existingCart[idx].quantity = command.quantity ?? item.quantity;
          }
        }
        db.setLiveTableCart(targetTableStr, existingCart);
        break;

      case 'CLEAR_CART':
        db.clearTableCartAndFree(targetTableStr);
        break;

      case 'APPLY_DISCOUNT':
        if (command.isRemoveDiscount || (command.discountValue != null && command.discountValue == 0)) {
          db.setLiveTableDiscount(targetTableStr, coupon: '', discountInput: 0.0, discountMode: 'percent', discountAmount: 0.0);
        } else if (command.discountValue != null) {
          db.setLiveTableDiscount(
            targetTableStr,
            discountInput: command.discountValue!,
            discountMode: command.discountType ?? 'percent',
          );
        }
        break;

      case 'SEND_KOT':
        final tbl = db.tables.where((t) => isSameTable(t.name, targetTableStr) || t.tableNumber.toString() == tableNum).firstOrNull;
        if (tbl != null) {
          db.updateTableStatus(tbl.id, TableStatus.runningKot, occupiedSince: tbl.occupiedSince ?? DateTime.now().toIso8601String());
        }
        break;

      case 'SWITCH_TABLE':
        if (command.tableNumber != null && command.tableNumber!.isNotEmpty) {
          _currentTableContext = command.tableNumber;
        }
        break;

      default:
        break;
    }
  }

  /// Checks if any requested item in the parsed command is explicitly out of stock
  ChotuCommandItem? checkUnmatchedOrOutOfStockItem(ChotuParsedCommand command) {
    if (command.intent != 'ADD_ITEM') return null;
    final db = DatabaseService();
    for (final item in command.items) {
      if (item.productId != null && (item.productId!.startsWith('custom_') || item.productId!.startsWith('temp_'))) {
        continue;
      }
      final menuItem = db.menuItems.where((m) =>
          m.id == item.productId ||
          m.productId == item.productId ||
          m.name.toLowerCase() == item.productName.toLowerCase()
      ).firstOrNull;

      if (menuItem != null && (!menuItem.isAvailable || (menuItem.stockQuantity == 0))) {
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

  /// Transliterates Devanagari Hindi text to Romanized script phonetically
  static String _transliterateDevanagari(String text) {
    if (text.isEmpty) return text;
    if (!RegExp(r'[\u0900-\u097F]').hasMatch(text)) return text;

    // Convert known compound words and POS keywords first
    final commonHindiWords = {
      RegExp(r'टेबल|मेज'): 'table',
      RegExp(r'कोट|केओटी|के\.ओ\.टी|के\s+ओ\s+टी'): 'kot',
      RegExp(r'किचन|रसोई'): 'kitchen',
      RegExp(r'बिल|पर्ची'): 'bill',
      RegExp(r'प्रिंट'): 'print',
      RegExp(r'सेटल'): 'settle',
      RegExp(r'पेमेंट|हिसाब'): 'payment',
      RegExp(r'डिस्काउंट|छूट'): 'discount',
      RegExp(r'प्रतिशत|परसेंट'): 'percent',
      RegExp(r'रुपये|रुपए|रु\.'): 'rs',
      RegExp(r'कार्ट'): 'cart',
      RegExp(r'ऑर्डर|आर्डर'): 'order',
      RegExp(r'खाली'): 'clear',
      RegExp(r'कैंसिल|कैंसल|रद्द'): 'cancel',
      RegExp(r'हटा\s*दो|हटाओ|हटा'): 'hata do',
      RegExp(r'लगा\s*दो|लगाओ|लगा'): 'laga do',
      RegExp(r'डाल\s*दो|डालो|डाल'): 'daal do',
      RegExp(r'कर\s*दो|करो'): 'kar do',
      RegExp(r'बना\s*दो|बनाओ'): 'bana do',
      RegExp(r'भेज\s*दो|भेजो'): 'bhej do',
      RegExp(r'ऐड\s*करो|ऐड\s*कर\s*दो|ऐड'): 'add karo',
      RegExp(r'ग्राहक|कस्टमर'): 'customer',
      RegExp(r'नाम'): 'naam',
      RegExp(r'नंबर|फोन|मोबाइल'): 'number',
      RegExp(r'और|तथा|एवं'): 'aur',
      RegExp(r'समझ\s*गए|समझे|समझा|अंडरस्टैंड'): 'understand',
      RegExp(r'कोल्ड\s*कॉफी'): 'cold coffee',
      RegExp(r'मसाला\s*डोसा'): 'masala dosa',
      RegExp(r'पनीर\s*बटर\s*मसाला'): 'paneer butter masala',
      RegExp(r'कढ़ाई\s*पनीर|कढाई\s*पनीर'): 'kadhai paneer',
      RegExp(r'बटर\s*नान'): 'butter naan',
      RegExp(r'तंदूरी\s*रोटी'): 'tandoori roti',
      RegExp(r'दाल\s*मखनी'): 'dal makhani',
      RegExp(r'दाल\s*तड़का|दाल\s*तड़का'): 'dal tadka',
      RegExp(r'चिकन\s*बिरयानी'): 'chicken biryani',
      RegExp(r'वेज\s*बिरयानी'): 'veg biryani',
      RegExp(r'गुलाब\s*जामुन'): 'gulab jamun',
      RegExp(r'चाय'): 'chai',
      RegExp(r'कॉफी'): 'coffee',
      RegExp(r'समोसा'): 'samosa',
      RegExp(r'पिज़्ज़ा|पिज्जा'): 'pizza',
      RegExp(r'बर्गर'): 'burger',
      RegExp(r'सैंडविच'): 'sandwich',
      RegExp(r'चाउमीन|चाऊमीन'): 'chowmein',
      RegExp(r'मोमोज|मोमोज़'): 'momos',
      RegExp(r'पाव\s*भाजी'): 'pav bhaji',
      RegExp(r'छोले\s*भटूरे'): 'chhole bhature',
      RegExp(r'लस्सी'): 'lassi',
      RegExp(r'फ्रेंच\s*फ्राइज|फ्राइज'): 'french fries',
    };

    String res = text;
    for (final entry in commonHindiWords.entries) {
      res = res.replaceAll(entry.key, entry.value);
    }

    const charMap = {
      'अ': 'a', 'आ': 'aa', 'इ': 'i', 'ई': 'ee', 'उ': 'u', 'ऊ': 'oo',
      'ऋ': 'ri', 'ए': 'e', 'ऐ': 'ai', 'ओ': 'o', 'औ': 'au',
      'अं': 'an', 'अः': 'ah', 'ऑ': 'o', 'ऍ': 'e',
      'ा': 'a', 'ि': 'i', 'ी': 'i', 'ु': 'u', 'ू': 'u',
      'ृ': 'ri', 'े': 'e', 'ै': 'ai', 'ो': 'o', 'ौ': 'au',
      'ॉ': 'o', 'ॅ': 'e',
      'ं': 'n', 'ँ': 'n', 'ः': 'h', '़': '',
      'क': 'k', 'ख': 'kh', 'ग': 'g', 'घ': 'gh', 'ङ': 'ng',
      'च': 'ch', 'छ': 'chh', 'ज': 'j', 'झ': 'jh', 'ञ': 'ny',
      'ट': 't', 'ठ': 'th', 'ड': 'd', 'ढ': 'dh', 'ण': 'n',
      'त': 't', 'थ': 'th', 'द': 'd', 'ध': 'dh', 'न': 'n',
      'प': 'p', 'फ': 'f', 'ब': 'b', 'भ': 'bh', 'म': 'm',
      'य': 'y', 'र': 'r', 'ल': 'l', 'व': 'v',
      'श': 'sh', 'ष': 'sh', 'स': 's', 'ह': 'h',
      'क्ष': 'ksh', 'त्र': 'tr', 'ज्ञ': 'gy',
      'क़': 'q', 'ख़': 'kh', 'ग़': 'gh', 'ज़': 'z', 'ड़': 'r', 'ढ़': 'rh', 'फ़': 'f',
    };

    final buffer = StringBuffer();
    final len = res.length;
    for (int i = 0; i < len; i++) {
      final ch = res[i];
      final nextCh = i + 1 < len ? res[i + 1] : '';

      if (charMap.containsKey(ch)) {
        buffer.write(charMap[ch]);
        final isConsonant = RegExp(r'[\u0915-\u0939\u0958-\u095F]').hasMatch(ch);
        final isMatraOrHalant = RegExp(r'[\u093E-\u094D\u0962-\u0963]').hasMatch(nextCh);
        if (isConsonant && !isMatraOrHalant && nextCh.isNotEmpty && !RegExp(r'\s').hasMatch(nextCh) && RegExp(r'[\u0915-\u0939]').hasMatch(nextCh)) {
          buffer.write('a');
        }
      } else if (ch == '्') {
        // Halant
      } else {
        buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// Levenshtein distance between two strings
  static int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        int cost = (a[i] == b[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((curr, next) => curr < next ? curr : next);
      }
      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[b.length];
  }

  /// Token Jaccard similarity score (0.0 to 1.0)
  static double _tokenSimilarity(String query, String target) {
    final qTokens = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet();
    final tTokens = target.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet();
    if (qTokens.isEmpty || tTokens.isEmpty) return 0.0;

    double intersection = 0.0;
    for (final q in qTokens) {
      if (tTokens.contains(q)) {
        intersection += 1.0;
      } else {
        for (final t in tTokens) {
          if (t.contains(q) || q.contains(t)) {
            intersection += 0.8;
            break;
          }
        }
      }
    }
    final union = qTokens.union(tTokens).length;
    return union > 0 ? (intersection / union).clamp(0.0, 1.0) : 0.0;
  }

  /// 5-Tier Smart Product Matcher against live menu
  static MenuItemModel? _fuzzyMatchProduct(String query, List<MenuItemModel> menuItems) {
    if (query.trim().isEmpty || menuItems.isEmpty) return null;
    final cleanQuery = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').trim();
    if (cleanQuery.isEmpty) return null;

    // 1. Exact Name match
    for (final item in menuItems) {
      final cleanName = item.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').trim();
      if (cleanName == cleanQuery) return item;
    }

    // 2. Alias match
    for (final item in menuItems) {
      for (final alias in item.aliases) {
        final cleanAlias = alias.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').trim();
        if (cleanAlias == cleanQuery) return item;
      }
    }

    // 3. Substring match
    for (final item in menuItems) {
      final cleanName = item.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').trim();
      if (cleanName.contains(cleanQuery) || cleanQuery.contains(cleanName)) return item;
      for (final alias in item.aliases) {
        final cleanAlias = alias.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').trim();
        if (cleanAlias.contains(cleanQuery) || cleanQuery.contains(cleanAlias)) return item;
      }
    }

    // 4. Token Jaccard + Levenshtein distance combined score
    MenuItemModel? bestMatch;
    double bestScore = 0.0;

    for (final item in menuItems) {
      final cleanName = item.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').trim();
      final jaccard = _tokenSimilarity(cleanQuery, cleanName);
      final maxLen = cleanQuery.length > cleanName.length ? cleanQuery.length : cleanName.length;
      final levDist = _levenshteinDistance(cleanQuery, cleanName);
      final levScore = maxLen > 0 ? (1.0 - levDist / maxLen).clamp(0.0, 1.0) : 0.0;
      double score = (jaccard * 0.6) + (levScore * 0.4);

      for (final alias in item.aliases) {
        final cleanAlias = alias.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').trim();
        final aJaccard = _tokenSimilarity(cleanQuery, cleanAlias);
        final aMaxLen = cleanQuery.length > cleanAlias.length ? cleanQuery.length : cleanAlias.length;
        final aLevDist = _levenshteinDistance(cleanQuery, cleanAlias);
        final aLevScore = aMaxLen > 0 ? (1.0 - aLevDist / aMaxLen).clamp(0.0, 1.0) : 0.0;
        final aScore = (aJaccard * 0.6) + (aLevScore * 0.4);
        if (aScore > score) score = aScore;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }

    if (bestScore >= 0.55 && bestMatch != null) {
      return bestMatch;
    }

    return null;
  }

  /// Fast local parsing fallback matching dynamically against in-memory DatabaseService menu
  ChotuParsedCommand _localParseCommand(String text, String? table) {
    final normalized = _localNormalize(text);
    final lower = normalized.toLowerCase();
    final db = DatabaseService();

    // 1. Extract table number
    String? resolvedTable = table;
    final tblMatch = RegExp(r'\b(?:table|tbl|t|mez)\s*[-#]?\s*(\d+)\b', caseSensitive: false).firstMatch(normalized);
    if (tblMatch != null) {
      resolvedTable = tblMatch.group(1);
    }

    // 2. Classify Intent

    // A. Send KOT / Print KOT
    if ((RegExp(r'\b(kot|kitchen|kitchin)\b', caseSensitive: false).hasMatch(lower) &&
        RegExp(r'\b(bhej|print|laga|daal|generate|send|karo|do|nikal)\b', caseSensitive: false).hasMatch(lower)) ||
        lower.contains('kot print') || lower.contains('print kot') || lower.contains('kitchen order') || lower.contains('kot nikalo')) {
      return ChotuParsedCommand(
        intent: 'SEND_KOT',
        tableNumber: resolvedTable,
        confidence: 0.98,
        chotuResponse: resolvedTable != null
            ? 'Table $resolvedTable ka KOT kitchen mein bhej diya sir.'
            : 'KOT kitchen mein bhej diya sir.',
      );
    }

    // B. Bill / Save & Print / Settle Order / Checkout / Payment
    if (lower.contains('bill print') || lower.contains('print bill') || lower.contains('settle order') || lower.contains('settle') ||
        lower.contains('save and print') || lower.contains('save & print') || lower.contains('checkout') ||
        ((lower.contains('bill') || lower.contains('payment') || lower.contains('paisa') || lower.contains('hisab')) &&
         (lower.contains('bana') || lower.contains('print') || lower.contains('generate') || lower.contains('karo') || lower.contains('do') || lower.contains('nikal') || lower.contains('le') || lower.contains('settle')))) {
      return ChotuParsedCommand(
        intent: 'GENERATE_BILL',
        tableNumber: resolvedTable,
        confidence: 0.98,
        chotuResponse: resolvedTable != null
            ? 'Table $resolvedTable ka bill generate kar diya sir.'
            : 'Bill generate kar diya sir.',
      );
    }

    // C. Clear Cart / Cancel Order
    if ((lower.contains('clear') || lower.contains('cancel') || lower.contains('khali') || lower.contains('hata')) &&
        (lower.contains('cart') || lower.contains('sab') || lower.contains('poora') || lower.contains('all') || lower.contains('order')) &&
        !lower.contains('butter') && !lower.contains('naan') && !lower.contains('paneer') && !lower.contains('roti')) {
      return ChotuParsedCommand(
        intent: 'CLEAR_CART',
        tableNumber: resolvedTable,
        confidence: 0.98,
        chotuResponse: resolvedTable != null
            ? 'Table $resolvedTable ka cart clear kar diya sir.'
            : 'Cart clear kar diya gaya hai sir.',
      );
    }

    // D. Apply Discount
    if (lower.contains('discount') || lower.contains('off') || lower.contains('chhoot') || lower.contains('coupon')) {
      double discountVal = 0.0;
      String discountType = 'percent';

      final percentMatch = RegExp(r'(\d+)\s*(?:percent|%|pratishat)', caseSensitive: false).firstMatch(lower);
      final flatMatch = RegExp(r'(?:rupaye|rs|inr|₹)\s*(\d+)|(\d+)\s*(?:rupaye|rs|inr|₹|ka\s+discount)', caseSensitive: false).firstMatch(lower);

      if (percentMatch != null) {
        discountVal = double.tryParse(percentMatch.group(1)!) ?? 0.0;
        discountType = 'percent';
      } else if (flatMatch != null) {
        discountVal = double.tryParse(flatMatch.group(1) ?? flatMatch.group(2) ?? '0') ?? 0.0;
        discountType = 'flat';
      } else {
        final simpleNum = RegExp(r'\b(\d+)\b').firstMatch(lower);
        if (simpleNum != null) {
          discountVal = double.tryParse(simpleNum.group(1)!) ?? 0.0;
          discountType = discountVal <= 100 ? 'percent' : 'flat';
        }
      }

      final isRemove = lower.contains('hata') || lower.contains('remove') || lower.contains('zero') || discountVal == 0;

      return ChotuParsedCommand(
        intent: 'APPLY_DISCOUNT',
        tableNumber: resolvedTable,
        discountValue: isRemove ? 0.0 : discountVal,
        discountType: discountType,
        isRemoveDiscount: isRemove,
        confidence: 0.95,
        chotuResponse: isRemove
            ? 'Discount hata diya gaya hai sir.'
            : '${discountVal.toStringAsFixed(0)}${discountType == 'percent' ? '%' : '₹'} discount apply kar diya sir.',
      );
    }

    // E. Customer Details
    if ((lower.contains('customer') || lower.contains('grahak')) &&
        (lower.contains('naam') || lower.contains('name') || lower.contains('number') || lower.contains('phone') || lower.contains('mobile'))) {
      final phoneMatch = RegExp(r'\b([6-9]\d{9})\b').firstMatch(normalized);
      final customerPhone = phoneMatch?.group(1);

      final nameMatch = RegExp(r'(?:customer|grahak)?\s*(?:ka\s+)?(?:naam|name)\s*(?:is|hai)?\s*([a-zA-Z]+)', caseSensitive: false).firstMatch(normalized);
      final customerName = nameMatch?.group(1);

      return ChotuParsedCommand(
        intent: 'SET_CUSTOMER_DETAILS',
        customerName: customerName,
        customerPhone: customerPhone,
        tableNumber: resolvedTable,
        confidence: 0.95,
        chotuResponse: (customerName != null || customerPhone != null)
            ? 'Customer ${customerName ?? customerPhone} details save kar di sir.'
            : 'Customer details save kar di sir.',
      );
    }

    // F. Order Type (Takeaway / Delivery / Dine In)
    if ((lower.contains('takeaway') || lower.contains('take away') || lower.contains('delivery') || lower.contains('dine in') || lower.contains('parcel')) &&
        (lower.contains('order') || lower.contains('kar') || lower.contains('karo') || lower.contains('hai'))) {
      String orderType = 'dineIn';
      if (lower.contains('takeaway') || lower.contains('take away') || lower.contains('parcel')) {
        orderType = 'takeaway';
      } else if (lower.contains('delivery')) {
        orderType = 'delivery';
      }

      final label = orderType == 'takeaway' ? 'Takeaway' : (orderType == 'delivery' ? 'Delivery' : 'Dine In');
      return ChotuParsedCommand(
        intent: 'SET_ORDER_TYPE',
        orderType: orderType,
        tableNumber: resolvedTable,
        confidence: 0.95,
        chotuResponse: 'Order type $label set kar diya sir.',
      );
    }

    // G. Switch Table
    if ((lower.contains('switch') || lower.contains('select') || lower.contains('open') || lower.contains('pe jao') || lower.contains('par jao')) &&
        (lower.contains('table') || lower.contains('tbl') || lower.contains('mez')) &&
        !lower.contains('add') && !lower.contains('laga') && !lower.contains('bhej')) {
      return ChotuParsedCommand(
        intent: 'SWITCH_TABLE',
        tableNumber: resolvedTable,
        confidence: 0.98,
        chotuResponse: resolvedTable != null
            ? 'Table $resolvedTable select kar liya sir.'
            : 'Kaunsi table select karni hai sir?',
      );
    }

    // H. Update Quantity (e.g. "butter naan ko 4 kar do")
    if (RegExp(r'\b(?:ko|to)\s+(\d+)\s+(?:kar|karo|set|change)\b', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'\b(?:kar|karo|set)\s+(?:ko\s+)?(\d+)\b', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'\b(\d+)\s+(?:kar\s+do|karo)\b', caseSensitive: false).hasMatch(lower)) {
      int targetQty = 1;
      final qm = RegExp(r'\b(?:ko\s+|to\s+)?(\d+)\s*(?:kar|karo|set|pieces|plate)?\b', caseSensitive: false).firstMatch(lower);
      if (qm != null) {
        targetQty = int.tryParse(qm.group(1)!) ?? 1;
      }

      final cleanProd = lower
          .replaceAll(RegExp(r'\b(?:table|tbl)\s*\d+\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b(pe|mein|ko|to|kar|karo|do|set|quantity|qty|plate|pieces)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b\d+\b'), '')
          .trim();

      final matchedItem = _fuzzyMatchProduct(cleanProd, db.menuItems);
      final pName = matchedItem?.name ?? cleanProd;

      return ChotuParsedCommand(
        intent: 'UPDATE_QUANTITY',
        tableNumber: resolvedTable,
        quantity: targetQty,
        items: [
          ChotuCommandItem(
            productId: matchedItem?.id,
            productName: pName,
            quantity: targetQty,
            price: matchedItem?.price ?? 0.0,
            matched: matchedItem != null,
          ),
        ],
        confidence: matchedItem != null ? 0.95 : 0.70,
        chotuResponse: 'Table ${resolvedTable ?? ""} mein $pName ki quantity $targetQty set kar di sir.',
      );
    }

    // I. Remove Item (e.g. "butter naan hata do", "1 chai cancel karo")
    if (lower.contains('hata do') || lower.contains('hatao') || lower.contains('remove') ||
        lower.contains('delete') || lower.contains('kam kar do') || lower.contains('nikal do') || lower.contains('cancel karo')) {
      int removeQty = 1;
      final qm = RegExp(r'\b(\d+)\s+([a-zA-Z\s]+?)\s+(?:hata|remove|kam|nikal|cancel)\b', caseSensitive: false).firstMatch(lower);
      if (qm != null) {
        removeQty = int.tryParse(qm.group(1)!) ?? 1;
      }

      final cleanProd = lower
          .replaceAll(RegExp(r'\b(?:table|tbl)\s*\d+\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b(se|mein|pe|ek|do|hata|hatao|do|remove|delete|kam|kar|nikal|cancel|plate)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b\d+\b'), '')
          .trim();

      final matchedItem = _fuzzyMatchProduct(cleanProd, db.menuItems);
      final pName = matchedItem?.name ?? cleanProd;

      return ChotuParsedCommand(
        intent: 'REMOVE_ITEM',
        tableNumber: resolvedTable,
        quantity: removeQty,
        items: [
          ChotuCommandItem(
            productId: matchedItem?.id,
            productName: pName,
            quantity: removeQty,
            price: matchedItem?.price ?? 0.0,
            matched: matchedItem != null,
          ),
        ],
        confidence: matchedItem != null ? 0.95 : 0.70,
        chotuResponse: 'Table ${resolvedTable ?? ""} se $pName remove kar diya sir.',
      );
    }

    // J. Add Item (Default & Dynamic)
    final items = <ChotuCommandItem>[];

    // Clean text by stripping table prefix/suffix and action verbs
    String contentStr = normalized
        .replaceAll(RegExp(r'\b(?:table|tbl|mez)\s*[-#]?\s*\d+\s*(?:pe|mein|par|to|for)?\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:laga|lagao|kar|karo|bhej|rakh)\s+do\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:add\s+karo|add\s+kar\s+do|add|chahiye|de\s+do)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(?:aur\s+add\s+karo|bhi\s+add\s+karo|bhi)\b', caseSensitive: false), ' ')
        .trim();

    // Split multi-dish phrases joined by 'aur', 'and', '+', '&', or comma
    final phrases = contentStr.split(RegExp(r'\b(?:aur|and|\+|&)\b|,', caseSensitive: false));

    for (final p in phrases) {
      final phrase = p.trim();
      if (phrase.isEmpty) continue;

      int qty = 1;
      String prodName = phrase;

      final numMatch = RegExp(r'^(\d+)\s+(.+)$').firstMatch(phrase) ?? RegExp(r'^(.+?)\s+(\d+)$').firstMatch(phrase);
      if (numMatch != null) {
        if (RegExp(r'^\d+$').hasMatch(numMatch.group(1)!)) {
          qty = int.tryParse(numMatch.group(1)!) ?? 1;
          prodName = numMatch.group(2)!.trim();
        } else {
          qty = int.tryParse(numMatch.group(2)!) ?? 1;
          prodName = numMatch.group(1)!.trim();
        }
      }

      // Strip units like plate, piece, cup, bottle
      prodName = prodName
          .replaceAll(RegExp(r'\b(plate|piece|pieces|cup|glass|bottle|order|item)\b', caseSensitive: false), '')
          .trim();

      if (prodName.isEmpty) continue;

      final matched = _fuzzyMatchProduct(prodName, db.menuItems);
      if (matched != null) {
        items.add(ChotuCommandItem(
          productId: matched.id,
          productName: matched.name,
          quantity: qty,
          price: matched.price,
          salePrice: matched.salePrice,
          foodType: matched.itemType.toLowerCase(),
          matched: true,
          confidence: 0.95,
        ));
      } else {
        // Dynamic addition for arbitrary/custom spoken items
        items.add(ChotuCommandItem(
          productId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
          productName: prodName,
          quantity: qty,
          price: 0.0,
          matched: true,
          confidence: 0.85,
        ));
      }
    }

    final itemSummary = items.map((i) => '${i.productName} × ${i.quantity}').join(' aur ');
    final chotuReply = items.isNotEmpty
        ? (resolvedTable != null
            ? 'Table $resolvedTable mein $itemSummary add kar diya sir.'
            : '$itemSummary add kar diya sir.')
        : 'Item samajh nahi aaya sir.';

    return ChotuParsedCommand(
      intent: 'ADD_ITEM',
      tableNumber: resolvedTable,
      tableContextMissing: resolvedTable == null,
      items: items,
      confidence: items.isNotEmpty ? 0.95 : 0.40,
      chotuResponse: chotuReply,
    );
  }

  /// Fast local number normalization for offline fallback
  String _localNormalize(String text) {
    String clean = text.trim();

    // 1. Normalize Devanagari numerals (०-९)
    const devanagariDigits = {
      '०': '0', '१': '1', '२': '2', '३': '3', '४': '4',
      '५': '5', '६': '6', '७': '7', '८': '8', '९': '9'
    };
    clean = clean.replaceAllMapped(RegExp(r'[०-९]'), (m) => devanagariDigits[m.group(0)!] ?? m.group(0)!);

    // 2. Normalize Devanagari number words
    final devanagariNumberWords = {
      RegExp(r'\b(सौ|एक\s+सौ)\b'): '100',
      RegExp(r'\b(पचास|पचाास)\b'): '50',
      RegExp(r'\b(पैंतीस|पैंतेंस)\b'): '35',
      RegExp(r'\b(चालीस|चालिस)\b'): '40',
      RegExp(r'\b(तीस)\b'): '30',
      RegExp(r'\b(पच्चीस|पचीस)\b'): '25',
      RegExp(r'\b(बीस|बिस)\b'): '20',
      RegExp(r'\b(उन्नीस|उनीस)\b'): '19',
      RegExp(r'\b(अठारह|अठारा)\b'): '18',
      RegExp(r'\b(सत्रह|सत्रा)\b'): '17',
      RegExp(r'\b(सोलह|सोला)\b'): '16',
      RegExp(r'\b(पंद्रह|पंदरा)\b'): '15',
      RegExp(r'\b(चौदह|चौदा)\b'): '14',
      RegExp(r'\b(तेरह|तेरा)\b'): '13',
      RegExp(r'\b(बारह|बारा)\b'): '12',
      RegExp(r'\b(ग्यारह|ग्यारा)\b'): '11',
      RegExp(r'\b(दस|दश)\b'): '10',
      RegExp(r'\b(नौ)\b'): '9',
      RegExp(r'\b(आठ)\b'): '8',
      RegExp(r'\b(सात)\b'): '7',
      RegExp(r'\b(छह|छः|छे)\b'): '6',
      RegExp(r'\b(पांच|पाँच)\b'): '5',
      RegExp(r'\b(चार)\b'): '4',
      RegExp(r'\b(तीन)\b'): '3',
      RegExp(r'\b(दो)\b'): '2',
      RegExp(r'\b(एक)\b'): '1',
    };
    for (final entry in devanagariNumberWords.entries) {
      clean = clean.replaceAll(entry.key, entry.value);
    }

    // 3. Transliterate Devanagari Hindi text to Roman
    clean = _transliterateDevanagari(clean);

    // 4. Protect Hindi imperative verbs ending in 'do'
    final verbDoMap = <String, String>{};
    clean = clean.replaceAllMapped(
      RegExp(r'\b(laga|kar|bana|hata|de|bhej|daal|rakh|nikal|le)\s+do\b', caseSensitive: false),
      (match) {
        final placeholder = '__VERB_${verbDoMap.length}__';
        verbDoMap[placeholder] = match.group(0)!;
        return placeholder;
      },
    );

    // 5. Normalize Hindi & English numerals
    final numberMap = {
      RegExp(r'\b(sau|ek\s+sau|one\s+hundred|hundred)\b', caseSensitive: false): '100',
      RegExp(r'\b(pachaas|pachas|fifty)\b', caseSensitive: false): '50',
      RegExp(r'\b(paintees|pentees|thirty\s*five)\b', caseSensitive: false): '35',
      RegExp(r'\b(chalis|chaalis|forty)\b', caseSensitive: false): '40',
      RegExp(r'\b(tees|thirty)\b', caseSensitive: false): '30',
      RegExp(r'\b(pachees|pachis|twenty\s*five)\b', caseSensitive: false): '25',
      RegExp(r'\b(bees|bis|twenty)\b', caseSensitive: false): '20',
      RegExp(r'\b(unnis|unees|nineteen)\b', caseSensitive: false): '19',
      RegExp(r'\b(atharah|athara|eighteen)\b', caseSensitive: false): '18',
      RegExp(r'\b(satrah|satra|seventeen)\b', caseSensitive: false): '17',
      RegExp(r'\b(solah|sola|sixteen)\b', caseSensitive: false): '16',
      RegExp(r'\b(pandrah|pandra|fifteen)\b', caseSensitive: false): '15',
      RegExp(r'\b(chaudah|chauda|fourteen)\b', caseSensitive: false): '14',
      RegExp(r'\b(terah|tera|thirteen)\b', caseSensitive: false): '13',
      RegExp(r'\b(barah|baarah|twelve)\b', caseSensitive: false): '12',
      RegExp(r'\b(gyarah|gyara|eleven)\b', caseSensitive: false): '11',
      RegExp(r'\b(das|dus|ten)\b', caseSensitive: false): '10',
      RegExp(r'\b(nau|no|nine)\b', caseSensitive: false): '9',
      RegExp(r'\b(aath|ath|eight)\b', caseSensitive: false): '8',
      RegExp(r'\b(saat|sat|seven)\b', caseSensitive: false): '7',
      RegExp(r'\b(chhah|che|chhe|six)\b', caseSensitive: false): '6',
      RegExp(r'\b(paanch|panch|five)\b', caseSensitive: false): '5',
      RegExp(r'\b(chaar|char|four)\b', caseSensitive: false): '4',
      RegExp(r'\b(teen|tin|three)\b', caseSensitive: false): '3',
      RegExp(r'\b(do|too|two)\b', caseSensitive: false): '2',
      RegExp(r'\b(ek|ik|one)\b', caseSensitive: false): '1',
    };
    for (final entry in numberMap.entries) {
      clean = clean.replaceAll(entry.key, entry.value);
    }

    // 6. Restore verbal 'do' phrases
    for (final entry in verbDoMap.entries) {
      clean = clean.replaceAll(entry.key, entry.value);
    }

    // 7. Filter background voices, filler artifacts, and conversational chatter
    clean = clean
        .replaceAll(RegExp(r'\b(umm+|ahh+|uhh+|hmmm+|hmm|arre\s+yaar|arre|suno|sun|chotu\s+sun|chotu|kripya|please)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(understand|understood|samjhe|samajh\s*gaye|samjh\s*gaye|samjha|samjh)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[(?:noise|music|laughter|applause|cough|throat-clearing)\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return clean;
  }

  void clearHistory() {
    _history.clear();
    _lastResult = null;
    _lastParsedCommand = null;
    notifyListeners();
  }
}

