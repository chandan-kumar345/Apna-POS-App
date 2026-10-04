import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
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
    db.saveOnboardingProgress(route: 'confirm_address', step: 6);
    _displayAddressType = widget.addressType ?? 'Home';

    final savedAddress = db.restaurant?.address;
    if (widget.customAddress != null && widget.customAddress!.isNotEmpty) {
      _displayAddress = widget.customAddress!;
    } else if (savedAddress != null && savedAddress.isNotEmpty) {
      _displayAddress = savedAddress;
    } else {
      _displayAddress = '111, Sitapuri, New Delhi, Delhi, 110059';
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

      await db.saveOnboardingProgress(route: 'business_settings', step: 7);

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
    final dynamicCompanyName = db.restaurant?.name ??
        db.currentUser?.companyName ??
        'The Sky High';

    return Scaffold(
      backgroundColor: const Color(0xFF021B54),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // 1. Top Header on Midnight Navy (Company Badge Icon Removed)
              _buildTopHeader(dynamicCompanyName),

              // 2. Curved Soft Neumorphic Body Sheet with Sticky Continue Button
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F4F8),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x25001C55),
                        blurRadius: 24,
                        offset: Offset(0, -6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    child: Column(
                      children: [
                        // Scrollable Content
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Error Banner
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(12),
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
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 6),

                                // 3D Storefront Illustration Plate with Dynamic Company Name Signboard Overlay
                                Container(
                                  width: 215,
                                  height: 205,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFF0F5FA),
                                    boxShadow: [
                                      const BoxShadow(
                                        color: Color(0x16002460),
                                        blurRadius: 18,
                                        offset: Offset(5, 7),
                                      ),
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.95),
                                        blurRadius: 14,
                                        offset: const Offset(-5, -5),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/images/business_address_graphic.png',
                                        width: 205,
                                        height: 195,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 190,
                                            height: 175,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF0F5FA),
                                              borderRadius: BorderRadius.circular(28),
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.storefront_rounded,
                                                size: 76,
                                                color: Color(0xFF0052FF),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      // Dynamic Company Name Signboard Overlay over "YOUR BUSINESS ADDRESS"
                                      Positioned(
                                        top: 48,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                          constraints: const BoxConstraints(maxWidth: 125),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFF38BDF8),
                                              width: 1.2,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x70000000),
                                                blurRadius: 6,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            dynamicCompanyName.toUpperCase(),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: 0.6,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Title Text
                                const Text(
                                  'Your Business Address\nHas Been Added!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.4,
                                    height: 1.24,
                                  ),
                                ),

                                const SizedBox(height: 22),

                                // Neumorphic Address Card with Enhanced Tactile Effects
                                _buildNeumorphicAddressCard(),

                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),

                        // Sticky Continue Button
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

  // Top Header with Circular Back Button and Company Name Badge (Icon Removed)
  Widget _buildTopHeader(String companyName) {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              // Circular Neumorphic Back Button
              InkWell(
                onTap: () => Navigator.pop(context),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      fontSize: 13.5,
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

  // Enhanced Neumorphic Address Card
  Widget _buildNeumorphicAddressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE2EBF6),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14002870),
            blurRadius: 18,
            offset: Offset(5, 7),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 14,
            offset: Offset(-4, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Type Icon, Title, Default Badge, Edit Button
          Row(
            children: [
              // Icon Container with Neumorphic Inset Feel
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF5FD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFDEE9F7),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x10002870),
                      blurRadius: 5,
                      offset: Offset(2, 2),
                    ),
                    BoxShadow(
                      color: Colors.white,
                      blurRadius: 4,
                      offset: Offset(-2, -2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _displayAddressType == 'Work'
                        ? Icons.business_center_rounded
                        : _displayAddressType == 'Other'
                            ? Icons.location_on_rounded
                            : Icons.home_rounded,
                    color: const Color(0xFF002D7A),
                    size: 21,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Address Type Name
              Text(
                _displayAddressType,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),

              const SizedBox(width: 10),

              // Green "Default" Badge with Emerald Glow
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3510B981),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
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

              const Spacer(),

              // Neumorphic Edit Pencil Action Button
              InkWell(
                onTap: _editAddress,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF5FD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFDEE9F7),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x16002870),
                        blurRadius: 6,
                        offset: Offset(3, 4),
                      ),
                      BoxShadow(
                        color: Colors.white,
                        blurRadius: 5,
                        offset: Offset(-3, -3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.edit_rounded,
                      color: Color(0xFF002D7A),
                      size: 19,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Inset Neumorphic Address Details Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F6FB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFDEE7F6),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.location_on_rounded,
                    size: 18,
                    color: Color(0xFF0066FF),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _displayAddress,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                      height: 1.45,
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

  // Sticky Bottom Action Bar with Midnight Navy "Continue" Button
  Widget _buildStickyBottomBar() {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF021B54),
                Color(0xFF002B7A),
                Color(0xFF003D9E),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x35021B54),
                blurRadius: 16,
                offset: Offset(0, 8),
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
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
