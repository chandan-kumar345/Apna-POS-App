const ebillService = require('../services/ebillService');
const ApiResponse = require('../utils/ApiResponse');

class EbillController {
  /**
   * GET /api/v1/ebill/eligibility?billId=BILL_ID
   */
  async getEligibility(req, res, next) {
    try {
      const billId = req.query.billId || req.query.orderId || req.query.id;
      let bId = req.businessId;
      if (!bId && billId) {
        const Order = require('../models/Order');
        const mongoose = require('mongoose');
        let order = null;
        if (mongoose.Types.ObjectId.isValid(billId)) {
          order = await Order.findById(billId);
        }
        if (!order) {
          order = await Order.findOne({ orderNumber: billId });
        }
        if (order) bId = order.businessId;
      }
      const result = await ebillService.checkEligibility(bId, billId);
      return res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/ebill/send
   * Header: Idempotency-Key
   * Body: { billId, customerId?, customerPhone? }
   */
  async sendEbill(req, res, next) {
    try {
      const { billId, customerId, customerPhone } = req.body;
      const targetBillId = billId || req.body.orderId;
      let bId = req.businessId;
      if (!bId && targetBillId) {
        const Order = require('../models/Order');
        const mongoose = require('mongoose');
        let order = null;
        if (mongoose.Types.ObjectId.isValid(targetBillId)) {
          order = await Order.findById(targetBillId);
        }
        if (!order) {
          order = await Order.findOne({ orderNumber: targetBillId });
        }
        if (order) bId = order.businessId;
      }

      const idempotencyKey =
        req.headers['idempotency-key'] ||
        req.body.idempotencyKey ||
        `ebill_${bId}_${targetBillId}`;

      const result = await ebillService.sendEbill({
        businessId: bId,
        userId: req.user?._id || req.user?.id,
        billId: targetBillId,
        customerId,
        idempotencyKey,
        customerPhoneOverride: customerPhone,
      });

      return ApiResponse.success(res, result.data, result.message);
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/ebill/:ebillId/status
   */
  async getEbillStatus(req, res, next) {
    try {
      const { ebillId } = req.params;
      const statusData = await ebillService.getEbillStatus(req.businessId, ebillId);
      return ApiResponse.success(res, statusData, 'eBill status retrieved');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new EbillController();
