const request = require('supertest');
const mongoose = require('mongoose');
require('./setup');
const app = require('../src/app');
const User = require('../src/models/User');
const Business = require('../src/models/Business');
const Order = require('../src/models/Order');
const Customer = require('../src/models/Customer');
const Wallet = require('../src/models/Wallet');
const WalletTransaction = require('../src/models/WalletTransaction');
const EBill = require('../src/models/EBill');
const tokenService = require('../src/services/tokenService');

describe('Save & eBill, Wallet, and WhatsApp Integration (/api/v1/ebill, /api/v1/wallet, /api/v1/whatsapp)', () => {
  let userA, businessA, tokenA;
  let userB, businessB, tokenB;
  let orderWithPhone, orderWithoutPhone;

  beforeEach(async () => {
    // 1. Setup Tenant A
    userA = await User.create({
      name: 'Owner A',
      email: 'tenant_a@apnapos.com',
      passwordHash: 'hashed_password_123',
      role: 'owner',
      status: 'active',
    });

    businessA = await Business.create({
      ownerId: userA._id,
      profile: { name: 'Tenant A Resto', companyName: 'Tenant A Foods', phone: '9876543210' },
      address: { city: 'Mumbai', state: 'Maharashtra' },
    });

    userA.businessId = businessA._id;
    await userA.save();

    tokenA = tokenService.generateAccessToken(userA);

    // 2. Setup Tenant B (for multi-tenant isolation testing)
    userB = await User.create({
      name: 'Owner B',
      email: 'tenant_b@apnapos.com',
      passwordHash: 'hashed_password_456',
      role: 'owner',
      status: 'active',
    });

    businessB = await Business.create({
      ownerId: userB._id,
      profile: { name: 'Tenant B Cafe', companyName: 'Tenant B Foods', phone: '9123456789' },
      address: { city: 'Delhi', state: 'Delhi' },
    });

    userB.businessId = businessB._id;
    await userB.save();

    tokenB = tokenService.generateAccessToken(userB);


    // 3. Create Orders for Tenant A
    orderWithPhone = await Order.create({
      businessId: businessA._id,
      orderNumber: 'ORD-2026-00101',
      orderType: 'dineIn',
      status: 'completed',
      customerName: 'Rahul Sharma',
      customerPhone: '9876543210',
      totalAmount: 450.0,
      subtotal: 400.0,
      taxAmount: 50.0,
      paymentMethod: 'UPI',
      items: [
        { name: 'Paneer Butter Masala', price: 250, quantity: 1, foodType: 'veg' },
        { name: 'Butter Naan', price: 50, quantity: 3, foodType: 'veg' },
      ],
    });

    orderWithoutPhone = await Order.create({
      businessId: businessA._id,
      orderNumber: 'ORD-2026-00102',
      orderType: 'takeaway',
      status: 'completed',
      customerName: 'Walk-in Guest',
      customerPhone: '',
      totalAmount: 180.0,
      subtotal: 180.0,
      paymentMethod: 'Cash',
      items: [{ name: 'Cold Coffee', price: 90, quantity: 2, foodType: 'beverage' }],
    });
  });

  describe('1. Wallet Operations (/api/v1/wallet)', () => {
    it('should initialize and fetch business wallet balance with default credit', async () => {
      const res = await request(app)
        .get('/api/v1/wallet/balance')
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.balance).toBeGreaterThanOrEqual(100);
      expect(res.body.data.ebillCharge).toBe(2.0);
    });

    it('should recharge business wallet and create an auditable CREDIT transaction', async () => {
      const rechargeRes = await request(app)
        .post('/api/v1/wallet/recharge')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ amount: 50, referenceId: 'PAY-1234', description: 'Test top-up' });

      expect(rechargeRes.status).toBe(200);
      expect(rechargeRes.body.success).toBe(true);
      expect(rechargeRes.body.data.wallet.balance).toBeGreaterThanOrEqual(150);

      const txRes = await request(app)
        .get('/api/v1/wallet/transactions')
        .set('Authorization', `Bearer ${tokenA}`);

      expect(txRes.status).toBe(200);
      expect(txRes.body.data.transactions.length).toBeGreaterThanOrEqual(1);
      expect(txRes.body.data.transactions[0].type).toBe('CREDIT');
      expect(txRes.body.data.transactions[0].amount).toBe(50);
    });
  });

  describe('2. eBill Eligibility (/api/v1/ebill/eligibility)', () => {
    it('should report eligible: true when customer phone is present and wallet has sufficient balance', async () => {
      const res = await request(app)
        .get(`/api/v1/ebill/eligibility?billId=${orderWithPhone._id}`)
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      expect(res.body.eligible).toBe(true);
      expect(res.body.customerPhonePresent).toBe(true);
      expect(res.body.ebillCharge).toBe(2.0);
      expect(res.body.walletBalance).toBeGreaterThanOrEqual(2.0);
    });

    it('should report eligible: false with CUSTOMER_PHONE_REQUIRED when customer phone is missing', async () => {
      const res = await request(app)
        .get(`/api/v1/ebill/eligibility?billId=${orderWithoutPhone._id}`)
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      expect(res.body.eligible).toBe(false);
      expect(res.body.customerPhonePresent).toBe(false);
      expect(res.body.reason).toBe('CUSTOMER_PHONE_REQUIRED');
    });

    it('should report eligible: false with INSUFFICIENT_WALLET_BALANCE when wallet is empty', async () => {
      // Drain Tenant A wallet
      await Wallet.findOneAndUpdate(
        { businessId: businessA._id },
        { balance: 0.5, isActive: true },
        { upsert: true, new: true }
      );

      const res = await request(app)
        .get(`/api/v1/ebill/eligibility?billId=${orderWithPhone._id}`)
        .set('Authorization', `Bearer ${tokenA}`);

      expect(res.status).toBe(200);
      expect(res.body.eligible).toBe(false);
      expect(res.body.customerPhonePresent).toBe(true);
      expect(res.body.reason).toBe('INSUFFICIENT_WALLET_BALANCE');
    });

  });

  describe('3. Save & Send eBill (/api/v1/ebill/send)', () => {
    it('should deduct eBill charge atomically, send receipt, and update bill ebill metadata', async () => {
      const initialWallet = await Wallet.findOne({ businessId: businessA._id });
      const initialBalance = initialWallet ? initialWallet.balance : 100.0;

      const res = await request(app)
        .post('/api/v1/ebill/send')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ billId: orderWithPhone._id.toString() });

      expect(res.status).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.data.status).toBe('SENT');
      expect(res.body.data.deliveryStatus).toBe('SENT');
      expect(res.body.data.amountCharged).toBe(2.0);
      expect(res.body.data.whatsappMessageId).toMatch(/^wamid\./);

      // Verify wallet deduction
      const updatedWallet = await Wallet.findOne({ businessId: businessA._id });
      expect(updatedWallet.balance).toBe(initialBalance - 2.0);

      // Verify wallet transaction ledger
      const tx = await WalletTransaction.findOne({
        businessId: businessA._id,
        category: 'EBILL',
        referenceId: orderWithPhone._id.toString(),
      });
      expect(tx).not.toBeNull();
      expect(tx.type).toBe('DEBIT');
      expect(tx.amount).toBe(2.0);

      // Verify EBill record
      const ebill = await EBill.findOne({ billId: orderWithPhone._id });
      expect(ebill).not.toBeNull();
      expect(ebill.status).toBe('SENT');
      expect(ebill.whatsappPhoneNumberId).toBe('1391578214040423');

      // Verify Order model updated
      const updatedOrder = await Order.findById(orderWithPhone._id);
      expect(updatedOrder.ebill.enabled).toBe(true);
      expect(updatedOrder.ebill.latestEbillId.toString()).toBe(ebill._id.toString());
    });

    it('should prevent duplicate charging on duplicate requests for the same bill', async () => {
      // First Send
      const res1 = await request(app)
        .post('/api/v1/ebill/send')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ billId: orderWithPhone._id.toString() });

      expect(res1.status).toBe(200);
      const balanceAfterFirst = res1.body.data.walletBalance;

      // Duplicate Send
      const res2 = await request(app)
        .post('/api/v1/ebill/send')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ billId: orderWithPhone._id.toString() });

      expect(res2.status).toBe(200);
      expect(res2.body.data.isDuplicate).toBe(true);

      // Wallet balance must NOT be debited twice!
      const currentWallet = await Wallet.findOne({ businessId: businessA._id });
      expect(currentWallet.balance).toBe(balanceAfterFirst);

      // Only ONE DEBIT transaction must exist for this bill
      const txCount = await WalletTransaction.countDocuments({
        businessId: businessA._id,
        category: 'EBILL',
        referenceId: orderWithPhone._id.toString(),
      });
      expect(txCount).toBe(1);
    });

    it('should reject sending when customer phone number is missing', async () => {
      const res = await request(app)
        .post('/api/v1/ebill/send')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ billId: orderWithoutPhone._id.toString() });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('CUSTOMER_PHONE_REQUIRED');

      // Bill remains completely intact
      const intactOrder = await Order.findById(orderWithoutPhone._id);
      expect(intactOrder).not.toBeNull();
    });

    it('should reject sending and not deduct wallet when wallet balance is insufficient', async () => {
      // Drain wallet
      await Wallet.findOneAndUpdate(
        { businessId: businessA._id },
        { balance: 1.0, isActive: true },
        { upsert: true, new: true }
      );

      const newOrder = await Order.create({

        businessId: businessA._id,
        orderNumber: 'ORD-2026-999',
        customerPhone: '9876543210',
        totalAmount: 100,
        subtotal: 100,
        items: [{ name: 'Tea', price: 20, quantity: 5 }],
      });

      const res = await request(app)
        .post('/api/v1/ebill/send')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ billId: newOrder._id.toString() });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('INSUFFICIENT_WALLET_BALANCE');

      // Balance remains 1.0
      const wallet = await Wallet.findOne({ businessId: businessA._id });
      expect(wallet.balance).toBe(1.0);
    });
  });

  describe('4. Multi-Tenant Data Isolation', () => {
    it('should reject Tenant B from accessing or sending eBill for Tenant A bill', async () => {
      const res = await request(app)
        .post('/api/v1/ebill/send')
        .set('Authorization', `Bearer ${tokenB}`) // Tenant B token
        .send({ billId: orderWithPhone._id.toString() }); // Tenant A bill

      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('BILL_NOT_FOUND');
    });
  });

  describe('5. WhatsApp Meta Webhook Integration (/api/v1/whatsapp/webhook)', () => {
    it('should verify Meta Webhook GET challenge with correct verify token', async () => {
      const res = await request(app)
        .get('/api/v1/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=apna_pos_ebill_verify_token&hub.challenge=test_challenge_123');

      expect(res.status).toBe(200);
      expect(res.text).toBe('test_challenge_123');
    });

    it('should reject Meta Webhook GET challenge with incorrect verify token', async () => {
      const res = await request(app)
        .get('/api/v1/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=wrong_token&hub.challenge=test_challenge_123');

      expect(res.status).toBe(403);
    });

    it('should process POST delivery status events and update EBill to DELIVERED', async () => {
      // 1. Send eBill first to generate an EBill with a whatsappMessageId
      const sendRes = await request(app)
        .post('/api/v1/ebill/send')
        .set('Authorization', `Bearer ${tokenA}`)
        .send({ billId: orderWithPhone._id.toString() });

      const messageId = sendRes.body.data.whatsappMessageId;
      const ebillId = sendRes.body.data.ebillId;

      // 2. Simulate Meta Webhook status event for DELIVERED
      const webhookPayload = {
        object: 'whatsapp_business_account',
        entry: [
          {
            id: '1391578214040423',
            changes: [
              {
                value: {
                  messaging_product: 'whatsapp',
                  metadata: { display_phone_number: '1234567890', phone_number_id: '1391578214040423' },
                  statuses: [
                    {
                      id: messageId,
                      status: 'delivered',
                      timestamp: Math.floor(Date.now() / 1000).toString(),
                      recipient_id: '919876543210',
                    },
                  ],
                },
                field: 'messages',
              },
            ],
          },
        ],
      };

      const webhookRes = await request(app)
        .post('/api/v1/whatsapp/webhook')
        .send(webhookPayload);

      expect(webhookRes.status).toBe(200);
      expect(webhookRes.body.success).toBe(true);

      // 3. Verify status endpoint shows DELIVERED
      const statusRes = await request(app)
        .get(`/api/v1/ebill/${ebillId}/status`)
        .set('Authorization', `Bearer ${tokenA}`);

      expect(statusRes.status).toBe(200);
      expect(statusRes.body.data.status).toBe('DELIVERED');
      expect(statusRes.body.data.deliveryStatus).toBe('DELIVERED');
    });
  });
});
