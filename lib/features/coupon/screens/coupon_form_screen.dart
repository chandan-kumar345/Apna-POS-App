import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/services/coupon_service.dart';
import '../../../core/widgets/food_type_icon.dart';

class CouponFormScreen extends StatefulWidget {
  final CouponModel? existingCoupon;
  final VoidCallback onSaved;

  const CouponFormScreen({
    super.key,
    this.existingCoupon,
    required this.onSaved,
  });

  @override
  State<CouponFormScreen> createState() => _CouponFormScreenState();
}

class _CouponFormScreenState extends State<CouponFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _couponService = CouponService();
  final DatabaseService _db = DatabaseService();

  late TextEditingController _codeController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _discountValueController;
  late TextEditingController _maxDiscountController;
  late TextEditingController _minCartAmountController;
  late TextEditingController _usagePerCustomerController;
  late TextEditingController _totalUsageLimitController;
  late TextEditingController _termsController;
  final TextEditingController _productSearchController = TextEditingController();

  String _discountType = 'flat'; // default flat or percentage
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;
  List<String> _selectedOrderTypes = ['dineIn', 'takeaway', 'delivery'];
  String _customerEligibility = 'all';
  int _customerMinOrders = 0;
  List<int> _selectedDays = [0, 1, 2, 3, 4, 5, 6];
  TimeOfDay? _timeSlotStart;
  TimeOfDay? _timeSlotEnd;

  // Accordion Expand/Collapse States
  bool _isBasicInfoExpanded = true;
  bool _isDiscountSettingsExpanded = true;
  bool _isValidityPeriodExpanded = true;
  bool _isProductEligibilityExpanded = true;
  bool _isUsageLimitsExpanded = false;
  bool _isTermsExpanded = false;

  // Product Selection State
  String _productApplicationMode = 'all'; // 'all' or 'specific'
  final Set<String> _selectedProductIds = {};
  String _productCategoryFilter = 'All';
  String _productSearchQuery = '';

  bool _isSaving = false;
  final List<String> _weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    final c = widget.existingCoupon;
    _codeController = TextEditingController(text: c?.code ?? '');
    _titleController = TextEditingController(text: c?.title ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    _discountValueController = TextEditingController(
      text: c != null ? (c.discountValue == c.discountValue.roundToDouble() ? c.discountValue.toStringAsFixed(0) : c.discountValue.toString()) : '',
    );
    _maxDiscountController = TextEditingController(
      text: c?.maxDiscountAmount != null ? (c!.maxDiscountAmount == c.maxDiscountAmount!.roundToDouble() ? c.maxDiscountAmount!.toStringAsFixed(0) : c.maxDiscountAmount.toString()) : '',
    );
    _minCartAmountController = TextEditingController(
      text: c != null && c.minCartAmount > 0 ? (c.minCartAmount == c.minCartAmount.roundToDouble() ? c.minCartAmount.toStringAsFixed(0) : c.minCartAmount.toString()) : '',
    );
    _usagePerCustomerController = TextEditingController(
      text: (c?.usageLimitPerCustomer ?? 1).toString(),
    );
    _totalUsageLimitController = TextEditingController(
      text: (c?.totalUsageLimit ?? 0).toString(),
    );
    _termsController = TextEditingController(
      text: c?.termsAndConditions.join('\n') ?? '',
    );

    if (c != null) {
      _discountType = c.discountType;
      if (c.startDate != null) _startDate = c.startDate!;
      _endDate = c.endDate;
      _isActive = c.isActive;
      _selectedOrderTypes = List.from(c.orderTypes);
      _customerEligibility = c.customerEligibility;
      _customerMinOrders = c.customerMinOrders;
      _selectedDays = List.from(c.validDays);
      if (c.applicableProducts.isNotEmpty) {
        _selectedProductIds.addAll(c.applicableProducts);
        _productApplicationMode = 'specific';
      }
      if (c.timeSlots.isNotEmpty) {
        final parts1 = c.timeSlots.first.startTime.split(':');
        final parts2 = c.timeSlots.first.endTime.split(':');
        if (parts1.length == 2) {
          _timeSlotStart = TimeOfDay(hour: int.tryParse(parts1[0]) ?? 0, minute: int.tryParse(parts1[1]) ?? 0);
        }
        if (parts2.length == 2) {
          _timeSlotEnd = TimeOfDay(hour: int.tryParse(parts2[0]) ?? 23, minute: int.tryParse(parts2[1]) ?? 59);
        }
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _discountValueController.dispose();
    _maxDiscountController.dispose();
    _minCartAmountController.dispose();
    _usagePerCustomerController.dispose();
    _totalUsageLimitController.dispose();
    _termsController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  List<MenuItemModel> get _filteredMenuItems {
    return _db.menuItems.where((item) {
      if (_productCategoryFilter != 'All' && item.category != _productCategoryFilter) {
        return false;
      }
      if (_productSearchQuery.isNotEmpty) {
        final query = _productSearchQuery.toLowerCase();
        final nameMatch = item.name.toLowerCase().contains(query);
        final catMatch = item.category.toLowerCase().contains(query);
        if (!nameMatch && !catMatch) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _pickTimeSlot(bool isStart) async {
    final initial = isStart
        ? (_timeSlotStart ?? const TimeOfDay(hour: 10, minute: 0))
        : (_timeSlotEnd ?? const TimeOfDay(hour: 23, minute: 59));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _timeSlotStart = picked;
        } else {
          _timeSlotEnd = picked;
        }
      });
    }
  }

  Future<void> _saveCoupon() async {
    if (!_formKey.currentState!.validate()) return;

    if (_productApplicationMode == 'specific' && _selectedProductIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 product for specific discount, or choose "All Products".'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final code = _codeController.text.trim().toUpperCase();
    final discountVal = double.tryParse(_discountValueController.text.trim()) ?? 0.0;
    if (discountVal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discount value must be greater than 0'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_discountType == 'percentage' && discountVal > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Percentage discount cannot exceed 100%'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    final coupon = CouponModel(
      id: widget.existingCoupon?.id ?? '',
      code: code,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      discountType: _discountType,
      discountValue: discountVal,
      maxDiscountAmount: _maxDiscountController.text.trim().isNotEmpty
          ? double.tryParse(_maxDiscountController.text.trim())
          : null,
      minCartAmount: double.tryParse(_minCartAmountController.text.trim()) ?? 0.0,
      startDate: _startDate,
      endDate: _endDate,
      isActive: _isActive,
      usageLimitPerCustomer: int.tryParse(_usagePerCustomerController.text.trim()) ?? 1,
      totalUsageLimit: int.tryParse(_totalUsageLimitController.text.trim()) ?? 0,
      totalTimesUsed: widget.existingCoupon?.totalTimesUsed ?? 0,
      customerEligibility: _customerEligibility,
      customerMinOrders: _customerMinOrders,
      orderTypes: _selectedOrderTypes,
      applicableProducts: _productApplicationMode == 'specific' ? _selectedProductIds.toList() : [],
      validDays: _selectedDays,
      timeSlots: (_timeSlotStart != null && _timeSlotEnd != null)
          ? [
              CouponTimeSlot(
                startTime: '${_timeSlotStart!.hour.toString().padLeft(2, '0')}:${_timeSlotStart!.minute.toString().padLeft(2, '0')}',
                endTime: '${_timeSlotEnd!.hour.toString().padLeft(2, '0')}:${_timeSlotEnd!.minute.toString().padLeft(2, '0')}',
              ),
            ]
          : [],
      termsAndConditions: _termsController.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    );

    try {
      if (widget.existingCoupon == null) {
        await _couponService.createCoupon(coupon);
      } else {
        await _couponService.updateCoupon(coupon.id, coupon);
      }
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingCoupon == null ? 'Coupon created successfully!' : 'Coupon updated successfully!'),
            backgroundColor: const Color(0xFF021B54),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save coupon: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  // ===========================================================================
  // LIVE VOUCHER CARD (Pixel-Matched to User Image)
  // ===========================================================================
  Widget _buildLivePreviewCard() {
    final code = _codeController.text.trim().toUpperCase();
    final title = _titleController.text.trim();
    final discVal = _discountValueController.text.trim();

    String discountSubtitle;
    if (discVal.isEmpty) {
      discountSubtitle = _discountType == 'percentage' ? 'Get 0% OFF on all products' : 'Get ₹0 OFF on all products';
    } else if (_discountType == 'percentage') {
      discountSubtitle = 'Get $discVal% OFF on eligible products';
    } else {
      discountSubtitle = 'Get ₹$discVal OFF on all products';
    }

    String productsText;
    if (_productApplicationMode == 'all' || _selectedProductIds.isEmpty) {
      productsText = 'All Products';
    } else {
      productsText = '${_selectedProductIds.length} Product(s)';
    }

    String expiryText;
    if (_endDate != null) {
      expiryText = 'Till ${DateFormat('dd MMM yyyy').format(_endDate!)}';
    } else {
      expiryText = 'No Expiry';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10002870),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Graphic Voucher Section (Vibrant Coral/Rose 3D Gift Box)
              Container(
                width: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF2A6D),
                      Color(0xFFFF5E7E),
                      Color(0xFFFF758C),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Sparkle stars in corners
                    const Positioned(
                      top: 10,
                      left: 12,
                      child: Icon(Icons.auto_awesome, color: Color(0xFFFFD166), size: 13),
                    ),
                    const Positioned(
                      bottom: 12,
                      right: 14,
                      child: Icon(Icons.auto_awesome, color: Color(0xFFFFD166), size: 11),
                    ),

                    // Layered 3D Gift Graphic Representation
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Gift box base
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x35000000),
                                  blurRadius: 10,
                                  offset: Offset(2, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.card_giftcard_rounded,
                                color: Color(0xFFFF5E7E),
                                size: 38,
                              ),
                            ),
                          ),
                          // Discount Tag Badge on Gift
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF0055),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x30000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                '%',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Left scalloped ticket notch
                    Positioned(
                      left: -7,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF0F4F8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Right Information Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Top Row: Code Pill Badge + Status Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFECEE),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFFFCDD2)),
                            ),
                            child: Text(
                              code.isEmpty ? 'WELCOME50' : code,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFE11D48),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _isActive ? 'ACTIVE' : 'DISABLED',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Title & Sparkle
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title.isEmpty ? 'Special Offer' : title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const Icon(Icons.auto_awesome, color: Color(0xFFF59E0B), size: 15),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Subtitle
                      Text(
                        discountSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 7),

                      // Bottom Chips: Cart & Expiry
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFFFFE4E6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shopping_cart_rounded, size: 10, color: Color(0xFFE11D48)),
                                const SizedBox(width: 3.5),
                                Text(
                                  productsText,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFE11D48),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFFFEF3C7)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 10, color: Color(0xFFD97706)),
                                const SizedBox(width: 3.5),
                                Text(
                                  expiryText,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
  }

  // ===========================================================================
  // COLLAPSIBLE ACCORDION SECTION WRAPPER
  // ===========================================================================
  Widget _buildAccordionSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 5,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accordion Header Bar
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: const Color(0xFF021B54)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: const Color(0xFF0F172A),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Content
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: content,
            ),
          ],
        ],
      ),
    );
  }

  // Inset Form Field (Exact Match to User Image)
  Widget _buildInsetField({
    required String label,
    required IconData prefixIcon,
    required Widget inputChild,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(prefixIcon, size: 15, color: const Color(0xFF021B54)),
              const SizedBox(width: 7),
              Expanded(child: inputChild),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: BASIC INFORMATION
  // ===========================================================================
  Widget _buildBasicInfoSection() {
    return _buildAccordionSection(
      title: 'Basic Information',
      icon: Icons.info_rounded,
      isExpanded: _isBasicInfoExpanded,
      onToggle: () => setState(() => _isBasicInfoExpanded = !_isBasicInfoExpanded),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInsetField(
                  label: 'Coupon Code *',
                  prefixIcon: Icons.tag_rounded,
                  inputChild: TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'WELCOME50',
                      hintStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Code required';
                      if (v.trim().length < 2) return 'Min 2 chars';
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInsetField(
                  label: 'Offer Title *',
                  prefixIcon: Icons.local_offer_outlined,
                  inputChild: TextFormField(
                    controller: _titleController,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Special Offer',
                      hintStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInsetField(
            label: 'Description / Tagline',
            prefixIcon: Icons.description_outlined,
            inputChild: TextFormField(
              controller: _descriptionController,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Get ₹50 OFF on all products',
                hintStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 2: DISCOUNT SETTINGS
  // ===========================================================================
  Widget _buildDiscountSettingsSection() {
    return _buildAccordionSection(
      title: 'Discount Settings',
      icon: Icons.percent_rounded,
      isExpanded: _isDiscountSettingsExpanded,
      onToggle: () => setState(() => _isDiscountSettingsExpanded = !_isDiscountSettingsExpanded),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Toggle: Percentage vs Flat Amount
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _discountType = 'percentage'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _discountType == 'percentage' ? const Color(0xFF021B54) : const Color(0xFFF1F6FB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _discountType == 'percentage' ? const Color(0xFF021B54) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Percentage (%)',
                      style: TextStyle(
                        color: _discountType == 'percentage' ? Colors.white : const Color(0xFF334155),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _discountType = 'flat'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _discountType == 'flat' ? const Color(0xFF021B54) : const Color(0xFFF1F6FB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _discountType == 'flat' ? const Color(0xFF021B54) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Flat Amount (₹)',
                      style: TextStyle(
                        color: _discountType == 'flat' ? Colors.white : const Color(0xFF334155),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Discount Value Field
          _buildInsetField(
            label: _discountType == 'percentage' ? 'Discount Percentage (%) *' : 'Discount Amount (₹) *',
            prefixIcon: _discountType == 'percentage' ? Icons.percent_rounded : Icons.currency_rupee_rounded,
            inputChild: TextFormField(
              controller: _discountValueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: _discountType == 'percentage' ? 'e.g. 20' : 'e.g. 50',
                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Min Cart & Max Discount Row
          Row(
            children: [
              Expanded(
                child: _buildInsetField(
                  label: 'Minimum Cart Value (₹)',
                  prefixIcon: Icons.shopping_cart_outlined,
                  inputChild: TextFormField(
                    controller: _minCartAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: '0',
                      hintStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInsetField(
                  label: 'Max Discount (₹)',
                  prefixIcon: Icons.layers_outlined,
                  inputChild: TextFormField(
                    controller: _maxDiscountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'No limit',
                      hintStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 3: VALIDITY PERIOD
  // ===========================================================================
  Widget _buildValidityPeriodSection() {
    return _buildAccordionSection(
      title: 'Validity Period',
      icon: Icons.calendar_today_rounded,
      isExpanded: _isValidityPeriodExpanded,
      onToggle: () => setState(() => _isValidityPeriodExpanded = !_isValidityPeriodExpanded),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickStartDate,
                  borderRadius: BorderRadius.circular(12),
                  child: _buildInsetField(
                    label: 'Start Date',
                    prefixIcon: Icons.calendar_today_outlined,
                    inputChild: Text(
                      DateFormat('dd MMM yyyy').format(_startDate),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: _pickEndDate,
                  borderRadius: BorderRadius.circular(12),
                  child: _buildInsetField(
                    label: 'Expiry Date',
                    prefixIcon: Icons.calendar_today_outlined,
                    inputChild: Text(
                      _endDate != null ? DateFormat('dd MMM yyyy').format(_endDate!) : 'No Expiry',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _pickTimeSlot(true),
                  borderRadius: BorderRadius.circular(12),
                  child: _buildInsetField(
                    label: 'Start Time (Optional)',
                    prefixIcon: Icons.access_time_rounded,
                    inputChild: Text(
                      _timeSlotStart != null ? _timeSlotStart!.format(context) : 'All Day',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _pickTimeSlot(false),
                  borderRadius: BorderRadius.circular(12),
                  child: _buildInsetField(
                    label: 'End Time (Optional)',
                    prefixIcon: Icons.access_time_rounded,
                    inputChild: Text(
                      _timeSlotEnd != null ? _timeSlotEnd!.format(context) : 'All Day',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 4: PRODUCT ELIGIBILITY
  // ===========================================================================
  Widget _buildProductEligibilitySection() {
    final filteredItems = _filteredMenuItems;
    final allCategories = ['All', ..._db.categories];

    return _buildAccordionSection(
      title: 'Product Eligibility',
      icon: Icons.restaurant_menu_rounded,
      isExpanded: _isProductEligibilityExpanded,
      onToggle: () => setState(() => _isProductEligibilityExpanded = !_isProductEligibilityExpanded),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _productApplicationMode = 'all'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _productApplicationMode == 'all' ? const Color(0xFF021B54) : const Color(0xFFF1F6FB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _productApplicationMode == 'all' ? const Color(0xFF021B54) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'All Products',
                      style: TextStyle(
                        color: _productApplicationMode == 'all' ? Colors.white : const Color(0xFF334155),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _productApplicationMode = 'specific'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _productApplicationMode == 'specific' ? const Color(0xFF021B54) : const Color(0xFFF1F6FB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _productApplicationMode == 'specific' ? const Color(0xFF021B54) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Specific Products (${_selectedProductIds.length})',
                      style: TextStyle(
                        color: _productApplicationMode == 'specific' ? Colors.white : const Color(0xFF334155),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_productApplicationMode == 'specific') ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedProductIds.length} item(s) selected',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0052FF)),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          for (final item in filteredItems) {
                            _selectedProductIds.add(item.id);
                          }
                        });
                      },
                      child: const Text('Select All', style: TextStyle(fontSize: 10.5, color: Color(0xFF021B54), fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => setState(() => _selectedProductIds.clear()),
                      child: const Text('Clear', style: TextStyle(fontSize: 10.5, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 34,
              child: TextField(
                controller: _productSearchController,
                onChanged: (val) => setState(() => _productSearchQuery = val.trim()),
                style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Search product by name...',
                  hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 14, color: Color(0xFF475569)),
                  filled: true,
                  fillColor: const Color(0xFFF1F6FB),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (allCategories.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: allCategories.map((cat) {
                    final isSel = _productCategoryFilter == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: InkWell(
                        onTap: () => setState(() => _productCategoryFilter = cat),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSel ? const Color(0xFF021B54) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                              color: isSel ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 6),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: filteredItems.isEmpty
                  ? const Center(child: Text('No products found', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))))
                  : ListView.builder(
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = _selectedProductIds.contains(item.id);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedProductIds.remove(item.id);
                              } else {
                                _selectedProductIds.add(item.id);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                              color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                FoodTypeIcon(itemType: item.itemType, size: 12),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(item.category, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF021B54))),
                                const SizedBox(width: 8),
                                Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 16,
                                  color: isSelected ? const Color(0xFF0052FF) : const Color(0xFFCBD5E1),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 5: USAGE LIMITS & ORDER RULES
  // ===========================================================================
  Widget _buildUsageLimitsSection() {
    return _buildAccordionSection(
      title: 'Usage Limits & Rules',
      icon: Icons.tune_rounded,
      isExpanded: _isUsageLimitsExpanded,
      onToggle: () => setState(() => _isUsageLimitsExpanded = !_isUsageLimitsExpanded),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInsetField(
                  label: 'Limit Per Customer',
                  prefixIcon: Icons.person_outline_rounded,
                  inputChild: TextFormField(
                    controller: _usagePerCustomerController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildInsetField(
                  label: 'Total Usage Limit (0 = ∞)',
                  prefixIcon: Icons.all_inclusive_rounded,
                  inputChild: TextFormField(
                    controller: _totalUsageLimitController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Applicable Order Types', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              {'key': 'dineIn', 'label': 'Dine-In', 'icon': Icons.table_restaurant_rounded},
              {'key': 'takeaway', 'label': 'Takeaway', 'icon': Icons.shopping_bag_outlined},
              {'key': 'delivery', 'label': 'Delivery', 'icon': Icons.delivery_dining_rounded},
            ].map((t) {
              final key = t['key'] as String;
              final isSelected = _selectedOrderTypes.contains(key);
              return FilterChip(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                label: Text(t['label'] as String),
                selected: isSelected,
                selectedColor: const Color(0xFF021B54),
                labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF334155), fontSize: 10, fontWeight: FontWeight.bold),
                onSelected: (sel) {
                  setState(() {
                    if (sel) {
                      _selectedOrderTypes.add(key);
                    } else if (_selectedOrderTypes.length > 1) {
                      _selectedOrderTypes.remove(key);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          const Text('Valid Days of Week', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: List.generate(7, (index) {
              final isSelected = _selectedDays.contains(index);
              return FilterChip(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                label: Text(_weekDays[index]),
                selected: isSelected,
                selectedColor: const Color(0xFF021B54),
                labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF334155), fontSize: 10, fontWeight: FontWeight.bold),
                onSelected: (sel) {
                  setState(() {
                    if (sel) {
                      _selectedDays.add(index);
                    } else if (_selectedDays.length > 1) {
                      _selectedDays.remove(index);
                    }
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SECTION 6: TERMS & CONDITIONS
  // ===========================================================================
  Widget _buildTermsSection() {
    return _buildAccordionSection(
      title: 'Terms & Conditions',
      icon: Icons.rule_rounded,
      isExpanded: _isTermsExpanded,
      onToggle: () => setState(() => _isTermsExpanded = !_isTermsExpanded),
      content: _buildInsetField(
        label: 'Terms (1 per line)',
        prefixIcon: Icons.format_list_bulleted_rounded,
        inputChild: TextFormField(
          controller: _termsController,
          maxLines: 2,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: 'e.g. Cannot be combined with other offers',
            hintStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TOP HEADER BAR (Pixel-Matched to User Image)
  // ===========================================================================
  Widget _buildTopHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            // Left squircle discount tag badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.existingCoupon != null ? 'Edit Coupon' : 'Create New Coupon',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    'Configure discount rules, products and order limits',
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            // Right circular close button
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // BOTTOM STICKY ACTION BAR (Pixel-Matched to User Image)
  // ===========================================================================
  Widget _buildBottomStickyBar() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottomPadding > 0 ? bottomPadding + 6 : 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel Button
          Expanded(
            child: SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  backgroundColor: const Color(0xFFF8FAFD),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Create / Update Button
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0052FF), Color(0xFF0038E0)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0052FF).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveCoupon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            widget.existingCoupon != null ? 'Update Coupon' : 'Create Coupon',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF021B54),
      body: Column(
        children: [
          // 1. Top Header Bar (Deep Midnight Navy with Squircle tag and Close X)
          _buildTopHeader(),

          // 2. Curved Neumorphic Sheet Container
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F4F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x30001C55),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live Ticket Voucher Preview
                        _buildLivePreviewCard(),

                        // Section 1: Basic Information
                        _buildBasicInfoSection(),

                        // Section 2: Discount Settings
                        _buildDiscountSettingsSection(),

                        // Section 3: Validity Period
                        _buildValidityPeriodSection(),

                        // Section 4: Product Eligibility
                        _buildProductEligibilitySection(),

                        // Section 5: Usage Limits & Rules
                        _buildUsageLimitsSection(),

                        // Section 6: Terms & Conditions
                        _buildTermsSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Bottom Sticky Action Bar
          _buildBottomStickyBar(),
        ],
      ),
    );
  }
}
