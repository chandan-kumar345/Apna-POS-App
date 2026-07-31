import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import '../dashboard/main_layout.dart';
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
    // Pre-fill with user's companyName or restaurant name
    final initialName = db.currentUser?.companyName ??
        db.restaurant?.name ??
        'Tea Coffee';
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

  Widget _buildProfileCardAvatar(String? photoPath, String typedName) {
    if (photoPath != null && photoPath.isNotEmpty) {
      if (!photoPath.contains('_selected') && File(photoPath).existsSync()) {
        return Image.file(
          File(photoPath),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        );
      } else {
        return Image.network(
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF1F5F9),
            child: Center(
              child: Text(
                typedName.isNotEmpty ? typedName[0].toUpperCase() : 'T',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF00C2FF),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Container(
      color: const Color(0xFFF1F5F9),
      child: Center(
        child: Text(
          typedName.isNotEmpty ? typedName[0].toUpperCase() : 'T',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF00C2FF),
          ),
        ),
      ),
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
      // Save updated business name to database & persistent local storage
      final success = await db.updateBusinessName(newName);

      if (!mounted) return;

      if (success) {
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
                    'Business name updated to "$newName" successfully!',
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

        // Open Business Details Screen (Country, Phone, Currency, Timezone)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BusinessDetailsScreen()),
        );
      } else {
        setState(() => _errorMessage = 'Failed to update business name.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error saving business name: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTypedName = _businessNameController.text.trim().isEmpty
        ? 'Tea Coffee'
        : _businessNameController.text.trim();

    final userPhotoPath = db.currentUser?.profilePhotoPath;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Deep Midnight Background Gradient matching Auth & Profile Screens
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

          // 2. Decorative Glass Background Orbs / Ambient Glow Shapes
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
            top: 160,
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

          // 3. Main Layout Content
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Section on Dark Theme
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Circular Glass Back Button
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

                      const SizedBox(height: 14),

                      // Screen Header Title
                      const Text(
                        'Add your company name',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Text(
                        'Confirm or update your business name for Apna POS profile',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                // 4. White Bottom Curved Card Container matching Auth Theme
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

                                // 1. Company Name Field Label
                                const Text(
                                  'Company Name',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // Semi-Circle Pill Box Field matching Auth Theme
                                Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(26), // Stadium Semi-Circle Pill Shape
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
                                      const Icon(
                                        Icons.storefront_rounded,
                                        color: GlassTheme.primaryBlue,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _businessNameController,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                          decoration: const InputDecoration(
                                            hintText: 'Enter company name',
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

                                const SizedBox(height: 6),

                                const Text(
                                  'you can change your company name anytime',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // 2. Select Profile Card Section
                                const Text(
                                  'Select Profile Card',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),

                                const SizedBox(height: 2),

                                const Text(
                                  'Select profile card for your business',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF64748B),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Profile Card Container (Dynamically updating with typed business name!)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAFAFC),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF00C2FF), // Selected Cyan Border
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x1400C2FF),
                                        blurRadius: 14,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Circular Avatar Photo / Logo
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          border: Border.all(
                                            color: const Color(0xFF00C2FF),
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: _buildProfileCardAvatar(userPhotoPath, currentTypedName),
                                        ),
                                      ),

                                      const SizedBox(width: 14),

                                      // Dynamic Business Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              currentTypedName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              currentTypedName,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF475569),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              (db.currentUser?.name != null && db.currentUser!.name.isNotEmpty)
                                                  ? db.currentUser!.name
                                                  : 'Chandan Yaduvanshi',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF64748B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Green Checkmark Badge
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981), // Emerald Green
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 5. Primary Bottom Action Button ("Next")
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
                              onPressed: _isLoading ? null : _handleSaveAndNext,
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
                                      'Next',
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
