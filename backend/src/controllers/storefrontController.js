const Business = require('../models/Business');
const Product = require('../models/Product');
const Category = require('../models/Category');
const Extra = require('../models/Extra');
const Order = require('../models/Order');
const Table = require('../models/Table');
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
          { 'profile.companyName': { $regex: new RegExp('^' + rawSlug.replace(/-/g, ' ').replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '$', 'i') } },
        ],
      }).lean();

      // Fallback: try by ObjectId
      if (!business && /^[0-9a-fA-F]{24}$/.test(rawSlug)) {
        business = await Business.findById(rawSlug).lean();
      }

      if (!business) throw new ApiError(404, 'Storefront business not found');
      const businessId = business._id;

      const config = business.storefront || {};
      const settings = business.orderSettings || {};
      const services = Object.entries(settings.services || {})
        .filter(([, enabled]) => enabled === true)
        .map(([key]) => ({ dineIn: 'Dine In', takeaway: 'Takeaway', delivery: 'Delivery' }[key]))
        .filter(Boolean);
      const restaurant = {
        id: String(business._id),
        name: business.profile?.companyName || business.profile?.name || '',
        companyName: business.profile?.companyName || '',
        slug: business.profile?.slug || business.slug || rawSlug,
        tagline: business.profile?.tagline || '',
        cuisineType: business.profile?.cuisineType || business.business?.businessType || 'Indian & Continental',
        phone: business.profile?.phone || '',
        address: [business.address?.addressLine, business.address?.city, business.address?.state, business.address?.postalCode].filter(Boolean).join(', '),
        logoUrl: business.profile?.profileImage || '',
        currencySymbol: ({ INR: '₹', USD: '$', EUR: '€', GBP: '£' })[business.business?.currency] || business.business?.currency || '₹',
        openingTime: settings.openingTime || '09:00 AM', closingTime: settings.closingTime || '11:00 PM',
        services,
        taxRate: settings.tax?.type === 'no_gst' ? 0 : (settings.tax?.percentage ?? 0),
        billingType: settings.tax?.type === 'no_gst' ? 'Non-GST' : 'GST',
        upiId: settings.upiId || '', tableCount: settings.tableCount ?? 0,
        deliveryBaseCharge: settings.deliverySettings?.baseCharge ?? 0,
        deliveryChargePerKm: settings.deliverySettings?.chargePerKm ?? 0,
        freeDeliveryEnabled: settings.deliverySettings?.freeDeliveryEnabled ?? false,
        freeDeliveryMinOrder: settings.deliverySettings?.freeDeliveryMinOrder ?? 0,
        maxDeliveryDistanceKm: settings.deliverySettings?.maxDistanceKm ?? 0,
        isStorefrontOnline: config.isOnline ?? true,
        storefrontThemeColor: config.themeColorHex ?? 0xFFE65100,
        storefrontThemeColorEnd: config.themeColorEndHex ?? null,
        likesCount: 0,
        rating: business.profile?.rating ?? 4.6,
        reviewCount: business.profile?.reviewCount ?? '1.2k+',
      };
      if (req.query.brandingOnly === 'true') return ApiResponse.success(res, { restaurant }, 'Restaurant branding loaded');

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

      const categoryNames = [...new Set(categories.length
        ? categories.map(c => c.name).filter(Boolean)
        : products.map(p => p.category).filter(Boolean))];
      let banners = (config.banners || []).filter(b => b.isActive !== false)
        .sort((a,b) => (a.displayOrder || 0) - (b.displayOrder || 0));

      if (banners.length === 0) {
        const topDish = products[0];
        banners = [
          {
            id: 'banner_combo_1',
            tag: 'SUPER SAVER COMBO',
            headline: 'COMBO DELIGHT BOX',
            subtitle: `${topDish ? topDish.name : 'Delicious Food'} + Fries + Cold Drink at exclusive prices`,
            ctaText: 'GRAB COMBO',
            imageUrl: topDish?.imageUrl || (topDish?.images && topDish.images[0]) || 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800',
            accentColorHex: 0xFFE65100,
            couponCode: 'COMBO100',
            discountText: 'FLAT ₹100 OFF',
            isActive: true,
            displayOrder: 0,
          }
        ];
      }

      // Parse optional table ordering query parameters (e.g. ?R=R1&T=T01)
      const tableQuery = (req.query.T || req.query.t || req.query.table || req.query.tableNumber || '').toString().trim();
      const restaurantCodeQuery = (req.query.R || req.query.r || req.query.restaurant || '').toString().trim();
      let tableInfo = null;
      if (tableQuery) {
        const cleanTable = tableQuery.toUpperCase();
        const parsedNum = parseInt(cleanTable.replace(/[^0-9]/g, ''), 10);

        // Retrieve existing tables & configured limit for this business
        const businessId = business?._id;
        let tables = [];
        if (businessId) {
          tables = await Table.find({ businessId }).sort({ tableNumber: 1 }).lean();
        }
        const configuredCount = (business?.orderSettings?.tableCount && business.orderSettings.tableCount > 0)
          ? business.orderSettings.tableCount
          : tables.length;
        const maxDbTableNum = tables.length > 0
          ? Math.max(...tables.map((t) => t.tableNumber || 0))
          : configuredCount;
        const totalTables = Math.max(configuredCount, tables.length, maxDbTableNum);

        // Check if the requested table exists or is within the business's allowed table limit (1..totalTables)
        const matchedTable = tables.find((t) =>
          (parsedNum && t.tableNumber === parsedNum) ||
          (t.name && t.name.toUpperCase().replace(/\s+/g, '') === cleanTable.replace(/\s+/g, '')) ||
          (cleanTable === `T${String(t.tableNumber).padStart(2, '0')}`)
        );

        const isWithinRange = !isNaN(parsedNum) && parsedNum >= 1 && parsedNum <= totalTables;
        const isValid = !!matchedTable || isWithinRange;

        if (isValid) {
          const finalNum = matchedTable ? matchedTable.tableNumber : parsedNum;
          tableInfo = {
            isValid: true,
            tableCode: `T${String(finalNum).padStart(2, '0')}`,
            tableNumber: finalNum,
            name: matchedTable?.name || `Table ${finalNum}`,
            floor: matchedTable?.floor || 'Ground Floor',
            capacity: matchedTable?.capacity || 4,
            isTableOrdering: true,
            restaurantCode: restaurantCodeQuery || 'R1',
            totalTables,
          };
        } else {
          tableInfo = {
            isValid: false,
            tableCode: cleanTable,
            tableNumber: !isNaN(parsedNum) ? parsedNum : null,
            totalTables,
            isTableOrdering: false,
            error: `Table ${cleanTable} is not available at ${restaurant.name}. This outlet only has ${totalTables} tables (Table 1 to Table ${totalTables}).`,
          };
        }
      }

      return ApiResponse.success(res, {
        restaurant,
        categories: categoryNames,
        products: products.map((p) => ({
          ...p,
          id: p._id ? p._id.toString() : (p.id || p.productId),
          productId: p.productId || (p._id ? p._id.toString() : p.id),
          itemType: p.itemType || p.foodType || 'Veg',
          rating: p.rating || 4.8,
          variants: Array.isArray(p.variants) ? p.variants : [],
        })),
        addons: addons.map((a) => ({
          ...a,
          id: a._id ? a._id.toString() : a.id,
        })),
        banners,
        isOnline: restaurant.isStorefrontOnline,
        themeColorHex: restaurant.storefrontThemeColor,
        themeColorEndHex: restaurant.storefrontThemeColorEnd,
        deliveryEta: config.deliveryEta || (business.orderSettings?.deliverySettings?.estimatedTimeMinutes ? `${business.orderSettings.deliverySettings.estimatedTimeMinutes} mins` : '25–35 mins'),
        pickupEta: config.pickupEta || '15–20 mins',
        table: tableInfo,
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

      if (!business) {
        throw new ApiError(404, 'Storefront business not found');
      }

      const businessId = business._id;

      const rawOrderType = (orderPayload.orderType || (orderPayload.tableNumber ? 'dineIn' : 'delivery')).toString();
      const cleanType = rawOrderType.toLowerCase().replace(/[-_\s]/g, '');
      const isDineIn = cleanType.includes('dine') || !!orderPayload.tableNumber || !!orderPayload.T;
      const orderType = isDineIn ? 'dineIn' : (cleanType.includes('take') ? 'takeaway' : 'delivery');
      const tableNumber = isDineIn ? (orderPayload.tableNumber || orderPayload.T || '').toString().trim() : '';

      if (isDineIn) {
        const cleanTable = (tableNumber || '').toString().trim().toUpperCase();
        const parsedNum = parseInt(cleanTable.replace(/[^0-9]/g, ''), 10);
        const tables = await Table.find({ businessId }).lean();
        const configuredCount = (business?.orderSettings?.tableCount && business.orderSettings.tableCount > 0)
          ? business.orderSettings.tableCount
          : tables.length;
        const maxDbTableNum = tables.length > 0
          ? Math.max(...tables.map((t) => t.tableNumber || 0))
          : configuredCount;
        const totalTables = Math.max(configuredCount, tables.length, maxDbTableNum);

        const matchedTable = tables.find((t) =>
          (parsedNum && t.tableNumber === parsedNum) ||
          (t.name && t.name.toUpperCase().replace(/\s+/g, '') === cleanTable.replace(/\s+/g, '')) ||
          (cleanTable === `T${String(t.tableNumber).padStart(2, '0')}`)
        );
        const isWithinRange = !isNaN(parsedNum) && parsedNum >= 1 && parsedNum <= totalTables;

        if (!matchedTable && !isWithinRange) {
          throw new ApiError(
            400,
            `Table ${tableNumber} is not available. This outlet only supports tables from 1 to ${totalTables}.`
          );
        }
      }

      const orderNumber = `ONL-${Math.floor(1000 + Math.random() * 9000)}`;
      const order = new Order({
        businessId,
        orderNumber,
        orderType: isDineIn ? 'dineIn' : orderType,
        tableNumber: isDineIn ? (tableNumber || '') : '',
        tableCode: isDineIn ? (tableNumber || '') : '',
        status: 'pending',
        items: orderPayload.items || [],
        subtotal: orderPayload.subtotal || 0,
        taxAmount: orderPayload.taxAmount || 0,
        deliveryCharge: isDineIn ? 0 : (orderPayload.deliveryCharge || 0),
        totalAmount: orderPayload.totalAmount || 0,
        paymentMethod: isDineIn ? 'Pay at Counter / Table' : (orderPayload.paymentMethod || 'UPI'),
        paymentStatus: 'pending',
        isPaid: false,
        isDineIn: isDineIn,
        deliveryAddress: isDineIn ? '' : (orderPayload.deliveryAddress || ''),
        customerName: orderPayload.customerName || (isDineIn ? `Guest (Table ${tableNumber || 'Dine-In'})` : 'Online Guest'),
        customerPhone: orderPayload.customerPhone || '',
        orderSource: (orderPayload.orderSource || orderPayload.source || '').toString().toLowerCase().includes('profile') ? 'profile' : (isDineIn ? 'storefront' : (orderPayload.orderSource || orderPayload.source || 'storefront')),
        notes: orderPayload.notes || '',
      });

      await order.save();

      const bId = businessId.toString();

      // 1. Emit real-time socket events across all connected POS terminals
      try {
        const socketService = require('../services/socketService');
        if (socketService) {
          const orderJson = order.toJSON ? order.toJSON() : order;
          const tableLabel = tableNumber ? ` • Table ${tableNumber}` : '';
          socketService.broadcastToBusiness(bId, 'new_order', {
            order: orderJson,
            alertTitle: isDineIn ? `🍽️ New Table Order (${tableNumber ? `Table ${tableNumber}` : 'Dine-In'})!` : '🔔 New Online Order Received!',
            alertMessage: `Order #${orderNumber} for ₹${order.totalAmount}${tableLabel}`,
          });
          socketService.emitOrderCreated(bId, {
            orderId: order._id.toString(),
            orderNumber: order.orderNumber,
            tableNumber: order.tableNumber || '',
            totalAmount: order.totalAmount,
            orderType: order.orderType,
            orderSource: order.orderSource || 'storefront',
            status: 'pending',
            isPaid: false,
            paymentStatus: 'pending',
            order: orderJson,
          });
          socketService.emitWhatsAppOrderRequest(bId, {
            order: orderJson,
            customerName: order.customerName,
            customerPhone: order.customerPhone,
            totalAmount: order.totalAmount,
            orderType: order.orderType,
            tableNumber: order.tableNumber || '',
            orderSource: order.orderSource || 'storefront',
          });
        }
      } catch (sockErr) {
        console.warn('[storefrontController] Socket emission notice:', sockErr.message);
      }

      // 2. Dispatch high-priority push notification so device rings even if app is closed / locked
      try {
        const pushNotificationService = require('../services/pushNotificationService');
        const tableLabel = order.tableNumber ? ` • Table ${order.tableNumber}` : '';
        pushNotificationService.sendPushNotificationToBusiness({
          businessId: bId,
          title: `🔔 #${order.orderNumber} • ₹${order.totalAmount}${tableLabel}`,
          message: `${order.customerName || 'Customer'} • ${(order.orderType || 'takeaway').toUpperCase()}${tableLabel}`,
          data: {
            type: 'whatsapp_order_request',
            orderId: order._id.toString(),
            orderNumber: order.orderNumber,
            customerPhone: order.customerPhone || '',
            customerName: order.customerName || 'Customer',
            totalAmount: String(order.totalAmount || 0),
            orderType: order.orderType || 'dineIn',
            tableNumber: order.tableNumber || '',
            orderSource: (orderPayload.orderSource || orderPayload.source || '').toString().toLowerCase().includes('profile') ? 'profile' : (orderPayload.orderSource || orderPayload.source || 'storefront'),
            deliveryAddress: order.deliveryAddress || '',
            items: JSON.stringify(order.items || []),
            createdAt: (order.createdAt || new Date()).toISOString(),
          },
        }).catch((err) => console.warn('[storefrontController] Push dispatch notice:', err.message));
      } catch (pushErr) {
        console.warn('[storefrontController] Push notification notice:', pushErr.message);
      }

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
