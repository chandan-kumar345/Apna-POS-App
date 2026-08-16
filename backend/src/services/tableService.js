const Table = require('../models/Table');
const ApiError = require('../utils/ApiError');

class TableService {
  async getTables(businessId) {
    let tables = await Table.find({ businessId }).sort({ tableNumber: 1 });

    // Seed default clean tables if empty
    if (tables.length === 0) {
      const defaultTables = [];
      for (let i = 1; i <= 12; i++) {
        defaultTables.push({
          businessId,
          tableNumber: i,
          name: `T-${i}`,
          floor: 'Ground Floor',
          capacity: i <= 4 ? 2 : i <= 8 ? 4 : 6,
          status: 'free',
        });
      }
      tables = await Table.insertMany(defaultTables);
    }

    return tables;
  }

  async createTable(businessId, { tableNumber, name, floor, capacity }) {
    const existing = await Table.findOne({ businessId, tableNumber });
    if (existing) {
      throw ApiError.conflict(`Table number ${tableNumber} already exists`);
    }

    const table = await Table.create({
      businessId,
      tableNumber,
      name: name || `T-${tableNumber}`,
      floor: floor || 'Ground Floor',
      capacity: capacity || 4,
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
