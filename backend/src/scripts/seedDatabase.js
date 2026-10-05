/**
 * MongoDB Compass Database Seeder & Schema Initializer for Apna POS
 * 
 * This script connects to MongoDB, creates all collections and indexes,
 * and inserts a rich, realistic baseline dataset for full POS operations.
 * 
 * Run with: node src/scripts/seedDatabase.js (or npm run seed)
 */

const mongoose = require('mongoose');
const env = require('../config/env');
const User = require('../models/User');
const Business = require('../models/Business');
const Category = require('../models/Category');
const Product = require('../models/Product');
const Table = require('../models/Table');
const Order = require('../models/Order');
const Cart = require('../models/Cart');
const Customer = require('../models/Customer');
const CustomerLoyalty = require('../models/CustomerLoyalty');
const LoyaltyProgram = require('../models/LoyaltyProgram');
const LoyaltyTransaction = require('../models/LoyaltyTransaction');
const Inventory = require('../models/Inventory');
const Extra = require('../models/Extra');
const Staff = require('../models/Staff');
const PrintLog = require('../models/PrintLog');
const Notification = require('../models/Notification');
const Sale = require('../models/Sale');

async function seedDatabase() {
  const uri = process.env.MONGODB_URI || env.MONGODB_URI || 'mongodb://127.0.0.1:27017/apna_pos';
  console.log('=================================================================');
  console.log('🚀 [Apna POS] Initializing MongoDB Compass Database Seeder...');
  console.log(`📡 Connecting to: ${uri}`);
  console.log('=================================================================');

  try {
    await mongoose.connect(uri, { autoIndex: true });
    console.log('✅ Connected to MongoDB successfully.');

    // 1. Create or Find Baseline User (Owner)
    console.log('👤 [1/10] Setting up Owner User...');
    const ownerEmail = 'owner@apnapos.com';
    let user = await User.findOne({ email: ownerEmail });
    if (!user) {
      const passwordHash = await User.hashPassword('Admin@123');
      user = await User.create({
        email: ownerEmail,
        phone: '+919876543210',
        passwordHash,
        role: 'owner',
        status: 'active',
        isSuperAdmin: true,
        emailVerified: true,
        phoneVerified: true,
        onboardingCompleted: true,
        onboardingStep: 4,
        subscription: {
          plan: 'pro',
          status: 'active',
          billingCycle: 'annual',
          maxTables: 50,
          maxStaff: 20,
        },
      });
      console.log(`   ✨ Created Owner User (ID: ${user._id})`);
    } else {
      console.log(`   ℹ️ Found Existing Owner User (ID: ${user._id})`);
    }

    const businessId = user._id;

    // 2. Create or Update Business Profile
    console.log('🏢 [2/10] Setting up Restaurant Business Profile...');
    let business = await Business.findOne({ ownerId: user._id });
    if (!business) {
      business = await Business.create({
        ownerId: user._id,
        profile: {
          name: 'Apna Restaurant & Cafe',
          companyName: 'Apna Hospitality Pvt Ltd',
          phone: '+919876543210',
          website: 'https://apnapos.com',
          referralCode: 'APNA100',
        },
        business: {
          country: 'IN',
          currency: 'INR',
          timezone: 'Asia/Kolkata',
          businessType: 'Restaurant',
        },
        address: {
          addressLine: 'Connaught Place, Inner Circle',
          building: 'Block B, Ground Floor',
          landmark: 'Near Rajiv Chowk Metro Gate 2',
          city: 'New Delhi',
          state: 'Delhi',
          postalCode: '110001',
          placeType: 'work',
          location: { type: 'Point', coordinates: [77.2195, 28.6328] },
        },
        orderSettings: {
          services: { dineIn: true, takeaway: true, delivery: true },
          tax: { type: 'gst', gstNumber: '07AAAAA0000A1Z5', percentage: 5 },
          restaurantType: 'both',
          paymentMethods: { cash: true, upi: true, card: true },
          upiId: 'apnapos@upi',
          tableCount: 12,
          posViewMode: 'with_image',
          enableChotuVoice: true,
        },
      });
      console.log(`   ✨ Created Restaurant Profile (ID: ${business._id})`);
    } else {
      console.log(`   ℹ️ Found Existing Restaurant Profile (ID: ${business._id})`);
    }

    // 3. Setup Categories
    console.log('📂 [3/10] Setting up Categories...');
    const categoryNames = ['Starters', 'Main Course', 'Breads & Rice', 'Beverages', 'Desserts'];
    const categoryColors = ['#F59E0B', '#EF4444', '#10B981', '#3B82F6', '#EC4899'];
    for (let i = 0; i < categoryNames.length; i++) {
      await Category.findOneAndUpdate(
        { businessId: business._id, name: categoryNames[i] },
        {
          businessId: business._id,
          name: categoryNames[i],
          sortOrder: i + 1,
          color: categoryColors[i],
          icon: 'restaurant_menu',
        },
        { upsert: true, new: true }
      );
    }
    console.log(`   ✨ Synced ${categoryNames.length} Categories.`);

    // 4. Setup Products / Menu Items with Variants & Discounts
    console.log('🍔 [4/10] Setting up Menu Products with Variants...');
    const productsSeed = [
      {
        name: 'Paneer Butter Masala',
        category: 'Main Course',
        price: 280,
        hasDiscount: true,
        discountPercent: 10,
        salePrice: 252,
        foodType: 'veg',
        stock: 45,
        sku: 'PBM-001',
        description: 'Rich cottage cheese in creamy tomato-butter gravy',
        aliases: ['paneer', 'pbm', 'butter paneer', 'shahi paneer'],
        variants: [
          { name: 'Half (300ml)', price: 160, hasDiscount: false, discountPercent: 0, salePrice: 160, stock: 25 },
          { name: 'Full (600ml)', price: 280, hasDiscount: true, discountPercent: 10, salePrice: 252, stock: 20 },
        ],
      },
      {
        name: 'Butter Chicken Special',
        category: 'Main Course',
        price: 340,
        hasDiscount: false,
        discountPercent: 0,
        salePrice: 340,
        foodType: 'non_veg',
        stock: 35,
        sku: 'BC-002',
        description: 'Tender tandoori chicken cooked in velvety buttery gravy',
        aliases: ['chicken', 'butter chicken', 'murgh makhani'],
        variants: [
          { name: 'Half (2 pcs)', price: 200, hasDiscount: false, discountPercent: 0, salePrice: 200, stock: 15 },
          { name: 'Full (4 pcs)', price: 340, hasDiscount: false, discountPercent: 0, salePrice: 340, stock: 20 },
        ],
      },
      {
        name: 'Crispy Veg Spring Rolls',
        category: 'Starters',
        price: 180,
        hasDiscount: true,
        discountPercent: 15,
        salePrice: 153,
        foodType: 'veg',
        stock: 50,
        sku: 'STR-003',
        description: 'Golden fried rolls stuffed with crunchy seasoned vegetables',
        aliases: ['spring roll', 'rolls', 'veg roll'],
        variants: [],
      },
      {
        name: 'Butter Garlic Naan',
        category: 'Breads & Rice',
        price: 60,
        hasDiscount: false,
        discountPercent: 0,
        salePrice: 60,
        foodType: 'veg',
        stock: 100,
        sku: 'BRD-004',
        description: 'Clay-oven baked leavened bread topped with roasted garlic & butter',
        aliases: ['naan', 'butter naan', 'garlic naan', 'roti'],
        variants: [],
      },
      {
        name: 'Cold Coffee with Ice Cream',
        category: 'Beverages',
        price: 120,
        hasDiscount: false,
        discountPercent: 0,
        salePrice: 120,
        foodType: 'beverage',
        stock: 60,
        sku: 'BEV-005',
        description: 'Chilled blended espresso with creamy vanilla scoop',
        aliases: ['coffee', 'cold coffee', 'frappe'],
        variants: [
          { name: 'Regular', price: 120, hasDiscount: false, discountPercent: 0, salePrice: 120, stock: 30 },
          { name: 'Large 500ml', price: 160, hasDiscount: false, discountPercent: 0, salePrice: 160, stock: 30 },
        ],
      },
      {
        name: 'Gulab Jamun with Rabri',
        category: 'Desserts',
        price: 110,
        hasDiscount: false,
        discountPercent: 0,
        salePrice: 110,
        foodType: 'veg',
        stock: 40,
        sku: 'DES-006',
        description: 'Warm melt-in-mouth milk dumplings served with rich saffron rabri',
        aliases: ['gulab jamun', 'sweet', 'mithai'],
        variants: [],
      },
    ];

    for (const p of productsSeed) {
      await Product.findOneAndUpdate(
        { businessId: business._id, name: p.name },
        { ...p, businessId: business._id, isAvailable: true, trackInventory: true },
        { upsert: true, new: true }
      );
    }
    console.log(`   ✨ Synced ${productsSeed.length} Products with Variants.`);

    // 5. Setup Dining Tables across Floors
    console.log('🪑 [5/10] Setting up Dining Tables across Floors...');
    const tableConfigs = [
      { tableNumber: 1, name: 'T-1', floor: 'Ground Floor', capacity: 2, status: 'free' },
      { tableNumber: 2, name: 'T-2', floor: 'Ground Floor', capacity: 4, status: 'occupied', currentOrderTotal: 532, activeItemCount: 3, occupiedSince: new Date(Date.now() - 25 * 60000) },
      { tableNumber: 3, name: 'T-3', floor: 'Ground Floor', capacity: 4, status: 'runningKot', currentOrderTotal: 340, activeItemCount: 2, occupiedSince: new Date(Date.now() - 10 * 60000) },
      { tableNumber: 4, name: 'T-4', floor: 'Ground Floor', capacity: 6, status: 'free' },
      { tableNumber: 5, name: 'T-5', floor: 'Ground Floor', capacity: 4, status: 'free' },
      { tableNumber: 6, name: 'T-6', floor: 'Ground Floor', capacity: 8, status: 'free' },
      { tableNumber: 7, name: 'T-7', floor: '1st Floor', capacity: 2, status: 'free' },
      { tableNumber: 8, name: 'T-8', floor: '1st Floor', capacity: 4, status: 'free' },
      { tableNumber: 9, name: 'T-9', floor: '1st Floor', capacity: 6, status: 'free' },
      { tableNumber: 10, name: 'T-10', floor: '1st Floor', capacity: 4, status: 'free' },
      { tableNumber: 11, name: 'T-11', floor: '1st Floor', capacity: 4, status: 'free' },
      { tableNumber: 12, name: 'T-12', floor: '1st Floor', capacity: 10, status: 'free' },
    ];

    for (const t of tableConfigs) {
      await Table.findOneAndUpdate(
        { businessId: business._id, tableNumber: t.tableNumber },
        { ...t, businessId: business._id },
        { upsert: true, new: true }
      );
    }
    console.log(`   ✨ Synced ${tableConfigs.length} Tables across Ground Floor & 1st Floor.`);

    // 6. Setup Staff Members & Role Permissions
    console.log('👥 [6/10] Setting up Staff Members with Roles & PINs...');
    const staffSeed = [
      {
        name: 'Rahul Sharma',
        role: 'Manager',
        employeeId: 'EMP-001',
        pin: '1234',
        phone: '+919811122233',
        email: 'rahul.manager@apnapos.com',
        department: 'Operations',
        shift: 'Morning Shift (8 AM - 4 PM)',
        salary: 35000,
        permissions: ['pos', 'tables', 'orders', 'menu', 'inventory', 'reports', 'crm', 'loyalty', 'staff'],
        status: 'Active',
      },
      {
        name: 'Pooja Verma',
        role: 'Cashier',
        employeeId: 'EMP-002',
        pin: '2222',
        phone: '+919822233344',
        email: 'pooja.cashier@apnapos.com',
        department: 'Billing & Front Desk',
        shift: 'Morning Shift (8 AM - 4 PM)',
        salary: 22000,
        permissions: ['pos', 'tables', 'orders', 'crm'],
        status: 'Active',
      },
      {
        name: 'Amit Kumar',
        role: 'Waiter',
        employeeId: 'EMP-003',
        pin: '3333',
        phone: '+919833344455',
        department: 'Service',
        shift: 'Evening Shift (4 PM - 12 AM)',
        salary: 16000,
        permissions: ['pos', 'tables', 'orders'],
        status: 'Active',
      },
      {
        name: 'Chef Vikram Singh',
        role: 'Chef',
        employeeId: 'EMP-004',
        pin: '4444',
        phone: '+919844455566',
        department: 'Kitchen',
        shift: 'Full Day',
        salary: 30000,
        permissions: ['orders'],
        status: 'Active',
      },
    ];

    for (const s of staffSeed) {
      await Staff.findOneAndUpdate(
        { businessId: business._id, employeeId: s.employeeId },
        { ...s, businessId: business._id },
        { upsert: true, new: true }
      );
    }
    console.log(`   ✨ Synced ${staffSeed.length} Staff Members.`);

    // 7. Setup CRM Customers
    console.log('🤝 [7/10] Setting up CRM Customers...');
    const customerSeed = [
      {
        name: 'Ananya Roy',
        phone: '9876543210',
        email: 'ananya.roy@gmail.com',
        address: 'B-14, Connaught Place, New Delhi',
        totalOrders: 14,
        totalSpent: 4860,
        visitCount: 14,
        stage: 'Won',
        status: 'Active Customer',
        customerType: 'Regular Customer',
        tags: ['VIP', 'Regular', 'Dine-In Lover'],
        isStarred: true,
        isLiked: true,
      },
      {
        name: 'Rohan Gupta',
        phone: '9812345678',
        email: 'rohan.gupta@outlook.com',
        address: 'Flat 302, Green Park, New Delhi',
        totalOrders: 5,
        totalSpent: 1620,
        visitCount: 5,
        stage: 'Prospect',
        status: 'Follow Up',
        customerType: 'Regular Customer',
        tags: ['Weekend Customer'],
      },
      {
        name: 'Priya Sundaram',
        phone: '9899887766',
        email: 'priya.s@yahoo.com',
        address: 'H-9, Hauz Khas Enclave, New Delhi',
        totalOrders: 1,
        totalSpent: 450,
        visitCount: 1,
        stage: 'New Lead',
        status: 'New Lead',
        customerType: 'New Customer',
        tags: ['New Lead'],
      },
    ];

    for (const c of customerSeed) {
      await Customer.findOneAndUpdate(
        { businessId: business._id, phone: c.phone },
        { ...c, businessId: business._id },
        { upsert: true, new: true }
      );
    }
    console.log(`   ✨ Synced ${customerSeed.length} CRM Customers.`);

    // 8. Setup Inventory Stock & Raw Ingredients
    console.log('📦 [8/10] Setting up Raw Material Inventory Items...');
    const inventorySeed = [
      { itemName: 'Paneer (Fresh Cottage Cheese)', category: 'Dairy', quantity: 24.5, unit: 'kg', minThreshold: 5.0, costPerUnit: 320, supplier: 'Amul Dairy Distributor' },
      { itemName: 'Fresh Chicken Breast', category: 'Poultry', quantity: 18.0, unit: 'kg', minThreshold: 8.0, costPerUnit: 240, supplier: 'Delhi Fresh Meats' },
      { itemName: 'Amul Butter', category: 'Dairy', quantity: 15.0, unit: 'kg', minThreshold: 4.0, costPerUnit: 480, supplier: 'Amul Direct' },
      { itemName: 'Fresh Cream (Cooking)', category: 'Dairy', quantity: 12.0, unit: 'L', minThreshold: 3.0, costPerUnit: 210, supplier: 'Mother Dairy' },
      { itemName: 'Refined Flour (Maida)', category: 'Raw Ingredient', quantity: 50.0, unit: 'kg', minThreshold: 15.0, costPerUnit: 38, supplier: 'Kisan Agro Foods' },
      { itemName: 'Basmati Rice (Premium)', category: 'Raw Ingredient', quantity: 40.0, unit: 'kg', minThreshold: 10.0, costPerUnit: 110, supplier: 'Daawat Mills' },
      { itemName: 'Coffee Beans Espresso Roast', category: 'Beverage', quantity: 8.5, unit: 'kg', minThreshold: 2.0, costPerUnit: 850, supplier: 'Blue Tokai Roasters' },
    ];

    for (const inv of inventorySeed) {
      await Inventory.findOneAndUpdate(
        { businessId: business._id, itemName: inv.itemName },
        { ...inv, businessId: business._id },
        { upsert: true, new: true }
      );
    }
    console.log(`   ✨ Synced ${inventorySeed.length} Inventory Stock Items.`);

    // 9. Setup Extra Discounts & Coupons
    console.log('🏷️ [9/10] Setting up Extra Discounts & Promo Coupons...');
    const extrasSeed = [
      { name: 'Welcome 50 Flat Off', code: 'WELCOME50', type: 'coupon', discountType: 'flat', value: 50, minOrderAmount: 299, isAvailable: true, status: 'active' },
      { name: 'Flat 10% Off on Food', code: 'FLAT10', type: 'discount', discountType: 'percent', value: 10, minOrderAmount: 499, maxDiscount: 150, isAvailable: true, status: 'active' },
      { name: 'Extra Cheese Slice', name_display: 'Extra Cheese', type: 'addon', value: 30, price: 30, isAvailable: true, status: 'active' },
      { name: 'Packaging & Delivery Container', type: 'charge', value: 20, price: 20, isAvailable: true, status: 'active' },
    ];

    for (const ext of extrasSeed) {
      await Extra.findOneAndUpdate(
        { businessId: business._id, name: ext.name },
        { ...ext, businessId: business._id },
        { upsert: true, new: true }
      );
    }
    console.log(`   ✨ Synced ${extrasSeed.length} Discounts & Addons.`);

    // 10. Setup Loyalty Program
    console.log('💎 [10/10] Setting up Customer Loyalty Program...');
    await LoyaltyProgram.findOneAndUpdate(
      { businessId: business._id },
      {
        businessId: business._id,
        name: 'Apna Club Rewards',
        description: 'Earn 1 point for every ₹10 spent. Redeem points on delicious food!',
        pointsPerCurrency: 0.1, // 1 pt per ₹10
        currencyPerPoint: 0.5,  // 1 pt = ₹0.50
        minPointsToRedeem: 50,
        expiryDays: 365,
        isActive: true,
      },
      { upsert: true, new: true }
    );
    console.log('   ✨ Synced Customer Loyalty Program.');

    console.log('=================================================================');
    console.log('🎉 [SUCCESS] MongoDB Database Seeded & Verified Successfully!');
    console.log('=================================================================');
    console.log('📋 MONGODB COMPASS INSTRUCTIONS:');
    console.log(`1. Open MongoDB Compass.`);
    console.log(`2. Connect to: ${uri}`);
    console.log(`3. Select database: apna_pos`);
    console.log(`4. You can now view, edit, filter, and insert data across all collections:`);
    console.log(`   - users           (Roles, PINs, auth credentials, subscription)`);
    console.log(`   - businesses      (Restaurant info, GST, UPI, order settings)`);
    console.log(`   - categories      (Menu categories, colors, sort order)`);
    console.log(`   - products        (Menu items, prices, variants, stock, aliases)`);
    console.log(`   - tables          (Floors, capacities, statuses, active orders)`);
    console.log(`   - orders          (Dine-in, KOTs, takeaway, payment details)`);
    console.log(`   - staffs          (Staff members, PINs, granular permissions)`);
    console.log(`   - customers       (CRM leads, phone, total spend, loyalty)`);
    console.log(`   - inventories     (Raw material stocks, min alert thresholds)`);
    console.log(`   - extras          (Coupons, modifiers, discounts, charges)`);
    console.log(`   - loyaltyprograms (Points rules, reward exchange rates)`);
    console.log('=================================================================');
  } catch (err) {
    console.error('❌ Error during database seed:', err);
  } finally {
    await mongoose.disconnect();
    console.log('🔌 Disconnected from MongoDB.');
  }
}

if (require.main === module) {
  seedDatabase();
}

module.exports = seedDatabase;
