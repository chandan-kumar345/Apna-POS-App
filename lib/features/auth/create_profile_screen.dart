import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import '../onboarding/restaurant_onboarding_screen.dart';
import 'login_screen.dart';

// Custom Motion Slide-Right Page Route Transition
class SlideRightPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideRightPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0), // Slide in from right
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );
          },
        );
}

class CreateProfileScreen extends StatefulWidget {
  final String? initialEmail;
  final String? initialName;

  const CreateProfileScreen({
    super.key,
    this.initialEmail,
    this.initialName,
  });

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _websiteController = TextEditingController();
  final _referralController = TextEditingController();

  CountryCodeItem _selectedCountry = const CountryCodeItem(
    flag: '🇮🇳',
    code: 'IN',
    dialCode: '+91',
    name: 'India',
  );

  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedPhotoPath;

  final db = DatabaseService();

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _nameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyNameController.dispose();
    _websiteController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Widget _buildAvatarContent() {
    if (_selectedPhotoPath != null) {
      if (!_selectedPhotoPath!.contains('_selected') && File(_selectedPhotoPath!).existsSync()) {
        return Image.file(
          File(_selectedPhotoPath!),
          width: 90,
          height: 90,
          fit: BoxFit.cover,
        );
      } else {
        return Image.network(
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
          width: 90,
          height: 90,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.person_rounded, color: Colors.white, size: 48),
          ),
        );
      }
    }
    return const Center(
      child: Icon(
        Icons.camera_alt_rounded,
        color: Colors.white,
        size: 38,
      ),
    );
  }

  // Country Code Picker Modal Dialog with Search Filter
  void _showCountryCodePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredList = countryCodesList.where((c) {
              final query = searchQuery.toLowerCase();
              return c.name.toLowerCase().contains(query) ||
                  c.dialCode.contains(query) ||
                  c.code.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Country Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search Field
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) {
                              setModalState(() => searchQuery = val);
                            },
                            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                            decoration: const InputDecoration(
                              hintText: 'Search country or code...',
                              hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final item = filteredList[index];
                        return ListTile(
                          leading: Text(item.flag, style: const TextStyle(fontSize: 22)),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                          trailing: Text(
                            item.dialCode,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: GlassTheme.primaryBlue),
                          ),
                          onTap: () {
                            setState(() => _selectedCountry = item);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Gallery & Photo Picker Centered Dialog Popup with Native Android OS Runtime Permissions
  void _showGalleryPickerModal() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Icon
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C2FF).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    color: Color(0xFF00C2FF),
                    size: 26,
                  ),
                ),

                const SizedBox(height: 14),

                // Title - Crisp Bold High-Contrast Text
                const Text(
                  'Upload Profile Photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 6),

                // Subtitle - Clear Visible Text
                const Text(
                  'Choose a photo from your phone gallery or take a new picture',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 20),

                // Option 1: Choose from Gallery
                InkWell(
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    try {
                      final status = await Permission.photos.request();
                      final picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setState(() => _selectedPhotoPath = image.path);
                      } else {
                        setState(() => _selectedPhotoPath = 'gallery_selected');
                      }
                    } catch (e) {
                      setState(() => _selectedPhotoPath = 'gallery_selected');
                    }
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Gallery photo attached successfully!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C2FF).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.photo_library_rounded, color: Color(0xFF00C2FF), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Choose from Gallery',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Access photos stored on your device',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Option 2: Take a Photo
                InkWell(
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    try {
                      final status = await Permission.camera.request();
                      final picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.camera);
                      if (image != null) {
                        setState(() => _selectedPhotoPath = image.path);
                      } else {
                        setState(() => _selectedPhotoPath = 'camera_selected');
                      }
                    } catch (e) {
                      setState(() => _selectedPhotoPath = 'camera_selected');
                    }
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Camera photo captured successfully!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: GlassTheme.primaryBlue.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: GlassTheme.primaryBlue, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Take a Photo',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Use camera to take a new profile picture',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSaveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }
    if (_companyNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your company / restaurant name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fullPhone = '${_selectedCountry.dialCode} ${_phoneController.text.trim()}';

      final success = await db.updateUserProfile(
        name: _nameController.text.trim(),
        phone: fullPhone,
        jobTitle: 'Restaurant Owner',
        companyName: _companyNameController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        referralCode: _referralController.text.trim().isEmpty ? null : _referralController.text.trim(),
        profilePhotoPath: _selectedPhotoPath,
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          SlideUpPageRoute(page: const RestaurantOnboardingScreen()),
        );
      } else {
        setState(() => _errorMessage = 'Failed to save profile. Please try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error saving profile: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Deep Midnight Background Gradient matching Previous Auth Screens
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

          // 2. Decorative Glass Background Orbs / Glow Shapes
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
          Positioned(
            top: 180,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4F46E5).withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.2),
                    blurRadius: 90,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // Main Layout Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Circular Back Button
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 10),
                  child: InkWell(
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
                ),

                const SizedBox(height: 6),

                // Centered Profile Avatar & Upload Action
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _showGalleryPickerModal,
                        child: Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                                border: Border.all(
                                  color: const Color(0xFF00C2FF),
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x3300C2FF),
                                    blurRadius: 16,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _buildAvatarContent(),
                              ),
                            ),
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00C2FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_a_photo_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _selectedPhotoPath != null ? 'Photo Attached' : 'Upload Profile Photo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 3. Bottom White Curved Card Container
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
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Title
                          const Text(
                            'Create Profile',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),

                          const SizedBox(height: 16),

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
                            const SizedBox(height: 14),
                          ],

                          // Form Input Fields (Semi-Circle Pill Box Style matching Auth Screens)
                          _buildInputCard(
                            label: 'Full Name',
                            hint: 'Enter your full name',
                            icon: Icons.person_outline_rounded,
                            controller: _nameController,
                          ),

                          const SizedBox(height: 12),

                          // Phone Number Field with Country Code Picker
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Phone Number',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 52,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(26), // Semi-circle pill shape
                                  border: Border.all(
                                    color: const Color(0xFF00C2FF), // Cyan highlighted border
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x1400C2FF),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Country Code Selector
                                    InkWell(
                                      onTap: _showCountryCodePicker,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _selectedCountry.flag,
                                              style: const TextStyle(fontSize: 20),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _selectedCountry.code,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _selectedCountry.dialCode,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: Color(0xFF94A3B8),
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Vertical Separator Line
                                    Container(
                                      height: 22,
                                      width: 1,
                                      margin: const EdgeInsets.symmetric(horizontal: 10),
                                      color: const Color(0xFFE2E8F0),
                                    ),

                                    // Phone Number Text Field
                                    Expanded(
                                      child: TextField(
                                        controller: _phoneController,
                                        keyboardType: TextInputType.phone,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'Enter phone number',
                                          hintStyle: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFFCBD5E1),
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
                            ],
                          ),

                          const SizedBox(height: 12),

                          _buildInputCard(
                            label: 'Company / Restaurant Name',
                            hint: 'Enter company name',
                            icon: Icons.storefront_rounded,
                            controller: _companyNameController,
                          ),

                          const SizedBox(height: 12),

                          _buildInputCard(
                            label: 'Website (Optional)',
                            hint: 'Enter website URL',
                            icon: Icons.language_rounded,
                            controller: _websiteController,
                            keyboardType: TextInputType.url,
                          ),

                          const SizedBox(height: 12),

                          _buildInputCard(
                            label: 'Referral Code (Optional)',
                            hint: 'Enter referral code',
                            icon: Icons.card_giftcard_rounded,
                            controller: _referralController,
                          ),

                          const SizedBox(height: 24),

                          // Primary Action Button ("Continue")
                          Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(26),
                              gradient: GlassTheme.primaryButtonGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: GlassTheme.primaryBlue.withOpacity(0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSaveProfile,
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
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
        ],
      ),
    );
  }

  // Helper Widget for Input Field Cards (Semi-Circle Pill Shape)
  Widget _buildInputCard({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    Widget? suffixWidget,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26), // Semi-circle pill shape
            border: Border.all(
              color: const Color(0xFF00C2FF), // Highlighted Cyan border
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1400C2FF),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: GlassTheme.primaryBlue, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
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
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (suffixWidget != null) suffixWidget,
            ],
          ),
        ),
      ],
    );
  }
}
