jest.mock('../src/services/chotu/geminiCommandEngine', () => ({
  isConfigured: () => false,
  parseCommandWithGemini: jest.fn(async () => null),
}));

const request = require('supertest');
const app = require('../src/app');
const Product = require('../src/models/Product');
const Business = require('../src/models/Business');
const User = require('../src/models/User');
const Staff = require('../src/models/Staff');
const tokenService = require('../src/services/tokenService');
const Table = require('../src/models/Table');
const Cart = require('../src/models/Cart');
const Order = require('../src/models/Order');
const Sale = require('../src/models/Sale');
const PrintLog = require('../src/models/PrintLog');
const Session = require('../src/models/ChotuAgentSession');
const Turn = require('../src/models/ChotuAgentTurn');
const Lock = require('../src/models/ChotuAgentLock');
const orderService = require('../src/services/orderService');
const chotuService = require('../src/services/chotu/chotuService');
require('./setup');

describe('Python Chotu agent: authoritative order lifecycle', () => {
  let token;
  let businessId;
  let naan;
  let counter;
  const sessionId = 'agent-test-session';

  beforeAll(async () => {
    process.env.CHOTU_AGENT_ENABLED = 'true';
    await Promise.all([Session.init(), Turn.init(), Lock.init()]);
  });

  beforeEach(async () => {
    counter = 0;
    const registration = await request(app).post('/api/v1/auth/register').send({
      email: `agent_${Date.now()}@example.com`, password: 'Password@123', restaurantName: 'Agent Test',
    });
    expect(registration.status).toBe(201);
    token = registration.body.data.accessToken;
    await require('./helpers/grantBusinessAccess')(token);
    const me = await request(app).get('/api/v1/auth/me').set('Authorization', `Bearer ${token}`);
    businessId = me.body.data.business.id || me.body.data.business._id;
    await Table.create({ businessId, tableNumber: 5, name: 'T-5' });
    await Table.create({ businessId, tableNumber: 6, name: 'T-6' });
    naan = await Product.create({ businessId, name: 'Butter Naan', category: 'Bread', price: 40, stock: 50, taxPercentage: 5, aliases: ['naan'] });
    await Product.create({ businessId, name: 'Paneer Tikka', category: 'Starter', price: 240, stock: 20 });
  });

  afterEach(() => jest.restoreAllMocks());
  afterAll(() => { delete process.env.CHOTU_AGENT_ENABLED; });

  async function turn(text, extra = {}, authToken = token) {
    const response = await request(app).post('/api/v1/chotu/agent/turn')
      .set('Authorization', `Bearer ${authToken}`)
      .send({ sessionId, requestId: `turn-${++counter}`, text, ...extra });
    expect(response.status).toBe(200);
    return response.body.data;
  }

  it('reports an actual Python runtime in health', async () => {
    const response = await request(app).get('/api/v1/chotu/health').set('Authorization', `Bearer ${token}`);
    expect(response.body.data.automationAgent).toMatchObject({ enabled: true, available: true });
    expect(response.body.data.automationAgent.pythonVersion).toMatch(/^3\./);
  });

  it('grounds polite typed/voice requests, table switches, quantities and billing', async () => {
    const added = await turn('Can you add two butter naan to table no. five?');
    expect(added.status).toBe('completed');
    expect(added.cart.items[0].quantity).toBe(2);
    const updated = await turn('Table 5 butter naan ko 4 kar do');
    expect(updated.cart.items[0].quantity).toBe(4);
    const switched = await turn('Change table to 6');
    expect(switched.tableNumber).toBe('T-6');
    const emptyBill = await turn('Bill banao');
    expect(emptyBill.steps).toEqual([]);
    await turn('Select table 5');
    const kot = await turn('K O T bhejo');
    expect(kot.steps).toEqual(['send_kot']);
    const bill = await turn('Bill banao');
    expect(bill.order.totalAmount).toBe(168);
    expect(bill.order.isPaid).toBe(false);
  });

  it('creates cart, KOT, unpaid bill, paid sale, and frees table without duplicate effects', async () => {
    const added = await turn('Table 5 pe do butter naan aur ek paneer tikka laga do');
    expect(added.status).toBe('completed');
    expect(added.cart.items).toHaveLength(2);
    expect(added.cart.items.find((i) => i.name === 'Butter Naan').quantity).toBe(2);
    const kot = await turn('KOT kitchen bhej do');
    expect(kot.steps).toEqual(['send_kot']);
    expect(kot.order.status).toBe('preparing');
    expect(await PrintLog.countDocuments({ businessId, printType: 'kot' })).toBe(1);
    const repeatedKot = await turn('KOT kitchen bhej do');
    expect(repeatedKot.steps).toEqual([]);
    const bill = await turn('Bill bana do');
    expect(bill.order.isPaid).toBe(false);
    expect(bill.order.totalAmount).toBe(336);
    expect(await Sale.countDocuments({ businessId })).toBe(0);
    const confirmation = await turn('Complete order');
    expect(confirmation.status).toBe('needs_confirmation');
    expect(confirmation.steps).toEqual([]);
    const settled = await turn('Cash received, settle order', { requestId: 'cash-final' });
    expect(settled.steps).toEqual(['settle_cash']);
    expect(settled.order.isPaid).toBe(true);
    expect(settled.order.status).toBe('completed');
    expect(settled.table.status).toBe('free');
    expect(settled.table.currentOrderTotal).toBe(0);
    expect(await Sale.countDocuments({ businessId })).toBe(1);
    expect(await Order.countDocuments({ businessId })).toBe(1);
    console.log('CHOTU_LIFECYCLE_EVIDENCE', JSON.stringify({
      cartLines: added.cart.items.length, kot: kot.order.status,
      unpaidBillTotal: bill.order.totalAmount, paid: settled.order.isPaid,
      table: settled.table.status, saleCount: await Sale.countDocuments({ businessId }),
    }));
    // Replays load the persisted receipt, not an in-memory duplicate cache.
    const replay = await turn('Cash received, settle order', { requestId: 'cash-final' });
    expect(replay.isDuplicate).toBe(true);
    expect(await PrintLog.countDocuments({ businessId, printType: 'receipt' })).toBe(1);
    expect((await Product.findById(naan._id)).stock).toBe(48);
    const current = await request(app).get(`/api/v1/chotu/agent/sessions/${sessionId}`).set('Authorization', `Bearer ${token}`);
    expect(current.body.data.session.stage).toBe('completed');
  });

  it('runs the missing kitchen and invoice steps before confirmed cash completion', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    const settled = await turn('Cash received, settle order');
    expect(settled.steps).toEqual(['send_kot', 'generate_bill', 'settle_cash']);
    expect(settled.order.totalAmount).toBe(42);
    expect(await Sale.countDocuments({ businessId })).toBe(1);
  });

  it('preserves a pending order while asking for its table', async () => {
    const missing = await turn('Do butter naan laga do');
    expect(missing.status).toBe('needs_clarification');
    expect(await Cart.countDocuments({ businessId })).toBe(0);
    const resolved = await turn('Table 5');
    expect(resolved.cart.items[0].quantity).toBe(2);
  });

  it('does not partially add unmatched or insufficient-stock multi-item orders', async () => {
    const unknown = await turn('Table 5 pe ek butter naan aur ek unicorn soup laga do');
    expect(unknown.steps).toEqual([]);
    expect(await Cart.countDocuments({ businessId })).toBe(0);
    await Product.updateOne({ _id: naan._id }, { $set: { stock: 1 } });
    const stock = await turn('Table 5 pe do butter naan aur ek paneer tikka laga do');
    expect(stock.status).toBe('rejected');
    expect(await Cart.countDocuments({ businessId })).toBe(0);
  });

  it('edits a draft and blocks reductions of kitchen-submitted quantities', async () => {
    await turn('Table 5 pe do butter naan laga do');
    const edited = await turn('Butter naan ko 3 kar do');
    expect(edited.cart.items[0].quantity).toBe(3);
    await turn('KOT kitchen bhej do');
    const reduction = await turn('Butter naan ko 1 kar do');
    expect(reduction.status).toBe('rejected');
    expect((await Cart.findOne({ businessId, tableNumber: 'T-5' })).items[0].quantity).toBe(3);
  });

  it('re-bills after an addition and keeps one running order', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    await turn('Bill bana do');
    await turn('Ek butter naan aur add karo');
    const settled = await turn('Cash received, settle order');
    expect(settled.steps).toEqual(['send_kot', 'generate_bill', 'settle_cash']);
    expect(settled.order.totalAmount).toBe(84);
    expect(await Order.countDocuments({ businessId })).toBe(1);
    expect(await PrintLog.countDocuments({ businessId, printType: 'bill' })).toBe(2);
  });

  it('preserves unsent draft additions when the kitchen updates order status', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    const kot = await turn('KOT kitchen bhej do');
    await turn('Ek butter naan aur add karo');
    await Order.updateOne({ _id: kot.order.id, businessId }, { $set: { status: 'ready' } });

    const bill = await turn('Bill bana do', {
      expectedDrafts: [{ tableNumber: 'T-5', items: [{ productId: naan._id.toString(), quantity: 2 }] }],
    });
    expect(bill.status).toBe('completed');
    expect(bill.steps).toEqual(['generate_bill']);
    expect(bill.order.items[0].quantity).toBe(2);
    expect(bill.cart.items[0].quantity).toBe(2);
    expect(bill.order.totalAmount).toBe(84);
    expect((await Cart.findOne({ businessId, tableNumber: 'T-5' })).items[0].quantity).toBe(2);
    expect((await PrintLog.findOne({ businessId, printType: 'bill' })).totalAmount).toBe(84);
  });

  it('keeps billed additions pending until a new KOT snapshot is created', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    await turn('KOT kitchen bhej do');
    await turn('Ek butter naan aur add karo');
    const bill = await turn('Bill bana do');
    expect(bill.cart.items[0]).toMatchObject({ quantity: 2, kotQuantity: 1 });
    expect(bill.order.items[0]).toMatchObject({ quantity: 2, kotQuantity: 1 });

    const sent = await turn('KOT kitchen bhej do');
    expect(sent.steps).toEqual(['send_kot']);
    expect(sent.cart.items[0]).toMatchObject({ quantity: 2, kotQuantity: 2 });
    expect(sent.order.items[0]).toMatchObject({ quantity: 2, kotQuantity: 2 });
    expect((await turn('KOT kitchen bhej do')).steps).toEqual([]);
  });

  it('allows an unsent addition to be removed after billing without reducing sent quantities', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    await turn('KOT kitchen bhej do');
    await turn('Ek butter naan aur add karo');
    await turn('Bill bana do');
    const reduced = await turn('Butter naan ko 1 kar do');
    expect(reduced.status).toBe('completed');
    expect(reduced.cart.items[0]).toMatchObject({ quantity: 1, kotQuantity: 1 });
  });

  it('requires confirmation to clear and payment selection alone cannot settle', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    const clear = await turn('Clear cart');
    expect(clear.status).toBe('needs_confirmation');
    const switched = await turn('Table 6 confirm clear cart');
    expect(switched.steps).toEqual([]);
    expect((await Cart.findOne({ businessId, tableNumber: 'T-5' })).items).toHaveLength(1);
    await turn('Select table 5');
    const digital = await turn('Settle order with UPI');
    expect(digital.status).toBe('needs_confirmation');
    expect(await Sale.countDocuments({ businessId })).toBe(0);
    const negative = await turn('Cash not received, settle order');
    expect(negative.status).toBe('needs_confirmation');
    expect(negative.steps).toEqual([]);
  });

  it.each(['cash', 'upi', 'card'])('settles confirmed %s once using existing sale and receipt services', async (method) => {
    await Business.updateOne({ _id: businessId }, { $set: { [`orderSettings.paymentMethods.${method}`]: true } });
    await turn('Table 5 pe do butter naan laga do');
    const selection = await turn(`Settle bill with ${method}`);
    expect(selection.status).toBe('needs_confirmation');
    expect(selection.steps).toEqual([]);
    expect(selection.chotuMessage).toContain('84.00');
    const paid = await turn('Haan confirm', { requestId: 'confirmed-payment' });
    expect(paid.status).toBe('completed');
    expect(paid.order.isPaid).toBe(true);
    expect(paid.order.paymentMethod.toLowerCase()).toBe(method);
    expect(paid.table.status).toBe('free');
    expect(paid.printJobs.map((job) => job.type)).toEqual(['kot', 'bill']);
    expect(paid.printJobs.at(-1).order.isPaid).toBe(true);
    const replay = await turn('Haan confirm', { requestId: 'confirmed-payment' });
    expect(replay.printJobs).toEqual(paid.printJobs);
    expect(await Sale.countDocuments({ businessId })).toBe(1);
    expect((await Product.findById(naan._id)).stock).toBe(48);
  });

  it('asks for a method and binds confirmation to the unchanged table and total', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    expect((await turn('Settle bill')).status).toBe('needs_confirmation');
    expect((await turn('UPI')).status).toBe('needs_confirmation');
    await Cart.updateOne({ businessId, tableNumber: 'T-5' }, { $set: { 'items.0.quantity': 2 } });
    const changed = await turn('Yes');
    expect(changed.status).toBe('needs_confirmation');
    expect(changed.chotuMessage).toContain('84.00');
    expect(await Sale.countDocuments({ businessId })).toBe(0);
    await turn('Select table 6');
    expect((await turn('Haan confirm')).steps).toEqual([]);
    expect(await Sale.countDocuments({ businessId })).toBe(0);
  });

  it('preflights disabled methods before creating KOT, bill or payment', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    await Business.updateOne({ _id: businessId }, { $set: { 'orderSettings.paymentMethods.card': false } });
    const denied = await turn('Card payment received, settle bill');
    expect(denied.status).toBe('rejected');
    expect(await Order.countDocuments({ businessId })).toBe(0);
    expect(await PrintLog.countDocuments({ businessId })).toBe(0);
  });

  it('does not settle an explicit underpayment or split payment as a full bill', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    for (const text of ['Cash received 10 rupees, settle bill', 'UPI received Rs 20 settle order', 'cash and card received settle bill']) {
      const response = await turn(text);
      expect(response.steps).toEqual([]);
    }
    expect(await Sale.countDocuments({ businessId })).toBe(0);
    expect(await Order.countDocuments({ businessId })).toBe(0);
    expect((await turn('Cash received 42 rupees, settle bill')).order.isPaid).toBe(true);
  });

  it('settles an existing manual invoice without repricing variants, discounts or round-off', async () => {
    await Product.updateOne({ _id: naan._id }, { $set: { variants: [{ name: 'Large', price: 50 }] } });
    const saved = await orderService.saveAndPrintOrder(businessId, {
      orderType: 'dineIn', tableNumber: 'T-5',
      items: [{ productId: String(naan._id), name: 'Butter Naan (Large)', quantity: 2, price: 50, variantName: 'Large' }],
      subtotal: 100, discountAmount: 10, taxAmount: 4.5, totalAmount: 95, roundOff: 0.5,
      printType: 'bill', notes: 'manual-invoice',
    });
    saved.order.roundOff = 0.5;
    await saved.order.save();
    const before = JSON.parse(JSON.stringify(saved.order));
    await require('../src/services/cartService').syncCart(businessId, {
      orderType: 'dineIn', tableNumber: 'T-5',
      items: [{ productId: String(naan._id), name: 'Butter Naan', quantity: 2, price: 50, effectivePrice: 50, variantName: 'Large' }],
    });
    const selection = await turn('Table 5 settle UPI');
    if (selection.status !== 'needs_confirmation') throw new Error(JSON.stringify(selection));
    expect(selection).toMatchObject({ status: 'needs_confirmation', preserveLocalDraft: true });
    const paid = await turn('Haan confirm');
    expect(paid.steps).toEqual(['settle_payment']);
    expect(paid.order).toMatchObject({
      isPaid: true, totalAmount: before.totalAmount, taxAmount: before.taxAmount,
      discountAmount: before.discountAmount, roundOff: before.roundOff,
    });
    expect(JSON.parse(JSON.stringify((await Order.findById(saved.order._id)).items))).toEqual(before.items);
    expect(paid.order.items[0]).toMatchObject({ price: 50, name: 'Butter Naan (Large)' });
    expect(paid.printJobs).toHaveLength(1);
    expect(await Sale.countDocuments({ businessId })).toBe(1);
  });

  it('understands Hindi UPI confirmation and rejects hypothetical, negative and expired approvals', async () => {
    await turn('टेबल पांच पर एक बटर नान लगा दो');
    for (const text of ['UPI payment not received, settle bill', 'If UPI received settle bill', 'Card payment received? Settle order', 'यूपीआई पेमेंट नहीं मिला, सेटल करो']) {
      expect((await turn(text)).steps).toEqual([]);
    }
    await turn('Settle bill UPI');
    await Session.updateOne({ businessId, sessionId }, { $set: { 'pending.createdAt': Date.now() - 180000 } });
    expect((await turn('Yes')).steps).toEqual([]);
    expect(await Sale.countDocuments({ businessId })).toBe(0);
    const paid = await turn('यूपीआई पेमेंट मिल गया सेटल कर दो');
    expect(paid.order.isPaid).toBe(true);
    expect(paid.order.paymentMethod).toBe('UPI');
  });

  it('returns immutable delta KOT jobs and no print job for a repeated KOT', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    const first = await turn('के ओ टी प्रिंट करो');
    expect(first.printJobs[0]).toMatchObject({ type: 'kot', order: { items: [{ quantity: 1 }] } });
    expect((await turn('Print K O T')).printJobs).toEqual([]);
    await turn('Ek butter naan aur add karo');
    const next = await turn('KOT print karo');
    expect(next.printJobs[0].order.items[0].quantity).toBe(1);
    expect(next.order.items[0].quantity).toBe(2);
    expect(next.printJobs[0].id).not.toBe(first.printJobs[0].id);
  });

  it('never invents an order for an empty cart', async () => {
    const empty = await turn('Table 5 ka bill bana do');
    expect(empty.status).toBe('needs_clarification');
    expect(await Order.countDocuments({ businessId })).toBe(0);
  });

  it('replays persistent receipts and rejects altered reuse of request IDs', async () => {
    await turn('Table 5 pe ek butter naan laga do', { requestId: 'fixed' });
    const prior = await Turn.findOne({ businessId, requestId: 'fixed' }).lean();
    expect(prior.response.cart.items[0].quantity).toBe(1);
    const again = await turn('Table 5 pe ek butter naan laga do', { requestId: 'fixed' });
    expect(again.isDuplicate).toBe(true);
    const changed = await request(app).post('/api/v1/chotu/agent/turn').set('Authorization', `Bearer ${token}`)
      .send({ sessionId, requestId: 'fixed', text: 'Table 5 pe do butter naan laga do' });
    expect(changed.status).toBe(409);
    expect(changed.body.error.code).toBe('CHOTU_REQUEST_MISMATCH');
  });

  it('is tenant-scoped even when session IDs and request IDs collide', async () => {
    await turn('Table 5 pe ek butter naan laga do', { requestId: 'same' });
    await turn('Select table 5', { sessionId: 'owner-only' });
    const other = await request(app).post('/api/v1/auth/register').send({ email: 'other-agent@example.com', password: 'Password@123' });
    const otherToken = other.body.data.accessToken;
    await require('./helpers/grantBusinessAccess')(otherToken);
    const isolated = await turn('Table 5 pe ek butter naan laga do', { requestId: 'same' }, otherToken);
    expect(isolated.status).toBe('rejected');
    expect(isolated.isDuplicate).not.toBe(true);
    const hidden = await request(app).get('/api/v1/chotu/agent/sessions/owner-only').set('Authorization', `Bearer ${otherToken}`);
    expect(hidden.status).toBe(404);
    expect((await Cart.findOne({ businessId, tableNumber: 'T-5' })).items[0].quantity).toBe(1);
  });

  it('leaves a review receipt and blocks another writer after uncertain tool failure', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    const actual = orderService.saveAndPrintOrder.bind(orderService);
    jest.spyOn(orderService, 'saveAndPrintOrder').mockImplementationOnce(async (...args) => {
      await actual(...args);
      throw new Error('simulated disconnect after database write');
    });
    const failed = await turn('Bill bana do', { requestId: 'uncertain' });
    expect(failed.status).toBe('needs_review');
    expect(failed.failedAction).toBe('generate_bill');
    expect(await PrintLog.countDocuments({ businessId, printType: 'bill' })).toBe(1);
    const again = await turn('Bill bana do', { requestId: 'uncertain' });
    expect(again.isDuplicate).toBe(true);
    const blocked = await turn('Table 5 pe ek butter naan laga do', { sessionId: 'other-session' });
    expect(blocked.status).toBe('rejected');
    expect(await Lock.countDocuments({ businessId, resource: /^table:/ })).toBe(1);
  });

  it('validates authentication, text and runtime availability without a mutation fallback', async () => {
    const unauthenticated = await request(app).post('/api/v1/chotu/agent/turn').send({ text: 'add naan' });
    expect(unauthenticated.status).toBe(401);
    const forged = await request(app).post('/api/v1/chotu/agent/turn').set('Authorization', 'Bearer forged-token')
      .set('x-business-id', businessId).send({ sessionId, requestId: 'forged', text: 'Table 5 cash received, settle order' });
    expect(forged.status).toBe(401);
    const invalid = await request(app).post('/api/v1/chotu/agent/turn').set('Authorization', `Bearer ${token}`)
      .send({ sessionId, requestId: 'bad', text: '' });
    expect(invalid.status).toBe(400);
    process.env.CHOTU_PYTHON_BIN = 'missing-chotu-python-executable';
    try {
      const unavailable = await turn('Table 5 pe ek butter naan laga do');
      expect(unavailable.status).toBe('rejected');
      expect(unavailable.code).toBe('CHOTU_RUNTIME_UNAVAILABLE');
      expect(await Cart.countDocuments({ businessId })).toBe(0);
    } finally {
      delete process.env.CHOTU_PYTHON_BIN;
    }
  });

  it('does not let a parser fabricate cash confirmation', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    jest.spyOn(chotuService, 'parseVoiceCommand').mockResolvedValueOnce({ command: {
      intent: 'COMPLETE_ORDER', table_number: '5', confidence: 0.99, payment_confirmed: true,
    } });
    const result = await turn('Please handle it');
    expect(result.status).toBe('needs_confirmation');
    expect(await Sale.countDocuments({ businessId })).toBe(0);
  });

  it('checks staff permissions and settlement roles before running any completion steps', async () => {
    const waiter = await User.create({ email: 'agent-waiter@example.com', passwordHash: 'not-a-live-password', role: 'Waiter', businessId });
    const staff = await Staff.create({ businessId, userId: waiter._id, name: 'Test Waiter', role: 'Waiter', permissions: ['pos'] });
    const waiterToken = tokenService.generateAccessToken(waiter);
    await turn('Table 5 pe ek butter naan laga do', {}, waiterToken);
    const denied = await turn('Cash received, settle order', { userRole: 'owner', paymentConfirmed: true }, waiterToken);
    expect(denied.status).toBe('rejected');
    expect(denied.code).toBe('FORBIDDEN');
    expect(await Order.countDocuments({ businessId })).toBe(0);
    await Staff.updateOne({ _id: staff._id }, { $set: { permissions: [] } });
    const forbidden = await request(app).post('/api/v1/chotu/agent/turn').set('Authorization', `Bearer ${waiterToken}`)
      .send({ sessionId: 'staff-denied', requestId: 'denied', text: 'Table 5 pe ek butter naan laga do' });
    expect(forbidden.status).toBe(403);
  });

  it('uses authoritative prices and tax, including non-GST configuration', async () => {
    jest.spyOn(chotuService, 'parseVoiceCommand').mockResolvedValueOnce({ command: {
      intent: 'ADD_ITEM', table_number: '5', confidence: 1,
      items: [{ product_id: naan._id.toString(), quantity: 2, matched: true, price: 1 }],
    } });
    const added = await turn('Table 5 pe do butter naan laga do');
    expect(added.cart.items[0].effectivePrice).toBe(40);
    expect(added.cart.items[0].gstPercent).toBe(5);
    await Business.updateOne({ _id: businessId }, { $set: { 'orderSettings.tax.type': 'no_gst' } });
    const bill = await turn('Bill bana do');
    expect(bill.order.totalAmount).toBe(80);
    expect(bill.order.taxAmount).toBe(0);
    expect(bill.cart.items[0].gstPercent).toBe(0);
    expect(bill.order.items[0].gstPercent).toBe(0);
    const issuedClear = await turn('Clear cart');
    expect(issuedClear.status).toBe('unsupported');
  });

  it('includes authoritative zero and twelve percent tax rates in cart and invoice snapshots', async () => {
    await Product.updateOne({ _id: naan._id }, { $set: { taxPercentage: 0 } });
    await Product.updateOne({ businessId, name: 'Paneer Tikka' }, { $set: { taxPercentage: 12 } });
    const added = await turn('Table 5 pe ek butter naan aur ek paneer tikka laga do');
    expect(added.cart.items.find((item) => item.name === 'Butter Naan').gstPercent).toBe(0);
    expect(added.cart.items.find((item) => item.name === 'Paneer Tikka').gstPercent).toBe(12);
    const bill = await turn('Bill bana do');
    expect(bill.order.items.find((item) => item.name === 'Butter Naan').gstPercent).toBe(0);
    expect(bill.order.items.find((item) => item.name === 'Paneer Tikka').gstPercent).toBe(12);
    expect(bill.order.taxAmount).toBe(28.8);
    expect(bill.order.totalAmount).toBe(308.8);
  });

  it('refuses unsupported fulfilment and negative/compound instructions without mutation', async () => {
    for (const text of ['Table 5 pe ek butter naan takeaway order', "Table 5 don't add butter naan", 'Table 5 pe ek butter naan laga do aur KOT bhej do']) {
      const result = await turn(text);
      expect(result.steps).toEqual([]);
    }
    expect(await Cart.countDocuments({ businessId })).toBe(0);
  });

  it('serialises concurrent duplicate requests and applies the order exactly once', async () => {
    const input = { sessionId, requestId: 'concurrent', text: 'Table 5 pe ek butter naan laga do' };
    const send = () => request(app).post('/api/v1/chotu/agent/turn').set('Authorization', `Bearer ${token}`).send(input);
    const responses = await Promise.all([send(), send()]);
    expect(responses.some((r) => r.status === 200)).toBe(true);
    expect(responses.every((r) => [200, 409].includes(r.status))).toBe(true);
    const cart = await Cart.findOne({ businessId, tableNumber: 'T-5' });
    expect(cart.items[0].quantity).toBe(1);
    expect(await Turn.countDocuments({ businessId, requestId: 'concurrent' })).toBe(1);
  });

  it('preserves a local draft when its expected items differ from the backend', async () => {
    const mismatch = await turn('Table 5 pe ek butter naan laga do', {
      expectedDrafts: [{ tableNumber: 'T-5', items: [{ productId: naan._id.toString(), quantity: 2 }] }],
    });
    expect(mismatch.code).toBe('CHOTU_DRAFT_CONFLICT');
    expect(mismatch.steps).toEqual([]);
    expect(mismatch.cart).toBeUndefined();
    expect(await Cart.countDocuments({ businessId })).toBe(0);
  });

  it('does not clear a draft when confirmation is negated', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    await turn('Clear cart');
    const negative = await turn("Don't confirm clear cart");
    expect(negative.steps).toEqual([]);
    expect((await Cart.findOne({ businessId, tableNumber: 'T-5' })).items).toHaveLength(1);
  });

  it('preserves negation and conditional language before number normalization', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    for (const text of ['No cash received, settle order', 'If cash received, settle order', 'Cash received? Settle order', 'After cash received settle order']) {
      const result = await turn(text);
      expect(result.steps).toEqual([]);
      expect(await Sale.countDocuments({ businessId })).toBe(0);
    }
    await turn('Clear cart');
    const refused = await turn('No, confirm clear cart');
    expect(refused.steps).toEqual([]);
    expect((await Cart.findOne({ businessId, tableNumber: 'T-5' })).items).toHaveLength(1);
  });

  it('starts a fresh order after settlement without reusing the previous kitchen or customer state', async () => {
    await turn('Table 5 pe ek butter naan laga do');
    const first = await turn('Cash received, settle order');
    const next = await turn('Ek butter naan aur add karo');
    expect(next.stage).toBe('draft');
    expect(next.table.status).toBe('occupied');
    expect(next.order).toBeNull();
    const second = await turn('Cash received, settle order');
    expect(second.order.id).not.toBe(first.order.id);
    expect(await Order.countDocuments({ businessId })).toBe(2);
    expect(await Sale.countDocuments({ businessId })).toBe(2);
  });
});
