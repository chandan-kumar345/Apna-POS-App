import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import '../../core/models/restaurant_model.dart';
import '../../core/services/location_service.dart';
import '../../core/widgets/glass_company_name_badge.dart';
import '../dashboard/main_layout.dart';
import 'choose_business_category_screen.dart';
import 'confirm_business_address_screen.dart';

class AddressSuggestion {
  final String mainText;
  final String secondaryText;
  final String fullAddress;
  final String houseNo;
  final String landmark;
  final String pincode;

  const AddressSuggestion({
    required this.mainText,
    required this.secondaryText,
    required this.fullAddress,
    required this.houseNo,
    required this.landmark,
    required this.pincode,
  });
}

const List<AddressSuggestion> mockAddressSuggestions = [
  AddressSuggestion(
    mainText: 'Connaught Place',
    secondaryText: 'Inner Circle, New Delhi, Delhi 110001',
    fullAddress: 'Connaught Place, Inner Circle, Central Delhi',
    houseNo: 'Flat 12-A',
    landmark: 'Near Rajiv Chowk Metro Station Gate 2',
    pincode: '110001',
  ),
  AddressSuggestion(
    mainText: 'Cyber City',
    secondaryText: 'DLF Phase 2, Gurugram, Haryana 122002',
    fullAddress: 'DLF Cyber City, Building 10, Sector 24',
    houseNo: 'Tower B, 4th Floor',
    landmark: 'Opposite Cyber Hub Main Gate',
    pincode: '122002',
  ),
  AddressSuggestion(
    mainText: 'Indiranagar',
    secondaryText: '100 Feet Road, Bengaluru, Karnataka 560038',
    fullAddress: '100 Feet Road, Indiranagar 1st Stage',
    houseNo: 'No. 458, 2nd Cross',
    landmark: 'Behind Toit Brewpub',
    pincode: '560038',
  ),
  AddressSuggestion(
    mainText: 'Bandra West',
    secondaryText: 'Linking Road, Mumbai, Maharashtra 400050',
    fullAddress: 'Linking Road, Bandra West, Mumbai',
    houseNo: 'Shop No. 5, Star Building',
    landmark: 'Near National College',
    pincode: '400050',
  ),
  AddressSuggestion(
    mainText: 'Park Street',
    secondaryText: 'Kolkata, West Bengal 700016',
    fullAddress: 'Park Street Area, Chowringhee',
    houseNo: 'Building 18-C',
    landmark: 'Near Flurys Bakery',
    pincode: '700016',
  ),
];

class AddBusinessAddressScreen extends StatefulWidget {
  const AddBusinessAddressScreen({super.key});

  @override
  State<AddBusinessAddressScreen> createState() => _AddBusinessAddressScreenState();
}

class _AddBusinessAddressScreenState extends State<AddBusinessAddressScreen> {
  final db = DatabaseService();

  late TextEditingController _searchController;
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _houseNoController;
  late TextEditingController _landmarkController;
  late TextEditingController _pincodeController;
  late TextEditingController _additionalController;

  String _selectedAddressType = 'Home';
  bool _showSuggestions = false;
  List<AddressSuggestion> _filteredSuggestions = [];
  bool _showAdditionalDetails = false;

  bool _isLoading = false;
  bool _isFetchingLocation = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = db.currentUser;
    final rest = db.restaurant;

    final initialName = rest?.name ?? user?.companyName ?? user?.name ?? 'Tea Coffee';
    final initialPhone = user?.phone ?? rest?.phone ?? '9899636369';
    final cleanPhone = initialPhone.replaceAll(RegExp(r'^\+\d+\s*'), '');

    _searchController = TextEditingController();
    _fullNameController = TextEditingController(text: initialName);
    _phoneController = TextEditingController(text: cleanPhone);
    _addressController = TextEditingController(text: rest?.address ?? '');
    _houseNoController = TextEditingController();
    _landmarkController = TextEditingController();
    _pincodeController = TextEditingController();
    _additionalController = TextEditingController();

    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _houseNoController.dispose();
    _landmarkController.dispose();
    _pincodeController.dispose();
    _additionalController.dispose();
    super.dispose();
  }

  void _onSearchChanged() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _showSuggestions = false;
          _filteredSuggestions = [];
        });
      }
      return;
    }

    final liveResults = await LocationService.fetchAddressSuggestions(query);
    if (!mounted) return;

    if (liveResults.isNotEmpty) {
      setState(() {
        _filteredSuggestions = liveResults.map((item) {
          return AddressSuggestion(
            mainText: item.mainText,
            secondaryText: item.secondaryText,
            fullAddress: item.fullAddress,
            houseNo: item.houseNo,
            landmark: item.landmark,
            pincode: item.pincode,
          );
        }).toList();
        _showSuggestions = true;
      });
    } else {
      final localMatches = mockAddressSuggestions.where((s) {
        final q = query.toLowerCase();
        return s.mainText.toLowerCase().contains(q) ||
            s.secondaryText.toLowerCase().contains(q) ||
            s.fullAddress.toLowerCase().contains(q);
      }).toList();

      setState(() {
        _filteredSuggestions = localMatches;
        _showSuggestions = localMatches.isNotEmpty;
      });
    }
  }

  Future<void> _fetchCurrentLocationWithPermission() async {
    setState(() {
      _isFetchingLocation = true;
      _errorMessage = null;
    });

    try {
      final locationResult = await LocationService.getCurrentLocationAddress();
      if (!mounted) return;

      setState(() {
        _addressController.text = locationResult.fullAddress;
        if (locationResult.houseNo.isNotEmpty) _houseNoController.text = locationResult.houseNo;
        if (locationResult.landmark.isNotEmpty) _landmarkController.text = locationResult.landmark;
        if (locationResult.pincode.isNotEmpty) _pincodeController.text = locationResult.pincode;
        _searchController.text = locationResult.mainText;
        _showSuggestions = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0F172A),
          content: Text(
            'GPS Location permission granted & location loaded successfully!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _applySuggestion(AddressSuggestion suggestion) {
    setState(() {
      _addressController.text = suggestion.fullAddress;
      if (suggestion.houseNo.isNotEmpty) _houseNoController.text = suggestion.houseNo;
      if (suggestion.landmark.isNotEmpty) _landmarkController.text = suggestion.landmark;
      if (suggestion.pincode.isNotEmpty) _pincodeController.text = suggestion.pincode;
      _searchController.text = suggestion.mainText;
      _showSuggestions = false;
    });
  }

  Future<void> _handleSaveAddressAndNext() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() => _errorMessage = 'Please enter your business address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final businessName = _fullNameController.text.trim().isNotEmpty
          ? _fullNameController.text.trim()
          : (db.restaurant?.name ?? 'Tea Coffee');

      final fullFormattedAddress =
          '${_houseNoController.text.trim()}, $address, ${_landmarkController.text.trim()} - ${_pincodeController.text.trim()}';

      final updated = RestaurantModel(
        id: db.restaurant?.id ?? 'rest_001',
        name: businessName,
        tagline: 'Authentic Flavors & Swift Service',
        phone: '+91 ${_phoneController.text.trim()}',
        address: fullFormattedAddress,
        cuisineType: db.restaurant?.cuisineType ?? 'Multi-Cuisine POS',
        currencySymbol: db.restaurant?.currencySymbol ?? '₹',
        taxRate: 5.0,
        tableCount: 12,
        isOnboarded: true,
      );

      // Save onboarding data to backend database & SharedPreferences
      await db.saveRestaurantOnboarding(updated);

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
                  'Welcome to Apna POS! Setup for "$businessName" completed.',
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

      // Open Confirm Business Address Screen with filled address
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmBusinessAddressScreen(
            customAddress: fullFormattedAddress,
            addressType: _selectedAddressType,
          ),
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Error saving address: $e');
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

          // 3. Main Layout
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Back Button and Address Title
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
                          child: GlassCompanyNameBadge(
                            name: db.restaurant?.name ?? db.currentUser?.companyName ?? 'Tea Coffee',
                          ),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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

                                // Top Location Search Bar & Map Pin Action Row matching Screenshot
                                Row(
                                  children: [
                                    // Search Location Input Field with Autocomplete
                                    Expanded(
                                      child: Container(
                                        height: 50,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color(0xFFCBD5E1),
                                            width: 1.2,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x0F000000),
                                              blurRadius: 6,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.search_rounded,
                                              color: Color(0xFF94A3B8),
                                              size: 22,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: TextField(
                                                controller: _searchController,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                decoration: const InputDecoration(
                                                  hintText: 'Search Location',
                                                  hintStyle: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w400,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    // Emerald/Cyan Location Pin Action Button matching screenshot
                                    InkWell(
                                      onTap: _isFetchingLocation ? null : _fetchCurrentLocationWithPermission,
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE6FFFA),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color(0xFF10B981),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: _isFetchingLocation
                                            ? const Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                ),
                                              )
                                            : const Center(
                                                child: Icon(
                                                  Icons.my_location_rounded,
                                                  color: Color(0xFF10B981),
                                                  size: 26,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Address Autocomplete Suggestions Dropdown List Overlay
                                if (_showSuggestions && _filteredSuggestions.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFF00C2FF), width: 1.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x1F000000),
                                          blurRadius: 16,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _filteredSuggestions.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (context, index) {
                                        final item = _filteredSuggestions[index];
                                        return Material(
                                          color: Colors.transparent,
                                          child: ListTile(
                                            dense: true,
                                            leading: const Icon(Icons.location_on_rounded, color: Color(0xFF00C2FF), size: 20),
                                            title: Text(item.mainText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: Color(0xFF0F172A))),
                                            subtitle: Text(item.secondaryText, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                            onTap: () => _applySuggestion(item),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 18),

                                // OR Divider matching Screenshot
                                Row(
                                  children: const [
                                    Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        'OR',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
                                  ],
                                ),

                                const SizedBox(height: 18),

                                // Save Address As Chips matching Screenshot
                                const Text(
                                  'Save Address As',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),

                                const SizedBox(height: 10),

                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    _buildAddressTypeChip('Home', Icons.home_rounded),
                                    _buildAddressTypeChip('Work', Icons.business_center_rounded),
                                    _buildAddressTypeChip('Other', Icons.location_on_rounded),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Full Name Field matching Screenshot
                                _buildOutlinedField(
                                  label: 'Full Name',
                                  controller: _fullNameController,
                                  hint: 'Tea Coffee',
                                ),

                                const SizedBox(height: 16),

                                // Phone Number Field Row matching Screenshot
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Country Code Box
                                    Container(
                                      height: 52,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                      ),
                                      child: Row(
                                        children: const [
                                          Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                          SizedBox(width: 6),
                                          Text('IN +91', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                          Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF64748B)),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    // Phone Number Field
                                    Expanded(
                                      child: _buildOutlinedField(
                                        label: 'Phone Number',
                                        controller: _phoneController,
                                        hint: '9899636369',
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Address Field matching Screenshot
                                _buildOutlinedField(
                                  label: 'Address',
                                  controller: _addressController,
                                  hint: 'Street Address',
                                ),

                                const SizedBox(height: 16),

                                // House No./Flat/Buildings Field matching Screenshot
                                _buildOutlinedField(
                                  label: 'House No./Flat/Buildings',
                                  controller: _houseNoController,
                                  hint: 'Flat or House Number',
                                ),

                                const SizedBox(height: 16),

                                // Add Nearby Landmark Field matching Screenshot
                                _buildOutlinedField(
                                  label: 'Add Nearby Landmark',
                                  controller: _landmarkController,
                                  hint: 'Landmark',
                                ),

                                const SizedBox(height: 16),

                                // Pincode Field matching Screenshot
                                _buildOutlinedField(
                                  label: 'Pincode',
                                  controller: _pincodeController,
                                  hint: 'Pincode',
                                  keyboardType: TextInputType.number,
                                ),

                                const SizedBox(height: 14),

                                // Additional Details Expandable Button matching Screenshot
                                InkWell(
                                  onTap: () {
                                    setState(() => _showAdditionalDetails = !_showAdditionalDetails);
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Additional Details',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        _showAdditionalDetails ? Icons.remove_rounded : Icons.add_rounded,
                                        color: Colors.black87,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),

                                if (_showAdditionalDetails) ...[
                                  const SizedBox(height: 10),
                                  _buildOutlinedField(
                                    label: 'Additional Delivery Notes',
                                    controller: _additionalController,
                                    hint: 'Floor number, gate code, etc.',
                                    maxLines: 2,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // 5. Primary Action Button ("Save & Continue")
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
                              onPressed: _isLoading ? null : _handleSaveAddressAndNext,
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
                                      'Save & Continue',
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

  Widget _buildAddressTypeChip(String label, IconData icon) {
    final isSelected = _selectedAddressType == label;

    return InkWell(
      onTap: () => setState(() => _selectedAddressType = label),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00C2FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x3300C2FF),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlinedField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                maxLines: maxLines,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFCBD5E1),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
