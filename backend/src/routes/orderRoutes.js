const express = require('express');
const orderController = require('../controllers/orderController');
const authMiddleware = require('../middleware/authMiddleware');
const validate = require('../middleware/validationMiddleware');
const {
  createOrderSchema,
  generatePosOrderSchema,
  updateOrderStatusSchema,
  payOrderSchema,
} = require('../validators/orderValidator');

const router = express.Router();

router.use(authMiddleware);

router.get('/', (req, res, next) => orderController.getOrders(req, res, next));
router.post('/', validate(createOrderSchema), (req, res, next) =>
  orderController.createOrder(req, res, next)
);
router.post('/generateposorder', validate(generatePosOrderSchema), (req, res, next) =>
  orderController.generatePosOrder(req, res, next)
);
router.post('/generatePosOrder', validate(generatePosOrderSchema), (req, res, next) =>
  orderController.generatePosOrder(req, res, next)
);
router.get('/table/:tableNumber', (req, res, next) =>
  orderController.getTableOrder(req, res, next)
);
router.get('/:id', (req, res, next) => orderController.getOrderById(req, res, next));
router.patch('/:id/status', validate(updateOrderStatusSchema), (req, res, next) =>
  orderController.updateStatus(req, res, next)
);
router.post('/:id/pay', validate(payOrderSchema), (req, res, next) =>
  orderController.payOrder(req, res, next)
);

module.exports = router;
