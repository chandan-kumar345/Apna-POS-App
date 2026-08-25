const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '..', '.env') });

const Business = require('../src/models/Business');
const Order = require('../src/models/Order');
const Sale = require('../src/models/Sale');
const PrintLog = require('../src/models/PrintLog');
const Table = require('../src/models/Table');

const orderService = require('../src/services/orderService');
const printLogService = require('../src/services/printLogService');
const salesService = require('../src/services/salesService');
const dashboardService = require('../src/services/dashboardService');

async function runTests() {
  console.log('Testing Save & Print, Multiple Prints, Snapshots, and Settlement Flow...');
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('✅ Connected to MongoDB');

  try {
    let business = await Business.findOne();
    if (!business) {
      console.log('No business found, creating test business...');
      business = await Business.create({
        ownerId: new mongoose.Types.ObjectId(),
        profile: { name: 'Test Food Cafe', companyName: 'Test Food Cafe' },
        orderSettings: { upiId: 'testcafe@okaxis' },
      });
    }

    const businessId = business._id;
    console.log(`Using businessId: ${businessId}`);

    // Clean any prior test orders with specific test prefix
    const testOrderNum = `TEST-ORD-${Date.now().toString().slice(-5)}`;

    // 1. First Save & Print with 2 items (Pizza = ₹200, Coke = ₹50 -> Total = ₹250)
    console.log('\n--- 1. Testing First Save & Print ---');
    const save1 = await orderService.saveAndPrintOrder(businessId, {
      orderNumber: testOrderNum,
      orderType: 'dineIn',
      tableNumber: 'T-99',
      customerName: 'Aman Kumar',
      customerPhone: '9876543210',
      items: [
        { name: 'Margherita Pizza', price: 200, quantity: 1, foodType: 'veg' },
        { name: 'Cold Drink (Coke)', price: 50, quantity: 1, foodType: 'beverage' },
      ],
      subtotal: 250,
      taxAmount: 12.5,
      totalAmount: 262.5,
    });

    console.log(`✅ Save & Print #1 success! Order ID: ${save1.order._id}, Order No: ${save1.order.orderNumber}`);
    console.log(`   Order Status: ${save1.order.status}, Payment Status: ${save1.order.paymentStatus}, isPaid: ${save1.order.isPaid}`);
    console.log(`   Print Log #1 Created: PrintNumber=${save1.printNumber}, Total=₹${save1.printLog.totalAmount}, Items=${save1.printLog.items.length}`);
    console.log(`   Dynamic QR Payload: ${save1.qrData.qrIntentUrl}`);

    if (save1.order.paymentStatus !== 'pending' || save1.order.isPaid) {
      throw new Error('Save & Print order must remain unpaid/pending!');
    }
    if (save1.printNumber !== 1) {
      throw new Error('Expected first printNumber to be 1');
    }

    // 2. Second Save & Print: User adds Fries (₹100) -> Total = ₹350
    console.log('\n--- 2. Testing Second Save & Print on the SAME running order (adding Fries) ---');
    const save2 = await orderService.saveAndPrintOrder(businessId, {
      orderId: save1.order._id.toString(),
      orderNumber: save1.order.orderNumber,
      orderType: 'dineIn',
      tableNumber: 'T-99',
      customerName: 'Aman Kumar',
      customerPhone: '9876543210',
      items: [
        { name: 'Margherita Pizza', price: 200, quantity: 1, foodType: 'veg' },
        { name: 'Cold Drink (Coke)', price: 50, quantity: 1, foodType: 'beverage' },
        { name: 'French Fries', price: 100, quantity: 1, foodType: 'veg' },
      ],
      subtotal: 350,
      taxAmount: 17.5,
      totalAmount: 367.5,
    });

    console.log(`✅ Save & Print #2 success! Order ID: ${save2.order._id}, Order No: ${save2.order.orderNumber}`);
    console.log(`   Print Log #2 Created: PrintNumber=${save2.printNumber}, Total=₹${save2.printLog.totalAmount}, Items=${save2.printLog.items.length}`);

    if (save2.order._id.toString() !== save1.order._id.toString()) {
      throw new Error('Order ID must remain identical for the same running order!');
    }
    if (save2.printNumber !== 2) {
      throw new Error('Expected second printNumber to be 2');
    }

    // 3. Verify Snapshot Immutability: Print Log #1 must still show 2 items (₹262.5), Print Log #2 must show 3 items (₹367.5)
    console.log('\n--- 3. Verifying Print Log Snapshot Immutability ---');
    const log1 = await printLogService.getPrintLogById(businessId, save1.printLog._id);
    const log2 = await printLogService.getPrintLogById(businessId, save2.printLog._id);

    console.log(`   Print Log #1 snapshot items: ${log1.items.length}, total: ₹${log1.totalAmount}`);
    console.log(`   Print Log #2 snapshot items: ${log2.items.length}, total: ₹${log2.totalAmount}`);

    if (log1.items.length !== 2 || log1.totalAmount !== 262.5) {
      throw new Error('Print Log #1 snapshot was mutated! It must remain 2 items and ₹262.5');
    }
    if (log2.items.length !== 3 || log2.totalAmount !== 367.5) {
      throw new Error('Print Log #2 snapshot must have 3 items and ₹367.5');
    }
    console.log('✅ Immutable snapshots verified successfully!');

    // 4. Verify Sales Report & Dashboard do NOT include this running/unpaid order yet
    console.log('\n--- 4. Verifying Unpaid Order is EXCLUDED from Sales Report & Dashboard ---');
    const salesReportBefore = await salesService.getSalesReport(businessId, { period: 'allTime' });
    const orderInReport = salesReportBefore.orders.find((o) => o.orderNumber === testOrderNum);
    if (orderInReport) {
      throw new Error('Unpaid running order should NOT appear in Sales Report orders!');
    }
    console.log('✅ Unpaid order correctly excluded from completed sales report!');

    // 5. Test Settlement Flow
    console.log('\n--- 5. Testing Settle Order Flow ---');
    const settlement = await orderService.settleOrder(businessId, save1.order._id, {
      paymentMethod: 'UPI',
      amountPaid: 367.5,
    });

    console.log(`✅ Settle success! Order Status: ${settlement.order.status}, Payment Status: ${settlement.order.paymentStatus}, isPaid: ${settlement.order.isPaid}`);
    console.log(`   Sale Record Created: ${settlement.sale?.orderNumber}, Total: ₹${settlement.sale?.totalAmount}`);

    if (settlement.order.paymentStatus !== 'paid' || !settlement.order.isPaid || settlement.order.status !== 'completed') {
      throw new Error('Settled order must be marked completed & paid!');
    }

    // 6. Verify Duplicate Settle Calls are IDEMPOTENT (Do not create duplicate sales)
    console.log('\n--- 6. Testing Idempotent Settlement (No Duplicate Sales) ---');
    const repeatSettle = await orderService.settleOrder(businessId, save1.order._id, {
      paymentMethod: 'UPI',
      amountPaid: 367.5,
    });
    console.log(`   Repeated Settle returned isExisting: ${repeatSettle.isExisting}`);

    const salesCount = await Sale.countDocuments({ businessId, orderNumber: testOrderNum });
    console.log(`   Sale records for ${testOrderNum}: ${salesCount}`);
    if (salesCount !== 1) {
      throw new Error(`Expected exactly 1 Sale record, but found ${salesCount}!`);
    }
    console.log('✅ Idempotent settlement verified: exactly 1 sale record created!');

    // 7. Verify Sales Report now includes the settled order exactly ONCE
    console.log('\n--- 7. Verifying Settled Order in Sales Report ---');
    const salesReportAfter = await salesService.getSalesReport(businessId, { period: 'allTime' });
    const matchingOrders = salesReportAfter.orders.filter((o) => o.orderNumber === testOrderNum);
    console.log(`   Matching orders in Sales Report: ${matchingOrders.length}`);
    if (matchingOrders.length !== 1) {
      throw new Error(`Expected exactly 1 settled order in Sales Report, found ${matchingOrders.length}`);
    }
    console.log('✅ Sales Report correctly counts settled order exactly once!');

    // 8. Test Print Logs API listing and filtering
    console.log('\n--- 8. Testing Print Logs API Query & Filtering ---');
    const printLogsList = await printLogService.getPrintLogs(businessId, { orderNumber: testOrderNum });
    console.log(`   Total print logs for ${testOrderNum}: ${printLogsList.printLogs.length}`);
    if (printLogsList.printLogs.length < 2) {
      throw new Error('Expected at least 2 print logs for this order!');
    }

    // Clean up test order & logs
    await Order.deleteMany({ businessId, orderNumber: testOrderNum });
    await Sale.deleteMany({ businessId, orderNumber: testOrderNum });
    await PrintLog.deleteMany({ businessId, orderNumber: testOrderNum });

    console.log('\n========================================');
    console.log('🎉 ALL BACKEND SAVE & PRINT + SETTLE TESTS PASSED!');
    console.log('========================================\n');
  } finally {
    await mongoose.disconnect();
  }
}

runTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
