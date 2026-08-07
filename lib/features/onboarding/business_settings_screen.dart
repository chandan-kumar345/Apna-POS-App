import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import '../../core/models/restaurant_model.dart';
import '../../core/widgets/glass_company_name_badge.dart';
import '../dashboard/main_layout.dart';

class BusinessSettingsScreen extends StatefulWidget {
  const BusinessSettingsScreen({super.key});

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

      // Show success toast feedback
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF00C2FF), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Business settings saved successfully!',
                  style: const TextStyle(
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

      // Only navigate to Main POS Dashboard if completing initial onboarding setup
      if (Navigator.canPop(context)) {
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
                // Top Header: Back Button & Highlighted Glass Company Name Badge (Removed when logged in / in sidebar)
                if (!(db.restaurant?.isOnboarded ?? false) && Navigator.canPop(context))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFFCA5A5)),
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
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // SECTION 1: Select Your Services (Multi Select) - ONLY Dine In, Takeaway & Delivery
                                const Text(
                                  'Select Your Services (Multi Select)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Choose order channels available in your restaurant',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 10),

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

                                const SizedBox(height: 18),
                                const Divider(color: Color(0xFFE2E8F0), thickness: 1),
                                const SizedBox(height: 16),

                                // SECTION 2: Billing Type & GST Setup (Required ✅)
                                const Text(
                                  'Billing Type & GST Configuration',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Billing Type Toggle Chips (GST vs Non-GST)
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
                                  // GST Number Field (High Contrast Crisp Border)
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
                                  // Horizontal Sliding GST Tax Percentage Options + Custom Option
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
                                              avatar: isSelected
                                                  ? const Icon(
                                                      Icons.check_circle_rounded,
                                                      color: Colors.white,
                                                      size: 16,
                                                    )
                                                  : null,
                                              label: Text('${rate.toInt()}% GST'),
                                              selected: isSelected,
                                              selectedColor: const Color(0xFF10B981),
                                              backgroundColor: const Color(0xFFF1F5F9),
                                              side: BorderSide(
                                                color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                                                width: 1.2,
                                              ),
                                              labelStyle: TextStyle(
                                                color: isSelected ? Colors.white : const Color(0xFF334155),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
                                              ),
                                              onSelected: (_) {
                                                setState(() {
                                                  _gstPercentage = rate;
                                                  _isCustomGstSelected = false;
                                                });
                                              },
                                            ),
                                          );
                                        }),

                                        // Custom GST Percentage Chip Option
                                        ChoiceChip(
                                          avatar: _isCustomGstSelected
                                              ? const Icon(
                                                  Icons.check_circle_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                )
                                              : const Icon(Icons.edit_note_rounded, size: 16),
                                          label: Text(
                                            _isCustomGstSelected
                                                ? 'Custom (${_gstPercentage.toStringAsFixed(_gstPercentage.truncateToDouble() == _gstPercentage ? 0 : 1)}%)'
                                                : 'Custom',
                                          ),
                                          selected: _isCustomGstSelected,
                                          selectedColor: const Color(0xFF00C2FF),
                                          backgroundColor: const Color(0xFFF1F5F9),
                                          side: BorderSide(
                                            color: _isCustomGstSelected ? const Color(0xFF00C2FF) : const Color(0xFFCBD5E1),
                                            width: 1.2,
                                          ),
                                          labelStyle: TextStyle(
                                            color: _isCustomGstSelected ? Colors.white : const Color(0xFF334155),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                          ),
                                          onSelected: (_) => _showCustomGstDialog(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 18),
                                const Divider(color: Color(0xFFE2E8F0), thickness: 1),
                                const SizedBox(height: 16),

                                // SECTION 3: Restaurant Type (Veg / Non-Veg / Both) (Required ✅)
                                const Text(
                                  'Restaurant Type (Dietary)',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 10),

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

                                // SECTION 3.5: Payment Methods Configuration (Merchant UPI VPA ID)
                                const SizedBox(height: 18),
                                const Divider(color: Color(0xFFE2E8F0), thickness: 1),
                                const SizedBox(height: 16),

                                const Text(
                                  'Payment Methods Configuration',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Add your Merchant UPI VPA ID to receive exact-amount customer payments directly into your bank account.',
                                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 10),

                                TextField(
                                  controller: _upiIdController,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    labelText: 'Merchant UPI VPA ID (to Receive Money)',
                                    labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontWeight: FontWeight.bold),
                                    hintText: 'e.g. merchant@okicici, 9876543210@paytm',
                                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF00C2FF)),
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(color: Color(0xFF00C2FF), width: 1.5),
                                    ),
                                  ),
                                ),

                                // SECTION 4: Number of Tables (If Dine-In Selected)
                                if (_selectedServices.contains('Dine In')) ...[
                                  const SizedBox(height: 18),
                                  const Divider(color: Color(0xFFE2E8F0), thickness: 1),
                                  const SizedBox(height: 16),

                                  const Text(
                                    'Number of Tables (Dine-In Layout)',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 10),

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
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
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
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _tableCount++;
                                                  _tableCountController.text = '$_tableCount';
                                                });
                                              },
                                              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00C2FF)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          '$_tableCount Dining Tables Configured',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // 5. Primary Action Button ("Save & Launch POS")
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Container(
                            width: double.infinity,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: GlassTheme.primaryButtonGradient,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x3300C2FF),
                                  blurRadius: 12,
                                  offset: Offset(0, 5),
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
                                  : const Text(
                                      'Save Business Settings',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
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
