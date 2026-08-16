const express = require('express');
const tableController = require('../controllers/tableController');
const authMiddleware = require('../middleware/authMiddleware');
const validate = require('../middleware/validationMiddleware');
const {
  createTableSchema,
  updateTableSchema,
  updateTableStatusSchema,
} = require('../validators/tableValidator');

const router = express.Router();

router.use(authMiddleware);

router.get('/', (req, res, next) => tableController.getTables(req, res, next));
router.post('/', validate(createTableSchema), (req, res, next) =>
  tableController.createTable(req, res, next)
);
router.put('/:id', validate(updateTableSchema), (req, res, next) =>
  tableController.updateTable(req, res, next)
);
router.patch('/:id/status', validate(updateTableStatusSchema), (req, res, next) =>
  tableController.updateStatus(req, res, next)
);
router.delete('/:id', (req, res, next) => tableController.deleteTable(req, res, next));

module.exports = router;
