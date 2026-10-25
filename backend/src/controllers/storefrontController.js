const Business = require('../models/Business');
const Product = require('../models/Product');
const Category = require('../models/Category');
const Extra = require('../models/Extra');
const Order = require('../models/Order');
const ApiResponse = require('../utils/ApiResponse');
const ApiError = require('../utils/ApiError');

function slugify(text) {
  if (!text) return 'store';
  return text
    .toString()
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '') || 'store';
}

class StorefrontController {
  async getStorefront(req, res, next) {
    try {
      const rawSlug = (req.params.slug || '').trim().toLowerCase();
      if (!rawSlug) {
        throw new ApiError(400, 'Storefront slug is required');
      }

      // 1. Find business by slug or company name
      let business = await Business.findOne({
        $or: [
          { 'profile.slug': rawSlug },
          { slug: rawSlug },
          { 'profile.companyName': { $regex: new RegExp(`^${rawSlug.replace(/-/g, ' ')}$`, 'i') } },
        ],
      }).lean();

      // Fallback: try by ObjectId
      if (!business && /^[0-9a-fA-F]{24}$/.test(rawSlug)) {
        business = await Business.findById(rawSlug).lean();
      }

      // If still not found, check if any business exists to provide fallback preview data
      if (!business) {
        business = await Business.findOne().lean();
      }

      const businessId = business ? business._id : null;

      // 2. Fetch categories & products
      let categories = [];
      let products = [];
      let addons = [];

      if (businessId) {
        [categories, products, addons] = await Promise.all([
          Category.find({ businessId, isActive: { $ne: false } }).sort({ sortOrder: 1, name: 1 }).lean(),
          Product.find({ businessId, isAvailable: { $ne: false } }).sort({ createdAt: -1 }).lean(),
          Extra.find({ businessId, isAvailable: { $ne: false }, type: { $in: ['addon', 'extra'] } }).lean(),
        ]);
      }

      // Default fallback categories if empty
      const categoryNames = categories.length > 0 
        ? categories.map(c => c.name) 
        : (products.length > 0 
            ? [...new Set(products.map(p => p.category || 'General'))] 
            : ['Pizzas', 'Burgers', 'Pastas', 'Sides', 'Beverages']);

      // Formatted restaurant profile
      const restaurant = {
        id: business?._id?.toString() || 'store_preview',
        name: business?.profile?.companyName || business?.profile?.name || 'Pizza 47',
        companyName: business?.profile?.companyName || 'Pizza 47',
        slug: rawSlug,
        tagline: business?.profile?.tagline || 'Pizzas • Burgers • Fast Food',
        cuisineType: business?.business?.businessType || 'Pizzas • Burgers • Fast Food',
        phone: business?.profile?.phone || '+91 98765 43210',
        address: business?.address?.addressLine 
          ? `${business.address.addressLine}, ${business.address.city || ''}`.trim() 
          : 'Sector 62, Noida',
        logoUrl: business?.profile?.profileImage || '',
        currencySymbol: business?.business?.currency === 'USD' ? '$' : '₹',
        rating: 4.6,
        reviewCount: '1.2k+',
        status: 'Open',
        openingTime: '10:00 AM',
        closingTime: '11:00 PM',
        deliveryBaseCharge: business?.orderSettings?.deliverySettings?.baseCharge || 0,
        deliveryChargePerKm: business?.orderSettings?.deliverySettings?.chargePerKm || 0,
        freeDeliveryEnabled: business?.orderSettings?.deliverySettings?.freeDeliveryEnabled || false,
        freeDeliveryMinOrder: business?.orderSettings?.deliverySettings?.freeDeliveryMinOrder || 299,
        deliveryEta: '25–35 mins',
        pickupEta: '15–20 mins',
        services: ['Takeaway', 'Delivery'],
      };

      // Promotional Banners
      const banners = [
        {
          id: 'banner_1',
          tag: 'HOT & CHEESY',
          headline: 'PIZZA LOVERS',
          subtitle: 'Fresh Ingredients Bigger Happiness',
          ctaText: 'ORDER NOW',
          imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=1200&q=80',
          accentColor: '#E65100',
        },
        {
          id: 'banner_2',
          tag: 'WEEKEND SPECIAL',
          headline: 'BUY 1 GET 1 FREE',
          subtitle: 'On all Large Gourmet Pizzas',
          ctaText: 'EXPLORE DEALS',
          imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=1200&q=80',
          accentColor: '#D84315',
        },
      ];

      return ApiResponse.success(res, {
        restaurant,
        categories: categoryNames,
        products,
        addons,
        banners,
      }, 'Storefront loaded successfully');
    } catch (error) {
      next(error);
    }
  }

  async createStorefrontOrder(req, res, next) {
    try {
      const rawSlug = (req.params.slug || '').trim().toLowerCase();
      const orderPayload = req.body;

      let business = await Business.findOne({
        $or: [{ 'profile.slug': rawSlug }, { slug: rawSlug }],
      });

      if (!business && /^[0-9a-fA-F]{24}$/.test(rawSlug)) {
        business = await Business.findById(rawSlug);
      }

      const businessId = business ? business._id : null;

      const orderNumber = `ONL-${Math.floor(1000 + Math.random() * 9000)}`;
      const order = new Order({
        businessId,
        orderNumber,
        orderType: orderPayload.orderType || 'delivery',
        status: 'pending',
        items: orderPayload.items || [],
        subtotal: orderPayload.subtotal || 0,
        taxAmount: orderPayload.taxAmount || 0,
        deliveryCharge: orderPayload.deliveryCharge || 0,
        totalAmount: orderPayload.totalAmount || 0,
        paymentMethod: orderPayload.paymentMethod || 'UPI',
        paymentStatus: 'pending',
        deliveryAddress: orderPayload.deliveryAddress || '',
        customerName: orderPayload.customerName || 'Online Guest',
        customerPhone: orderPayload.customerPhone || '',
        orderSource: 'online',
        notes: orderPayload.notes || '',
      });

      await order.save();

      // Emit socket notification to POS terminal if connected
      try {
        const socketService = require('../services/socketService');
        if (socketService && businessId) {
          socketService.emitToBusiness(businessId.toString(), 'new_order', {
            order: order.toJSON(),
            alertTitle: '🔔 New Online Order Received!',
            alertMessage: `Order #${orderNumber} for ₹${order.totalAmount}`,
          });
        }
      } catch (_) {}

      return ApiResponse.created(res, {
        orderId: order._id,
        orderNumber: order.orderNumber,
        status: order.status,
        totalAmount: order.totalAmount,
      }, 'Online order placed successfully!');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new StorefrontController();
