import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import '../../core/models/restaurant_model.dart';
import '../../core/widgets/glass_company_name_badge.dart';
import '../dashboard/main_layout.dart';

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

  // 5. Merchant UPI ID Controller
  late TextEditingController _upiIdController;

  final List<double> _standardGstOptions = [5.0, 12.0, 18.0, 28.0];

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
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
      _upiIdController = TextEditingController(text: rest.upiId.isNotEmpty ? rest.upiId : 'apnapos@upi');
    } else {
      _gstNumberController = TextEditingController();
      _upiIdController = TextEditingController(text: 'apnapos@upi');
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

  /// Popup dialog with background blur effect for entering a custom GST %
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.88),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 30,
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C2FF).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.percent_rounded,
                            color: Color(0xFF00C2FF),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Enter Custom GST %',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. 18.0',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                        suffixText: '% GST',
                        suffixStyle: const TextStyle(
                          color: Color(0xFF00C2FF),
                          fontWeight: FontWeight.bold,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF00C2FF), width: 1.8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
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
                            backgroundColor: const Color(0xFF00C2FF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          ),
                          child: const Text(
                            'Apply',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
      final businessName = db.restaurant?.name ?? db.currentUser?.companyName ?? 'Tea Coffee';

      final updated = RestaurantModel(
        id: db.restaurant?.id ?? 'rest_001',
        name: businessName,
        tagline: db.restaurant?.tagline ?? 'Authentic Flavors & Swift Service',
        phone: db.restaurant?.phone ?? db.currentUser?.phone ?? '+91 98765 43210',
        address: db.restaurant?.address ?? 'Connaught Place, New Delhi',
        cuisineType: db.restaurant?.cuisineType ?? 'Multi-Cuisine POS',
        currencySymbol: db.restaurant?.currencySymbol ?? '₹',
        taxRate: _billingType == 'GST' ? _gstPercentage : 0.0,
        serviceCharge: db.restaurant?.serviceCharge ?? 0.0,
        tableCount: _selectedServices.contains('Dine In') ? _tableCount : 0,
        isOnboarded: true,
        services: _selectedServices.toList(),
        billingType: _billingType,
        gstNumber: _billingType == 'GST' ? _gstNumberController.text.trim().toUpperCase() : '',
        restaurantType: _restaurantType,
        upiId: _upiIdController.text.trim().isEmpty ? 'apnapos@upi' : _upiIdController.text.trim(),
      );

      // Save complete setup to database
      await db.saveRestaurantOnboarding(updated);

      if (!mounted) return;

      if (widget.isFromOnboarding) {
        // Onboarding Flow: Toast feedback & Launch Main POS Dashboard
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF00C2FF), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Business settings saved! Launching POS...',
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

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainLayout()),
          (route) => false,
        );
      } else {
        // Business Setting Hub Flow: Toast feedback & Navigate back to Hub
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
      setState(() => _errorMessage = 'Error saving settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Deep Midnight Background Gradient with Glass Ambient Glows
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.4),
                  radius: 1.25,
                  colors: [
                    Color(0x550052FF),
                    Color(0xFF071126),
                    Color(0xFF03060F),
                  ],
                  stops: [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // 2. Glassmorphism Ambient Glow Orbs
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00C2FF).withOpacity(0.18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C2FF).withOpacity(0.18),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // 3. Main Screen Layout (Responsive & Compact)
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Back Button & Highlighted Glass Company Name Badge
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
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
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: GlassCompanyNameBadge(
                            name: db.restaurant?.name ?? db.currentUser?.companyName ?? 'Tea Coffee',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Curved White Container Layout
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 24,
                          offset: Offset(0, -8),
                        ),
                      ],
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     // Error Banner
                                     if (_errorMessage != null) ...[
                                   Container(
                                     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                     decoration: BoxDecoration(
                                       color: const Color(0xFFFEE2E2),
                                       borderRadius: BorderRadius.circular(12),
                                       border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                                       boxShadow: const [BoxShadow(color: Color(0x1AEF4444), blurRadius: 6, offset: Offset(0, 2))],
                                     ),
                                     child: Row(
                                       children: [
                                         const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                         const SizedBox(width: 10),
                                         Expanded(
                                           child: Text(
                                             _errorMessage!,
                                             style: const TextStyle(
                                               color: Color(0xFF991B1B),
                                               fontSize: 13,
                                               fontWeight: FontWeight.w800,
                                             ),
                                           ),
                                         ),
                                         IconButton(
                                           icon: const Icon(Icons.close_rounded, color: Color(0xFF991B1B), size: 18),
                                           onPressed: () => setState(() => _errorMessage = null),
                                           constraints: const BoxConstraints(),
                                           padding: EdgeInsets.zero,
                                         ),
                                       ],
                                     ),
                                   ),
                                   const SizedBox(height: 14),
                                 ],

                                 // Screen Header Title
                                 Row(
                                   children: [
                                     Container(
                                       padding: const EdgeInsets.all(8),
                                       decoration: BoxDecoration(
                                         color: const Color(0xFF00C2FF).withOpacity(0.15),
                                         shape: BoxShape.circle,
                                       ),
                                       child: const Icon(Icons.shopping_cart_checkout_rounded, color: Color(0xFF00C2FF), size: 22),
                                     ),
                                     const SizedBox(width: 10),
                                     const Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Text(
                                           'Order Setting',
                                           style: TextStyle(
                                             fontSize: 20,
                                             fontWeight: FontWeight.w900,
                                             color: Color(0xFF0F172A),
                                             letterSpacing: -0.3,
                                           ),
                                         ),
                                        //  Text(
                                        //    'Configure services, GST rules, billing type & dining tables',
                                        //    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        //  ),
                                       ],
                                     ),
                                   ],
                                 ),
                                 const SizedBox(height: 16),
                                 const Divider(color: Color(0xFFE2E8F0)),
                                 const SizedBox(height: 14),

                                  // SECTION 1: Select Your Services (Multi Select)
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: const [
                                        BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(color: Color(0xFF051C48), shape: BoxShape.circle),
                                              child: const Icon(Icons.room_service_rounded, color: Colors.white, size: 16),
                                            ),
                                            const SizedBox(width: 8),
                                            const Expanded(
                                              child: Text(
                                                'Select Your Services',
                                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Choose order channels available in your restaurant',
                                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildServiceChip(
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
                                              child: _buildServiceChip(
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
                                              child: _buildServiceChip(
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
                                  ),

                                  const SizedBox(height: 14),

                                  // SECTION 2: Billing Type & GST Setup
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: const [
                                        BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(color: Color(0xFF051C48), shape: BoxShape.circle),
                                              child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 16),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Billing Type & GST',
                                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () => setState(() => _billingType = 'GST'),
                                                  borderRadius: BorderRadius.circular(11),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: _billingType == 'GST' ? const Color(0xFF00C2FF) : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(11),
                                                      boxShadow: _billingType == 'GST'
                                                          ? [
                                                              BoxShadow(
                                                                color: const Color(0xFF00C2FF).withOpacity(0.3),
                                                                blurRadius: 6,
                                                                offset: const Offset(0, 2),
                                                              )
                                                            ]
                                                          : [],
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          _billingType == 'GST' ? Icons.check_circle_rounded : Icons.receipt_long_rounded,
                                                          size: 16,
                                                          color: _billingType == 'GST' ? Colors.white : const Color(0xFF64748B),
                                                        ),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          _billingType == 'GST' ? 'GST Billing ✅' : 'GST Billing',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w700,
                                                            color: _billingType == 'GST' ? Colors.white : const Color(0xFF64748B),
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
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: _billingType == 'Non-GST' ? const Color(0xFF0F172A) : Colors.transparent,
                                                      borderRadius: BorderRadius.circular(11),
                                                      boxShadow: _billingType == 'Non-GST'
                                                          ? [
                                                              BoxShadow(
                                                                color: const Color(0xFF0F172A).withOpacity(0.3),
                                                                blurRadius: 6,
                                                                offset: const Offset(0, 2),
                                                              )
                                                            ]
                                                          : [],
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(
                                                          _billingType == 'Non-GST' ? Icons.check_circle_rounded : Icons.description_outlined,
                                                          size: 16,
                                                          color: _billingType == 'Non-GST' ? Colors.white : const Color(0xFF64748B),
                                                        ),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          _billingType == 'Non-GST' ? 'Non-GST Billing ✅' : 'Non-GST Billing',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w700,
                                                            color: _billingType == 'Non-GST' ? Colors.white : const Color(0xFF64748B),
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
                                        if (_billingType == 'GST') ...[
                                          const SizedBox(height: 14),
                                          const Text(
                                            'GSTIN Number *',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                          ),
                                          const SizedBox(height: 6),
                                          TextField(
                                            controller: _gstNumberController,
                                            textCapitalization: TextCapitalization.characters,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 1),
                                            decoration: InputDecoration(
                                              hintText: 'e.g. 07AAAAA0000A1Z5',
                                              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                              prefixIcon: const Icon(Icons.verified_user_rounded, color: Color(0xFF00C2FF)),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(color: Color(0xFF64748B), width: 1.5),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(color: Color(0xFF64748B), width: 1.5),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(color: Color(0xFF00C2FF), width: 2.0),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          const Text(
                                            'GST Tax Percentage *',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                          ),
                                          const SizedBox(height: 8),
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            physics: const BouncingScrollPhysics(),
                                            child: Row(
                                              children: [
                                                ..._standardGstOptions.map((rate) {
                                                  final isSelected = !_isCustomGstSelected && _gstPercentage == rate;
                                                  return Padding(
                                                    padding: const EdgeInsets.only(right: 8),
                                                    child: ChoiceChip(
                                                      avatar: isSelected ? const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16) : null,
                                                      label: Text('${rate.toInt()}% GST'),
                                                      selected: isSelected,
                                                      selectedColor: const Color(0xFF10B981),
                                                      backgroundColor: const Color(0xFFF1F5F9),
                                                      labelStyle: TextStyle(
                                                        color: isSelected ? Colors.white : const Color(0xFF334155),
                                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                                      ),
                                                      onSelected: (selected) {
                                                        if (selected) {
                                                          setState(() {
                                                            _isCustomGstSelected = false;
                                                            _gstPercentage = rate;
                                                          });
                                                        }
                                                      },
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // SECTION 3: Dietary & Restaurant Type
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: const [
                                        BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(color: Color(0xFF051C48), shape: BoxShape.circle),
                                              child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 16),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Restaurant Type',
                                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildTypeOptionCard(
                                                title: 'Pure Veg',
                                                emoji: '🌱',
                                                color: const Color(0xFF10B981),
                                                isSelected: _restaurantType == 'Veg',
                                                onTap: () => setState(() => _restaurantType = 'Veg'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildTypeOptionCard(
                                                title: 'Non-Veg',
                                                emoji: '🍗',
                                                color: const Color(0xFFEF4444),
                                                isSelected: _restaurantType == 'Non-Veg',
                                                onTap: () => setState(() => _restaurantType = 'Non-Veg'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _buildTypeOptionCard(
                                                title: 'Both',
                                                emoji: '🥗',
                                                color: const Color(0xFF0052FF),
                                                isSelected: _restaurantType == 'Both',
                                                onTap: () => setState(() => _restaurantType = 'Both'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // SECTION 4: Payment Methods Configuration
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: const [
                                        BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(color: Color(0xFF051C48), shape: BoxShape.circle),
                                              child: const Icon(Icons.payment_rounded, color: Colors.white, size: 16),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Payment Methods',
                                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'Add your Merchant UPI VPA ID to receive instant customer payments',
                                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: _upiIdController,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                          decoration: InputDecoration(
                                            labelText: 'Merchant UPI VPA ID',
                                            labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.bold),
                                            hintText: 'e.g. merchant@okicici, 9876543210@paytm',
                                            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                            prefixIcon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF00C2FF)),
                                            filled: true,
                                            fillColor: const Color(0xFFF1F5F9),
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00C2FF), width: 1.5)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // SECTION 5: Tables Configuration (If Dine-In)
                                  if (_selectedServices.contains('Dine In')) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        boxShadow: const [
                                          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: const BoxDecoration(color: Color(0xFF051C48), shape: BoxShape.circle),
                                                child: const Icon(Icons.table_restaurant_rounded, color: Colors.white, size: 16),
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Number of Tables',
                                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    IconButton(
                                                      onPressed: () {
                                                        if (_tableCount > 1) {
                                                          setState(() {
                                                            _tableCount--;
                                                            _tableCountController.text = '$_tableCount';
                                                          });
                                                        }
                                                      },
                                                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF0F172A)),
                                                    ),
                                                    SizedBox(
                                                      width: 50,
                                                      child: TextField(
                                                        controller: _tableCountController,
                                                        keyboardType: TextInputType.number,
                                                        textAlign: TextAlign.center,
                                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                                                        onChanged: (val) {
                                                          final num = int.tryParse(val);
                                                          if (num != null && num > 0) {
                                                            setState(() => _tableCount = num);
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          _tableCount++;
                                                          _tableCountController.text = '$_tableCount';
                                                        });
                                                      },
                                                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0F172A)),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Text(
                                                  '$_tableCount Dining Tables',
                                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                              ],
                            ),
                          ),
                        ),

                        // 5. Primary Action Button (Save & Launch POS vs Save Settings)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: widget.isFromOnboarding
                                  ? GlassTheme.primaryButtonGradient
                                  : const LinearGradient(
                                      colors: [Color(0xFF051C48), Color(0xFF0A2B6E)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.isFromOnboarding ? const Color(0x3300C2FF) : const Color(0x33051C48),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSaveSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.2,
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
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
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

  Widget _buildServiceChip({
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C2FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF00C2FF) : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00C2FF).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF475569),
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOptionCard({
    required String title,
    required String emoji,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? color : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
