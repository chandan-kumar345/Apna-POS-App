const crypto = require('crypto');
const Product = require('../../models/Product');
const Business = require('../../models/Business');
const Cart = require('../../models/Cart');
const Table = require('../../models/Table');
const Order = require('../../models/Order');
const PrintLog = require('../../models/PrintLog');
const cartService = require('../cartService');
const orderService = require('../orderService');
const tableService = require('../tableService');
const ApiError = require('../../utils/ApiError');

const cents = (value) => Math.round((Number(value) + Number.EPSILON) * 100) / 100;
const hash = (value) => crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
const idOf = (product) => product._id.toString();
const quantityValid = (value) => Number.isInteger(value) && value >= 1 && value <= 99;

function tableNames(table) {
  return [...new Set([table.name, `${table.tableNumber}`, `T-${table.tableNumber}`, `Table ${table.tableNumber}`])];
}

async function resolveTable(businessId, value) {
  const raw = String(value || '').trim();
  if (!raw) return null;
  const numeric = raw.match(/^(?:(?:table\s*|t-?)\s*)?(\d+)$/i);
  const table = await Table.findOne({
    businessId,
    $or: [{ name: raw }, ...(numeric ? [{ tableNumber: Number(numeric[1]) }] : [])],
  });
  if (!table) throw ApiError.badRequest('Table nahi mili. Existing POS table select kijiye.');
  if (table.status === 'reserved') throw ApiError.conflict('Reserved table ko pehle normal POS par open kijiye.');
  return table;
}

function productFor(context, id) {
  const product = context.products.find((p) => idOf(p) === String(id) || p.productId === String(id));
  if (!product) throw ApiError.badRequest('Menu item is restaurant mein nahi mila. Please repeat the full order.');
  return product;
}

function lineFor(product, quantity) {
  if (!quantityValid(quantity)) throw ApiError.badRequest('Quantity must be a whole number from 1 to 99.');
  if (!product.isAvailable) throw ApiError.badRequest(`${product.name} available nahi hai.`);
  if (product.variants?.length) throw ApiError.badRequest(`${product.name} ka variant normal POS par select kijiye.`);
  if (product.trackInventory && product.stock !== -1 && product.stock < quantity) {
    throw ApiError.badRequest(`${product.name} ka sufficient stock nahi hai.`);
  }
  const discountPercent = Number(product.discountPercent) || 0;
  const hasDiscount = product.hasDiscount === true || discountPercent > 0;
  if (hasDiscount && discountPercent >= 100) throw ApiError.badRequest('Complimentary items normal POS par handle kijiye.');
  const salePrice = hasDiscount && product.salePrice > 0
    ? product.salePrice
    : hasDiscount && discountPercent > 0 ? cents(product.price * (1 - discountPercent / 100)) : null;
  return {
    productId: idOf(product), name: product.name, quantity,
    price: product.price, salePrice, hasDiscount, discountPercent,
    effectivePrice: salePrice > 0 ? salePrice : product.price,
    foodType: product.foodType, variantName: '',
  };
}

function gstPercentFor(context, product) {
  const taxSettings = context.business.orderSettings?.tax;
  return taxSettings?.type === 'no_gst' ? 0 : product.taxPercentage ?? taxSettings?.percentage ?? 5;
}

function financials(context, items = context.items) {
  const subtotal = cents(items.reduce((sum, item) => sum + item.effectivePrice * item.quantity, 0));
  const taxAmount = cents(items.reduce((sum, item) => {
    const product = productFor(context, item.productId);
    return sum + item.effectivePrice * item.quantity * gstPercentFor(context, product) / 100;
  }, 0));
  return { subtotal, discountAmount: 0, taxAmount, totalAmount: cents(subtotal + taxAmount) };
}

function fingerprint(context) {
  return hash({
    items: context.items.map((i) => [i.productId, i.quantity, i.effectivePrice]).sort((a, b) => a[0].localeCompare(b[0])),
    ...financials(context),
  });
}

async function loadContext(businessId, table, session) {
  const [business, products, carts, orders] = await Promise.all([
    Business.findById(businessId).lean(),
    Product.find({ businessId }).lean(),
    table ? Cart.find({ businessId, orderType: 'dineIn', tableNumber: { $in: tableNames(table) } }).lean() : [],
    table ? Order.find({ businessId, orderType: 'dineIn', tableNumber: { $in: tableNames(table) }, status: { $in: ['pending', 'preparing', 'ready'] } }) : [],
  ]);
  if (!business) throw ApiError.notFound('Business not found.');
  if (orders.length > 1 || carts.filter((cart) => cart.items.length).length > 1) {
    throw ApiError.conflict('Multiple active drafts/orders found. Reconcile this table in the normal POS first.');
  }
  let order = orders[0] || null;
  if (!order && session.orderId && table && session.tableNumber === table.name) {
    order = await Order.findOne({ _id: session.orderId, businessId, tableNumber: { $in: tableNames(table) } });
  }
  const cart = carts.find((c) => c.items.length) || carts[0];
  const running = order && !['completed', 'cancelled'].includes(order.status);
  // The cart contains the full current draft, including additions not yet sent
  // to the kitchen. Order.updatedAt also changes for kitchen status updates,
  // so its timestamp cannot decide which item list represents the draft.
  const rawItems = cart?.items?.length ? cart.items : running ? order.items : [];
  const context = { businessId, business, products, table, cart, order, items: [], session };
  context.items = rawItems.map((item) => {
    if (item.variantName || item.note) throw ApiError.badRequest('Special instructions/variants ke liye normal POS use kijiye.');
    return lineFor(productFor(context, item.productId), item.quantity);
  });
  context.fingerprint = fingerprint(context);
  const snapshots = order && !['completed', 'cancelled'].includes(order.status)
    ? await PrintLog.find({ businessId, orderId: order._id, printType: { $in: ['kot', 'bill'] } }).sort({ createdAt: -1 }).lean()
    : [];
  context.hasKitchenOrder = !!running && (order.kotStatus === 'sent' || order.kotStatus === 'printed' || order.status === 'preparing' || snapshots.some((s) => s.printType === 'kot'));
  // Billing can replace order.items before the new additions reach the kitchen.
  // Only the immutable latest KOT snapshot records what was actually sent.
  context.kitchenItems = context.hasKitchenOrder ? snapshots.find((s) => s.printType === 'kot')?.items || order.items : [];
  const lines = (items, price) => items.map((i) => [String(i.productId), i.quantity, price(i)]).sort((a, b) => a[0].localeCompare(b[0]));
  const orderMatches = order && JSON.stringify(lines(order.items, (i) => i.price)) === JSON.stringify(lines(context.items, (i) => i.effectivePrice))
    && order.totalAmount === financials(context).totalAmount && order.taxAmount === financials(context).taxAmount;
  context.kitchenCurrent = orderMatches && snapshots.find((s) => s.printType === 'kot')?.notes === `chotu:${context.fingerprint}`;
  context.billCurrent = orderMatches && snapshots.find((s) => s.printType === 'bill')?.notes === `chotu:${context.fingerprint}`;
  return context;
}

function policyContext(context) {
  return {
    cartCount: context.items.length,
    hasKitchenOrder: context.hasKitchenOrder,
    hasRunningOrder: !!context.order && !['completed', 'cancelled'].includes(context.order.status),
    kitchenCurrent: context.kitchenCurrent,
    billCurrent: context.billCurrent,
    orderCompleted: context.order?.status === 'completed' && context.order?.isPaid,
  };
}

function checkExpectedDraft(context, expectedDrafts = []) {
  if (!context.table) return;
  const expected = expectedDrafts.find((draft) => tableNames(context.table).includes(draft.tableNumber));
  if (!expected) return;
  const quantities = (items) => {
    const totals = new Map();
    for (const item of items) {
      const id = idOf(productFor(context, item.productId));
      totals.set(id, (totals.get(id) || 0) + item.quantity);
    }
    return [...totals.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  };
  if (JSON.stringify(quantities(expected.items)) !== JSON.stringify(quantities(context.items))) {
    throw ApiError.conflict('Local draft aur backend draft alag hain. Pehle current draft normal POS se save/KOT ya reconcile kijiye. Chotu ne draft change nahi kiya.', 'CHOTU_DRAFT_CONFLICT');
  }
}

function ensureSimpleOrder(context) {
  const order = context.order;
  if (order && (order.discountAmount > 0 || order.tipAmount > 0 || order.deliveryCharge > 0 || order.roundOff)) {
    throw ApiError.badRequest('Discounted/adjusted order ko normal POS se complete kijiye.');
  }
}

function draftItems(context, action, command) {
  const items = context.items.map((item) => ({ ...item }));
  const requested = command.items?.length ? command.items : [command.item];
  for (const item of requested) {
    if (!item || !item.product_id || item.matched === false || item.modifiers?.length || item.variantName || item.variant_name) {
      throw ApiError.badRequest('Please repeat the complete order using exact menu items.');
    }
    const product = productFor(context, item.product_id);
    const id = idOf(product);
    const position = items.findIndex((i) => i.productId === id);
    const quantity = action === 'add_items' ? item.quantity ?? 1 : command.quantity ?? item.quantity ?? 1;
    if (!quantityValid(quantity)) throw ApiError.badRequest('Quantity must be a whole number from 1 to 99.');
    if (action !== 'add_items' && position < 0) throw ApiError.badRequest(`${product.name} cart mein nahi hai.`);
    const nextQuantity = action === 'add_items' ? (items[position]?.quantity || 0) + quantity
      : action === 'remove_item' ? Math.max(0, items[position].quantity - quantity) : quantity;
    const sent = context.kitchenItems.find((i) => String(i.productId) === id)?.quantity || 0;
    if (nextQuantity < sent) throw ApiError.badRequest('Kitchen mein bheje items ko normal POS correction se change kijiye.');
    if (nextQuantity === 0) items.splice(position, 1);
    else {
      const line = lineFor(product, nextQuantity);
      if (position >= 0) items[position] = line; else items.push(line);
    }
  }
  // Validate every line before replacing the cart, so multi-item requests are all or nothing.
  return items.map((item) => lineFor(productFor(context, item.productId), item.quantity));
}

function payloadFor(context, actor) {
  ensureSimpleOrder(context);
  if (!context.items.length) throw ApiError.badRequest('Cannot submit or bill an empty cart.');
  return {
    orderId: context.order && !['completed', 'cancelled'].includes(context.order.status) ? context.order._id.toString() : undefined,
    orderType: 'dineIn', tableNumber: context.table.name,
    items: context.items.map((i) => ({ ...i, price: i.effectivePrice })),
    ...financials(context),
    customerName: context.order?.customerName || '', customerPhone: context.order?.customerPhone || '',
    staffId: actor.userId.toString(), staffRole: actor.role, staffName: actor.name || '',
    CreatedByUserId: actor.userId.toString(),
  };
}

function preflight(context, actions, command, actor) {
  const action = actions.find((value) => ['add_items', 'remove_item', 'set_quantity'].includes(value));
  if (action) {
    ensureSimpleOrder(context);
    context.nextItems = draftItems(context, action, command);
  }
  if (actions.includes('clear_draft') && context.order && !['completed', 'cancelled'].includes(context.order.status)) {
    throw ApiError.badRequest('Issued order/invoice cancellation normal POS par kijiye.');
  }
  if (actions.some((value) => ['send_kot', 'generate_bill', 'settle_cash'].includes(value))) payloadFor(context, actor);
  if (actions.includes('settle_cash')) {
    if (!['owner', 'admin', 'cashier'].includes(actor.role)) throw ApiError.forbidden('Cash settlement requires owner, admin or cashier role.');
    if (!context.business.orderSettings?.paymentMethods?.cash) throw ApiError.badRequest('Cash payments are disabled for this business.');
    if (command.payment_confirmed !== true || command.payment_method !== 'cash') throw ApiError.badRequest('Explicit cash received confirmation is required.');
  }
}

async function execute(context, action, command, actor, requestKey) {
  const { businessId, table } = context;
  if (['add_items', 'remove_item', 'set_quantity'].includes(action)) {
    await cartService.syncCart(businessId, { tableNumber: context.cart?.tableNumber || table.name, orderType: 'dineIn', items: context.nextItems });
    context.items = context.nextItems;
    context.session.stage = 'draft';
    context.session.billFingerprint = '';
    // A new draft after settlement must not reuse the previous paid order ID.
    if (['completed', 'cancelled'].includes(context.order?.status)) {
      context.order = null;
      context.session.orderId = null;
    }
  } else if (action === 'clear_draft') {
    await cartService.clearCart(businessId, { tableNumber: context.cart?.tableNumber || table.name, orderType: 'dineIn' });
    context.items = [];
    context.session.stage = 'draft';
  } else if (action === 'send_kot') {
    const data = payloadFor(context, actor);
    const generated = await orderService.generatePosOrder(businessId, {
      ...data, isKOT: true, status: 'preparing', paymentMethod: 'kot pending',
      idempotencyKey: `chotu:${requestKey}`,
    });
    context.order = generated.order;
    const saved = await orderService.saveAndPrintOrder(businessId, {
      ...data, orderId: context.order._id.toString(), printType: 'kot', notes: `chotu:${fingerprint(context)}`,
    });
    context.order = saved.order;
    context.order.status = 'preparing';
    context.order.kotStatus = 'sent';
    context.order.kotNumber = (context.order.kotNumber || 0) + 1;
    await context.order.save();
    await Table.updateOne({ _id: table._id, businessId }, { $set: { status: 'runningKot', currentOrderId: context.order._id } });
    tableService.emitTableUpdateForTable(businessId, table.name);
    context.session.stage = 'kitchen';
    context.session.kitchenFingerprint = fingerprint(context);
    context.hasKitchenOrder = true;
    context.kitchenItems = context.items.map((item) => ({ ...item }));
  } else if (action === 'generate_bill') {
    const saved = await orderService.saveAndPrintOrder(businessId, {
      ...payloadFor(context, actor), printType: 'bill', notes: `chotu:${fingerprint(context)}`,
      idempotencyKey: `chotu:${requestKey}`,
    });
    context.order = saved.order;
    context.session.stage = 'billed';
    context.session.billFingerprint = fingerprint(context);
  } else if (action === 'settle_cash') {
    const settled = await orderService.settleOrder(businessId, context.order._id.toString(), {
      paymentMethod: 'Cash', amountPaid: context.order.totalAmount,
      staffId: actor.userId.toString(), staffRole: actor.role, CreatedByUserId: actor.userId.toString(),
    });
    context.order = settled.order;
    context.items = [];
    context.session.stage = 'completed';
  } else if (action !== 'view_order') {
    throw ApiError.badRequest('Unknown Chotu automation tool.');
  }
  if (context.order) context.session.orderId = context.order._id;
  if (action !== 'view_order') {
    const isFree = context.session.stage === 'completed' || !context.items.length;
    await Table.updateOne({ _id: table._id, businessId }, {
      $set: {
        status: isFree ? 'free' : context.hasKitchenOrder ? 'runningKot' : 'occupied',
        currentOrderTotal: isFree ? 0 : financials(context).totalAmount,
        activeItemCount: context.items.reduce((sum, item) => sum + item.quantity, 0),
        currentOrderId: isFree ? null : context.order?._id || null,
        currentOrderNumber: isFree ? null : context.order?.orderNumber || null,
        ...(isFree ? { occupiedSince: null } : {}),
      },
    });
    await tableService.emitTableUpdateForTable(businessId, table.name);
  }
}

async function snapshot(context) {
  const table = context.table ? await Table.findOne({ _id: context.table._id, businessId: context.businessId }) : null;
  const kotQuantityFor = (item) => context.kitchenItems.find((line) => String(line.productId) === String(item.productId))?.quantity || 0;
  const order = context.order?.toJSON ? context.order.toJSON() : context.order;
  if (order) {
    const rates = order.items.map((item) => {
      const product = context.products.find((p) => idOf(p) === String(item.productId) || p.productId === String(item.productId));
      return product ? gstPercentFor(context, product) : null;
    });
    // Historical receipts retain their stored money values. Annotate their line
    // rates only when today's menu/settings explain the original tax total.
    const taxMatches = rates.every((rate) => rate != null)
      && cents(order.items.reduce((sum, item, index) => sum + item.price * item.quantity * rates[index] / 100, 0)) === order.taxAmount;
    order.items = order.items.map((item, index) => ({
      ...item, kotQuantity: kotQuantityFor(item),
      ...(taxMatches ? { gstPercent: rates[index] } : {}),
    }));
  }
  return {
    tableNumber: table?.name || null, table,
    cart: {
      tableNumber: table?.name || '', orderType: 'dineIn',
      items: context.items.map((item) => ({
        ...item,
        gstPercent: gstPercentFor(context, productFor(context, item.productId)),
        kotQuantity: kotQuantityFor(item),
      })),
    },
    order: order || null,
  };
}

module.exports = { resolveTable, loadContext, policyContext, checkExpectedDraft, preflight, execute, snapshot, hash };
