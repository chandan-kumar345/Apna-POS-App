const subscriptionService = require('../services/subscriptionService');

class SubscriptionController {
  getPlans(req, res, next) {
    try {
      const data = subscriptionService.getPlans();
      res.json({
        success: true,
        data,
      });
    } catch (err) {
      next(err);
    }
  }

  async createLead(req, res, next) {
    try {
      const result = await subscriptionService.createLead(
        req.body,
        req.user || null,
        req.business || null
      );
      res.status(201).json({
        success: true,
        message: result.message,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async getLeads(req, res, next) {
    try {
      const businessId = req.business ? req.business._id : (req.user ? req.user.businessId : null);
      const leads = await subscriptionService.getLeads(businessId);
      res.json({
        success: true,
        data: leads,
      });
    } catch (err) {
      next(err);
    }
  }

  async testEmail(req, res, next) {
    try {
      const emailService = require('../services/emailService');
      const status = await emailService.testConnection();
      res.json({
        success: true,
        data: status,
      });
    } catch (err) {
      next(err);
    }
  }

  async getStatus(req, res, next) {
    try {
      const businessId = req.business ? req.business._id : (req.user ? req.user.businessId : null);
      const userId = req.user ? req.user._id : null;
      const status = await subscriptionService.getStatus(businessId, userId);
      res.json({
        success: true,
        data: status,
      });
    } catch (err) {
      next(err);
    }
  }

  async activateSubscription(req, res, next) {
    try {
      const businessId = req.business ? req.business._id : (req.user ? req.user.businessId : null);
      const userId = req.user ? req.user._id : null;
      const result = await subscriptionService.activateSubscription(businessId, userId, req.body);
      res.json({
        success: true,
        message: 'Subscription unlocked and activated successfully!',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async updateStatus(req, res, next) {
    try {
      const businessId = req.business ? req.business._id : (req.user ? req.user.businessId : null);
      const userId = req.user ? req.user._id : null;
      const result = await subscriptionService.updateStatus(businessId, userId, req.body);
      res.json({
        success: true,
        message: 'Subscription status updated successfully',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async assignStaffSubscription(req, res, next) {
    try {
      const businessId = req.business ? req.business._id : (req.user ? req.user.businessId : null);
      const result = await subscriptionService.assignStaffSubscription({
        businessId,
        ...req.body,
      });
      res.json({
        success: true,
        message: 'Staff subscription updated successfully',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async getAllSubscriptions(req, res, next) {
    try {
      const result = await subscriptionService.getAllSubscriptions(req.query);
      res.json({
        success: true,
        data: result.subscriptions,
        pagination: result.pagination,
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new SubscriptionController();
