import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import '../../core/widgets/glass_company_name_badge.dart';
import 'add_business_address_screen.dart';
import 'business_settings_screen.dart';
import '../../core/services/onboarding_service.dart';



class ConfirmBusinessAddressScreen extends StatefulWidget {
  final String? customAddress;
  final String? addressType;

  const ConfirmBusinessAddressScreen({
    super.key,
    this.customAddress,
    this.addressType = 'Home',
  });

  @override
  State<ConfirmBusinessAddressScreen> createState() => _ConfirmBusinessAddressScreenState();
}

class _ConfirmBusinessAddressScreenState extends State<ConfirmBusinessAddressScreen> {
  final db = DatabaseService();

  late String _displayAddress;
  late String _displayAddressType;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayAddressType = widget.addressType ?? 'Home';

    final savedAddress = db.restaurant?.address;
    if (widget.customAddress != null && widget.customAddress!.isNotEmpty) {
      _displayAddress = widget.customAddress!;
    } else if (savedAddress != null && savedAddress.isNotEmpty) {
      _displayAddress = savedAddress;
    } else {
      _displayAddress = '';
    }
  }

  void _editAddress() {
    // Navigate back to AddBusinessAddressScreen to edit address
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddBusinessAddressScreen()),
    ).then((_) {
      // Refresh address when returning
      setState(() {
        if (db.restaurant?.address != null && db.restaurant!.address.isNotEmpty) {
          _displayAddress = db.restaurant!.address;
        }
      });
    });
  }

  Future<void> _handleFinalContinue() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final city = _displayAddress.split(',').first.trim().isNotEmpty
          ? _displayAddress.split(',').first.trim()
          : 'New Delhi';

      await OnboardingService().saveAddress(
        addressLine: _displayAddress,
        placeType: _displayAddressType.toLowerCase() == 'home'
            ? 'home'
            : _displayAddressType.toLowerCase() == 'work'
                ? 'work'
                : 'other',
        city: city,
        country: 'IN',
        latitude: 28.6139,
        longitude: 77.2090,
      );

      if (!mounted) return;

      // Navigate to Business Settings Screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BusinessSettingsScreen()),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final businessTitle = db.restaurant?.name ??
        db.currentUser?.companyName ??
        'Tea Coffee';

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
                    Color(0x550052FF), // Logo Electric Blue Ambient Glow
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
              width: 240,
              height: 240,
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

          // 3. Main Screen Layout
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Back Button and Requested Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
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
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: GlassCompanyNameBadge(name: businessTitle),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. Curved White Card Container matching Auth Theme
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 30,
                          offset: Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                            child: Column(
                              children: [
                                // Error Banner
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFFCA5A5)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded,
                                            color: Color(0xFFEF4444), size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              color: Color(0xFFB91C1C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                const SizedBox(height: 10),

                                // 3D Storefront Business Address Graphic Illustration (Transparent PNG)
                                SizedBox(
                                  width: 210,
                                  height: 190,
                                  child: Image.asset(
                                    'assets/images/business_address_graphic.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 200,
                                        height: 180,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.storefront_rounded,
                                            size: 80,
                                            color: Color(0xFF0052FF),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Rephrased Title Subheading in Professional English
                                const Text(
                                  'Your Business Address Has Been Added!',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 24),

                                // Filled Address Card Container matching Mockup with Red Edit Pencil
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFF10B981), // Emerald Green Border
                                          width: 1.8,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x1410B981),
                                            blurRadius: 14,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                _displayAddressType,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                _displayAddressType == 'Work'
                                                    ? Icons.business_center_rounded
                                                    : _displayAddressType == 'Other'
                                                        ? Icons.location_on_rounded
                                                        : Icons.home_rounded,
                                                size: 18,
                                                color: const Color(0xFF0F172A),
                                              ),
                                              const Spacer(),

                                              // Red Edit Pencil Icon Button matching Mockup
                                              InkWell(
                                                onTap: _editAddress,
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFEF2F2),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.edit_rounded,
                                                    color: Color(0xFFEF4444), // Red Pencil Icon
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 8),

                                          // Full Saved Address Text
                                          Text(
                                            _displayAddress,
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF475569),
                                              height: 1.4,
                                            ),
                                          ),

                                          const SizedBox(height: 12),
                                        ],
                                      ),
                                    ),

                                    // Green "Default" Tag Badge matching Mockup
                                    Positioned(
                                      bottom: -12,
                                      left: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981), // Emerald Green
                                          borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(10),
                                            bottomLeft: Radius.circular(10),
                                            bottomRight: Radius.circular(10),
                                          ),
                                        ),
                                        child: const Text(
                                          'Default',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 5. Primary Action Button ("Continue") as requested
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: GlassTheme.primaryButtonGradient,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x3300C2FF),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleFinalContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(26),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontSize: 17,
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
}
