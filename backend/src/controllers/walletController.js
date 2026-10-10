const walletService = require('../services/walletService');
const ApiResponse = require('../utils/ApiResponse');

class WalletController {
  /**
   * GET /api/v1/wallet/balance
   */
  async getBalance(req, res, next) {
    try {
      const eligibility = await walletService.checkEligibility(req.businessId);
      return ApiResponse.success(res, eligibility, 'Wallet balance retrieved');
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/wallet/recharge
   * Body: { amount, referenceId, description }
   */
  async recharge(req, res, next) {
    try {
      const { amount, referenceId, description } = req.body;
      const result = await walletService.rechargeWallet({
        businessId: req.businessId,
        amount,
        referenceId,
        description,
      });
      return ApiResponse.success(res, result, 'Wallet recharged successfully');
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/wallet/transactions
   */
  async getTransactions(req, res, next) {
    try {
      const page = req.query.page || 1;
      const limit = req.query.limit || 20;
      const result = await walletService.getTransactions(req.businessId, { page, limit });
      return ApiResponse.success(res, result, 'Transactions fetched');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new WalletController();
