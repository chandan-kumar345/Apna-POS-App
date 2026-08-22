const express = require('express');
const customerController = require('../controllers/customerController');
const authMiddleware = require('../middleware/authMiddleware');
const validate = require('../middleware/validationMiddleware');
const {
  createCustomerSchema,
  updateCustomerSchema,
} = require('../validators/customerValidator');

const router = express.Router();

router.use(authMiddleware);

router.get('/', (req, res, next) => customerController.getCustomers(req, res, next));
router.get('/suggest', (req, res, next) => customerController.getSuggestions(req, res, next));
router.post('/', validate(createCustomerSchema), (req, res, next) =>
  customerController.createOrUpdate(req, res, next)
);
router.get('/phone/:phone', (req, res, next) =>
  customerController.getByPhone(req, res, next)
);

module.exports = router;

