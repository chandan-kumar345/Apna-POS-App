import 'package:flutter/material.dart';
import '../../core/theme/glass_theme.dart';
import '../../core/database/database_service.dart';
import 'add_business_address_screen.dart';
import '../../core/services/onboarding_service.dart';



class BusinessGridCategory {
  final String title;
  final String icon;
  final Color bgColor;

  const BusinessGridCategory({
    required this.title,
    required this.icon,
    required this.bgColor,
  });
}

const List<BusinessGridCategory> gridBusinessCategories = [
  BusinessGridCategory(title: 'Restaurant', icon: '🏬', bgColor: Color(0xFFFFF1F2)),
  BusinessGridCategory(title: 'Cafe', icon: '☕', bgColor: Color(0xFFFFF7ED)),
  BusinessGridCategory(title: 'Snacks & Beverage', icon: '🍹', bgColor: Color(0xFFFEF3C7)),
  BusinessGridCategory(title: 'Grocery Store', icon: '🛒', bgColor: Color(0xFFECFDF5)),
  BusinessGridCategory(title: 'Retail Store', icon: '🛍️', bgColor: Color(0xFFFDF2F8)),
  BusinessGridCategory(title: 'Fashion & Apparel', icon: '👕', bgColor: Color(0xFFEFF6FF)),
  BusinessGridCategory(title: 'Footwear', icon: '👟', bgColor: Color(0xFFF3F4F6)),
  BusinessGridCategory(title: 'Jewelry', icon: '💎', bgColor: Color(0xFFFFF7ED)),
  BusinessGridCategory(title: 'Watches & Accessories', icon: '⌚', bgColor: Color(0xFFEFF6FF)),
  BusinessGridCategory(title: 'Beauty & Salon', icon: '💄', bgColor: Color(0xFFFFF1F2)),
  BusinessGridCategory(title: 'Furniture & Decor', icon: '🪑', bgColor: Color(0xFFFEF9C3)),
  BusinessGridCategory(title: 'Building Material', icon: '🧱', bgColor: Color(0xFFFFF7ED)),
  BusinessGridCategory(title: 'E-Commerce', icon: '🌐', bgColor: Color(0xFFE0F2FE)),
  BusinessGridCategory(title: 'Electronics', icon: '💻', bgColor: Color(0xFFF0F9FF)),
  BusinessGridCategory(title: 'Books & Stationery', icon: '📚', bgColor: Color(0xFFFEF3C7)),
  BusinessGridCategory(title: 'Pharmacy', icon: '💊', bgColor: Color(0xFFF0FDFA)),
  BusinessGridCategory(title: 'Clinic & Healthcare', icon: '🩺', bgColor: Color(0xFFEFF6FF)),
  BusinessGridCategory(title: 'Sports & Fitness', icon: '⚽', bgColor: Color(0xFFECFDF5)),
  BusinessGridCategory(title: 'Gym & Fitness', icon: '🏋️', bgColor: Color(0xFFF3F4F6)),
  BusinessGridCategory(title: 'Hotel & Hospitality', icon: '🏨', bgColor: Color(0xFFFEF9C3)),
  BusinessGridCategory(title: 'Travel & Tourism', icon: '🧳', bgColor: Color(0xFFE0F2FE)),
  BusinessGridCategory(title: 'Automobile', icon: '🚗', bgColor: Color(0xFFF3F4F6)),
  BusinessGridCategory(title: 'Real Estate', icon: '🏠', bgColor: Color(0xFFFEF2F2)),
  BusinessGridCategory(title: 'Hardware Store', icon: '🔧', bgColor: Color(0xFFF3F4F6)),
  BusinessGridCategory(title: 'Food Delivery', icon: '🛵', bgColor: Color(0xFFFEF2F2)),
  BusinessGridCategory(title: 'Bakery', icon: '🧁', bgColor: Color(0xFFFFF7ED)),
  BusinessGridCategory(title: 'Agriculture', icon: '🌱', bgColor: Color(0xFFF0FDF4)),
  BusinessGridCategory(title: 'Pet Shop', icon: '🐶', bgColor: Color(0xFFFFF7ED)),
  BusinessGridCategory(title: 'Entertainment', icon: '🎬', bgColor: Color(0xFFF3F4F6)),
  BusinessGridCategory(title: 'Services', icon: '⚙️', bgColor: Color(0xFFEFF6FF)),
];

class ChooseBusinessCategoryScreen extends StatefulWidget {
  const ChooseBusinessCategoryScreen({super.key});

  @override
  State<ChooseBusinessCategoryScreen> createState() => _ChooseBusinessCategoryScreenState();
}

class _ChooseBusinessCategoryScreenState extends State<ChooseBusinessCategoryScreen> {
  final db = DatabaseService();

  late TextEditingController _searchController;
  String _searchQuery = '';
  String? _selectedCategory;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedCategory = db.restaurant?.cuisineType ?? 'Restaurant';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveCategoryAndNext() async {
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      setState(() => _errorMessage = 'Please select a business category.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await OnboardingService().saveBusinessDetails(
        country: 'IN',
        currency: 'INR',
        timezone: 'Asia/Kolkata',
        businessType: _selectedCategory!,
        phone: db.currentUser?.phone,
      );

      if (!mounted) return;

      // Open Add Business Address Screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddBusinessAddressScreen()),
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

    final filteredCategories = gridBusinessCategories.where((item) {
      final q = _searchQuery.toLowerCase();
      return item.title.toLowerCase().contains(q);
    }).toList();

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
                // Top Header with Back Button and Business Title
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
                        child: Text(
                          businessTitle,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                                const SizedBox(height: 12),
                              ],

                              // Title Section matching mockup
                              const Text(
                                'What Do You Sell?',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),

                              const SizedBox(height: 2),

                              const Text(
                                'Select your business category to continue setup',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF64748B),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Real-Time Search Bar
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(0xFF00C2FF),
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x1400C2FF),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.search_rounded,
                                      color: Color(0xFF00C2FF),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (val) => setState(() => _searchQuery = val),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'Search Business Category...',
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
                                    if (_searchQuery.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Color(0xFF94A3B8),
                                          size: 18,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // 3D Business Category Grid Cards
                        Expanded(
                          child: filteredCategories.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No matching category found',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 0.92,
                                  ),
                                  itemCount: filteredCategories.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredCategories[index];
                                    final isSelected = _selectedCategory == item.title;

                                    return InkWell(
                                      onTap: () {
                                        setState(() => _selectedCategory = item.title);
                                      },
                                      borderRadius: BorderRadius.circular(18),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFFAFAFC) : Colors.white,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF00C2FF) // Selected Cyan Border
                                                : const Color(0xFFF1F5F9),
                                            width: isSelected ? 2.2 : 1.2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isSelected
                                                  ? const Color(0x2200C2FF)
                                                  : const Color(0x0F000000),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  // 3D Icon Container
                                                  Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      color: item.bgColor,
                                                      borderRadius: BorderRadius.circular(14),
                                                    ),
                                                     child: Center(
                                                       child: item.title == 'Restaurant'
                                                           ? Image.asset(
                                                               'assets/images/restaurant_icon.png',
                                                               width: 32,
                                                               height: 32,
                                                               fit: BoxFit.contain,
                                                               errorBuilder: (_, __, ___) => Text(
                                                                 item.icon,
                                                                 style: const TextStyle(fontSize: 26),
                                                               ),
                                                             )
                                                           : Text(
                                                               item.icon,
                                                               style: const TextStyle(fontSize: 26),
                                                             ),
                                                     ),
                                                  ),

                                                  const SizedBox(height: 8),

                                                  // Category Label
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                                    child: Text(
                                                      item.title,
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                                        color: isSelected
                                                            ? const Color(0xFF00C2FF)
                                                            : const Color(0xFF1E293B),
                                                        height: 1.15,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Green Selected Checkmark Badge
                                            if (isSelected)
                                              Positioned(
                                                top: 6,
                                                right: 6,
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF10B981),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.check_rounded,
                                                    color: Colors.white,
                                                    size: 12,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // 5. Primary Action Button ("Continue")
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
                              onPressed: _isLoading ? null : _handleSaveCategoryAndNext,
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
