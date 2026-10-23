const { GoogleGenAI } = require('@google/genai');
const Product = require('../models/Product');
const Category = require('../models/Category');
const Coupon = require('../models/Coupon');
const WhatsAppMessage = require('../models/WhatsAppMessage');
const Business = require('../models/Business');

class AIAgentService {
  constructor() {
    this.defaultModel = 'gemini-2.0-flash';
  }

  /**
   * Format and clean customer name for polite hospitality greetings
   */
  formatCustomerName(name) {
    if (!name || typeof name !== 'string') return '';
    const trimmed = name.trim();
    if (
      !trimmed ||
      /^customer\s*\d*$/i.test(trimmed) ||
      /^\+?\d+$/.test(trimmed) ||
      /^guest$/i.test(trimmed)
    ) {
      return '';
    }
    // Title-case words nicely (e.g. "chand" -> "Chand", "chandan kumar" -> "Chandan")
    const words = trimmed
      .split(/\s+/)
      .filter(Boolean)
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase());
    return words.slice(0, 2).join(' ');
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

        let tag = p.isVeg === false ? ' [Non-Veg]' : ' [Veg]';
        let best = p.isBestseller ? ' ⭐ Bestseller' : '';
        let priceStr = '';
        if (p.variants && p.variants.length > 0) {
          const validVariantPrices = p.variants
            .map((v) => (typeof v.price === 'number' && v.price > 0 ? v.price : (parseFloat(v.salePrice) || 0)))
            .filter((pr) => pr > 0);
          const minVariantPrice = validVariantPrices.length > 0 ? Math.min(...validVariantPrices) : (p.price || 0);
          const varPrices = p.variants
            .map((v) => `${v.name}: ₹${v.price || v.salePrice || minVariantPrice}`)
            .join(', ');

          if (minVariantPrice > 0) {
            priceStr = `From ₹${minVariantPrice} (${varPrices})`;
          } else {
            priceStr = `(${varPrices})`;
          }
        } else {
          priceStr = `₹${p.price || 0}`;
        }

        menuByCategory[catName].push(`• *${p.name}*: ${priceStr}${tag}${best}`);
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

      // Authoritative restaurant brand resolution (prioritize store/company name over personal owner name)
      const restaurantName =
        (business.profile?.companyName && business.profile.companyName.trim()) ||
        (business.companyName && business.companyName.trim()) ||
        (business.restaurantName && business.restaurantName.trim()) ||
        (business.name && business.name.trim()) ||
        (business.profile?.name && business.profile.name.trim()) ||
        'Our Restaurant';

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
        business,
      };
    } catch (err) {
      console.error('[AIAgentService] Context extraction notice:', err.message);
      return null;
    }
  }

  /**
   * Build persona instruction text
   */
  getPersonaPrompt(persona, restaurantName, customerDisplayName = '') {
    const greetingName = customerDisplayName ? ` ${customerDisplayName}` : ' Ji';
    switch (persona) {
      case 'professional':
        return `You are a formal, polite, and highly efficient AI reservation and hospitality executive for *${restaurantName}*. Greet the customer with "Namaste${greetingName}!". Speak with elegance, precision, and respectful courtesy.`;
      case 'chef':
        return `You are Chef's personal AI concierge at *${restaurantName}*. Greet the customer warmly with "Namaste${greetingName}!". You are deeply passionate about cuisine, rich flavors, cooking methods, and mouth-watering culinary recommendations. Explain dishes vividly!`;
      case 'sales':
        return `You are an energetic, welcoming host at *${restaurantName}*. Greet guests with "Namaste${greetingName}!". Enthusiastically highlight today's combos, bestsellers, promotions, and add-on pairings. Always encourage trying customer favorites!`;
      case 'hinglish':
        return `You are a cheerful, friendly local assistant for *${restaurantName}*. Talk in natural Indian Hinglish (e.g. "Namaste${greetingName}! Welcome to ${restaurantName}. Bataiye aaj kya mangwayenge? Hamare bestsellers sabse famous hain!"). Keep it very respectful and heartwarming.`;
      case 'friendly':
      default:
        return `You are a warm, courteous, and helpful AI hospitality host for *${restaurantName}*. Greet guests with "Namaste${greetingName}!", be super welcoming, guide them with a smile, and make them feel at home.`;
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
    const formattedCustomerName = this.formatCustomerName(customerName);

    // If Custom Text Auto-Reply is enabled and incoming message is not a direct order intent
    if (settings.customAutoReplyEnabled && settings.customAutoReplyMessage && settings.customAutoReplyMessage.trim()) {
      const isOrderIntent = /order|pack|parcel|deliver|karo|bhejo|chaiye|chahiye/i.test(messageText);
      if (!isOrderIntent) {
        // Check if customer reply matches any configured step trigger keywords
        const steps = Array.isArray(settings.customAutoReplySteps) ? settings.customAutoReplySteps : [];
        const cleanMsg = messageText.trim().toLowerCase();
        let matchedStep = null;

        for (const step of steps) {
          if (!step || !step.triggerKeyword || !step.responseMessage) continue;
          const keywords = step.triggerKeyword
            .split(',')
            .map((k) => k.trim().toLowerCase())
            .filter(Boolean);
          if (keywords.some((k) => cleanMsg === k || cleanMsg.includes(k))) {
            matchedStep = step;
            break;
          }
        }

        const rawReply = matchedStep ? matchedStep.responseMessage : settings.customAutoReplyMessage;

        const customReply = rawReply
          .replace(/{restaurant_name}/gi, restaurantName)
          .replace(/{customer_name}/gi, formattedCustomerName || 'Guest')
          .replace(/{phone}/gi, context.phone || '')
          .replace(/{address}/gi, context.address || '')
          .trim();
        return {
          replyText: customReply,
          isAiGenerated: true,
          source: 'custom_auto_reply',
          orderPayload: null,
        };
      }
    }

    const persona = settings.persona || 'friendly';
    const personaPrompt = this.getPersonaPrompt(persona, restaurantName, formattedCustomerName);
    const customPrompt = settings.systemPrompt || '';
    const houseRules = settings.customInstructions || '';
    const autoMenu = settings.autoMenuSuggest !== false;
    const autoOrder = settings.autoOrderTaking !== false;

    // Compose System Instruction
    const systemInstruction = `
${personaPrompt}

RESTAURANT PROFILE:
- Restaurant Name: ${restaurantName}
- Phone: ${context.phone}
- Address: ${context.address}

CUSTOMER PROFILE:
- Customer Name: ${formattedCustomerName || 'Guest'}

GREETING INSTRUCTION:
- In greetings and welcome messages, ALWAYS warmly say "Namaste ${formattedCustomerName || 'Ji'}!" and welcome them to *${restaurantName}*.

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
- VARIANT PRICING RULE: If an item has variants (e.g. "Paneer Pizza" with "Half: ₹100, Full: ₹180") and the customer mentions a variant or portion size (Half, Full, Regular, Large, 500g, 1kg, etc.):
  * Set "variant" to the chosen variant name (e.g. "Half").
  * Set "price" to the exact price of that variant (e.g. 100), NEVER ₹0!
  * If the customer did not specify a variant for a multi-variant item, pick the starting/standard variant price, NEVER ₹0!
- AT THE VERY END OF YOUR RESPONSE, append a strict JSON block wrapped in \`\`\`order_data ... \`\`\` with:
\`\`\`order_data
{
  "isOrder": true,
  "orderType": "delivery" or "takeaway",
  "deliveryAddress": "address if specified or empty string",
  "items": [
    {
      "name": "Exact Name matching the LIVE RESTAURANT MENU",
      "variant": "Half / Full / Regular / Large or empty string",
      "quantity": 2,
      "price": 100,
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

    let modelName = (settings.model || this.defaultModel || 'gemini-2.0-flash').trim();
    if (modelName === 'gemini-3.8-flash' || modelName.includes('3.8') || modelName === 'default') {
      modelName = 'gemini-2.0-flash';
    }

    // 1. Try Gemini API invocation
    if (apiKey) {
      try {
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

        let response = null;
        const candidateModels = [modelName, 'gemini-2.0-flash', 'gemini-1.5-flash'].filter(
          (m, idx, arr) => Boolean(m) && arr.indexOf(m) === idx
        );

        for (const candidateModel of candidateModels) {
          try {
            console.log(`[AIAgentService] 🤖 Invoking Gemini model '${candidateModel}' for ${restaurantName}...`);
            response = await aiClient.models.generateContent({
              model: candidateModel,
              contents,
              config: {
                systemInstruction: {
                  parts: [{ text: systemInstruction }],
                },
                temperature: 0.7,
                maxOutputTokens: 600,
              },
            });
            if (response && response.text) {
              modelName = candidateModel;
              break;
            }
          } catch (modelErr) {
            console.warn(`[AIAgentService] Model '${candidateModel}' attempt notice: ${modelErr.message}`);
          }
        }

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
                  const rawVariant = (it.variant || '').trim();
                  if (!rawName) continue;

                  const matched = productsList.find(
                    (p) => p.name.toLowerCase() === rawName.toLowerCase() ||
                           p.name.toLowerCase().includes(rawName.toLowerCase()) ||
                           rawName.toLowerCase().includes(p.name.toLowerCase())
                  );

                  let finalPrice = 0;
                  let finalName = matched ? matched.name : rawName;
                  let chosenVariant = null;

                  if (matched) {
                    if (Array.isArray(matched.variants) && matched.variants.length > 0) {
                      // 1. Match variant by rawVariant
                      if (rawVariant) {
                        chosenVariant = matched.variants.find(
                          (v) => v.name && v.name.toLowerCase() === rawVariant.toLowerCase()
                        ) || matched.variants.find(
                          (v) => v.name && (v.name.toLowerCase().includes(rawVariant.toLowerCase()) || rawVariant.toLowerCase().includes(v.name.toLowerCase()))
                        );
                      }
                      // 2. Match variant mentioned in rawName
                      if (!chosenVariant) {
                        chosenVariant = matched.variants.find(
                          (v) => v.name && rawName.toLowerCase().includes(v.name.toLowerCase())
                        );
                      }
                      // 3. Match variant mentioned in incoming customer message text
                      if (!chosenVariant && messageText) {
                        chosenVariant = matched.variants.find(
                          (v) => v.name && new RegExp(`\\b${v.name.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')}\\b`, 'i').test(messageText)
                        );
                      }
                      // 4. Match variant by provided it.price
                      const parsedItPrice = parseFloat(it.price) || 0;
                      if (!chosenVariant && parsedItPrice > 0) {
                        chosenVariant = matched.variants.find(
                          (v) => (v.price === parsedItPrice || v.salePrice === parsedItPrice)
                        );
                      }
                      // 5. Fallback to first positive variant price
                      if (!chosenVariant) {
                        chosenVariant = matched.variants.find(
                          (v) => (typeof v.price === 'number' && v.price > 0) || (parseFloat(v.salePrice) > 0)
                        ) || matched.variants[0];
                      }

                      if (chosenVariant) {
                        finalPrice = chosenVariant.price || chosenVariant.salePrice || 0;
                        finalName = `${matched.name} (${chosenVariant.name})`;
                      } else {
                        finalPrice = matched.price || 0;
                      }
                    } else {
                      finalPrice = (typeof matched.price === 'number' && matched.price > 0)
                        ? matched.price
                        : (parseFloat(it.price) || 0);
                    }
                  } else {
                    finalPrice = parseFloat(it.price) || 0;
                  }

                  // If still 0 and it.price is positive, use it.price
                  if (finalPrice <= 0 && parseFloat(it.price) > 0) {
                    finalPrice = parseFloat(it.price);
                  }

                  const foodType = matched ? (matched.isVeg === false ? 'non_veg' : 'veg') : 'veg';

                  validItems.push({
                    productId: matched ? matched._id : undefined,
                    name: finalName,
                    variant: chosenVariant ? chosenVariant.name : (rawVariant || undefined),
                    price: finalPrice,
                    quantity: qty,
                    foodType,
                    note: it.note || '',
                  });
                  subtotal += finalPrice * qty;
                }

                if (validItems.length > 0) {
                  const bObj = business || context?.business;
        const isGstActive = bObj?.orderSettings?.tax?.type !== 'no_gst';
                  const taxRate = isGstActive
                    ? (typeof bObj?.orderSettings?.tax?.percentage === 'number' && bObj.orderSettings.tax.percentage >= 0
                        ? bObj.orderSettings.tax.percentage
                        : 5)
                    : 0;
                  const taxAmount = Number(((subtotal * taxRate) / 100).toFixed(2));
                  const cgst = Number((taxAmount / 2).toFixed(2));
                  const sgst = Number((taxAmount / 2).toFixed(2));
                  const totalAmount = Number((subtotal + taxAmount).toFixed(2));

                  orderPayload = {
                    orderType: parsed.orderType === 'delivery' ? 'delivery' : 'takeaway',
                    deliveryAddress: (parsed.deliveryAddress || '').trim(),
                    items: validItems,
                    subtotal,
                    taxAmount,
                    cgst,
                    sgst,
                    totalAmount,
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
      business: business || context?.business,
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
  generateSmartGroundedReply({ messageText, context, customerName, persona, settings, business = null }) {
    const raw = (messageText || '').toLowerCase().trim();
    const rName = context.restaurantName || 'Apna POS';
    const formattedCustomerName = this.formatCustomerName(customerName);
    const cGreeting = formattedCustomerName ? ` ${formattedCustomerName}` : ' Ji';

    // Greeting / Hello
    if (/^(hi|hello|hey|namaste|pranam|hola|good\s*(morning|afternoon|evening))/i.test(raw)) {
      if (settings.greeting && settings.greeting.trim()) {
        let customGreeting = settings.greeting.trim();

        // 1. Replace {restaurant_name}
        customGreeting = customGreeting.replace(/\{restaurant_name\}/gi, rName);

        // 2. Handle {customer_name} or inject after greeting salutation
        if (customGreeting.includes('{customer_name}')) {
          if (formattedCustomerName) {
            customGreeting = customGreeting.replace(/\{customer_name\}/gi, formattedCustomerName);
          } else {
            customGreeting = customGreeting.replace(/\{customer_name\}/gi, 'Ji');
          }
        } else if (formattedCustomerName) {
          // If greeting starts with Namaste / Hello / Hi, inject customer name
          if (/^namaste[!,\s]*/i.test(customGreeting)) {
            customGreeting = customGreeting.replace(/^namaste[!,\s]*/i, `Namaste ${formattedCustomerName}! `);
          } else if (/^hello[!,\s]*/i.test(customGreeting)) {
            customGreeting = customGreeting.replace(/^hello[!,\s]*/i, `Hello ${formattedCustomerName}! `);
          } else if (/^hi[!,\s]*/i.test(customGreeting)) {
            customGreeting = customGreeting.replace(/^hi[!,\s]*/i, `Hi ${formattedCustomerName}! `);
          } else {
            customGreeting = `Namaste ${formattedCustomerName}! ` + customGreeting;
          }
        } else if (/^namaste[!,\s]*/i.test(customGreeting)) {
          customGreeting = customGreeting.replace(/^namaste[!,\s]*/i, `Namaste Ji! `);
        }

        customGreeting = customGreeting.replace(/\s+/g, ' ').replace(/!\s*!+/g, '!').trim();

        return {
          replyText: `✨ *WELCOME TO ${rName.toUpperCase()}* ✨\n━━━━━━━━━━━━━━━━━━━━\n${customGreeting}\n━━━━━━━━━━━━━━━━━━━━\n💡 _Reply with *Menu*, *Specials*, or type your order directly!_`,
          orderPayload: null,
        };
      }
      if (persona === 'hinglish') {
        return {
          replyText: `✨ *WELCOME TO ${rName.toUpperCase()}* ✨\n━━━━━━━━━━━━━━━━━━━━\n🙏 *Namaste${cGreeting}!* *${rName}* mein aapka swagat hai!\n\nAaj aap kya mangwana pasand karenge? Hamara menu dekhne ke liye *Menu* type karein, ya aaj ke bestsellers jaanein! 😊\n━━━━━━━━━━━━━━━━━━━━\n💡 _Type your order directly to place it in our kitchen!_`,
          orderPayload: null,
        };
      }
      return {
        replyText: `✨ *WELCOME TO ${rName.toUpperCase()}* ✨\n━━━━━━━━━━━━━━━━━━━━\n🙏 *Namaste${cGreeting}!* Welcome to *${rName}*.\n\nI am your smart AI hospitality assistant. How can I delight you today?\n\n✨ *Quick Options:*\n• 📋 Send *Menu* for all dishes & drinks\n• ⭐ Send *Specials* for Chef's bestsellers\n• 🎉 Send *Offers* for today's discount coupons\n• 🍽️ Send *Book Table* to reserve dining seats\n• 🛍️ Type your order directly to place it!\n━━━━━━━━━━━━━━━━━━━━\n💬 _What would you like to have today?_`,
        orderPayload: null,
      };
    }

    // Menu inquiry
    if (/(menu|food|dishes|items|item list|catalogue|catalog|price list|kya kya hai|kya milta hai|rate|card)/i.test(raw)) {
      return {
        replyText: `📋 *${rName.toUpperCase()} — MENU & SPECIALTIES* 📋\n━━━━━━━━━━━━━━━━━━━━\n${context.menuText}\n━━━━━━━━━━━━━━━━━━━━\n🎉 *Today's Offers:*\n${context.offersText}\n━━━━━━━━━━━━━━━━━━━━\n💡 _Reply with dish names & quantities to order directly (e.g. "1 Masala Chai, 2 Samosa")!_`,
        orderPayload: null,
      };
    }

    // Order taking intent & direct POS order processing
    const productsList = context.products || [];
    const orderKeywordsRegex = /(order|chahiye|pack|deliver|parcel|bhejo|mangwa|send|lao|de do|please|want|need|give|bring|plate|plates|half|full|glass|\d+\s*(?:x|plate|plates|pcs|half|full)?)/i;
    const hasOrderKeyword = orderKeywordsRegex.test(raw);
    const mentionsAnyProduct = productsList.some((prod) => {
      if (!prod || !prod.name) return false;
      const cleanName = prod.name.trim().toLowerCase();
      return cleanName.length >= 3 && raw.includes(cleanName);
    });

    if ((hasOrderKeyword || mentionsAnyProduct) && settings.autoOrderTaking !== false) {
      const validItems = [];
      let calculatedSubtotal = 0;

      for (const prod of productsList) {
        if (!prod || !prod.name) continue;
        const pName = prod.name.toLowerCase().trim();
        if (pName.length < 2) continue;

        const escaped = pName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const regex = new RegExp(`(?:(\\d+)\\s*(?:x|plate|plates|glass|cup|cups|pieces|pcs|bottle|bottles)?\\s*)?${escaped}(?:\\s*(?:x|plate|plates|glass|cup|cups|pieces|pcs|bottle|bottles)?\\s*(\\d+))?`, 'i');
        const match = raw.match(regex);
        if (match) {
          const qty = parseInt(match[1] || match[2] || '1', 10) || 1;
          let pPrice = typeof prod.price === 'number' ? prod.price : (parseFloat(prod.price) || 0);
          let itemName = prod.name;
          let variantName = '';

          if (Array.isArray(prod.variants) && prod.variants.length > 0) {
            let matchedVariant = null;
            // Check if any variant name is mentioned in user message
            for (const v of prod.variants) {
              if (v.name && new RegExp(`\\b${v.name.replace(/[.*+?^${}()|[\\]\\]/g, '\\$&')}\\b`, 'i').test(raw)) {
                matchedVariant = v;
                break;
              }
            }
            if (!matchedVariant) {
              matchedVariant = prod.variants.find((v) => (typeof v.price === 'number' && v.price > 0) || (parseFloat(v.salePrice) > 0)) || prod.variants[0];
            }
            if (matchedVariant) {
              pPrice = matchedVariant.price || matchedVariant.salePrice || pPrice;
              variantName = matchedVariant.name;
              itemName = `${prod.name} (${matchedVariant.name})`;
            }
          }

          validItems.push({
            productId: prod._id,
            name: itemName,
            variant: variantName || undefined,
            price: pPrice,
            quantity: qty,
            foodType: prod.isVeg === false ? 'non_veg' : 'veg',
            note: '',
          });
          calculatedSubtotal += pPrice * qty;
        }
      }

      if (validItems.length > 0) {
        const isDelivery = /\b(deliver|delivery|home\s*delivery|bhejo|ghar\s*pe|ghar\s*par|send\s*to)\b/i.test(raw);
        const isTakeaway = /\b(takeaway|take\s*away|parcel|pack|pickup|pick\s*up|le\s*jaana|pack\s*karo|parcel\s*karo)\b/i.test(raw);

        // Extract address if provided
        let extractedAddress = '';
        const addressMatch = messageText.match(/(?:at|to|address[:\s]|near|deliver\s+to|send\s+to)\s+([A-Za-z0-9\s,\-\/\.]{5,100})/i);
        if (addressMatch) {
          extractedAddress = addressMatch[1].trim();
        } else {
          const directAddr = messageText.match(/(?:flat|room|house|h\.no|block|plot|sector|colony|apartment|society|nagar|road|street|gali|lane|floor|building|tower)\s*([A-Za-z0-9\s,\-\/\.]{4,80})/i);
          if (directAddr) {
            extractedAddress = directAddr[0].trim();
          }
        }

        let finalOrderType = 'takeaway';
        if (isDelivery || extractedAddress) {
          finalOrderType = 'delivery';
        } else if (isTakeaway) {
          finalOrderType = 'takeaway';
        }

        const bObj = business || context?.business;
        const isGstActive = bObj?.orderSettings?.tax?.type !== 'no_gst';
        const taxRate = isGstActive
          ? (typeof bObj?.orderSettings?.tax?.percentage === 'number' && bObj.orderSettings.tax.percentage >= 0
              ? bObj.orderSettings.tax.percentage
              : 5)
          : 0;
        const taxAmount = Number(((calculatedSubtotal * taxRate) / 100).toFixed(2));
        const cgst = Number((taxAmount / 2).toFixed(2));
        const sgst = Number((taxAmount / 2).toFixed(2));
        const totalAmount = Number((calculatedSubtotal + taxAmount).toFixed(2));

        const orderPayload = {
          orderType: finalOrderType,
          deliveryAddress: extractedAddress || '',
          items: validItems,
          subtotal: calculatedSubtotal,
          taxAmount,
          cgst,
          sgst,
          totalAmount,
          notes: `Ordered via WhatsApp AI Agent (${finalOrderType})`,
          source: 'whatsapp_ai',
        };

        const itemsListStr = validItems.map((i) => `• ${i.quantity}x *${i.name}* (₹${(i.price * i.quantity).toFixed(0)})`).join('\n');

        let typeStr = finalOrderType === 'delivery'
          ? (extractedAddress ? `🛵 *Type*: *Home Delivery*\n📍 *Deliver To*: *${extractedAddress}*` : `🛵 *Type*: *Home Delivery*\n📍 *Delivery Address*: _Please reply with your delivery address!_`)
          : `🛍️ *Type*: *Takeaway / Pickup*\n💡 _(For Home Delivery, reply with your address!)_`;

        let summaryTaxes = '';
        if (taxAmount > 0) {
          summaryTaxes = `\n🧾 *Taxes (GST ${taxRate}%)*: ₹${taxAmount.toFixed(2)}`;
        }

        const reply = `🧾 *ORDER RECEIVED* 🧾\n*${rName}*\n━━━━━━━━━━━━━━━━━━━━\n📦 *Order Summary*:\n${itemsListStr}\n━━━━━━━━━━━━━━━━━━━━\n💵 *Subtotal*: ₹${calculatedSubtotal}${summaryTaxes}\n💰 *Estimated Total*: *₹${totalAmount}*\n${typeStr}\n⏳ *Status*: 🕒 *Awaiting Restaurant Confirmation*\n━━━━━━━━━━━━━━━━━━━━\n🙏 _We have sent your order to the restaurant counter. You will receive an instant WhatsApp update when your order is accepted!_ 🚀`;

        return {
          replyText: reply,
          orderPayload,
        };
      }
    }

    // Recommendations / Bestsellers / Specials
    if (/(special|best|bestseller|recommend|famous|tasty|suggest|top)/i.test(raw)) {
      const bestList = context.menuText.split('\n').filter((l) => l.includes('Bestseller') || l.includes('Special')).slice(0, 6).join('\n') || context.menuText.split('\n').slice(0, 6).join('\n');
      return {
        replyText: `⭐ *CHEF'S TOP RECOMMENDATIONS* ⭐\n*${rName}*\n━━━━━━━━━━━━━━━━━━━━\nOur guests love these signature specialties:\n\n${bestList}\n━━━━━━━━━━━━━━━━━━━━\n💡 _Would you like to order any of these? Just text the dish name!_`,
        orderPayload: null,
      };
    }

    // Pure Veg / Vegetarian inquiry
    if (/\b(only\s*veg|pure\s*veg|veg\s*only|veg\s*menu|veg\s*options|veg\s*items|shakahari)\b/i.test(raw) && !/non[-\s]?veg/i.test(raw)) {
      const vegItems = context.menuText.split('\n').filter((l) => l.includes('[Veg]')).slice(0, 6).join('\n');
      return {
        replyText: `🥦 *PURE VEG SPECIALTIES* 🥦\n*${rName}*\n━━━━━━━━━━━━━━━━━━━━\n${vegItems || 'All our vegetarian items are freshly prepared with pure ingredients!'}\n━━━━━━━━━━━━━━━━━━━━\n💡 _Reply with dish names to order or inquire!_`,
        orderPayload: null,
      };
    }

    // Non-Veg inquiry
    if (/\b(only\s*non[-\s]?veg|non[-\s]?veg\s*menu|non[-\s]?veg\s*options|non[-\s]?veg\s*items)\b/i.test(raw)) {
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

    // Unmatched order intent with no valid items recognized
    if (hasOrderKeyword) {
      return {
        replyText: `📝 *ORDER FROM ${rName.toUpperCase()}*\n━━━━━━━━━━━━━━━━━━━━\nI would be delighted to place your order! 🍽️\n\nPlease reply with the dish name & quantity from our menu (e.g. *"2 Crispy Veg Burger"* or *"1 Margherita Pizza"*).\n\n💡 _Send *Menu* to see the full list of available items!_`,
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
