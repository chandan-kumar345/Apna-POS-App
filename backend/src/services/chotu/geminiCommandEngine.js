const { GoogleGenAI } = require('@google/genai');
const env = require('../../config/env');

/**
 * Gemini Command Engine for Chotu AI Voice Assistant
 * Grounded on the restaurant's live POS menu and tables.
 * Understands natural Hindi, Hinglish, and English voice commands.
 */
class GeminiCommandEngine {
  /**
   * Check if Gemini API key is configured in environment
   */
  static isConfigured() {
    const key = (env.GEMINI_API_KEY || process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || '').trim();
    return key.length > 0;
  }

  /**
   * Get active Gemini API key
   */
  static getApiKey() {
    return (env.GEMINI_API_KEY || process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || '').trim();
  }

  /**
   * Parses natural voice command into structured POS action using Gemini
   * @param {Object} params
   * @param {string} params.text - Transcribed voice string (Hindi, Hinglish, English)
   * @param {Array<Object>} params.availableProducts - Live restaurant products
   * @param {Array<Object>} [params.availableTables] - Live restaurant tables
   * @param {string|null} [params.currentTableContext] - Active table in POS
   * @param {Object|null} [params.sessionContext] - Multi-turn conversational memory
   * @returns {Promise<Object|null>} Structured Chotu command JSON or null
   */
  static async parseCommandWithGemini({
    text,
    availableProducts = [],
    availableTables = [],
    currentTableContext = null,
    sessionContext = null,
    apiKey = null,
  }) {
    const activeApiKey = (apiKey || this.getApiKey() || '').trim();
    if (!activeApiKey) return null;

    if (!text || typeof text !== 'string' || !text.trim()) {
      return null;
    }

    const aiClient = new GoogleGenAI({ apiKey: activeApiKey });

    // 1. Build compact live menu representation
    const compactMenu = availableProducts.map((p) => {
      const itemObj = {
        id: p.id || (p._id ? p._id.toString() : p.productId),
        name: p.name,
        price: p.price || 0,
        category: p.category || 'General',
        foodType: p.foodType || 'veg',
      };
      if (Array.isArray(p.variants) && p.variants.length > 0) {
        itemObj.variants = p.variants.map((v) => ({
          name: v.name,
          price: v.salePrice > 0 ? v.salePrice : v.price,
        }));
      }
      if (Array.isArray(p.aliases) && p.aliases.length > 0) {
        itemObj.aliases = p.aliases;
      }
      return itemObj;
    });

    // 2. Build compact tables list
    const tableList = availableTables.map((t) => ({
      tableNumber: t.tableNumber,
      name: t.name,
      status: t.status,
    }));

    // 3. Build Active Context
    const activeTable = currentTableContext || sessionContext?.tableNumber || null;

    // 4. Construct System Instruction with POS Training
    const systemInstruction = `
You are Chotu AI, the intelligent, fast, and friendly voice assistant built into Apna POS for Indian restaurants and cafes.
Your task is to convert spoken natural language orders (in Hindi, Hinglish, or English) into precise, structured POS command JSON.

GROUND TRUTH LIVE DATA:
1. RESTAURANT MENU CATALOG:
${JSON.stringify(compactMenu, null, 1)}

2. RESTAURANT TABLES:
${JSON.stringify(tableList)}

3. ACTIVE POS CONTEXT:
- Currently Selected Table: ${activeTable ? activeTable : 'None'}
- Previous Session Table: ${sessionContext?.tableNumber ? sessionContext.tableNumber : 'None'}

SUPPORTED POS INTENTS:
1. "ADD_ITEM": Adding one or more food/drink items to a table cart.
   - Handles Hindi numbers: ek (1), do (2), teen (3), chaar (4), paanch (5), chhah (6), saat (7), aath (8), nau (9), das (10), etc.
   - Handles multi-item orders: e.g. "Table 4 pe do butter naan aur ek dal makhani laga do".
   - Handles portion/size variants: e.g. "half", "full", "small", "medium", "large", "300ml". If a product has variants, pick the matching variant and its exact price.
   - Handles cooking/dietary modifiers: e.g. "bina pyaz", "extra spicy", "kam namak", "extra butter", "crispy", "without garlic".
2. "REMOVE_ITEM": Removing or reducing quantity of an existing item from table cart.
   - e.g. "Table 4 se ek butter naan hata do", "dal makhani cancel karo".
3. "UPDATE_QUANTITY": Changing quantity of an existing cart item to an exact number.
   - e.g. "Butter naan 4 kar do", "table 2 mein chai 3 kar do".
4. "SEND_KOT": Sending / printing Kitchen Order Ticket (KOT) to the kitchen.
   - e.g. "Table 5 ka KOT bhej do", "KOT print karo", "kitchen mein order send karo".
5. "GENERATE_BILL": Generating / printing customer bill or invoice for checkout.
   - e.g. "Table 5 ka bill banao", "bill print kar do", "hisab karo".
6. "CLEAR_CART": Clearing all items from the table cart.
   - e.g. "Table 5 ka cart clear kar do", "table khali karo".
7. "APPLY_DISCOUNT": Applying percentage or flat discount on table order.
   - e.g. "10% discount laga do", "50 rupaye discount de do".
8. "SWITCH_TABLE": Switching the active screen table.
   - e.g. "Table 3 pe chalo", "Table 5 select karo".
9. "SET_CUSTOMER_DETAILS": Attaching customer name and 10-digit phone number.
   - e.g. "Customer ka naam Rohit aur phone 9876543210 hai".
10. "SET_ORDER_TYPE": Setting order type to "dineIn", "takeaway" (parcel), or "delivery".
   - e.g. "Parcel pack kar do", "Delivery order banao".
11. "CHECK_ITEM_AVAILABILITY": Checking if a product is in stock / available.
   - e.g. "Kya cold coffee available hai?", "Butter naan hai kya?".
12. "VIEW_TABLE_ORDER": Viewing or displaying active table order.
   - e.g. "Table 4 ka order dikhao".

STRICT GROUNDING & MAPPING RULES:
- ALWAYS match item names against the provided RESTAURANT MENU CATALOG.
- Find the closest matching product from the catalog. Use product name, aliases, or category.
- When an item is matched from the catalog, populate "product_id" with the catalog item's "id", "product_name" with the exact catalog name, and "price" with catalog price (or variant price). Set "matched": true.
- If the customer asks for an item that is COMPLETELY MISSING from the catalog, set "matched": false, "product_id": null, and set "price": 0.
- Table Resolution:
  - If a table is explicitly mentioned in speech (e.g. "Table 4 pe..."), extract that table number (e.g. "4").
  - If no table is mentioned in speech, use the ACTIVE POS CONTEXT table.
  - If still unknown, set "table_number": null and "table_context_missing": true.
- "chotu_response": Write a warm, natural, short Hindi/Hinglish voice confirmation line that Chotu will speak aloud:
  - For ADD_ITEM: "Table [N] mein [Qty] [Item] add kar diya sir."
  - For SEND_KOT: "Table [N] ka KOT kitchen mein bhej diya sir."
  - For GENERATE_BILL: "Table [N] ka bill generate kar diya sir."
  - For CLEAR_CART: "Table [N] ka cart clear kar diya gaya hai sir."
  - For missing item: "Ye item menu mein nahi mila: [Name]."

REQUIRED JSON OUTPUT SCHEMA:
{
  "intent": "ADD_ITEM",
  "table_number": "4",
  "table_context_missing": false,
  "items": [
    {
      "product_id": "PRD-101",
      "product_name": "Butter Naan",
      "quantity": 2,
      "price": 45,
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
Only output valid JSON. Do not wrap in markdown or backticks.
`;

    // 5. Execute Gemini call with fast timeout race
    const candidateModels = ['gemini-3.8-flash', 'gemini-3.5-flash-lite', 'gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash'];

    for (const model of candidateModels) {
      try {
        const geminiPromise = aiClient.models.generateContent({
          model,
          contents: [
            {
              role: 'user',
              parts: [{ text: text.trim() }],
            },
          ],
          config: {
            systemInstruction: {
              parts: [{ text: systemInstruction }],
            },
            temperature: 0.1,
            responseMimeType: 'application/json',
          },
        });

        // 4.5 second timeout to keep voice UX fast and snappy
        const timeoutPromise = new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Gemini voice parsing timed out (4500ms)')), 4500)
        );

        const response = await Promise.race([geminiPromise, timeoutPromise]);
        const responseText = response?.text?.trim() || '';

        if (!responseText) continue;

        // Clean any accidental markdown backticks
        const cleanJsonStr = responseText
          .replace(/^```json\s*/i, '')
          .replace(/^```\s*/i, '')
          .replace(/\s*```$/i, '')
          .trim();

        const parsed = JSON.parse(cleanJsonStr);

        if (parsed && parsed.intent) {
          // Normalize table number if needed
          if (parsed.table_number) {
            parsed.table_number = parsed.table_number.toString().replace(/[^0-9]/g, '');
          }

          // Ensure items is always an array
          if (!Array.isArray(parsed.items)) {
            parsed.items = [];
          }

          // Fill default fallback response if empty
          if (!parsed.chotu_response) {
            parsed.chotu_response = parsed.table_number
              ? `Table ${parsed.table_number} command execute ho gaya sir.`
              : 'Command execute ho gaya sir.';
          }

          return parsed;
        }
      } catch (err) {
        console.warn(`[GeminiCommandEngine] Attempt with '${model}' notice:`, err.message);
      }
    }

    return null;
  }
}

module.exports = GeminiCommandEngine;
