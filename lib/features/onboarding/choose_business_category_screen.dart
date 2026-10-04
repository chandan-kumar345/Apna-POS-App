import 'package:flutter/material.dart';
import '../../core/database/database_service.dart';
import '../../core/services/onboarding_service.dart';
import 'add_business_address_screen.dart';

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
  BusinessGridCategory(title: 'Beauty & Personal Care', icon: '💄', bgColor: Color(0xFFFFF1F2)),
  BusinessGridCategory(title: 'Furniture & Home Decor', icon: '🪑', bgColor: Color(0xFFFEF9C3)),
  BusinessGridCategory(title: 'Building Materials', icon: '🧱', bgColor: Color(0xFFFFF7ED)),
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
    db.saveOnboardingProgress(route: 'choose_category', step: 4);
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

      await db.saveOnboardingProgress(route: 'add_address', step: 5);

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
    final dynamicCompanyName = db.restaurant?.name ??
        db.currentUser?.companyName ??
        'The Sky High';

    final filteredCategories = gridBusinessCategories.where((item) {
      final q = _searchQuery.toLowerCase();
      return item.title.toLowerCase().contains(q);
    }).toList();

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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Static Header Area inside Sheet
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
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

                              // Title Section
                              const Text(
                                'What Do You Sell?',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                              ),

                              const SizedBox(height: 3),

                              const Text(
                                'Select your business category to continue setup',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Neumorphic Inset Search Bar
                              Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5ECF4),
                                  borderRadius: BorderRadius.circular(21),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14002870),
                                      blurRadius: 5,
                                      offset: Offset(1, 2),
                                    ),
                                    BoxShadow(
                                      color: Colors.white,
                                      blurRadius: 5,
                                      offset: Offset(-1, -1),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.search_rounded,
                                      color: Color(0xFF0066FF),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (val) => setState(() => _searchQuery = val),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                        decoration: const InputDecoration(
                                          hintText: 'Search Business Category...',
                                          hintStyle: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF94A3B8),
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
                                          color: Color(0xFF64748B),
                                          size: 16,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Contrastic Neumorphic 3-Column Grid
                        Expanded(
                          child: filteredCategories.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No matching category found',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 0.88,
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
                                        duration: const Duration(milliseconds: 180),
                                        decoration: BoxDecoration(
                                          gradient: isSelected
                                              ? const LinearGradient(
                                                  colors: [Color(0xFFDCE8FD), Color(0xFFEFF5FF)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : const LinearGradient(
                                                  colors: [Color(0xFFFFFFFF), Color(0xFFE9F0F8)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF0066FF)
                                                : Colors.white,
                                            width: isSelected ? 2.0 : 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isSelected
                                                  ? const Color(0x350066FF)
                                                  : const Color(0x14002870),
                                              blurRadius: isSelected ? 10 : 8,
                                              offset: isSelected
                                                  ? const Offset(0, 3)
                                                  : const Offset(3, 4),
                                            ),
                                            BoxShadow(
                                              color: Colors.white,
                                              blurRadius: isSelected ? 6 : 6,
                                              offset: isSelected
                                                  ? const Offset(-2, -2)
                                                  : const Offset(-3, -3),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    // Neumorphic Icon Container
                                                    Container(
                                                      width: 44,
                                                      height: 44,
                                                      decoration: BoxDecoration(
                                                        color: isSelected ? Colors.white : item.bgColor,
                                                        borderRadius: BorderRadius.circular(14),
                                                        border: Border.all(color: Colors.white, width: 1.2),
                                                        boxShadow: const [
                                                          BoxShadow(
                                                            color: Color(0x0C002870),
                                                            blurRadius: 4,
                                                            offset: Offset(1, 2),
                                                          ),
                                                          BoxShadow(
                                                            color: Colors.white,
                                                            blurRadius: 3,
                                                            offset: Offset(-1, -1),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Center(
                                                        child: Text(
                                                          item.icon,
                                                          style: const TextStyle(fontSize: 22),
                                                        ),
                                                      ),
                                                    ),

                                                    const SizedBox(height: 6),

                                                    // Category Title Label
                                                    Text(
                                                      item.title,
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                                        color: isSelected
                                                            ? const Color(0xFF021B54)
                                                            : const Color(0xFF0F172A),
                                                        height: 1.15,
                                                      ),
                                                      textAlign: TextAlign.center,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // Brand Blue Selected Checkmark Badge
                                            if (isSelected)
                                              Positioned(
                                                top: 6,
                                                right: 6,
                                                child: Container(
                                                  padding: const EdgeInsets.all(3),
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF0066FF),
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Color(0x400066FF),
                                                        blurRadius: 4,
                                                        offset: Offset(0, 1),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.check_rounded,
                                                    color: Colors.white,
                                                    size: 11,
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

                        // Sticky Bottom Action Bar with "Continue" Button (Background Box Removed)
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

  // Sticky Bottom Action Bar with Midnight Navy "Continue" Button (Background Removed)
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
            onPressed: _isLoading ? null : _handleSaveCategoryAndNext,
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
                      'Continue',
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
