const Product = require('../models/Product');
const Category = require('../models/Category');
const ApiError = require('../utils/ApiError');

class ProductService {
  async getProducts(businessId, { page = 1, limit = 100, category, search, isAvailable } = {}) {
    const query = { businessId };

    if (category && category !== 'All') {
      query.category = category;
    }

    if (isAvailable !== undefined) {
      query.isAvailable = isAvailable === 'true' || isAvailable === true;
    }

    if (search && search.trim()) {
      const regex = new RegExp(search.trim(), 'i');
      query.$or = [{ name: regex }, { description: regex }, { category: regex }];
    }

    const skip = (Math.max(1, parseInt(page, 10)) - 1) * Math.max(1, parseInt(limit, 10));
    const parsedLimit = Math.max(1, parseInt(limit, 10));

    const [products, total] = await Promise.all([
      Product.find(query).sort({ createdAt: -1 }).skip(skip).limit(parsedLimit),
      Product.countDocuments(query),
    ]);

    return {
      products,
      pagination: {
        total,
        page: parseInt(page, 10),
        limit: parsedLimit,
        totalPages: Math.ceil(total / parsedLimit),
      },
    };
  }

  async createProduct(businessId, data) {
    const product = await Product.create({
      ...data,
      businessId,
    });

    // Auto-create category if doesn't exist
    if (data.category) {
      await Category.findOneAndUpdate(
        { businessId, name: data.category.trim() },
        { $setOnInsert: { businessId, name: data.category.trim() } },
        { upsert: true, new: true }
      );
    }

    return product;
  }

  async getProductById(businessId, productId) {
    const product = await Product.findOne({ _id: productId, businessId });
    if (!product) {
      throw ApiError.notFound('Product not found or does not belong to this business');
    }
    return product;
  }

  async updateProduct(businessId, productId, data) {
    const product = await Product.findOneAndUpdate(
      { _id: productId, businessId },
      { $set: data },
      { new: true, runValidators: true }
    );

    if (!product) {
      throw ApiError.notFound('Product not found or does not belong to this business');
    }

    if (data.category) {
      await Category.findOneAndUpdate(
        { businessId, name: data.category.trim() },
        { $setOnInsert: { businessId, name: data.category.trim() } },
        { upsert: true, new: true }
      );
    }

    return product;
  }

  async deleteProduct(businessId, productId) {
    const product = await Product.findOneAndDelete({ _id: productId, businessId });
    if (!product) {
      throw ApiError.notFound('Product not found or does not belong to this business');
    }
    return { id: productId, message: 'Product deleted successfully' };
  }

  async getCategories(businessId) {
    const categories = await Category.find({ businessId }).sort({ sortOrder: 1, name: 1 });
    // Also pull distinct categories directly from products for fallback sync
    const productCategories = await Product.distinct('category', { businessId });
    const existingNames = new Set(categories.map((c) => c.name));

    for (const catName of productCategories) {
      if (catName && !existingNames.has(catName)) {
        const newCat = await Category.create({ businessId, name: catName });
        categories.push(newCat);
      }
    }

    return categories;
  }

  async createCategory(businessId, { name, icon, color, sortOrder }) {
    const trimmed = name.trim();
    const existing = await Category.findOne({ businessId, name: trimmed });
    if (existing) {
      throw ApiError.conflict(`Category '${trimmed}' already exists`);
    }
    return Category.create({ businessId, name: trimmed, icon, color, sortOrder });
  }

  async deleteCategory(businessId, name) {
    const trimmed = name.trim();
    const result = await Category.findOneAndDelete({ businessId, name: trimmed });
    if (!result) {
      throw ApiError.notFound(`Category '${trimmed}' not found`);
    }
    return { name: trimmed, message: 'Category removed' };
  }

  async bulkImportProducts(businessId, items) {
    if (!Array.isArray(items) || items.length === 0) {
      throw ApiError.badRequest('Items array is required for bulk import');
    }

    const docs = items.map((item) => ({
      businessId,
      name: item.name,
      description: item.description || '',
      category: item.category || 'General',
      price: parseFloat(item.price) || 0,
      salePrice: parseFloat(item.salePrice) || 0,
      foodType: ['veg', 'non_veg', 'egg'].includes(item.foodType) ? item.foodType : 'veg',
      isAvailable: item.isAvailable !== false,
      stock: item.stock !== undefined ? parseInt(item.stock, 10) : -1,
      sku: item.sku || '',
      taxPercentage: parseFloat(item.taxPercentage) || 5,
    }));

    const inserted = await Product.insertMany(docs);

    // Sync categories
    const distinctCategories = [...new Set(docs.map((d) => d.category))];
    for (const cat of distinctCategories) {
      await Category.findOneAndUpdate(
        { businessId, name: cat },
        { $setOnInsert: { businessId, name: cat } },
        { upsert: true }
      );
    }

    return { importedCount: inserted.length, products: inserted };
  }
}

module.exports = new ProductService();
