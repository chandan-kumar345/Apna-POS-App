const Table = require('../models/Table');
const Business = require('../models/Business');
const ApiError = require('../utils/ApiError');

class TableService {
  async getTables(businessId) {
    let tables = await Table.find({ businessId }).sort({ tableNumber: 1 });

    const business = await Business.findById(businessId);
    const configuredCount = business?.orderSettings?.tableCount && business.orderSettings.tableCount > 0
      ? business.orderSettings.tableCount
      : 12;

    // Seed default clean tables if empty
    if (tables.length === 0) {
      const defaultTables = [];
      for (let i = 1; i <= configuredCount; i++) {
        defaultTables.push({
          businessId,
          tableNumber: i,
          name: `T-${i}`,
          floor: i <= 8 ? 'Ground Floor' : '1st Floor',
          capacity: i <= 4 ? 2 : i <= 8 ? 4 : 6,
          status: 'free',
        });
      }
      tables = await Table.insertMany(defaultTables);
    } else if (tables.length < configuredCount) {
      // If user configured more tables than currently in DB, seamlessly create the missing ones
      const existingMax = tables.length > 0 ? (tables[tables.length - 1].tableNumber || tables.length) : 0;
      let maxNum = existingMax;
      const additionalTables = [];
      for (let i = tables.length + 1; i <= configuredCount; i++) {
        maxNum++;
        additionalTables.push({
          businessId,
          tableNumber: maxNum,
          name: `T-${maxNum}`,
          floor: maxNum <= 8 ? 'Ground Floor' : '1st Floor',
          capacity: maxNum <= 4 ? 2 : maxNum <= 8 ? 4 : 6,
          status: 'free',
        });
      }
      if (additionalTables.length > 0) {
        await Table.insertMany(additionalTables);
        tables = await Table.find({ businessId }).sort({ tableNumber: 1 });
      }
    }

    return tables;
  }

  /**
   * Sync table count when user changes tableCount in onboarding or business settings
   */
  async syncBusinessTableCount(businessId, targetCount) {
    const count = Math.max(0, parseInt(targetCount, 10) || 0);
    if (count <= 0) return await Table.find({ businessId }).sort({ tableNumber: 1 });

    let existingTables = await Table.find({ businessId }).sort({ tableNumber: 1 });
    const currentCount = existingTables.length;

    if (currentCount < count) {
      // Add missing tables
      let maxNum = currentCount > 0 ? (existingTables[existingTables.length - 1].tableNumber || currentCount) : 0;
      const newTables = [];
      for (let i = currentCount + 1; i <= count; i++) {
        maxNum++;
        newTables.push({
          businessId,
          tableNumber: maxNum,
          name: `T-${maxNum}`,
          floor: maxNum <= 8 ? 'Ground Floor' : '1st Floor',
          capacity: maxNum <= 4 ? 2 : maxNum <= 8 ? 4 : 6,
          status: 'free',
        });
      }
      if (newTables.length > 0) {
        await Table.insertMany(newTables);
      }
    } else if (currentCount > count) {
      // Remove excess tables only if they are free (no running orders)
      const excess = currentCount - count;
      const freeExcess = existingTables
        .slice(count)
        .filter((t) => t.status === 'free');
      
      const idsToDelete = freeExcess.slice(0, excess).map((t) => t._id);
      if (idsToDelete.length > 0) {
        await Table.deleteMany({ _id: { $in: idsToDelete }, businessId });
      }
    }

    // Update orderSettings.tableCount on Business model
    await Business.findByIdAndUpdate(businessId, {
      $set: { 'orderSettings.tableCount': count },
    });

    return await Table.find({ businessId }).sort({ tableNumber: 1 });
  }

  async createTable(businessId, { tableNumber, name, floor, capacity, count = 1 }) {
    const qty = Math.max(1, parseInt(count, 10) || 1);
    
    // Find current highest tableNumber for this business
    const allTables = await Table.find({ businessId }).sort({ tableNumber: -1 });
    let maxNum = allTables.length > 0 ? (allTables[0].tableNumber || allTables.length) : 0;

    if (qty > 1) {
      const createdList = [];
      for (let i = 1; i <= qty; i++) {
        maxNum++;
        const baseName = name ? name.trim() : 'T';
        const tName = baseName.includes('-') || baseName.includes(' ') ? `${baseName}-${maxNum}` : `${baseName}-${maxNum}`;
        const newT = await Table.create({
          businessId,
          tableNumber: maxNum,
          name: tName,
          floor: floor || 'Ground Floor',
          capacity: capacity || 4,
          status: 'free',
        });
        createdList.push(newT);
      }
      return createdList;
    }

    // Single Table Creation
    let num = parseInt(tableNumber, 10);
    if (!num || isNaN(num)) {
      num = maxNum + 1;
    } else {
      const existing = await Table.findOne({ businessId, tableNumber: num });
      if (existing) {
        num = maxNum + 1;
      }
    }

    const table = await Table.create({
      businessId,
      tableNumber: num,
      name: name || `T-${num}`,
      floor: floor || 'Ground Floor',
      capacity: capacity || 4,
      status: 'free',
    });

    return table;
  }

  async updateTable(businessId, tableId, data) {
    const table = await Table.findOneAndUpdate(
      { _id: tableId, businessId },
      { $set: data },
      { new: true, runValidators: true }
    );

    if (!table) {
      throw ApiError.notFound('Table not found');
    }

    return table;
  }

  async updateTableStatus(businessId, tableId, { status, currentOrderId }) {
    const update = { status };
    if (status === 'occupied') {
      update.occupiedSince = new Date();
      if (currentOrderId) update.currentOrderId = currentOrderId;
    } else if (status === 'free') {
      update.occupiedSince = null;
      update.currentOrderId = null;
    }

    const table = await Table.findOneAndUpdate(
      { _id: tableId, businessId },
      { $set: update },
      { new: true }
    );

    if (!table) {
      throw ApiError.notFound('Table not found');
    }

    return table;
  }

  async deleteTable(businessId, tableId) {
    const table = await Table.findOneAndDelete({ _id: tableId, businessId });
    if (!table) {
      throw ApiError.notFound('Table not found');
    }
    return { id: tableId, message: 'Table removed' };
  }
}

module.exports = new TableService();
