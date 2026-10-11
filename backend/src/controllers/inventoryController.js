const inventoryService = require('../services/inventoryService');
const ApiResponse = require('../utils/ApiResponse');

class InventoryController {
  // Legacy inventory items
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

  // Raw Materials
  async getRawMaterials(req, res, next) {
    try {
      const materials = await inventoryService.getRawMaterials(req.businessId, req.query);
      return ApiResponse.success(res, { materials });
    } catch (error) {
      next(error);
    }
  }

  async getRawMaterialById(req, res, next) {
    try {
      const material = await inventoryService.getRawMaterialById(req.businessId, req.params.id);
      return ApiResponse.success(res, { material });
    } catch (error) {
      next(error);
    }
  }

  async createRawMaterial(req, res, next) {
    try {
      const material = await inventoryService.createRawMaterial(
        req.businessId,
        req.body,
        req.user?.name || 'Owner'
      );
      return ApiResponse.created(res, { material }, 'Raw material created successfully');
    } catch (error) {
      next(error);
    }
  }

  async updateRawMaterial(req, res, next) {
    try {
      const material = await inventoryService.updateRawMaterial(req.businessId, req.params.id, req.body);
      return ApiResponse.success(res, { material }, 'Raw material updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async archiveRawMaterial(req, res, next) {
    try {
      const result = await inventoryService.archiveRawMaterial(req.businessId, req.params.id);
      return ApiResponse.success(res, result, 'Raw material archived');
    } catch (error) {
      next(error);
    }
  }

  async getMaterialMovements(req, res, next) {
    try {
      const data = await inventoryService.getMaterialMovements(req.businessId, req.params.id, req.query);
      return ApiResponse.success(res, data);
    } catch (error) {
      next(error);
    }
  }

  // Recipes
  async getRecipes(req, res, next) {
    try {
      const recipes = await inventoryService.getRecipes(req.businessId, req.query);
      return ApiResponse.success(res, { recipes });
    } catch (error) {
      next(error);
    }
  }

  async getRecipeById(req, res, next) {
    try {
      const recipe = await inventoryService.getRecipeById(req.businessId, req.params.id);
      return ApiResponse.success(res, { recipe });
    } catch (error) {
      next(error);
    }
  }

  async createRecipe(req, res, next) {
    try {
      const recipe = await inventoryService.createRecipe(req.businessId, req.body);
      return ApiResponse.created(res, { recipe }, 'Recipe created successfully');
    } catch (error) {
      next(error);
    }
  }

  async updateRecipe(req, res, next) {
    try {
      const recipe = await inventoryService.updateRecipe(req.businessId, req.params.id, req.body);
      return ApiResponse.success(res, { recipe }, 'Recipe updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async deleteRecipe(req, res, next) {
    try {
      const result = await inventoryService.deleteRecipe(req.businessId, req.params.id);
      return ApiResponse.success(res, result, 'Recipe deleted');
    } catch (error) {
      next(error);
    }
  }

  // Stock Operations (Mode B & manual entries)
  async recordOpeningStock(req, res, next) {
    try {
      const result = await inventoryService.recordOpeningStock(
        req.businessId,
        req.body,
        req.user?.name || 'Owner'
      );
      return ApiResponse.success(res, { result }, 'Opening stock recorded successfully');
    } catch (error) {
      next(error);
    }
  }

  async recordStockIn(req, res, next) {
    try {
      const receipt = await inventoryService.recordStockIn(
        req.businessId,
        req.body,
        req.user?.name || 'Owner'
      );
      return ApiResponse.created(res, { receipt }, 'Stock-in receipt recorded successfully');
    } catch (error) {
      next(error);
    }
  }

  async recordStockOut(req, res, next) {
    try {
      const result = await inventoryService.recordStockOut(
        req.businessId,
        req.body,
        req.user?.name || 'Owner'
      );
      return ApiResponse.success(res, result, 'Stock-out recorded successfully');
    } catch (error) {
      next(error);
    }
  }

  async recordPhysicalStockCount(req, res, next) {
    try {
      const count = await inventoryService.recordPhysicalStockCount(
        req.businessId,
        req.body,
        req.user?.name || 'Manager'
      );
      return ApiResponse.created(res, { count }, 'Physical stock count saved & adjusted');
    } catch (error) {
      next(error);
    }
  }

  // Dashboard & Reports
  async getDashboardSummary(req, res, next) {
    try {
      const summary = await inventoryService.getDashboardSummary(req.businessId);
      return ApiResponse.success(res, summary);
    } catch (error) {
      next(error);
    }
  }

  async getStockReport(req, res, next) {
    try {
      const data = await inventoryService.getStockReport(req.businessId, req.query);
      return ApiResponse.success(res, data);
    } catch (error) {
      next(error);
    }
  }

  async getMovementsLedger(req, res, next) {
    try {
      const data = await inventoryService.getMovementsLedger(req.businessId, req.query);
      return ApiResponse.success(res, data);
    } catch (error) {
      next(error);
    }
  }

  async getProductAnalytics(req, res, next) {
    try {
      const analytics = await inventoryService.getProductAnalytics(req.businessId);
      return ApiResponse.success(res, { analytics });
    } catch (error) {
      next(error);
    }
  }

  async getClosingStockSummary(req, res, next) {
    try {
      const summary = await inventoryService.getClosingStockSummary(req.businessId, req.query);
      return ApiResponse.success(res, { summary });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new InventoryController();
