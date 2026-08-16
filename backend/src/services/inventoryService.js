const Inventory = require('../models/Inventory');
const ApiError = require('../utils/ApiError');

class InventoryService {
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
    const item = await Inventory.create({
      ...data,
      businessId,
    });
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
}

module.exports = new InventoryService();
