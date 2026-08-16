const inventoryService = require('../services/inventoryService');
const ApiResponse = require('../utils/ApiResponse');

class InventoryController {
  async getInventory(req, res, next) {
    try {
      const items = await inventoryService.getInventory(req.businessId, req.query);
      return ApiResponse.success(res, { items });
    } catch (error) {
      next(error);
    }
  }

  async createItem(req, res, next) {
    try {
      const item = await inventoryService.createInventoryItem(req.businessId, req.body);
      return ApiResponse.created(res, { item }, 'Item added to inventory');
    } catch (error) {
      next(error);
    }
  }

  async updateItem(req, res, next) {
    try {
      const item = await inventoryService.updateInventoryItem(req.businessId, req.params.id, req.body);
      return ApiResponse.success(res, { item }, 'Item updated');
    } catch (error) {
      next(error);
    }
  }

  async deleteItem(req, res, next) {
    try {
      const result = await inventoryService.deleteInventoryItem(req.businessId, req.params.id);
      return ApiResponse.success(res, result, 'Item deleted');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new InventoryController();
