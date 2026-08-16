const express = require('express');
const inventoryController = require('../controllers/inventoryController');
const authMiddleware = require('../middleware/authMiddleware');
const validate = require('../middleware/validationMiddleware');
const {
  createInventorySchema,
  updateInventorySchema,
} = require('../validators/inventoryValidator');

const router = express.Router();

router.use(authMiddleware);

router.get('/', (req, res, next) => inventoryController.getInventory(req, res, next));
router.post('/', validate(createInventorySchema), (req, res, next) =>
  inventoryController.createItem(req, res, next)
);
router.put('/:id', validate(updateInventorySchema), (req, res, next) =>
  inventoryController.updateItem(req, res, next)
);
router.delete('/:id', (req, res, next) => inventoryController.deleteItem(req, res, next));

module.exports = router;
