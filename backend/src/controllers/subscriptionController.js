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
}

module.exports = new SubscriptionController();
