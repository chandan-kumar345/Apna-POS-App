const crypto = require('crypto');
const Session = require('../../models/ChotuAgentSession');
const Turn = require('../../models/ChotuAgentTurn');
const Lock = require('../../models/ChotuAgentLock');
const chotuService = require('./chotuService');
const AICommandEngine = require('./aiCommandEngine');
const { normalizeSpokenText } = require('./speechProvider');
const python = require('./pythonAgentBridge');
const tools = require('./automationTools');
const ApiError = require('../../utils/ApiError');

const plain = (value) => JSON.parse(JSON.stringify(value));
const CONFIRMATION_TTL_MS = 2 * 60 * 1000;
let indexesReady;

async function ensureIndexes() {
  if (!indexesReady) indexesReady = Promise.all([Session.createIndexes(), Turn.createIndexes(), Lock.createIndexes()]);
  try {
    await indexesReady;
  } catch (error) {
    indexesReady = null;
    throw error;
  }
}

function validateInput(input) {
  if (!input || typeof input.text !== 'string' || !input.text.trim() || input.text.length > 2000) {
    throw ApiError.badRequest('A non-empty text command of at most 2000 characters is required.');
  }
  for (const key of ['sessionId', 'requestId']) {
    if (typeof input[key] !== 'string' || !/^[A-Za-z0-9_.:-]{1,128}$/.test(input[key])) {
      throw ApiError.badRequest(`${key} must contain 1-128 letters, numbers, dots, underscores, colons or hyphens.`);
    }
  }
  if (input.currentTableContext != null && (typeof input.currentTableContext !== 'string' || input.currentTableContext.length > 128)) {
    throw ApiError.badRequest('currentTableContext must be a table name of at most 128 characters.');
  }
  if (input.expectedDrafts != null && (!Array.isArray(input.expectedDrafts) || input.expectedDrafts.length > 100)) {
    throw ApiError.badRequest('expectedDrafts must contain at most 100 table drafts.');
  }
  for (const draft of input.expectedDrafts || []) {
    if (!draft || typeof draft.tableNumber !== 'string' || draft.tableNumber.length > 128 || !Array.isArray(draft.items) || draft.items.length > 200
      || draft.items.some((item) => !item || typeof item.productId !== 'string' || item.productId.length > 128 || !Number.isInteger(item.quantity) || item.quantity < 1 || item.quantity > 99)) {
      throw ApiError.badRequest('Invalid expected draft snapshot.');
    }
  }
  return {
    sessionId: input.sessionId, requestId: input.requestId,
    text: input.text.trim(), currentTableContext: (input.currentTableContext || '').trim(),
    ...(input.expectedDrafts ? { expectedDrafts: input.expectedDrafts } : {}),
  };
}

function replay(existing, payloadHash) {
  if (existing.payloadHash !== payloadHash) throw ApiError.conflict('requestId was already used with another payload.', 'CHOTU_REQUEST_MISMATCH');
  if (existing.status === 'processing' || !existing.response) {
    throw ApiError.conflict('This turn is processing or was interrupted. Inspect its session receipt before retrying.', 'CHOTU_TURN_UNCERTAIN');
  }
  return { ...existing.response, isDuplicate: true };
}

async function replayWithCurrentSnapshot(actor, existing, payloadHash) {
  const response = replay(existing, payloadHash);
  const session = await Session.findOne({ businessId: actor.businessId, userId: actor.userId, sessionId: existing.sessionId });
  // The receipt remains immutable. Refresh displayed state separately so an old
  // receipt cannot roll back a cart that another device has since changed.
  response.currentSnapshot = null;
  if (session?.tableNumber && response.status !== 'needs_review') {
    try {
      const table = await tools.resolveTable(actor.businessId, session.tableNumber);
      const context = await tools.loadContext(actor.businessId, table, session);
      response.currentSnapshot = plain({ stage: session.stage, ...await tools.snapshot(context) });
    } catch (_) { /* Read-only refresh is optional; never execute a replayed tool. */ }
  }
  return response;
}

async function acquire(actor, input, resource, token) {
  try {
    await Lock.create({ businessId: actor.businessId, resource, token, sessionId: input.sessionId, requestId: input.requestId });
  } catch (error) {
    if (error.code === 11000) throw ApiError.conflict('Chotu is processing this session/table, or an interrupted action needs review.', 'CHOTU_RESOURCE_BUSY');
    throw error;
  }
}

async function parse(actor, input, session, apiKey) {
  const normalized = normalizeSpokenText(input.text);
  const lower = normalized.toLowerCase();
  const table = AICommandEngine.extractTableNumber(normalized, session.tableNumber || input.currentTableContext || null);
  const explicitTable = AICommandEngine.extractTableNumber(normalized);
  const pending = session.pending && Date.now() - session.pending.createdAt < CONFIRMATION_TTL_MS ? session.pending : null;
  const sameTable = !explicitTable || String(explicitTable) === String(session.tableNumber).replace(/^(?:table\s*|t-?)/i, '');
  // The general number normalizer converts English "no" to 9 (Hindi nau).
  // Read negation and conditionals from the original utterance as well.
  const language = `${input.text.toLowerCase()} ${lower}`;
  const negative = /\b(?:no|not|never|nahi|nahin|mat|dont|don't|pending|unpaid|without)\b/i.test(language);
  const hypothetical = /[?]|\b(?:if|when|after|before|once|unless|whether|maybe|perhaps|will|did|has|have|was|is|can|could|should)\b/i.test(language);
  const cashReceived = !negative && !hypothetical && /\b(?:cash\s+(?:received|collected)|received\s+cash|cash\s+(?:mil|aa)\s+gay[ae]|cash\s+le\s+liya)\b/i.test(lower);
  const complete = /\b(?:settle|checkout|complete\s+(?:the\s+)?order|order\s+(?:complete|finish)|finish\s+(?:the\s+)?order)\b/i.test(lower);
  const base = { table_number: table, confidence: 1 };
  if (/\b(?:take\s*away|takeaway|parcel|delivery)\b/i.test(lower)) {
    return { ...base, intent: 'SET_ORDER_TYPE', order_type: /\bdelivery\b/.test(lower) ? 'delivery' : 'takeaway' };
  }
  if (pending && /^(?:cancel|no|nahi|nahin|cancel confirmation)[.!\s]*$/i.test(lower)) {
    return { ...base, intent: 'CHAT', chotu_response: 'Pending instruction cancel kar di. Order change nahi hua.' };
  }
  if (complete && /\b(?:add|laga|hata|remove|quantity|update)\b/i.test(lower)) {
    return { ...base, intent: 'UNKNOWN', ambiguity: true, question: 'Pehle item changes alag instruction mein confirm kijiye, phir order complete boliye.' };
  }
  if (complete || cashReceived || (pending?.kind === 'cash' && sameTable && /^(?:yes|haan|han|confirm)[.!\s]*$/i.test(lower))) {
    return {
      ...base, intent: 'COMPLETE_ORDER',
      payment_method: /\b(?:upi|card|online)\b/.test(lower) ? 'digital' : 'cash',
      payment_confirmed: cashReceived,
    };
  }
  if (negative || hypothetical) {
    return { ...base, intent: 'CHAT', chotu_response: 'Instruction execute nahi ki. Clear affirmative instruction dobara boliye.' };
  }
  if (/\bconfirm\s+clear\s+cart\b/i.test(lower) || (pending?.kind === 'clear' && sameTable && /^(?:yes|haan|han)[.!\s]*$/i.test(lower))) {
    return { ...base, intent: 'CLEAR_CART', confirmed: pending?.kind === 'clear' && sameTable };
  }
  if (/\b(?:kot|kitchen)\b/.test(lower) && /\b(?:bill|invoice|add|laga)\b/.test(lower)) {
    return { ...base, intent: 'UNKNOWN', ambiguity: true, question: 'Pehle items batayiye, phir KOT ya bill alag instruction mein boliye.' };
  }
  if (/(?:^|\s)-\d|\b(?:minus|negative)\s+\d|\b\d+\.\d+\b/.test(lower)) {
    return { ...base, intent: 'UNKNOWN', ambiguity: true, question: 'Quantity 1 se 99 tak whole number mein batayiye.' };
  }
  if (pending?.kind === 'table' && explicitTable && /^(?:(?:table|t|tbl)\s*[-#]?\s*)?\d+[.!\s]*$/i.test(lower)) {
    return { ...pending.command, table_number: explicitTable, table_context_missing: false };
  }
  const parsed = await chotuService.parseVoiceCommand(actor.businessId, {
    text: input.text,
    sessionId: `agent:${actor.businessId}:${actor.userId}:${input.sessionId}`,
    currentTableContext: session.tableNumber || input.currentTableContext || null,
    userId: actor.userId, apiKey,
  });
  // LLM/provider output is never allowed to confirm a destructive or payment action.
  return { ...parsed.command, confirmed: false, payment_confirmed: false, payment_method: 'cash' };
}

async function runTurn(actor, rawInput, apiKey = null) {
  if ((rawInput?.expectedBusinessId && rawInput.expectedBusinessId !== String(actor.businessId))
    || (rawInput?.expectedUserId && rawInput.expectedUserId !== String(actor.userId))) {
    throw ApiError.conflict('The active account changed while this turn was pending. Return to its original POS account.', 'CHOTU_ACTOR_CHANGED');
  }
  const input = validateInput(rawInput);
  await ensureIndexes();
  const scope = { businessId: actor.businessId, userId: actor.userId, sessionId: input.sessionId };
  const turnKey = { ...scope, requestId: input.requestId };
  const payloadHash = tools.hash({ text: input.text, currentTableContext: input.currentTableContext, expectedDrafts: input.expectedDrafts });
  const previous = await Turn.findOne(turnKey).lean();
  if (previous) return replayWithCurrentSnapshot(actor, previous, payloadHash);
  if (!python.enabled()) throw new ApiError(503, 'Chotu automation agent is disabled.', 'CHOTU_AGENT_DISABLED');
  const token = crypto.randomUUID();
  const sessionResource = `session:${actor.userId}:${input.sessionId}`;
  await acquire(actor, input, sessionResource, token);
  let tableResource = null;
  let turn = null;
  let session = null;
  let context = null;
  let command = null;
  let mutationStarted = false;
  let receiptStored = false;
  let needsReview = false;
  let failedAction = null;
  try {
    // Check again under the writer lock in case the preceding turn just finished.
    const raced = await Turn.findOne(turnKey).lean();
    if (raced) return replayWithCurrentSnapshot(actor, raced, payloadHash);
    if (await Turn.exists({ ...scope, status: 'processing' })) {
      throw ApiError.conflict('A previous interrupted turn must be reconciled first.', 'CHOTU_TURN_UNCERTAIN');
    }
    session = await Session.findOneAndUpdate(scope, { $setOnInsert: scope }, { upsert: true, new: true, setDefaultsOnInsert: true });
    turn = await Turn.create({ ...turnKey, payloadHash, text: input.text });
    command = await parse(actor, input, session, apiKey);
    turn.intent = command.intent;
    const table = await tools.resolveTable(actor.businessId, command.table_number);
    if (table) {
      tableResource = `table:${table._id}`;
      await acquire(actor, input, tableResource, token);
      if (session.tableNumber !== table.name) {
        session.orderId = null;
        session.kitchenFingerprint = '';
        session.billFingerprint = '';
        session.stage = 'draft';
        session.pending = null;
      }
      session.tableNumber = table.name;
      command.table_number = table.name;
    }
    context = await tools.loadContext(actor.businessId, table, session);
    tools.checkExpectedDraft(context, input.expectedDrafts);
    if (context.order?.status === 'completed' && !context.items.length) session.stage = 'completed';
    else if (context.billCurrent) session.stage = 'billed';
    else if (context.kitchenCurrent) session.stage = 'kitchen';
    else session.stage = 'draft';
    const plan = await python.plan(command, tools.policyContext(context));
    tools.preflight(context, plan.actions, command, actor);
    session.pending = plan.pending ? {
      kind: plan.pending, command: plain(command), createdAt: Date.now(), tableNumber: table?.name || '',
    } : null;
    for (const action of plan.actions) {
      failedAction = action;
      if (action !== 'view_order') mutationStarted = true;
      await tools.execute(context, action, command, actor, tools.hash(turnKey));
      turn.steps.push(action);
      // Persist each successful step; an interrupted processing receipt is never auto-replayed.
      await turn.save();
    }
    if (context.order) session.orderId = context.order._id;
    await session.save();
    const response = plain({
      status: plan.status, intent: command.intent, stage: session.stage,
      sessionId: input.sessionId, requestId: input.requestId,
      chotuMessage: plan.message, steps: turn.steps, ...await tools.snapshot(context),
    });
    turn.status = 'completed';
    turn.response = response;
    await turn.save();
    receiptStored = true;
    return response;
  } catch (error) {
    if (!turn) throw error;
    needsReview = mutationStarted;
    const response = {
      status: needsReview ? 'needs_review' : 'rejected',
      intent: command?.intent || '', stage: needsReview ? 'needs_review' : session?.stage || 'draft',
      sessionId: input.sessionId, requestId: input.requestId,
      steps: [...turn.steps], failedAction: needsReview ? failedAction : null,
      code: needsReview ? 'CHOTU_REVIEW_REQUIRED' : error.code || 'CHOTU_TURN_FAILED',
      chotuMessage: needsReview
        ? 'Action poori tarah confirm nahi ho paya. Session receipt aur POS records review kijiye; repeat execution roki gayi hai.'
        : error.isOperational ? error.message : 'Chotu action execute nahi hua. Backend connection/configuration check kijiye.',
    };
    if (session) {
      if (needsReview) session.stage = 'needs_review';
      session.pending = null;
      await session.save();
    }
    turn.status = needsReview ? 'needs_review' : 'completed';
    turn.response = response;
    await turn.save();
    receiptStored = true;
    return response;
  } finally {
    // Unknown mutations retain the table lock. A lost receipt retains both locks.
    if (!turn || receiptStored) {
      await Lock.deleteOne({ businessId: actor.businessId, resource: sessionResource, token });
      if (tableResource && !needsReview) await Lock.deleteOne({ businessId: actor.businessId, resource: tableResource, token });
    }
  }
}

async function getSession(actor, sessionId) {
  if (!/^[A-Za-z0-9_.:-]{1,128}$/.test(sessionId)) throw ApiError.badRequest('Invalid sessionId.');
  const scope = { businessId: actor.businessId, userId: actor.userId, sessionId };
  const [session, latestTurn, reviewTurns] = await Promise.all([
    Session.findOne(scope).lean(),
    Turn.findOne(scope).sort({ createdAt: -1 }).lean(),
    Turn.find({ ...scope, status: 'needs_review' }).sort({ createdAt: -1 }).limit(10).lean(),
  ]);
  if (!session) throw ApiError.notFound('Chotu session not found.');
  return { session, latestTurn, reviewTurns };
}

module.exports = { runTurn, getSession };
