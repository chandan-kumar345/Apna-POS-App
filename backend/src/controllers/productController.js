const productService = require('../services/productService');
const ApiResponse = require('../utils/ApiResponse');

class ProductController {
  async getPosProducts(req, res, next) {
    try {
      const result = await productService.getPosProducts(req.businessId, req.query);
      return ApiResponse.success(res, result, 'POS Products fetched successfully');
    } catch (error) {
      next(error);
    }
  }

  async getProducts(req, res, next) {
    try {
      const result = await productService.getProducts(req.businessId, req.query);
      return ApiResponse.success(res, result, 'Products fetched successfully');
    } catch (error) {
      next(error);
    }
  }

  async createProduct(req, res, next) {
    try {
      const product = await productService.createProduct(req.businessId, req.body);
      return ApiResponse.created(res, { product }, 'Product created successfully');
    } catch (error) {
      next(error);
    }
  }

  async getProductById(req, res, next) {
    try {
      const product = await productService.getProductById(req.businessId, req.params.id);
      return ApiResponse.success(res, { product });
    } catch (error) {
      next(error);
    }
  }

  async updateProduct(req, res, next) {
    try {
      const product = await productService.updateProduct(req.businessId, req.params.id, req.body);
      return ApiResponse.success(res, { product }, 'Product updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async deleteProduct(req, res, next) {
    try {
      const result = await productService.deleteProduct(req.businessId, req.params.id);
      return ApiResponse.success(res, result, 'Product deleted successfully');
    } catch (error) {
      next(error);
    }
  }

  async getCategories(req, res, next) {
    try {
      const categories = await productService.getCategories(req.businessId);
      return ApiResponse.success(res, { categories });
    } catch (error) {
      next(error);
    }
  }

  async createCategory(req, res, next) {
    try {
      const category = await productService.createCategory(req.businessId, req.body);
      return ApiResponse.created(res, { category }, 'Category created successfully');
    } catch (error) {
      next(error);
    }
  }

  async updateCategory(req, res, next) {
    try {
      const category = await productService.updateCategory(req.businessId, req.params.name, req.body);
      return ApiResponse.success(res, { category }, 'Category updated successfully');
    } catch (error) {
      next(error);
    }
  }

  async deleteCategory(req, res, next) {
    try {
      const result = await productService.deleteCategory(req.businessId, req.params.name);
      return ApiResponse.success(res, result, 'Category deleted successfully');
    } catch (error) {
      next(error);
    }
  }

  async bulkImport(req, res, next) {
    try {
      const items = Array.isArray(req.body) ? req.body : (req.body.items || req.body.products || []);
      const result = await productService.bulkImportProducts(req.businessId, items);
      return ApiResponse.success(res, result, `${result.importedCount} products imported successfully`);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ProductController();
