const mongoose = require('mongoose');
const Order = require('../models/Order');
const Product = require('../models/Product');
const Category = require('../models/Category');

const STATES = Object.freeze({
  IDLE: 'IDLE',
  WAITING_FOR_ORDER_TYPE: 'WAITING_FOR_ORDER_TYPE',
  WAITING_FOR_PRODUCT_SELECTION: 'WAITING_FOR_PRODUCT_SELECTION',
  WAITING_FOR_VARIANT_SELECTION: 'WAITING_FOR_VARIANT_SELECTION',
  WAITING_FOR_QUANTITY: 'WAITING_FOR_QUANTITY',
  CART_ACTIVE: 'CART_ACTIVE',
  WAITING_FOR_DELIVERY_ADDRESS: 'WAITING_FOR_DELIVERY_ADDRESS',
  WAITING_FOR_ADDRESS_CONFIRMATION: 'WAITING_FOR_ADDRESS_CONFIRMATION',
  WAITING_FOR_ORDER_CONFIRMATION: 'WAITING_FOR_ORDER_CONFIRMATION',
  ORDER_AWAITING_BUSINESS_DECISION: 'ORDER_AWAITING_BUSINESS_DECISION',
});

class WhatsAppOrderSessionService {
  constructor() {
    this.STATES = STATES;
    // Map of sessionKey (`${businessId}:${customerPhone}`) -> Session Object
    this._sessions = new Map();
    // Map of sessionKey -> Promise chain for sequential execution per customer
    this._queues = new Map();
    // Deduplication cache for Meta incoming message IDs (messageId -> timestamp)
    this._processedMessageIds = new Map();

    // Cleanup stale sessions every 10 minutes (TTL: 30 minutes)
    const cleanupTimer = setInterval(() => this._cleanupStaleSessions(), 10 * 60 * 1000);
    if (cleanupTimer.unref) cleanupTimer.unref();
  }

  /**
   * Build unique isolation key per business profile and customer phone
   */
  _buildKey(businessId, customerPhone) {
    const bId = (businessId?._id || businessId || '').toString().trim();
    const cleanPhone = (customerPhone || '').replace(/\D/g, '').slice(-10);
    return `${bId}:${cleanPhone}`;
  }

  /**
   * Check and record incoming Meta messageId to prevent duplicate webhook executions
   */
  isDuplicateMessage(messageId) {
    if (!messageId) return false;
    if (this._processedMessageIds.has(messageId)) {
      return true;
    }
    this._processedMessageIds.set(messageId, Date.now());

    // Prune entries older than 15 minutes when map grows large
    if (this._processedMessageIds.size > 2000) {
      const cutoff = Date.now() - 15 * 60 * 1000;
      for (const [mid, ts] of this._processedMessageIds.entries()) {
        if (ts < cutoff) this._processedMessageIds.delete(mid);
      }
    }
    return false;
  }

  /**
   * Enqueue a task for a specific customer to guarantee strict message sequence
   * while allowing multiple different customers to process fully in parallel.
   */
  async enqueue(businessId, customerPhone, taskFn) {
    const key = this._buildKey(businessId, customerPhone);
    const previousPromise = this._queues.get(key) || Promise.resolve();

    const currentPromise = (async () => {
      try {
        await previousPromise;
      } catch (_) {
        // Ignore previous errors so subsequent messages are not blocked
      }
      return await taskFn();
    })();

    this._queues.set(key, currentPromise);
    currentPromise.finally(() => {
      if (this._queues.get(key) === currentPromise) {
        this._queues.delete(key);
      }
    });

    return currentPromise;
  }

  /**
   * Get or initialize session state for a customer
   */
  getSession(businessId, customerPhone) {
    const key = this._buildKey(businessId, customerPhone);
    let session = this._sessions.get(key);
    if (!session) {
      session = {
        businessId: (businessId?._id || businessId).toString(),
        customerPhone: (customerPhone || '').replace(/\D/g, ''),
        state: 'IDLE',
        orderType: null, // 'delivery' | 'takeaway'
        menuMapping: [],
        selectedProduct: null,
        variantMapping: [],
        selectedVariant: null,
        cart: [],
        deliveryAddress: '',
        pendingAddressToConfirm: '',
        recentOrderId: null,
        recentOrderNumber: null,
        lastIntent: null,
        lastActiveAt: new Date(),
      };
      this._sessions.set(key, session);
    } else {
      session.lastActiveAt = new Date();
    }
    return session;
  }

  /**
   * Update active customer session state
   */
  updateSession(businessId, customerPhone, updates = {}) {
    const session = this.getSession(businessId, customerPhone);
    Object.assign(session, updates, { lastActiveAt: new Date() });
    return session;
  }

  /**
   * Record a newly placed order in the customer's session
   */
  recordOrder(businessId, customerPhone, order) {
    if (!order) return;
    const session = this.getSession(businessId, customerPhone);
    session.recentOrderId = order._id ? order._id.toString() : order.id;
    session.recentOrderNumber = order.orderNumber;
    session.orderType = order.orderType || 'takeaway';
    session.deliveryAddress = order.deliveryAddress || '';
    session.lastIntent = order.orderType === 'delivery' && !order.deliveryAddress ? 'awaiting_address' : 'order_placed';
    session.state = 'ORDER_AWAITING_BUSINESS_DECISION';
    session.cart = [];
    session.lastActiveAt = new Date();
    return session;
  }

  /**
   * Main entry point for processing customer messages through the conversation state machine
   */
  async processConversationMessage(params) {
    const res = await this._processConversationMessageCore(params);
    if (res && !res.session && !res.isDuplicate) {
      const bId = (params.business?._id || params.business?.id || params.businessId || '').toString();
      const cleanPhone = (params.customerPhone || '').replace(/\D/g, '');
      res.session = this.getSession(bId, cleanPhone);
    }
    return res;
  }

  async _processConversationMessageCore({
    business,
    customerPhone,
    messageText,
    customerName,
    messageId,
    chat,
    targetUserId,
  }) {
    const raw = (messageText || '').trim();
    const rawLower = raw.toLowerCase();
    const bId = (business._id || business.id).toString();
    const cleanPhone = (customerPhone || '').replace(/\D/g, '');

    // 1. Webhook Deduplication Check
    if (messageId && this.isDuplicateMessage(messageId)) {
      console.log(`[WhatsAppOrderSessionService] ⚠️ Dropping duplicate Meta webhook message: ${messageId}`);
      return { isDuplicate: true };
    }

    const session = this.getSession(bId, cleanPhone);

    // 2. Active Pending Order Address/Type update check (preserves multi-turn updates on pending orders)
    const pendingUpdate = await this.handleAddressOrTypeUpdate({
      businessId: bId,
      customerPhone: cleanPhone,
      messageText: raw,
      chat,
      targetUserId,
    });
    if (pendingUpdate && pendingUpdate.isHandled) {
      return {
        replyText: pendingUpdate.replyText,
        buttons: null,
        orderPayload: null,
        handled: true,
      };
    }

    const rName =
      (business.profile?.companyName && business.profile.companyName.trim()) ||
      (business.companyName && business.companyName.trim()) ||
      (business.restaurantName && business.restaurantName.trim()) ||
      (business.name && business.name.trim()) ||
      (business.profile?.name && business.profile.name.trim()) ||
      'Our Restaurant';

    // 3. Greeting / Fresh Order Reset Trigger
    const isGreeting = /^(hi|hello|hey|namaste|pranam|start|hola|greeting|shuru)\b/i.test(rawLower);
    const isExplicitOrderStart = /^(new\s*order|start\s*order|order|fresh\s*order)\b/i.test(rawLower);

    if (isGreeting || isExplicitOrderStart || session.state === 'IDLE' || !session.state) {
      session.cart = [];
      session.selectedProduct = null;
      session.selectedVariant = null;
      session.deliveryAddress = '';
      session.pendingAddressToConfirm = '';

      // Check if the message itself already specifies Delivery or Takeaway
      const mentionsDel = rawLower.includes('delivery') || rawLower.includes('deliver') || rawLower.includes('ghar');
      const mentionsTake = rawLower.includes('takeaway') || rawLower.includes('take away') || rawLower.includes('parcel') || rawLower.includes('pickup') || rawLower.includes('pack');

      if (mentionsDel && !mentionsTake) {
        session.orderType = 'delivery';
        const menuData = await this._buildNumberedMenu(bId);
        session.menuMapping = menuData.mapping;
        session.activeMenu = menuData.mapping;
        session.state = 'WAITING_FOR_PRODUCT_SELECTION';

        const promptText = `Hello! 👋 Welcome to *${rName}*.\n\nGreat! 🚚 Here is our available menu for *Delivery*:\n\n${menuData.menuText}\n━━━━━━━━━━━━━━━━━━━━\nPlease enter the number of the product you want to order.\n_Example: 1_`;
        return {
          replyText: promptText,
          buttons: null,
          orderPayload: null,
          handled: true,
          session,
        };
      } else if (mentionsTake && !mentionsDel) {
        session.orderType = 'takeaway';
        const menuData = await this._buildNumberedMenu(bId);
        session.menuMapping = menuData.mapping;
        session.activeMenu = menuData.mapping;
        session.state = 'WAITING_FOR_PRODUCT_SELECTION';

        const promptText = `Hello! 👋 Welcome to *${rName}*.\n\nGreat! 🛍️ Here is our available menu for *Takeaway / Pickup*:\n\n${menuData.menuText}\n━━━━━━━━━━━━━━━━━━━━\nPlease enter the number of the product you want to order.\n_Example: 1_`;
        return {
          replyText: promptText,
          buttons: null,
          orderPayload: null,
          handled: true,
          session,
        };
      }

      session.state = 'WAITING_FOR_ORDER_TYPE';
      session.orderType = null;

      const greetingReply = `Hello! 👋 Welcome to *${rName}*.\n\nWhat would you like to do today?\nChoose your order type below to get started:\n\n1. 🚚 *Delivery*\n2. 🛍️ *Takeaway*\n\n_Reply with 1 for Delivery or 2 for Takeaway_`;

      return {
        replyText: greetingReply,
        buttons: [
          { id: 'btn_delivery', title: '🚚 Delivery' },
          { id: 'btn_takeaway', title: '🛍️ Takeaway' },
        ],
        orderPayload: null,
        handled: true,
        session,
      };
    }

    // 4. State: WAITING_FOR_ORDER_TYPE
    if (session.state === 'WAITING_FOR_ORDER_TYPE') {
      const isDel = rawLower === '1' || rawLower.includes('delivery') || rawLower.includes('deliver') || rawLower.includes('ghar');
      const isTake = rawLower === '2' || rawLower.includes('takeaway') || rawLower.includes('take away') || rawLower.includes('parcel') || rawLower.includes('pickup') || rawLower.includes('pack');

      if (isDel) {
        session.orderType = 'delivery';
      } else if (isTake) {
        session.orderType = 'takeaway';
      } else {
        return {
          replyText: `Please choose your order type below to get started:\n\n1. 🚚 *Delivery*\n2. 🛍️ *Takeaway*\n\n_Reply with 1 or 2_`,
          buttons: [
            { id: 'btn_delivery', title: '🚚 Delivery' },
            { id: 'btn_takeaway', title: '🛍️ Takeaway' },
          ],
          orderPayload: null,
          handled: true,
          session,
        };
      }

      // Fetch dynamic numbered menu from database
      const menuData = await this._buildNumberedMenu(bId);
      session.menuMapping = menuData.mapping;
      session.activeMenu = menuData.mapping;
      session.state = 'WAITING_FOR_PRODUCT_SELECTION';

      const typeIcon = session.orderType === 'delivery' ? '🚚' : '🛍️';
      const typeLabel = session.orderType === 'delivery' ? 'Delivery' : 'Takeaway / Pickup';
      const promptText = `Great! ${typeIcon} Here is our available menu for *${typeLabel}*.\n\n${menuData.menuText}\n━━━━━━━━━━━━━━━━━━━━\nPlease enter the number of the product you want to order.\n_Example: 2_`;

      return {
        replyText: promptText,
        buttons: null,
        orderPayload: null,
        handled: true,
        session,
      };
    }

    // 5. State: WAITING_FOR_PRODUCT_SELECTION
    if (session.state === 'WAITING_FOR_PRODUCT_SELECTION') {
      if (!session.menuMapping || session.menuMapping.length === 0) {
        const menuData = await this._buildNumberedMenu(bId);
        session.menuMapping = menuData.mapping;
        session.activeMenu = menuData.mapping;
      }

      const inputNum = parseInt(raw, 10);
      let matchedItem = null;

      if (!isNaN(inputNum)) {
        matchedItem = session.menuMapping.find((m) => m.num === inputNum);
      }

      if (!matchedItem) {
        // Secondary match: Check if customer typed dish name directly
        matchedItem = session.menuMapping.find((m) => rawLower.includes(m.name.toLowerCase()));
      }

      if (!matchedItem) {
        return {
          replyText: `❌ Invalid selection: That number isn't in our menu. 😊\n\nPlease enter a valid product number (1 to ${session.menuMapping.length}).`,
          buttons: null,
          orderPayload: null,
          handled: true,
        };
      }

      return this._handleProductChosen(session, matchedItem);
    }

    // 6. State: WAITING_FOR_VARIANT_SELECTION
    if (session.state === 'WAITING_FOR_VARIANT_SELECTION') {
      const variants = session.variantMapping || [];
      const inputNum = parseInt(raw, 10);
      let matchedVariant = null;

      if (!isNaN(inputNum)) {
        matchedVariant = variants.find((v) => v.num === inputNum);
      }
      // Support letter choices A, B, C, D (e.g. 'a' -> first variant, 'b' -> second variant)
      if (!matchedVariant && raw.trim().length === 1) {
        const charCode = rawLower.charCodeAt(0);
        if (charCode >= 97 && charCode <= 122) {
          const letterIdx = charCode - 97;
          if (letterIdx >= 0 && letterIdx < variants.length) {
            matchedVariant = variants[letterIdx];
          }
        }
      }
      if (!matchedVariant) {
        matchedVariant = variants.find((v) => rawLower.includes(v.name.toLowerCase()));
      }

      if (!matchedVariant) {
        return {
          replyText: `Sorry, please enter a valid option number (1 to ${variants.length}) or letter (A, B...).\n\n${variants.map((v) => `${v.num}. ${v.name} (Option ${String.fromCharCode(64 + v.num)}) — ₹${v.price}`).join('\n')}`,
          buttons: variants.slice(0, 3).map((v) => ({ id: `var_${v.num}`, title: `${v.name} (₹${v.price})`.slice(0, 20) })),
          orderPayload: null,
          handled: true,
        };
      }

      session.selectedVariant = matchedVariant;
      session.state = 'WAITING_FOR_QUANTITY';

      return {
        replyText: `How many *${session.selectedProduct.name} (${matchedVariant.name})* would you like?\n\n_Reply with quantity (e.g. 1, 2, 3...)_`,
        buttons: null,
        orderPayload: null,
        handled: true,
      };
    }

    // 7. State: WAITING_FOR_QUANTITY
    if (session.state === 'WAITING_FOR_QUANTITY') {
      const qtyMatch = raw.match(/\b\d+\b/);
      const qty = qtyMatch ? parseInt(qtyMatch[0], 10) : 0;

      if (!qty || qty <= 0 || qty > 100) {
        return {
          replyText: `Please enter a valid quantity (e.g. 1, 2, 3...).`,
          buttons: null,
          orderPayload: null,
          handled: true,
        };
      }

      const prod = session.selectedProduct;
      const v = session.selectedVariant;
      const unitPrice = v ? (v.price || prod.price) : (prod.price || 0);
      const itemName = v ? `${prod.name} (${v.name})` : prod.name;

      if (!session.cart) session.cart = [];
      const existingCartItem = session.cart.find(
        (i) => i.productId === prod.id && i.variant === (v ? v.name : undefined)
      );

      if (existingCartItem) {
        existingCartItem.quantity += qty;
      } else {
        session.cart.push({
          productId: prod.id,
          name: itemName,
          variant: v ? v.name : undefined,
          price: unitPrice,
          quantity: qty,
          taxPercentage: typeof prod.taxPercentage === 'number' ? prod.taxPercentage : undefined,
          foodType: prod.foodType || 'veg',
        });
      }

      session.state = 'CART_ACTIVE';
      session.selectedProduct = null;
      session.selectedVariant = null;

      const cartSummaryStr = session.cart
        .map((i, idx) => `${idx + 1}. *${i.name}* × ${i.quantity} — ₹${(i.price * i.quantity).toFixed(0)}`)
        .join('\n');

      const financials = this._calculateFinancials(business, session.cart, session.orderType);

      let totalsText = `💵 *Cart Subtotal*: ₹${financials.subtotal}`;
      if (financials.taxAmount > 0) {
        totalsText += `\n🧾 *Taxes (GST ${financials.gstRateLabel})*: ₹${financials.taxAmount.toFixed(2)}`;
        totalsText += `\n💰 *Cart Total*: *₹${financials.cartTotalWithTax.toFixed(2).replace(/\.00$/, '')}*`;
      } else {
        totalsText = `💰 *Cart Subtotal*: *₹${financials.subtotal}*`;
      }

      const cartReply = `✅ *Added to your cart!*\n\n${cartSummaryStr}\n━━━━━━━━━━━━━━━━━━━━\n${totalsText}\n\nWould you like to add more items or proceed to checkout?\n\n1. ➕ *Add More Items*\n2. 🛒 *Checkout*\n3. ❌ *Cancel Order*`;

      return {
        replyText: cartReply,
        buttons: [
          { id: 'btn_add_more', title: '➕ Add More Items' },
          { id: 'btn_checkout', title: '🛒 Checkout' },
          { id: 'btn_cancel_order', title: '❌ Cancel Order' },
        ],
        orderPayload: null,
        handled: true,
      };
    }

    // 8. State: CART_ACTIVE
    if (session.state === 'CART_ACTIVE') {
      const isAddMore = rawLower === '1' || rawLower.includes('add') || rawLower.includes('more') || rawLower.includes('item');
      const isCheckout = rawLower === '2' || rawLower.includes('checkout') || rawLower.includes('proceed') || rawLower.includes('order');
      const isCancel = rawLower === '3' || rawLower.includes('cancel');

      if (isCancel) {
        session.cart = [];
        session.state = 'IDLE';
        return {
          replyText: `❌ Your order has been cancelled.\n\nSend *Hi* anytime to start a fresh order! 😊`,
          buttons: null,
          orderPayload: null,
          handled: true,
        };
      }

      if (isAddMore) {
        if (!session.menuMapping || session.menuMapping.length === 0) {
          const menuData = await this._buildNumberedMenu(bId);
          session.menuMapping = menuData.mapping;
        }
        session.state = 'WAITING_FOR_PRODUCT_SELECTION';
        return {
          replyText: `🍽️ Please enter the number of the next product you want to order:\n_(e.g. 1 to ${session.menuMapping.length})_`,
          buttons: null,
          orderPayload: null,
          handled: true,
        };
      }

      if (isCheckout) {
        if (!session.cart || session.cart.length === 0) {
          session.state = 'WAITING_FOR_PRODUCT_SELECTION';
          return {
            replyText: `Your cart is empty! Please choose a product number to get started.`,
            buttons: null,
            orderPayload: null,
            handled: true,
          };
        }

        if (session.orderType === 'takeaway') {
          session.state = 'WAITING_FOR_ORDER_CONFIRMATION';
          return this._buildOrderReviewResponse(business, session);
        }

        // Delivery orders request complete address
        session.state = 'WAITING_FOR_DELIVERY_ADDRESS';
        return {
          replyText: `📍 *Please share your complete delivery address.*\n\nInclude:\n• House or flat number\n• Building or street name\n• Area or locality\n• City\n• PIN code\n• Landmark, if applicable\n\n_You can type the complete address in one message._`,
          buttons: null,
          orderPayload: null,
          handled: true,
        };
      }

      // If customer enters a product number directly while in CART_ACTIVE, process it
      const directNum = parseInt(raw, 10);
      if (session.menuMapping && session.menuMapping.find((m) => m.num === directNum)) {
        session.state = 'WAITING_FOR_PRODUCT_SELECTION';
        const item = session.menuMapping.find((m) => m.num === directNum);
        return this._handleProductChosen(session, item);
      }

      return {
        replyText: `Would you like to add more items or proceed to checkout?\n\n1. ➕ *Add More Items*\n2. 🛒 *Checkout*\n3. ❌ *Cancel Order*`,
        buttons: [
          { id: 'btn_add_more', title: '➕ Add More Items' },
          { id: 'btn_checkout', title: '🛒 Checkout' },
          { id: 'btn_cancel_order', title: '❌ Cancel Order' },
        ],
        orderPayload: null,
        handled: true,
      };
    }

    // 9. State: WAITING_FOR_DELIVERY_ADDRESS
    if (session.state === 'WAITING_FOR_DELIVERY_ADDRESS') {
      const cleanAddress = raw.replace(/^(?:please\s+)?(?:deliver\s+(?:to|at)|(?:my\s+)?address\s*(?:is|:)?)\s*/i, '').trim();

      if (cleanAddress.length < 8) {
        return {
          replyText: `Thanks! Could you also share your PIN code and Area so we can complete your delivery address accurately?`,
          buttons: null,
          orderPayload: null,
          handled: true,
        };
      }

      session.pendingAddressToConfirm = cleanAddress;
      session.state = 'WAITING_FOR_ADDRESS_CONFIRMATION';

      return {
        replyText: `📍 *Please confirm your delivery address:*\n\n${cleanAddress}\n\nIs this correct?\n\n1. ✅ *Confirm Address*\n2. ✏️ *Edit Address*`,
        buttons: [
          { id: 'btn_confirm_addr', title: '✅ Confirm Address' },
          { id: 'btn_edit_addr', title: '✏️ Edit Address' },
        ],
        orderPayload: null,
        handled: true,
      };
    }

    // 10. State: WAITING_FOR_ADDRESS_CONFIRMATION
    if (session.state === 'WAITING_FOR_ADDRESS_CONFIRMATION') {
      const isConfirm = rawLower === '1' || rawLower.includes('confirm') || rawLower.includes('yes') || rawLower.includes('correct') || rawLower.includes('sahi');
      const isEdit = rawLower === '2' || rawLower.includes('edit') || rawLower.includes('change') || rawLower.includes('no');

      if (isEdit) {
        session.state = 'WAITING_FOR_DELIVERY_ADDRESS';
        return {
          replyText: `Please type your updated delivery address:`,
          buttons: null,
          orderPayload: null,
          handled: true,
        };
      }

      if (isConfirm) {
        session.deliveryAddress = session.pendingAddressToConfirm;
        session.state = 'WAITING_FOR_ORDER_CONFIRMATION';
        return this._buildOrderReviewResponse(business, session);
      }

      return {
        replyText: `Is your delivery address correct?\n\n${session.pendingAddressToConfirm}\n\n1. ✅ *Confirm Address*\n2. ✏️ *Edit Address*`,
        buttons: [
          { id: 'btn_confirm_addr', title: '✅ Confirm Address' },
          { id: 'btn_edit_addr', title: '✏️ Edit Address' },
        ],
        orderPayload: null,
        handled: true,
      };
    }

    // 11. State: WAITING_FOR_ORDER_CONFIRMATION
    if (session.state === 'WAITING_FOR_ORDER_CONFIRMATION') {
      const isConfirm = rawLower === '1' || rawLower.includes('confirm') || rawLower.includes('yes') || rawLower.includes('place');
      const isEditCart = rawLower === '2' || rawLower.includes('edit') || rawLower.includes('cart');
      const isCancel = rawLower === '3' || rawLower.includes('cancel');

      if (isCancel) {
        session.cart = [];
        session.state = 'IDLE';
        return {
          replyText: `❌ Your order has been cancelled.\n\nSend *Hi* anytime to start a fresh order! 😊`,
          buttons: null,
          orderPayload: null,
          handled: true,
        };
      }

      if (isEditCart) {
        session.state = 'CART_ACTIVE';
        const cartSummaryStr = session.cart
          .map((i, idx) => `${idx + 1}. *${i.name}* × ${i.quantity} — ₹${(i.price * i.quantity).toFixed(0)}`)
          .join('\n');
        const financials = this._calculateFinancials(business, session.cart, session.orderType);

        let totalsText = `💵 *Subtotal*: ₹${financials.subtotal}`;
        if (financials.taxAmount > 0) {
          totalsText += `\n🧾 *Taxes (GST ${financials.gstRateLabel})*: ₹${financials.taxAmount.toFixed(2)}`;
          totalsText += `\n💰 *Cart Total*: *₹${financials.cartTotalWithTax.toFixed(2).replace(/\.00$/, '')}*`;
        } else {
          totalsText += `\n💰 *Cart Subtotal*: *₹${financials.subtotal}*`;
        }

        return {
          replyText: `📦 *Current Cart*:\n${cartSummaryStr}\n━━━━━━━━━━━━━━━━━━━━\n${totalsText}\n\n1. ➕ *Add More Items*\n2. 🛒 *Checkout*\n3. ❌ *Cancel Order*`,
          buttons: [
            { id: 'btn_add_more', title: '➕ Add More Items' },
            { id: 'btn_checkout', title: '🛒 Checkout' },
            { id: 'btn_cancel_order', title: '❌ Cancel Order' },
          ],
          orderPayload: null,
          handled: true,
        };
      }

      if (isConfirm) {
        const financials = this._calculateFinancials(business, session.cart, session.orderType);

        const orderPayload = {
          orderType: session.orderType || 'takeaway',
          deliveryAddress: session.deliveryAddress || '',
          items: session.cart.map((i) => ({
            productId: i.productId,
            name: i.name,
            variant: i.variant,
            price: i.price,
            quantity: i.quantity,
            taxPercentage: i.taxPercentage,
            foodType: i.foodType || 'veg',
            note: '',
          })),
          subtotal: financials.subtotal,
          taxAmount: financials.taxAmount,
          cgst: financials.cgst,
          sgst: financials.sgst,
          deliveryFee: financials.deliveryFee,
          totalAmount: financials.totalAmount,
          notes: `Ordered via WhatsApp AI Agent (${session.orderType})`,
          source: 'whatsapp_ai',
        };

        session.state = 'ORDER_AWAITING_BUSINESS_DECISION';
        session.cart = [];

        return {
          replyText: `⏳ *ORDER PLACED & SENT TO RESTAURANT!* 👨‍🍳\n━━━━━━━━━━━━━━━━━━━━\nYour order has been sent to our register and kitchen.\nWe will notify you immediately once the restaurant accepts it! 🛎️`,
          buttons: null,
          orderPayload,
          handled: true,
        };
      }

      return this._buildOrderReviewResponse(business, session);
    }

    // Unhandled within ordering state machine -> fall back to general AI hospitality
    return null;
  }

  /**
   * Helper to handle product selection and determine if variants are present
   */
  _handleProductChosen(session, product) {
    session.selectedProduct = product;

    if (product.variants && product.variants.length > 0) {
      session.variantMapping = product.variants.map((v, idx) => ({
        num: idx + 1,
        name: v.name,
        price: typeof v.price === 'number' && v.price > 0 ? v.price : parseFloat(v.salePrice) || product.price || 0,
      }));

      session.state = 'WAITING_FOR_VARIANT_SELECTION';

      const variantListStr = session.variantMapping
        .map((v) => `${v.num}. ${v.name} (Option ${String.fromCharCode(64 + v.num)}) — ₹${v.price}`)
        .join('\n');

      return {
        replyText: `You selected *${product.name}*.\n\nPlease choose your variant / size:\n\n${variantListStr}\n\n_Reply with number or letter (e.g. 1 or A)_`,
        buttons: session.variantMapping.slice(0, 3).map((v) => ({
          id: `var_${v.num}`,
          title: `${v.name} (₹${v.price})`.slice(0, 20),
        })),
        orderPayload: null,
        handled: true,
      };
    }

    session.selectedVariant = null;
    session.state = 'WAITING_FOR_QUANTITY';

    return {
      replyText: `How many *${product.name}* would you like?\n\n_Enter quantity (e.g. 1, 2, 3...)_`,
      buttons: null,
      orderPayload: null,
      handled: true,
    };
  }

  /**
   * Helper to build dynamic numbered menu mapped to database products
   */
  async _buildNumberedMenu(businessId) {
    const [products, categories] = await Promise.all([
      Product.find({ businessId, isAvailable: { $ne: false } }).sort({ category: 1, name: 1 }).lean(),
      Category.find({ businessId }).select('name').lean(),
    ]);

    const catMap = {};
    categories.forEach((c) => {
      catMap[c._id.toString()] = c.name;
    });

    const mapping = [];
    const grouped = {};
    let currentNum = 1;

    for (const p of products) {
      const catName = (p.category && catMap[p.category.toString()]) || 'Specialties';
      if (!grouped[catName]) grouped[catName] = [];

      const num = currentNum++;
      let priceStr = '';
      let variantSubLine = '';
      if (p.variants && p.variants.length > 0) {
        const validVariantPrices = p.variants
          .map((v) => (typeof v.price === 'number' && v.price > 0 ? v.price : parseFloat(v.salePrice) || 0))
          .filter((pr) => pr > 0);
        const minPrice = validVariantPrices.length > 0 ? Math.min(...validVariantPrices) : p.price || 0;
        priceStr = `From ₹${minPrice > 0 ? minPrice : p.price}`;

        const vDetails = p.variants.map((v) => {
          const vPrice = typeof v.price === 'number' && v.price > 0 ? v.price : parseFloat(v.salePrice) || p.price || 0;
          return `${v.name || 'Regular'}: ₹${vPrice}`;
        }).join(' | ');
        if (vDetails) {
          variantSubLine = `\n   ↳ _Variants: ${vDetails}_`;
        }
      } else {
        priceStr = `₹${p.price || 0}`;
      }

      grouped[catName].push(`${num}. ${p.name} — ${priceStr}${variantSubLine}`);

      mapping.push({
        num,
        id: p._id.toString(),
        name: p.name,
        price: p.price,
        taxPercentage: typeof p.taxPercentage === 'number' ? p.taxPercentage : undefined,
        variants: p.variants || [],
        foodType: p.foodType || (p.isVeg === false ? 'non_veg' : 'veg'),
      });
    }

    let menuText = '🍽️ *OUR MENU*\n━━━━━━━━━━━━━━━━━━━━';
    for (const [cat, items] of Object.entries(grouped)) {
      menuText += `\n\n*${cat.toUpperCase()}*\n${items.join('\n')}`;
    }

    return { menuText, mapping };
  }

  /**
   * Helper to calculate item totals, GST taxes, delivery fee, and net total
   */
  _calculateFinancials(business, cart = [], orderType = 'takeaway') {
    const isGstActive = business?.orderSettings?.tax?.type !== 'no_gst';
    const defaultTaxRate = isGstActive
      ? (typeof business?.orderSettings?.tax?.percentage === 'number' && business.orderSettings.tax.percentage >= 0
          ? business.orderSettings.tax.percentage
          : 5)
      : 0;

    let subtotal = 0;
    let taxAmount = 0;
    const rateSet = new Set();

    for (const item of cart) {
      const qty = Number(item.quantity) || 1;
      const price = Number(item.price) || 0;
      const itemTotal = price * qty;
      subtotal += itemTotal;

      if (isGstActive) {
        const itemRate =
          typeof item.taxPercentage === 'number' && item.taxPercentage >= 0
            ? item.taxPercentage
            : defaultTaxRate;
        if (itemRate > 0) {
          rateSet.add(itemRate);
          taxAmount += itemTotal * (itemRate / 100);
        }
      }
    }

    subtotal = Number(subtotal.toFixed(2));
    taxAmount = Number(taxAmount.toFixed(2));
    const cgst = Number((taxAmount / 2).toFixed(2));
    const sgst = Number((taxAmount / 2).toFixed(2));

    let deliveryFee = 0;
    if (orderType === 'delivery') {
      const dSettings = business?.orderSettings?.deliverySettings;
      if (dSettings) {
        if (dSettings.freeDeliveryEnabled && dSettings.freeDeliveryMinOrder > 0 && subtotal >= dSettings.freeDeliveryMinOrder) {
          deliveryFee = 0;
        } else if (typeof dSettings.baseCharge === 'number' && dSettings.baseCharge > 0) {
          deliveryFee = dSettings.baseCharge;
        } else {
          deliveryFee = 40;
        }
      } else {
        deliveryFee = 40;
      }
    }

    const totalAmount = Number((subtotal + taxAmount + deliveryFee).toFixed(2));
    const cartTotalWithTax = Number((subtotal + taxAmount).toFixed(2));

    let gstRateLabel = '';
    if (rateSet.size === 1) {
      gstRateLabel = `${Array.from(rateSet)[0]}%`;
    } else if (rateSet.size > 1) {
      gstRateLabel = 'GST';
    } else if (defaultTaxRate > 0) {
      gstRateLabel = `${defaultTaxRate}%`;
    } else {
      gstRateLabel = 'GST';
    }

    return {
      subtotal,
      taxAmount,
      cgst,
      sgst,
      deliveryFee,
      totalAmount,
      cartTotalWithTax,
      isGstActive,
      gstRateLabel,
    };
  }

  /**
   * Helper to build complete Order Review before customer submission
   */
  _buildOrderReviewResponse(business, session) {
    const rName =
      (business.profile?.companyName && business.profile.companyName.trim()) ||
      (business.companyName && business.companyName.trim()) ||
      (business.restaurantName && business.restaurantName.trim()) ||
      (business.name && business.name.trim()) ||
      (business.profile?.name && business.profile.name.trim()) ||
      'Our Restaurant';

    const financials = this._calculateFinancials(business, session.cart, session.orderType);

    const itemsListStr = session.cart
      .map((i, idx) => `${idx + 1}. *${i.name}* × ${i.quantity} — ₹${(i.price * i.quantity).toFixed(0)}`)
      .join('\n');

    const typeStr = session.orderType === 'delivery' ? 'Home Delivery' : 'Takeaway / Pickup';

    let summary = `🧾 *ORDER SUMMARY*\n*${rName}*\n━━━━━━━━━━━━━━━━━━━━\n🛵 *Order Type*: *${typeStr}*\n\n📦 *Items*:\n${itemsListStr}\n━━━━━━━━━━━━━━━━━━━━\n💵 *Subtotal*: ₹${financials.subtotal}\n`;

    if (financials.taxAmount > 0) {
      summary += `🧾 *Taxes (GST ${financials.gstRateLabel})*: ₹${financials.taxAmount.toFixed(2)}\n`;
    }
    if (financials.deliveryFee > 0) {
      summary += `🛵 *Delivery Fee*: ₹${financials.deliveryFee}\n`;
    }
    summary += `💰 *Total Amount*: *₹${financials.totalAmount.toFixed(2).replace(/\.00$/, '')}*\n`;

    if (session.orderType === 'delivery' && session.deliveryAddress) {
      summary += `📍 *Delivery Address*:\n${session.deliveryAddress}\n`;
    }
    summary += `━━━━━━━━━━━━━━━━━━━━\nPlease confirm your order:\n\n1. ✅ *Confirm Order*\n2. ✏️ *Edit Cart*\n3. ❌ *Cancel Order*`;

    return {
      replyText: summary,
      buttons: [
        { id: 'btn_confirm_order', title: '✅ Confirm Order' },
        { id: 'btn_edit_cart', title: '✏️ Edit Cart' },
        { id: 'btn_cancel_order', title: '❌ Cancel Order' },
      ],
      orderPayload: null,
      handled: true,
    };
  }

  /**
   * Check if customer message is providing a delivery address or updating order type
   * for an active recent pending order (placed within the last 25 minutes)
   */
  async handleAddressOrTypeUpdate({
    businessId,
    customerPhone,
    messageText,
    chat,
    targetUserId,
  }) {
    if (!messageText || !messageText.trim()) return null;
    const raw = messageText.trim();
    const rawLower = raw.toLowerCase();

    const session = this.getSession(businessId, customerPhone);

    let activeOrder = null;
    if (session.recentOrderId) {
      activeOrder = await Order.findOne({
        _id: session.recentOrderId,
        status: { $in: ['pending', 'preparing'] },
      });
    }

    if (!activeOrder) {
      const twentyFiveMinsAgo = new Date(Date.now() - 25 * 60 * 1000);
      const cleanPhone = (customerPhone || '').replace(/\D/g, '');
      const last10 = cleanPhone.slice(-10);

      activeOrder = await Order.findOne({
        businessId: businessId?._id || businessId,
        customerPhone: { $in: [cleanPhone, last10, `+91${last10}`, `91${last10}`] },
        status: 'pending',
        createdAt: { $gte: twentyFiveMinsAgo },
      }).sort({ createdAt: -1 });
    }

    if (!activeOrder) return null;

    // 1. Detect Takeaway intent
    const isTakeawayRequest =
      /\b(takeaway|take\s*away|parcel|pack\s*kar\s*do|parcel\s*kar\s*do|pickup|pick\s*up|le\s*jaana\s*hai)\b/i.test(
        rawLower
      );

    if (isTakeawayRequest) {
      activeOrder.orderType = 'takeaway';
      activeOrder.deliveryAddress = '';
      await activeOrder.save();

      this.updateSession(businessId, customerPhone, {
        recentOrderId: activeOrder._id.toString(),
        recentOrderNumber: activeOrder.orderNumber,
        orderType: 'takeaway',
        deliveryAddress: '',
        lastIntent: 'takeaway_confirmed',
      });

      this._emitOrderUpdateToPOS(businessId, activeOrder, chat, targetUserId);

      return {
        isHandled: true,
        replyText: `🛍️ *ORDER UPDATED TO TAKEAWAY — #${activeOrder.orderNumber}* 🛍️\n━━━━━━━━━━━━━━━━━━━━\n📦 *Order Type*: *Takeaway / Pickup*\n💰 *Total Amount*: *₹${activeOrder.totalAmount}*\n⏳ *Status*: 🕒 *Awaiting Restaurant Confirmation*\n━━━━━━━━━━━━━━━━━━━━\n🙏 _Your order will be packed fresh and ready for pickup at our counter!_ 🚀`,
      };
    }

    // 2. Detect Delivery Address or Delivery Intent
    const isExplicitDelivery = /\b(delivery|deliver|ghar\s*pe|ghar\s*par|home\s*delivery)\b/i.test(rawLower);
    const hasAddressPatterns =
      /(?:flat|room|house|h\.no|block|plot|sector|colony|apartment|society|nagar|road|street|gali|lane|floor|building|tower|near|behind|opp|opposite|pincode|\d{6})/i.test(
        rawLower
      );
    const isLikelyAddressText =
      hasAddressPatterns ||
      (session.lastIntent === 'awaiting_address' && raw.length >= 8 && !rawLower.includes('menu'));

    if (isExplicitDelivery || isLikelyAddressText) {
      let cleanAddress = raw
        .replace(
          /^(?:please\s+)?(?:deliver\s+(?:to|at)|delivery\s+(?:to|at)|(?:my\s+)?address\s*(?:is|:)?|home\s+delivery\s+(?:to|at)?|send\s+(?:to|at)|ship\s+(?:to|at))\s*/i,
          ''
        )
        .trim();

      if (cleanAddress.length < 5 && isExplicitDelivery) {
        activeOrder.orderType = 'delivery';
        await activeOrder.save();

        this.updateSession(businessId, customerPhone, {
          recentOrderId: activeOrder._id.toString(),
          recentOrderNumber: activeOrder.orderNumber,
          orderType: 'delivery',
          lastIntent: 'awaiting_address',
        });

        this._emitOrderUpdateToPOS(businessId, activeOrder, chat, targetUserId);

        return {
          isHandled: true,
          replyText: `🛵 *HOME DELIVERY REQUESTED — #${activeOrder.orderNumber}* 🛵\n━━━━━━━━━━━━━━━━━━━━\n💰 *Total Amount*: *₹${activeOrder.totalAmount}*\n\n📍 *Please share your complete delivery address:*\n_(House/Flat No, Landmark, Area/Sector, Road)_\n━━━━━━━━━━━━━━━━━━━━\n🛵 _Once you send your address, we will dispatch our delivery partner immediately!_`,
        };
      }

      if (cleanAddress.length >= 5) {
        activeOrder.orderType = 'delivery';
        activeOrder.deliveryAddress = cleanAddress;
        await activeOrder.save();

        this.updateSession(businessId, customerPhone, {
          recentOrderId: activeOrder._id.toString(),
          recentOrderNumber: activeOrder.orderNumber,
          orderType: 'delivery',
          deliveryAddress: cleanAddress,
          lastIntent: 'address_confirmed',
        });

        this._emitOrderUpdateToPOS(businessId, activeOrder, chat, targetUserId);

        return {
          isHandled: true,
          replyText: `🛵 *DELIVERY ADDRESS RECORDED — #${activeOrder.orderNumber}* 🛵\n━━━━━━━━━━━━━━━━━━━━\n📍 *Deliver To*: *${cleanAddress}*\n💰 *Total Amount*: *₹${activeOrder.totalAmount}*\n🛵 *Type*: *Home Delivery*\n⏳ *Status*: 🕒 *Awaiting Restaurant Confirmation*\n━━━━━━━━━━━━━━━━━━━━\n🙏 _The kitchen and delivery desk have received your address! We will notify you once your order is accepted and out for delivery._ 🚀`,
        };
      }
    }

    return null;
  }

  /**
   * Helper to broadcast updated order to POS terminals in real time
   */
  _emitOrderUpdateToPOS(businessId, order, chat, targetUserId) {
    try {
      const bId = (businessId?._id || businessId).toString();
      const socketService = require('./socketService');
      socketService.emitWhatsAppOrderRequest(bId, {
        order: order.toJSON ? order.toJSON() : order,
        chat,
        customerPhone: order.customerPhone,
        customerName: order.customerName,
        targetUserId,
      });
    } catch (err) {
      console.warn('[WhatsAppOrderSessionService] Error emitting order update to socket:', err.message);
    }

    try {
      const pushNotificationService = require('./pushNotificationService');
      const bId = (businessId?._id || businessId).toString();
      pushNotificationService
        .sendPushNotificationToBusiness({
          businessId: bId,
          title: `🛵 Order Updated: #${order.orderNumber}`,
          message: `${order.orderType === 'delivery' ? 'Delivery Address Added' : 'Updated to Takeaway'}: ${
            order.deliveryAddress || 'Counter Pickup'
          }`,
          data: {
            type: 'whatsapp_order_request',
            orderId: order._id.toString(),
            orderNumber: order.orderNumber,
            customerPhone: order.customerPhone || '',
            customerName: order.customerName || '',
            totalAmount: String(order.totalAmount || 0),
            orderType: order.orderType,
            deliveryAddress: order.deliveryAddress || '',
            items: JSON.stringify(order.items || []),
            createdAt: (order.createdAt || new Date()).toISOString(),
          },
        })
        .catch((e) => console.warn('[WhatsAppOrderSessionService] Push dispatch notice:', e.message));
    } catch (_) {}
  }

  /**
   * Periodically remove sessions inactive for > 30 minutes to conserve memory
   */
  _cleanupStaleSessions() {
    const cutoff = Date.now() - 30 * 60 * 1000;
    for (const [key, session] of this._sessions.entries()) {
      if (session.lastActiveAt && session.lastActiveAt.getTime() < cutoff) {
        this._sessions.delete(key);
      }
    }
  }
}

const instance = new WhatsAppOrderSessionService();
instance.STATES = STATES;
WhatsAppOrderSessionService.STATES = STATES;
module.exports = instance;
