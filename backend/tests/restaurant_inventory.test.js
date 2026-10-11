require('./setup');
const mongoose = require('mongoose');
const inventoryService = require('../src/services/inventoryService');
const RawMaterial = require('../src/models/RawMaterial');
const Recipe = require('../src/models/Recipe');
const InventoryMovement = require('../src/models/InventoryMovement');
const StockReceipt = require('../src/models/StockReceipt');
const StockCount = require('../src/models/StockCount');

describe('Restaurant Inventory Management System', () => {
  const businessId = new mongoose.Types.ObjectId();

  it('Mode A: creates raw materials and recipes, and automatically deducts stock on POS order with idempotency', async () => {
    // 1. Create Raw Materials (Paneer, Butter, Cream, Tomato)
    const paneer = await inventoryService.createRawMaterial(businessId, {
      sku: 'RM-PAN-01',
      name: 'Paneer',
      category: 'Dairy',
      baseUnit: 'g',
      purchaseUnit: 'kg',
      conversionFactor: 1000,
      openingStock: 10000, // 10,000 g (10 kg)
      minimumStock: 2000,
      averageUnitCost: 320, // 320 INR / kg => 0.32 INR / g
    });

    const butter = await inventoryService.createRawMaterial(businessId, {
      sku: 'RM-BUT-01',
      name: 'Butter',
      category: 'Dairy',
      baseUnit: 'g',
      purchaseUnit: 'kg',
      conversionFactor: 1000,
      openingStock: 5000, // 5,000 g (5 kg)
      minimumStock: 1000,
      averageUnitCost: 500, // 500 INR / kg => 0.50 INR / g
    });

    expect(paneer.currentStock).toBe(10000);
    expect(paneer.costPerBaseUnit).toBe(0.32);
    expect(butter.currentStock).toBe(5000);
    expect(butter.costPerBaseUnit).toBe(0.50);

    // Verify initial opening stock movements
    const paneerMovements = await InventoryMovement.find({ businessId, materialId: paneer._id });
    expect(paneerMovements.length).toBe(1);
    expect(paneerMovements[0].movementType).toBe('opening_stock');
    expect(paneerMovements[0].quantityDeltaBaseUnits).toBe(10000);

    // 2. Create Recipe for "Paneer Butter Masala"
    // Per portion: 200g Paneer, 100g Butter
    const productId = new mongoose.Types.ObjectId();
    const recipe = await inventoryService.createRecipe(businessId, {
      productId,
      productName: 'Paneer Butter Masala',
      recipeName: 'Paneer Butter Masala Standard',
      servingSize: 1,
      sellingPrice: 350,
      ingredients: [
        {
          materialId: paneer._id,
          quantity: 200,
          unit: 'g',
          preparationLossPercent: 0,
        },
        {
          materialId: butter._id,
          quantity: 100,
          unit: 'g',
          preparationLossPercent: 0,
        },
      ],
    });

    expect(recipe).toBeDefined();
    // 200g * 0.32 = 64 INR + 100g * 0.50 = 50 INR => 114 INR food cost
    expect(recipe.totalFoodCost).toBe(114);
    // (114 / 350) * 100 = 32.57%
    expect(recipe.foodCostPercentage).toBeCloseTo(32.57, 1);

    // 3. Simulate POS Order: 5 portions of Paneer Butter Masala sold
    const orderId = new mongoose.Types.ObjectId();
    const order = {
      _id: orderId,
      orderNumber: 'POS-1001',
      status: 'completed',
      items: [
        {
          productId,
          name: 'Paneer Butter Masala',
          quantity: 5,
          price: 350,
        },
      ],
    };

    const deductionResult = await inventoryService.deductRecipeInventoryForOrder(businessId, order);
    expect(deductionResult.deducted).toBe(true);

    // 5 portions * 200g = 1,000g Paneer deduction -> 9,000g remaining
    const updatedPaneer = await RawMaterial.findById(paneer._id);
    expect(updatedPaneer.currentStock).toBe(9000);

    // 5 portions * 100g = 500g Butter deduction -> 4,500g remaining
    const updatedButter = await RawMaterial.findById(butter._id);
    expect(updatedButter.currentStock).toBe(4500);

    // Verify sale consumption movement in ledger
    const saleMovements = await InventoryMovement.find({
      businessId,
      sourceId: orderId.toString(),
      movementType: 'sale_consumption',
    });
    expect(saleMovements.length).toBe(2);
    const pMovement = saleMovements.find((m) => m.materialName === 'Paneer');
    expect(pMovement.quantityDeltaBaseUnits).toBe(-1000);
    expect(pMovement.balanceAfterBaseUnits).toBe(9000);

    // 4. Test Idempotency: re-running deduction for the same order should skip without double deducting
    const duplicateDeduction = await inventoryService.deductRecipeInventoryForOrder(businessId, order);
    expect(duplicateDeduction.skipped).toBe(true);

    const paneerAfterDuplicate = await RawMaterial.findById(paneer._id);
    expect(paneerAfterDuplicate.currentStock).toBe(9000); // Remained 9000, not 8000!
  });

  it('Mode B: records stock-in purchases with weighted average cost calculation', async () => {
    // Start with 10 kg (10,000 g) Paneer at 320 INR / kg (0.32 / g)
    const paneer = await inventoryService.createRawMaterial(businessId, {
      sku: 'RM-PAN-02',
      name: 'Paneer Batch 2',
      category: 'Dairy',
      baseUnit: 'g',
      purchaseUnit: 'kg',
      conversionFactor: 1000,
      openingStock: 10000,
      averageUnitCost: 320,
    });

    // Purchase 5 kg (5,000 g) at 350 INR / kg (total 1,750 INR)
    const receipt = await inventoryService.recordStockIn(businessId, {
      supplierName: 'Dairy Pure Farm',
      invoiceNumber: 'INV-DP-55',
      items: [
        {
          materialId: paneer._id,
          purchaseQuantity: 5,
          purchaseUnit: 'kg',
          conversionFactor: 1000,
          unitCost: 350,
        },
      ],
    });

    expect(receipt).toBeDefined();
    expect(receipt.totalAmount).toBe(1750);

    const updated = await RawMaterial.findById(paneer._id);
    // Total stock: 10,000g + 5,000g = 15,000g (15 kg)
    expect(updated.currentStock).toBe(15000);

    // Previous valuation = 10,000 * 0.32 = 3200 INR. New purchase = 1750 INR. Total = 4950 INR.
    // New cost per gram = 4950 / 15,000 = 0.33 INR / g => 330 INR / kg average cost
    expect(updated.costPerBaseUnit).toBeCloseTo(0.33, 2);
    expect(updated.averageUnitCost).toBeCloseTo(330, 1);
  });

  it('records stock-out for kitchen wastage and logs movement', async () => {
    const paneer = await inventoryService.createRawMaterial(businessId, {
      sku: 'RM-PAN-03',
      name: 'Paneer Spoilage Test',
      baseUnit: 'g',
      purchaseUnit: 'kg',
      conversionFactor: 1000,
      openingStock: 5000,
      averageUnitCost: 300,
    });

    // Spoilage of 500g
    const result = await inventoryService.recordStockOut(businessId, {
      materialId: paneer._id,
      quantity: 500,
      unit: 'g',
      movementType: 'wastage',
      reason: 'Spoiled due to refrigerator breakdown',
    });

    expect(result.material.currentStock).toBe(4500);
    expect(result.movement.movementType).toBe('wastage');
    expect(result.movement.quantityDeltaBaseUnits).toBe(-500);
  });

  it('records physical stock count and calculates variance accurately', async () => {
    const paneer = await inventoryService.createRawMaterial(businessId, {
      sku: 'RM-PAN-04',
      name: 'Paneer Count Test',
      baseUnit: 'g',
      purchaseUnit: 'kg',
      conversionFactor: 1000,
      openingStock: 10000,
      averageUnitCost: 300,
    });

    // Physical count found 9,800g instead of 10,000g (deficit of -200g)
    const count = await inventoryService.recordPhysicalStockCount(businessId, {
      items: [
        {
          materialId: paneer._id,
          actualQuantity: 9800,
          unit: 'g',
          reason: 'Weekly Sunday physical count',
        },
      ],
    });

    expect(count.items[0].expectedBaseUnits).toBe(10000);
    expect(count.items[0].actualBaseUnits).toBe(9800);
    expect(count.items[0].varianceBaseUnits).toBe(-200);

    const updated = await RawMaterial.findById(paneer._id);
    expect(updated.currentStock).toBe(9800);
  });

  it('generates accurate dashboard summary and stock report', async () => {
    const mat = await inventoryService.createRawMaterial(businessId, {
      sku: 'RM-REPORT-01',
      name: 'Basmati Rice Premium',
      baseUnit: 'g',
      purchaseUnit: 'kg',
      conversionFactor: 1000,
      openingStock: 25000, // 25kg
      minimumStock: 5000,
      averageUnitCost: 100, // 100/kg => 0.1/g
    });

    const summary = await inventoryService.getDashboardSummary(businessId);
    expect(summary.totalRawMaterials).toBeGreaterThan(0);
    expect(summary.totalInventoryValue).toBeGreaterThan(0);

    const report = await inventoryService.getStockReport(businessId);
    expect(report.itemCount).toBeGreaterThan(0);
    expect(report.totalValuation).toBeGreaterThan(0);
  });

  it('exposes HTTP REST API endpoints for inventory dashboard, materials, and recipes', async () => {
    const request = require('supertest');
    const app = require('../src/app');

    // Register a tenant user
    const authRes = await request(app)
      .post('/api/v1/auth/register')
      .send({
        email: `inventory_chef_${Date.now()}@apnapos.com`,
        password: 'Password@123',
        restaurantName: 'Grand Spice Palace',
      });

    const token = authRes.body.data.accessToken;
    expect(token).toBeDefined();

    // 1. Create Raw Material via REST API
    const createMatRes = await request(app)
      .post('/api/v1/inventory/raw-materials')
      .set('Authorization', `Bearer ${token}`)
      .send({
        sku: 'RM-REST-01',
        name: 'Cow Milk Pure',
        category: 'Dairy',
        baseUnit: 'ml',
        purchaseUnit: 'L',
        conversionFactor: 1000,
        openingStock: 20000, // 20 L
        minimumStock: 5000,
        averageUnitCost: 60,
      });

    expect(createMatRes.status).toBe(201);
    expect(createMatRes.body.success).toBe(true);
    expect(createMatRes.body.data.material.sku).toBe('RM-REST-01');

    // 2. Fetch raw materials list
    const getMatRes = await request(app)
      .get('/api/v1/inventory/raw-materials')
      .set('Authorization', `Bearer ${token}`);

    expect(getMatRes.status).toBe(200);
    expect(getMatRes.body.data.materials.length).toBeGreaterThanOrEqual(1);

    // 3. Fetch dashboard summary
    const summaryRes = await request(app)
      .get('/api/v1/inventory/dashboard-summary')
      .set('Authorization', `Bearer ${token}`);

    expect(summaryRes.status).toBe(200);
    expect(summaryRes.body.data.totalRawMaterials).toBeGreaterThanOrEqual(1);
  });
});
