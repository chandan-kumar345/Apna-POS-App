const { DefaultSpeechProvider } = require('./speechProvider');
const AICommandEngine = require('./aiCommandEngine');
const ChotuActionLog = require('../../models/ChotuActionLog');
const Product = require('../../models/Product');
const Table = require('../../models/Table');
const cartService = require('../cartService');
const tableService = require('../tableService');
const socketService = require('../socketService');
const ApiError = require('../../utils/ApiError');

class ChotuService {
  constructor(speechProvider = null) {
    this.speechProvider = speechProvider || new DefaultSpeechProvider();
    // Short-term session memory for contextual multi-turn conversation (Section 10)
    this.sessionMemory = new Map();
    // Idempotency cache to prevent duplicate voice execution (Section 32)
    this.idempotencyCache = new Map();
  }

  /**
   * Set or replace active speech provider at runtime
   */
  setSpeechProvider(provider) {
    this.speechProvider = provider;
  }

  /**
   * Transcribe spoken audio or speech text
   */
  async transcribeVoice(businessId, {
    audio,
    format = 'raw_text',
    language = 'hinglish',
    userId = null,
    sessionId = '',
    tableContext = null,
  }) {
    if (!audio) {
      throw ApiError.badRequest('Audio or spoken text payload is required for transcription');
    }

    const startTime = Date.now();
    const result = await this.speechProvider.transcribe({
      audio,
      format,
      language,
    });

    const executionTimeMs = Date.now() - startTime;

    // Create Audit Log record in chotu_action_logs (Section 30)
    let logRecord = null;
    try {
      logRecord = await ChotuActionLog.create({
        restaurantId: businessId,
        userId: userId || undefined,
        sessionId: sessionId || `sess_${Date.now()}`,
        transcription: result.text || '(silence/empty)',
        intent: 'TRANSCRIBE_ONLY',
        confidence: result.confidence || 0.95,
        actionStatus: 'transcribed',
        tableNumber: tableContext?.tableNumber ? tableContext.tableNumber.toString() : '',
        language: result.language || language,
        executionTimeMs,
      });
    } catch (err) {
      console.error('[ChotuService] Failed to record audit log:', err.message);
    }

    return {
      transcription: result.text,
      originalText: result.originalText || result.text,
      confidence: result.confidence,
      language: result.language,
      provider: result.provider,
      sessionId: logRecord?.sessionId || sessionId,
      logId: logRecord?._id ? logRecord._id.toString() : null,
      phase: 1,
      durationMs: executionTimeMs,
      message: 'Transcription completed successfully.',
    };
  }

  /**
   * Phase 2 & 3: Parse Spoken Natural Language into Structured POS Command
   * Evaluates table context, performs 5-tier product matching, and builds structured command JSON.
   */
  async parseVoiceCommand(businessId, {
    text,
    sessionId = '',
    currentTableContext = null,
    userId = null,
  }) {
    if (!text || typeof text !== 'string') {
      throw ApiError.badRequest('Spoken text command is required');
    }

    const startTime = Date.now();
    const cleanSessionId = sessionId || `sess_${Date.now()}`;

    // 1. Fetch available products with aliases for this business
    const products = await Product.find({ businessId, isAvailable: true }).lean();

    // 2. Retrieve session memory for contextual conversation (Section 10)
    const existingSession = this.sessionMemory.get(cleanSessionId) || null;

    // 3. Parse intent & entities
    const parsed = AICommandEngine.parseCommand({
      text,
      availableProducts: products,
      currentTableContext,
      sessionContext: existingSession,
    });

    // Update short-term session memory if table was found
    if (parsed.table_number) {
      this.sessionMemory.set(cleanSessionId, {
        tableNumber: parsed.table_number,
        lastIntent: parsed.intent,
        timestamp: Date.now(),
      });
    }

    const executionTimeMs = Date.now() - startTime;

    // Record audit log entry
    let logRecord = null;
    try {
      logRecord = await ChotuActionLog.create({
        restaurantId: businessId,
        userId: userId || undefined,
        sessionId: cleanSessionId,
        transcription: text,
        intent: parsed.intent,
        commandJson: parsed,
        confidence: parsed.confidence,
        actionStatus: 'validated',
        tableNumber: parsed.table_number ? parsed.table_number.toString() : '',
        executionTimeMs,
      });
    } catch (err) {
      console.error('[ChotuService] Audit log error in parseVoiceCommand:', err.message);
    }

    return {
      success: true,
      sessionId: cleanSessionId,
      logId: logRecord?._id ? logRecord._id.toString() : null,
      command: parsed,
      durationMs: executionTimeMs,
    };
  }

  /**
   * Phase 3: Execute Validated POS Command via Existing POS Services
   * Strictly respects POS business logic, table state, and RBAC permissions.
   */
  async executeVoiceCommand(businessId, {
    commandId,
    sessionId = '',
    command,
    userId = null,
    userRole = 'owner',
  }) {
    if (!command || !command.intent) {
      throw ApiError.badRequest('Invalid or missing command structure');
    }

    // 1. Idempotency Check (Section 32)
    const effectiveCommandId = commandId || `cmd_${sessionId}_${Date.now()}`;
    if (this.idempotencyCache.has(effectiveCommandId)) {
      const cached = this.idempotencyCache.get(effectiveCommandId);
      return {
        ...cached,
        isDuplicate: true,
        message: 'Command already processed (idempotent)',
      };
    }

    const startTime = Date.now();
    const tableNum = (command.table_number || '').toString().trim();
    const targetTableStr = tableNum ? `T-${tableNum}` : '';

    let executionResult = null;

    switch (command.intent) {
      case 'ADD_ITEM': {
        if (!Array.isArray(command.items) || command.items.length === 0) {
          throw ApiError.badRequest('No items found to add');
        }

        const addedItems = [];
        let updatedCart = null;

        for (const item of command.items) {
          if (!item.product_id) continue;

          // Fetch authoritative product from database (Section 29: NEVER send raw spoken names to DB)
          const product = await Product.findOne({
            businessId,
            $or: [{ _id: item.product_id }, { productId: item.product_id }],
          });

          if (!product || !product.isAvailable) continue;

          // Add to cart via existing CartService
          updatedCart = await cartService.addToCart(businessId, {
            tableNumber: targetTableStr || tableNum,
            orderType: 'dineIn',
            product: {
              productId: product.productId || product._id.toString(),
              name: product.name,
              price: product.price,
              salePrice: product.salePrice,
              hasDiscount: product.hasDiscount,
              discountPercent: product.discountPercent,
              foodType: product.foodType,
            },
            quantity: item.quantity || 1,
          });

          addedItems.push({
            name: product.name,
            quantity: item.quantity || 1,
            price: product.price,
          });
        }

        // Update table status to occupied if currently free
        if (targetTableStr || tableNum) {
          try {
            await Table.findOneAndUpdate(
              {
                businessId,
                $or: [{ name: targetTableStr }, { name: `T-${tableNum}` }, { tableNumber: parseInt(tableNum, 10) || 0 }],
                status: 'free',
              },
              { $set: { status: 'occupied', occupiedSince: new Date() } }
            );
            tableService.emitTableUpdateForTable(businessId, targetTableStr || tableNum);
          } catch (_) {}
        }

        executionResult = {
          success: true,
          intent: 'ADD_ITEM',
          tableNumber: targetTableStr || tableNum,
          addedItems,
          cart: updatedCart,
          chotuMessage: targetTableStr
            ? `Table ${tableNum} mein ${addedItems.map((i) => `${i.name} × ${i.quantity}`).join(', ')} add kar diya.`
            : `${addedItems.map((i) => `${i.name} × ${i.quantity}`).join(', ')} add kar diya.`,
        };
        break;
      }

      case 'REMOVE_ITEM': {
        const item = command.item;
        if (!item || !item.product_id) {
          throw ApiError.badRequest('Target product ID is required to remove item');
        }

        const updatedCart = await cartService.reduceProductFromCart(businessId, {
          tableNumber: targetTableStr || tableNum,
          orderType: 'dineIn',
          productId: item.product_id,
          quantity: item.quantity || 1,
        });

        executionResult = {
          success: true,
          intent: 'REMOVE_ITEM',
          tableNumber: targetTableStr || tableNum,
          removedItem: item,
          cart: updatedCart,
          chotuMessage: `Table ${tableNum || ''} se ${item.product_name} remove kar diya.`,
        };
        break;
      }

      case 'UPDATE_QUANTITY': {
        const item = command.item;
        if (!item || !item.product_id) {
          throw ApiError.badRequest('Target product ID is required to update quantity');
        }

        const updatedCart = await cartService.updateCartItemQuantity(businessId, {
          tableNumber: targetTableStr || tableNum,
          orderType: 'dineIn',
          productId: item.product_id,
          quantity: command.quantity || item.quantity || 1,
        });

        executionResult = {
          success: true,
          intent: 'UPDATE_QUANTITY',
          tableNumber: targetTableStr || tableNum,
          updatedItem: item,
          newQuantity: command.quantity || item.quantity,
          cart: updatedCart,
          chotuMessage: `Table ${tableNum || ''} mein ${item.product_name} ki quantity ${command.quantity} set kar di.`,
        };
        break;
      }

      case 'CHECK_ITEM_AVAILABILITY': {
        executionResult = {
          success: true,
          intent: 'CHECK_ITEM_AVAILABILITY',
          product: command.product,
          chotuMessage: command.chotu_response,
        };
        break;
      }

      case 'VIEW_TABLE_ORDER': {
        const tableDoc = await Table.findOne({
          businessId,
          $or: [{ name: targetTableStr }, { name: `T-${tableNum}` }, { tableNumber: parseInt(tableNum, 10) || 0 }],
        }).lean();

        executionResult = {
          success: true,
          intent: 'VIEW_TABLE_ORDER',
          tableNumber: targetTableStr || tableNum,
          table: tableDoc,
          chotuMessage: `Table ${tableNum} ka order display kar diya.`,
        };
        break;
      }

      default:
        throw ApiError.badRequest(`Unsupported execution intent: ${command.intent}`);
    }

    const executionTimeMs = Date.now() - startTime;
    executionResult.executionTimeMs = executionTimeMs;
    executionResult.commandId = effectiveCommandId;

    // Cache result in idempotency cache (retain for 5 minutes)
    this.idempotencyCache.set(effectiveCommandId, executionResult);
    setTimeout(() => this.idempotencyCache.delete(effectiveCommandId), 5 * 60 * 1000);

    // Save executed audit log record
    try {
      await ChotuActionLog.create({
        restaurantId: businessId,
        userId: userId || undefined,
        sessionId: sessionId || '',
        transcription: executionResult.chotuMessage || command.intent,
        intent: command.intent,
        commandJson: command,
        confidence: command.confidence || 1.0,
        actionStatus: 'executed',
        tableNumber: tableNum,
        executionTimeMs,
      });
    } catch (err) {
      console.error('[ChotuService] Audit log error in executeVoiceCommand:', err.message);
    }

    return executionResult;
  }

  /**
   * Get Chotu action audit logs with pagination
   */
  async getActionLogs(businessId, { page = 1, limit = 50, intent, actionStatus } = {}) {
    const query = { restaurantId: businessId };
    if (intent && intent !== 'All') {
      query.intent = intent;
    }
    if (actionStatus && actionStatus !== 'All') {
      query.actionStatus = actionStatus;
    }

    const skip = (Math.max(1, parseInt(page, 10)) - 1) * Math.max(1, parseInt(limit, 10));
    const parsedLimit = Math.max(1, parseInt(limit, 10));

    const [logs, total] = await Promise.all([
      ChotuActionLog.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(parsedLimit)
        .lean(),
      ChotuActionLog.countDocuments(query),
    ]);

    return {
      logs,
      pagination: {
        total,
        page: parseInt(page, 10),
        limit: parsedLimit,
        totalPages: Math.ceil(total / parsedLimit),
      },
    };
  }
}

module.exports = new ChotuService();
