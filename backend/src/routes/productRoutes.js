const express = require('express');
const productController = require('../controllers/productController');
const authMiddleware = require('../middleware/authMiddleware');
const validate = require('../middleware/validationMiddleware');
const {
  createProductSchema,
  updateProductSchema,
  categorySchema,
  updateCategorySchema,
} = require('../validators/productValidator');

const router = express.Router();

// All product routes require authentication
router.use(authMiddleware);

// Categories
router.get('/categories', (req, res, next) => productController.getCategories(req, res, next));
router.post('/categories', validate(categorySchema), (req, res, next) =>
  productController.createCategory(req, res, next)
);
router.put('/categories/:name', validate(updateCategorySchema), (req, res, next) =>
  productController.updateCategory(req, res, next)
);
router.delete('/categories/:name', (req, res, next) =>
  productController.deleteCategory(req, res, next)
);

// Products
router.get('/', (req, res, next) => productController.getProducts(req, res, next));
router.post('/', validate(createProductSchema), (req, res, next) =>
  productController.createProduct(req, res, next)
);
router.post('/bulk', (req, res, next) => productController.bulkImport(req, res, next));
router.get('/:id', (req, res, next) => productController.getProductById(req, res, next));
router.put('/:id', validate(updateProductSchema), (req, res, next) =>
  productController.updateProduct(req, res, next)
);
router.patch('/:id', validate(updateProductSchema), (req, res, next) =>
  productController.updateProduct(req, res, next)
);
router.delete('/:id', (req, res, next) => productController.deleteProduct(req, res, next));

module.exports = router;
