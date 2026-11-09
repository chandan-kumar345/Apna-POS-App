import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/models/order_model.dart';
import 'package:flutter/services.dart';
import '../models/customer_storefront_flow_models.dart';
import '../models/storefront_model.dart';
import '../services/customer_storefront_api_service.dart';
import '../screens/customer_my_orders_screen.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/services/coupon_service.dart';

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
  final String? tableCode;
  final String? restaurantCode;

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
    this.tableCode,
    this.restaurantCode,
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
  final TextEditingController _phoneController = TextEditingController();
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

  bool get _isTableOrder => widget.tableCode != null && widget.tableCode!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    if (_isTableOrder) {
      _selectedAddress = CustomerAddressModel(
        id: 'addr_table_${widget.tableCode}',
        label: 'Dining Table',
        fullAddress: 'Table ${widget.tableCode}, ${widget.restaurant.name}',
        isDefault: true,
      );
      _currentCustomer = null;
    } else {
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
  double get _deliveryCharge => _isTableOrder
      ? 0.0
      : (_itemTotal > 0 ? (widget.restaurant.deliveryBaseCharge > 0 ? widget.restaurant.deliveryBaseCharge : 40.0) : 0.0);
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

  Future<void> _handleProceedToCheckout() async {
    if (_isTableOrder) {
      // Direct Table Order: Ask for customer details via bottom sheet and place order directly!
      // Bypasses Step 8 (dining table details) and Step 9 (payment method selection).
      final details = await _showCustomerDetailsBottomSheet();
      if (details == null) {
        return; // User cancelled
      }

      _selectedAddress = CustomerAddressModel(
        id: 'addr_table_${widget.tableCode}',
        label: 'Dining Table',
        fullAddress: 'Table ${widget.tableCode}, ${widget.restaurant.name}',
        isDefault: true,
      );
      _currentCustomer = CustomerProfileModel(
        id: 'cust_table_${DateTime.now().millisecondsSinceEpoch}',
        phone: details['phone']!,
        name: details['name']!,
        addresses: [_selectedAddress!],
      );
      if (details['instructions'] != null && details['instructions']!.isNotEmpty) {
        _deliveryInstructionsController.text = details['instructions']!;
      }
      _selectedPaymentMethod = 'Pay at Counter (Dine-In)';

      await _executeOrderPlacement();
      return;
    }

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

  Future<Map<String, String>?> _showCustomerDetailsBottomSheet() async {
    final formKey = GlobalKey<FormState>();
    // Strictly NO PREFILL DETAILS as requested by user
    final nameController = TextEditingController(text: '');
    final phoneController = TextEditingController(text: '');
    final instructionsController = TextEditingController(
      text: _deliveryInstructionsController.text.trim(),
    );

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(bottomCtx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header with Table Number & Close
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Icon(Icons.table_restaurant_rounded, size: 22, color: Color(0xFF15803D)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Table ${widget.tableCode ?? "01"} • Customer Details',
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Enter your details to send order to the kitchen',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.of(bottomCtx).pop(null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),

                  const Divider(height: 24, color: Color(0xFFE2E8F0)),

                  // 1. Customer Name Field (Clear high contrast black text, no prefill)
                  const Text(
                    'Customer Name *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your name (e.g. Rahul Sharma)',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.themeColor, width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      if (val.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // 2. Mobile Number Field (Clear high contrast black text, no prefill)
                  const Text(
                    'Mobile Number *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      hintText: '10-digit mobile number',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.phone_outlined, size: 18, color: Color(0xFF64748B)),
                            SizedBox(width: 6),
                            Text(
                              '+91',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.themeColor, width: 1.5),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your mobile number';
                      }
                      final digits = val.replaceAll(RegExp(r'\D'), '');
                      if (digits.length != 10) {
                        return 'Enter a valid 10-digit number';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 14),

                  // 3. Special Requests / Kitchen Notes (Optional)
                  const Text(
                    'Kitchen Requests (Optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: instructionsController,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Less spicy, no onions, extra napkins',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 24),
                        child: Icon(Icons.edit_note_rounded, size: 22, color: Color(0xFF64748B)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: widget.themeColor, width: 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment & Total Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.point_of_sale_rounded, size: 18, color: Color(0xFF0F172A)),
                            SizedBox(width: 8),
                            Text(
                              'Pay at Counter',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Text(
                          '₹${_grandTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Confirm & Send to Kitchen Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() == true) {
                          final name = nameController.text.trim();
                          final rawPhone = phoneController.text.trim();
                          final cleanPhone = rawPhone.startsWith('+91') ? rawPhone : '+91 $rawPhone';
                          Navigator.of(bottomCtx).pop({
                            'name': name,
                            'phone': cleanPhone,
                            'instructions': instructionsController.text.trim(),
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.themeColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.soup_kitchen_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Confirm & Send to Kitchen • ₹${_grandTotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showOrderSuccessDialog(CustomerOrderTrackingModel order) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 44,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Order Placed Successfully! 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your order has been sent to the kitchen. Fresh food is being prepared for your table!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                  softWrap: true,
                ),
                const SizedBox(height: 14),

                // Order & Table Info Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ORDER ID',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.orderNumber,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          'Table ${widget.tableCode ?? "01"}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Primary Button: View Order
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(dialogCtx).pop(); // Close success dialog
                      Navigator.of(context).pop(); // Close checkout flow sheet
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerMyOrdersScreen(
                            order: order,
                            restaurant: widget.restaurant,
                            tableCode: widget.tableCode,
                            themeColor: widget.themeColor,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'View Order',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.themeColor,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Secondary Text Button: Order More Items
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop(); // Close success dialog
                    Navigator.of(context).pop(); // Close checkout flow sheet
                  },
                  child: const Text(
                    'Order More Items',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeOrderPlacement() async {
    setState(() => _isSubmittingOrder = true);
    final stopwatch = Stopwatch()..start();

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
      tableNumber: widget.tableCode,
      orderType: _isTableOrder ? OrderType.dineIn : OrderType.delivery,
    );

    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 800) {
      await Future.delayed(Duration(milliseconds: 800 - elapsed));
    }

    if (mounted) {
      setState(() => _isSubmittingOrder = false);
    }

    if (order != null && mounted) {
      setState(() => _activeOrder = order);
      widget.onClearCart();
      _subscribeToOrderUpdates(order.orderId);

      if (_isTableOrder) {
        await _showOrderSuccessDialog(order);
      } else {
        _navigateToStep(10); // Order Confirmation & Live Tracking
      }
    } else {
      _showSnackbar('Could not place order. Please try again.');
    }
  }

  Future<void> _handlePlaceOrder() async {
    if (_isTableOrder) {
      await _handleProceedToCheckout();
      return;
    } else if (_selectedAddress == null) {
      _showSnackbar('Please select or add a delivery address');
      _navigateToStep(8);
      return;
    }

    await _executeOrderPlacement();
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

  bool get _isRestaurantCategory {
    final cuisine = widget.restaurant.cuisineType.toLowerCase();
    const nonFoodCategories = [
      'grocery', 'retail', 'fashion', 'apparel', 'footwear', 'jewelry',
      'watch', 'beauty', 'personal care', 'furniture', 'home decor',
      'building materials', 'e-commerce', 'electronics', 'books',
      'stationery', 'pharmacy', 'clinic', 'healthcare', 'sports',
      'fitness', 'gym', 'automobile', 'real estate', 'hardware',
      'agriculture', 'pet shop', 'entertainment', 'services',
    ];
    for (final nonFood in nonFoodCategories) {
      if (cuisine.contains(nonFood)) return false;
    }
    return true;
  }

  Widget _buildSubmittingOrderOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 28, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isRestaurantCategory) ...[
                  Container(
                    width: 140,
                    height: 140,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/restaurant_loader.gif',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/restaurant_cooking_pan.jpg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sending Order to Kitchen...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Tossing fresh ingredients & notifying chefs',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ] else ...[
                  CircularProgressIndicator(color: widget.themeColor, strokeWidth: 3),
                  const SizedBox(height: 16),
                  const Text(
                    'Placing Your Order...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
      child: Stack(
        children: [
          Column(
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
          if (_isSubmittingOrder) _buildSubmittingOrderOverlay(),
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
                  Row(
                    children: [
                      const Text(
                        'Your Cart',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      if (_isTableOrder) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.table_restaurant_rounded, size: 14, color: Color(0xFF15803D)),
                              const SizedBox(width: 4),
                              Text(
                                'Table ${widget.tableCode}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
                      // Table Order Dine-in Strip
                      if (_isTableOrder)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.table_restaurant_rounded, size: 18, color: Color(0xFF16A34A)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Table ${widget.tableCode} • Dine-In Order',
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF15803D),
                                      ),
                                    ),
                                    const Text(
                                      'Order will be delivered directly to your table',
                                      style: TextStyle(fontSize: 11.5, color: Color(0xFF166534)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

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
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _handleProceedToCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.themeColor,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: widget.themeColor.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isTableOrder ? 'Send Order to Kitchen' : 'Proceed to Checkout',
                                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _isTableOrder ? Icons.soup_kitchen_rounded : Icons.arrow_forward_rounded,
                                size: 19,
                              ),
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
    final String sizeText;
    if (cartItem.selectedSize != null && cartItem.selectedSize!.name.isNotEmpty) {
      if (cartItem.selectedSize!.description.isNotEmpty) {
        sizeText = '${cartItem.selectedSize!.name} (${cartItem.selectedSize!.description})';
      } else {
        sizeText = cartItem.selectedSize!.name;
      }
    } else {
      sizeText = '';
    }

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
        crossAxisAlignment: CrossAxisAlignment.start,
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

          // Title & Size & Price (Full product text clearly visible)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _buildVegDot(cartItem.item.itemType),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cartItem.item.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (sizeText.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sizeText,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
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
    final bool hasCoupon = _appliedCouponCode != null && _appliedCouponCode!.isNotEmpty;
    return InkWell(
      onTap: hasCoupon ? null : _showCouponsBottomSheet,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                    hasCoupon ? 'Coupon Applied: $_appliedCouponCode' : 'Apply Coupon',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  if (hasCoupon)
                    Text(
                      'Saved ₹${_couponDiscount.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF10B981), fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
            if (hasCoupon)
              TextButton(
                onPressed: () {
                  setState(() {
                    _appliedCouponCode = null;
                    _couponDiscount = 0.0;
                  });
                  _showSnackbar('Coupon removed');
                },
                child: const Row(
                  children: [
                    Text(
                      'Remove',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Color(0xFFEF4444),
                    ),
                  ],
                ),
              )
            else
              TextButton(
                onPressed: _showCouponsBottomSheet,
                child: const Row(
                  children: [
                    Text(
                      'Select a coupon',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCouponsBottomSheet() async {
    // 1. Load active coupons from CouponService or fallback list
    List<CouponModel> availableCoupons = [];
    try {
      final res = await CouponService().getCoupons(status: 'active');
      availableCoupons = res.coupons.where((c) => c.isActive && !c.isExpired).toList();
    } catch (e) {
      debugPrint('[CheckoutSheet] getCoupons error: $e');
    }

    // Fallback offers if none configured yet
    if (availableCoupons.isEmpty) {
      availableCoupons = [
        const CouponModel(
          id: 'welcome_50',
          code: 'WELCOME50',
          title: 'Flat ₹50 OFF',
          description: 'Special discount on your order',
          discountType: 'flat',
          discountValue: 50.0,
          minCartAmount: 200.0,
          isActive: true,
        ),
        const CouponModel(
          id: 'chef_20',
          code: 'CHEF20',
          title: '20% OFF Chef Special',
          description: 'Get 20% discount on order value',
          discountType: 'percentage',
          discountValue: 20.0,
          maxDiscountAmount: 100.0,
          minCartAmount: 300.0,
          isActive: true,
        ),
        const CouponModel(
          id: 'festive_100',
          code: 'FESTIVE100',
          title: 'Flat ₹100 Mega Saver',
          description: 'Save ₹100 on party & family feasts',
          discountType: 'flat',
          discountValue: 100.0,
          minCartAmount: 500.0,
          isActive: true,
        ),
      ];
    }

    final codeInputController = TextEditingController();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (bottomCtx, setModalState) {
            void applySpecificCoupon(CouponModel coupon) {
              if (_itemTotal < coupon.minCartAmount) {
                final diff = (coupon.minCartAmount - _itemTotal).toStringAsFixed(0);
                Navigator.of(sheetCtx).pop();
                _showSnackbar('Add ₹$diff more to apply coupon ${coupon.code}');
                return;
              }

              double discount = 0.0;
              if (coupon.isPercentage) {
                discount = (_itemTotal * coupon.discountValue) / 100.0;
                if (coupon.maxDiscountAmount != null && coupon.maxDiscountAmount! > 0) {
                  discount = discount > coupon.maxDiscountAmount! ? coupon.maxDiscountAmount! : discount;
                }
              } else {
                discount = coupon.discountValue > _itemTotal ? _itemTotal : coupon.discountValue;
              }

              setState(() {
                _appliedCouponCode = coupon.code;
                _couponDiscount = discount;
              });

              Navigator.of(sheetCtx).pop();
              _showSnackbar('Coupon ${coupon.code} applied! Saved ₹${discount.toStringAsFixed(0)}');
            }

            void applyEnteredCode() async {
              final code = codeInputController.text.trim().toUpperCase();
              if (code.isEmpty) {
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  const SnackBar(content: Text('Please enter a coupon code')),
                );
                return;
              }

              // Check in available coupons
              final match = availableCoupons.firstWhere(
                (c) => c.code.toUpperCase() == code,
                orElse: () => const CouponModel(
                  id: '',
                  code: '',
                  discountValue: 0,
                  isActive: false,
                ),
              );

              if (match.code.isNotEmpty) {
                applySpecificCoupon(match);
                return;
              }

              // Validate via CouponService
              final val = await CouponService().validateCoupon(
                code: code,
                cartSubtotal: _itemTotal,
                orderType: _isTableOrder ? 'dine_in' : 'delivery',
              );

              if (val.valid) {
                setState(() {
                  _appliedCouponCode = val.code ?? code;
                  _couponDiscount = val.discountAmount;
                });
                if (Navigator.of(sheetCtx).canPop()) {
                  Navigator.of(sheetCtx).pop();
                }
                _showSnackbar(val.message ?? 'Coupon applied!');
              } else {
                ScaffoldMessenger.of(sheetCtx).showSnackBar(
                  SnackBar(
                    content: Text(val.message ?? 'Invalid coupon code'),
                    backgroundColor: const Color(0xFFEF4444),
                  ),
                );
              }
            }

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Apply Coupon',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Choose or enter a promo code to get discounts',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Coupon Code Input Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          const Icon(Icons.confirmation_number_outlined, size: 20, color: Color(0xFF64748B)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: codeInputController,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.8,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Enter coupon code',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0,
                                  fontWeight: FontWeight.normal,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: applyEnteredCode,
                            style: TextButton.styleFrom(
                              backgroundColor: widget.themeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                              'APPLY',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Available Coupons List
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      itemCount: availableCoupons.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 12),
                      itemBuilder: (c, idx) {
                        final coupon = availableCoupons[idx];
                        final bool isEligible = _itemTotal >= coupon.minCartAmount;
                        final bool isCurrent = _appliedCouponCode == coupon.code;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurrent
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFE2E8F0),
                              width: isCurrent ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF94A3B8).withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Dashed coupon badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: widget.themeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: widget.themeColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      coupon.code,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        color: widget.themeColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),

                                  if (isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'APPLIED',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF16A34A),
                                        ),
                                      ),
                                    )
                                  else
                                    ElevatedButton(
                                      onPressed: () => applySpecificCoupon(coupon),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isEligible ? widget.themeColor : const Color(0xFF94A3B8),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text(
                                        'APPLY',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                coupon.title.isNotEmpty ? coupon.title : 'Special Offer',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (coupon.description.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  coupon.description,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                              const SizedBox(height: 8),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    isEligible ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                                    size: 14,
                                    color: isEligible ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      isEligible
                                          ? 'Valid on this order (min order: ₹${coupon.minCartAmount.toStringAsFixed(0)})'
                                          : 'Add ₹${(coupon.minCartAmount - _itemTotal).toStringAsFixed(0)} more to unlock this coupon',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isEligible ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
          if (!_isTableOrder) ...[
            const SizedBox(height: 8),
            _buildBillRow('Delivery Charge', '₹${_deliveryCharge.toStringAsFixed(0)}'),
          ],
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
              Text(
                _isTableOrder ? 'Dining Table Details' : 'Delivery Details',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (_isTableOrder) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dining at Table ${widget.tableCode}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.restaurant.name} • Dine-In Ordering',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Your freshly prepared food will be served directly to your table.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF065F46)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
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
          ],

          // Delivery Instructions (Optional)
          Text(
            _isTableOrder ? 'Special Instructions for Kitchen (Optional)' : 'Delivery Instructions (Optional)',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
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
                if (!_isTableOrder) ...[
                  const SizedBox(height: 4),
                  _buildBillRow('Delivery Charge', '₹${_deliveryCharge.toStringAsFixed(0)}'),
                ],
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

          const SizedBox(height: 16),

          // Restaurant Live Kitchen Preparing Animation
          if (_isRestaurantCategory && currentStepIdx <= 1) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/restaurant_loader.gif',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/restaurant_cooking_pan.jpg',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Kitchen is Preparing Your Food',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Chefs are tossing fresh ingredients for your order',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

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
