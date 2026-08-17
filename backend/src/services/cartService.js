const Cart = require('../models/Cart');

class CartService {
  /**
   * Get active cart for a specific table or order type
   */
  async getCart(businessId, { tableNumber = '', orderType = 'dineIn' } = {}) {
    let cart = await Cart.findOne({
      businessId,
      tableNumber: tableNumber ? tableNumber.trim() : '',
      orderType: orderType || 'dineIn',
    });

    if (!cart) {
      cart = new Cart({
        businessId,
        tableNumber: tableNumber ? tableNumber.trim() : '',
        orderType: orderType || 'dineIn',
        items: [],
      });
      cart.recalculateTotals();
      await cart.save();
    }

    return cart;
  }

  /**
   * Add a product / variant to the active cart (increments quantity if already present)
   */
  async addToCart(businessId, {
    tableNumber = '',
    orderType = 'dineIn',
    product = {},
    quantity = 1,
    variantName = '',
  } = {}) {
    const qty = Math.max(1, parseInt(quantity, 10) || 1);
    const tbl = tableNumber ? tableNumber.trim() : '';
    const oType = orderType || 'dineIn';

    let cart = await Cart.findOne({
      businessId,
      tableNumber: tbl,
      orderType: oType,
    });

    if (!cart) {
      cart = new Cart({
        businessId,
        tableNumber: tbl,
        orderType: oType,
        items: [],
      });
    }

    const prodId = (product.productId || product.id || product._id || '').toString();
    const vName = (variantName || product.variantName || '').toString().trim();
    const regularPrice = parseFloat(product.price) || 0;
    const discountPct = parseFloat(product.discountPercent || product.discount) || 0;
    const hasDisc = product.hasDiscount === true || discountPct > 0;
    let saleP = product.salePrice != null ? parseFloat(product.salePrice) : null;
    if (hasDisc && discountPct > 0 && (saleP == null || saleP <= 0)) {
      saleP = Math.round(regularPrice * (1 - discountPct / 100) * 100) / 100;
    }
    const effPrice = hasDisc && saleP != null && saleP > 0 ? saleP : regularPrice;

    // Check if matching item (same productId and variantName) already in cart
    const existingIndex = cart.items.findIndex(
      (item) => item.productId === prodId && item.variantName === vName
    );

    if (existingIndex >= 0) {
      cart.items[existingIndex].quantity += qty;
      cart.items[existingIndex].price = regularPrice;
      cart.items[existingIndex].salePrice = saleP;
      cart.items[existingIndex].effectivePrice = effPrice;
      cart.items[existingIndex].hasDiscount = hasDisc;
      cart.items[existingIndex].discountPercent = discountPct;
    } else {
      cart.items.push({
        productId: prodId,
        name: (product.name || product.title || 'Product').toString().trim(),
        price: regularPrice,
        salePrice: saleP,
        effectivePrice: effPrice,
        hasDiscount: hasDisc,
        discountPercent: discountPct,
        variantName: vName,
        quantity: qty,
        foodType: (product.foodType || product.itemType || 'veg').toString().toLowerCase().replace('-', '_'),
        imageUrl: (product.imageUrl || product.image || '').toString(),
      });
    }

    cart.recalculateTotals();
    await cart.save();
    return cart;
  }

  /**
   * Reduce quantity of a product / variant in the cart.
   * If quantity reaches 0, the item is removed.
   */
  async reduceProductFromCart(businessId, {
    tableNumber = '',
    orderType = 'dineIn',
    productId = '',
    variantName = '',
    quantity = 1,
  } = {}) {
    const qty = Math.max(1, parseInt(quantity, 10) || 1);
    const tbl = tableNumber ? tableNumber.trim() : '';
    const oType = orderType || 'dineIn';
    const prodId = (productId || '').toString().trim();
    const vName = (variantName || '').toString().trim();

    let cart = await Cart.findOne({
      businessId,
      tableNumber: tbl,
      orderType: oType,
    });

    if (!cart) {
      cart = new Cart({
        businessId,
        tableNumber: tbl,
        orderType: oType,
        items: [],
      });
      cart.recalculateTotals();
      await cart.save();
      return cart;
    }

    const existingIndex = cart.items.findIndex(
      (item) => item.productId === prodId && item.variantName === vName
    );

    if (existingIndex >= 0) {
      cart.items[existingIndex].quantity -= qty;
      if (cart.items[existingIndex].quantity <= 0) {
        cart.items.splice(existingIndex, 1);
      }
    }

    cart.recalculateTotals();
    await cart.save();
    return cart;
  }

  /**
   * Remove an item completely from the active cart
   */
  async removeItemFromCart(businessId, {
    tableNumber = '',
    orderType = 'dineIn',
    productId = '',
    variantName = '',
  } = {}) {
    const tbl = tableNumber ? tableNumber.trim() : '';
    const oType = orderType || 'dineIn';
    const prodId = (productId || '').toString().trim();
    const vName = (variantName || '').toString().trim();

    let cart = await Cart.findOne({
      businessId,
      tableNumber: tbl,
      orderType: oType,
    });

    if (!cart) {
      cart = new Cart({
        businessId,
        tableNumber: tbl,
        orderType: oType,
        items: [],
      });
      cart.recalculateTotals();
      await cart.save();
      return cart;
    }

    cart.items = cart.items.filter(
      (item) => !(item.productId === prodId && item.variantName === vName)
    );

    cart.recalculateTotals();
    await cart.save();
    return cart;
  }

  /**
   * Sync full list of cart items in batch from frontend
   */
  async syncCart(businessId, {
    tableNumber = '',
    orderType = 'dineIn',
    items = [],
  } = {}) {
    const tbl = tableNumber ? tableNumber.trim() : '';
    const oType = orderType || 'dineIn';

    let cart = await Cart.findOne({
      businessId,
      tableNumber: tbl,
      orderType: oType,
    });

    if (!cart) {
      cart = new Cart({
        businessId,
        tableNumber: tbl,
        orderType: oType,
        items: [],
      });
    }

    cart.items = (items || []).map((item) => {
      const prodId = (item.productId || item.id || item._id || '').toString();
      const vName = (item.variantName || '').toString().trim();
      const regularPrice = parseFloat(item.price) || 0;
      const discountPct = parseFloat(item.discountPercent || item.discount) || 0;
      const hasDisc = item.hasDiscount === true || discountPct > 0;
      let saleP = item.salePrice != null ? parseFloat(item.salePrice) : null;
      if (hasDisc && discountPct > 0 && (saleP == null || saleP <= 0)) {
        saleP = Math.round(regularPrice * (1 - discountPct / 100) * 100) / 100;
      }
      const effPrice = hasDisc && saleP != null && saleP > 0 ? saleP : regularPrice;

      return {
        productId: prodId,
        name: (item.name || item.title || 'Product').toString().trim(),
        price: regularPrice,
        salePrice: saleP,
        effectivePrice: effPrice,
        hasDiscount: hasDisc,
        discountPercent: discountPct,
        variantName: vName,
        quantity: Math.max(1, parseInt(item.quantity, 10) || 1),
        foodType: (item.foodType || item.itemType || 'veg').toString().toLowerCase().replace('-', '_'),
        imageUrl: (item.imageUrl || item.image || '').toString(),
      };
    });

    cart.recalculateTotals();
    await cart.save();
    return cart;
  }

  /**
   * Clear all items from the active cart
   */
  async clearCart(businessId, { tableNumber = '', orderType = 'dineIn' } = {}) {
    const tbl = tableNumber ? tableNumber.trim() : '';
    const oType = orderType || 'dineIn';

    let cart = await Cart.findOne({
      businessId,
      tableNumber: tbl,
      orderType: oType,
    });

    if (cart) {
      cart.items = [];
      cart.recalculateTotals();
      await cart.save();
      return cart;
    }

    cart = new Cart({
      businessId,
      tableNumber: tbl,
      orderType: oType,
      items: [],
    });
    cart.recalculateTotals();
    await cart.save();
    return cart;
  }
}

module.exports = new CartService();
