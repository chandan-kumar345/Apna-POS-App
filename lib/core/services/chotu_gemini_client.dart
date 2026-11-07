import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../database/database_service.dart';
import '../models/order_model.dart';
import 'chotu_service.dart';

class ChotuGeminiClient {
  static final ChotuGeminiClient _instance = ChotuGeminiClient._internal();
  factory ChotuGeminiClient() => _instance;
  ChotuGeminiClient._internal();

  /// Candidate Gemini models in priority order (Current fast flash models)
  static const List<String> _candidateModels = [
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
  ];

  /// Checks if Gemini API key is configured
  bool isConfigured([String? customKey]) {
    final key = (customKey ?? DatabaseService().chotuGeminiApiKey).trim();
    return key.isNotEmpty;
  }

  /// Parses spoken natural language using Google Gemini REST API directly
  Future<ChotuParsedCommand?> parseWithGemini({
    required String speechText,
    String? tableNumber,
    String? apiKey,
    List<Map<String, String>>? conversationHistory,
  }) async {
    final key = (apiKey ?? DatabaseService().chotuGeminiApiKey).trim();
    if (key.isEmpty) {
      debugPrint('[ChotuGeminiClient] No Gemini API key provided');
      return null;
    }

    final cleanText = speechText.trim();
    if (cleanText.isEmpty) return null;

    final db = DatabaseService();
    final activeTable = tableNumber ?? db.selectedTable ?? '1';

    // 1. Build compact live menu representation
    final compactMenu = db.menuItems.map((p) {
      return {
        'id': p.id,
        'productId': p.productId,
        'name': p.name,
        'price': p.price,
        'category': p.category,
        'foodType': p.isVeg ? 'veg' : 'non-veg',
        'isAvailable': p.isAvailable,
      };
    }).toList();

    // 2. Build compact table list
    final compactTables = db.tables.map((t) {
      return {
        'name': t.name,
        'number': t.tableNumber,
        'status': t.status.name,
      };
    }).toList();

    // 3. Build current cart on the table
    final currentCart = db.getLiveTableCart(activeTable).map((ci) {
      return {
        'name': ci.item.name,
        'quantity': ci.quantity,
        'price': ci.item.price,
      };
    }).toList();

    // 4. Construct System Instruction with POS grounding & conversational rules
    final systemPrompt = '''
You are Chotu AI, the intelligent, friendly, and lightning-fast voice assistant built into Apna POS for Indian restaurants, cafes, and dhabas.
You take orders accurately AND talk warmly with the cashier or customer in natural Hindi, Hinglish, or English.

GROUND TRUTH LIVE RESTAURANT DATA:
1. MENU CATALOG:
${jsonEncode(compactMenu)}

2. TABLES:
${jsonEncode(compactTables)}

3. ACTIVE POS CONTEXT:
- Active Table: "$activeTable"
- Current Cart on Table $activeTable: ${jsonEncode(currentCart)}

SUPPORTED INTENTS:
1. "ADD_ITEM": When the user wants to add food or drink items to a table.
   - Extracts item names, quantities (1, 2, 3, ek, do, teen, chaar, paanch, etc.), variants (half, full, small, large), and modifiers (extra spicy, bina pyaz, less salt, extra butter, etc.).
   - Matches item names against the MENU CATALOG. Sets product_id and price from the matched menu item.
   - If item is missing from menu, set matched: false, product_id: null.
2. "REMOVE_ITEM": Removing or reducing items from the table cart.
3. "UPDATE_QUANTITY": Changing item quantity (e.g. "Butter Naan 4 kar do").
4. "SEND_KOT": Printing or sending Kitchen Order Ticket to kitchen (e.g. "KOT bhej do", "kitchen mein send karo").
5. "GENERATE_BILL": Generating customer bill or bill settlement (e.g. "Table 4 ka bill banao", "hisab karo").
6. "CLEAR_CART": Clearing table cart (e.g. "Table clear kar do").
7. "APPLY_DISCOUNT": Applying percent or flat discount (e.g. "10% discount laga do").
8. "SWITCH_TABLE": Switching to another table (e.g. "Table 3 pe jao").
9. "SET_CUSTOMER_DETAILS": Attaching customer name or phone number.
10. "SET_ORDER_TYPE": dineIn, takeaway, or delivery.
11. "CHECK_ITEM_AVAILABILITY": Checking if an item is available.
12. "VIEW_TABLE_ORDER": Checking current order on a table.
13. "CHAT": When the user talks with Chotu, greets Chotu, asks menu suggestions, chef recommendations, general questions, jokes, or chit-chat.
    - Examples:
      * "Namaste Chotu kaise ho?" -> intent: "CHAT", chotu_response: "Namaste sir! Main badhiya hoon. Boliye aaj kya order lena hai?"
      * "Menu mein kya special hai?" -> intent: "CHAT", chotu_response: "Sir hamare yahan ke top items bohot popular hain! Kya aapke liye kuch special laga du?"
      * "Aap kya kya kar sakte ho?" -> intent: "CHAT", chotu_response: "Sir main table orders add kar sakta hoon, bill bana sakta hoon, KOT bhej sakta hoon aur menu ki jankari de sakta hoon."
      * "Table $activeTable ka total kitna hua?" -> intent: "CHAT", chotu_response: "Sir Table $activeTable ka live hisab screen par update hai. Bill banane ke liye 'bill banao' bol sakte hain."
      * "Thank you Chotu" -> intent: "CHAT", chotu_response: "You're welcome sir! Khana enjoy kijiye!"

RULES FOR "chotu_response":
- Always write a warm, respectful, short, natural Hindi/Hinglish voice line that Chotu will speak aloud.
- Keep responses concise (1 to 2 short sentences) so voice synthesis is fast and snappy.

REQUIRED STRICT JSON OUTPUT SCHEMA:
{
  "intent": "ADD_ITEM" or "REMOVE_ITEM" or "UPDATE_QUANTITY" or "SEND_KOT" or "GENERATE_BILL" or "CLEAR_CART" or "APPLY_DISCOUNT" or "SWITCH_TABLE" or "SET_CUSTOMER_DETAILS" or "SET_ORDER_TYPE" or "CHECK_ITEM_AVAILABILITY" or "VIEW_TABLE_ORDER" or "CHAT",
  "table_number": "4",
  "table_context_missing": false,
  "items": [
    {
      "product_id": "PRD-101",
      "product_name": "Butter Naan",
      "quantity": 2,
      "price": 45.0,
      "sale_price": null,
      "foodType": "veg",
      "modifiers": ["extra butter"],
      "matched": true,
      "confidence": 0.98
    }
  ],
  "quantity": null,
  "discount_value": null,
  "discount_type": null,
  "is_remove": false,
  "customer_name": null,
  "customer_phone": null,
  "order_type": "dineIn",
  "ambiguity": false,
  "question": null,
  "confidence": 0.98,
  "chotu_response": "Table 4 mein 2 Butter Naan add kar diya sir."
}
Output pure JSON only. Do not add markdown codeblocks.
''';

    // 5. Try each candidate model
    for (final model in _candidateModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key',
        );

        final contents = <Map<String, dynamic>>[];
        if (conversationHistory != null && conversationHistory.isNotEmpty) {
          for (final turn in conversationHistory.take(4)) {
            contents.add({
              'role': turn['role'] == 'chotu' ? 'model' : 'user',
              'parts': [{'text': turn['message'] ?? ''}],
            });
          }
        }
        contents.add({
          'role': 'user',
          'parts': [{'text': cleanText}],
        });

        final requestPayload = {
          'system_instruction': {
            'parts': [{'text': systemPrompt}],
          },
          'contents': contents,
          'generationConfig': {
            'temperature': 0.1,
            'responseMimeType': 'application/json',
          },
        };

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestPayload),
        ).timeout(const Duration(milliseconds: 4000));

        if (response.statusCode != 200) {
          debugPrint('[ChotuGeminiClient] Model $model returned status ${response.statusCode}: ${response.body}');
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) continue;

        final firstCandidate = candidates.first as Map<String, dynamic>;
        final content = firstCandidate['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List?;
        if (parts == null || parts.isEmpty) continue;

        final rawText = parts.first['text']?.toString() ?? '';
        final cleanJson = rawText
            .replaceAll(RegExp(r'^```json\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'^```\s*'), '')
            .replaceAll(RegExp(r'\s*```$'), '')
            .trim();

        if (cleanJson.isEmpty) continue;

        final parsedMap = jsonDecode(cleanJson) as Map<String, dynamic>;
        return ChotuParsedCommand.fromMap(parsedMap);
      } catch (e) {
        debugPrint('[ChotuGeminiClient] Error with model $model: $e');
      }
    }

    return null;
  }
}
