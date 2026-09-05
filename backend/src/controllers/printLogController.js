const printLogService = require('../services/printLogService');
const ApiResponse = require('../utils/ApiResponse');

class PrintLogController {
  async getPrintLogs(req, res, next) {
    try {
      const result = await printLogService.getPrintLogs(req.businessId, req.query);
      return ApiResponse.success(res, result, 'Print logs fetched successfully');
    } catch (error) {
      next(error);
    }
  }

  async getPrintLogById(req, res, next) {
    try {
      const printLog = await printLogService.getPrintLogById(req.businessId, req.params.id);
      return ApiResponse.success(res, { printLog });
    } catch (error) {
      next(error);
    }
  }

  async reprintLog(req, res, next) {
    try {
      const printLog = await printLogService.reprintLog(req.businessId, req.params.id, {
        printedBy: req.user?.name || req.body.printedBy || '',
      });
      return ApiResponse.success(res, { printLog }, 'Reprint recorded successfully');
    } catch (error) {
      next(error);
    }
  }

  async createPrintLog(req, res, next) {
    try {
      const printLog = await printLogService.createPrintLog(req.businessId, {
        ...req.body,
        printedBy: req.user?.name || req.body.printedBy || '',
      });
      return ApiResponse.created(res, { printLog }, 'Print log created successfully');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new PrintLogController();
