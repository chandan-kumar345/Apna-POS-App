import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/services/onboarding_service.dart';
import 'business_details_screen.dart';

class ConfirmBusinessNameScreen extends StatefulWidget {
  const ConfirmBusinessNameScreen({super.key});

  @override
  State<ConfirmBusinessNameScreen> createState() => _ConfirmBusinessNameScreenState();
}

class _ConfirmBusinessNameScreenState extends State<ConfirmBusinessNameScreen> {
  late TextEditingController _businessNameController;
  final db = DatabaseService();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Save onboarding step progress (Step 2: Confirm Business Name)
    db.saveOnboardingProgress(route: 'confirm_business_name', step: 2);

    // Dynamic initial business / company name
    final initialName = (db.currentUser?.companyName != null && db.currentUser!.companyName!.trim().isNotEmpty)
        ? db.currentUser!.companyName!.trim()
        : ((db.restaurant?.name != null && db.restaurant!.name.trim().isNotEmpty)
            ? db.restaurant!.name.trim()
            : 'The Sky High');

    _businessNameController = TextEditingController(text: initialName);
    _businessNameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    super.dispose();
  }

  // Dynamic Avatar Photo Builder with Compact Sizing
  Widget _buildDynamicAvatar(String? photoPath, String businessName) {
    if (photoPath != null && photoPath.trim().isNotEmpty) {
      final cleanPath = photoPath.trim();

      // 1. Local File
      if (!cleanPath.contains('_selected') && File(cleanPath).existsSync()) {
        return Image.file(
          File(cleanPath),
          width: 52,
          height: 52,
          fit: BoxFit.cover,
        );
      }

      // 2. Base64 Image
      if (cleanPath.startsWith('data:image') ||
          (cleanPath.length > 50 && !cleanPath.startsWith('http') && !cleanPath.startsWith('/'))) {
        try {
          final cleanBase64 = cleanPath.contains(',') ? cleanPath.split(',').last : cleanPath;
          final bytes = base64Decode(cleanBase64);
          return Image.memory(
            bytes,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(businessName),
          );
        } catch (_) {}
      }

      // 3. Network URL
      if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
        return Image.network(
          cleanPath,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(businessName),
        );
      }
    }

    // Default Fallback Photo / Avatar
    return _buildFallbackAvatar(businessName);
  }

  Widget _buildFallbackAvatar(String name) {
    return Image.network(
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      width: 52,
      height: 52,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF93C5FD), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSaveAndNext() async {
    final newName = _businessNameController.text.trim();
    if (newName.isEmpty) {
      setState(() => _errorMessage = 'Please enter your business / company name');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Update DatabaseService & local state
      await db.updateBusinessName(newName);

      // 2. Update backend profile if user is authenticated
      try {
        final user = db.currentUser;
        if (user != null) {
          await OnboardingService().saveProfile(
            name: user.name.isNotEmpty ? user.name : 'Business Owner',
            phone: user.phone ?? '',
            companyName: newName,
            profileImage: user.profilePhotoPath,
          );
        }
      } catch (_) {}

      // 3. Save progress to next onboarding step (Step 3: Business Details)
      await db.saveOnboardingProgress(route: 'business_details', step: 3);

      if (!mounted) return;

      // 4. Navigate forward to BusinessDetailsScreen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BusinessDetailsScreen()),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Error saving business name: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTypedName = _businessNameController.text.trim().isEmpty
        ? 'The Sky High'
        : _businessNameController.text.trim();

    final userPhotoPath = db.companyLogoPath ?? db.currentUser?.profilePhotoPath;

    final dynamicUserName = (db.currentUser?.name != null && db.currentUser!.name.trim().isNotEmpty)
        ? db.currentUser!.name.trim()
        : 'Rohit Sharma';

    return Scaffold(
      backgroundColor: const Color(0xFF021B54),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              // 1. Top Header on Midnight Navy
              _buildTopHeader(),

              // 2. Curved White Neumorphic Body with Sticky Next Button
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
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
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Error Banner if validation fails
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  margin: const EdgeInsets.only(bottom: 14),
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

                              // SECTION 1: Company Name Text Header (Icon Removed)
                              const Text(
                                'Company Name',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Enter or update your business name',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Compact Neumorphic Input Box
                              Container(
                                height: 52,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F9FD),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0A002870),
                                      blurRadius: 8,
                                      offset: Offset(2, 3),
                                    ),
                                    BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 6,
                                      offset: Offset(-2, -2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Embossed Storefront Icon Container
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0x0A002870),
                                            blurRadius: 4,
                                            offset: const Offset(1, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.storefront_rounded,
                                          color: Color(0xFF0A2560),
                                          size: 19,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    // Editable Company Name TextField
                                    Expanded(
                                      child: TextField(
                                        controller: _businessNameController,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'Enter company name',
                                          hintStyle: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ),

                                    // Clear (x) Button
                                    if (_businessNameController.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _businessNameController.clear();
                                          setState(() {});
                                        },
                                        child: Container(
                                          width: 22,
                                          height: 22,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.close_rounded,
                                              color: Colors.white,
                                              size: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Helper Text Row with (i) Info icon
                              Row(
                                children: const [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 14,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'You can change your company name anytime',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // SECTION 2: Select Profile Card Text Header
                              const Text(
                                'Select Profile Card',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Select profile card for your business',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Compact Selected Profile Card Container
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7FAFF),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFF38BDF8),
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x0C002870),
                                      blurRadius: 10,
                                      offset: Offset(2, 3),
                                    ),
                                    BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 6,
                                      offset: Offset(-2, -2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Dynamic Circular Avatar
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF93C5FD), Color(0xFF3B82F6)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x180066FF),
                                            blurRadius: 6,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: ClipOval(
                                        child: _buildDynamicAvatar(userPhotoPath, currentTypedName),
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    // Details Column
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            currentTypedName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            currentTypedName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            dynamicUserName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    // Compact Neumorphic Checkbox Container with Dark Navy Checkmark
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0x0C002870),
                                            blurRadius: 4,
                                            offset: Offset(1, 2),
                                          ),
                                          BoxShadow(
                                            color: Colors.white,
                                            blurRadius: 4,
                                            offset: Offset(-1, -1),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 26,
                                          height: 26,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Color(0xFF0A2560),
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 15,
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
                        ),
                      ),

                      // Sticky Bottom Action Button ("Next" - Pinned at the bottom of the white card)
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

  // Top Midnight Navy Header with Compact Detailing
  Widget _buildTopHeader() {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Neumorphic Frosted Circular Back Button on top left
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

              const SizedBox(height: 16),

              // Title
              const Text(
                'Add your company name',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.15,
                  letterSpacing: -0.4,
                ),
              ),

              const SizedBox(height: 6),

              // Subtitle
              const Text(
                'Confirm or update your business name for\nApna POS profile',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF94A3B8),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sticky Bottom Action Bar with Pure Centered "Next" Button (Arrow Removed, White Card Integrated)
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
            onPressed: _isLoading ? null : _handleSaveAndNext,
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
                      'Next',
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
