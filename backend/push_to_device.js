const mongoose = require('mongoose');
require('dotenv').config({ path: 'backend/.env' });
const cronService = require('./src/services/cronService');
const pushNotificationService = require('./src/services/pushNotificationService');
const notificationService = require('./src/services/notificationService');

async function pushNow() {
  try {
    console.log('[PushNow] Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('[PushNow] Connected to MongoDB.');

    const User = require('./src/models/User');
    const Business = require('./src/models/Business');
    const Order = require('./src/models/Order');

    // Find the user with active pushToken
    const user = await User.findOne({ pushToken: { $exists: true, $ne: '' } }).lean();
    if (!user) {
      console.error('[PushNow] ❌ No user found with an active pushToken in database!');
      process.exit(1);
    }
    console.log(`[PushNow] ✅ Found registered user: ${user.name || user.email || user._id} with token starting with ${user.pushToken.substring(0, 25)}...`);

    // Find user's business
    let business = null;
    if (user.businessId) {
      business = await Business.findById(user.businessId).lean();
    }
    if (!business) {
      business = await Business.findOne({ ownerId: user._id }).lean();
    }
    if (!business) {
      business = await Business.findOne().lean();
    }
    console.log(`[PushNow] Business: ${business?.name || 'My Store'} (${business?._id})`);

    // Let's check today's orders
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
    const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999);

    const bId = business ? business._id : user.businessId;
    const orders = await Order.find({
      businessId: { $in: [bId, bId.toString()] },
      createdAt: { $gte: startOfToday, $lte: endOfToday },
      status: { $nin: ['cancelled', 'void'] },
    }).lean();

    console.log(`[PushNow] Found ${orders.length} orders for today.`);

    // If today has orders, use today's actual totals; otherwise generate realistic business summary for demonstration
    let totalSales = 0;
    let orderCount = orders.length;
    for (const ord of orders) {
      totalSales += Number(ord.totalAmount) || 0;
    }

    const salesBannerService = require('./src/services/salesBannerService');

    const avgOrderValue = orderCount > 0 ? Math.round(totalSales / orderCount) : 0;
    const formattedDate = new Intl.DateTimeFormat('en-IN', {
      day: 'numeric',
      month: 'short',
    }).format(now);

    const bannerUrl = await salesBannerService.generateAndUploadBanner({
      totalSales,
      orderCount,
      avgOrderValue,
      dateLabel: formattedDate,
      percentageChange: 0,
      isHigher: true,
      yesterdaySales: 0,
    });

    const formattedSales = `₹${totalSales.toLocaleString('en-IN')}`;
    const formattedAvg = `₹${avgOrderValue.toLocaleString('en-IN')}`;

    const title = `${business?.name ? business.name + ' • ' : ''}Daily Sales Summary 📊 • ${formattedDate}`;
    let message = '';
    if (orderCount > 0) {
      message = `🟢 Total Sales: ${formattedSales}  •  🔵 Total Orders: ${orderCount}  •  🟠 Avg Order Value: ${formattedAvg}`;
    } else {
      message = `Your daily business summary for ${formattedDate} is ready. No orders were recorded today. Tap to view sales report.`;
    }

    console.log(`[PushNow] Dispatching Daily Sales Summary to device...`);
    console.log(`[PushNow] Title: "${title}"`);
    console.log(`[PushNow] Message: "${message}"`);

    // Create notification in DB
    const notification = await notificationService.createNotification({
      userId: user._id,
      businessId: bId,
      type: 'daily_sales_summary',
      title,
      message,
      entityType: 'sales_report',
      entityId: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`,
      metadata: {
        businessName: business?.name || 'Apna POS',
        date: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`,
        formattedDate,
        totalSales,
        yesterdaySales: Math.round(totalSales * 0.88),
        percentageChange: 12,
        isHigher: true,
        revenue: totalSales,
        ordersCount: orderCount,
        avgOrderValue,
      },
      sendPush: false, // We will manually push below to ensure delivery log
    });

    console.log(`[PushNow] ✅ Created Notification record in DB: ${notification._id}`);

    // Directly invoke pushNotificationService with explicit token, data payload and BigPicture banner imageUrl
    const pushResult = await pushNotificationService.sendPushNotification({
      token: user.pushToken,
      userId: user._id.toString(),
      businessId: bId.toString(),
      title,
      message,
      imageUrl: bannerUrl,
      data: {
        notificationId: notification._id.toString(),
        type: 'daily_sales_summary',
        entityType: 'sales_report',
        imageUrl: bannerUrl,
        image: bannerUrl,
        entityId: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`,
        notificationTag: 'daily_sales_summary',
        businessName: business?.name || 'Apna POS',
        date: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`,
        formattedDate,
        totalSales: String(totalSales),
        yesterdaySales: String(Math.round(totalSales * 0.88)),
        percentageChange: '12',
        isHigher: 'true',
        revenue: String(totalSales),
        ordersCount: String(orderCount),
        avgOrderValue: String(avgOrderValue),
      },
    });

    console.log(`[PushNow] ✅ Push dispatched with result:`, pushResult);
    await mongoose.disconnect();
    console.log('[PushNow] Completed.');
    process.exit(0);
  } catch (err) {
    console.error('[PushNow] Error:', err);
    process.exit(1);
  }
}

pushNow();
