import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/database/database_service.dart';
import '../dashboard/main_layout.dart';
import '../../core/services/onboarding_service.dart';

class BusinessSettingsScreen extends StatefulWidget {
  final bool isFromOnboarding;

  const BusinessSettingsScreen({
    super.key,
    this.isFromOnboarding = true,
  });

  @override
  State<BusinessSettingsScreen> createState() => _BusinessSettingsScreenState();
}

class _BusinessSettingsScreenState extends State<BusinessSettingsScreen> {
  final db = DatabaseService();

  // 1. Select Your Services (Multi Select) - Dine In selected by default
  Set<String> _selectedServices = {'Dine In'};

  // 2. Billing Type & GST Number & GST Percentage
  String _billingType = 'GST'; // 'GST' or 'Non-GST'
  late TextEditingController _gstNumberController;
  double _gstPercentage = 5.0;
  bool _isCustomGstSelected = false;

  // 3. Restaurant Type
  String _restaurantType = 'Both'; // 'Veg', 'Non-Veg', 'Both'

  // 4. Number of Tables (If Dine-In selected)
  late TextEditingController _tableCountController;
  int _tableCount = 12;

  // 5. Merchant UPI ID Controller (NOT prefilled)
  late TextEditingController _upiIdController;

  final List<double> _standardGstOptions = [0.0, 5.0, 12.0, 18.0, 28.0];

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    db.saveOnboardingProgress(route: 'business_settings', step: 7);
    final rest = db.restaurant;

    if (rest != null) {
      if (rest.services.isNotEmpty) {
        _selectedServices = Set<String>.from(rest.services);
      }
      _billingType = rest.billingType.isNotEmpty ? rest.billingType : 'GST';
      _gstNumberController = TextEditingController(text: rest.gstNumber);
      _gstPercentage = rest.taxRate > 0 ? rest.taxRate : 5.0;
      if (!_standardGstOptions.contains(_gstPercentage)) {
        _isCustomGstSelected = true;
      }
      _restaurantType = rest.restaurantType.isNotEmpty ? rest.restaurantType : 'Both';
      _tableCount = rest.tableCount > 0 ? rest.tableCount : 12;
      _upiIdController = TextEditingController(
        text: (rest.upiId.isNotEmpty && !rest.upiId.toLowerCase().contains('apnapos')) ? rest.upiId : '',
      );
    } else {
      _gstNumberController = TextEditingController();
      _upiIdController = TextEditingController();
    }

    _tableCountController = TextEditingController(text: '$_tableCount');
  }

  @override
  void dispose() {
    _gstNumberController.dispose();
    _tableCountController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  /// Neumorphic dialog for entering a custom GST %
  void _showCustomGstDialog() {
    final controller = TextEditingController(
      text: _isCustomGstSelected ? '$_gstPercentage' : '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFFDEE7F6),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x35001C55),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF5FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFDEE9F7), width: 1),
                      ),
                      child: const Icon(
                        Icons.percent_rounded,
                        color: Color(0xFF0066FF),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'Enter Custom GST %',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5EDF6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14002870),
                        blurRadius: 4,
                        offset: Offset(1, 2),
                      ),
                      BoxShadow(
                        color: Colors.white,
                        blurRadius: 3,
                        offset: Offset(-1, -1),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'e.g. 18.0',
                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      suffixText: '% GST',
                      suffixStyle: TextStyle(
                        color: Color(0xFF0066FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0066FF), Color(0xFF0052CC)],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x250066FF),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          final val = double.tryParse(controller.text.trim());
                          if (val != null && val >= 0) {
                            setState(() {
                              _gstPercentage = val;
                              _isCustomGstSelected = true;
                            });
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSaveSettings() async {
    if (_selectedServices.isEmpty) {
      setState(() => _errorMessage = 'Please select at least one service channel.');
      return;
    }

    if (_billingType == 'GST' && _gstNumberController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your GSTIN number or switch to Non-GST.');
      return;
    }

    if (_selectedServices.contains('Dine In') && (_tableCount <= 0)) {
      setState(() => _errorMessage = 'Please specify at least 1 table for Dine-In.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String restType = _restaurantType.toLowerCase() == 'veg'
          ? 'pure_veg'
          : (_restaurantType.toLowerCase() == 'non-veg' ? 'non_veg' : 'both');

      final upiText = _upiIdController.text.trim();

      await OnboardingService().saveOrderSettings(
        services: {
          'dineIn': _selectedServices.contains('Dine In'),
          'takeaway': _selectedServices.contains('Takeaway'),
          'delivery': _selectedServices.contains('Delivery'),
        },
        taxType: _billingType == 'GST' ? 'gst' : 'no_gst',
        gstNumber: _billingType == 'GST' ? _gstNumberController.text.trim().toUpperCase() : '',
        taxPercentage: _billingType == 'GST' ? _gstPercentage : null,
        restaurantType: restType,
        paymentMethods: {
          'cash': true,
          'upi': upiText.isNotEmpty,
          'card': false,
        },
        upiId: upiText,
        tableCount: _selectedServices.contains('Dine In') ? _tableCount : 0,
      );

      final effectiveCount = _selectedServices.contains('Dine In') ? _tableCount : 0;
      await DatabaseService().syncTableCount(effectiveCount);

      if (widget.isFromOnboarding) {
        // Trigger backend onboarding verification
        final completeData = await OnboardingService().completeOnboarding();
        await db.saveOnboardingProgress(route: 'completed', step: 8);

        final activeBizId = completeData['businessId']?.toString() ??
            (completeData['business'] is Map ? completeData['business']['_id']?.toString() : null) ??
            db.currentBusinessId;

        if (!mounted) return;
        setState(() => _isLoading = false);

        await _showOnboardingSuccessDialog(activeBizId);
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF15803D),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order settings updated successfully!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showOnboardingSuccessDialog(String businessId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3D021B54),
                  blurRadius: 36,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Celebration Badge Icon
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header Title
                  const Text(
                    '🎉 Business Setup Complete!',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Your restaurant terminal is configured and production-ready.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // BUSINESS ID KEY HERO CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF021B54), Color(0xFF0B2B6B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF021B54).withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.key_rounded,
                                color: Color(0xFF38BDF8),
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'YOUR BUSINESS ID KEY',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 3,
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // The Key Value Row + Copy Button
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF010E2E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  businessId,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: Color(0xFF38BDF8),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: businessId));
                                  HapticFeedback.lightImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: const Color(0xFF0F172A),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Business ID copied: $businessId',
                                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.copy_rounded, color: Color(0xFF38BDF8), size: 13),
                                      SizedBox(width: 4),
                                      Text(
                                        'Copy',
                                        style: TextStyle(
                                          color: Color(0xFF38BDF8),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.white.withValues(alpha: 0.5), size: 12),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Use this key to connect Waiter tablets, Kitchen Display (KDS), and additional billing terminals.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 10.5,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Outlet Configuration Summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OUTLET SUMMARY',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          icon: Icons.storefront_rounded,
                          label: 'Outlet Name',
                          value: db.restaurant?.name.isNotEmpty == true ? db.restaurant!.name : 'Apna POS Outlet',
                        ),
                        const SizedBox(height: 5),
                        _buildSummaryRow(
                          icon: Icons.table_restaurant_rounded,
                          label: 'Dining Tables',
                          value: _selectedServices.contains('Dine In') ? '$_tableCount Tables configured' : 'Dine-In Disabled',
                        ),
                        const SizedBox(height: 5),
                        _buildSummaryRow(
                          icon: Icons.receipt_long_rounded,
                          label: 'Tax / GST',
                          value: _billingType == 'GST' ? 'GST $_gstPercentage%' : 'Non-GST Mode',
                        ),
                        if (_upiIdController.text.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          _buildSummaryRow(
                            icon: Icons.qr_code_2_rounded,
                            label: 'UPI Merchant ID',
                            value: _upiIdController.text.trim(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Launch Apna POS Terminal Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const MainLayout()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF021B54),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0xFF021B54).withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Launch Apna POS Terminal',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
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

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 13, color: const Color(0xFF021B54)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dynamicCompanyName = db.restaurant?.name ??
        db.currentUser?.companyName ??
        'Delhi Chai Cafe';

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF021B54),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // 1. Top Header on Midnight Navy (No Icon on Badge)
              _buildTopHeader(dynamicCompanyName),

              // 2. Curved Soft Neumorphic Body Sheet with Sticky Save Button (Wider Big Boxes)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x30001C55),
                        blurRadius: 18,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    child: Column(
                      children: [
                        // Scrollable Content (Glitch-Free with Keyboard Inset Padding)
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              14,
                              16,
                              14,
                              16 + MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Error Banner
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x10EF4444),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              color: Color(0xFFB91C1C),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close_rounded, color: Color(0xFFB91C1C), size: 15),
                                          onPressed: () => setState(() => _errorMessage = null),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // SECTION 1: Select Your Services (Multi-Select)
                                _buildServicesSection(),

                                const SizedBox(height: 12),

                                // SECTION 2: Billing Type & GST (with Horizontal Slider)
                                _buildBillingGstSection(),

                                const SizedBox(height: 12),

                                // SECTION 3: Restaurant Type (Dietary)
                                _buildRestaurantTypeSection(),

                                const SizedBox(height: 12),

                                // SECTION 4: Payment Methods (UPI ID)
                                _buildPaymentMethodsSection(),

                                // SECTION 5: Tables Configuration (If Dine-In)
                                if (_selectedServices.contains('Dine In')) ...[
                                  const SizedBox(height: 12),
                                  _buildTablesSection(),
                                ],

                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),

                        // Sticky Bottom Action Button with dedicated space above it
                        _buildStickyBottomBar(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Top Header with Circular Back Button and Company Name Badge (No Icon)
  Widget _buildTopHeader(String companyName) {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              // Circular Neumorphic Back Button
              InkWell(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MainLayout()),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0).withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFF0F172A),
                      size: 24,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Neumorphic Frosted Company Name Badge (No Icon)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    companyName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SECTION 1: Select Your Services (Multi-Select)
  Widget _buildServicesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12002870),
            blurRadius: 12,
            offset: Offset(4, 5),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF021B54),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x25021B54),
                      blurRadius: 6,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.room_service_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Select Your Services',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Padding(
            padding: EdgeInsets.only(left: 37),
            child: Text(
              'Choose order channels available in your restaurant',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildNeumorphicServiceCard(
                  title: 'Dine In',
                  icon: Icons.restaurant_rounded,
                  isSelected: _selectedServices.contains('Dine In'),
                  onTap: () {
                    setState(() {
                      if (_selectedServices.contains('Dine In')) {
                        if (_selectedServices.length > 1) {
                          _selectedServices.remove('Dine In');
                        }
                      } else {
                        _selectedServices.add('Dine In');
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNeumorphicServiceCard(
                  title: 'Takeaway',
                  icon: Icons.takeout_dining_rounded,
                  isSelected: _selectedServices.contains('Takeaway'),
                  onTap: () {
                    setState(() {
                      if (_selectedServices.contains('Takeaway')) {
                        if (_selectedServices.length > 1) {
                          _selectedServices.remove('Takeaway');
                        }
                      } else {
                        _selectedServices.add('Takeaway');
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNeumorphicServiceCard(
                  title: 'Delivery',
                  icon: Icons.two_wheeler_rounded,
                  isSelected: _selectedServices.contains('Delivery'),
                  onTap: () {
                    setState(() {
                      if (_selectedServices.contains('Delivery')) {
                        if (_selectedServices.length > 1) {
                          _selectedServices.remove('Delivery');
                        }
                      } else {
                        _selectedServices.add('Delivery');
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Individual Service Channel Pill Card (Compact Tactile Neumorphic)
  Widget _buildNeumorphicServiceCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF0066FF), Color(0xFF0052CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : const Color(0xFFEFF4FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF70A9FF) : Colors.white,
            width: isSelected ? 1.5 : 1.2,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x400066FF),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x12002870),
                    blurRadius: 5,
                    offset: Offset(2, 3),
                  ),
                  BoxShadow(
                    color: Colors.white,
                    blurRadius: 4,
                    offset: Offset(-2, -2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF334155),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SECTION 2: Billing Type & GST Section (with Horizontal Slider)
  Widget _buildBillingGstSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12002870),
            blurRadius: 12,
            offset: Offset(4, 5),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF021B54),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x25021B54),
                      blurRadius: 6,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Billing Type & GST',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Padding(
            padding: EdgeInsets.only(left: 37),
            child: Text(
              'Select billing type and configure GST settings',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // GST vs Non-GST Recessed Toggle
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E9F3),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10002870),
                  blurRadius: 4,
                  offset: Offset(1, 2),
                ),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 3,
                  offset: Offset(-1, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _billingType = 'GST'),
                    borderRadius: BorderRadius.circular(11),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        gradient: _billingType == 'GST'
                            ? const LinearGradient(
                                colors: [Color(0xFF0066FF), Color(0xFF004EC4)],
                              )
                            : null,
                        color: _billingType == 'GST' ? null : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: _billingType == 'GST'
                            ? const [
                                BoxShadow(
                                  color: Color(0x350066FF),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: _billingType == 'GST' ? Colors.white : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'GST Billing',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _billingType == 'GST' ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _billingType = 'Non-GST'),
                    borderRadius: BorderRadius.circular(11),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        gradient: _billingType == 'Non-GST'
                            ? const LinearGradient(
                                colors: [Color(0xFF021B54), Color(0xFF002B7A)],
                              )
                            : null,
                        color: _billingType == 'Non-GST' ? null : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: _billingType == 'Non-GST'
                            ? const [
                                BoxShadow(
                                  color: Color(0x35021B54),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 15,
                            color: _billingType == 'Non-GST' ? Colors.white : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Non-GST Billing',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _billingType == 'Non-GST' ? Colors.white : const Color(0xFF475569),
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

          // If GST Billing is active
          if (_billingType == 'GST') ...[
            const SizedBox(height: 12),
            const Text(
              'GSTIN Number *',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE5EDF6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14002870),
                    blurRadius: 4,
                    offset: Offset(1, 2),
                  ),
                  BoxShadow(
                    color: Colors.white,
                    blurRadius: 3,
                    offset: Offset(-1, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10002870),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF0066FF),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _gstNumberController,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.6,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g. 07AAAAA0000A1Z5',
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              'GST Tax Percentage *',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 7),

            // Horizontal Slider for GST Tax Percentage Options (Glitch-Free & No Overflows)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  ..._standardGstOptions.map((rate) {
                    final isSelected = !_isCustomGstSelected && _gstPercentage == rate;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isCustomGstSelected = false;
                            _gstPercentage = rate;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                                  )
                                : null,
                            color: isSelected ? null : const Color(0xFFEFF4FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF6EE7B7) : Colors.white,
                              width: 1.2,
                            ),
                            boxShadow: isSelected
                                ? const [
                                    BoxShadow(
                                      color: Color(0x3510B981),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ]
                                : const [
                                    BoxShadow(
                                      color: Color(0x10002870),
                                      blurRadius: 4,
                                      offset: Offset(2, 2),
                                    ),
                                    BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 3,
                                      offset: Offset(-1, -1),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                '${rate.toInt()}% GST',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  // Custom GST Option Button
                  InkWell(
                    onTap: _showCustomGstDialog,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                      decoration: BoxDecoration(
                        gradient: _isCustomGstSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              )
                            : null,
                        color: _isCustomGstSelected ? null : const Color(0xFFEFF4FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isCustomGstSelected ? const Color(0xFF6EE7B7) : Colors.white,
                          width: 1.2,
                        ),
                        boxShadow: _isCustomGstSelected
                            ? const [
                                BoxShadow(
                                  color: Color(0x3510B981),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ]
                            : const [
                                BoxShadow(
                                  color: Color(0x10002870),
                                  blurRadius: 4,
                                  offset: Offset(2, 2),
                                ),
                                BoxShadow(
                                  color: Colors.white,
                                  blurRadius: 3,
                                  offset: Offset(-1, -1),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isCustomGstSelected) ...[
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            _isCustomGstSelected ? '$_gstPercentage%' : 'Custom %',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: _isCustomGstSelected ? FontWeight.w900 : FontWeight.w700,
                              color: _isCustomGstSelected ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // SECTION 3: Dietary & Restaurant Type
  Widget _buildRestaurantTypeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12002870),
            blurRadius: 12,
            offset: Offset(4, 5),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF021B54),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x25021B54),
                      blurRadius: 6,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Restaurant Type',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildNeumorphicTypeOption(
                  title: 'Pure Veg',
                  emoji: '🌱',
                  color: const Color(0xFF10B981),
                  isSelected: _restaurantType == 'Veg',
                  onTap: () => setState(() => _restaurantType = 'Veg'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNeumorphicTypeOption(
                  title: 'Non-Veg',
                  emoji: '🍗',
                  color: const Color(0xFFEF4444),
                  isSelected: _restaurantType == 'Non-Veg',
                  onTap: () => setState(() => _restaurantType = 'Non-Veg'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNeumorphicTypeOption(
                  title: 'Both',
                  emoji: '🥗',
                  color: const Color(0xFF0066FF),
                  isSelected: _restaurantType == 'Both',
                  onTap: () => setState(() => _restaurantType = 'Both'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Dietary option card (Tactile Neumorphic)
  Widget _buildNeumorphicTypeOption({
    required String title,
    required String emoji,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.14) : const Color(0xFFEFF4FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.white,
            width: isSelected ? 1.6 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x10002870),
                    blurRadius: 4,
                    offset: Offset(2, 2),
                  ),
                  BoxShadow(
                    color: Colors.white,
                    blurRadius: 3,
                    offset: Offset(-1, -1),
                  ),
                ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 17)),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected ? color : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SECTION 4: Payment Methods (UPI ID)
  Widget _buildPaymentMethodsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12002870),
            blurRadius: 12,
            offset: Offset(4, 5),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF021B54),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x25021B54),
                      blurRadius: 6,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.payment_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Payment Methods',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Padding(
            padding: EdgeInsets.only(left: 37),
            child: Text(
              'Add your Merchant UPI VPA ID to receive customer payments',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Inset UPI ID Input Field (NOT prefilled)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE5EDF6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14002870),
                  blurRadius: 4,
                  offset: Offset(1, 2),
                ),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 3,
                  offset: Offset(-1, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x10002870),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF0066FF),
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _upiIdController,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      hintText: 'e.g. merchant@upi, 9876543210@paytm',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // SECTION 5: Tables Configuration (If Dine-In)
  Widget _buildTablesSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12002870),
            blurRadius: 12,
            offset: Offset(4, 5),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFF021B54),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x25021B54),
                      blurRadius: 6,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.table_restaurant_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Number of Tables',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EDF6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14002870),
                      blurRadius: 4,
                      offset: Offset(1, 2),
                    ),
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 3,
                      offset: Offset(-1, -1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Embossed Minus Button
                    InkWell(
                      onTap: () {
                        if (_tableCount > 1) {
                          setState(() {
                            _tableCount--;
                            _tableCountController.text = '$_tableCount';
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F6FB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12002870),
                              blurRadius: 3,
                              offset: Offset(1, 2),
                            ),
                            BoxShadow(
                              color: Colors.white,
                              blurRadius: 2,
                              offset: Offset(-1, -1),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.remove_rounded, color: Color(0xFF0066FF), size: 16),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: TextField(
                        controller: _tableCountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) {
                          final num = int.tryParse(val);
                          if (num != null && num > 0) {
                            setState(() => _tableCount = num);
                          }
                        },
                      ),
                    ),
                    // Embossed Plus Button
                    InkWell(
                      onTap: () {
                        setState(() {
                          _tableCount++;
                          _tableCountController.text = '$_tableCount';
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F6FB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x12002870),
                              blurRadius: 3,
                              offset: Offset(1, 2),
                            ),
                            BoxShadow(
                              color: Colors.white,
                              blurRadius: 2,
                              offset: Offset(-1, -1),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add_rounded, color: Color(0xFF0066FF), size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$_tableCount Dining Tables',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Sticky Bottom Action Bar with Midnight Navy "Save & Launch POS" Button (No Background Box)
  Widget _buildStickyBottomBar() {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF021B54),
                Color(0xFF002B7A),
                Color(0xFF003D9E),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x35021B54),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 4,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSaveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isFromOnboarding ? Icons.rocket_launch_rounded : Icons.save_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isFromOnboarding ? 'Save & Launch POS' : 'Save Settings',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
