const mongoose = require('mongoose');
const Business = require('../models/Business');
const Order = require('../models/Order');
const Sale = require('../models/Sale');
const notificationService = require('./notificationService');

class CronService {
  constructor() {
    this._intervalId = null;
  }

  /**
   * Helper to format a date to '27 Aug 2026' or '27 Aug'
   */
  _formatDisplayDate(date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const d = date.getDate();
    const m = months[date.getMonth()];
    return `${d} ${m}`;
  }

  /**
   * Calculate daily sales summary for a given business and date
   */
  async generateDailySummaryForBusiness(business, targetDate = null) {
    try {
      if (!business || !business._id) return null;
      const bId = business._id;
      const timezone = business.business?.timezone || 'Asia/Kolkata';

      // Default target date is yesterday
      const now = new Date();
      let refDate = targetDate ? new Date(targetDate) : new Date(now.getTime() - 24 * 60 * 60 * 1000);

      // Start of target day 00:00:00.000 to 23:59:59.999
      const startOfDay = new Date(refDate.getFullYear(), refDate.getMonth(), refDate.getDate(), 0, 0, 0, 0);
      const endOfDay = new Date(refDate.getFullYear(), refDate.getMonth(), refDate.getDate(), 23, 59, 59, 999);

      const dateStr = `${startOfDay.getFullYear()}-${String(startOfDay.getMonth() + 1).padStart(2, '0')}-${String(startOfDay.getDate()).padStart(2, '0')}`;
      const formattedDate = this._formatDisplayDate(startOfDay);

      const idempotencyKey = `daily_summary_${bId.toString()}_${dateStr}`;

      // Aggregate completed sales for this date
      const bIdObj = mongoose.Types.ObjectId.isValid(bId) ? new mongoose.Types.ObjectId(bId) : bId;
      const matchQuery = {
        businessId: { $in: [bIdObj, bId.toString()] },
        createdAt: { $gte: startOfDay, $lte: endOfDay },
        status: { $nin: ['cancelled', 'void'] },
        $or: [
          { status: { $in: ['completed', 'paid'] } },
          { paymentStatus: 'paid' },
          { isPaid: true },
        ],
      };

      const orders = await Order.find(matchQuery).sort({ createdAt: -1 }).lean();
      const orderCount = orders.length;

      let totalSales = 0;
      let revenue = 0;
      const orderBreakdown = [];

      for (const ord of orders) {
        const amt = Number(ord.totalAmount) || 0;
        totalSales += amt;
        revenue += amt;
        orderBreakdown.push({
          id: ord._id ? ord._id.toString() : ord.id,
          orderNumber: ord.orderNumber || 'POS',
          totalAmount: amt,
          orderType: ord.orderType || 'Dine-In',
          paymentMethod: ord.paymentMethod || 'Cash',
          createdAt: ord.createdAt,
          customerName: ord.customerName || '',
          customerPhone: ord.customerPhone || '',
          itemsCount: Array.isArray(ord.items) ? ord.items.length : 1,
        });
      }

      totalSales = Math.round(totalSales * 100) / 100;
      revenue = Math.round(revenue * 100) / 100;

      // Construct dynamic message
      let message = '';
      if (orderCount > 0) {
        message = `Here’s your business summary for ${formattedDate}: Total Sales ₹${totalSales.toLocaleString('en-IN')} from ${orderCount} order${orderCount > 1 ? 's' : ''}, with revenue of ₹${revenue.toLocaleString('en-IN')}. Tap to view your complete sales report.`;
      } else {
        message = `Your daily business summary for ${formattedDate} is ready. No orders were recorded today. Tap to view your sales report.`;
      }

      const notification = await notificationService.createNotification({
        userId: business.ownerId,
        businessId: bId,
        type: 'daily_sales_summary',
        title: 'Your Daily Business Summary 📊',
        message,
        entityType: 'sales_report',
        entityId: dateStr,
        metadata: {
          date: dateStr,
          formattedDate,
          totalSales,
          revenue,
          ordersCount: orderCount,
          timezone,
          orders: orderBreakdown,
        },
        idempotencyKey,
      });

      // Dispatch push notification
      const pushNotificationService = require('./pushNotificationService');
      pushNotificationService.sendPushNotification({
        userId: business.ownerId,
        title: 'Your Daily Business Summary 📊',
        message,
        data: {
          type: 'daily_sales_summary',
          date: dateStr,
          totalSales,
          ordersCount: orderCount,
          orders: orderBreakdown,
        },
      }).catch(() => {});

      return notification;
    } catch (error) {
      console.error(`[CronService] Error generating summary for business ${business._id}: ${error.message}`);
      return null;
    }
  }

  /**
   * Run daily summary job for all active businesses
   */
  async runDailySummaryJob() {
    try {
      console.log('[CronService] Running Daily Sales Summary Job...');
      const businesses = await Business.find({}).lean();
      for (const business of businesses) {
        await this.generateDailySummaryForBusiness(business);
      }
      console.log(`[CronService] Daily Sales Summary Job finished for ${businesses.length} businesses.`);
    } catch (error) {
      console.error(`[CronService] Error in runDailySummaryJob: ${error.message}`);
    }
  }

  /**
   * Initialize server-side scheduler
   */
  initSchedulers() {
    // Check every minute for midnight 00:00 trigger
    let lastRunDate = '';

    this._intervalId = setInterval(async () => {
      const now = new Date();
      const currentHour = now.getHours();
      const currentMinute = now.getMinutes();
      const todayStr = `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;

      // Run once at 00:00 (12:00 AM midnight)
      if (currentHour === 0 && currentMinute === 0 && lastRunDate !== todayStr) {
        lastRunDate = todayStr;
        await this.runDailySummaryJob();
      }
    }, 60000);

    console.log('[CronService] Schedulers initialized (Daily Midnight 12:00 AM summary active)');
  }

  stopSchedulers() {
    if (this._intervalId) {
      clearInterval(this._intervalId);
      this._intervalId = null;
    }
  }
}

module.exports = new CronService();
