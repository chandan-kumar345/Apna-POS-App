const mongoose = require('mongoose');
const Inventory = require('../models/Inventory');
const RawMaterial = require('../models/RawMaterial');
const Recipe = require('../models/Recipe');
const InventoryMovement = require('../models/InventoryMovement');
const StockReceipt = require('../models/StockReceipt');
const StockCount = require('../models/StockCount');
const Product = require('../models/Product');
const ApiError = require('../utils/ApiError');

class InventoryService {
  // =========================================================================
  // 1. LEGACY INVENTORY BACKWARD COMPATIBILITY
  // =========================================================================

  async getInventory(businessId, { category, lowStock } = {}) {
    const query = { businessId };
    if (category && category !== 'All') {
      query.category = category;
    }
    if (lowStock === 'true' || lowStock === true) {
      query.$expr = { $lte: ['$quantity', '$minThreshold'] };
    }
    const items = await Inventory.find(query).sort({ itemName: 1 });
    return items;
  }

  async createInventoryItem(businessId, data) {
    const item = await Inventory.create({ ...data, businessId });
    return item;
  }

  async updateInventoryItem(businessId, id, data) {
    const item = await Inventory.findOneAndUpdate(
      { _id: id, businessId },
      { $set: data },
      { new: true, runValidators: true }
    );
    if (!item) {
      throw ApiError.notFound('Inventory item not found');
    }
    return item;
  }

  async deleteInventoryItem(businessId, id) {
    const item = await Inventory.findOneAndDelete({ _id: id, businessId });
    if (!item) {
      throw ApiError.notFound('Inventory item not found');
    }
    return { id, message: 'Item deleted' };
  }

  // =========================================================================
  // 2. RAW MATERIAL MANAGEMENT
  // =========================================================================

  async getRawMaterials(businessId, { category, search, lowStock, mode, status } = {}) {
    const query = { businessId };

    if (status === 'archived') {
      query.isActive = false;
    } else if (status !== 'all') {
      query.isActive = true;
    }

    if (category && category !== 'All') {
      query.category = category;
    }

    if (mode && mode !== 'All') {
      query.inventoryMode = mode.toLowerCase();
    }

    if (search && search.trim()) {
      const searchRegex = new RegExp(search.trim(), 'i');
      query.$or = [{ name: searchRegex }, { sku: searchRegex }, { category: searchRegex }];
    }

    if (lowStock === 'true' || lowStock === true) {
      query.$expr = { $lte: ['$currentStock', '$minimumStock'] };
    }

    const materials = await RawMaterial.find(query).sort({ name: 1 });
    return materials;
  }

  async getRawMaterialById(businessId, id) {
    const material = await RawMaterial.findOne({ _id: id, businessId });
    if (!material) {
      throw ApiError.notFound('Raw material not found');
    }
    return material;
  }

  async createRawMaterial(businessId, data, createdBy = 'Owner') {
    // Generate SKU if omitted (e.g., RM-0001)
    let sku = (data.sku || '').trim().toUpperCase();
    if (!sku) {
      const count = await RawMaterial.countDocuments({ businessId });
      sku = `RM-${String(count + 1).padStart(4, '0')}`;
    }

    const existingSku = await RawMaterial.findOne({ businessId, sku });
    if (existingSku) {
      throw ApiError.badRequest(`Material with SKU "${sku}" already exists`);
    }

    const conversionFactor = Number(data.conversionFactor) || 1000;
    const averageUnitCost = Number(data.averageUnitCost) || 0;
    const costPerBaseUnit = conversionFactor > 0 ? averageUnitCost / conversionFactor : 0;
    const initialStock = Number(data.openingStock || data.currentStock) || 0;

    const material = await RawMaterial.create({
      businessId,
      sku,
      name: data.name,
      category: data.category || 'General',
      baseUnit: data.baseUnit || 'g',
      purchaseUnit: data.purchaseUnit || 'kg',
      conversionFactor,
      minimumStock: Number(data.minimumStock) || 0,
      currentStock: initialStock,
      averageUnitCost,
      costPerBaseUnit,
      preferredSupplier: data.preferredSupplier || '',
      inventoryMode: data.inventoryMode || 'automatic',
      isActive: data.isActive !== undefined ? data.isActive : true,
      notes: data.notes || '',
    });

    // Record opening stock movement if initialStock > 0
    if (initialStock > 0) {
      await InventoryMovement.create({
        businessId,
        materialId: material._id,
        materialName: material.name,
        movementType: 'opening_stock',
        quantityDeltaBaseUnits: initialStock,
        balanceBeforeBaseUnits: 0,
        balanceAfterBaseUnits: initialStock,
        unitCost: costPerBaseUnit,
        totalCost: initialStock * costPerBaseUnit,
        sourceType: 'opening',
        sourceId: material._id.toString(),
        reason: 'Initial opening stock creation',
        createdBy,
      });
    }

    return material;
  }

  async updateRawMaterial(businessId, id, data) {
    const material = await RawMaterial.findOne({ _id: id, businessId });
    if (!material) {
      throw ApiError.notFound('Raw material not found');
    }

    if (data.conversionFactor !== undefined || data.averageUnitCost !== undefined) {
      const conv = Number(data.conversionFactor !== undefined ? data.conversionFactor : material.conversionFactor) || 1000;
      const avgCost = Number(data.averageUnitCost !== undefined ? data.averageUnitCost : material.averageUnitCost) || 0;
      data.costPerBaseUnit = conv > 0 ? avgCost / conv : 0;
    }

    // Do not allow direct silent modification of currentStock through generic update;
    // stock adjustments must go through stock operations / movement ledger.
    delete data.currentStock;

    Object.assign(material, data);
    await material.save();
    return material;
  }

  async archiveRawMaterial(businessId, id) {
    const material = await RawMaterial.findOneAndUpdate(
      { _id: id, businessId },
      { $set: { isActive: false } },
      { new: true }
    );
    if (!material) {
      throw ApiError.notFound('Raw material not found');
    }
    return { id, message: 'Material archived successfully' };
  }

  async getMaterialMovements(businessId, materialId, { limit = 50, page = 1 } = {}) {
    const skip = (Math.max(1, Number(page)) - 1) * Number(limit);
    const query = { businessId, materialId };

    const [movements, total] = await Promise.all([
      InventoryMovement.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      InventoryMovement.countDocuments(query),
    ]);

    return { movements, total, page: Number(page), limit: Number(limit) };
  }

  // =========================================================================
  // 3. RECIPE MANAGEMENT & COSTING
  // =========================================================================

  async getRecipes(businessId, { search, productId } = {}) {
    const query = { businessId, isActive: true };

    if (productId) {
      query.productId = productId;
    }

    if (search && search.trim()) {
      const searchRegex = new RegExp(search.trim(), 'i');
      query.$or = [{ productName: searchRegex }, { recipeName: searchRegex }];
    }

    const recipes = await Recipe.find(query).sort({ productName: 1 });
    return recipes;
  }

  async getRecipeById(businessId, id) {
    const recipe = await Recipe.findOne({ _id: id, businessId });
    if (!recipe) {
      throw ApiError.notFound('Recipe not found');
    }
    return recipe;
  }

  async calculateRecipeCosting(businessId, ingredients = [], sellingPrice = 0) {
    let totalFoodCost = 0;
    const computedIngredients = [];

    for (const item of ingredients) {
      const material = await RawMaterial.findOne({ _id: item.materialId, businessId });
      if (!material) {
        throw ApiError.badRequest(`Material with ID "${item.materialId}" does not exist`);
      }

      const inputQty = Number(item.quantity) || 0;
      const unit = (item.unit || material.baseUnit).trim().toLowerCase();
      let quantityBaseUnits = inputQty;

      // Handle unit conversions safely
      if (unit === 'kg' && material.baseUnit === 'g') {
        quantityBaseUnits = inputQty * 1000;
      } else if (unit === 'g' && material.baseUnit === 'g') {
        quantityBaseUnits = inputQty;
      } else if (unit === 'l' && material.baseUnit === 'ml') {
        quantityBaseUnits = inputQty * 1000;
      } else if (unit === 'ml' && material.baseUnit === 'ml') {
        quantityBaseUnits = inputQty;
      } else if (unit === material.purchaseUnit.toLowerCase()) {
        quantityBaseUnits = inputQty * (material.conversionFactor || 1);
      } else if (unit === material.baseUnit.toLowerCase()) {
        quantityBaseUnits = inputQty;
      } else {
        quantityBaseUnits = inputQty;
      }

      const lossPercent = Number(item.preparationLossPercent) || 0;
      const effectiveQuantityBaseUnits = quantityBaseUnits * (1 + lossPercent / 100);
      const unitCost = Number(material.costPerBaseUnit) || 0;
      const itemTotalCost = effectiveQuantityBaseUnits * unitCost;

      totalFoodCost += itemTotalCost;

      computedIngredients.push({
        materialId: material._id,
        materialName: material.name,
        quantity: inputQty,
        unit: item.unit || material.baseUnit,
        quantityBaseUnits: Math.round(quantityBaseUnits * 10000) / 10000,
        preparationLossPercent: lossPercent,
        effectiveQuantityBaseUnits: Math.round(effectiveQuantityBaseUnits * 10000) / 10000,
        unitCost: Math.round(unitCost * 10000) / 10000,
        totalCost: Math.round(itemTotalCost * 100) / 100,
      });
    }

    totalFoodCost = Math.round(totalFoodCost * 100) / 100;
    const sPrice = Number(sellingPrice) || 0;
    const foodCostPercentage = sPrice > 0 ? Math.round((totalFoodCost / sPrice) * 10000) / 100 : 0;

    return {
      ingredients: computedIngredients,
      totalFoodCost,
      sellingPrice: sPrice,
      foodCostPercentage,
    };
  }

  async createRecipe(businessId, data) {
    if (!data.productId) {
      throw ApiError.badRequest('Product ID is required');
    }
    if (!Array.isArray(data.ingredients) || data.ingredients.length === 0) {
      throw ApiError.badRequest('At least one ingredient is required to create a recipe');
    }

    // Attempt to lookup product if name/price missing
    let productName = data.productName;
    let sellingPrice = Number(data.sellingPrice) || 0;
    if (!productName || !sellingPrice) {
      const prod = await Product.findOne({
        businessId,
        $or: [
          mongoose.Types.ObjectId.isValid(data.productId) ? { _id: data.productId } : null,
          { productId: data.productId },
        ].filter(Boolean),
      });
      if (prod) {
        if (!productName) productName = prod.name;
        if (!sellingPrice) sellingPrice = prod.salePrice || prod.price || 0;
      }
    }

    const costing = await this.calculateRecipeCosting(businessId, data.ingredients, sellingPrice);

    const recipe = await Recipe.create({
      businessId,
      productId: data.productId,
      productName: productName || 'Menu Item',
      recipeName: data.recipeName || productName || 'Recipe',
      variantId: data.variantId || '',
      variantName: data.variantName || '',
      servingSize: Number(data.servingSize) || 1,
      version: data.version || 'v1.0',
      ingredients: costing.ingredients,
      totalFoodCost: costing.totalFoodCost,
      sellingPrice: costing.sellingPrice,
      foodCostPercentage: costing.foodCostPercentage,
      isActive: true,
      instructions: data.instructions || '',
    });

    return recipe;
  }

  async updateRecipe(businessId, id, data) {
    const recipe = await Recipe.findOne({ _id: id, businessId });
    if (!recipe) {
      throw ApiError.notFound('Recipe not found');
    }

    const ingredientsToUse = data.ingredients || recipe.ingredients;
    const sellingPriceToUse = data.sellingPrice !== undefined ? data.sellingPrice : recipe.sellingPrice;
    const costing = await this.calculateRecipeCosting(businessId, ingredientsToUse, sellingPriceToUse);

    recipe.recipeName = data.recipeName !== undefined ? data.recipeName : recipe.recipeName;
    recipe.servingSize = data.servingSize !== undefined ? Number(data.servingSize) : recipe.servingSize;
    recipe.version = data.version !== undefined ? data.version : recipe.version;
    recipe.ingredients = costing.ingredients;
    recipe.totalFoodCost = costing.totalFoodCost;
    recipe.sellingPrice = costing.sellingPrice;
    recipe.foodCostPercentage = costing.foodCostPercentage;
    if (data.instructions !== undefined) recipe.instructions = data.instructions;
    if (data.isActive !== undefined) recipe.isActive = data.isActive;

    await recipe.save();
    return recipe;
  }

  async deleteRecipe(businessId, id) {
    const recipe = await Recipe.findOneAndUpdate(
      { _id: id, businessId },
      { $set: { isActive: false } },
      { new: true }
    );
    if (!recipe) {
      throw ApiError.notFound('Recipe not found');
    }
    return { id, message: 'Recipe archived' };
  }

  // =========================================================================
  // 4. AUTOMATIC RECIPE DEDUCTION ENGINE (ON POS SALE / ORDER COMPLETION)
  // =========================================================================

  /**
   * Deducts raw materials according to recipes for a finalized POS order.
   * Guarantees strict idempotency via composite unique idempotency keys.
   */
  async deductRecipeInventoryForOrder(businessId, order) {
    if (!businessId || !order) return null;

    const orderIdStr = (order._id ? order._id.toString() : order.id || order.orderNumber || '').toString();
    const orderNumberStr = order.orderNumber || orderIdStr;

    // Check if movements have already been recorded for this order (Idempotency safeguard)
    const existingMovement = await InventoryMovement.findOne({
      businessId,
      sourceType: 'order',
      sourceId: orderIdStr,
    });

    if (existingMovement) {
      // Already deducted, skip to prevent double-deduction on retries
      return { skipped: true, reason: 'Already deducted' };
    }

    const items = order.items || [];
    if (!Array.isArray(items) || items.length === 0) {
      return { skipped: true, reason: 'No items in order' };
    }

    const deductionsSummary = [];

    for (const item of items) {
      const soldQty = Number(item.quantity) || 1;
      const prodId = item.productId || item.id;
      const itemName = item.name || '';

      // Find active recipe by productId or by productName
      let recipe = null;
      if (prodId) {
        recipe = await Recipe.findOne({
          businessId,
          productId: prodId,
          isActive: true,
        });
      }
      if (!recipe && itemName) {
        recipe = await Recipe.findOne({
          businessId,
          productName: new RegExp(`^${itemName.trim()}$`, 'i'),
          isActive: true,
        });
      }

      if (!recipe || !Array.isArray(recipe.ingredients) || recipe.ingredients.length === 0) {
        // No recipe configured for this menu item, skip automatically
        continue;
      }

      const servingFactor = (recipe.servingSize && recipe.servingSize > 0) ? recipe.servingSize : 1;
      const portionsSold = soldQty / servingFactor;

      for (const ingredient of recipe.ingredients) {
        const material = await RawMaterial.findOne({
          _id: ingredient.materialId,
          businessId,
          isActive: true,
        });

        if (!material) continue;

        // Skip manual-only mode materials if configured to not deduct automatically
        if (material.inventoryMode === 'manual') continue;

        const deductionBaseUnits = portionsSold * ingredient.effectiveQuantityBaseUnits;
        const currentBalance = Number(material.currentStock) || 0;
        const newBalance = Math.round((currentBalance - deductionBaseUnits) * 1000) / 1000;
        const idempotencyKey = `sale_${orderIdStr}_${material._id.toString()}`;

        // Deduct from material
        material.currentStock = newBalance;
        await material.save();

        const cost = Math.round(deductionBaseUnits * (material.costPerBaseUnit || ingredient.unitCost || 0) * 100) / 100;

        // Record immutable ledger entry
        try {
          await InventoryMovement.create({
            businessId,
            materialId: material._id,
            materialName: material.name,
            movementType: 'sale_consumption',
            quantityDeltaBaseUnits: -Math.round(deductionBaseUnits * 1000) / 1000,
            balanceBeforeBaseUnits: currentBalance,
            balanceAfterBaseUnits: newBalance,
            unitCost: material.costPerBaseUnit || ingredient.unitCost || 0,
            totalCost: cost,
            sourceType: 'order',
            sourceId: orderIdStr,
            idempotencyKey,
            reason: `POS Sale #${orderNumberStr}: ${itemName} x ${soldQty}`,
            createdBy: 'POS System',
          });

          deductionsSummary.push({
            productId: prodId,
            productName: itemName,
            materialName: material.name,
            deducted: deductionBaseUnits,
            baseUnit: material.baseUnit,
            newBalance,
          });
        } catch (mErr) {
          // Ignore duplicate idempotency key collisions safely
          if (mErr.code !== 11000) {
            console.error('[InventoryService.deductRecipeInventoryForOrder] Movement creation error:', mErr);
          }
        }
      }
    }

    return { deducted: true, orderId: orderIdStr, count: deductionsSummary.length, summary: deductionsSummary };
  }

  // =========================================================================
  // 5. MANUAL STOCK OPERATIONS (MODE B)
  // =========================================================================

  /**
   * Set opening stock in bulk (used when onboarding or establishing initial stock)
   */
  async recordOpeningStock(businessId, { items = [], conductedBy = 'Owner' } = {}) {
    if (!Array.isArray(items) || items.length === 0) {
      throw ApiError.badRequest('At least one item is required for opening stock');
    }

    const results = [];
    for (const item of items) {
      const material = await RawMaterial.findOne({ _id: item.materialId, businessId });
      if (!material) continue;

      const openingQty = Number(item.quantity) || 0;
      const unit = (item.unit || material.baseUnit).trim().toLowerCase();
      let openingBaseUnits = openingQty;

      if (unit === material.purchaseUnit.toLowerCase()) {
        openingBaseUnits = openingQty * (material.conversionFactor || 1);
      }

      const balanceBefore = material.currentStock || 0;
      material.currentStock = openingBaseUnits;
      if (item.unitCost !== undefined && item.unitCost > 0) {
        material.averageUnitCost = Number(item.unitCost);
        material.costPerBaseUnit = material.conversionFactor > 0 ? material.averageUnitCost / material.conversionFactor : 0;
      }
      await material.save();

      await InventoryMovement.create({
        businessId,
        materialId: material._id,
        materialName: material.name,
        movementType: 'opening_stock',
        quantityDeltaBaseUnits: openingBaseUnits - balanceBefore,
        balanceBeforeBaseUnits: balanceBefore,
        balanceAfterBaseUnits: openingBaseUnits,
        unitCost: material.costPerBaseUnit,
        totalCost: openingBaseUnits * material.costPerBaseUnit,
        sourceType: 'opening',
        sourceId: material._id.toString(),
        reason: item.reason || 'Opening stock entry',
        createdBy: conductedBy,
      });

      results.push({ materialId: material._id, name: material.name, stock: openingBaseUnits });
    }

    return results;
  }

  /**
   * Record Stock-In (Purchases / Receipts from Suppliers)
   */
  async recordStockIn(businessId, receiptData, conductedBy = 'Owner') {
    if (!Array.isArray(receiptData.items) || receiptData.items.length === 0) {
      throw ApiError.badRequest('At least one receipt item is required');
    }

    const receiptNumber = receiptData.receiptNumber || `REC-${Date.now().toString().slice(-6)}`;
    let totalAmount = 0;
    const computedItems = [];

    for (const item of receiptData.items) {
      const material = await RawMaterial.findOne({ _id: item.materialId, businessId });
      if (!material) {
        throw ApiError.badRequest(`Raw material ${item.materialId} not found`);
      }

      const purchaseQty = Number(item.purchaseQuantity) || 0;
      const purchaseUnit = item.purchaseUnit || material.purchaseUnit;
      const conversionFactor = Number(item.conversionFactor) || material.conversionFactor || 1;
      const baseUnitsReceived = purchaseQty * conversionFactor;
      const unitCost = Number(item.unitCost) || material.averageUnitCost || 0;
      const totalItemCost = purchaseQty * unitCost;

      totalAmount += totalItemCost;

      // Weighted average cost update
      const currentStock = material.currentStock || 0;
      const currentValuation = currentStock * (material.costPerBaseUnit || 0);
      const newTotalStock = currentStock + baseUnitsReceived;
      const newTotalValuation = currentValuation + totalItemCost;
      const newCostPerBaseUnit = newTotalStock > 0 ? newTotalValuation / newTotalStock : material.costPerBaseUnit;

      material.currentStock = newTotalStock;
      material.costPerBaseUnit = newCostPerBaseUnit;
      material.averageUnitCost = newCostPerBaseUnit * conversionFactor;
      if (receiptData.supplierName && !material.preferredSupplier) {
        material.preferredSupplier = receiptData.supplierName;
      }
      await material.save();

      computedItems.push({
        materialId: material._id,
        materialName: material.name,
        purchaseQuantity: purchaseQty,
        purchaseUnit,
        conversionFactor,
        baseUnitsReceived,
        unitCost,
        totalCost: totalItemCost,
      });

      // Log movement ledger entry
      await InventoryMovement.create({
        businessId,
        materialId: material._id,
        materialName: material.name,
        movementType: 'purchase_receipt',
        quantityDeltaBaseUnits: baseUnitsReceived,
        balanceBeforeBaseUnits: currentStock,
        balanceAfterBaseUnits: newTotalStock,
        unitCost: newCostPerBaseUnit,
        totalCost: totalItemCost,
        sourceType: 'purchase_receipt',
        sourceId: receiptNumber,
        reason: `Purchase from ${receiptData.supplierName || 'Supplier'} (Inv: ${receiptData.invoiceNumber || 'N/A'})`,
        createdBy: conductedBy,
      });
    }

    const receipt = await StockReceipt.create({
      businessId,
      receiptNumber,
      supplierName: receiptData.supplierName || '',
      invoiceNumber: receiptData.invoiceNumber || '',
      purchaseDate: receiptData.purchaseDate || new Date(),
      items: computedItems,
      totalAmount,
      paymentStatus: receiptData.paymentStatus || 'paid',
      notes: receiptData.notes || '',
      receivedBy: conductedBy,
    });

    return receipt;
  }

  /**
   * Record Stock-Out (Manual removals, Kitchen consumption, Wastage, Spoilage, Damage)
   */
  async recordStockOut(businessId, data, conductedBy = 'Owner') {
    const material = await RawMaterial.findOne({ _id: data.materialId, businessId });
    if (!material) {
      throw ApiError.notFound('Raw material not found');
    }

    const qty = Number(data.quantity) || 0;
    if (qty <= 0) {
      throw ApiError.badRequest('Quantity must be greater than zero');
    }

    const unit = (data.unit || material.baseUnit).trim().toLowerCase();
    let baseUnitsOut = qty;

    if (unit === material.purchaseUnit.toLowerCase()) {
      baseUnitsOut = qty * (material.conversionFactor || 1);
    }

    const currentBalance = Number(material.currentStock) || 0;
    const newBalance = Math.round((currentBalance - baseUnitsOut) * 1000) / 1000;
    material.currentStock = newBalance;
    await material.save();

    const movementType = data.movementType === 'wastage' ? 'wastage' : 'stock_out';
    const totalCost = baseUnitsOut * (material.costPerBaseUnit || 0);

    const movement = await InventoryMovement.create({
      businessId,
      materialId: material._id,
      materialName: material.name,
      movementType,
      quantityDeltaBaseUnits: -baseUnitsOut,
      balanceBeforeBaseUnits: currentBalance,
      balanceAfterBaseUnits: newBalance,
      unitCost: material.costPerBaseUnit || 0,
      totalCost,
      sourceType: 'manual_issue',
      sourceId: `OUT-${Date.now().toString().slice(-6)}`,
      reason: data.reason || 'Manual stock deduction / wastage',
      createdBy: conductedBy,
    });

    return { material, movement };
  }

  /**
   * Record Physical Stock Count & Variance Adjustments
   */
  async recordPhysicalStockCount(businessId, countData, conductedBy = 'Manager') {
    if (!Array.isArray(countData.items) || countData.items.length === 0) {
      throw ApiError.badRequest('At least one item is required for physical count');
    }

    const countNumber = countData.countNumber || `CNT-${Date.now().toString().slice(-6)}`;
    let totalVarianceValue = 0;
    const processedItems = [];

    for (const item of countData.items) {
      const material = await RawMaterial.findOne({ _id: item.materialId, businessId });
      if (!material) continue;

      const expectedBaseUnits = Number(material.currentStock) || 0;
      const actualQty = Number(item.actualQuantity !== undefined ? item.actualQuantity : item.actualBaseUnits) || 0;
      const unit = (item.unit || material.baseUnit).trim().toLowerCase();
      let actualBaseUnits = actualQty;

      if (unit === material.purchaseUnit.toLowerCase()) {
        actualBaseUnits = actualQty * (material.conversionFactor || 1);
      }

      const varianceBaseUnits = Math.round((actualBaseUnits - expectedBaseUnits) * 1000) / 1000;
      const unitCost = Number(material.costPerBaseUnit) || 0;
      const varianceValue = Math.round(varianceBaseUnits * unitCost * 100) / 100;
      totalVarianceValue += varianceValue;

      // Adjust stock to actual counted quantity
      material.currentStock = actualBaseUnits;
      await material.save();

      // Log movement for this variance
      await InventoryMovement.create({
        businessId,
        materialId: material._id,
        materialName: material.name,
        movementType: 'inventory_adjustment',
        quantityDeltaBaseUnits: varianceBaseUnits,
        balanceBeforeBaseUnits: expectedBaseUnits,
        balanceAfterBaseUnits: actualBaseUnits,
        unitCost,
        totalCost: Math.abs(varianceValue),
        sourceType: 'stock_count',
        sourceId: countNumber,
        reason: item.reason || `Physical count audit variance (${varianceBaseUnits > 0 ? '+' : ''}${varianceBaseUnits} ${material.baseUnit})`,
        createdBy: conductedBy,
      });

      processedItems.push({
        materialId: material._id,
        materialName: material.name,
        baseUnit: material.baseUnit,
        expectedBaseUnits,
        actualBaseUnits,
        varianceBaseUnits,
        unitCost,
        varianceValue,
        reason: item.reason || 'Physical count adjustment',
      });
    }

    const count = await StockCount.create({
      businessId,
      countNumber,
      countDate: countData.countDate || new Date(),
      status: 'approved',
      items: processedItems,
      totalVarianceValue,
      conductedBy,
      notes: countData.notes || '',
    });

    return count;
  }

  // =========================================================================
  // 6. REPORTS & ANALYTICS
  // =========================================================================

  /**
   * Executive Dashboard Summary:
   * 1. Total inventory value
   * 2. Total raw materials
   * 3. Low stock count & alerts
   * 4. Out of stock count
   * 5. Today's stock-in
   * 6. Today's stock-out / consumption
   * 7. Recent stock transactions
   * 8. Top consumed ingredients
   */
  async getDashboardSummary(businessId) {
    const materials = await RawMaterial.find({ businessId, isActive: true });

    let totalInventoryValue = 0;
    let lowStockCount = 0;
    let outOfStockCount = 0;
    const lowStockAlerts = [];

    for (const m of materials) {
      const stock = Number(m.currentStock) || 0;
      const costPerBase = Number(m.costPerBaseUnit) || 0;
      totalInventoryValue += stock * costPerBase;

      if (stock <= 0) {
        outOfStockCount++;
        lowStockAlerts.push(m);
      } else if (stock <= (m.minimumStock || 0)) {
        lowStockCount++;
        lowStockAlerts.push(m);
      }
    }

    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const [todayInMovements, todayOutMovements, recentMovements] = await Promise.all([
      InventoryMovement.find({
        businessId,
        movementType: { $in: ['purchase_receipt', 'opening_stock'] },
        createdAt: { $gte: startOfToday },
      }),
      InventoryMovement.find({
        businessId,
        movementType: { $in: ['sale_consumption', 'stock_out', 'wastage'] },
        createdAt: { $gte: startOfToday },
      }),
      InventoryMovement.find({ businessId })
        .sort({ createdAt: -1 })
        .limit(10),
    ]);

    let todayStockInValue = 0;
    let todayStockInQuantity = 0;
    for (const m of todayInMovements) {
      todayStockInQuantity += Math.abs(m.quantityDeltaBaseUnits || 0);
      todayStockInValue += Math.abs(m.totalCost || 0);
    }

    let todayStockOutValue = 0;
    let todayStockOutQuantity = 0;
    for (const m of todayOutMovements) {
      todayStockOutQuantity += Math.abs(m.quantityDeltaBaseUnits || 0);
      todayStockOutValue += Math.abs(m.totalCost || 0);
    }

    // Top consumed materials this week/month
    const startOfWeek = new Date();
    startOfWeek.setDate(startOfWeek.getDate() - 7);
    startOfWeek.setHours(0, 0, 0, 0);

    const topConsumedAgg = await InventoryMovement.aggregate([
      {
        $match: {
          businessId: new mongoose.Types.ObjectId(businessId),
          movementType: 'sale_consumption',
          createdAt: { $gte: startOfWeek },
        },
      },
      {
        $group: {
          _id: '$materialId',
          materialName: { $first: '$materialName' },
          totalConsumedBaseUnits: { $sum: { $abs: '$quantityDeltaBaseUnits' } },
          totalCost: { $sum: '$totalCost' },
        },
      },
      { $sort: { totalConsumedBaseUnits: -1 } },
      { $limit: 5 },
    ]);

    return {
      totalInventoryValue: Math.round(totalInventoryValue * 100) / 100,
      totalRawMaterials: materials.length,
      lowStockCount,
      outOfStockCount,
      todayStockInValue: Math.round(todayStockInValue * 100) / 100,
      todayStockInQuantity: Math.round(todayStockInQuantity * 100) / 100,
      todayStockOutValue: Math.round(todayStockOutValue * 100) / 100,
      todayStockOutQuantity: Math.round(todayStockOutQuantity * 100) / 100,
      lowStockAlerts: lowStockAlerts.slice(0, 8),
      recentTransactions: recentMovements,
      topConsumed: topConsumedAgg,
    };
  }

  /**
   * Comprehensive Stock Report with Stock Status & Valuations
   */
  async getStockReport(businessId, { category, search } = {}) {
    const query = { businessId, isActive: true };
    if (category && category !== 'All') query.category = category;
    if (search && search.trim()) {
      const reg = new RegExp(search.trim(), 'i');
      query.$or = [{ name: reg }, { sku: reg }];
    }

    const materials = await RawMaterial.find(query).sort({ category: 1, name: 1 });

    const report = materials.map((m) => {
      const stock = Number(m.currentStock) || 0;
      const minStock = Number(m.minimumStock) || 0;
      const costPerBase = Number(m.costPerBaseUnit) || 0;
      const valuation = Math.round(stock * costPerBase * 100) / 100;

      let status = 'Healthy';
      if (stock <= 0) status = 'Out of Stock';
      else if (stock <= minStock) status = 'Low Stock';

      return {
        id: m._id,
        sku: m.sku,
        name: m.name,
        category: m.category,
        currentStock: stock,
        baseUnit: m.baseUnit,
        purchaseUnit: m.purchaseUnit,
        conversionFactor: m.conversionFactor,
        minimumStock: minStock,
        costPerBaseUnit: costPerBase,
        averageUnitCost: m.averageUnitCost,
        valuation,
        status,
        inventoryMode: m.inventoryMode,
        preferredSupplier: m.preferredSupplier,
      };
    });

    const totalValuation = report.reduce((sum, item) => sum + item.valuation, 0);

    return {
      report,
      totalValuation: Math.round(totalValuation * 100) / 100,
      itemCount: report.length,
    };
  }

  /**
   * Filterable Stock Movement Ledger Report
   */
  async getMovementsLedger(businessId, { materialId, movementType, startDate, endDate, limit = 100, page = 1 } = {}) {
    const query = { businessId };

    if (materialId) query.materialId = materialId;
    if (movementType && movementType !== 'All') query.movementType = movementType;

    if (startDate || endDate) {
      query.createdAt = {};
      if (startDate) query.createdAt.$gte = new Date(startDate);
      if (endDate) {
        const end = new Date(endDate);
        end.setHours(23, 59, 59, 999);
        query.createdAt.$lte = end;
      }
    }

    const skip = (Math.max(1, Number(page)) - 1) * Number(limit);
    const [movements, total] = await Promise.all([
      InventoryMovement.find(query).sort({ createdAt: -1 }).skip(skip).limit(Number(limit)),
      InventoryMovement.countDocuments(query),
    ]);

    return { movements, total, page: Number(page), limit: Number(limit) };
  }

  /**
   * Recipe & Product Analytics Report (Food Cost %, Contribution)
   */
  async getProductAnalytics(businessId) {
    const recipes = await Recipe.find({ businessId, isActive: true }).sort({ foodCostPercentage: -1 });

    const analytics = recipes.map((r) => {
      const foodCost = Number(r.totalFoodCost) || 0;
      const sellingPrice = Number(r.sellingPrice) || 0;
      const profitMargin = sellingPrice - foodCost;
      const foodCostPercentage = Number(r.foodCostPercentage) || (sellingPrice > 0 ? (foodCost / sellingPrice) * 100 : 0);

      return {
        recipeId: r._id,
        productId: r.productId,
        productName: r.productName,
        recipeName: r.recipeName,
        variantName: r.variantName,
        servingSize: r.servingSize,
        ingredientCount: r.ingredients ? r.ingredients.length : 0,
        totalFoodCost: Math.round(foodCost * 100) / 100,
        sellingPrice: Math.round(sellingPrice * 100) / 100,
        profitMargin: Math.round(profitMargin * 100) / 100,
        foodCostPercentage: Math.round(foodCostPercentage * 10) / 10,
        costHealth: foodCostPercentage <= 30 ? 'Excellent' : foodCostPercentage <= 40 ? 'Moderate' : 'High Cost',
      };
    });

    return analytics;
  }

  /**
   * Daily Closing Stock Reconciliation:
   * Expected Closing Stock = Opening Stock + Stock In - Sales Consumption - Stock Out ± Adjustments
   */
  async getClosingStockSummary(businessId, { date } = {}) {
    const targetDate = date ? new Date(date) : new Date();
    const startOfDay = new Date(targetDate);
    startOfDay.setHours(0, 0, 0, 0);
    const endOfDay = new Date(targetDate);
    endOfDay.setHours(23, 59, 59, 999);

    const materials = await RawMaterial.find({ businessId, isActive: true });
    const movements = await InventoryMovement.find({
      businessId,
      createdAt: { $gte: startOfDay, $lte: endOfDay },
    });

    const summaryByMaterial = {};

    materials.forEach((m) => {
      summaryByMaterial[m._id.toString()] = {
        materialId: m._id,
        sku: m.sku,
        name: m.name,
        baseUnit: m.baseUnit,
        currentStock: m.currentStock,
        stockIn: 0,
        salesConsumption: 0,
        manualStockOut: 0,
        adjustments: 0,
      };
    });

    movements.forEach((mov) => {
      const entry = summaryByMaterial[mov.materialId.toString()];
      if (!entry) return;

      const delta = mov.quantityDeltaBaseUnits || 0;
      if (mov.movementType === 'purchase_receipt') {
        entry.stockIn += delta;
      } else if (mov.movementType === 'sale_consumption') {
        entry.salesConsumption += Math.abs(delta);
      } else if (mov.movementType === 'stock_out' || mov.movementType === 'wastage') {
        entry.manualStockOut += Math.abs(delta);
      } else if (mov.movementType === 'inventory_adjustment') {
        entry.adjustments += delta;
      }
    });

    return Object.values(summaryByMaterial);
  }
}

module.exports = new InventoryService();
