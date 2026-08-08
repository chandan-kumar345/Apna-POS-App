import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/models/restaurant_model.dart';
import '../../core/services/sound_service.dart';
import '../../core/widgets/printer_selection_dialog.dart';
import '../onboarding/business_settings_screen.dart';

class BusinessSettingsHubScreen extends StatefulWidget {
  const BusinessSettingsHubScreen({super.key});

  @override
  State<BusinessSettingsHubScreen> createState() => _BusinessSettingsHubScreenState();
}

class _BusinessSettingsHubScreenState extends State<BusinessSettingsHubScreen> {
  final db = DatabaseService();

  late TextEditingController _nameController;
  late TextEditingController _taglineController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _taxController;
  late TextEditingController _upiIdController;

  @override
  void initState() {
    super.initState();
    final rest = db.restaurant;
    _nameController = TextEditingController(text: rest?.name ?? '');
    _taglineController = TextEditingController(text: rest?.tagline ?? '');
    _phoneController = TextEditingController(text: rest?.phone ?? '');
    _addressController = TextEditingController(text: rest?.address ?? '');
    _taxController = TextEditingController(text: rest?.taxRate.toString() ?? '5.0');
    _upiIdController = TextEditingController(text: rest?.upiId ?? 'apnapos@upi');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  void _showPaymentSettingsModal() {
    String? modalError;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 10,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF051C48),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.payment_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Payment Setting',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Configure your Merchant UPI VPA ID to receive instant customer payments',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),

                      if (modalError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  modalError!,
                                  style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      const Text('Merchant UPI VPA ID *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _upiIdController,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'e.g. merchant@okicici, 9876543210@paytm',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          prefixIcon: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF051C48)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final text = _upiIdController.text.trim();
                              if (text.isEmpty) {
                                setModalState(() => modalError = 'Please enter a valid Merchant UPI VPA ID');
                                return;
                              }
                              final updated = (db.restaurant ?? RestaurantModel(
                                id: 'rest_001',
                                name: '',
                                tagline: '',
                                phone: '',
                                address: '',
                                cuisineType: 'Indian',
                              )).copyWith(
                                upiId: text,
                              );
                              await db.updateRestaurantProfile(updated);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text('Payment setting updated successfully!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF15803D),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF051C48),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text('Save Payment Setting', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showOutletInfoModal() {
    String? modalError;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 10,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF051C48),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Outlet Info',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Update outlet name, tagline, contact phone and receipt header address',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),

                      if (modalError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  modalError!,
                                  style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      
                      _buildLightInputField(controller: _nameController, label: 'Outlet Name *', hint: 'Apna POS Diner'),
                      const SizedBox(height: 10),
                      _buildLightInputField(controller: _taglineController, label: 'Tagline / Slogan', hint: 'Taste the Perfection'),
                      const SizedBox(height: 10),
                      _buildLightInputField(controller: _phoneController, label: 'Contact Phone *', hint: '+91 98765 43210'),
                      const SizedBox(height: 10),
                      _buildLightInputField(controller: _addressController, label: 'Outlet Address *', hint: 'Connaught Place, New Delhi', maxLines: 2),

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              if (_nameController.text.trim().isEmpty) {
                                setModalState(() => modalError = 'Please enter outlet name');
                                return;
                              }
                              if (_phoneController.text.trim().isEmpty) {
                                setModalState(() => modalError = 'Please enter contact phone number');
                                return;
                              }
                              if (_addressController.text.trim().isEmpty) {
                                setModalState(() => modalError = 'Please enter outlet address');
                                return;
                              }
                              final updated = (db.restaurant ?? RestaurantModel(
                                id: 'rest_001',
                                name: '',
                                tagline: '',
                                phone: '',
                                address: '',
                                cuisineType: 'Indian',
                              )).copyWith(
                                name: _nameController.text.trim(),
                                tagline: _taglineController.text.trim(),
                                phone: _phoneController.text.trim(),
                                address: _addressController.text.trim(),
                              );
                              await db.updateRestaurantProfile(updated);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text('Outlet info updated successfully!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF15803D),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF051C48),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text('Save Outlet Info', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTaxSettingsModal() {
    final rest = db.restaurant;
    final gstController = TextEditingController(text: rest?.gstNumber ?? '');
    final taxRateController = TextEditingController(text: rest?.taxRate.toString() ?? '5.0');
    String? modalError;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 10,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF051C48),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.percent_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Tax Settings',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Configure GSTIN and default tax percentage for billing',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 16),

                      if (modalError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  modalError!,
                                  style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      
                      _buildLightInputField(controller: gstController, label: 'GSTIN Number', hint: 'e.g. 07AAAAA0000A1Z5'),
                      const SizedBox(height: 12),
                      _buildLightInputField(controller: taxRateController, label: 'GST Tax Percentage (%)', hint: 'e.g. 5.0, 12.0, 18.0', isNumeric: true),

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              final rateText = taxRateController.text.trim();
                              final rate = double.tryParse(rateText);
                              if (rate == null || rate < 0) {
                                setModalState(() => modalError = 'Please enter a valid non-negative tax percentage');
                                return;
                              }
                              final updated = (db.restaurant ?? RestaurantModel(
                                id: 'rest_001',
                                name: '',
                                tagline: '',
                                phone: '',
                                address: '',
                                cuisineType: 'Indian',
                              )).copyWith(
                                gstNumber: gstController.text.trim(),
                                taxRate: rate,
                              );
                              await db.updateRestaurantProfile(updated);
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text('Tax settings updated successfully!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF15803D),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF051C48),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text('Save Tax Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLightInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    bool isNumeric = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF051C48), width: 1.5)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Header Title Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF051C48), Color(0xFF0A2B6E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF00C2FF), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Business Setting',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            db.restaurant?.name.isNotEmpty == true
                                ? 'Outlet Settings & Configuration for ${db.restaurant!.name}'
                                : 'Configure store preferences, orders, hardware & payments',
                            style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // CATEGORY 1: STORE & ORDER CONFIGURATION (Cyan Pill Header Banner)
              _buildSectionPillHeader('Store & Order Configuration', Icons.storefront_rounded),
              const SizedBox(height: 14),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final crossAxisCount = isWide ? 4 : 2;

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: isWide ? 1.15 : 1.05,
                    children: [
                      // 1. ORDER SETTING (Primary Card requested by user)
                      _buildSettingGridCard(
                        title: 'Order Setting',
                        subtitle: 'Dine-In, Tables, GST & Channels',
                        icon: Icons.shopping_cart_checkout_rounded,
                        accentColor: const Color(0xFF00C2FF),
                        badgeText: 'Primary',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BusinessSettingsScreen()),
                          );
                        },
                      ),

                      // 2. OUTLET INFO
                      _buildSettingGridCard(
                        title: 'Outlet Info',
                        subtitle: 'Name, Address & Contact Details',
                        icon: Icons.storefront_rounded,
                        accentColor: const Color(0xFF0052FF),
                        onTap: _showOutletInfoModal,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // CATEGORY 2: FINANCIALS & PAYMENTS (Cyan Pill Header Banner)
              _buildSectionPillHeader('Financials & Payments', Icons.account_balance_wallet_rounded),
              const SizedBox(height: 14),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final crossAxisCount = isWide ? 4 : 2;

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: isWide ? 1.15 : 1.05,
                    children: [
                      // 3. PAYMENT SETTING (Primary Card requested by user)
                      _buildSettingGridCard(
                        title: 'Payment Setting',
                        subtitle: 'UPI VPA & Accepted Modes',
                        icon: Icons.payment_rounded,
                        accentColor: const Color(0xFF10B981),
                        badgeText: 'Active',
                        onTap: _showPaymentSettingsModal,
                      ),

                      // 4. TAX SETTINGS
                      _buildSettingGridCard(
                        title: 'Tax Settings',
                        subtitle: 'GST Rate (${db.restaurant?.taxRate ?? 5.0}%) & Breakdown',
                        icon: Icons.percent_rounded,
                        accentColor: const Color(0xFF8B5CF6),
                        onTap: _showTaxSettingsModal,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 28),

              // CATEGORY 3: HARDWARE & LOGISTICS (Cyan Pill Header Banner)
              _buildSectionPillHeader('Hardware & Logistics', Icons.precision_manufacturing_rounded),
              const SizedBox(height: 14),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final crossAxisCount = isWide ? 4 : 2;

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: isWide ? 1.15 : 1.05,
                    children: [
                      // 5. PRINTER SETTING (Primary Card requested by user)
                      _buildSettingGridCard(
                        title: 'Printer Setting',
                        subtitle: 'Bluetooth Thermal Bill Printer',
                        icon: Icons.print_rounded,
                        accentColor: const Color(0xFFF59E0B),
                        badgeText: 'Bluetooth',
                        onTap: () {
                          PrinterSelectionDialog.show(context);
                        },
                      ),

                      // 6. SOUND & CLICK FEEL
                      _buildSettingGridCard(
                        title: 'Sound Setting',
                        subtitle: SoundService.soundEnabled ? 'Click Audio Enabled' : 'Muted',
                        icon: SoundService.soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                        accentColor: const Color(0xFFEC4899),
                        onTap: () {
                          setState(() {
                            SoundService.setSoundEnabled(!SoundService.soundEnabled);
                          });
                          if (SoundService.soundEnabled) {
                            SoundService.playButtonClick();
                          }
                        },
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Section Pill Header matching exact rounded banner design from reference image
  Widget _buildSectionPillHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF00C2FF), // Vibrant cyan matching user screenshot banner
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2200C2FF),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Grid Setting Card matching rounded icon box layout from reference image
  Widget _buildSettingGridCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
                  ),
                  child: Center(
                    child: Icon(icon, color: accentColor, size: 26),
                  ),
                ),
                if (badgeText != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF64748B),
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
