import 'package:flutter/material.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/restaurant_model.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/storefront_model.dart';
import '../services/storefront_service.dart';

class StorefrontCartSheet extends StatefulWidget {
  final RestaurantModel restaurant;
  final List<StorefrontCartItem> cartItems;
  final OrderType initialOrderType;
  final String deliveryAddress;
  final Function(StorefrontCartItem item, int newQty) onUpdateQuantity;
  final VoidCallback onClearCart;
  final Color themeColor;
  final bool isOnline;

  const StorefrontCartSheet({
    super.key,
    required this.restaurant,
    required this.cartItems,
    required this.initialOrderType,
    required this.deliveryAddress,
    required this.onUpdateQuantity,
    required this.onClearCart,
    this.themeColor = const Color(0xFFE65100),
    this.isOnline = true,
  });

  @override
  State<StorefrontCartSheet> createState() => _StorefrontCartSheetState();
}

class _StorefrontCartSheetState extends State<StorefrontCartSheet> {
  late OrderType _orderType;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  late TextEditingController _addressController;
  final TextEditingController _notesController = TextEditingController();

  String _paymentMethod = 'UPI'; // 'UPI' or 'Cash'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _orderType = widget.initialOrderType;
    _addressController = TextEditingController(text: widget.deliveryAddress);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal {
    return widget.cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get _taxAmount {
    return (_subtotal * (widget.restaurant.taxRate / 100.0));
  }

  double get _deliveryFee {
    if (_orderType == OrderType.takeaway) return 0.0;
    if (widget.restaurant.freeDeliveryEnabled && _subtotal >= widget.restaurant.freeDeliveryMinOrder) {
      return 0.0;
    }
    return widget.restaurant.deliveryBaseCharge > 0 ? widget.restaurant.deliveryBaseCharge : 30.0;
  }

  double get _grandTotal => _subtotal + _taxAmount + _deliveryFee;

  Future<void> _handlePlaceOrder() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    if (name.isEmpty) {
      _showWarning('Please enter your name');
      return;
    }
    if (phone.isEmpty || phone.length < 10) {
      _showWarning('Please enter a valid 10-digit mobile number');
      return;
    }
    if (_orderType == OrderType.delivery && address.isEmpty) {
      _showWarning('Please enter your delivery address');
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await StorefrontService().submitOrder(
      restaurant: widget.restaurant,
      orderType: _orderType,
      cartItems: widget.cartItems,
      customerName: name,
      customerPhone: phone,
      deliveryAddress: address,
      subtotal: _subtotal,
      taxAmount: _taxAmount,
      deliveryFee: _deliveryFee,
      totalAmount: _grandTotal,
      paymentMethod: _paymentMethod,
      specialNote: _notesController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      widget.onClearCart();
      Navigator.pop(context);
      _showOrderSuccessDialog(context, name, phone);
    } else {
      _showWarning('Could not complete order right now. Please try again or call the outlet.');
    }
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showOrderSuccessDialog(BuildContext ctx, String customerName, String customerPhone) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Order Placed Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Thank you, $customerName!\nYour ${_orderType == OrderType.delivery ? "delivery" : "takeaway"} order has been sent to ${widget.restaurant.name}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated Time:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  Text(
                    _orderType == OrderType.delivery ? '25–35 Mins' : '15–20 Mins',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFE65100)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Menu', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cartItems.isEmpty) {
      return Container(
        height: 280,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🛒', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text('Add some delicious items from the menu to order.', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Explore Menu'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Your Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${widget.cartItems.length} items',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Scrollable Cart Items & Customer Form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Type Toggle (Delivery vs Pickup)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _orderType = OrderType.delivery),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _orderType == OrderType.delivery ? const Color(0xFFE65100) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.two_wheeler_rounded,
                                    size: 16,
                                    color: _orderType == OrderType.delivery ? Colors.white : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Delivery',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _orderType == OrderType.delivery ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _orderType = OrderType.takeaway),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _orderType == OrderType.takeaway ? const Color(0xFFE65100) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.store_mall_directory_rounded,
                                    size: 16,
                                    color: _orderType == OrderType.takeaway ? Colors.white : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      'Pickup',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _orderType == OrderType.takeaway ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Cart Items List
                  ...widget.cartItems.map((cartItem) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 52,
                              height: 52,
                              color: const Color(0xFFE2E8F0),
                              child: (cartItem.item.imageUrl.isNotEmpty)
                                  ? Image.network(
                                      ApiEndpoints.resolveMediaUrl(cartItem.item.imageUrl),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const Center(child: Text('🍕', style: TextStyle(fontSize: 24))),
                                    )
                                  : const Center(child: Text('🍕', style: TextStyle(fontSize: 24))),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cartItem.item.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (cartItem.selectedSize != null)
                                  Text(
                                    'Size: ${cartItem.selectedSize!.name} (₹${cartItem.selectedSize!.price.toStringAsFixed(0)})',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                if (cartItem.selectedAddons.where((a) => a.isSelected).isNotEmpty)
                                  Text(
                                    'Addons: ${cartItem.selectedAddons.where((a) => a.isSelected).map((a) => a.name).join(', ')}',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFFE65100)),
                                  ),
                                if (cartItem.instructions.isNotEmpty)
                                  Text(
                                    'Note: "${cartItem.instructions}"',
                                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  '₹${cartItem.totalPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Quantity buttons
                          Row(
                            children: [
                              InkWell(
                                onTap: () => widget.onUpdateQuantity(cartItem, cartItem.quantity - 1),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: const Icon(Icons.remove_rounded, size: 16, color: Color(0xFF0F172A)),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  '${cartItem.quantity}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                              ),
                              InkWell(
                                onTap: () => widget.onUpdateQuantity(cartItem, cartItem.quantity + 1),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE65100),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  // Customer Details Form
                  const Text(
                    'Contact & Delivery Details',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),

                  // Name & Phone in Row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            labelText: 'Your Name',
                            labelStyle: const TextStyle(fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            labelText: 'Mobile Number',
                            labelStyle: const TextStyle(fontSize: 12),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_orderType == OrderType.delivery) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _addressController,
                      style: const TextStyle(fontSize: 12.5),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Complete Delivery Address',
                        labelStyle: const TextStyle(fontSize: 12),
                        hintText: 'House/Flat No, Apartment, Street & Landmark',
                        hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Payment Method Switcher
                  const Text(
                    'Payment Method',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _paymentMethod = 'UPI'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                            decoration: BoxDecoration(
                              color: _paymentMethod == 'UPI' ? const Color(0xFFFFF3E0) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _paymentMethod == 'UPI' ? const Color(0xFFE65100) : const Color(0xFFE2E8F0),
                                width: _paymentMethod == 'UPI' ? 1.8 : 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFFE65100)),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'UPI / QR Pay',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _paymentMethod = 'Cash'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                            decoration: BoxDecoration(
                              color: _paymentMethod == 'Cash' ? const Color(0xFFFFF3E0) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _paymentMethod == 'Cash' ? const Color(0xFFE65100) : const Color(0xFFE2E8F0),
                                width: _paymentMethod == 'Cash' ? 1.8 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.payments_outlined, size: 18, color: Color(0xFF10B981)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _orderType == OrderType.delivery ? 'Pay on Delivery' : 'Pay at Store',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Bill Breakdown
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _buildBillRow('Item Subtotal', '₹${_subtotal.toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        _buildBillRow('Taxes & Charges (GST)', '₹${_taxAmount.toStringAsFixed(0)}'),
                        const SizedBox(height: 8),
                        _buildBillRow(
                          'Delivery Fee',
                          _deliveryFee == 0 ? 'FREE' : '₹${_deliveryFee.toStringAsFixed(0)}',
                          valueColor: _deliveryFee == 0 ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: Color(0xFFCBD5E1)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'To Pay',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '₹${_grandTotal.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFE65100)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sticky Bottom Checkout Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  offset: const Offset(0, -4),
                  blurRadius: 16,
                )
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isSubmitting || !widget.isOnline) ? null : _handlePlaceOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isOnline ? widget.themeColor : const Color(0xFF94A3B8),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    disabledForegroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.isOnline
                                    ? 'Place ${_orderType == OrderType.delivery ? "Delivery" : "Takeaway"} Order • ₹${_grandTotal.toStringAsFixed(0)}'
                                    : 'Store is Offline • Ordering Paused',
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(widget.isOnline ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded, size: 18),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(String label, String value, {Color valueColor = const Color(0xFF0F172A)}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: valueColor),
        ),
      ],
    );
  }
}
