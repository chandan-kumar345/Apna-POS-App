const { GoogleGenAI } = require('@google/genai');
const Product = require('../models/Product');
const Category = require('../models/Category');
const Coupon = require('../models/Coupon');
const WhatsAppMessage = require('../models/WhatsAppMessage');
const Business = require('../models/Business');

class AIAgentService {
  constructor() {
    this.defaultModel = 'gemini-3.8-flash';
  }

  /**
   * Build dynamic menu & restaurant knowledge context for the AI prompt
   */
  async buildBusinessContext(businessId) {
    try {
      const business = await Business.findById(businessId).lean();
      if (!business) return null;

      // 1. Fetch available products / dishes
      const products = await Product.find({
        businessId,
        $or: [{ isAvailable: true }, { isAvailable: { $exists: false } }],
      })
        .select('name description price category isVeg isBestseller variants')
        .limit(100)
        .lean();

      // 2. Fetch categories
      const categories = await Category.find({ businessId }).select('name').lean();
      const catMap = {};
      categories.forEach((c) => {
        catMap[c._id.toString()] = c.name;
      });

      // Group products by category
      const menuByCategory = {};
      products.forEach((p) => {
        const catName = (p.category && catMap[p.category.toString()]) || 'Specialties';
        if (!menuByCategory[catName]) menuByCategory[catName] = [];

        let desc = p.description ? ` - ${p.description}` : '';
        let tag = p.isVeg === false ? ' [Non-Veg]' : ' [Veg]';
        let best = p.isBestseller ? ' ⭐ Bestseller' : '';
        let priceStr = `₹${p.price || 0}`;

        if (p.variants && p.variants.length > 0) {
          const varPrices = p.variants.map((v) => `${v.name}: ₹${v.price || v.salePrice}`).join(', ');
          priceStr += ` (${varPrices})`;
        }

        menuByCategory[catName].push(`• *${p.name}*: ${priceStr}${tag}${best}${desc}`);
      });

      let menuText = '';
      for (const [cat, items] of Object.entries(menuByCategory)) {
        menuText += `\n*${cat.toUpperCase()}*:\n${items.join('\n')}\n`;
      }
      if (!menuText.trim()) {
        menuText = 'Menu items will be shared upon request.';
      }

      // 3. Fetch active coupons
      let offersText = 'No special coupons active currently.';
      try {
        const coupons = await Coupon.find({
          businessId,
          isActive: true,
          $or: [{ expiryDate: { $gte: new Date() } }, { expiryDate: null }],
        })
          .select('code discountType discountValue minOrderAmount description')
          .limit(5)
          .lean();

        if (coupons && coupons.length > 0) {
          offersText = coupons
            .map(
              (c) =>
                `• Use code *${c.code}*: ${c.discountType === 'percentage' ? `${c.discountValue}% OFF` : `₹${c.discountValue} OFF`}${c.minOrderAmount ? ` on orders above ₹${c.minOrderAmount}` : ''}`
            )
            .join('\n');
        }
      } catch (_) {}

      const restaurantName = business.name || business.profile?.name || 'Our Restaurant';
      const address = [
        business.address?.street,
        business.address?.city,
        business.address?.state,
        business.address?.pincode,
      ]
        .filter(Boolean)
        .join(', ');

      const phone = business.profile?.phone || business.whatsappSettings?.phoneNumber || '';

      return {
        restaurantName,
        phone,
        address: address || 'City Center',
        menuText,
        offersText,
        products: products || [],
        settings: business.aiChatAgentSettings || {},
      };
    } catch (err) {
      console.error('[AIAgentService] Context extraction notice:', err.message);
      return null;
    }
  }

  /**
   * Build persona instruction text
   */
  getPersonaPrompt(persona, restaurantName) {
    switch (persona) {
      case 'professional':
        return `You are a formal, polite, and highly efficient AI reservation and hospitality executive for *${restaurantName}*. Speak with elegance, precision, and respectful courtesy.`;
      case 'chef':
        return `You are Chef's personal AI concierge at *${restaurantName}*. You are deeply passionate about cuisine, rich flavors, cooking methods, and mouth-watering culinary recommendations. Explain dishes vividly!`;
      case 'sales':
        return `You are an energetic, welcoming host at *${restaurantName}*. Enthusiastically highlight today's combos, bestsellers, promotions, and add-on pairings. Always encourage trying customer favorites!`;
      case 'hinglish':
        return `You are a cheerful, friendly local assistant for *${restaurantName}*. Talk in natural Indian Hinglish (mixture of easy Hindi and English, e.g. "Namaste ji! Welcome to ${restaurantName}. Bataiye aaj kya mangwayenge? Hamare Paneer Tikka aur Biryani sabse famous hain!"). Keep it very respectful and heartwarming.`;
      case 'friendly':
      default:
        return `You are a warm, courteous, and helpful AI hospitality host for *${restaurantName}*. Greet guests with "Namaste!", be super welcoming, guide them with a smile, and make them feel at home.`;
    }
  }

  /**
   * Retrieve recent conversation history for context
   */
  async getChatHistory(chatId, limit = 8) {
    if (!chatId) return [];
    try {
      const messages = await WhatsAppMessage.find({ chatId })
        .sort({ timestamp: -1 })
        .limit(limit)
        .select('direction text timestamp isAiGenerated')
        .lean();

      return messages.reverse().map((m) => ({
        role: m.direction === 'INCOMING' ? 'user' : 'model',
        text: m.text || '',
      }));
    } catch (_) {
      return [];
    }
  }

  /**
   * Generate AI response using Google Gemini API or intelligent grounded fallback
   */
  async generateReply({
    business,
    chatId,
    customerPhone,
    customerName,
    messageText,
    customerMessage,
    message,
    settingsOverride = null,
  }) {
    const rawText = messageText || customerMessage || message || '';
    if (!business || !rawText.trim()) return null;
    messageText = rawText.trim();

    const bId = business._id || business.id;
    const context = await this.buildBusinessContext(bId);
    if (!context) return null;

    const settings = {
      ...(context.settings || {}),
      ...(settingsOverride || {}),
    };

    const restaurantName = context.restaurantName;
    const persona = settings.persona || 'friendly';
    const personaPrompt = this.getPersonaPrompt(persona, restaurantName);
    const customPrompt = settings.systemPrompt || '';
    const houseRules = settings.customInstructions || '';
    const autoMenu = settings.autoMenuSuggest !== false;
    const autoOrder = settings.autoOrderTaking !== false;

    // Compose System Instruction
    const systemInstruction = `
${personaPrompt}

RESTAURANT PROFILE:
- Name: ${restaurantName}
- Phone: ${context.phone}
- Address: ${context.address}

LIVE RESTAURANT MENU (GROUND TRUTH):
${context.menuText}

ACTIVE DEALS & OFFERS:
${context.offersText}

CAPABILITIES & RULES:
1. Always represent ${restaurantName} with hospitality and politeness.
2. Answer queries about menu items, prices, veg/non-veg status, and specialties accurately using the LIVE RESTAURANT MENU above.
3. NEVER make up or hallucinate items or prices that do not exist in the menu above.
4. ${autoMenu ? 'Proactively suggest popular bestsellers or complementary items when asked for recommendations.' : 'Share menu items only when requested.'}
5. ${autoOrder ? `DIRECT ORDER TAKING INSTRUCTIONS:
If the customer wants to order items from the menu (e.g. "pack 2 Masala Chai and 1 Sandwich", "order 1 Burger", "send 2 Pizza to ..."):
- Warmly confirm the items, quantities, and calculate the exact total price in ₹ in your message text.
- AT THE VERY END OF YOUR RESPONSE, append a strict JSON block wrapped in \`\`\`order_data ... \`\`\` with:
\`\`\`order_data
{
  "isOrder": true,
  "orderType": "delivery" or "takeaway",
  "deliveryAddress": "address if specified or empty string",
  "items": [
    {
      "name": "Exact Name matching the LIVE RESTAURANT MENU",
      "quantity": 2,
      "price": 50,
      "note": ""
    }
  ]
}
\`\`\`
If the customer is NOT placing an order, DO NOT output any \`\`\`order_data\`\`\` block.` : 'Advise the customer to call or visit to place orders.'}
6. Table Booking / Reservation: If the guest wants to reserve a table, ask for party size, date, time, and confirm that their request has been noted for the manager.
7. Format your response cleanly using an elegant, professional WhatsApp template:
   - Begin with a branded header banner with emojis (e.g. ✨ *{RESTAURANT_NAME}* ✨ or 📋 *MENU & SPECIALTIES* 📋).
   - Use clean horizontal divider lines: ━━━━━━━━━━━━━━━━━━━━
   - Use *bold* for dish names, section titles, and prices (e.g. • *Paneer Butter Masala* — ₹240).
   - Format lists with neat bullet points (• or 🔹).
   - Keep replies concise, clean, and easily scannable. Avoid unformatted walls of text.
   - Conclude with a clean divider: ━━━━━━━━━━━━━━━━━━━━ followed by a helpful guidance line (e.g. 💡 _Reply with dish names to order directly!_).
   - Add friendly food & hospitality emojis naturally (🍛, 🍕, ☕, 🙏, 🍽️).

${houseRules ? `SPECIAL HOUSE RULES FROM OWNER:\n${houseRules}\n` : ''}
${customPrompt ? `OWNER CUSTOM INSTRUCTIONS:\n${customPrompt}\n` : ''}
`.trim();

    // Fetch conversation history
    const history = await this.getChatHistory(chatId, 6);

    // API Key resolution (Custom Key from settings OR Server .env GEMINI_API_KEY)
    const apiKey =
      (settings.apiKey && settings.apiKey.trim()) ||
      process.env.GEMINI_API_KEY ||
      process.env.GOOGLE_API_KEY ||
      '';

    const modelName = settings.model || this.defaultModel;

    // 1. Try Gemini API invocation
    if (apiKey) {
      try {
        console.log(`[AIAgentService] 🤖 Invoking Gemini model '${modelName}' for ${restaurantName}...`);
        const aiClient = new GoogleGenAI({ apiKey });

        const contents = [];
        for (const h of history) {
          if (h.text && h.text.trim()) {
            contents.push({
              role: h.role,
              parts: [{ text: h.text }],
            });
          }
        }
        contents.push({
          role: 'user',
          parts: [{ text: messageText }],
        });

        const response = await aiClient.models.generateContent({
          model: modelName,
          contents,
          config: {
            systemInstruction: {
              parts: [{ text: systemInstruction }],
            },
            temperature: 0.7,
            maxOutputTokens: 600,
          },
        });

        let replyText = response.text ? response.text.trim() : '';
        let orderPayload = null;

        if (replyText) {
          const orderMatch = replyText.match(/```order_data\s*([\s\S]*?)\s*```/);
          if (orderMatch && orderMatch[1]) {
            try {
              const parsed = JSON.parse(orderMatch[1].trim());
              if (parsed.isOrder && Array.isArray(parsed.items) && parsed.items.length > 0) {
                // Strip order_data block from customer-visible message
                replyText = replyText.replace(/```order_data[\s\S]*?```/g, '').trim();

                const validItems = [];
                let subtotal = 0;
                const productsList = context.products || [];

                for (const it of parsed.items) {
                  const qty = Math.max(1, parseInt(it.quantity, 10) || 1);
                  const rawName = (it.name || '').trim();
                  if (!rawName) continue;

                  const matched = productsList.find(
                    (p) => p.name.toLowerCase() === rawName.toLowerCase() ||
                           p.name.toLowerCase().includes(rawName.toLowerCase()) ||
                           rawName.toLowerCase().includes(p.name.toLowerCase())
                  );

                  const finalPrice = matched ? (matched.price || 0) : (parseFloat(it.price) || 0);
                  const finalName = matched ? matched.name : rawName;
                  const foodType = matched ? (matched.isVeg === false ? 'non_veg' : 'veg') : 'veg';

                  validItems.push({
                    productId: matched ? matched._id : undefined,
                    name: finalName,
                    price: finalPrice,
                    quantity: qty,
                    foodType,
                    note: it.note || '',
                  });
                  subtotal += finalPrice * qty;
                }

                if (validItems.length > 0) {
                  orderPayload = {
                    orderType: parsed.orderType === 'delivery' ? 'delivery' : 'takeaway',
                    deliveryAddress: (parsed.deliveryAddress || '').trim(),
                    items: validItems,
                    subtotal,
                    totalAmount: subtotal,
                    notes: 'Ordered via WhatsApp AI Agent',
                    source: 'whatsapp_ai',
                  };
                }
              }
            } catch (jsonErr) {
              console.warn('[AIAgentService] Order JSON parse notice:', jsonErr.message);
            }
          }

          console.log(`[AIAgentService] ✅ Gemini generated response (${replyText.length} chars)`);
          return {
            replyText,
            isAiGenerated: true,
            model: modelName,
            source: 'gemini',
            orderPayload,
          };
        }
      } catch (geminiErr) {
        console.warn(`[AIAgentService] Gemini API invocation notice: ${geminiErr.message}. Falling back to smart rules.`);
      }
    } else {
      console.log('[AIAgentService] No custom or server GEMINI_API_KEY set. Employing smart grounded POS AI assistant.');
    }

    // 2. High-Fidelity Smart Fallback (Guaranteed to always reply reliably)
    const fallbackResult = this.generateSmartGroundedReply({
      messageText,
      context,
      customerName,
      persona,
      settings,
    });

    const replyText = typeof fallbackResult === 'object' && fallbackResult.replyText ? fallbackResult.replyText : (typeof fallbackResult === 'string' ? fallbackResult : '');
    const orderPayload = typeof fallbackResult === 'object' ? fallbackResult.orderPayload : null;

    return {
      replyText,
      isAiGenerated: true,
      model: 'apna-pos-rule-engine',
      source: 'smart_fallback',
      orderPayload,
    };
  }

  /**
   * Smart rule-based conversational engine grounded in the live menu
   */
  generateSmartGroundedReply({ messageText, context, customerName, persona, settings }) {
    const raw = (messageText || '').toLowerCase().trim();
    const rName = context.restaurantName || 'Apna POS';
    const cGreeting = customerName ? ` ${customerName}` : '';

    // Greeting / Hello
    if (/^(hi|hello|hey|namaste|pranam|hola|good\s*(morning|afternoon|evening))/i.test(raw)) {
      if (settings.greeting && settings.greeting.trim()) {
        const customGreeting = settings.greeting
          .replace(/\{restaurant_name\}/gi, rName)
          .replace(/\{customer_name\}/gi, customerName || 'guest');
        return {
          replyText: `✨ *WELCOME TO ${rName.toUpperCase()}* ✨\n━━━━━━━━━━━━━━━━━━━━\n${customGreeting}\n━━━━━━━━━━━━━━━━━━━━\n💡 _Reply with *Menu*, *Specials*, or type your order directly!_`,
          orderPayload: null,
        };
      }
      if (persona === 'hinglish') {
        return {
          replyText: `✨ *WELCOME TO ${rName.toUpperCase()}* ✨\n━━━━━━━━━━━━━━━━━━━━\n🙏 *Namaste${cGreeting}!* ${rName} mein aapka swagat hai!\n\nAaj aap kya mangwana pasand karenge? Hamara menu dekhne ke liye *Menu* type karein, ya aaj ke bestsellers jaanein! 😊\n━━━━━━━━━━━━━━━━━━━━\n💡 _Type your order directly to place it in our kitchen!_`,
          orderPayload: null,
        };
      }
      return {
        replyText: `✨ *WELCOME TO ${rName.toUpperCase()}* ✨\n━━━━━━━━━━━━━━━━━━━━\n🙏 *Namaste${cGreeting}!* Welcome to *${rName}*.\n\nI am your smart AI hospitality assistant. How can I delight you today?\n\n✨ *Quick Options:*\n• 📋 Send *Menu* for all dishes & drinks\n• ⭐ Send *Specials* for Chef's bestsellers\n• 🎉 Send *Offers* for today's discount coupons\n• 🍽️ Send *Book Table* to reserve dining seats\n• 🛍️ Type your order directly to place it!\n━━━━━━━━━━━━━━━━━━━━\n💬 _What would you like to have today?_`,
        orderPayload: null,
      };
    }

    // Menu inquiry
    if (/(menu|food|dishes|list|kya kya hai|kya milta hai|rate|card)/i.test(raw)) {
      return {
        replyText: `📋 *${rName.toUpperCase()} — MENU & SPECIALTIES* 📋\n━━━━━━━━━━━━━━━━━━━━\n${context.menuText}\n━━━━━━━━━━━━━━━━━━━━\n🎉 *Today's Offers:*\n${context.offersText}\n━━━━━━━━━━━━━━━━━━━━\n💡 _Reply with dish names & quantities to order directly (e.g. "1 Masala Chai, 2 Samosa")!_`,
        orderPayload: null,
      };
    }

    // Recommendations / Bestsellers / Specials
    if (/(special|best|bestseller|recommend|famous|tasty|suggest|top)/i.test(raw)) {
      const bestList = context.menuText.split('\n').filter((l) => l.includes('Bestseller') || l.includes('Special')).slice(0, 6).join('\n') || context.menuText.split('\n').slice(0, 6).join('\n');
      return {
        replyText: `⭐ *CHEF'S TOP RECOMMENDATIONS* ⭐\n*${rName}*\n━━━━━━━━━━━━━━━━━━━━\nOur guests love these signature specialties:\n\n${bestList}\n━━━━━━━━━━━━━━━━━━━━\n💡 _Would you like to order any of these? Just text the dish name!_`,
        orderPayload: null,
      };
    }

    // Pure Veg / Vegetarian
    if (/(veg|vegetarian|shakahari)/i.test(raw) && !/non[-\s]?veg/i.test(raw)) {
      const vegItems = context.menuText.split('\n').filter((l) => l.includes('[Veg]')).slice(0, 6).join('\n');
      return {
        replyText: `🥦 *PURE VEG SPECIALTIES* 🥦\n*${rName}*\n━━━━━━━━━━━━━━━━━━━━\n${vegItems || 'All our vegetarian items are freshly prepared with pure ingredients!'}\n━━━━━━━━━━━━━━━━━━━━\n💡 _Reply with dish names to order or inquire!_`,
        orderPayload: null,
      };
    }

    // Non-Veg
    if (/(non[-\s]?veg|chicken|mutton|egg|meat|fish)/i.test(raw)) {
      const nonVegItems = context.menuText.split('\n').filter((l) => l.includes('[Non-Veg]')).slice(0, 6).join('\n');
      return {
        replyText: `🍗 *NON-VEG DELICACIES* 🍗\n*${rName}*\n━━━━━━━━━━━━━━━━━━━━\n${nonVegItems || 'We have delicious non-veg delicacies prepared fresh daily!'}\n━━━━━━━━━━━━━━━━━━━━\n💡 _Reply with dish names to place your order!_`,
        orderPayload: null,
      };
    }

    // Table reservation / booking
    if (/(table|book|seat|reservation|reserve|bithane|jagah)/i.test(raw)) {
      return {
        replyText: `🍽️ *TABLE RESERVATION* 🍽️\n*${rName}*\n━━━━━━━━━━━━━━━━━━━━\nWe would be delighted to host you! Please share:\n1️⃣ *Date & Time* ⏰\n2️⃣ *Number of Guests* 👥\n3️⃣ *Guest Name* 👤\n━━━━━━━━━━━━━━━━━━━━\n✨ _Our team will confirm your table reservation right away!_`,
        orderPayload: null,
      };
    }

    // Location / Address / Timings / Contact
    if (/(location|address|kahan hai|timing|time|open|close|phone|call|contact)/i.test(raw)) {
      return {
        replyText: `📍 *${rName.toUpperCase()} — LOCATION & TIMINGS* 📍\n━━━━━━━━━━━━━━━━━━━━\n• 📌 *Address*: ${context.address}\n• 📞 *Contact*: ${context.phone || 'Available on WhatsApp'}\n• 🕒 *Timings*: Open Daily for Dining & Delivery\n━━━━━━━━━━━━━━━━━━━━\n😊 _We look forward to serving you!_`,
        orderPayload: null,
      };
    }

    // Offers / Discounts
    if (/(offer|discount|coupon|deal|bachat|sale)/i.test(raw)) {
      return {
        replyText: `🎉 *TODAY'S SPECIAL OFFERS & DEALS* 🎉\n*${rName}*\n━━━━━━━━━━━━━━━━━━━━\n${context.offersText}\n━━━━━━━━━━━━━━━━━━━━\n💰 _Apply these codes when ordering to enjoy instant savings!_`,
        orderPayload: null,
      };
    }

    // Order taking intent & direct POS order processing
    if (/(order|chahiye|pack|deliver|parcel|bhejo|mangwa|send|lao|de do)/i.test(raw) && settings.autoOrderTaking !== false) {
      const validItems = [];
      let calculatedSubtotal = 0;
      const productsList = context.products || [];

      for (const prod of productsList) {
        if (!prod || !prod.name) continue;
        const pName = prod.name.toLowerCase().trim();
        if (pName.length < 2) continue;

        const escaped = pName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const regex = new RegExp(`(?:(\\d+)\\s*(?:x|plate|plates|glass|cup|cups|pieces|pcs|bottle|bottles)?\\s*)?${escaped}(?:\\s*(?:x|plate|plates|glass|cup|cups|pieces|pcs|bottle|bottles)?\\s*(\\d+))?`, 'i');
        const match = raw.match(regex);
        if (match) {
          const qty = parseInt(match[1] || match[2] || '1', 10) || 1;
          const pPrice = typeof prod.price === 'number' ? prod.price : (parseFloat(prod.price) || 0);
          validItems.push({
            productId: prod._id,
            name: prod.name,
            price: pPrice,
            quantity: qty,
            foodType: prod.isVeg === false ? 'non_veg' : 'veg',
            note: '',
          });
          calculatedSubtotal += pPrice * qty;
        }
      }

      const isDelivery = /(deliver|delivery|address|ghar|flat|room|colony|sector|road|nagar)/i.test(raw);

      if (validItems.length > 0) {
        const orderPayload = {
          orderType: isDelivery ? 'delivery' : 'takeaway',
          deliveryAddress: '',
          items: validItems,
          subtotal: calculatedSubtotal,
          totalAmount: calculatedSubtotal,
          notes: 'Ordered via WhatsApp AI Agent',
          source: 'whatsapp_ai',
        };

        const itemsListStr = validItems.map((i) => `• ${i.quantity}x *${i.name}* (₹${i.price * i.quantity})`).join('\n');
        const reply = `🧾 *ORDER RECEIVED* 🧾\n*${rName}*\n━━━━━━━━━━━━━━━━━━━━\n📦 *Order Summary*:\n${itemsListStr}\n━━━━━━━━━━━━━━━━━━━━\n💰 *Estimated Total*: *₹${calculatedSubtotal}*\n🛵 *Type*: ${isDelivery ? 'Home Delivery' : 'Takeaway / Pickup'}\n⏳ *Status*: 🕒 Waiting for restaurant confirmation\n━━━━━━━━━━━━━━━━━━━━\n🙏 _We have sent your order to the restaurant manager. You will receive an instant WhatsApp update when your order is accepted!_ 🚀`;

        return {
          replyText: reply,
          orderPayload,
        };
      }

      return {
        replyText: `📝 *ORDER REQUEST — ${rName.toUpperCase()}*\n━━━━━━━━━━━━━━━━━━━━\nI have noted your request: _"${messageText}"_.\n\nOur kitchen staff has received your order alert on the POS counter and will confirm the preparation time and total bill shortly!\n━━━━━━━━━━━━━━━━━━━━\n🙏 _Thank you for ordering with us!_`,
        orderPayload: null,
      };
    }

    // Default polite hospitality response
    if (persona === 'hinglish') {
      return {
        replyText: `✨ *${rName.toUpperCase()} — AI ASSISTANT* ✨\n━━━━━━━━━━━━━━━━━━━━\nJi bilkul! *${rName}* mein hum aapki help karne ke liye taiyaar hain.\n\nAap hamara *Menu* dekh sakte hain, *Chef Specials* jaan sakte hain, ya direct *Order* likh kar bhej sakte hain.\n━━━━━━━━━━━━━━━━━━━━\n😊 _Bataiye kya seva karein?_`,
        orderPayload: null,
      };
    }

    return {
      replyText: `✨ *${rName.toUpperCase()} — AI ASSISTANT* ✨\n━━━━━━━━━━━━━━━━━━━━\n🙏 Thank you for reaching out to *${rName}*!\n\nHere is how I can assist you right now:\n• 📋 Send *Menu* — View full food & drink menu\n• ⭐ Send *Specials* — Chef's top recommendations\n• 🍽️ Send *Book Table* — Reserve a dining table\n• 📍 Send *Location* — View address & store timings\n• 🛍️ Type your order directly to place it!\n━━━━━━━━━━━━━━━━━━━━\n😊 _How can I delight you today?_`,
      orderPayload: null,
    };
  }
}

module.exports = new AIAgentService();
