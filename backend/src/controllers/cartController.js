const cartService = require('../services/cartService');

class CartController {
  async getCart(req, res, next) {
    try {
      const businessId = req.business._id;
      const { tableNumber, orderType } = req.query;

      const cart = await cartService.getCart(businessId, { tableNumber, orderType });

      return res.status(200).json({
        status: 'success',
        data: { cart },
      });
    } catch (err) {
      next(err);
    }
  }

  async addToCart(req, res, next) {
    try {
      const businessId = req.business._id;
      const { tableNumber, orderType, product, quantity, variantName } = req.body;

      if (!product || (!product.productId && !product.id && !product._id && !product.name)) {
        return res.status(400).json({
          status: 'fail',
          message: 'Valid product data is required to add to cart',
        });
      }

      const cart = await cartService.addToCart(businessId, {
        tableNumber,
        orderType,
        product,
        quantity: quantity || 1,
        variantName,
      });

      return res.status(200).json({
        status: 'success',
        message: 'Product added to cart successfully',
        data: { cart },
      });
    } catch (err) {
      next(err);
    }
  }

  async reduceProductFromCart(req, res, next) {
    try {
      const businessId = req.business._id;
      const { tableNumber, orderType, productId, variantName, quantity } = req.body;

      if (!productId) {
        return res.status(400).json({
          status: 'fail',
          message: 'productId is required to reduce product from cart',
        });
      }

      const cart = await cartService.reduceProductFromCart(businessId, {
        tableNumber,
        orderType,
        productId,
        variantName,
        quantity: quantity || 1,
      });

      return res.status(200).json({
        status: 'success',
        message: 'Product reduced from cart successfully',
        data: { cart },
      });
    } catch (err) {
      next(err);
    }
  }

  async removeItemFromCart(req, res, next) {
    try {
      const businessId = req.business._id;
      const { tableNumber, orderType, productId, variantName } = req.body;

      if (!productId) {
        return res.status(400).json({
          status: 'fail',
          message: 'productId is required to remove item from cart',
        });
      }

      const cart = await cartService.removeItemFromCart(businessId, {
        tableNumber,
        orderType,
        productId,
        variantName,
      });

      return res.status(200).json({
        status: 'success',
        message: 'Item removed from cart successfully',
        data: { cart },
      });
    } catch (err) {
      next(err);
    }
  }

  async syncCart(req, res, next) {
    try {
      const businessId = req.business._id;
      const { tableNumber, orderType, items } = req.body;

      const cart = await cartService.syncCart(businessId, {
        tableNumber,
        orderType,
        items: items || [],
      });

      return res.status(200).json({
        status: 'success',
        message: 'Cart synchronized successfully',
        data: { cart },
      });
    } catch (err) {
      next(err);
    }
  }

  async clearCart(req, res, next) {
    try {
      const businessId = req.business._id;
      const { tableNumber, orderType } = req.body;

      const cart = await cartService.clearCart(businessId, { tableNumber, orderType });

      return res.status(200).json({
        status: 'success',
        message: 'Cart cleared successfully',
        data: { cart },
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new CartController();
