const { normalizeSpokenText } = require('./speechProvider');
const ProductMatcher = require('./productMatcher');

/**
 * AI Command Engine for Parsing Natural Spoken Restaurant Orders
 * Converts spoken English, Hindi, and Hinglish sentences into structured POS commands.
 */
class AICommandEngine {
  /**
   * Extract table number from text or fallback to context
   */
  static extractTableNumber(text, fallbackTable = null) {
    if (!text || typeof text !== 'string') return fallbackTable ? fallbackTable.toString() : null;

    // Matches: table 5, t-5, t5, table five, table no 5, table number 5
    const tableRegex = /\b(?:table|tbl|table\s+no|table\s+number|t|mez|table\s+no\.)\s*[-#]?\s*(\d+)\b/i;
    const match = text.match(tableRegex);
    if (match && match[1]) {
      return match[1];
    }

    // Check for "T-5", "T5"
    const directTRegex = /\b[Tt]-?(\d+)\b/;
    const directMatch = text.match(directTRegex);
    if (directMatch && directMatch[1]) {
      return directMatch[1];
    }

    return fallbackTable ? fallbackTable.toString() : null;
  }

  /**
   * Detect modifiers in spoken text
   */
  static extractModifiers(text) {
    const modifierPatterns = [
      'spicy', 'extra spicy', 'less spicy', 'very spicy',
      'without onion', 'without garlic', 'bina pyaz', 'bina lahsun',
      'extra cheese', 'cheese', 'no mayo', 'without mayo',
      'less salt', 'kam namak', 'extra butter', 'without butter',
      'crispy', 'well done', 'medium'
    ];

    const found = [];
    const lower = text.toLowerCase();
    for (const mod of modifierPatterns) {
      if (lower.includes(mod)) {
        found.push(mod);
      }
    }
    return found;
  }

  /**
   * Main parsing method: natural language text -> structured command JSON
   * @param {Object} params
   * @param {string} params.text - Normalized spoken text
   * @param {Array<Object>} params.availableProducts - POS products list
   * @param {string|null} [params.currentTableContext] - POS current active table
   * @param {Object|null} [params.sessionContext] - Short-term session memory
   */
  static parseCommand({
    text,
    availableProducts = [],
    currentTableContext = null,
    sessionContext = null,
  }) {
    if (!text || typeof text !== 'string') {
      return {
        intent: 'UNKNOWN',
        confidence: 0,
        message: 'Empty command received',
      };
    }

    const normalized = normalizeSpokenText(text);
    const lower = normalized.toLowerCase();

    // 1. Resolve Table Context (Spoken table takes priority, then session memory, then active POS screen)
    const resolvedTable = this.extractTableNumber(
      normalized,
      sessionContext?.tableNumber || currentTableContext
    );

    // 2. Identify Intent
    let intent = 'ADD_ITEM';

    // A. Check for Send KOT / Print KOT
    if (
      (/\b(kot|kitchen|kitchin)\b/i.test(lower) &&
        /\b(bhej|print|laga|daal|generate|send|karo|do|nikal)\b/i.test(lower)) ||
      lower.includes('kot print') ||
      lower.includes('print kot') ||
      lower.includes('kitchen order')
    ) {
      intent = 'SEND_KOT';
    }
    // B. Check for Bill Generation / Checkout / Save & Print / Settle Order
    else if (
      lower.includes('bill print') ||
      lower.includes('print bill') ||
      lower.includes('settle order') ||
      lower.includes('settle') ||
      lower.includes('save and print') ||
      lower.includes('save & print') ||
      lower.includes('checkout') ||
      ((lower.includes('bill') || lower.includes('payment') || lower.includes('paisa') || lower.includes('hisab')) &&
        (lower.includes('bana') || lower.includes('print') || lower.includes('generate') || lower.includes('karo') || lower.includes('do') || lower.includes('nikal') || lower.includes('le') || lower.includes('settle')))
    ) {
      intent = 'GENERATE_BILL';
    }
    // C. Check for Clear Cart / Cancel Order
    else if (
      (lower.includes('clear') || lower.includes('cancel') || lower.includes('khali') || lower.includes('hata')) &&
      (lower.includes('cart') || lower.includes('sab') || lower.includes('poora') || lower.includes('all') || lower.includes('order')) &&
      !lower.includes('butter') && !lower.includes('naan') && !lower.includes('paneer') && !lower.includes('roti')
    ) {
      intent = 'CLEAR_CART';
    }
    // D. Check for Apply Discount
    else if (
      lower.includes('discount') || lower.includes('off') || lower.includes('chhoot') || lower.includes('coupon')
    ) {
      intent = 'APPLY_DISCOUNT';
    }
    // E. Check for Customer Details
    else if (
      (lower.includes('customer') || lower.includes('grahak')) &&
      (lower.includes('naam') || lower.includes('name') || lower.includes('number') || lower.includes('phone') || lower.includes('mobile'))
    ) {
      intent = 'SET_CUSTOMER_DETAILS';
    }
    // F. Check for Order Type (Takeaway, Delivery, Dine In)
    else if (
      (lower.includes('takeaway') || lower.includes('take away') || lower.includes('delivery') || lower.includes('dine in') || lower.includes('parcel')) &&
      (lower.includes('order') || lower.includes('kar') || lower.includes('karo') || lower.includes('hai'))
    ) {
      intent = 'SET_ORDER_TYPE';
    }
    // G. Check for Switch / Select Table only (without dish names)
    else if (
      (lower.includes('switch') || lower.includes('select') || lower.includes('open') || lower.includes('pe jao') || lower.includes('par jao')) &&
      (lower.includes('table') || lower.includes('tbl') || lower.includes('mez')) &&
      !lower.includes('add') && !lower.includes('laga') && !lower.includes('bhej')
    ) {
      intent = 'SWITCH_TABLE';
    }
    // H. Check for Search / Availability
    else if (
      lower.includes('available') ||
      lower.includes('hai kya') ||
      lower.includes('kya hai') ||
      lower.includes('check') ||
      lower.includes('menu mein') ||
      lower.includes('dhoondo')
    ) {
      intent = 'CHECK_ITEM_AVAILABILITY';
    }
    // I. Check for View Order
    else if (
      (lower.includes('order dikhao') || lower.includes('show order') || lower.includes('view order') || lower.includes('order kya hai')) &&
      !lower.includes('add') && !lower.includes('laga')
    ) {
      intent = 'VIEW_TABLE_ORDER';
    }
    // J. Check for Modify Quantity (e.g., "Butter naan ko 4 kar do", "naan 4 kar do", "set naan to 4")
    else if (
      /\b(?:ko|to)\s+(\d+)\s+(?:kar|karo|set|change)\b/i.test(lower) ||
      /\b(?:kar|karo|set)\s+(?:ko\s+)?(\d+)\b/i.test(lower) ||
      /\b(\d+)\s+(?:kar\s+do|karo)\b/i.test(lower)
    ) {
      intent = 'UPDATE_QUANTITY';
    }
    // K. Check for Remove Item
    else if (
      lower.includes('hata do') ||
      lower.includes('hatao') ||
      lower.includes('remove') ||
      lower.includes('delete') ||
      lower.includes('kam kar do') ||
      lower.includes('nikal do')
    ) {
      intent = 'REMOVE_ITEM';
    }
    // L. Check for Modifiers
    else if (
      (lower.includes('spicy kar do') || lower.includes('extra cheese') || lower.includes('without onion')) &&
      !lower.includes('add') && !lower.includes('laga do')
    ) {
      intent = 'ADD_MODIFIER';
    }

    // 3. Process Intent-Specific Logic
    switch (intent) {
      case 'SEND_KOT': {
        return {
          intent: 'SEND_KOT',
          table_number: resolvedTable,
          confidence: 0.98,
          chotu_response: resolvedTable
            ? `Table ${resolvedTable} ka KOT kitchen mein bhej diya sir.`
            : 'KOT kitchen mein bhej diya sir.',
        };
      }

      case 'GENERATE_BILL': {
        return {
          intent: 'GENERATE_BILL',
          table_number: resolvedTable,
          confidence: 0.98,
          chotu_response: resolvedTable
            ? `Table ${resolvedTable} ka bill generate kar diya sir.`
            : 'Bill generate kar diya sir.',
        };
      }

      case 'CLEAR_CART': {
        return {
          intent: 'CLEAR_CART',
          table_number: resolvedTable,
          confidence: 0.98,
          chotu_response: resolvedTable
            ? `Table ${resolvedTable} ka cart clear kar diya sir.`
            : 'Cart clear kar diya gaya hai sir.',
        };
      }

      case 'APPLY_DISCOUNT': {
        let discountValue = 0;
        let discountType = 'percent';

        const percentMatch = lower.match(/(\d+)\s*(?:percent|%|pratishat)/i);
        const flatMatch = lower.match(/(?:rupaye|rs|inr|₹)\s*(\d+)|(\d+)\s*(?:rupaye|rs|inr|₹|ka\s+discount)/i);

        if (percentMatch) {
          discountValue = parseFloat(percentMatch[1]);
          discountType = 'percent';
        } else if (flatMatch) {
          discountValue = parseFloat(flatMatch[1] || flatMatch[2]);
          discountType = 'flat';
        } else {
          const simpleNum = lower.match(/\b(\d+)\b/);
          if (simpleNum) {
            discountValue = parseFloat(simpleNum[1]);
            discountType = discountValue <= 100 ? 'percent' : 'flat';
          }
        }

        const isRemove = lower.includes('hata') || lower.includes('remove') || lower.includes('zero') || discountValue === 0;

        return {
          intent: 'APPLY_DISCOUNT',
          table_number: resolvedTable,
          discount_value: isRemove ? 0 : discountValue,
          discount_type: discountType,
          is_remove: isRemove,
          confidence: 0.95,
          chotu_response: isRemove
            ? 'Discount hata diya gaya hai sir.'
            : `${discountValue}${discountType === 'percent' ? '%' : '₹'} discount apply kar diya sir.`,
        };
      }

      case 'SWITCH_TABLE': {
        return {
          intent: 'SWITCH_TABLE',
          table_number: resolvedTable,
          confidence: 0.98,
          chotu_response: resolvedTable
            ? `Table ${resolvedTable} select kar liya sir.`
            : 'Kaunsi table select karni hai sir?',
        };
      }

      case 'SET_CUSTOMER_DETAILS': {
        // Extract phone number (10 digits)
        const phoneMatch = normalized.match(/\b([6-9]\d{9})\b/);
        const customerPhone = phoneMatch ? phoneMatch[1] : '';

        // Extract customer name: e.g. "customer ka naam Rahul hai", "customer name Rahul"
        let customerName = '';
        const nameMatch = normalized.match(/(?:customer|grahak)?\s*(?:ka\s+)?(?:naam|name)\s*(?:is|hai)?\s*([a-zA-Z]+)/i);
        if (nameMatch) {
          customerName = nameMatch[1].trim();
        }

        return {
          intent: 'SET_CUSTOMER_DETAILS',
          customer_name: customerName,
          customer_phone: customerPhone,
          table_number: resolvedTable,
          confidence: 0.95,
          chotu_response: customerName || customerPhone
            ? `Customer ${customerName ? customerName : customerPhone} details save kar di sir.`
            : 'Customer details samajh nahi aayi sir.',
        };
      }

      case 'SET_ORDER_TYPE': {
        let orderType = 'dineIn';
        if (lower.includes('takeaway') || lower.includes('take away') || lower.includes('parcel')) {
          orderType = 'takeaway';
        } else if (lower.includes('delivery')) {
          orderType = 'delivery';
        } else if (lower.includes('dine')) {
          orderType = 'dineIn';
        }

        const typeLabels = { dineIn: 'Dine In', takeaway: 'Takeaway / Parcel', delivery: 'Delivery' };

        return {
          intent: 'SET_ORDER_TYPE',
          order_type: orderType,
          table_number: resolvedTable,
          confidence: 0.95,
          chotu_response: `Order type ${typeLabels[orderType] || orderType} set kar diya sir.`,
        };
      }

      case 'CHECK_ITEM_AVAILABILITY': {
        // Strip filler words to find the item
        const cleanQuery = lower
          .replace(/\b(kya|available|hai|check|karo|batao|item|product|please)\b/gi, '')
          .trim();
        const matchResult = ProductMatcher.matchProduct(cleanQuery, availableProducts);
        return {
          intent: 'CHECK_ITEM_AVAILABILITY',
          spoken_query: cleanQuery,
          table_number: resolvedTable,
          product: matchResult.match ? {
            id: matchResult.match.id || matchResult.match._id,
            name: matchResult.match.name,
            price: matchResult.match.price,
            isAvailable: matchResult.match.isAvailable,
            stock: matchResult.match.stock,
          } : null,
          confidence: matchResult.confidence,
          chotu_response: matchResult.match
            ? `${matchResult.match.name} available hai sir, price ₹${matchResult.match.price}.`
            : 'Ye item menu mein nahi mila sir.',
        };
      }

      case 'VIEW_TABLE_ORDER': {
        return {
          intent: 'VIEW_TABLE_ORDER',
          table_number: resolvedTable,
          confidence: 0.95,
          chotu_response: resolvedTable
            ? `Table ${resolvedTable} ka order screen par show kar raha hoon sir.`
            : 'Kaunsi table ka order dekhna hai sir?',
        };
      }

      case 'UPDATE_QUANTITY': {
        // Find target quantity: e.g. "Butter naan ko 4 kar do"
        let targetQty = 1;
        const qtyMatch = lower.match(/\b(?:ko\s+|to\s+)?(\d+)\s*(?:kar|karo|set|pieces|plate)?\b/i);
        if (qtyMatch && qtyMatch[1]) {
          targetQty = parseInt(qtyMatch[1], 10);
        }

        // Clean out quantity and verbs to get product name
        const cleanProd = lower
          .replace(/\b(?:table|tbl)\s*\d+\b/gi, '')
          .replace(/\b(pe|mein|ko|to|kar|karo|do|set|quantity|qty|plate|pieces)\b/gi, '')
          .replace(/\b\d+\b/g, '')
          .trim();

        const matchResult = ProductMatcher.matchProduct(cleanProd, availableProducts);
        return {
          intent: 'UPDATE_QUANTITY',
          table_number: resolvedTable,
          quantity: targetQty,
          item: matchResult.match ? {
            product_id: matchResult.match.id || matchResult.match._id,
            product_name: matchResult.match.name,
            quantity: targetQty,
            price: matchResult.match.price,
          } : null,
          ambiguity: matchResult.tier === 'ambiguous',
          question: matchResult.question,
          confidence: matchResult.confidence,
          chotu_response: matchResult.match
            ? `Table ${resolvedTable || ''} mein ${matchResult.match.name} ki quantity ${targetQty} set kar di sir.`
            : (matchResult.question || 'Product nahi mila sir.'),
        };
      }

      case 'REMOVE_ITEM': {
        // Find item and quantity to reduce (default 1)
        let removeQty = 1;
        const qtyMatch = lower.match(/\b(\d+)\s+([a-zA-Z\s]+?)\s+(?:hata|remove|kam|nikal|cancel)\b/i);
        if (qtyMatch && qtyMatch[1]) {
          removeQty = parseInt(qtyMatch[1], 10);
        }

        const cleanProd = lower
          .replace(/\b(?:table|tbl)\s*\d+\b/gi, '')
          .replace(/\b(se|mein|pe|ek|do|hata|hatao|do|remove|delete|kam|kar|nikal|cancel|plate)\b/gi, '')
          .replace(/\b\d+\b/g, '')
          .trim();

        const matchResult = ProductMatcher.matchProduct(cleanProd, availableProducts);
        return {
          intent: 'REMOVE_ITEM',
          table_number: resolvedTable,
          quantity: removeQty,
          item: matchResult.match ? {
            product_id: matchResult.match.id || matchResult.match._id,
            product_name: matchResult.match.name,
            quantity: removeQty,
            price: matchResult.match.price,
          } : null,
          ambiguity: matchResult.tier === 'ambiguous',
          question: matchResult.question,
          confidence: matchResult.confidence,
          chotu_response: matchResult.match
            ? `Table ${resolvedTable || ''} se ${matchResult.match.name} remove kar diya sir.`
            : (matchResult.question || 'Product nahi mila sir.'),
        };
      }

      case 'ADD_ITEM':
      default: {
        // Parse items and quantities: e.g. "Table 5 pe 2 butter naan aur 1 paneer tikka laga do"
        // Also supports: "ek coke aur add karo", "1 paneer tikka", "add 2 burgers"
        const items = [];
        const modifiers = this.extractModifiers(normalized);

        // Remove table prefix/suffix from item extraction string
        let contentStr = normalized
          .replace(/\b(?:table|tbl|mez)\s*[-#]?\s*\d+\s*(?:pe|mein|par|to|for)?\b/gi, ' ')
          .replace(/\b(?:laga|lagao|kar|karo|bhej|rakh)\s+do\b/gi, ' ')
          .replace(/\b(?:add\s+karo|add\s+kar\s+do|add)\b/gi, ' ')
          .replace(/\b(?:aur\s+add\s+karo|bhi\s+add\s+karo|bhi)\b/gi, ' ')
          .trim();

        // Split multi-item phrases joined by 'aur', 'and', 'plus', comma, '+'
        const itemPhrases = contentStr
          .split(/\b(?:aur|and|\+|&)\b|,/gi)
          .map((p) => p.trim())
          .filter(Boolean);

        let overallConfidence = 0.95;
        let ambiguityFound = null;

        for (const phrase of itemPhrases) {
          // Extract leading or embedded numeral quantity
          let qty = 1;
          let prodName = phrase;

          const numMatch = phrase.match(/^(\d+)\s+(.+)$/) || phrase.match(/^(.+?)\s+(\d+)$/);
          if (numMatch) {
            if (/^\d+$/.test(numMatch[1])) {
              qty = parseInt(numMatch[1], 10);
              prodName = numMatch[2].trim();
            } else {
              qty = parseInt(numMatch[2], 10);
              prodName = numMatch[1].trim();
            }
          }

          // Clean extraneous fillers from product name
          prodName = prodName
            .replace(/\b(plate|piece|pieces|cup|glass|bottle|order)\b/gi, '')
            .trim();

          if (!prodName) continue;

          // Match product against database catalog
          const matchResult = ProductMatcher.matchProduct(prodName, availableProducts);

          if (matchResult.tier === 'ambiguous') {
            ambiguityFound = matchResult;
            overallConfidence = Math.min(overallConfidence, 0.70);
          } else if (!matchResult.match) {
            overallConfidence = Math.min(overallConfidence, 0.40);
          } else {
            overallConfidence = Math.min(overallConfidence, matchResult.confidence);
          }

          items.push({
            spoken_name: prodName,
            product_id: matchResult.match ? (matchResult.match.id || matchResult.match._id) : null,
            product_name: matchResult.match ? matchResult.match.name : prodName,
            price: matchResult.match ? matchResult.match.price : 0,
            sale_price: matchResult.match?.salePrice || null,
            quantity: qty,
            foodType: matchResult.match?.foodType || 'veg',
            modifiers,
            matched: Boolean(matchResult.match),
            confidence: matchResult.confidence,
          });
        }

        // Build Chotu's natural fast confirmation response
        let chotuResponse = '';
        if (ambiguityFound) {
          chotuResponse = ambiguityFound.question;
        } else if (items.length > 0 && items.every((i) => i.matched)) {
          const itemSummary = items.map((i) => `${i.product_name} ${i.quantity}`).join(' aur ');
          if (resolvedTable) {
            chotuResponse = `Table ${resolvedTable} mein ${itemSummary} add kar diya.`;
          } else {
            chotuResponse = `${itemSummary} add kar diya. Kaunsi table mein add karna hai?`;
          }
        } else if (items.length > 0) {
          const missing = items.filter((i) => !i.matched).map((i) => i.spoken_name).join(', ');
          chotuResponse = `Ye item menu mein nahi mila: ${missing}.`;
        } else {
          chotuResponse = 'Kuch sunai nahi diya. Dobara boliye.';
        }

        return {
          intent: 'ADD_ITEM',
          table_number: resolvedTable,
          table_context_missing: !resolvedTable,
          items,
          ambiguity: Boolean(ambiguityFound),
          question: ambiguityFound ? ambiguityFound.question : null,
          confidence: parseFloat(overallConfidence.toFixed(2)),
          chotu_response: chotuResponse,
        };
      }
    }
  }
}

module.exports = AICommandEngine;
