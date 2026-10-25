import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/restaurant_model.dart';
import '../models/customer_storefront_flow_models.dart';
import '../models/storefront_model.dart';
import '../services/customer_storefront_api_service.dart';

class StorefrontCheckoutFlowSheet extends StatefulWidget {
  final RestaurantModel restaurant;
  final List<StorefrontCartItem> cartItems;
  final List<MenuItemModel> allMenuItems;
  final Function(StorefrontCartItem item, int newQty) onUpdateQuantity;
  final Function(MenuItemModel item) onAddCrossSellItem;
  final VoidCallback onClearCart;
  final Color themeColor;
  final Color? themeColorEnd;
  final int initialStep; // 3 to 10

  const StorefrontCheckoutFlowSheet({
    super.key,
    required this.restaurant,
    required this.cartItems,
    required this.allMenuItems,
    required this.onUpdateQuantity,
    required this.onAddCrossSellItem,
    required this.onClearCart,
    this.themeColor = const Color(0xFFE65100),
    this.themeColorEnd,
    this.initialStep = 3,
  });

  @override
  State<StorefrontCheckoutFlowSheet> createState() => _StorefrontCheckoutFlowSheetState();
}

class _StorefrontCheckoutFlowSheetState extends State<StorefrontCheckoutFlowSheet> {
  final CustomerStorefrontApiService _customerService = CustomerStorefrontApiService();

  late int _currentStep; // 3 to 10
  CustomerProfileModel? _currentCustomer;
  CustomerAddressModel? _selectedAddress;
  CustomerOrderTrackingModel? _activeOrder;

  // Step 5 & 6 Inputs
  final TextEditingController _phoneController = TextEditingController(text: '97095 93705');
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  int _resendTimerSeconds = 30;
  Timer? _countdownTimer;

  // Step 8 & 9 Inputs
  final TextEditingController _deliveryInstructionsController = TextEditingController();
  String _selectedPaymentMethod = 'Cash on Delivery'; // 'Cash on Delivery', 'UPI', 'Credit / Debit Card', 'Wallets'
  bool _isSubmittingOrder = false;

  // Step 3 Coupon
  String? _appliedCouponCode;
  double _couponDiscount = 0.0;

  // Stream subscription for Step 10
  StreamSubscription<CustomerOrderTrackingModel?>? _orderStreamSub;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    _currentCustomer = const CustomerProfileModel(
      id: 'cust_default',
      phone: '+91 97095 93705',
      name: 'Chandan Kumar',
      addresses: [
        CustomerAddressModel(
          id: 'addr_home',
          label: 'Home',
          fullAddress: '34, 34, Chanakya Place, Delhi, Delhi - 110021',
          isDefault: true,
        ),
        CustomerAddressModel(
          id: 'addr_work',
          label: 'Work',
          fullAddress: 'Sector 62, Noida - 201309',
          isDefault: false,
        ),
      ],
    );
    _selectedAddress = _currentCustomer!.addresses.first;
    _checkExistingCustomer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _orderStreamSub?.cancel();
    _phoneController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _deliveryInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingCustomer() async {
    final customer = await _customerService.getCurrentCustomer();
    if (customer != null && mounted) {
      setState(() {
        _currentCustomer = customer;
        if (customer.addresses.isNotEmpty) {
          _selectedAddress = customer.addresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => customer.addresses.first,
          );
        }
      });
    }
  }

  void _startOtpTimer() {
    _countdownTimer?.cancel();
    setState(() => _resendTimerSeconds = 30);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 0 && mounted) {
        setState(() => _resendTimerSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  // Bill Calculations
  double get _itemTotal => widget.cartItems.fold(0.0, (sum, i) => sum + i.totalPrice);
  double get _deliveryCharge => _itemTotal > 0 ? (widget.restaurant.deliveryBaseCharge > 0 ? widget.restaurant.deliveryBaseCharge : 40.0) : 0.0;
  double get _taxesAndCharges => (_itemTotal * (widget.restaurant.taxRate > 0 ? widget.restaurant.taxRate / 100.0 : 0.05)).roundToDouble() > 0 ? (_itemTotal * 0.09).roundToDouble() : 28.0;
  double get _grandTotal => (_itemTotal + _deliveryCharge + _taxesAndCharges - _couponDiscount).clamp(0.0, double.infinity);

  // Cross-sell items (items from other categories or popular pizzas)
  List<MenuItemModel> get _crossSellItems {
    final cartItemNames = widget.cartItems.map((c) => c.item.name.toLowerCase()).toSet();
    final candidates = widget.allMenuItems.where((m) => !cartItemNames.contains(m.name.toLowerCase())).toList();
    if (candidates.length >= 2) return candidates.take(4).toList();
    // Fallback cross-sell items matching screenshot
    return [
      MenuItemModel(
        id: 'cross_01',
        name: 'BBQ Chicken Pizza',
        category: 'Pizzas',
        price: 389.0,
        salePrice: 389.0,
        description: 'Tender chicken cubes with smoky barbecue glaze and mozzarella cheese.',
        itemType: 'Non-Veg',
        imageUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=400&q=80',
      ),
      MenuItemModel(
        id: 'cross_02',
        name: 'Chicken Supreme Pizza',
        category: 'Pizzas',
        price: 349.0,
        salePrice: 349.0,
        description: 'Loaded with seasoned chicken chunks, peri peri seasoning and herbs.',
        itemType: 'Non-Veg',
        imageUrl: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=400&q=80',
      ),
    ];
  }

  void _navigateToStep(int step) {
    setState(() => _currentStep = step);
  }

  void _handleProceedToCheckout() {
    if (_currentCustomer != null) {
      _navigateToStep(8); // Delivery Details
    } else {
      _navigateToStep(4); // Login Required Auth Gate
    }
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      _showSnackbar('Please enter a valid 10-digit mobile number');
      return;
    }
    await _customerService.sendOtp(phone);
    _startOtpTimer();
    _navigateToStep(6); // Enter OTP
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpControllers.map((c) => c.text.trim()).join();
    if (otp.length < 6) {
      _showSnackbar('Please enter the 6-digit verification code');
      return;
    }
    final customer = await _customerService.verifyOtp(_phoneController.text.trim(), otp);
    if (customer != null && mounted) {
      setState(() {
        _currentCustomer = customer;
        if (customer.addresses.isNotEmpty) {
          _selectedAddress = customer.addresses.first;
        }
      });
      _navigateToStep(7); // User Profile Created
    } else {
      _showSnackbar('Invalid code. Please try 123456');
    }
  }

  Future<void> _handlePlaceOrder() async {
    if (_selectedAddress == null) {
      _showSnackbar('Please select or add a delivery address');
      _navigateToStep(8);
      return;
    }

    setState(() => _isSubmittingOrder = true);

    final order = await _customerService.placeCustomerOrder(
      restaurant: widget.restaurant,
      customer: _currentCustomer!,
      selectedAddress: _selectedAddress!,
      cartItems: widget.cartItems,
      paymentMethod: _selectedPaymentMethod,
      subtotal: _itemTotal,
      deliveryFee: _deliveryCharge,
      tax: _taxesAndCharges,
      grandTotal: _grandTotal,
      discount: _couponDiscount,
      deliveryInstructions: _deliveryInstructionsController.text.trim(),
    );

    setState(() => _isSubmittingOrder = false);

    if (order != null && mounted) {
      setState(() => _activeOrder = order);
      widget.onClearCart();
      _subscribeToOrderUpdates(order.orderId);
      _navigateToStep(10); // Order Confirmation & Live Tracking
    } else {
      _showSnackbar('Could not place order. Please try again.');
    }
  }

  void _subscribeToOrderUpdates(String orderId) {
    _orderStreamSub?.cancel();
    _orderStreamSub = _customerService.streamOrderStatus(orderId).listen((updated) {
      if (updated != null && mounted) {
        setState(() => _activeOrder = updated);
      }
    });
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF3F8), // Soft Neumorphic Canvas
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Dynamic Step View
          Expanded(
            child: _buildStepView(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepView() {
    switch (_currentStep) {
      case 3:
        return _buildStep3CartView();
      case 4:
        return _buildStep4AuthGateView();
      case 5:
        return _buildStep5EnterMobileView();
      case 6:
        return _buildStep6EnterOtpView();
      case 7:
        return _buildStep7WelcomeProfileView();
      case 8:
        return _buildStep8DeliveryDetailsView();
      case 9:
        return _buildStep9PaymentMethodView();
      case 10:
        return _buildStep10OrderConfirmationView();
      default:
        return _buildStep3CartView();
    }
  }

  // =========================================================================
  // STEP 3: YOUR CART
  // =========================================================================
  Widget _buildStep3CartView() {
    return Column(
      children: [
        // Top Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildCircularNavButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Cart',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    '${widget.cartItems.length} ${widget.cartItems.length == 1 ? "item" : "items"}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const Spacer(),
              if (widget.cartItems.isNotEmpty)
                TextButton(
                  onPressed: widget.onClearCart,
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),

        // Scrollable Cart Body
        Expanded(
          child: widget.cartItems.isEmpty
              ? _buildEmptyCartPlaceholder()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. CART ITEMS LIST
                      ...widget.cartItems.map((cartItem) => _buildCartItemCard(cartItem)),

                      const SizedBox(height: 14),

                      // 2. APPLY COUPON SECTION
                      _buildApplyCouponCard(),

                      const SizedBox(height: 14),

                      // 3. BILL DETAILS CARD
                      _buildBillDetailsCard(),

                      const SizedBox(height: 14),

                      // 4. PROCEED TO CHECKOUT BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _handleProceedToCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.themeColor,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: widget.themeColor.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Proceed to Checkout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 5. "YOU MAY ALSO LIKE" CROSS-SELL CAROUSEL
                      const Text(
                        'You may also like',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 148,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _crossSellItems.length,
                          separatorBuilder: (c, i) => const SizedBox(width: 12),
                          itemBuilder: (c, idx) {
                            final item = _crossSellItems[idx];
                            return _buildCrossSellCard(item);
                          },
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyCartPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0xFFCBD5E1), offset: Offset(2, 2), blurRadius: 6),
              ],
            ),
            child: Icon(Icons.shopping_bag_outlined, size: 40, color: widget.themeColor),
          ),
          const SizedBox(height: 14),
          const Text('Your cart is empty', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          const Text('Add items from the menu to place an order.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(StorefrontCartItem cartItem) {
    final sizeText = cartItem.selectedSize != null
        ? '${cartItem.selectedSize!.name} (${cartItem.selectedSize!.description})'
        : 'Regular';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.16),
            offset: const Offset(2, 2.5),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          // Food Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              cartItem.item.imageUrl.isNotEmpty
                  ? cartItem.item.imageUrl
                  : 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=200&q=80',
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                width: 64,
                height: 64,
                color: const Color(0xFFE2E8F0),
                child: const Icon(Icons.fastfood_rounded, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Size & Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildVegDot(cartItem.item.itemType),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cartItem.item.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  sizeText,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                Text(
                  '₹${cartItem.unitPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          // Stepper Pill (- 1 + with trash)
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    cartItem.quantity == 1 ? Icons.delete_outline_rounded : Icons.remove,
                    size: 16,
                    color: cartItem.quantity == 1 ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                  ),
                  onPressed: () {
                    widget.onUpdateQuantity(cartItem, cartItem.quantity - 1);
                  },
                ),
                Text(
                  '${cartItem.quantity}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF0F172A)),
                  onPressed: () {
                    widget.onUpdateQuantity(cartItem, cartItem.quantity + 1);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplyCouponCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
            offset: const Offset(2, 2.5),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.themeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.local_offer_rounded, color: widget.themeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _appliedCouponCode != null ? 'Coupon Applied: $_appliedCouponCode' : 'Apply Coupon',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                if (_appliedCouponCode != null)
                  Text(
                    'Saved ₹${_couponDiscount.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // Apply default promo coupon
              setState(() {
                if (_appliedCouponCode == null) {
                  _appliedCouponCode = 'WELCOME50';
                  _couponDiscount = 50.0;
                } else {
                  _appliedCouponCode = null;
                  _couponDiscount = 0.0;
                }
              });
            },
            child: Row(
              children: [
                Text(
                  _appliedCouponCode != null ? 'Remove' : 'Select a coupon',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _appliedCouponCode != null ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: _appliedCouponCode != null ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
            offset: const Offset(2, 2.5),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill Details',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          _buildBillRow('Item Total', '₹${_itemTotal.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _buildBillRow('Delivery Charge', '₹${_deliveryCharge.toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          _buildBillRow('Taxes & Charges (GST)', '₹${_taxesAndCharges.toStringAsFixed(0)}'),
          if (_couponDiscount > 0) ...[
            const SizedBox(height: 8),
            _buildBillRow('Coupon Discount', '-₹${_couponDiscount.toStringAsFixed(0)}', isGreen: true),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Color(0xFFE2E8F0), height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              Text(
                '₹${_grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF10B981), // Vibrant green matching screenshot
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: isGreen ? const Color(0xFF10B981) : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildCrossSellCard(MenuItemModel item) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
            offset: const Offset(2, 2.5),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              item.imageUrl,
              height: 70,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                height: 70,
                color: const Color(0xFFE2E8F0),
                child: const Icon(Icons.local_pizza_rounded, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${item.effectivePrice.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              GestureDetector(
                onTap: () => widget.onAddCrossSellItem(item),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: widget.themeColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 4: LOGIN REQUIRED (AUTH GATE)
  // =========================================================================
  Widget _buildStep4AuthGateView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _buildCircularNavButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => _navigateToStep(3),
            ),
          ),
          const SizedBox(height: 20),

          // Glowing Padlock Icon
          _buildGlowingIllustration(
            icon: Icons.lock_rounded,
            color: widget.themeColor,
          ),

          const SizedBox(height: 20),

          const Text(
            'Login to Continue',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Please login or create an account\nto place your order.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
          ),

          const SizedBox(height: 26),

          // 3 Benefit Bullet Points with circular icons
          _buildAuthBenefitRow(Icons.location_on_rounded, 'Save your delivery addresses'),
          const SizedBox(height: 14),
          _buildAuthBenefitRow(Icons.delivery_dining_rounded, 'Track your orders in real-time'),
          const SizedBox(height: 14),
          _buildAuthBenefitRow(Icons.card_giftcard_rounded, 'Get exclusive offers & rewards'),

          const SizedBox(height: 32),

          // Primary Button: Login with Mobile Number
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToStep(5),
              icon: const Icon(Icons.phone_iphone_rounded, size: 20),
              label: const Text('Login with Mobile Number', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 3,
                shadowColor: widget.themeColor.withValues(alpha: 0.4),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Separator: — or continue with —
          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFFCBD5E1))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or continue with', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ),
              Expanded(child: Divider(color: Color(0xFFCBD5E1))),
            ],
          ),

          const SizedBox(height: 16),

          // Google Button
          _buildSocialButton(
            label: 'Login with Google',
            icon: Icons.g_mobiledata_rounded,
            iconColor: const Color(0xFFEA4335),
            onTap: () => _navigateToStep(5),
          ),

          const SizedBox(height: 10),

          // Email Button
          _buildSocialButton(
            label: 'Login with Email',
            icon: Icons.mail_outline_rounded,
            iconColor: const Color(0xFF0F172A),
            onTap: () => _navigateToStep(5),
          ),

          const SizedBox(height: 24),

          // Create an account link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'New to ${widget.restaurant.name}? ',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              GestureDetector(
                onTap: () => _navigateToStep(5),
                child: Text(
                  'Create an Account',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: widget.themeColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAuthBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: widget.themeColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: widget.themeColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.14),
            offset: const Offset(2, 2.5),
            blurRadius: 5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 5: ENTER MOBILE NUMBER
  // =========================================================================
  Widget _buildStep5EnterMobileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _buildCircularNavButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => _navigateToStep(4),
            ),
          ),
          const SizedBox(height: 24),

          // Smartphone illustration
          _buildGlowingIllustration(
            icon: Icons.phone_android_rounded,
            color: widget.themeColor,
          ),

          const SizedBox(height: 24),

          const Text(
            'Enter Your Mobile Number',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            "We'll send you a verification code\nto login or create an account.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
          ),

          const SizedBox(height: 32),

          // Phone Input Card (+91 Flag & Field)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
                BoxShadow(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.16),
                  offset: const Offset(2, 2.5),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                const Text('🇮🇳', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                const Text(
                  '+91',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 10),
                Container(width: 1.2, height: 24, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '97095 93705',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Primary Button: Send OTP ->
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _handleSendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 3,
                shadowColor: widget.themeColor.withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Send OTP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Legal disclaimer
          const Text(
            'By continuing, you agree to our\nTerms & Conditions and Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), height: 1.4),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 6: ENTER OTP
  // =========================================================================
  Widget _buildStep6EnterOtpView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _buildCircularNavButton(
              icon: Icons.arrow_back_rounded,
              onTap: () => _navigateToStep(5),
            ),
          ),
          const SizedBox(height: 20),

          // Envelope illustration
          _buildGlowingIllustration(
            icon: Icons.mark_email_read_rounded,
            color: widget.themeColor,
          ),

          const SizedBox(height: 20),

          const Text(
            'Enter Verification Code',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            "We've sent a 6-digit code to\n+91 ${_phoneController.text.trim()}",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
          ),

          const SizedBox(height: 28),

          // 6 Split Boxes for OTP
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (idx) {
              return Container(
                width: 44,
                height: 52,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _otpControllers[idx].text.isNotEmpty ? widget.themeColor : const Color(0xFFCBD5E1),
                    width: _otpControllers[idx].text.isNotEmpty ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
                    BoxShadow(
                      color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
                      offset: const Offset(2, 2.5),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: TextField(
                    controller: _otpControllers[idx],
                    focusNode: _otpFocusNodes[idx],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                    onChanged: (val) {
                      if (val.isNotEmpty && idx < 5) {
                        _otpFocusNodes[idx + 1].requestFocus();
                      } else if (val.isEmpty && idx > 0) {
                        _otpFocusNodes[idx - 1].requestFocus();
                      }
                      setState(() {});
                    },
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 20),

          // Countdown Timer & Resend
          _resendTimerSeconds > 0
              ? Text(
                  'Resend Code in 00:${_resendTimerSeconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                )
              : TextButton(
                  onPressed: _handleSendOtp,
                  child: Text(
                    'Resend OTP',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: widget.themeColor),
                  ),
                ),

          const SizedBox(height: 24),

          // Primary Button: Verify & Login
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _handleVerifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 3,
                shadowColor: widget.themeColor.withValues(alpha: 0.4),
              ),
              child: const Text('Verify & Login', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 7: USER PROFILE CREATED / WELCOME
  // =========================================================================
  Widget _buildStep7WelcomeProfileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // Confetti Celebration Checkmark
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0xFF10B981), blurRadius: 16, spreadRadius: -2),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text(
            'Welcome to ${widget.restaurant.name}! 🎉',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your account has been created successfully.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),

          const SizedBox(height: 32),

          // Profile Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
                BoxShadow(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.16),
                  offset: const Offset(2, 2.5),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, color: Color(0xFF10B981), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentCustomer?.name ?? 'Chandan Kumar',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _currentCustomer?.phone ?? '+91 97095 93705',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Primary Button: Continue to Order ->
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _navigateToStep(8),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 3,
                shadowColor: widget.themeColor.withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue to Order', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 8: DELIVERY DETAILS
  // =========================================================================
  Widget _buildStep8DeliveryDetailsView() {
    final addresses = _currentCustomer?.addresses ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCircularNavButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => _navigateToStep(3),
              ),
              const SizedBox(width: 14),
              const Text(
                'Delivery Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Saved Addresses',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              TextButton(
                onPressed: _showAddNewAddressDialog,
                child: Text(
                  '+ Add New',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: widget.themeColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Saved Addresses Cards
          ...addresses.map((addr) {
            final isSelected = _selectedAddress?.id == addr.id;
            return GestureDetector(
              onTap: () => setState(() => _selectedAddress = addr),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? widget.themeColor : const Color(0xFFE2E8F0),
                    width: isSelected ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
                    BoxShadow(
                      color: isSelected
                          ? widget.themeColor.withValues(alpha: 0.2)
                          : const Color(0xFF94A3B8).withValues(alpha: 0.15),
                      offset: const Offset(2, 2.5),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? widget.themeColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        addr.label.toLowerCase() == 'home' ? Icons.location_on_rounded : Icons.work_rounded,
                        color: isSelected ? widget.themeColor : const Color(0xFF64748B),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                addr.label,
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                              OutlinedButton(
                                onPressed: () {},
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Edit', style: TextStyle(fontSize: 11, color: Color(0xFF0F172A))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            addr.fullAddress,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? widget.themeColor : const Color(0xFFCBD5E1),
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: widget.themeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),

          // + Add New Address Dotted Button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            child: OutlinedButton.icon(
              onPressed: _showAddNewAddressDialog,
              icon: Icon(Icons.add, color: widget.themeColor, size: 18),
              label: Text(
                '+ Add New Address',
                style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: widget.themeColor.withValues(alpha: 0.5), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          // Delivery Instructions (Optional)
          const Text(
            'Delivery Instructions (Optional)',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDE3EC)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.22),
                  offset: const Offset(1.5, 1.5),
                  blurRadius: 3,
                ),
                const BoxShadow(color: Colors.white, offset: Offset(-1.5, -1.5), blurRadius: 3),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: TextField(
              controller: _deliveryInstructionsController,
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              decoration: const InputDecoration(
                hintText: 'e.g. Call me when you reach, Gate no. 2',
                hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Primary Button: Continue to Payment ->
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => _navigateToStep(9),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 3,
                shadowColor: widget.themeColor.withValues(alpha: 0.4),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Continue to Payment', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddNewAddressDialog() {
    final labelCtrl = TextEditingController(text: 'Home');
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Delivery Address', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Label (Home, Work, Other)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(labelText: 'Full Address'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (addressCtrl.text.trim().isNotEmpty) {
                final newAddr = CustomerAddressModel(
                  id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
                  label: labelCtrl.text.trim().isNotEmpty ? labelCtrl.text.trim() : 'Other',
                  fullAddress: addressCtrl.text.trim(),
                );
                final updated = await _customerService.saveAddress(newAddr);
                if (mounted && updated != null) {
                  setState(() {
                    _currentCustomer = updated;
                    _selectedAddress = newAddr;
                  });
                }
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor, foregroundColor: Colors.white),
            child: const Text('Save Address'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 9: SELECT PAYMENT METHOD
  // =========================================================================
  Widget _buildStep9PaymentMethodView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildCircularNavButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => _navigateToStep(8),
              ),
              const SizedBox(width: 14),
              const Text(
                'Select Payment Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Payment Option 1: Cash on Delivery
          _buildPaymentOptionCard(
            title: 'Cash on Delivery',
            subtitle: 'Pay when you receive your order',
            icon: Icons.payments_rounded,
            value: 'Cash on Delivery',
          ),

          // Payment Option 2: UPI
          _buildPaymentOptionCard(
            title: 'UPI (Google Pay, PhonePe, etc.)',
            subtitle: 'Pay directly via UPI apps',
            icon: Icons.qr_code_rounded,
            value: 'UPI',
            trailingWidget: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('GPay • PhonePe • Paytm', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              ],
            ),
          ),

          // Payment Option 3: Credit / Debit Card
          _buildPaymentOptionCard(
            title: 'Credit / Debit Card',
            subtitle: 'Visa, MasterCard, RuPay',
            icon: Icons.credit_card_rounded,
            value: 'Credit / Debit Card',
          ),

          // Payment Option 4: Wallets
          _buildPaymentOptionCard(
            title: 'Wallets',
            subtitle: 'Paytm, Amazon Pay, etc.',
            icon: Icons.account_balance_wallet_rounded,
            value: 'Wallets',
          ),

          const SizedBox(height: 16),

          // Bill Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
                BoxShadow(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
                  offset: const Offset(2, 2.5),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bill Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                    Text('₹${_grandTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                  ],
                ),
                const SizedBox(height: 8),
                _buildBillRow('Item Total', '₹${_itemTotal.toStringAsFixed(0)}'),
                const SizedBox(height: 4),
                _buildBillRow('Delivery Charge', '₹${_deliveryCharge.toStringAsFixed(0)}'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Primary Button: Place Order • ₹377 (with Padlock)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSubmittingOrder ? null : _handlePlaceOrder,
              icon: _isSubmittingOrder
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.lock_rounded, size: 18),
              label: Text(
                _isSubmittingOrder ? 'Placing Order...' : 'Place Order • ₹${_grandTotal.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.themeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                elevation: 3,
                shadowColor: widget.themeColor.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    Widget? trailingWidget,
  }) {
    final isSelected = _selectedPaymentMethod == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? widget.themeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: [
            const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
            BoxShadow(
              color: isSelected
                  ? widget.themeColor.withValues(alpha: 0.2)
                  : const Color(0xFF94A3B8).withValues(alpha: 0.15),
              offset: const Offset(2, 2.5),
              blurRadius: 5,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? widget.themeColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? widget.themeColor : const Color(0xFF64748B), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  if (trailingWidget != null) ...[
                    const SizedBox(height: 4),
                    trailingWidget,
                  ],
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? widget.themeColor : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: widget.themeColor, shape: BoxShape.circle),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 10: ORDER CONFIRMATION & LIVE TRACKING
  // =========================================================================
  Widget _buildStep10OrderConfirmationView() {
    final order = _activeOrder;
    final orderNumber = order?.orderNumber ?? '#ORD-261023-3714';
    final currentStepIdx = order?.currentStepIndex ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 10),

          // Celebration Checkmark with Confetti
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: widget.themeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: widget.themeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: widget.themeColor.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: -2),
                  ],
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'Order Placed Successfully! 🎉',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            'Order $orderNumber',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: widget.themeColor),
          ),
          const SizedBox(height: 4),
          const Text(
            "We've received your order and it's being prepared.",
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),

          const SizedBox(height: 20),

          // Estimated Delivery Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
                BoxShadow(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
                  offset: const Offset(2, 2.5),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.themeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delivery_dining_rounded, color: widget.themeColor, size: 26),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estimated Delivery', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    Text(
                      order?.estimatedDeliveryMinutes ?? '25 - 35 mins',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Live Vertical Status Timeline Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
                BoxShadow(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.15),
                  offset: const Offset(2, 2.5),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildTimelineItem(
                  title: 'Order Confirmed',
                  time: '12:42 PM',
                  isCompleted: currentStepIdx >= 0,
                  isActive: currentStepIdx == 0,
                  isLast: false,
                ),
                _buildTimelineItem(
                  title: 'Preparing Your Food',
                  time: currentStepIdx >= 1 ? '12:48 PM' : null,
                  isCompleted: currentStepIdx >= 1,
                  isActive: currentStepIdx == 1,
                  isLast: false,
                ),
                _buildTimelineItem(
                  title: 'Out for Delivery',
                  time: currentStepIdx >= 2 ? '01:05 PM' : null,
                  isCompleted: currentStepIdx >= 2,
                  isActive: currentStepIdx == 2,
                  isLast: false,
                ),
                _buildTimelineItem(
                  title: 'Delivered',
                  time: currentStepIdx >= 3 ? '01:17 PM' : null,
                  isCompleted: currentStepIdx >= 3,
                  isActive: currentStepIdx == 3,
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons: View Order Details & Back to Home
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _showOrderDetailsSheet(order),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('View Order Details', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 13.5)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.themeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      elevation: 2,
                    ),
                    child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String title,
    String? time,
    required bool isCompleted,
    required bool isActive,
    required bool isLast,
  }) {
    final activeColor = const Color(0xFF10B981); // Green timeline indicator

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicator circle and vertical line
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? activeColor : const Color(0xFFF1F5F9),
                border: Border.all(
                  color: isCompleted ? activeColor : const Color(0xFFCBD5E1),
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : (isActive
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: activeColor, shape: BoxShape.circle),
                          ),
                        )
                      : null),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted ? activeColor : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),

        // Title and Time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive || isCompleted ? FontWeight.w800 : FontWeight.w600,
                  color: isCompleted || isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                ),
              ),
              if (time != null)
                Text(
                  time,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  void _showOrderDetailsSheet(CustomerOrderTrackingModel? order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Order Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text('Order ID: ${order?.orderNumber ?? ""}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Delivery To: ${order?.deliveryAddress ?? ""}', style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Text('Payment Method: ${order?.paymentMethod ?? ""}', style: const TextStyle(color: Color(0xFF64748B))),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Amount Paid:', style: TextStyle(fontWeight: FontWeight.w800)),
                  Text('₹${order?.grandTotal.toStringAsFixed(0) ?? ""}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF10B981))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlowingIllustration({required IconData icon, required Color color}) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildCircularNavButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          const BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 4),
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.2),
            offset: const Offset(2, 2.5),
            blurRadius: 5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(icon, size: 20, color: const Color(0xFF0F172A)),
          ),
        ),
      ),
    );
  }

  Widget _buildVegDot(String itemType) {
    final isVeg = itemType.toLowerCase().contains('veg') && !itemType.toLowerCase().contains('non');
    final color = isVeg ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Center(
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
