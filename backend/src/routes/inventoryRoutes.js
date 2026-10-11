const express = require('express');
const inventoryController = require('../controllers/inventoryController');
const authMiddleware = require('../middleware/authMiddleware');
const { requirePermission } = require('../middleware/permissionMiddleware');

const router = express.Router();

router.use(authMiddleware);
router.use(requirePermission('inventory', 'inventory_view', 'inventory_adjust'));

// Dashboard Summary & Analytics
router.get('/dashboard-summary', (req, res, next) =>
  inventoryController.getDashboardSummary(req, res, next)
);

// Reports
router.get('/reports/stock', (req, res, next) =>
  inventoryController.getStockReport(req, res, next)
);
router.get('/reports/movements', (req, res, next) =>
  inventoryController.getMovementsLedger(req, res, next)
);
router.get('/reports/product-analytics', (req, res, next) =>
  inventoryController.getProductAnalytics(req, res, next)
);
router.get('/reports/closing-summary', (req, res, next) =>
  inventoryController.getClosingStockSummary(req, res, next)
);

// Raw Materials
router.get('/raw-materials', (req, res, next) =>
  inventoryController.getRawMaterials(req, res, next)
);
router.post('/raw-materials', (req, res, next) =>
  inventoryController.createRawMaterial(req, res, next)
);
router.get('/raw-materials/:id', (req, res, next) =>
  inventoryController.getRawMaterialById(req, res, next)
);
router.put('/raw-materials/:id', (req, res, next) =>
  inventoryController.updateRawMaterial(req, res, next)
);
router.delete('/raw-materials/:id', (req, res, next) =>
  inventoryController.archiveRawMaterial(req, res, next)
);
router.get('/raw-materials/:id/movements', (req, res, next) =>
  inventoryController.getMaterialMovements(req, res, next)
);

// Recipes
router.get('/recipes', (req, res, next) =>
  inventoryController.getRecipes(req, res, next)
);
router.post('/recipes', (req, res, next) =>
  inventoryController.createRecipe(req, res, next)
);
router.get('/recipes/:id', (req, res, next) =>
  inventoryController.getRecipeById(req, res, next)
);
router.put('/recipes/:id', (req, res, next) =>
  inventoryController.updateRecipe(req, res, next)
);
router.delete('/recipes/:id', (req, res, next) =>
  inventoryController.deleteRecipe(req, res, next)
);

// Stock Operations (Mode B & manual entries)
router.post('/opening-stock', (req, res, next) =>
  inventoryController.recordOpeningStock(req, res, next)
);
router.post('/stock-in', (req, res, next) =>
  inventoryController.recordStockIn(req, res, next)
);
router.post('/stock-out', (req, res, next) =>
  inventoryController.recordStockOut(req, res, next)
);
router.post('/stock-count', (req, res, next) =>
  inventoryController.recordPhysicalStockCount(req, res, next)
);

// Legacy routes for existing simple inventory model
router.get('/', (req, res, next) => inventoryController.getInventory(req, res, next));
router.post('/', (req, res, next) => inventoryController.createItem(req, res, next));
router.put('/:id', (req, res, next) => inventoryController.updateItem(req, res, next));
router.delete('/:id', (req, res, next) => inventoryController.deleteItem(req, res, next));

module.exports = router;
