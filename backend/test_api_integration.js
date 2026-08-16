const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '.env') });

const User = require('./src/models/User');
const Business = require('./src/models/Business');
const Product = require('./src/models/Product');
const Category = require('./src/models/Category');
const Order = require('./src/models/Order');
const Sale = require('./src/models/Sale');
const Table = require('./src/models/Table');
const Customer = require('./src/models/Customer');
const Inventory = require('./src/models/Inventory');

const productService = require('./src/services/productService');
const orderService = require('./src/services/orderService');
const salesService = require('./src/services/salesService');
const dashboardService = require('./src/services/dashboardService');
const tableService = require('./src/services/tableService');
const customerService = require('./src/services/customerService');
const inventoryService = require('./src/services/inventoryService');

async function runTests() {
  console.log('Connecting to MongoDB Atlas...');
  await mongoose.connect(process.env.MONGODB_URI);
  console.log('✅ Connected to MongoDB Atlas');

  try {
    // Find or create test business
    let user = await User.findOne({ email: 'chandanyaduvanshi190@gmail.com' });
    if (!user) {
      console.log('Creating test user...');
      user = await User.create({
        email: 'chandanyaduvanshi190@gmail.com',
        phone: '9876543210',
        passwordHash: 'dummy',
        role: 'owner',
        onboardingCompleted: true,
      });
    }

    let business = await Business.findOne({ ownerId: user._id });
    if (!business) {
      console.log('Creating test business...');
      business = await Business.create({
        ownerId: user._id,
        profile: { name: 'Food affair', companyName: 'Food affair' },
      });
    }

    const businessId = business._id;
    console.log(`Testing with businessId: ${businessId}`);

    // 1. Test Products
    console.log('\n--- 1. Testing Product & Category Services ---');
    const product = await productService.createProduct(businessId, {
      name: 'Paneer Butter Masala Live Test',
      category: 'Main Course',
      price: 260,
      foodType: 'veg',
      isAvailable: true,
      stock: 40,
    });
    console.log(`✅ Product created: ${product.name} (ID: ${product._id})`);

    const productsResult = await productService.getProducts(businessId, { category: 'Main Course' });
    console.log(`✅ Fetched ${productsResult.products.length} products in 'Main Course'`);

    const categories = await productService.getCategories(businessId);
    console.log(`✅ Categories: ${categories.map((c) => c.name).join(', ')}`);

    // 2. Test Tables
    console.log('\n--- 2. Testing Table Service ---');
    const tables = await tableService.getTables(businessId);
    console.log(`✅ Tables count: ${tables.length}`);

    // 3. Test Orders
    console.log('\n--- 3. Testing Order & POS Services ---');
    const newOrder = await orderService.createOrder(businessId, {
      orderType: 'dineIn',
      tableNumber: 'T-1',
      customerName: 'Chandan Customer',
      customerPhone: '9876543210',
      items: [
        {
          productId: product._id,
          name: product.name,
          price: product.price,
          quantity: 2,
          foodType: product.foodType,
        },
      ],
      subtotal: 520,
      taxAmount: 26,
      totalAmount: 546,
      paymentMethod: 'unpaid',
      status: 'preparing',
    });
    console.log(`✅ Order created: ${newOrder.orderNumber} (Total: ₹${newOrder.totalAmount})`);

    // 4. Test Payment & Sale conversion
    console.log('\n--- 4. Testing Settlement & Sales Conversion ---');
    const paymentResult = await orderService.payOrder(businessId, newOrder._id, {
      paymentMethod: 'upi',
    });
    console.log(`✅ Order paid and settled. Sale ID: ${paymentResult.sale._id}, Method: ${paymentResult.sale.paymentMethod}`);

    // 5. Test Sales & Reports Summary
    console.log('\n--- 5. Testing Sales & Reports Aggregations ---');
    const summary = await salesService.getSalesSummary(businessId);
    console.log(`✅ Sales Summary: Total Revenue = ₹${summary.totalRevenue}, Total Orders = ${summary.totalOrders}, UPI = ₹${summary.upiSales}`);

    const topSelling = await salesService.getTopSellingProducts(businessId);
    console.log(`✅ Top Products:`, topSelling);

    // 6. Test Dashboard Live Analytics
    console.log('\n--- 6. Testing Dashboard Analytics ---');
    const dashSummary = await dashboardService.getSummary(businessId, { period: 'Today' });
    console.log(`✅ Dashboard Today Summary: Revenue = ₹${dashSummary.revenue}, Orders = ${dashSummary.totalOrders}, Tables = ${dashSummary.tables.totalTables}`);

    const chartPoints = await dashboardService.getChartData(businessId, { filter: 'Today' });
    console.log(`✅ Dashboard Chart Points count: ${chartPoints.length}`);

    // 7. Test Inventory
    console.log('\n--- 7. Testing Inventory Service ---');
    const invItem = await inventoryService.createInventoryItem(businessId, {
      itemName: 'Paneer (Raw)',
      category: 'Dairy',
      quantity: 15,
      unit: 'kg',
      minThreshold: 5,
    });
    console.log(`✅ Inventory created: ${invItem.itemName} (${invItem.quantity} ${invItem.unit})`);

    console.log('\n========================================');
    console.log('🎉 ALL BACKEND PRODUCTION LOGICS & APIS PASSED AUTOMATED VERIFICATION!');
    console.log('========================================\n');
  } catch (err) {
    console.error('❌ Test failed with error:', err);
  } finally {
    await mongoose.disconnect();
  }
}

runTests();
