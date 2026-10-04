import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/models/restaurant_model.dart';
import '../../core/services/location_service.dart';
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
    db.saveOnboardingProgress(route: 'add_address', step: 5);
    final user = db.currentUser;
    final rest = db.restaurant;

    final initialName = rest?.name ?? user?.companyName ?? user?.name ?? 'The Sky High';
    final initialPhone = user?.phone ?? rest?.phone ?? '9899636418';
    final cleanPhone = initialPhone.replaceAll(RegExp(r'^\+\d+\s*'), '');

    _searchController = TextEditingController();
    _fullNameController = TextEditingController(text: initialName);
    _phoneController = TextEditingController(text: cleanPhone.isNotEmpty ? cleanPhone : '9899636418');
    _addressController = TextEditingController(text: rest?.address ?? '12-A Connaught Place, New Delhi');
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
          backgroundColor: Color(0xFF021B54),
          content: Text(
            'GPS Location loaded successfully!',
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
          : (db.restaurant?.name ?? 'The Sky High');

      final houseNo = _houseNoController.text.trim();
      final landmark = _landmarkController.text.trim();
      final pincode = _pincodeController.text.trim();

      String fullFormattedAddress = address;
      if (houseNo.isNotEmpty) fullFormattedAddress = '$houseNo, $fullFormattedAddress';
      if (landmark.isNotEmpty) fullFormattedAddress = '$fullFormattedAddress, $landmark';
      if (pincode.isNotEmpty) fullFormattedAddress = '$fullFormattedAddress - $pincode';

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
          backgroundColor: const Color(0xFF021B54),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Address for "$businessName" saved successfully!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      await db.saveOnboardingProgress(route: 'confirm_address', step: 6);

      if (!mounted) return;

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

              // 2. Curved Soft Neumorphic Body Sheet with Sticky Save & Continue Button
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
                                      border: Border.all(color: const Color(0xFFFCA5A5)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
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

                                // Top Location Search Bar & GPS Locate Button Row
                                Row(
                                  children: [
                                    // Search Location Input Field
                                    Expanded(
                                      child: Container(
                                        height: 48,
                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white, width: 1.5),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x0C002870),
                                              blurRadius: 6,
                                              offset: Offset(2, 3),
                                            ),
                                            BoxShadow(
                                              color: Colors.white,
                                              blurRadius: 5,
                                              offset: Offset(-2, -2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.search_rounded,
                                              color: Color(0xFF94A3B8),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: TextField(
                                                controller: _searchController,
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                decoration: const InputDecoration(
                                                  hintText: 'Search Location',
                                                  hintStyle: TextStyle(
                                                    fontSize: 13,
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

                                    const SizedBox(width: 10),

                                    // Neumorphic GPS Target Location Pin Button
                                    InkWell(
                                      onTap: _isFetchingLocation ? null : _fetchCurrentLocationWithPermission,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE6FFFA),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                            width: 1.5,
                                          ),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x1810B981),
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                                            ),
                                            BoxShadow(
                                              color: Colors.white,
                                              blurRadius: 5,
                                              offset: Offset(-2, -2),
                                            ),
                                          ],
                                        ),
                                        child: _isFetchingLocation
                                            ? const Center(
                                                child: SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    color: Color(0xFF10B981),
                                                  ),
                                                ),
                                              )
                                            : const Center(
                                                child: Icon(
                                                  Icons.my_location_rounded,
                                                  color: Color(0xFF10B981),
                                                  size: 22,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Address Autocomplete Suggestions Dropdown
                                if (_showSuggestions && _filteredSuggestions.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFF0066FF), width: 1.2),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x14002870),
                                          blurRadius: 12,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: _filteredSuggestions.length,
                                      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (context, index) {
                                        final item = _filteredSuggestions[index];
                                        return ListTile(
                                          dense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                          leading: const Icon(Icons.location_on_rounded, color: Color(0xFF0066FF), size: 18),
                                          title: Text(item.mainText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A))),
                                          subtitle: Text(item.secondaryText, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                          onTap: () => _applySuggestion(item),
                                        );
                                      },
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 14),

                                // OR Divider
                                Row(
                                  children: const [
                                    Expanded(child: Divider(color: Color(0xFFCBD5E1), thickness: 0.8)),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        'OR',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Color(0xFFCBD5E1), thickness: 0.8)),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                // Save Address As Section
                                const Text(
                                  'Save Address As',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    _buildAddressTypeChip('Home', Icons.home_rounded),
                                    _buildAddressTypeChip('Work', Icons.business_center_rounded),
                                    _buildAddressTypeChip('Other', Icons.location_on_rounded),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // FIELD 1: Full Name
                                _buildNeumorphicField(
                                  label: 'Full Name',
                                  controller: _fullNameController,
                                  hint: 'The Sky High',
                                ),

                                const SizedBox(height: 12),

                                // FIELD 2: Phone Number Row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Country Code Box
                                    Container(
                                      height: 52,
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white, width: 1.5),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0A002870),
                                            blurRadius: 6,
                                            offset: Offset(2, 3),
                                          ),
                                          BoxShadow(
                                            color: Colors.white,
                                            blurRadius: 5,
                                            offset: Offset(-2, -2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Text('🇮🇳', style: TextStyle(fontSize: 18)),
                                            SizedBox(width: 4),
                                            Text('IN +91', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                            SizedBox(width: 2),
                                            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                                          ],
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 10),

                                    // Phone Number Field
                                    Expanded(
                                      child: _buildNeumorphicField(
                                        label: 'Phone Number',
                                        controller: _phoneController,
                                        hint: '9899636418',
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                // FIELD 3: Address
                                _buildNeumorphicField(
                                  label: 'Address',
                                  controller: _addressController,
                                  hint: 'Street Address',
                                ),

                                const SizedBox(height: 12),

                                // FIELD 4: House No./Flat/Buildings
                                _buildNeumorphicField(
                                  label: 'House No./Flat/Buildings',
                                  controller: _houseNoController,
                                  hint: 'Flat or House Number',
                                ),

                                const SizedBox(height: 12),

                                // FIELD 5: Add Nearby Landmark
                                _buildNeumorphicField(
                                  label: 'Add Nearby Landmark',
                                  controller: _landmarkController,
                                  hint: 'Landmark',
                                ),

                                const SizedBox(height: 12),

                                // FIELD 6: Pincode
                                _buildNeumorphicField(
                                  label: 'Pincode',
                                  controller: _pincodeController,
                                  hint: 'Pincode',
                                  keyboardType: TextInputType.number,
                                ),

                                const SizedBox(height: 10),

                                // Additional Details Expandable
                                InkWell(
                                  onTap: () {
                                    setState(() => _showAdditionalDetails = !_showAdditionalDetails);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Additional Details',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _showAdditionalDetails ? const Color(0xFF0066FF) : const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          _showAdditionalDetails ? Icons.remove_rounded : Icons.add_rounded,
                                          color: _showAdditionalDetails ? const Color(0xFF0066FF) : const Color(0xFF64748B),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (_showAdditionalDetails) ...[
                                  const SizedBox(height: 8),
                                  _buildNeumorphicField(
                                    label: 'Additional Delivery Notes',
                                    controller: _additionalController,
                                    hint: 'Floor number, gate code, etc.',
                                    maxLines: 2,
                                  ),
                                ],

                                const SizedBox(height: 14),
                              ],
                            ),
                          ),
                        ),

                        // Sticky Bottom Action Bar with "Save & Continue" Button (Background Removed)
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

  // Address Type Neumorphic Chips (Home, Work, Other)
  Widget _buildAddressTypeChip(String label, IconData icon) {
    final isSelected = _selectedAddressType == label;

    return InkWell(
      onTap: () => setState(() => _selectedAddressType = label),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0066FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0066FF) : Colors.white,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x350066FF),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x0A002870),
                    blurRadius: 6,
                    offset: Offset(2, 3),
                  ),
                  BoxShadow(
                    color: Colors.white,
                    blurRadius: 5,
                    offset: Offset(-2, -2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Compact Neumorphic Input Field
  Widget _buildNeumorphicField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A002870),
            blurRadius: 6,
            offset: Offset(2, 3),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 5,
            offset: Offset(-2, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 1),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w400,
                color: Color(0xFFCBD5E1),
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 2),
            ),
          ),
        ],
      ),
    );
  }

  // Top Midnight Navy Header with Circular Back Button and Company Name Badge (Icon Removed)
  Widget _buildTopHeader(String companyName) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF021B54),
            Color(0xFF03266B),
            Color(0xFF021B54),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
          child: Row(
            children: [
              // Neumorphic Frosted Circular Back Button
              InkWell(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0).withValues(alpha: 0.88),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
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

              // Neumorphic Frosted Company Name Badge (Icon Removed)
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
                      color: Colors.black.withValues(alpha: 0.15),
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

  // Sticky Bottom Action Bar with Midnight Navy "Save & Continue" Button (Background Removed)
  Widget _buildStickyBottomBar() {
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
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
            boxShadow: const [
              BoxShadow(
                color: Color(0x30021B54),
                blurRadius: 12,
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
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.2,
                    ),
                  )
                : const Center(
                    child: Text(
                      'Save & Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
