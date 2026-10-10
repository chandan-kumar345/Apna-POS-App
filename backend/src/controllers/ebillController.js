const ebillService = require('../services/ebillService');
const ApiResponse = require('../utils/ApiResponse');

class EbillController {
  /**
   * GET /api/v1/ebill/eligibility?billId=BILL_ID
   */
  async getEligibility(req, res, next) {
    try {
      const billId = req.query.billId || req.query.orderId || req.query.id;
      const result = await ebillService.checkEligibility(req.businessId, billId);
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
      const idempotencyKey =
        req.headers['idempotency-key'] ||
        req.body.idempotencyKey ||
        `ebill_${req.businessId}_${billId}`;

      const result = await ebillService.sendEbill({
        businessId: req.businessId,
        billId: billId || req.body.orderId,
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
