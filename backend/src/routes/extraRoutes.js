const express = require('express');
const extraController = require('../controllers/extraController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/', (req, res, next) => extraController.getExtras(req, res, next));
router.post('/validate-coupon', (req, res, next) => extraController.validateCoupon(req, res, next));
router.post('/', (req, res, next) => extraController.createExtra(req, res, next));
router.patch('/:id', (req, res, next) => extraController.updateExtra(req, res, next));
router.delete('/:id', (req, res, next) => extraController.deleteExtra(req, res, next));

module.exports = router;
