import 'package:flutter/foundation.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/extra_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/services/firestore_service.dart';
import '../models/storefront_model.dart';

class StorefrontService {
  static final StorefrontService _instance = StorefrontService._internal();
  factory StorefrontService() => _instance;
  StorefrontService._internal();

  final DatabaseService _db = DatabaseService();
  final FirestoreService _firestore = FirestoreService();
  final ApiClient _apiClient = ApiClient();

  /// Fetch dynamic storefront data for given company slug or business ID
  Future<StorefrontData> loadStorefront(String slug) async {
    final cleanSlug = slug.trim().toLowerCase();

    RestaurantModel? restaurant;
    List<String> categories = [];
    List<MenuItemModel> menuItems = [];
    List<ExtraModel> addOns = [];
    List<StorefrontBanner> banners = [];

    // 1. Resolve dynamic local restaurant, logo, store name and menu data from DatabaseService
    final localRest = _db.restaurant;
    final dynamicLogo = _db.companyLogoPath?.trim().isNotEmpty == true
        ? _db.companyLogoPath!.trim()
        : (localRest?.logoUrl?.trim().isNotEmpty == true ? localRest!.logoUrl!.trim() : null);

    final dynamicStoreName = (localRest?.name.trim().isNotEmpty == true && localRest!.name != 'Apna Restaurant')
        ? localRest.name.trim()
        : ((localRest?.companyName.trim().isNotEmpty == true)
            ? localRest!.companyName.trim()
            : 'Pizza 47');

    final isLocalMatch = cleanSlug.isEmpty ||
        cleanSlug == 'preview' ||
        cleanSlug == 'company-name' ||
        (localRest != null &&
            (localRest.storefrontSlug.toLowerCase() == cleanSlug ||
                RestaurantModel.slugify(localRest.companyName).toLowerCase() == cleanSlug ||
                RestaurantModel.slugify(localRest.name).toLowerCase() == cleanSlug ||
                localRest.id.toLowerCase() == cleanSlug));

    if (isLocalMatch) {
      if (localRest != null) {
        restaurant = localRest.copyWith(
          name: dynamicStoreName,
          logoUrl: dynamicLogo ?? localRest.logoUrl,
        );
      }
      if (_db.menuItems.isNotEmpty) {
        menuItems = List<MenuItemModel>.from(_db.menuItems);
      }
      if (_db.categories.isNotEmpty) {
        categories = List<String>.from(_db.categories);
      }
      if (_db.extras.isNotEmpty) {
        addOns = List<ExtraModel>.from(_db.extras);
      }
    }

    // 2. Try loading from Backend Storefront API
    if (restaurant == null || menuItems.isEmpty) {
      try {
        final res = await _apiClient.get(ApiEndpoints.storefront(cleanSlug.isNotEmpty ? cleanSlug : 'store'));
        if (res['data'] != null && res['data'] is Map) {
          final data = res['data'] as Map<String, dynamic>;
          if (data['restaurant'] is Map) {
            restaurant = RestaurantModel.fromJson(Map<String, dynamic>.from(data['restaurant'] as Map));
          }
          if (data['categories'] is List) {
            categories = (data['categories'] as List).map((e) => e.toString()).toList();
          }
          if (data['products'] is List) {
            menuItems = (data['products'] as List)
                .map((e) => MenuItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          }
          if (data['addons'] is List) {
            addOns = (data['addons'] as List)
                .map((e) => ExtraModel.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          }
          if (data['banners'] is List) {
            banners = (data['banners'] as List)
                .map((e) => StorefrontBanner.fromJson(Map<String, dynamic>.from(e as Map)))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('[StorefrontService] Backend fetch note: $e');
      }
    }

    // 3. Try loading from Firestore
    if (restaurant == null) {
      try {
        restaurant = await _firestore.getRestaurantBySlug(cleanSlug);
        if (restaurant != null) {
          final storeMenu = await _firestore.getStorefrontMenu(restaurant.id);
          if (storeMenu != null) {
            if (storeMenu['categories'] is List) {
              categories = (storeMenu['categories'] as List).map((e) => e.toString()).toList();
            }
            if (storeMenu['items'] is List) {
              menuItems = (storeMenu['items'] as List)
                  .map((e) => MenuItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
                  .toList();
            }
          }
        }
      } catch (e) {
        debugPrint('[StorefrontService] Firestore fetch note: $e');
      }
    }

    // 4. Default / Fallback matching the rich user storefront
    RestaurantModel resolvedRestaurant = restaurant ??
        (localRest != null
            ? localRest.copyWith(
                name: dynamicStoreName,
                logoUrl: dynamicLogo ?? localRest.logoUrl,
              )
            : RestaurantModel(
                id: 'pizza-47',
                name: dynamicStoreName,
                companyName: dynamicStoreName,
                slug: cleanSlug.isNotEmpty ? cleanSlug : 'pizza-47',
                tagline: 'Fresh Ingredients Bigger Happiness',
                phone: _db.restaurant?.phone.isNotEmpty == true ? _db.restaurant!.phone : '+91 98765 43210',
                address: _db.restaurant?.address.isNotEmpty == true ? _db.restaurant!.address : 'Sector 62, Noida',
                cuisineType: _db.restaurant?.cuisineType.isNotEmpty == true ? _db.restaurant!.cuisineType : 'Pizzas • Burgers • Fast Food',
                taxRate: 5.0,
                deliveryBaseCharge: 30.0,
                deliveryChargePerKm: 10.0,
                freeDeliveryEnabled: true,
                freeDeliveryMinOrder: 299.0,
                openingTime: _db.restaurant?.openingTime ?? '10:00 AM',
                closingTime: _db.restaurant?.closingTime ?? '11:00 PM',
                logoUrl: dynamicLogo,
              ));

    if (dynamicLogo != null && (resolvedRestaurant.logoUrl == null || resolvedRestaurant.logoUrl!.isEmpty)) {
      resolvedRestaurant = resolvedRestaurant.copyWith(logoUrl: dynamicLogo);
    }

    // Ensure categories are rich and categorized
    if (categories.isEmpty) {
      if (_db.categories.isNotEmpty) {
        categories = List<String>.from(_db.categories);
      } else {
        categories = ['All', 'Pizzas', 'Burgers', 'Pastas', 'Sides', 'Beverages'];
      }
    }
    if (!categories.contains('All')) {
      categories = ['All', ...categories];
    }

    // Ensure menu items are filled and appetizing
    if (menuItems.isEmpty) {
      if (_db.menuItems.isNotEmpty) {
        menuItems = List<MenuItemModel>.from(_db.menuItems);
      } else {
        menuItems = _generateDefaultPizzeriaMenu();
      }
    }

    // Ensure addons are filled
    if (addOns.isEmpty && _db.extras.isNotEmpty) {
      addOns = List<ExtraModel>.from(_db.extras);
    }

    // Ensure banners are present
    if (banners.isEmpty) {
      banners = [
        const StorefrontBanner(
          id: 'b1',
          tag: 'HOT & CHEESY',
          headline: 'PIZZA LOVERS',
          subtitle: 'Fresh Ingredients Bigger Happiness',
          ctaText: 'ORDER NOW ➔',
          imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=1200&q=80',
          accentColorHex: 0xFFE65100,
        ),
        const StorefrontBanner(
          id: 'b2',
          tag: 'CHEF RECOMMENDATION',
          headline: 'PANEER SUPREME',
          subtitle: 'Loaded with 100% Mozzarella & Spiced Paneer',
          ctaText: 'VIEW ITEM ➔',
          imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=1200&q=80',
          accentColorHex: 0xFFD84315,
        ),
        const StorefrontBanner(
          id: 'b3',
          tag: 'SUPER SAVER COMBO',
          headline: 'PIZZA + FRIES + COKE',
          subtitle: 'Save flat 25% on Lunch & Dinner combos',
          ctaText: 'GRAB COMBO ➔',
          imageUrl: 'https://images.unsplash.com/photo-1571407970349-bc81e7e96d47?auto=format&fit=crop&w=1200&q=80',
          accentColorHex: 0xFFC2185B,
        ),
      ];
    }

    return StorefrontData(
      restaurant: resolvedRestaurant,
      categories: categories,
      menuItems: menuItems,
      addOns: addOns,
      banners: banners,
    );
  }

  /// Submit customer online order
  Future<bool> submitOrder({
    required RestaurantModel restaurant,
    required OrderType orderType,
    required List<StorefrontCartItem> cartItems,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required double subtotal,
    required double taxAmount,
    required double deliveryFee,
    required double totalAmount,
    required String paymentMethod,
    String specialNote = '',
  }) async {
    final orderNumber = 'ONL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final nowIso = DateTime.now().toIso8601String();

    final order = OrderModel(
      id: 'ord_onl_${DateTime.now().millisecondsSinceEpoch}',
      orderNumber: orderNumber,
      orderType: orderType,
      status: OrderStatus.pending,
      items: cartItems.map((c) => c.toCartItemModel()).toList(),
      subtotal: subtotal,
      taxAmount: taxAmount,
      deliveryCharge: deliveryFee,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentMethod == 'UPI' ? 'paid' : 'pending',
      isPaid: paymentMethod == 'UPI',
      deliveryAddress: orderType == OrderType.delivery ? deliveryAddress : null,
      createdAt: nowIso,
      customerName: customerName,
      customerPhone: customerPhone,
      orderSource: 'online',
    );

    // 1. Save locally in DatabaseService
    final localSuccess = await _db.placeOnlineStorefrontOrder(order);

    // 2. Submit to backend API
    try {
      await _apiClient.post(
        ApiEndpoints.storefrontOrder(restaurant.storefrontSlug),
        data: {
          'orderNumber': orderNumber,
          'orderType': orderType == OrderType.delivery ? 'delivery' : 'takeaway',
          'items': order.items.map((i) => i.toJson()).toList(),
          'subtotal': subtotal,
          'taxAmount': taxAmount,
          'deliveryCharge': deliveryFee,
          'totalAmount': totalAmount,
          'paymentMethod': paymentMethod,
          'deliveryAddress': deliveryAddress,
          'customerName': customerName,
          'customerPhone': customerPhone,
          'notes': specialNote,
        },
      );
    } catch (e) {
      debugPrint('[StorefrontService] Backend order submit notice: $e');
    }

    return localSuccess;
  }

  List<MenuItemModel> _generateDefaultPizzeriaMenu() {
    return [
      MenuItemModel(
        id: 'piz_01',
        name: 'Paneer Supreme Pizza',
        category: 'Pizzas',
        price: 249.0,
        salePrice: 249.0,
        description: 'Loaded with fresh paneer, capsicum, onions, olives and 100% mozzarella cheese on our signature sauce.',
        itemType: 'Veg',
        emoji: '🍕',
        imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=600&q=80',
        variants: const [
          ProductVariant(name: 'Regular (7")', price: 249.0),
          ProductVariant(name: 'Medium (10")', price: 349.0),
          ProductVariant(name: 'Large (12")', price: 449.0),
        ],
      ),
      MenuItemModel(
        id: 'piz_02',
        name: 'Margherita Pizza',
        category: 'Pizzas',
        price: 199.0,
        salePrice: 199.0,
        description: 'Classic delight with 100% mozzarella cheese & fresh basil on a hand-stretched crust.',
        itemType: 'Veg',
        emoji: '🍕',
        imageUrl: 'https://images.unsplash.com/photo-1604382355076-af4b0eb60143?auto=format&fit=crop&w=600&q=80',
        variants: const [
          ProductVariant(name: 'Regular (7")', price: 199.0),
          ProductVariant(name: 'Medium (10")', price: 299.0),
          ProductVariant(name: 'Large (12")', price: 399.0),
        ],
      ),
      MenuItemModel(
        id: 'piz_03',
        name: 'Farmhouse Special Pizza',
        category: 'Pizzas',
        price: 269.0,
        salePrice: 269.0,
        description: 'Delightful combination of onion, capsicum, tomato, grilled mushroom and melted mozzarella cheese.',
        itemType: 'Veg',
        emoji: '🍕',
        imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=600&q=80',
        variants: const [
          ProductVariant(name: 'Regular (7")', price: 269.0),
          ProductVariant(name: 'Medium (10")', price: 379.0),
          ProductVariant(name: 'Large (12")', price: 499.0),
        ],
      ),
      MenuItemModel(
        id: 'brg_01',
        name: 'Crispy Veg Whopper Burger',
        category: 'Burgers',
        price: 149.0,
        salePrice: 149.0,
        description: 'Crispy veg patty, fresh lettuce, sliced tomatoes, creamy mayo and spicy sauce on toasted sesame buns.',
        itemType: 'Veg',
        emoji: '🍔',
        imageUrl: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItemModel(
        id: 'pst_01',
        name: 'Creamy White Sauce Penne Pasta',
        category: 'Pastas',
        price: 219.0,
        salePrice: 219.0,
        description: 'Authentic Italian penne tossed in rich parmesan bechamel sauce with sweet corn and bell peppers.',
        itemType: 'Veg',
        emoji: '🍝',
        imageUrl: 'https://images.unsplash.com/photo-1621996346565-e3d5d6281096?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItemModel(
        id: 'sds_01',
        name: 'Cheesy Garlic Breadsticks',
        category: 'Sides',
        price: 139.0,
        salePrice: 139.0,
        description: 'Freshly baked buttery breadsticks infused with garlic butter and dripping with mozzarella cheese.',
        itemType: 'Veg',
        emoji: '🥖',
        imageUrl: 'https://images.unsplash.com/photo-1619895092538-128341789043?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItemModel(
        id: 'sds_02',
        name: 'Peri Peri French Fries',
        category: 'Sides',
        price: 119.0,
        salePrice: 119.0,
        description: 'Golden fried crispy potato fries seasoned generously with spicy African peri peri seasoning.',
        itemType: 'Veg',
        emoji: '🍟',
        imageUrl: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?auto=format&fit=crop&w=600&q=80',
      ),
      MenuItemModel(
        id: 'bev_01',
        name: 'Chilled Oreo Shake',
        category: 'Beverages',
        price: 129.0,
        salePrice: 129.0,
        description: 'Thick creamy milkshake blended with crunchy Oreo cookies and crowned with chocolate drizzle.',
        itemType: 'Beverage',
        emoji: '🥤',
        imageUrl: 'https://images.unsplash.com/photo-1572490122747-3968b75cc699?auto=format&fit=crop&w=600&q=80',
      ),
    ];
  }
}
