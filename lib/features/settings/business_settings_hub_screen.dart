import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/widgets/glass_widgets.dart';
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
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.payment_rounded, color: GlassTheme.primaryCyan, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Payment Setting',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Configure your Merchant UPI ID to receive instant customer payments',
                    style: TextStyle(fontSize: 12, color: GlassTheme.textMedium),
                  ),
                  const SizedBox(height: 20),
                  GlassTextField(
                    controller: _upiIdController,
                    labelText: 'Merchant UPI VPA ID',
                    hintText: 'e.g. merchant@okicici, 9876543210@paytm',
                    prefixIcon: Icons.qr_code_2_rounded,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white38),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          final updated = (db.restaurant ?? RestaurantModel(
                            id: 'rest_001',
                            name: '',
                            tagline: '',
                            phone: '',
                            address: '',
                            cuisineType: 'Indian',
                          )).copyWith(
                            upiId: _upiIdController.text.trim().isEmpty ? 'apnapos@upi' : _upiIdController.text.trim(),
                          );
                          await db.updateRestaurantProfile(updated);
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payment setting updated successfully!'), backgroundColor: Colors.green),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C2FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  }

  void _showOutletInfoModal() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storefront_rounded, color: GlassTheme.primaryCyan, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Outlet Info',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Update outlet name, phone number, and address displayed on receipt bills',
                    style: TextStyle(fontSize: 12, color: GlassTheme.textMedium),
                  ),
                  const SizedBox(height: 18),
                  GlassTextField(controller: _nameController, labelText: 'Outlet Name', hintText: 'Apna POS Diner'),
                  const SizedBox(height: 12),
                  GlassTextField(controller: _taglineController, labelText: 'Tagline / Slogan', hintText: 'Taste the Perfection'),
                  const SizedBox(height: 12),
                  GlassTextField(controller: _phoneController, labelText: 'Contact Phone', hintText: '+91 98765 43210'),
                  const SizedBox(height: 12),
                  GlassTextField(controller: _addressController, labelText: 'Outlet Address', hintText: 'Connaught Place, New Delhi', maxLines: 2),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white38),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
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
                            const SnackBar(content: Text('Outlet info updated successfully!'), backgroundColor: Colors.green),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C2FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BusinessSettingsScreen()),
                          );
                        },
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
