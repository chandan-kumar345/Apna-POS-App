const mongoose = require('mongoose');
const Product = require('../models/Product');
const Category = require('../models/Category');
const ApiError = require('../utils/ApiError');

class ProductService {
  _normalizeFoodType(val) {
    if (!val) return 'veg';
    const str = val.toString().toLowerCase().trim().replace('-', '_');
    if (['veg', 'non_veg', 'egg', 'beverage'].includes(str)) {
      return str;
    }
    return 'veg';
  }

  _generateUniqueProductId() {
    const timestamp = Date.now().toString().slice(-6);
    const random = Math.floor(1000 + Math.random() * 9000);
    return `PRD-${timestamp}-${random}`;
  }

  _normalizeProductData(data, isCreate = false) {
    const normalized = {};

    if (data.name !== undefined || data.title !== undefined) {
      normalized.name = (data.name || data.title || '').toString().trim();
    }
    if (data.description !== undefined) {
      normalized.description = data.description.toString().trim();
    }
    if (data.category !== undefined) {
      normalized.category = data.category.toString().trim();
    }
    if (data.price !== undefined) {
      normalized.price = Math.max(0, parseFloat(data.price) || 0);
    }
    if (data.foodType !== undefined || data.foodtype !== undefined || data.itemType !== undefined) {
      normalized.foodType = this._normalizeFoodType(data.foodType || data.foodtype || data.itemType);
    }
    if (data.hasDiscount !== undefined) {
      normalized.hasDiscount = Boolean(data.hasDiscount);
    }
    if (data.discountPercent !== undefined || data.discount !== undefined) {
      normalized.discountPercent = Math.max(0, Math.min(100, parseFloat(data.discountPercent ?? data.discount) || 0));
      if (normalized.discountPercent > 0 && normalized.hasDiscount === undefined) {
        normalized.hasDiscount = true;
      }
    }
    if (data.salePrice !== undefined) {
      normalized.salePrice = Math.max(0, parseFloat(data.salePrice) || 0);
    } else if (normalized.hasDiscount && normalized.discountPercent !== undefined && normalized.price !== undefined) {
      normalized.salePrice = normalized.price * (1 - normalized.discountPercent / 100);
    }

    if (data.image !== undefined || data.imageUrl !== undefined) {
      normalized.image = (data.image || data.imageUrl || '').toString().trim();
    }
    if (Array.isArray(data.images)) {
      normalized.images = data.images.map((img) => img.toString().trim()).filter(Boolean);
      if (!normalized.image && normalized.images.length > 0) {
        normalized.image = normalized.images[0];
      }
    } else if (normalized.image) {
      normalized.images = [normalized.image];
    }

    if (data.videoUrl !== undefined || data.video !== undefined) {
      normalized.videoUrl = (data.videoUrl || data.video || '').toString().trim();
    }

    if (Array.isArray(data.variants)) {
      normalized.variants = data.variants.map((v) => {
        const vPrice = Math.max(0, parseFloat(v.price) || 0);
        const vDiscPct = Math.max(0, Math.min(100, parseFloat(v.discountPercent ?? v.discount) || 0));
        const vHasDisc = v.hasDiscount === true || vDiscPct > 0;
        const vSalePrice = v.salePrice !== undefined ? Math.max(0, parseFloat(v.salePrice) || 0) : (vHasDisc ? vPrice * (1 - vDiscPct / 100) : 0);
        return {
          name: (v.name || '').toString().trim(),
          price: vPrice,
          hasDiscount: vHasDisc,
          discountPercent: vDiscPct,
          salePrice: vSalePrice,
          stock: v.stock !== undefined ? parseInt(v.stock, 10) : -1,
        };
      });
    }

    if (data.isAvailable !== undefined) {
      normalized.isAvailable = Boolean(data.isAvailable);
    }
    if (data.stock !== undefined || data.stockQuantity !== undefined || data.inventory !== undefined) {
      normalized.stock = parseInt(data.stock ?? data.stockQuantity ?? data.inventory, 10);
    }
    if (data.trackInventory !== undefined) {
      normalized.trackInventory = Boolean(data.trackInventory);
    }
    if (data.sku !== undefined) {
      normalized.sku = data.sku.toString().trim();
    }
    if (data.taxPercentage !== undefined || data.gstPercent !== undefined || data.gst !== undefined) {
      normalized.taxPercentage = Math.max(0, Math.min(100, parseFloat(data.taxPercentage ?? data.gstPercent ?? data.gst) || 0));
    }

    if (isCreate) {
      normalized.productId = (data.productId || data.id || this._generateUniqueProductId()).toString().trim();
    } else if (data.productId) {
      normalized.productId = data.productId.toString().trim();
    }

    return normalized;
  }

  _buildProductQuery(businessId, identifier) {
    const isObjectId = mongoose.Types.ObjectId.isValid(identifier);
    if (isObjectId) {
      return {
        businessId,
        $or: [{ _id: identifier }, { productId: identifier }],
      };
    }
    return {
      businessId,
      productId: identifier,
    };
  }

  async getPosProducts(businessId, { page = 1, limit = 100, category, search } = {}) {
    const query = { businessId, isAvailable: true };

    if (category && category !== 'All') {
      query.category = category;
    }

    if (search && search.trim()) {
      const regex = new RegExp(search.trim(), 'i');
      query.$or = [{ name: regex }, { barcode: search.trim() }, { sku: search.trim() }, { productId: search.trim() }];
    }

    const skip = (Math.max(1, parseInt(page, 10)) - 1) * Math.max(1, parseInt(limit, 10));
    const parsedLimit = Math.max(1, parseInt(limit, 10));

    const [rawProducts, total] = await Promise.all([
      Product.find(query)
        .sort({ name: 1 })
        .skip(skip)
        .limit(parsedLimit)
        .lean(),
      Product.countDocuments(query),
    ]);

    const seenNames = new Set();
    const products = [];
    for (const p of rawProducts) {
      const nameKey = (p.name || '').trim().toLowerCase();
      if (!nameKey || seenNames.has(nameKey)) continue;
      seenNames.add(nameKey);

      p.id = p._id ? p._id.toString() : (p.id || p.productId);
      p.productId = p.productId || p.id;
      delete p._id;
      delete p.__v;
      products.push(p);
    }

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
      query.$or = [{ name: regex }, { description: regex }, { category: regex }, { productId: regex }];
    }

    const skip = (Math.max(1, parseInt(page, 10)) - 1) * Math.max(1, parseInt(limit, 10));
    const parsedLimit = Math.max(1, parseInt(limit, 10));

    const [rawProducts, total] = await Promise.all([
      Product.find(query).sort({ createdAt: -1 }).skip(skip).limit(parsedLimit).lean(),
      Product.countDocuments(query),
    ]);

    const seenNames = new Set();
    const products = [];
    for (const p of rawProducts) {
      const nameKey = (p.name || '').trim().toLowerCase();
      if (!nameKey || seenNames.has(nameKey)) continue;
      seenNames.add(nameKey);

      p.id = p._id ? p._id.toString() : (p.id || p.productId);
      p.productId = p.productId || p.id;
      delete p._id;
      delete p.__v;
      products.push(p);
    }

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

  _escapeRegex(str) {
    return (str || '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  async createProduct(businessId, rawData) {
    const normalizedData = this._normalizeProductData(rawData, true);

    if (normalizedData.name) {
      const escapedName = this._escapeRegex(normalizedData.name);
      const existingProduct = await Product.findOne({
        businessId,
        name: { $regex: new RegExp(`^${escapedName}$`, 'i') },
      });

      if (existingProduct) {
        throw ApiError.conflict(
          `A product with name "${normalizedData.name}" already exists for this business.`,
          'DUPLICATE_PRODUCT_NAME'
        );
      }
    }

    const product = await Product.create({
      ...normalizedData,
      businessId,
    });

    // Auto-create category if doesn't exist
    if (product.category) {
      await Category.findOneAndUpdate(
        { businessId, name: product.category },
        { $setOnInsert: { businessId, name: product.category } },
        { upsert: true, new: true }
      );
    }

    return product;
  }

  async getProductById(businessId, identifier) {
    const query = this._buildProductQuery(businessId, identifier);
    const product = await Product.findOne(query);
    if (!product) {
      throw ApiError.notFound('Product not found or does not belong to this business');
    }
    return product;
  }

  async updateProduct(businessId, identifier, rawData) {
    const normalizedData = this._normalizeProductData(rawData, false);
    const query = this._buildProductQuery(businessId, identifier);

    const existingProduct = await Product.findOne(query);
    if (!existingProduct) {
      throw ApiError.notFound('Product not found or does not belong to this business');
    }

    if (
      normalizedData.name &&
      normalizedData.name.trim().toLowerCase() !== (existingProduct.name || '').trim().toLowerCase()
    ) {
      const escapedName = this._escapeRegex(normalizedData.name.trim());
      const duplicate = await Product.findOne({
        businessId,
        _id: { $ne: existingProduct._id },
        name: { $regex: new RegExp(`^${escapedName}$`, 'i') },
      });

      if (duplicate) {
        throw ApiError.conflict(
          `A product with name "${normalizedData.name}" already exists for this business.`,
          'DUPLICATE_PRODUCT_NAME'
        );
      }
    }

    const product = await Product.findOneAndUpdate(
      query,
      { $set: normalizedData },
      { new: true, runValidators: true }
    );

    if (!product) {
      throw ApiError.notFound('Product not found or does not belong to this business');
    }

    if (product.category) {
      await Category.findOneAndUpdate(
        { businessId, name: product.category },
        { $setOnInsert: { businessId, name: product.category } },
        { upsert: true, new: true }
      );
    }

    return product;
  }

  async deleteProduct(businessId, identifier) {
    const query = this._buildProductQuery(businessId, identifier);
    const product = await Product.findOneAndDelete(query);
    if (!product) {
      throw ApiError.notFound('Product not found or does not belong to this business');
    }
    return { id: product.productId || product._id.toString(), message: 'Product deleted successfully' };
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
    const trimmed = (name || '').trim();
    if (!trimmed) {
      throw ApiError.badRequest('Category name cannot be empty');
    }
    const existing = await Category.findOne({ businessId, name: trimmed });
    if (existing) {
      throw ApiError.conflict(`Category '${trimmed}' already exists`);
    }
    return Category.create({ businessId, name: trimmed, icon, color, sortOrder });
  }

  async updateCategory(businessId, oldName, { name, icon, color, sortOrder }) {
    const oldTrimmed = (oldName || '').trim();
    const newTrimmed = (name || oldName || '').trim();

    if (!newTrimmed) {
      throw ApiError.badRequest('Category name cannot be empty');
    }

    const category = await Category.findOne({ businessId, name: oldTrimmed });
    if (!category) {
      throw ApiError.notFound(`Category '${oldTrimmed}' not found`);
    }

    if (newTrimmed !== oldTrimmed) {
      const conflict = await Category.findOne({ businessId, name: newTrimmed });
      if (conflict) {
        throw ApiError.conflict(`Category '${newTrimmed}' already exists`);
      }
    }

    category.name = newTrimmed;
    if (icon !== undefined) category.icon = icon;
    if (color !== undefined) category.color = color;
    if (sortOrder !== undefined) category.sortOrder = sortOrder;
    await category.save();

    // Cascade rename to all products under this category
    if (newTrimmed !== oldTrimmed) {
      await Product.updateMany(
        { businessId, category: oldTrimmed },
        { $set: { category: newTrimmed } }
      );
    }

    return category;
  }

  async deleteCategory(businessId, name) {
    const trimmed = (name || '').trim();
    const result = await Category.findOneAndDelete({ businessId, name: trimmed });
    if (!result) {
      throw ApiError.notFound(`Category '${trimmed}' not found`);
    }
    return { name: trimmed, message: 'Category removed successfully' };
  }

  async bulkImportProducts(businessId, items) {
    if (!Array.isArray(items) || items.length === 0) {
      throw ApiError.badRequest('Items array is required for bulk import');
    }

    const results = [];
    for (const item of items) {
      const normalized = this._normalizeProductData(item, true);
      if (!normalized.name) continue;

      const escapedName = this._escapeRegex(normalized.name);
      const query = {
        businessId,
        $or: [
          ...(normalized.productId ? [{ productId: normalized.productId }] : []),
          { name: { $regex: new RegExp(`^${escapedName}$`, 'i') } }
        ]
      };

      const updated = await Product.findOneAndUpdate(
        query,
        {
          $set: {
            ...normalized,
            businessId,
          }
        },
        { new: true, upsert: true, setDefaultsOnInsert: true }
      );
      results.push(updated);
    }

    // Sync categories
    const distinctCategories = [...new Set(results.map((d) => d.category).filter(Boolean))];
    for (const cat of distinctCategories) {
      await Category.findOneAndUpdate(
        { businessId, name: cat },
        { $setOnInsert: { businessId, name: cat } },
        { upsert: true }
      );
    }

    return { importedCount: results.length, products: results };
  }
}

module.exports = new ProductService();

