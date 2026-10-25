import 'package:flutter/material.dart';
import '../../storefront/models/storefront_model.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/database/database_service.dart';

class PromotionalBannerDialog extends StatefulWidget {
  final StorefrontBanner? existingBanner;
  final List<CouponModel> availableCoupons;
  final ValueChanged<StorefrontBanner> onSave;

  const PromotionalBannerDialog({
    super.key,
    this.existingBanner,
    required this.availableCoupons,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    StorefrontBanner? existingBanner,
    required List<CouponModel> availableCoupons,
    required ValueChanged<StorefrontBanner> onSave,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
          child: PromotionalBannerDialog(
            existingBanner: existingBanner,
            availableCoupons: availableCoupons,
            onSave: onSave,
          ),
        ),
      ),
    );
  }

  @override
  State<PromotionalBannerDialog> createState() => _PromotionalBannerDialogState();
}

class _PromotionalBannerDialogState extends State<PromotionalBannerDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _tagController;
  late TextEditingController _headlineController;
  late TextEditingController _subtitleController;
  late TextEditingController _ctaController;
  late TextEditingController _discountController;
  late TextEditingController _imageController;
  late TextEditingController _couponCodeController;

  late int _selectedColorHex;
  late bool _isActive;
  String? _selectedCouponId;

  // Preset curated food photography
  static const List<Map<String, String>> _presetImages = [
    {
      'label': 'Pizza Deluxe',
      'url': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'label': 'Gourmet Burger',
      'url': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'label': 'Paneer Supreme',
      'url': 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'label': 'Combo & Fries',
      'url': 'https://images.unsplash.com/photo-1571407970349-bc81e7e96d47?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'label': 'Biryani Feast',
      'url': 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&w=1200&q=80',
    },
    {
      'label': 'Cafe & Treats',
      'url': 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?auto=format&fit=crop&w=1200&q=80',
    },
  ];

  static const List<int> _colorPresets = [
    0xFFE65100, // Deep Orange
    0xFFD84315, // Flame Red
    0xFFC2185B, // Royal Crimson
    0xFF059669, // Emerald
    0xFF0052FF, // Royal Blue
    0xFFD97706, // Amber
    0xFF7C3AED, // Violet
  ];

  static const List<String> _quickTags = [
    'HOT & CHEESY',
    'SPECIAL OFFER',
    'CHEF SPECIAL',
    'WEEKEND DEAL',
    'BUY 1 GET 1',
    'COMBO SAVER',
  ];

  static const List<String> _quickCtas = [
    'ORDER NOW ➔',
    'GRAB OFFER ➔',
    'VIEW MENU ➔',
    'EXPLORE ➔',
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.existingBanner;
    _tagController = TextEditingController(text: b?.tag ?? 'SPECIAL OFFER');
    _headlineController = TextEditingController(text: b?.headline ?? 'WEEKEND FEAST • FLAT 50% OFF');
    _subtitleController = TextEditingController(text: b?.subtitle ?? 'Fresh Ingredients Bigger Happiness');
    _ctaController = TextEditingController(text: b?.ctaText ?? 'ORDER NOW ➔');
    _discountController = TextEditingController(text: b?.discountText ?? 'FLAT 50% OFF');
    _imageController = TextEditingController(
      text: b?.imageUrl ?? _presetImages.first['url']!,
    );
    _couponCodeController = TextEditingController(text: b?.couponCode ?? '');
    _selectedColorHex = b?.accentColorHex ?? 0xFFE65100;
    _isActive = b?.isActive ?? true;

    // Detect if coupon matches an existing active coupon
    if (b?.couponCode != null && b!.couponCode!.isNotEmpty) {
      final match = widget.availableCoupons.where((c) => c.code.toUpperCase() == b.couponCode!.toUpperCase());
      if (match.isNotEmpty) {
        _selectedCouponId = match.first.id;
      }
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _headlineController.dispose();
    _subtitleController.dispose();
    _ctaController.dispose();
    _discountController.dispose();
    _imageController.dispose();
    _couponCodeController.dispose();
    super.dispose();
  }

  void _onCouponSelected(String? couponId) {
    setState(() {
      _selectedCouponId = couponId;
      if (couponId != null && couponId.isNotEmpty) {
        final coupon = widget.availableCoupons.firstWhere((c) => c.id == couponId);
        _couponCodeController.text = coupon.code;
        if (coupon.discountType == 'percent') {
          _discountController.text = '${coupon.discountValue.toInt()}% OFF';
          _headlineController.text = '${coupon.discountValue.toInt()}% OFF SPECIAL';
        } else {
          _discountController.text = 'FLAT ₹${coupon.discountValue.toInt()} OFF';
          _headlineController.text = 'SAVE ₹${coupon.discountValue.toInt()} ON YOUR ORDER';
        }
        _subtitleController.text = 'Use Code ${coupon.code} at checkout to save!';
      }
    });
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final banner = StorefrontBanner(
      id: widget.existingBanner?.id ?? 'b_${DateTime.now().millisecondsSinceEpoch}',
      tag: _tagController.text.trim().toUpperCase(),
      headline: _headlineController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      ctaText: _ctaController.text.trim(),
      imageUrl: _imageController.text.trim(),
      accentColorHex: _selectedColorHex,
      couponCode: _couponCodeController.text.trim().isNotEmpty ? _couponCodeController.text.trim().toUpperCase() : null,
      discountText: _discountController.text.trim().isNotEmpty ? _discountController.text.trim() : null,
      isActive: _isActive,
      displayOrder: widget.existingBanner?.displayOrder ?? 0,
      createdAt: widget.existingBanner?.createdAt ?? DateTime.now(),
    );

    widget.onSave(banner);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            _buildDialogHeader(),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Live Preview Card
                      _buildLiveBannerPreview(),
                      const SizedBox(height: 14),

                      // Section Title
                      const Text(
                        'BANNER CONTENT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Category Tag Field + Quick Chips
                      _buildFormField(
                        label: 'Category Tag',
                        controller: _tagController,
                        hint: 'e.g. HOT & CHEESY',
                        onChanged: (_) => setState(() {}),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: _quickTags.map((tag) {
                          final isSelected = _tagController.text.trim().toUpperCase() == tag;
                          return InkWell(
                            onTap: () {
                              setState(() => _tagController.text = tag);
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF021B54) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF021B54) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),

                      // Offer Headline Field
                      _buildFormField(
                        label: 'Offer Headline',
                        controller: _headlineController,
                        hint: 'e.g. WEEKEND PIZZA FEST',
                        onChanged: (_) => setState(() {}),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),

                      // Subtitle / Description Field
                      _buildFormField(
                        label: 'Subtitle / Description',
                        controller: _subtitleController,
                        hint: 'e.g. Fresh Hand-Tossed Pizzas & Bigger Happiness',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),

                      // Row: CTA Text & Discount Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'Button CTA Text',
                              controller: _ctaController,
                              hint: 'e.g. ORDER NOW ➔',
                              onChanged: (_) => setState(() {}),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFormField(
                              label: 'Discount Badge',
                              controller: _discountController,
                              hint: 'e.g. FLAT 50% OFF',
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: _quickCtas.map((cta) {
                          final isSelected = _ctaController.text.trim() == cta;
                          return InkWell(
                            onTap: () => setState(() => _ctaController.text = cta),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0052FF) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF0052FF) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              child: Text(
                                cta,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Section Title: LINK COUPON
                      const Text(
                        'LINK EXISTING COUPON (OPTIONAL)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Coupon Selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _selectedCouponId,
                            hint: const Text(
                              'Select a coupon to auto-fill code & discount...',
                              style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('No coupon linked', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                              ),
                              ...widget.availableCoupons.map((c) {
                                return DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFA7F3D0)),
                                        ),
                                        child: Text(
                                          c.code,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${c.title} (${c.discountType == 'percent' ? '${c.discountValue.toInt()}%' : '₹${c.discountValue.toInt()}'} off)',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: _onCouponSelected,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Manual Coupon Code Field
                      _buildFormField(
                        label: 'Promo / Coupon Code Display',
                        controller: _couponCodeController,
                        hint: 'e.g. PIZZA50 (leave empty if none)',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),

                      // Section Title: BACKGROUND & STYLING
                      const Text(
                        'BACKGROUND & COLOR THEME',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Preset Image Selector
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _presetImages.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final preset = _presetImages[index];
                            final isSelected = _imageController.text.trim() == preset['url'];
                            return InkWell(
                              onTap: () {
                                setState(() => _imageController.text = preset['url']!);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 92,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0052FF) : const Color(0xFFE2E8F0),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Image.network(
                                          preset['url']!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      Positioned.fill(
                                        child: Container(
                                          color: Colors.black.withValues(alpha: isSelected ? 0.25 : 0.45),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        right: 4,
                                        child: Text(
                                          preset['label']!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected)
                                        const Positioned(
                                          top: 3,
                                          right: 3,
                                          child: Icon(Icons.check_circle_rounded, color: Color(0xFF0052FF), size: 14),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Image URL input
                      _buildFormField(
                        label: 'Image URL (or select preset above)',
                        controller: _imageController,
                        hint: 'https://...',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),

                      // Accent Color Selector
                      Row(
                        children: [
                          const Text(
                            'Accent Tint:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              children: _colorPresets.map((hex) {
                                final isSelected = _selectedColorHex == hex;
                                return InkWell(
                                  onTap: () => setState(() => _selectedColorHex = hex),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: Color(hex),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.transparent,
                                        width: 2,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: Color(hex).withValues(alpha: 0.5),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: isSelected
                                        ? const Center(
                                            child: Icon(Icons.check, size: 12, color: Colors.white),
                                          )
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Active Switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              size: 16,
                              color: _isActive ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isActive ? 'Published to Customer Storefront' : 'Hidden from Storefront',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: _isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                    ),
                                  ),
                                  Text(
                                    _isActive
                                        ? 'Visible dynamically in customer profile banner carousel'
                                        : 'Banner saved in draft; toggle active to publish',
                                    style: const TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _isActive,
                              activeColor: const Color(0xFF059669),
                              onChanged: (val) => setState(() => _isActive = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer Actions
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF021B54),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.view_carousel_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existingBanner != null ? 'Edit Promotional Banner' : 'Create Promotional Banner',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                Text(
                  'Shows dynamically in customer profile storefront carousel',
                  style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveBannerPreview() {
    final tag = _tagController.text.trim().isNotEmpty ? _tagController.text.trim().toUpperCase() : 'SPECIAL OFFER';
    final headline = _headlineController.text.trim().isNotEmpty ? _headlineController.text.trim() : 'DELICIOUS BITES';
    final subtitle = _subtitleController.text.trim().isNotEmpty
        ? _subtitleController.text.trim()
        : 'Fresh taste crafted with passion';
    final cta = _ctaController.text.trim().isNotEmpty ? _ctaController.text.trim() : 'ORDER NOW ➔';
    final discount = _discountController.text.trim();
    final coupon = _couponCodeController.text.trim();
    final imgUrl = _imageController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LIVE STOREFRONT PREVIEW',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF0052FF), letterSpacing: 0.8),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: _isActive ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _isActive ? '● Live' : '○ Draft',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: _isActive ? const Color(0xFF059669) : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 125,
          decoration: BoxDecoration(
            color: Color(_selectedColorHex),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Color(0x18000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                if (imgUrl.isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Color(_selectedColorHex)),
                    ),
                  ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.72),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB74D),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Color(0xFF7C2D12),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (discount.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                discount,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                          if (coupon.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'CODE: $coupon',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        headline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          cta,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
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
      ],
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required String hint,
    ValueChanged<String>? onChanged,
    FormFieldValidator<String>? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        ),
        const SizedBox(height: 3),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0052FF), width: 1.3)),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052FF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'Save Banner',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
