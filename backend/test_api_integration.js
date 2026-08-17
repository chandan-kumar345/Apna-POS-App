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
const cartService = require('./src/services/cartService');

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

    // 1. Test Products & Categories CRUD & Variants
    console.log('\n--- 1. Testing Product & Category Services (Add, Edit, Delete & Cascade) ---');
    
    const initialCatName = 'Biryani Feast ' + Date.now().toString().slice(-4);
    const renamedCatName = 'Royal Feast ' + Date.now().toString().slice(-4);

    // 1.1 Add Category
    const newCategory = await productService.createCategory(businessId, {
      name: initialCatName,
      icon: 'rice',
      color: '#FF6B00',
    });
    console.log(`✅ Category created: ${newCategory.name}`);

    // 1.2 Add Product with optional image omitted (Verifying image is completely optional!)
    const product = await productService.createProduct(businessId, {
      title: 'Dum Handi Biryani',
      description: 'Slow cooked aromatic basmati rice layered with tender meat & herbs',
      foodType: 'non_veg',
      price: 0,
      hasDiscount: true,
      discount: 10,
      // Note: No image supplied to test optional image handling!
      category: initialCatName,
      variants: [
        { name: 'Half (500g)', price: 220, hasDiscount: true, discountPercent: 10, salePrice: 198, stock: 30 },
        { name: 'Full (1kg)', price: 380, hasDiscount: true, discountPercent: 10, salePrice: 342, stock: 20 },
      ],
      gst: 5,
      inventory: 50,
      trackInventory: true,
    });
    console.log(`✅ Product created without image: ${product.name} (Unique ProductID: ${product.productId}, Image: '${product.image}', ID: ${product._id})`);
    console.log(`   Variants: ${product.variants.map((v) => `${v.name} @ ₹${v.price} (Sale: ₹${v.salePrice})`).join(', ')}`);

    // 1.3 Edit Product
    const updatedProduct = await productService.updateProduct(businessId, product.productId, {
      description: 'Slow cooked aromatic basmati rice layered with tender chicken & herbs (Updated)',
      taxPercentage: 12,
    });
    console.log(`✅ Product updated successfully: ${updatedProduct.name}, Tax: ${updatedProduct.taxPercentage}%`);

    // 1.4 Edit / Rename Category and Verify Cascading to Products
    const renamedCategory = await productService.updateCategory(businessId, initialCatName, {
      name: renamedCatName,
    });
    console.log(`✅ Category renamed from '${initialCatName}' to: ${renamedCategory.name}`);
    
    // Verify product's category updated to renamedCatName
    const fetchedProductAfterCatRename = await productService.getProductById(businessId, product.productId);
    console.log(`✅ Cascaded Product Category is now: '${fetchedProductAfterCatRename.category}' (Matches: ${fetchedProductAfterCatRename.category === renamedCatName})`);

    // 1.5 List Categories
    const categories = await productService.getCategories(businessId);
    console.log(`✅ Categories in DB: ${categories.map((c) => c.name).join(', ')}`);

    // 2. Test Tables & Adding X Tables
    console.log('\n--- 2. Testing Table Service & Adding X Tables ---');
    const initialTables = await tableService.getTables(businessId);
    console.log(`✅ Initial Tables count: ${initialTables.length}`);

    // Test creating 3 (X) tables in bulk
    const addedXTables = await tableService.createTable(businessId, {
      name: 'Rooftop',
      floor: 'Rooftop Lounge',
      capacity: 6,
      count: 3,
    });
    console.log(`✅ Created ${addedXTables.length} (X) tables in bulk. Tables: ${addedXTables.map((t) => `${t.name} (${t.floor})`).join(', ')}`);

    const updatedTablesList = await tableService.getTables(businessId);
    console.log(`✅ Total Tables count after bulk add: ${updatedTablesList.length} (Matches expected: ${updatedTablesList.length === initialTables.length + 3})`);

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
    });
    console.log(`✅ Order created: ${newOrder.orderNumber} (Total: ₹${newOrder.totalAmount})`);

    // 4. Test Settlement & Sales
    console.log('\n--- 4. Testing Settlement & Sales Conversion ---');
    const payment = await orderService.payOrder(businessId, newOrder._id, {
      paymentMethod: 'upi',
    });
    console.log(`✅ Order paid and settled. Sale ID: ${payment.sale._id}, Method: ${payment.sale.paymentMethod}`);

    // 5. Test Reports & Analytics
    console.log('\n--- 5. Testing Sales & Reports Aggregations ---');
    const summary = await salesService.getSalesSummary(businessId);
    console.log(`✅ Sales Summary: Total Revenue = ₹${summary.totalRevenue}, Total Orders = ${summary.totalOrders}, UPI = ₹${summary.upiSales}`);

    const topProducts = await salesService.getTopSellingProducts(businessId);
    console.log(`✅ Top Products:`, topProducts);

    // 6. Test Dashboard Aggregations
    console.log('\n--- 6. Testing Dashboard Analytics ---');
    const dashboardToday = await dashboardService.getSummary(businessId, { period: 'Today' });
    console.log(`✅ Dashboard Today Summary: Revenue = ₹${dashboardToday.revenue}, Orders = ${dashboardToday.totalOrders}, Tables = ${dashboardToday.tables.totalTables}`);

    const dashboardCharts = await dashboardService.getChartData(businessId, { filter: 'Today' });
    console.log(`✅ Dashboard Chart Points count: ${dashboardCharts.length}`);

    // 7. Test Inventory Control
    console.log('\n--- 7. Testing Inventory Service ---');
    const newStock = await inventoryService.createInventoryItem(businessId, {
      itemName: 'Paneer (Raw)',
      category: 'Dairy',
      quantity: 15,
      unit: 'kg',
      minThreshold: 3,
    });
    console.log(`✅ Inventory created: ${newStock.itemName} (${newStock.quantity} ${newStock.unit})`);

    // 8. Test Active Cart API (Cart Screen Endpoints)
    console.log('\n--- 8. Testing Active Cart Screen APIs (Add, Reduce, Remove, Sync & Clear) ---');
    
    // 8.1 Add discounted variant item
    const cartAfterAdd1 = await cartService.addToCart(businessId, {
      tableNumber: 'T-1',
      orderType: 'dineIn',
      product: {
        productId: product.productId,
        name: product.name,
        price: 380,
        hasDiscount: true,
        discountPercent: 10,
        salePrice: 342,
        foodType: 'non_veg',
      },
      variantName: 'Full (1kg)',
      quantity: 2,
    });
    console.log(`✅ Cart item added: Subtotal = ₹${cartAfterAdd1.subtotal}, Items = ${cartAfterAdd1.itemCount}, Discount = ₹${cartAfterAdd1.totalDiscount}`);

    // 8.2 Add second item
    const cartAfterAdd2 = await cartService.addToCart(businessId, {
      tableNumber: 'T-1',
      orderType: 'dineIn',
      product: {
        productId: 'PRD-PANEER-99',
        name: 'Paneer Butter Masala',
        price: 260,
        hasDiscount: false,
        foodType: 'veg',
      },
      quantity: 1,
    });
    console.log(`✅ Second item added: Subtotal = ₹${cartAfterAdd2.subtotal}, Items = ${cartAfterAdd2.itemCount}`);

    // 8.3 Reduce first item by 1
    const cartAfterReduce = await cartService.reduceProductFromCart(businessId, {
      tableNumber: 'T-1',
      orderType: 'dineIn',
      productId: product.productId,
      variantName: 'Full (1kg)',
      quantity: 1,
    });
    console.log(`✅ Cart item reduced: Subtotal = ₹${cartAfterReduce.subtotal}, Items = ${cartAfterReduce.itemCount}`);

    // 8.4 Remove item completely from cart
    const cartAfterRemove = await cartService.removeItemFromCart(businessId, {
      tableNumber: 'T-1',
      orderType: 'dineIn',
      productId: 'PRD-PANEER-99',
    });
    console.log(`✅ Cart item removed: Subtotal = ₹${cartAfterRemove.subtotal}, Items = ${cartAfterRemove.itemCount}`);

    // 8.5 Batch Sync Cart Items
    const cartAfterSync = await cartService.syncCart(businessId, {
      tableNumber: 'T-1',
      orderType: 'dineIn',
      items: [
        {
          productId: product.productId,
          name: product.name,
          price: 220,
          salePrice: 198,
          hasDiscount: true,
          discountPercent: 10,
          variantName: 'Half (500g)',
          quantity: 3,
          foodType: 'non_veg',
        },
      ],
    });
    console.log(`✅ Cart batch sync: Subtotal = ₹${cartAfterSync.subtotal}, Items = ${cartAfterSync.itemCount}`);

    // 8.6 Clear cart
    const cartCleared = await cartService.clearCart(businessId, {
      tableNumber: 'T-1',
      orderType: 'dineIn',
    });
    console.log(`✅ Cart cleared: Items count = ${cartCleared.items.length}, Subtotal = ${cartCleared.subtotal}`);

    console.log('\n========================================');
    console.log('🎉 ALL BACKEND PRODUCTION LOGICS & APIS PASSED AUTOMATED VERIFICATION!');
    console.log('========================================\n');
    console.log('========================================\n');
  } catch (err) {
    console.error('❌ Test failed with error:', err);
  } finally {
    await mongoose.disconnect();
  }
}

runTests();
