const tableService = require('../services/tableService');
const ApiResponse = require('../utils/ApiResponse');

class TableController {
  async getTables(req, res, next) {
    try {
      const tables = await tableService.getTables(req.businessId);
      return ApiResponse.success(res, { tables });
    } catch (error) {
      next(error);
    }
  }

  async createTable(req, res, next) {
    try {
      const table = await tableService.createTable(req.businessId, req.body);
      const tables = Array.isArray(table) ? table : [table];
      return ApiResponse.created(res, { table, tables }, 'Table created');
    } catch (error) {
      next(error);
    }
  }

  async updateTable(req, res, next) {
    try {
      const table = await tableService.updateTable(req.businessId, req.params.id, req.body);
      return ApiResponse.success(res, { table }, 'Table updated');
    } catch (error) {
      next(error);
    }
  }

  async updateStatus(req, res, next) {
    try {
      const table = await tableService.updateTableStatus(req.businessId, req.params.id, req.body);
      return ApiResponse.success(res, { table }, 'Table status updated');
    } catch (error) {
      next(error);
    }
  }

  async deleteTable(req, res, next) {
    try {
      const result = await tableService.deleteTable(req.businessId, req.params.id);
      return ApiResponse.success(res, result, 'Table removed');
    } catch (error) {
      next(error);
    }
  }

  async shiftTable(req, res, next) {
    try {
      const { sourceTable, targetTable } = req.body;
      if (!sourceTable || !targetTable) {
        return res.status(400).json({
          status: 'fail',
          message: 'Source table and target table are required',
        });
      }
      const result = await tableService.shiftTable(req.businessId, { sourceTable, targetTable });
      return ApiResponse.success(res, result, 'Table shifted successfully');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new TableController();
