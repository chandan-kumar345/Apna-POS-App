const mongoose = require('mongoose');
const Business = require('../models/Business');
const Order = require('../models/Order');
const Sale = require('../models/Sale');
const User = require('../models/User');
const Campaign = require('../models/Campaign');
const notificationService = require('./notificationService');
const campaignService = require('./campaignService');

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
      const avgOrderValue = orderCount > 0 ? Math.round(totalSales / orderCount) : 0;
      const formattedSales = `₹${totalSales.toLocaleString('en-IN')}`;
      const formattedAvg = `₹${avgOrderValue.toLocaleString('en-IN')}`;

      // Construct dynamic message
      let message = '';
      if (orderCount > 0) {
        message = `🟢 Total Sales: ${formattedSales}  •  🔵 Total Orders: ${orderCount}  •  🟠 Avg Order Value: ${formattedAvg}`;
      } else {
        message = `Your daily business summary for ${formattedDate} is ready. No orders were recorded today. Tap to view sales report.`;
      }

      const title = `Daily Sales Summary 📊 • ${formattedDate}`;

      const notification = await notificationService.createNotification({
        userId: business.ownerId,
        businessId: bId,
        type: 'daily_sales_summary',
        title,
        message,
        entityType: 'sales_report',
        entityId: dateStr,
        metadata: {
          date: dateStr,
          formattedDate,
          totalSales,
          revenue,
          ordersCount: orderCount,
          avgOrderValue,
          timezone,
          orders: orderBreakdown,
        },
        idempotencyKey,
      });

      // Dispatch push notification
      const pushNotificationService = require('./pushNotificationService');
      pushNotificationService.sendPushNotification({
        userId: business.ownerId,
        title,
        message,
        data: {
          type: 'daily_sales_summary',
          date: dateStr,
          totalSales,
          ordersCount: orderCount,
          avgOrderValue,
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
   * Check for subscriptions expiring within 2 days (48 hours)
   * Dispatches push notification mentioning the exact date & time.
   */
  async checkExpiringSubscriptionsJob() {
    try {
      const now = new Date();
      const twoDaysFromNow = new Date(now.getTime() + 48 * 60 * 60 * 1000);

      // Find users with active subscriptions expiring in <= 48h and > now
      const expiringUsers = await User.find({
        $or: [
          { 'subscription.isActive': true },
          { 'subscription.isSubscriptionActive': true },
          { 'subscription.status': 'active' },
        ],
        'subscription.expiresAt': { $gt: now, $lte: twoDaysFromNow },
      }).lean();

      for (const user of expiringUsers) {
        if (!user.subscription?.expiresAt) continue;
        const expiry = new Date(user.subscription.expiresAt);

        // Format date and time (e.g., "13 Oct 2026 at 08:30 PM")
        const formattedDate = expiry.toLocaleDateString('en-IN', {
          day: 'numeric',
          month: 'short',
          year: 'numeric',
        });
        const formattedTime = expiry.toLocaleTimeString('en-IN', {
          hour: '2-digit',
          minute: '2-digit',
          hour12: true,
        });
        const formattedDateTime = `${formattedDate} at ${formattedTime}`;

        const dateKey = `${expiry.getFullYear()}-${expiry.getMonth() + 1}-${expiry.getDate()}`;
        const idempotencyKey = `sub_expiring_2days_${user._id.toString()}_${dateKey}`;

        const title = 'Your subscription will end soon ⏳';
        const message = `Your Apna POS subscription will end on ${formattedDateTime}. Please renew your plan to continue using all features.`;

        await notificationService.createNotification({
          userId: user._id,
          businessId: user.businessId,
          type: 'system',
          title,
          message,
          entityType: 'subscription',
          entityId: user._id.toString(),
          metadata: {
            expiresAt: expiry.toISOString(),
            formattedDateTime,
            plan: user.subscription?.plan || 'starter',
          },
          sendPush: true,
          idempotencyKey,
        });
      }
    } catch (error) {
      console.error(`[CronService] Error in checkExpiringSubscriptionsJob: ${error.message}`);
    }
  }

  /**
   * Process scheduled campaigns that have reached their delivery time
   * Employs atomic locking (findOneAndUpdate { status: 'scheduled' } -> { status: 'processing' })
   * to guarantee zero duplicate executions across cluster workers or intervals.
   */
  async processScheduledCampaignsJob() {
    try {
      const now = new Date();

      // Find campaigns due for delivery
      const dueCampaigns = await Campaign.find({
        status: 'scheduled',
        $or: [
          {
            'couponSettings.hasSendSchedule': true,
            'couponSettings.scheduledAt': { $exists: true, $ne: null, $lte: now },
          },
          {
            'couponSettings.hasSendSchedule': { $ne: true },
            'schedule.scheduledAt': { $exists: true, $ne: null, $lte: now },
          },
        ],
      }).select('_id name businessId couponSettings scheduledAt').lean();

      if (!dueCampaigns || dueCampaigns.length === 0) return;

      console.log(`[CronService] Found ${dueCampaigns.length} scheduled campaign(s) due for dispatch.`);

      for (const camp of dueCampaigns) {
        // Atomic lock: Only the worker that successfully transitions status executes the dispatch
        const locked = await Campaign.findOneAndUpdate(
          { _id: camp._id, status: 'scheduled' },
          {
            status: 'processing',
            $push: {
              executionLogs: {
                timestamp: new Date(),
                status: 'processing',
                message: 'Scheduler locked campaign for background dispatch',
                executedBy: 'cron_scheduler',
              },
            },
          },
          { new: true }
        );

        if (!locked) {
          // Another concurrent worker/trigger has already claimed this campaign
          continue;
        }

        try {
          await campaignService.executeScheduledCampaign(camp._id);
          console.log(`[CronService] Scheduled campaign "${camp.name}" (${camp._id}) executed successfully.`);
        } catch (execErr) {
          console.error(`[CronService] Failed executing scheduled campaign ${camp._id}:`, execErr.message);
        }
      }
    } catch (err) {
      console.error('[CronService] Error in processScheduledCampaignsJob:', err.message);
    }
  }

  /**
   * Recover stuck processing campaigns upon server restart / failover
   */
  async recoverStuckCampaignsJob() {
    try {
      const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000);
      const stuck = await Campaign.find({
        status: 'processing',
        updatedAt: { $lt: fifteenMinutesAgo },
      });

      for (const c of stuck) {
        c.status = 'scheduled';
        c.executionLogs.push({
          timestamp: new Date(),
          status: 'scheduled',
          message: 'Recovered stuck processing state on server restart; returned to scheduled queue',
          executedBy: 'server_recovery',
        });
        await c.save();
        console.log(`[CronService] Recovered stuck campaign "${c.name}" (${c._id}).`);
      }
    } catch (e) {
      console.error('[CronService] Error recovering stuck campaigns:', e.message);
    }
  }

  /**
   * Initialize server-side scheduler
   */
  initSchedulers() {
    // Check every minute for midnight 00:00 trigger, scheduled campaigns & hourly subscription check
    let lastRunDate = '';
    let lastHourlyCheck = 0;

    this._intervalId = setInterval(async () => {
      const now = new Date();
      const currentHour = now.getHours();
      const currentMinute = now.getMinutes();
      const todayStr = `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;

      // Check and execute scheduled campaigns every minute
      await this.processScheduledCampaignsJob();

      // Run once at 00:00 (12:00 AM midnight)
      if (currentHour === 0 && currentMinute === 0 && lastRunDate !== todayStr) {
        lastRunDate = todayStr;
        await this.runDailySummaryJob();
      }

      // Check subscription expiries every 60 minutes
      if (Date.now() - lastHourlyCheck > 60 * 60 * 1000) {
        lastHourlyCheck = Date.now();
        await this.checkExpiringSubscriptionsJob();
      }
    }, 60000);

    // Initial check on startup
    setTimeout(() => {
      this.recoverStuckCampaignsJob().catch(() => {});
      this.processScheduledCampaignsJob().catch(() => {});
      this.checkExpiringSubscriptionsJob().catch(() => {});
    }, 10000);

    console.log('[CronService] Schedulers initialized (Campaign Dispatcher, Daily Midnight summary & Hourly 2-day subscription alerts active)');
  }

  stopSchedulers() {
    if (this._intervalId) {
      clearInterval(this._intervalId);
      this._intervalId = null;
    }
  }
}

module.exports = new CronService();
