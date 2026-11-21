import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/services/firestore_service.dart';
import '../models/customer_storefront_flow_models.dart';
import '../models/storefront_model.dart';
import 'storefront_order_service.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'package:dio/dio.dart';
import '../models/customer_order_status.dart';
import 'table_qr_phone_auth.dart';

class CustomerStorefrontApiService {
  static Future<void> _historyWrites = Future.value();

  Future<List<CustomerOrderTrackingModel>> orderHistory(
    String restaurantId,
  ) async {
    final auth = TableQrPhoneAuth(restaurantId: restaurantId);
    if (await auth.token() != null) {
      try {
        return await auth.orders();
      } catch (_) {
        return [];
      }
    }
    final prefs = await SharedPreferences.getInstance();
    try {
      return (jsonDecode(
                prefs.getString('customer_orders_$restaurantId') ?? '[]',
              )
              as List)
          .map(
            (entry) => CustomerOrderTrackingModel.fromJson(
              Map<String, dynamic>.from(entry),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _rememberOrder(CustomerOrderTrackingModel order) {
    final save = _historyWrites.then((_) async {
      final history = await orderHistory(order.restaurantId);
      history.removeWhere((entry) => entry.orderId == order.orderId);
      history.insert(0, order);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'customer_orders_${order.restaurantId}',
        jsonEncode(history.take(50).map((entry) => entry.toJson()).toList()),
      );
    });
    return _historyWrites = save.catchError((Object _) {});
  }

  static final CustomerStorefrontApiService _instance =
      CustomerStorefrontApiService._internal();
  factory CustomerStorefrontApiService() => _instance;
  CustomerStorefrontApiService._internal();

  final DatabaseService _db = DatabaseService();
  final FirestoreService _firestore = FirestoreService();

  static const String _prefCustomerKey = 'customer_storefront_active_profile';
  static const String _prefActiveOrderKey = 'customer_storefront_active_order';

  final Map<String, ConfirmTablePhone> _verification = {};

  Future<String> sendOtp(String phone, {required String restaurantId}) async {
    final business = restaurantId;
    if (business.isEmpty) {
      throw StateError('Choose a restaurant before signing in.');
    }
    final challenge = await TableQrPhoneAuth(
      restaurantId: business,
    ).send(phone);
    final key = '$business|${phone.replaceAll(RegExp(r'\D'), '')}';
    _verification[key] = (code, {name}) async {
      final customer = await challenge.confirm!(code, name: name);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_auth_restaurant', business);
      await _saveProfileLocally(customer);
      return customer;
    };
    return 'whatsapp';
  }

  Future<CustomerProfileModel?> verifyOtp(
    String phone,
    String otp, {
    required String restaurantId,
  }) async {
    final key = '$restaurantId|${phone.replaceAll(RegExp(r'\D'), '')}';
    final verify = _verification[key];
    if (verify == null) return null;
    try {
      final customer = await verify(otp);
      _verification.remove(key);
      return customer;
    } catch (_) {
      return null;
    }
  }

  /// Get active logged-in customer profile
  Future<CustomerProfileModel?> getCurrentCustomer({
    String? restaurantId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final business =
        restaurantId ?? prefs.getString('customer_auth_restaurant');
    if (business == null || business.isEmpty) return null;
    CustomerProfileModel? customer;
    try {
      customer = await TableQrPhoneAuth(restaurantId: business).restore();
    } catch (_) {
      return null;
    }
    if (customer == null) return null;
    try {
      final cached = CustomerProfileModel.fromJson(
        jsonDecode(prefs.getString(_prefCustomerKey) ?? '{}'),
      );
      if (cached.id == customer.id) {
        return customer.copyWith(addresses: cached.addresses);
      }
    } catch (_) {}
    return customer;
  }

  /// Update customer profile details
  Future<bool> updateCustomerProfile(CustomerProfileModel profile) async {
    await _saveProfileLocally(profile);
    try {
      await _firestore.saveCustomerProfile(profile.toJson());
      return true;
    } catch (e) {
      debugPrint(
        '[CustomerStorefrontApiService] Error syncing profile to cloud: $e',
      );
      return true; // Local persistence succeeded
    }
  }

  /// Add or update an address
  Future<CustomerProfileModel?> saveAddress(
    CustomerAddressModel address,
  ) async {
    final current = await getCurrentCustomer();
    if (current == null) return null;

    final updatedAddresses = List<CustomerAddressModel>.from(current.addresses);
    final existingIdx = updatedAddresses.indexWhere((a) => a.id == address.id);
    if (existingIdx >= 0) {
      updatedAddresses[existingIdx] = address;
    } else {
      updatedAddresses.add(address);
    }

    final updatedProfile = current.copyWith(addresses: updatedAddresses);
    await updateCustomerProfile(updatedProfile);
    return updatedProfile;
  }

  /// Log out customer
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefCustomerKey);
  }

  Future<void> _saveProfileLocally(CustomerProfileModel profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefCustomerKey, jsonEncode(profile.toJson()));
    } catch (e) {
      debugPrint(
        '[CustomerStorefrontApiService] Error saving profile locally: $e',
      );
    }
  }

  /// Place dynamic customer order across DatabaseService, Cloud Firestore, and API
  Future<CustomerOrderTrackingModel?> placeCustomerOrder({
    required RestaurantModel restaurant,
    required CustomerProfileModel customer,
    required CustomerAddressModel selectedAddress,
    required List<StorefrontCartItem> cartItems,
    required String paymentMethod,
    required double subtotal,
    required double deliveryFee,
    required double tax,
    required double grandTotal,
    double discount = 0.0,
    String deliveryInstructions = '',
    String? tableNumber,
    OrderType orderType = OrderType.delivery,
  }) async {
    final now = DateTime.now();
    final datePrefix =
        '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomSuffix = (1000 + Random().nextInt(9000)).toString();
    final orderNumber = '#ORD-$datePrefix-$randomSuffix';
    final orderId = 'ord_${now.millisecondsSinceEpoch}_$randomSuffix';
    final nowIso = now.toIso8601String();
    final bool isDineIn =
        orderType == OrderType.dineIn ||
        (tableNumber != null && tableNumber.trim().isNotEmpty);
    final String resolvedAddress = isDineIn
        ? 'Table ${tableNumber?.trim() ?? "Dine-In"}'
        : '${selectedAddress.label}: ${selectedAddress.fullAddress}';

    // 1. Build Item Summaries
    final itemSummaries = cartItems.map((c) {
      return CustomerOrderItemSummary(
        name: c.item.name,
        size: c.selectedSize != null
            ? '${c.selectedSize!.name} (${c.selectedSize!.description})'
            : '',
        quantity: c.quantity,
        price: c.unitPrice,
        addons: c.selectedAddons
            .where((a) => a.isSelected)
            .map((a) => a.name)
            .toList(),
        instructions: c.instructions.isNotEmpty ? c.instructions : null,
      );
    }).toList();

    // 2. Build Tracking Model
    var trackingModel = CustomerOrderTrackingModel(
      orderId: orderId,
      orderNumber: orderNumber,
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      status: 'pending',
      currentStepIndex: 0,
      estimatedDeliveryMinutes: isDineIn ? '15 - 20 mins' : '25 - 35 mins',
      items: itemSummaries,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      tax: tax,
      discount: discount,
      grandTotal: grandTotal,
      paymentMethod:
          (isDineIn || (tableNumber != null && tableNumber.trim().isNotEmpty))
          ? 'Pay at Counter / Table'
          : paymentMethod,
      paymentStatus:
          (isDineIn || (tableNumber != null && tableNumber.trim().isNotEmpty))
          ? 'Pending'
          : (paymentMethod == 'Cash on Delivery' ? 'Pending' : 'Paid'),
      deliveryAddress: resolvedAddress,
      deliveryInstructions: deliveryInstructions,
      createdAt: now,
    );

    final bool isTableDineIn =
        isDineIn || (tableNumber != null && tableNumber.trim().isNotEmpty);
    final bool resolvedIsPaid = isTableDineIn
        ? false
        : (paymentMethod != 'Cash on Delivery');
    final String resolvedPaymentStatus = isTableDineIn
        ? 'pending'
        : (resolvedIsPaid ? 'paid' : 'pending');
    final String resolvedPaymentMethod = isTableDineIn
        ? 'Pay at Counter / Table'
        : (paymentMethod.toLowerCase().contains('cash') ? 'Cash' : 'UPI');

    try {
      final savedOrder = await StorefrontOrderService().submit(
        OrderModel(
          id: orderId,
          orderNumber: orderNumber,
          items: cartItems.map((c) => c.toCartItemModel()).toList(),
          orderType: isDineIn ? OrderType.dineIn : orderType,
          tableNumber: tableNumber?.trim(),
          status: OrderStatus.pending,
          subtotal: subtotal,
          discountAmount: discount,
          taxAmount: tax,
          deliveryCharge: isDineIn ? 0 : deliveryFee,
          totalAmount: grandTotal,
          paymentMethod: resolvedPaymentMethod,
          paymentStatus: resolvedPaymentStatus,
          isPaid: resolvedIsPaid,
          customerName: customer.name,
          customerPhone: customer.phone,
          deliveryAddress: resolvedAddress,
          createdAt: nowIso,
          orderSource: 'storefront',
        ),
        restaurant,
        notes: deliveryInstructions,
      );
      await _db.placeOnlineStorefrontOrder(
        savedOrder,
        skipFirestoreSync: true,
        showIncomingAlert: false,
      );
      trackingModel = trackingModel.copyWith(
        orderId: savedOrder.id,
        orderNumber: savedOrder.orderNumber,
        status: savedOrder.status.name,
        paymentStatus: savedOrder.paymentStatus,
      );
    } catch (error) {
      debugPrint(
        '[CustomerStorefrontApiService] Restaurant order submission failed: $error',
      );
      return null;
    }

    // 6. Cache active order locally
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefActiveOrderKey,
        jsonEncode(trackingModel.toJson()),
      );
    } catch (_) {}

    await _rememberOrder(trackingModel);
    return trackingModel;
  }

  /// Real-time stream of order status updates
  Stream<CustomerOrderTrackingModel?> streamOrderStatus(
    String orderId, {
    CustomerOrderTrackingModel? receipt,
    RestaurantModel? restaurant,
  }) {
    late StreamController<CustomerOrderTrackingModel?> controller;
    StreamSubscription<Map<String, dynamic>?>? subscription;
    Timer? timer;
    var polling = false;
    var authoritative = false;
    CustomerOrderTrackingModel? latest = receipt;

    void emit(Map<String, dynamic> data) {
      if (controller.isClosed) return;
      final status = CustomerOrderStatus.resolve(data);
      final base = latest;
      if (base == null) return;
      // Terminal receipts cannot regress when an older cache snapshot arrives.
      if (['completed', 'cancelled'].contains(base.status) &&
          base.status != status.name) {
        return;
      }
      latest = base.copyWith(
        status: status.name,
        currentStepIndex: status.step,
        paymentStatus: data['paymentStatus']?.toString() ?? base.paymentStatus,
      );
      controller.add(latest);
      unawaited(_rememberOrder(latest!));
    }

    Future<void> refresh() async {
      if (polling ||
          controller.isClosed ||
          receipt == null ||
          restaurant == null) {
        return;
      }
      polling = true;
      try {
        final response = await ApiClient().get(
          '${ApiEndpoints.storefrontOrder(restaurant.storefrontSlug)}/${Uri.encodeComponent(orderId)}/status',
          queryParameters: {'orderNumber': receipt.orderNumber},
          options: Options(
            receiveTimeout: const Duration(seconds: 8),
            sendTimeout: const Duration(seconds: 8),
          ),
        );
        if (response is Map && response['data'] is Map) {
          authoritative = true;
          emit(Map<String, dynamic>.from(response['data']));
        }
      } catch (_) {
        // A transient connection failure must not reset a known order status.
      } finally {
        polling = false;
      }
    }

    // 1. Check local order first
    void checkLocal() {
      final local = _db.orders
          .where((o) => o.id == orderId || o.orderNumber == orderId)
          .firstOrNull;
      if (local != null) {
        if (authoritative) return;
        int stepIdx = 0;
        if (local.status == OrderStatus.preparing) stepIdx = 1;
        if (local.status == OrderStatus.ready) stepIdx = 2;
        if (local.status == OrderStatus.completed) stepIdx = 3;

        final model = CustomerOrderTrackingModel(
          orderId: local.id,
          orderNumber: local.orderNumber,
          restaurantId: _db.restaurant?.id ?? 'rest_01',
          restaurantName: _db.restaurant?.name ?? 'Pizza 47',
          status: local.status.name,
          currentStepIndex: stepIdx,
          subtotal: local.subtotal,
          deliveryFee: local.deliveryCharge,
          tax: local.taxAmount,
          discount: local.discountAmount,
          grandTotal: local.totalAmount,
          paymentMethod: local.paymentMethod,
          paymentStatus: local.isPaid ? 'Paid' : 'Pending',
          deliveryAddress: local.deliveryAddress ?? '',
          createdAt: DateTime.tryParse(local.createdAt) ?? DateTime.now(),
        );
        latest ??= model;
        final json = local.toJson();
        if (local.items.any((line) => line.kotQuantity > 0)) {
          json['kotStatus'] = 'sent';
        }
        emit(json);
      }
    }

    controller = StreamController<CustomerOrderTrackingModel?>(
      onListen: () {
        if (latest != null) controller.add(latest);
        _db.addListener(checkLocal);
        checkLocal();
        subscription = _firestore.streamStorefrontOrder(orderId).listen((data) {
          if (data != null && !authoritative) emit(data);
        }, onError: (Object _) {});
        unawaited(refresh());
        timer = Timer.periodic(
          const Duration(seconds: 3),
          (_) => unawaited(refresh()),
        );
      },
      onCancel: () async {
        timer?.cancel();
        _db.removeListener(checkLocal);
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  /// Update order status for simulation or POS trigger
  Future<void> updateOrderStatus(String orderId, int stepIndex) async {
    final statuses = [
      'confirmed',
      'preparing',
      'out_for_delivery',
      'delivered',
    ];
    final status = stepIndex >= 0 && stepIndex < statuses.length
        ? statuses[stepIndex]
        : 'confirmed';

    // Update in local POS
    final localOrder = _db.orders
        .where((o) => o.id == orderId || o.orderNumber == orderId)
        .firstOrNull;
    if (localOrder != null) {
      OrderStatus posStatus = OrderStatus.pending;
      if (stepIndex == 1) posStatus = OrderStatus.preparing;
      if (stepIndex == 2) posStatus = OrderStatus.ready;
      if (stepIndex == 3) posStatus = OrderStatus.completed;

      _db.updateOrderStatus(localOrder.id, posStatus);
    }

    // Sync to Cloud
    await _firestore.updateStorefrontOrderStatus(orderId, status, stepIndex);
  }
}
