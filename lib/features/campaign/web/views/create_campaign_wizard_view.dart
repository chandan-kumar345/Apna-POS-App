import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/campaign_models.dart';
import '../../services/campaign_service.dart';
import '../widgets/campaign_submitted_dialog.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/models/menu_item_model.dart';
import '../../../../core/services/product_service.dart';

/// Campaign Creation & Reward Builder with Claymorphic / Neumorphic UI
/// and Live Reactive Smartphone Preview
class CreateCampaignWizardView extends StatefulWidget {
  final VoidCallback onCancel;
  final ValueChanged<CampaignModel> onCampaignCreated;
  final CampaignTemplateModel? initialTemplate;

  const CreateCampaignWizardView({
    super.key,
    required this.onCancel,
    required this.onCampaignCreated,
    this.initialTemplate,
  });

  @override
  State<CreateCampaignWizardView> createState() => _CreateCampaignWizardViewState();
}

class _CreateCampaignWizardViewState extends State<CreateCampaignWizardView> {
  final CampaignService _campaignService = CampaignService();
  final ProductService _productService = ProductService();
  final DatabaseService _db = DatabaseService();

  // App default brand colors
  static const Color _primaryNavy = Color(0xFF082559);
  static const Color _accentTeal = Color(0xFF10B981);
  static const Color _borderGrey = Color(0xFFCBD5E1);
  static const Color _cardBorder = Color(0xFFE2E8F0);
  static const Color _bgOffWhite = Color(0xFFF8FAFC);

  bool _isLoading = true;
  bool _isSavingDraft = false;
  bool _isPublishing = false;
  String _savedStatus = 'Not saved yet'; // 'Not saved yet' | 'Saved as Draft' | 'Published'
  String? _persistedCampaignId;

  // Phase 1: Order Types Selection
  final List<String> _selectedOrderTypes = ['Delivery', 'Take Away', 'Dine In'];

  // Phase 2: Reward Details
  String _selectedRewardType = 'Flat Cash Discount';
  final List<String> _rewardTypeOptions = [
    'Flat Cash Discount',
    'Percentage Discount',
    'Cashback',
    'Free Product',
    'Buy 1 Get 1 (BOGO)',
  ];

  late TextEditingController _discountValueController;
  String _discountScope = 'whole_bill'; // 'whole_bill' | 'chosen_products'
  final List<MenuItemModel> _selectedProducts = [];
  MenuItemModel? _selectedFreeGiftProduct;

  // Phase 4: Minimum Spend & Maximum Cashback Cap
  bool _hasMinSpend = true;
  late TextEditingController _minSpendController;
  late TextEditingController _maxCashbackController;
  late TextEditingController _campaignTitleController;
  late TextEditingController _descriptionController;

  // Phase 3: Coupon Settings & Validation
  bool _useCustomCouponCode = false;
  late TextEditingController _couponCodeController;
  bool _isCheckingCode = false;
  bool? _isCodeUnique;
  String _codeCheckMessage = '';
  Timer? _debounceTimer;

  // Phase 6: Campaign Scheduling (OFF by default)
  bool _hasSendSchedule = false;
  DateTime _sendDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _sendTime = const TimeOfDay(hour: 10, minute: 0);

  // Phase 7: Campaign Expiry Logic (ON by default)
  bool _hasExpiryDate = true;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));

  // Phase 8: Customer-wise Redemption Limits
  String _redemptionPerCustomer = 'only_once'; // 'only_once' | 'multiple_times'
  late TextEditingController _maxRedemptionsPerCustomerController;

  int _currentStep = 1; // 1: Edit Reward, 2: Edit Theme, 3: Whatsapp Review

  // Step 2: Edit Theme state
  String _bannerImageUrl = 'assets/images/campaign_hero_banner_full.png';
  String _logoUrl = '';
  Color _themeColor = const Color(0xFFE91E63);
  Color _textColor = Colors.white;

  // Step 3: Whatsapp Review state
  String _sendCampaignDisplayName = 'Knowwu'; // 'Loyalty Restaurant' | 'Knowwu'
  String _messageCategory = 'Marketing';
  String _templateLanguage = 'en';
  late TextEditingController _whatsappBodyController;
  late TextEditingController _whatsappFooterController;
  String _headerMediaOption = 'default_media'; // 'default_media', 'custom_media', 'no_media'
  String _customHeaderMediaUrl = '';
  String _interactiveActionsOption = 'all'; // 'none', 'all'
  late TextEditingController _ctaButtonTitleController;
  late TextEditingController _ctaButtonUrlController;
  bool _isSubmittingApproval = false;
  CampaignTemplateModel? _submittedTemplate;

  // Audience & Menu Products (Strictly isolated by business)
  List<AudienceGroupModel> _audienceGroups = [];
  AudienceGroupModel? _selectedGroup;
  List<CampaignChannelModel> _channels = [];
  CampaignChannelModel? _selectedChannel;
  List<MenuItemModel> _menuProducts = [];

  // Product Search and Category Filtering for Chosen Products
  final TextEditingController _productSearchController = TextEditingController();
  String _productSearchQuery = '';
  String _selectedProductCategory = 'All';
  bool _isLoadingProducts = false;

  List<String> get _productCategories {
    final cats = <String>{'All'};
    for (final p in _menuProducts) {
      if (p.category.trim().isNotEmpty) {
        cats.add(p.category.trim());
      }
    }
    return cats.toList();
  }

  List<MenuItemModel> get _filteredProducts {
    return _menuProducts.where((p) {
      final matchesCategory = _selectedProductCategory == 'All' ||
          p.category.trim().toLowerCase() == _selectedProductCategory.trim().toLowerCase();
      final q = _productSearchQuery.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    final tpl = widget.initialTemplate;
    final initialTitle = tpl?.name ?? '🥂 Weekend Special - Flat ₹300 OFF';
    final initialDesc = (tpl?.subtitle.isNotEmpty == true ? tpl!.subtitle : null) ??
        (tpl?.body.isNotEmpty == true ? tpl!.body : null) ??
        'Kick-start the celebrations with guaranteed savings. Enjoy our exclusive dining reward with confidence and joy.';

    _discountValueController = TextEditingController(text: '300');
    _minSpendController = TextEditingController(text: '500');
    _maxCashbackController = TextEditingController(text: '200');
    _campaignTitleController = TextEditingController(text: initialTitle);
    _descriptionController = TextEditingController(text: initialDesc);
    _couponCodeController = TextEditingController(text: 'FLAT300');
    _maxRedemptionsPerCustomerController = TextEditingController(text: '5');
    _whatsappBodyController = TextEditingController(text: initialDesc);
    _whatsappFooterController = TextEditingController(text: '');
    _ctaButtonTitleController = TextEditingController(text: 'Offer details');
    _ctaButtonUrlController = TextEditingController(text: 'https://loyalty.knowwu.me/b/{{1}}');

    // Attach listeners so live preview reacts immediately as user types
    _campaignTitleController.addListener(() => setState(() {}));
    _descriptionController.addListener(() => setState(() {}));
    _discountValueController.addListener(() {
      _syncAutoCouponCodeIfNeeded();
      setState(() {});
    });
    _minSpendController.addListener(() => setState(() {}));
    _maxCashbackController.addListener(() => setState(() {}));
    _couponCodeController.addListener(() {
      if (_useCustomCouponCode) {
        _onCustomCodeChanged(_couponCodeController.text);
      }
      setState(() {});
    });
    _maxRedemptionsPerCustomerController.addListener(() => setState(() {}));
    _whatsappBodyController.addListener(() => setState(() {}));
    _whatsappFooterController.addListener(() => setState(() {}));
    _ctaButtonTitleController.addListener(() => setState(() {}));
    _ctaButtonUrlController.addListener(() => setState(() {}));

    _loadInitialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _discountValueController.dispose();
    _minSpendController.dispose();
    _maxCashbackController.dispose();
    _campaignTitleController.dispose();
    _descriptionController.dispose();
    _couponCodeController.dispose();
    _maxRedemptionsPerCustomerController.dispose();
    _productSearchController.dispose();
    _whatsappBodyController.dispose();
    _whatsappFooterController.dispose();
    _ctaButtonTitleController.dispose();
    _ctaButtonUrlController.dispose();
    super.dispose();
  }

  void _syncAutoCouponCodeIfNeeded() {
    if (!_useCustomCouponCode) {
      final code = _generateAutoCouponCode();
      if (_couponCodeController.text != code) {
        _couponCodeController.text = code;
      }
    }
  }

  String _generateAutoCouponCode() {
    final val = double.tryParse(_discountValueController.text.trim())?.toInt() ?? 300;
    switch (_selectedRewardType) {
      case 'Percentage Discount':
        return 'SAVE$val';
      case 'Cashback':
        return 'CASH$val';
      case 'Free Product':
        return 'FREEGIFT';
      case 'Buy 1 Get 1 (BOGO)':
        return 'BOGO';
      case 'Flat Cash Discount':
      default:
        return 'FLAT$val';
    }
  }

  void _onCustomCodeChanged(String text) {
    _debounceTimer?.cancel();
    final clean = text.trim().toUpperCase();
    if (clean.isEmpty) {
      setState(() {
        _isCheckingCode = false;
        _isCodeUnique = null;
        _codeCheckMessage = '';
      });
      return;
    }

    setState(() {
      _isCheckingCode = true;
      _codeCheckMessage = 'Checking availability...';
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final isUnique = await _campaignService.checkCouponCode(
        clean,
        campaignId: _persistedCampaignId,
      );
      if (mounted) {
        setState(() {
          _isCheckingCode = false;
          _isCodeUnique = isUnique;
          _codeCheckMessage = isUnique ? 'Coupon code is available' : 'Code already taken by another campaign/coupon';
        });
      }
    });
  }

  Future<void> _loadProducts({bool forceRefresh = false}) async {
    if (mounted) setState(() => _isLoadingProducts = true);

    List<MenuItemModel> products = [];

    // 1. Check in-memory / local DatabaseService if already loaded in POS
    if (_db.menuItems.isNotEmpty && !forceRefresh) {
      products = List.from(_db.menuItems);
    }

    // 2. Fetch from ProductService.fetchPosProducts (cloud POS catalog)
    if (products.isEmpty || forceRefresh) {
      try {
        final posProds = await _productService.fetchPosProducts(
          limit: 500,
          forceRefresh: forceRefresh,
        );
        if (posProds.isNotEmpty) {
          products = posProds;
        }
      } catch (e) {
        debugPrint('[CreateCampaignWizardView] fetchPosProducts notice: $e');
      }
    }

    // 3. Fallback: try regular fetchProducts API
    if (products.isEmpty) {
      try {
        final prods = await _productService.fetchProducts(limit: 500);
        if (prods.isNotEmpty) {
          products = prods;
        }
      } catch (e) {
        debugPrint('[CreateCampaignWizardView] fetchProducts notice: $e');
      }
    }

    // 4. Fallback: trigger DatabaseService sync with backend
    if (products.isEmpty) {
      try {
        await _db.syncWithBackend();
        if (_db.menuItems.isNotEmpty) {
          products = List.from(_db.menuItems);
        }
      } catch (e) {
        debugPrint('[CreateCampaignWizardView] db.syncWithBackend notice: $e');
      }
    }

    // 5. Final fallback to _db.menuItems
    if (products.isEmpty && _db.menuItems.isNotEmpty) {
      products = List.from(_db.menuItems);
    }

    // Deduplicate items cleanly
    final seen = <String>{};
    final uniqueProducts = <MenuItemModel>[];
    for (final p in products) {
      final key = (p.id.isNotEmpty ? p.id : p.name).trim().toLowerCase();
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueProducts.add(p);
      }
    }

    if (mounted) {
      setState(() {
        _menuProducts = uniqueProducts;
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      // 1. Resiliently fetch audience groups without blocking
      _audienceGroups = await _campaignService.fetchAudienceGroups().catchError((e) {
        debugPrint('[CreateCampaignWizardView] fetchAudienceGroups notice: $e');
        return <AudienceGroupModel>[];
      });
      if (_audienceGroups.isNotEmpty) {
        _selectedGroup = _audienceGroups.first;
      }

      // 2. Resiliently fetch channels without blocking
      _channels = await _campaignService.fetchChannels().catchError((e) {
        debugPrint('[CreateCampaignWizardView] fetchChannels notice: $e');
        return <CampaignChannelModel>[];
      });
      if (_channels.isNotEmpty) {
        _selectedChannel = _channels.first;
      }

      // 3. Load menu products with multi-tier fallback (POS Cache, SQLite, Cloud API)
      await _loadProducts();

      _syncAutoCouponCodeIfNeeded();
    } catch (e) {
      debugPrint('[CreateCampaignWizardView] _loadInitialData notice: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // VALIDATION HELPER
  // =========================================================================
  String? _validateForm() {
    final title = _campaignTitleController.text.trim();
    if (title.isEmpty) return 'Please enter a Campaign Title';

    if (_selectedRewardType == 'Percentage Discount') {
      final perc = double.tryParse(_discountValueController.text.trim());
      if (perc == null || perc <= 0 || perc > 100) {
        return 'Please enter a valid discount percentage between 1% and 100%';
      }
    } else if (_selectedRewardType == 'Flat Cash Discount') {
      final amt = double.tryParse(_discountValueController.text.trim());
      if (amt == null || amt <= 0) {
        return 'Please enter a valid cash discount amount';
      }
    } else if (_selectedRewardType == 'Cashback') {
      final cashVal = double.tryParse(_discountValueController.text.trim());
      if (cashVal == null || cashVal <= 0) {
        return 'Please enter a valid cashback percentage or amount';
      }
      final cap = double.tryParse(_maxCashbackController.text.trim());
      if (cap == null || cap <= 0) {
        return 'Please configure a Maximum Cashback Cap';
      }
    } else if (_selectedRewardType == 'Free Product') {
      if (_selectedFreeGiftProduct == null) {
        return 'Please select a complimentary product to gift';
      }
    }

    if (_discountScope == 'chosen_products' && _selectedProducts.isEmpty) {
      return 'Please choose at least one product for the "Chosen products" reward scope';
    }

    if (_useCustomCouponCode) {
      final code = _couponCodeController.text.trim();
      if (code.isEmpty) return 'Please enter a custom coupon code';
      if (_isCodeUnique == false) return 'Coupon code "$code" is already taken. Please choose another.';
    }

    if (_hasMinSpend) {
      final minSpend = double.tryParse(_minSpendController.text.trim());
      if (minSpend == null || minSpend < 0) {
        return 'Please enter a valid minimum spend amount';
      }
    }

    if (_redemptionPerCustomer == 'multiple_times') {
      final maxCount = int.tryParse(_maxRedemptionsPerCustomerController.text.trim());
      if (maxCount == null || maxCount < 1) {
        return 'Please enter a valid maximum redemption count (at least 1)';
      }
    }

    return null;
  }

  // =========================================================================
  // SAVE DRAFT ACTION
  // =========================================================================
  Future<void> _saveDraft() async {
    final title = _campaignTitleController.text.trim().isNotEmpty
        ? _campaignTitleController.text.trim()
        : 'Weekend Special Offer';

    setState(() => _isSavingDraft = true);

    final reward = CampaignRewardDetailsModel(
      rewardType: _mapRewardTypeToKey(_selectedRewardType),
      discountAmount: double.tryParse(_discountValueController.text.trim()) ?? 300.0,
      discountScope: _discountScope,
      chosenProducts: _selectedProducts.map((p) => {'id': p.id, 'productId': p.id, 'name': p.name, 'price': p.price}).toList(),
      freeGiftProductId: _selectedFreeGiftProduct?.id ?? '',
      freeGiftProductName: _selectedFreeGiftProduct?.name ?? '',
      freeGiftProductPrice: _selectedFreeGiftProduct?.price ?? 0.0,
      hasMinSpend: _hasMinSpend,
      minSpendAmount: double.tryParse(_minSpendController.text.trim()) ?? 500.0,
      maxCashbackCap: double.tryParse(_maxCashbackController.text.trim()) ?? 200.0,
      campaignTitle: title,
      description: _descriptionController.text.trim(),
      termsAndConditions: _buildTermsList(),
    );

    final coupon = CampaignCouponSettingsModel(
      useCustomCouponCode: _useCustomCouponCode,
      customCouponCode: _useCustomCouponCode ? _couponCodeController.text.trim().toUpperCase() : '',
      couponCode: _couponCodeController.text.trim().toUpperCase(),
      hasSendSchedule: _hasSendSchedule,
      sendDate: _sendDate,
      sendTime: '${_sendTime.hourOfPeriod}:${_sendTime.minute.toString().padLeft(2, "0")} ${_sendTime.period == DayPeriod.am ? "AM" : "PM"}',
      scheduledAt: _hasSendSchedule ? DateTime(_sendDate.year, _sendDate.month, _sendDate.day, _sendTime.hour, _sendTime.minute) : null,
      hasExpiryDate: _hasExpiryDate,
      expiryDate: _hasExpiryDate ? _expiryDate : null,
      redemptionPerCustomer: _redemptionPerCustomer,
      maxRedemptionsPerCustomer: int.tryParse(_maxRedemptionsPerCustomerController.text.trim()) ?? 1,
      displayCouponInProfile: false,
    );

    final audience = CampaignAudienceModel(
      source: 'group',
      groupName: _selectedGroup?.name ?? 'All Customers',
      recipientCount: _selectedGroup?.count ?? 320,
    );

    final channel = _selectedChannel ?? const CampaignChannelModel();
    final template = _submittedTemplate ?? widget.initialTemplate ??
        CampaignTemplateModel(
          id: 'custom_reward_tpl',
          name: title,
          body: _descriptionController.text.trim(),
        );

    CampaignModel? result;
    if (_persistedCampaignId != null) {
      result = await _campaignService.updateCampaign(_persistedCampaignId!, {
        'name': title,
        'status': 'draft',
        'rewardDetails': reward.toJson(),
        'couponSettings': coupon.toJson(),
        'orderTypes': _selectedOrderTypes.map((e) => e.toLowerCase().replaceAll(' ', '_')).toList(),
      });
    } else {
      result = await _campaignService.createCampaign(
        name: title,
        type: 'marketing',
        status: 'draft',
        audience: audience,
        channel: channel,
        template: template,
        scheduleMode: _hasSendSchedule ? 'later' : 'now',
        scheduledAt: _sendDate,
        rewardDetails: reward,
        couponSettings: coupon,
        orderTypes: _selectedOrderTypes.map((e) => e.toLowerCase().replaceAll(' ', '_')).toList(),
      );
    }

    if (mounted) {
      setState(() {
        _isSavingDraft = false;
        if (result != null) {
          _persistedCampaignId = result.id;
          _savedStatus = 'Saved as Draft';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Campaign draft saved successfully in database!'),
          backgroundColor: Color(0xFF15803D),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  

  List<String> _buildTermsList() {
    return [
      if (_hasMinSpend) 'Minimum purchase of ₹${_minSpendController.text.trim()} required.',
      '2 offers cannot be clubbed.',
      if (_selectedOrderTypes.isNotEmpty) 'Valid on ${_selectedOrderTypes.join(", ")}.',
      if (_redemptionPerCustomer == 'only_once')
        'Valid once per customer.'
      else
        'Max ${_maxRedemptionsPerCustomerController.text.trim()} redemptions per customer.',
      if (_hasExpiryDate) 'Valid until ${DateFormat("dd MMM yyyy").format(_expiryDate)}.',
    ];
  }

  String _mapRewardTypeToKey(String label) {
    switch (label) {
      case 'Percentage Discount':
        return 'percent_discount';
      case 'Cashback':
        return 'cashback';
      case 'Free Product':
        return 'free_gift';
      case 'Buy 1 Get 1 (BOGO)':
        return 'bogo';
      case 'Flat Cash Discount':
      default:
        return 'flat_discount';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primaryNavy),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgOffWhite,
      body: Column(
        children: [
          // 1. Top Header Bar (Matching Image 2)
          _buildTopHeaderBar(),

          // 2. Main Content Split: Left (Live Phone Preview) & Right (Claymorphic Forms)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1380),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 960;
                      final phonePreview = _currentStep == 3
                          ? _buildWhatsappPhonePreviewColumn()
                          : _buildLeftPhonePreviewColumn();
                      final configForm = _currentStep == 1
                          ? _buildRightConfigurationForm()
                          : (_currentStep == 2
                              ? _buildThemeConfigurationForm()
                              : _buildWhatsappReviewConfigurationForm());

                      if (!isWide) {
                        return Column(
                          children: [
                            phonePreview,
                            const SizedBox(height: 24),
                            configForm,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side: Realistic Phone Mockup
                          SizedBox(
                            width: 380,
                            child: phonePreview,
                          ),
                          const SizedBox(width: 28),

                          // Right side: Neumorphic/Claymorphic Form Cards
                          Expanded(
                            child: configForm,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. TOP HEADER BAR (Claymorphic & SaaS Dashboard Styling)
  // =========================================================================
  Widget _buildTopHeaderBar() {
    String headerTitle = 'Edit Reward';
    String savedBadgeText = _savedStatus;
    if (_currentStep == 1) {
      headerTitle = 'Edit Reward';
      savedBadgeText = _savedStatus == 'Saved as Draft'
          ? 'Saved Reward at ${DateFormat("h:mm").format(DateTime.now())}'
          : (_savedStatus == 'Published' ? 'Published' : 'Saved Reward at ${DateFormat("h:mm").format(DateTime.now())}');
    } else if (_currentStep == 2) {
      headerTitle = 'Edit Theme';
      savedBadgeText = 'Saved Reward at ${DateFormat("h:mm").format(DateTime.now())}';
    } else if (_currentStep == 3) {
      headerTitle = 'Whatsapp Review';
      savedBadgeText = 'Saved Theme at ${DateFormat("h:mm").format(DateTime.now())}';
    }

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _cardBorder)),
        boxShadow: [
          BoxShadow(
            color: Color(0x05000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button + Title
          InkWell(
            onTap: () {
              if (_currentStep == 1) {
                widget.onCancel();
              } else if (_currentStep == 2) {
                setState(() => _currentStep = 1);
              } else if (_currentStep == 3) {
                setState(() => _currentStep = 2);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF0F172A)),
                  const SizedBox(width: 8),
                  Text(
                    headerTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Saved Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: Color(0xFF15803D),
                ),
                const SizedBox(width: 5),
                Text(
                  savedBadgeText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Save Draft Button
          OutlinedButton(
            onPressed: _isSavingDraft || _isPublishing || _isSubmittingApproval ? null : _saveDraft,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryNavy,
              side: const BorderSide(color: _primaryNavy, width: 1.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: _isSavingDraft
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _primaryNavy),
                  )
                : const Text(
                    'Save Draft',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
          ),
          const SizedBox(width: 10),

          // Next / Submit for Approval Button
          ElevatedButton(
            onPressed: _isSavingDraft || _isPublishing || _isSubmittingApproval
                ? null
                : () {
                    if (_currentStep == 1) {
                      final error = _validateForm();
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error), backgroundColor: const Color(0xFFDC2626)),
                        );
                        return;
                      }
                      setState(() => _currentStep = 2);
                    } else if (_currentStep == 2) {
                      _syncWhatsappTemplateDefaults();
                      setState(() => _currentStep = 3);
                    } else if (_currentStep == 3) {
                      _submitForMetaApproval();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            child: _isSubmittingApproval
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    children: [
                      Text(
                        _currentStep == 3 ? 'Submit for Approval' : 'Next',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. LEFT COLUMN: REALISTIC SMARTPHONE PREVIEW (Matching Image 2)
  // =========================================================================
  Widget _buildLeftPhonePreviewColumn() {
    final restName = (_db.restaurant?.name != null && _db.restaurant!.name.isNotEmpty)
        ? _db.restaurant!.name
        : ((_db.currentUser?.companyName != null && _db.currentUser!.companyName!.isNotEmpty)
            ? _db.currentUser!.companyName!
            : 'Apna Restaurant');

    final discountVal = _discountValueController.text.trim().isNotEmpty
        ? _discountValueController.text.trim()
        : '300';

    String discountBadgeText;
    switch (_selectedRewardType) {
      case 'Percentage Discount':
        final cap = _maxCashbackController.text.trim();
        discountBadgeText = cap.isNotEmpty ? '$discountVal% OFF (Up to ₹$cap)' : '$discountVal% OFF';
        break;
      case 'Cashback':
        final cap = _maxCashbackController.text.trim();
        discountBadgeText = cap.isNotEmpty ? '$discountVal% Cashback (Up to ₹$cap)' : '$discountVal% Cashback';
        break;
      case 'Free Product':
        discountBadgeText = 'FREE: ${_selectedFreeGiftProduct?.name ?? "Complimentary Item"}';
        break;
      case 'Buy 1 Get 1 (BOGO)':
        discountBadgeText = 'Buy 1 Get 1 FREE';
        break;
      case 'Flat Cash Discount':
      default:
        discountBadgeText = 'Flat ₹$discountVal OFF';
    }

    final campaignTitle = _campaignTitleController.text.trim().isNotEmpty
        ? _campaignTitleController.text.trim()
        : 'New Year Special - Flat ₹300 OFF';

    final campaignDesc = _descriptionController.text.trim().isNotEmpty
        ? _descriptionController.text.trim()
        : 'Kick-start your shopping with guaranteed savings. Get our exclusive reward and enjoy premium dining!';

    final couponCode = _couponCodeController.text.trim().isNotEmpty
        ? _couponCodeController.text.trim().toUpperCase()
        : 'FLAT300';

    return Center(
      child: Container(
        width: 330,
        height: 680,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(42),
          border: Border.all(color: const Color(0xFF334155), width: 5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(37),
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: Column(
              children: [
                // Phone Status Bar & Dynamic Island
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '9:41',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Container(
                        width: 86,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.signal_cellular_4_bar_rounded, size: 12, color: Color(0xFF0F172A)),
                          SizedBox(width: 4),
                          Icon(Icons.wifi_rounded, size: 12, color: Color(0xFF0F172A)),
                          SizedBox(width: 4),
                          Icon(Icons.battery_5_bar_rounded, size: 13, color: Color(0xFF0F172A)),
                        ],
                      ),
                    ],
                  ),
                ),

                // In-App Header & Voucher View
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Restaurant profile bar
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: _currentStep == 2 ? _showChangeLogoDialog : null,
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: _primaryNavy,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: _cardBorder),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: _logoUrl.isNotEmpty
                                          ? (_logoUrl.startsWith('http')
                                              ? Image.network(_logoUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => const Icon(Icons.storefront_rounded, size: 20, color: Colors.white))
                                              : Image.asset(_logoUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => const Icon(Icons.storefront_rounded, size: 20, color: Colors.white)))
                                          : const Center(
                                              child: Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
                                            ),
                                    ),
                                    if (_currentStep == 2)
                                      Positioned(
                                        right: -2,
                                        bottom: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: _primaryNavy,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.edit, size: 8, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  restName,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Promotional Banner
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: InkWell(
                            onTap: _currentStep == 2 ? _showChangeBannerDialog : null,
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: SizedBox(
                                    height: 130,
                                    width: double.infinity,
                                    child: _bannerImageUrl.startsWith('http')
                                        ? Image.network(
                                            _bannerImageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, st) => Container(
                                              color: const Color(0xFF0C464C),
                                              child: const Center(
                                                child: Icon(Icons.restaurant_rounded, size: 40, color: Color(0xFF2DD4BF)),
                                              ),
                                            ),
                                          )
                                        : Image.asset(
                                            _bannerImageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, err, st) => Container(
                                              color: const Color(0xFF0C464C),
                                              child: const Center(
                                                child: Icon(Icons.restaurant_rounded, size: 40, color: Color(0xFF2DD4BF)),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                if (_currentStep == 2)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                                          SizedBox(width: 4),
                                          Text('Change', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Vibrant Reward Voucher Card (Styled with _themeColor and _textColor)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _themeColor, _themeColor.withValues(alpha: 0.85),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: _themeColor.withValues(alpha: 0.35),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badge & Campaign Title
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('🥂 ', style: TextStyle(fontSize: 18)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              discountBadgeText,
                                              style: TextStyle(
                                                color: _themeColor,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            campaignTitle,
                                            style: TextStyle(
                                              color: _textColor,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              height: 1.25,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Description
                                Text(
                                  campaignDesc,
                                  style: TextStyle(
                                    color: _textColor.withValues(alpha: 0.92),
                                    fontSize: 11,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Dotted / subtle divider
                                Divider(color: _textColor.withValues(alpha: 0.25), height: 1),
                                const SizedBox(height: 10),

                                // Terms & Conditions section
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: _textColor.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.verified_outlined, size: 12, color: _textColor),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Terms & conditions',
                                      style: TextStyle(
                                        color: _textColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (_hasMinSpend)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                                    child: Text(
                                      '✓ Minimum purchase of ₹${_minSpendController.text.trim()} required.',
                                      style: TextStyle(color: _textColor.withValues(alpha: 0.9), fontSize: 10.5),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                                  child: Text(
                                    '✓ 2 offers cannot be clubbed.',
                                    style: TextStyle(color: _textColor.withValues(alpha: 0.9), fontSize: 10.5),
                                  ),
                                ),
                                if (_selectedOrderTypes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                                    child: Text(
                                      '✓ Valid on: ${_selectedOrderTypes.join(", ")}',
                                      style: TextStyle(color: _textColor.withValues(alpha: 0.9), fontSize: 10.5),
                                    ),
                                  ),
                                if (_hasExpiryDate)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                                    child: Text(
                                      '✓ Valid until ${DateFormat("dd MMM yyyy").format(_expiryDate)}',
                                      style: TextStyle(color: _textColor.withValues(alpha: 0.9), fontSize: 10.5),
                                    ),
                                  ),

                                const SizedBox(height: 12),
                                // Coupon Code Box
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.confirmation_num_outlined, size: 14, color: _themeColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        'CODE: $couponCode',
                                        style: TextStyle(
                                          color: _themeColor,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 2B. LEFT COLUMN: REALISTIC WHATSAPP PHONE PREVIEW (Matching Image 2)
  // =========================================================================
  Widget _buildWhatsappPhonePreviewColumn() {
    final senderName = _sendCampaignDisplayName == 'Knowwu'
        ? 'Knowwu'
        : ((_db.restaurant?.name != null && _db.restaurant!.name.isNotEmpty)
            ? _db.restaurant!.name
            : 'Loyalty Restaurant');

    final discountVal = _discountValueController.text.trim().isNotEmpty
        ? _discountValueController.text.trim()
        : '150';
    final coupon = _couponCodeController.text.trim().isNotEmpty
        ? _couponCodeController.text.trim().toUpperCase()
        : 'KNOV2210';
    final expiry = DateFormat('dd/MM/yyyy').format(_expiryDate);

    final rawBody = _whatsappBodyController.text.trim().isNotEmpty
        ? _whatsappBodyController.text.trim()
        : 'We appreciate having you with us! Enjoy flat Rs. $discountVal OFF on your next order with code $coupon. Valid until $expiry. Order now:';

    final previewBody = rawBody
        .replaceAll('{{1}}', 'Rahul')
        .replaceAll('{{2}}', '₹$discountVal')
        .replaceAll('{{3}}', coupon)
        .replaceAll('{{4}}', expiry);

    final footerText = _whatsappFooterController.text.trim();
    final buttonTitle = _ctaButtonTitleController.text.trim().isNotEmpty
        ? _ctaButtonTitleController.text.trim()
        : 'Offer details';

    return Center(
      child: Container(
        width: 330,
        height: 680,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(42),
          border: Border.all(color: const Color(0xFF334155), width: 5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(37),
          child: Container(
            color: const Color(0xFFECE5DD),
            child: Column(
              children: [
                // Phone Status Bar & Dynamic Island
                Container(
                  color: const Color(0xFF008069),
                  padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '9:41',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      Container(
                        width: 86,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.signal_cellular_4_bar_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Icon(Icons.wifi_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Icon(Icons.battery_5_bar_rounded, size: 13, color: Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),

                // WhatsApp Top App Bar (Green)
                Container(
                  color: const Color(0xFF008069),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 6),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Color(0xFF128C7E),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.storefront_rounded, size: 18, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    senderName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2DD4BF)),
                              ],
                            ),
                            const Text(
                              'Official Business Account',
                              style: TextStyle(
                                color: Color(0xFFE0F2FE),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.videocam_rounded, size: 18, color: Colors.white),
                      const SizedBox(width: 12),
                      const Icon(Icons.call_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 10),
                      const Icon(Icons.more_vert_rounded, size: 18, color: Colors.white),
                    ],
                  ),
                ),

                // Chat Canvas
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Bubble
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x10000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Text(
                              'TODAY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF54656F),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Incoming WhatsApp Message Bubble
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
                              bottomRight: Radius.circular(14),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x15000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Media
                              if (_headerMediaOption != 'no_media') ...[
                                SizedBox(
                                  height: 135,
                                  width: double.infinity,
                                  child: (_headerMediaOption == 'default_media'
                                          ? _bannerImageUrl
                                          : (_customHeaderMediaUrl.isNotEmpty ? _customHeaderMediaUrl : _bannerImageUrl))
                                      .startsWith('http')
                                      ? Image.network(
                                          _headerMediaOption == 'default_media'
                                              ? _bannerImageUrl
                                              : (_customHeaderMediaUrl.isNotEmpty ? _customHeaderMediaUrl : _bannerImageUrl),
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, st) => Container(
                                            color: const Color(0xFF0C464C),
                                            child: const Center(
                                              child: Icon(Icons.restaurant_rounded, size: 40, color: Color(0xFF2DD4BF)),
                                            ),
                                          ),
                                        )
                                      : Image.asset(
                                          _bannerImageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, st) => Container(
                                            color: const Color(0xFF0C464C),
                                            child: const Center(
                                              child: Icon(Icons.restaurant_rounded, size: 40, color: Color(0xFF2DD4BF)),
                                            ),
                                          ),
                                        ),
                                ),
                              ],

                              // Body & Footer
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      previewBody,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    if (footerText.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        footerText,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: Color(0xFF8696A0),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          DateFormat('h:mm a').format(DateTime.now()),
                                          style: const TextStyle(fontSize: 9.5, color: Color(0xFF8696A0)),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.done_all_rounded, size: 13, color: Color(0xFF53BDEB)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Interactive CTA Button
                              if (_interactiveActionsOption == 'all') ...[
                                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  color: Colors.white,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.card_giftcard_rounded, size: 15, color: Color(0xFF00A884)),
                                      const SizedBox(width: 6),
                                      Text(
                                        buttonTitle,
                                        style: const TextStyle(
                                          color: Color(0xFF00A884),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF00A884)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 3. RIGHT COLUMN: CLAYMORPHIC / NEUMORPHIC CONFIGURATION FORM
  // =========================================================================
  Widget _buildRightConfigurationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section A: Order Types Selection
        _buildOrderTypesCard(),
        const SizedBox(height: 18),

        // Section B: Offer & Reward Details (Fixed interactive selector + dynamic fields)
        _buildOfferDetailsCard(),
        const SizedBox(height: 18),

        // Section C: Favorite Coupon Code (Toggle Custom vs Auto-Generate)
        _buildCouponSettingsCard(),
        const SizedBox(height: 18),

        // Section D: Campaign Send Date & Time (Schedule toggle OFF by default)
        _buildScheduleSettingsCard(),
        const SizedBox(height: 18),

        // Section E: Campaign Expires Date
        _buildExpirySettingsCard(),
        const SizedBox(height: 18),

        // Section F: Redemption Per Customer (Only Once vs Multiple Times)
        _buildRedemptionRulesCard(),
        const SizedBox(height: 36),
      ],
    );
  }

  // Helper for claymorphic card styling
  Widget _buildNeumorphicCard({
    required Widget child,
    Color color = Colors.white,
    Border? border,
    EdgeInsetsGeometry padding = const EdgeInsets.all(22),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: border ?? Border.all(color: _cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
          BoxShadow(
            color: Color(0x05000000),
            offset: Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: child,
    );
  }

  // -------------------------------------------------------------------------
  // CARD 1: SELECT MARKETING CHANNELS & ORDER TYPES (Phase 1)
  // -------------------------------------------------------------------------
  Widget _buildOrderTypesCard() {
    return _buildNeumorphicCard(
      color: const Color(0xFFF0FDF4),
      border: Border.all(color: const Color(0xFF34D399), width: 1.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Marketing channels',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose order type selection',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildOrderTypeButton('Delivery'),
                    _buildOrderTypeButton('Take Away'),
                    _buildOrderTypeButton('Dine In'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTypeButton(String type) {
    final isSelected = _selectedOrderTypes.contains(type);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            if (_selectedOrderTypes.length > 1) {
              _selectedOrderTypes.remove(type);
            }
          } else {
            _selectedOrderTypes.add(type);
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primaryNavy : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? _primaryNavy : _borderGrey,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 5),
            ],
            Text(
              type,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CARD 2: OFFER & REWARD DETAILS (Phase 2 & 4)
  // -------------------------------------------------------------------------
  Widget _buildOfferDetailsCard() {
    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Here's what the campaign is all about",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Configure your reward type and dynamic parameters below.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 18),

          // 1. Tactile Reward Type Selector (Options clearly visible!)
          const Text(
            'Select reward type',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 10),
          _buildRewardTypeTiles(),
          const SizedBox(height: 20),

          // 2. Dynamic Input Fields based on selected reward type
          _buildDynamicRewardInputs(),
          const SizedBox(height: 18),

          // 3. Whole Bill vs Chosen Products Toggle (Phase 3)
          const Text(
            'Reward Application Scope',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _discountScope = 'whole_bill'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _discountScope == 'whole_bill' ? _primaryNavy : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _discountScope == 'whole_bill' ? _primaryNavy : _borderGrey,
                        width: _discountScope == 'whole_bill' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_discountScope == 'whole_bill') ...[
                          const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          'Whole bill',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _discountScope == 'whole_bill' ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _discountScope = 'chosen_products'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _discountScope == 'chosen_products' ? _primaryNavy : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _discountScope == 'chosen_products' ? _primaryNavy : _borderGrey,
                        width: _discountScope == 'chosen_products' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_discountScope == 'chosen_products') ...[
                          const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          'Chosen products',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _discountScope == 'chosen_products' ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_discountScope == 'chosen_products') ...[
            const SizedBox(height: 14),
            _buildProductSelectorSection(),
          ],
          const SizedBox(height: 20),

          // 4. Set Minimum Spend Checkbox & Amount (Phase 4)
          Row(
            children: [
              Checkbox(
                value: _hasMinSpend,
                activeColor: _primaryNavy,
                onChanged: (val) => setState(() => _hasMinSpend = val ?? true),
              ),
              const Expanded(
                child: Text(
                  'Set minimum spend for redemption',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          if (_hasMinSpend) ...[
            const Padding(
              padding: EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                'Define the lowest eligible cart purchase required to redeem this coupon.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
            TextField(
              controller: _minSpendController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: '500',
                prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 16, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Customer message on low cart: "Add products worth ₹${_minSpendController.text.trim()} or more to redeem this coupon."',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF059669)),
            ),
            const SizedBox(height: 16),
          ],

          // 5. Campaign Title
          const Text('Campaign title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: _campaignTitleController,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: '🥂 Weekend Special - Flat ₹300 OFF',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),

          // 6. Description
          const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.35),
            decoration: InputDecoration(
              hintText: 'Enter a clear description of the offer for your customers...',
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  // Tactile Claymorphic Reward Tiles (Phase 2)
  Widget _buildRewardTypeTiles() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _rewardTypeOptions.map((opt) {
            final isSelected = _selectedRewardType == opt;
            IconData icon;
            String subtitle;

            switch (opt) {
              case 'Percentage Discount':
                icon = Icons.percent_rounded;
                subtitle = '% off order total';
                break;
              case 'Cashback':
                icon = Icons.account_balance_wallet_outlined;
                subtitle = 'Wallet cashback reward';
                break;
              case 'Free Product':
                icon = Icons.card_giftcard_rounded;
                subtitle = 'Complimentary gift item';
                break;
              case 'Buy 1 Get 1 (BOGO)':
                icon = Icons.local_offer_outlined;
                subtitle = 'Buy item & get 1 free';
                break;
              case 'Flat Cash Discount':
              default:
                icon = Icons.currency_rupee_rounded;
                subtitle = 'Fixed ₹ cash deduction';
            }

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedRewardType = opt;
                  _syncAutoCouponCodeIfNeeded();
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: constraints.maxWidth > 500 ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _primaryNavy : _borderGrey,
                    width: isSelected ? 1.8 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? const [
                          BoxShadow(color: Color(0x14082559), offset: Offset(0, 3), blurRadius: 8),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryNavy : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              color: isSelected ? _primaryNavy : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded, size: 18, color: _accentTeal),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Progressive Disclosure: Dynamic fields per reward type
  Widget _buildDynamicRewardInputs() {
    if (_selectedRewardType == 'Percentage Discount') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Discount Percentage (%)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _discountValueController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: '20',
                        prefixIcon: const Icon(Icons.percent_rounded, size: 16, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Maximum Discount Cap (₹)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _maxCashbackController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: '200',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 16, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else if (_selectedRewardType == 'Cashback') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cashback Percentage (%)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _discountValueController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: '10',
                        prefixIcon: const Icon(Icons.percent_rounded, size: 16, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Maximum Cashback Cap (₹)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _maxCashbackController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: '100',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 16, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'The cashback will automatically be capped at the configured maximum amount on the backend.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
        ],
      );
    } else if (_selectedRewardType == 'Free Product') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderGrey),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Complimentary Gift Product', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                TextButton.icon(
                  onPressed: _showFreeGiftPickerDialog,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: _primaryNavy),
                  label: Text(
                    _selectedFreeGiftProduct == null ? 'Select Gift Product' : 'Change Product',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _primaryNavy),
                  ),
                ),
              ],
            ),
            if (_selectedFreeGiftProduct == null)
              const Text('No free gift item selected yet. Tap above to pick from your business menu.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)))
            else
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accentTeal),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard_rounded, size: 18, color: _accentTeal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_selectedFreeGiftProduct!.name} (Value: ₹${_selectedFreeGiftProduct!.price.toInt()})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                      onPressed: () => setState(() => _selectedFreeGiftProduct = null),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    } else if (_selectedRewardType == 'Buy 1 Get 1 (BOGO)') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderGrey),
        ),
        child: const Row(
          children: [
            Icon(Icons.local_offer_outlined, size: 20, color: _primaryNavy),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Buy 1 Get 1 (BOGO) Offer: Customers will get one free item when purchasing qualifying items from your menu.',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ),
          ],
        ),
      );
    } else {
      // Flat Cash Discount
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Discount Cash (₹)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: _discountValueController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: '300',
              prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 16, color: Color(0xFF64748B)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildProductSelectorSection() {
    final categories = _productCategories;
    final filtered = _filteredProducts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderGrey),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A082559),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with title and quick actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.checklist_rounded, size: 18, color: _primaryNavy),
                        const SizedBox(width: 6),
                        Text(
                          'Select Products (${_selectedProducts.length} of ${_menuProducts.length} selected)',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Discounts will apply only to the selected products in customer cart.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (_menuProducts.isNotEmpty) ...[
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedProducts.length == _menuProducts.length) {
                            _selectedProducts.clear();
                          } else {
                            _selectedProducts.clear();
                            _selectedProducts.addAll(_menuProducts);
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _selectedProducts.length == _menuProducts.length ? 'Deselect All' : 'Select All',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _primaryNavy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  IconButton(
                    icon: _isLoadingProducts
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _primaryNavy),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
                    tooltip: 'Refresh Products from Menu',
                    onPressed: _isLoadingProducts ? null : () => _loadProducts(forceRefresh: true),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Selected Chips Tray (if any selected)
          if (_selectedProducts.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Currently Chosen (${_selectedProducts.length}):',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                      ),
                      InkWell(
                        onTap: () => setState(() => _selectedProducts.clear()),
                        child: const Text('Clear All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE11D48))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 85),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _selectedProducts.map((p) {
                          return Container(
                            padding: const EdgeInsets.only(left: 8, right: 4, top: 3, bottom: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _primaryNavy.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${p.name} (₹${p.price.toInt()})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => setState(() => _selectedProducts.remove(p)),
                                  child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 3. Search Bar
          TextField(
            controller: _productSearchController,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Search products by name or category...',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
              suffixIcon: _productSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _productSearchController.clear();
                        setState(() => _productSearchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
            ),
            onChanged: (val) => setState(() => _productSearchQuery = val),
          ),
          const SizedBox(height: 10),

          // 4. Category filter pills (if more than 1 category)
          if (categories.length > 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isCatSelected = _selectedProductCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isCatSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isCatSelected ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                      selected: isCatSelected,
                      selectedColor: _primaryNavy,
                      backgroundColor: const Color(0xFFF1F5F9),
                      onSelected: (val) {
                        if (val) setState(() => _selectedProductCategory = cat);
                      },
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // 5. Scrollable Product Checklist
          if (_isLoadingProducts) ...[
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorder),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2, color: _primaryNavy),
                    SizedBox(height: 10),
                    Text('Loading products from your business menu...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ),
          ] else if (_menuProducts.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorder),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF94A3B8)),
                    const SizedBox(height: 8),
                    const Text('No products found in your menu yet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    const SizedBox(height: 4),
                    const Text('Sync menu items from your cloud backend or add items in POS.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _loadProducts(forceRefresh: true),
                      icon: const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Sync Menu Products'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (filtered.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorder),
              ),
              child: Center(
                child: Text('No products match "$_productSearchQuery"', style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              ),
            ),
          ] else ...[
            // Products List Container
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardBorder),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, idx) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (ctx, idx) {
                    final prod = filtered[idx];
                    final isSelected = _selectedProducts.any((p) => (p.id.isNotEmpty && p.id == prod.id) || p.name.trim().toLowerCase() == prod.name.trim().toLowerCase());

                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedProducts.removeWhere((p) => (p.id.isNotEmpty && p.id == prod.id) || p.name.trim().toLowerCase() == prod.name.trim().toLowerCase());
                          } else {
                            _selectedProducts.add(prod);
                          }
                        });
                      },
                      child: Container(
                        color: isSelected ? const Color(0x14082559) : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              activeColor: _primaryNavy,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    if (!isSelected) _selectedProducts.add(prod);
                                  } else {
                                    _selectedProducts.removeWhere((p) => (p.id.isNotEmpty && p.id == prod.id) || p.name.trim().toLowerCase() == prod.name.trim().toLowerCase());
                                  }
                                });
                              },
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected ? _primaryNavy.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.fastfood_rounded,
                                  size: 16,
                                  color: isSelected ? _primaryNavy : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    prod.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? _primaryNavy : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (prod.category.isNotEmpty)
                                    Text(
                                      prod.category,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${prod.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? _primaryNavy : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFreeGiftPickerDialog() {
    final searchController = TextEditingController();
    List<MenuItemModel> giftFiltered = List.from(_menuProducts);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setGiftState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Select Free Gift Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              content: SizedBox(
                width: 440,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search gift product by name...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (val) {
                        setGiftState(() {
                          final q = val.toLowerCase().trim();
                          giftFiltered = _menuProducts.where((p) => p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q)).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: giftFiltered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 32, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  const Text('No products found', style: TextStyle(color: Color(0xFF64748B))),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: () async {
                                      await _loadProducts(forceRefresh: true);
                                      setGiftState(() {
                                        giftFiltered = List.from(_menuProducts);
                                      });
                                    },
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Sync Menu'),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: giftFiltered.length,
                              itemBuilder: (c, i) {
                                final prod = giftFiltered[i];
                                return ListTile(
                                  title: Text(prod.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                  subtitle: Text('Value: ₹${prod.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  trailing: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryNavy,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedFreeGiftProduct = prod;
                                      });
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('Select', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // CARD 3: FAVORITE COUPON CODE (Phase 3)
  // -------------------------------------------------------------------------
  Widget _buildCouponSettingsCard() {
    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Favorite Coupon Code',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  Text(
                    _useCustomCouponCode ? 'Custom Code' : 'Auto-Generate',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _useCustomCouponCode,
                    activeThumbColor: _primaryNavy,
                    activeTrackColor: _primaryNavy.withValues(alpha: 0.5),
                    onChanged: (val) {
                      setState(() {
                        _useCustomCouponCode = val;
                        if (!val) {
                          _couponCodeController.text = _generateAutoCouponCode();
                          _isCheckingCode = false;
                          _isCodeUnique = true;
                          _codeCheckMessage = '';
                        } else {
                          _onCustomCodeChanged(_couponCodeController.text);
                        }
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _useCustomCouponCode
                ? 'Enter your unique custom coupon code. Uniqueness is automatically validated within your business.'
                : 'A unique coupon code is automatically generated for this campaign based on your offer.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          if (!_useCustomCouponCode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Auto-Generated Coupon Code:',
                          style: TextStyle(fontSize: 11, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _couponCodeController.text.toUpperCase(),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF), letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF2563EB)),
                    tooltip: 'Regenerate Code',
                    onPressed: () {
                      setState(() {
                        final val = double.tryParse(_discountValueController.text.trim())?.toInt() ?? 300;
                        final rand = (DateTime.now().millisecond % 900) + 100;
                        _couponCodeController.text = 'FLAT${val}_$rand';
                      });
                    },
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _couponCodeController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.5),
                  decoration: InputDecoration(
                    hintText: 'e.g. DIWALI300, FESTIVE20',
                    prefixIcon: const Icon(Icons.confirmation_num_outlined, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _isCheckingCode
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : (_isCodeUnique == true
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20)
                            : (_isCodeUnique == false
                                ? const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 20)
                                : null)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
                  ),
                ),
                if (_codeCheckMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      _codeCheckMessage,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _isCodeUnique == true ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CARD 4: CAMPAIGN SEND DATE & TIME (Phase 6 - OFF by default)
  // -------------------------------------------------------------------------
  Widget _buildScheduleSettingsCard() {
    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Campaign Send Date & Time',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Row(
                children: [
                  Text(
                    _hasSendSchedule ? 'Schedule Send' : 'Send Immediately',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _hasSendSchedule,
                    activeThumbColor: _primaryNavy,
                    activeTrackColor: _primaryNavy.withValues(alpha: 0.5),
                    onChanged: (val) => setState(() => _hasSendSchedule = val),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _hasSendSchedule
                ? 'Campaign will be stored and automatically dispatched at the selected date and time.'
                : 'Campaign will be sent out immediately upon publishing.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          if (!_hasSendSchedule)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF16A34A)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '⚡ Immediate Delivery: Campaign message will start sending immediately when you click Next / Publish.',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                // Date Picker Field
                Expanded(
                  child: InkWell(
                    onTap: _pickSendDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borderGrey),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MM/dd/yyyy').format(_sendDate),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Time Picker Field
                Expanded(
                  child: InkWell(
                    onTap: _pickSendTime,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _borderGrey),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _sendTime.format(context),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _pickSendDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sendDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: _primaryNavy),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _sendDate = picked);
  }

  Future<void> _pickSendTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _sendTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: _primaryNavy),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _sendTime = picked);
  }

  // -------------------------------------------------------------------------
  // CARD 5: CAMPAIGN EXPIRES DATE (Phase 7)
  // -------------------------------------------------------------------------
  Widget _buildExpirySettingsCard() {
    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Campaign Expires Date',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              Switch(
                value: _hasExpiryDate,
                activeThumbColor: _primaryNavy,
                activeTrackColor: _primaryNavy.withValues(alpha: 0.5),
                onChanged: (val) => setState(() => _hasExpiryDate = val),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose the final date by which customers can redeem this campaign. The offer will end at 11:59 PM on the selected date.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          if (_hasExpiryDate) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickExpiryDate,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _borderGrey),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MM/dd/yyyy').format(_expiryDate),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: _primaryNavy),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  // -------------------------------------------------------------------------
  // CARD 6: REDEMPTION PER CUSTOMER (Phase 8 - Only Once vs Multiple Times)
  // -------------------------------------------------------------------------
  Widget _buildRedemptionRulesCard() {
    return _buildNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Redemption Per Customer',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Control how many times an individual customer can redeem this campaign offer.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _redemptionPerCustomer = 'only_once'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _redemptionPerCustomer == 'only_once' ? _primaryNavy : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _redemptionPerCustomer == 'only_once' ? _primaryNavy : _borderGrey,
                        width: _redemptionPerCustomer == 'only_once' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_redemptionPerCustomer == 'only_once') ...[
                          const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          'Only Once',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _redemptionPerCustomer == 'only_once' ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _redemptionPerCustomer = 'multiple_times'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _redemptionPerCustomer == 'multiple_times' ? _primaryNavy : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _redemptionPerCustomer == 'multiple_times' ? _primaryNavy : _borderGrey,
                        width: _redemptionPerCustomer == 'multiple_times' ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_redemptionPerCustomer == 'multiple_times') ...[
                          const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          'Multiple Times',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _redemptionPerCustomer == 'multiple_times' ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (_redemptionPerCustomer == 'multiple_times') ...[
            const SizedBox(height: 14),
            const Text(
              'Maximum Redemptions Per Customer',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _maxRedemptionsPerCustomerController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: '5',
                prefixIcon: const Icon(Icons.repeat_rounded, size: 16, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Once a customer reaches this limit, further redemption attempts will be rejected.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ] else ...[
            const SizedBox(height: 10),
            const Text(
              'Customers will be restricted to exactly 1 redemption. Repeat attempts will be rejected with: "You have already redeemed this campaign coupon."',
              style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // 4. STEP 2: EDIT THEME CONFIGURATION FORM (Matching Image 1)
  // =========================================================================
  Widget _buildThemeConfigurationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNeumorphicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Review Campaign Profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review details to be displayed on your voucher',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: _cardBorder, height: 1),
              const SizedBox(height: 20),

              // Section 1: Upload Banner
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upload Banner',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    '(Recommended: 1200 x 628 px)',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Banner Thumbnail Box
                  Container(
                    width: 170,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cardBorder),
                      boxShadow: const [
                        BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _bannerImageUrl.startsWith('http')
                        ? Image.network(
                            _bannerImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, st) => Container(
                              color: const Color(0xFF0C464C),
                              child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 30),
                            ),
                          )
                        : Image.asset(
                            _bannerImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, st) => Container(
                              color: const Color(0xFF0C464C),
                              child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 30),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showChangeBannerDialog,
                          icon: const Icon(Icons.image_outlined, size: 16, color: _primaryNavy),
                          label: const Text(
                            'Change Banner',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _primaryNavy),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _primaryNavy, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'PNG, JPG, or WEBP up to 5MB',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Unsplash Explorer Callout Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDBEAFE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Try now',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text(
                                  'Explore millions of high-resolution photos on Unsplash',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: Color(0xFF1E3A8A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Instantly pick royalty-free culinary & dining photography to make your campaign stand out.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF3B82F6)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _showUnsplashPhotoExplorerDialog,
                      icon: const Icon(Icons.search_rounded, size: 14),
                      label: const Text('Explore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Divider(color: _cardBorder, height: 1),
              const SizedBox(height: 20),

              // Section 2: Upload Logo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upload Logo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    '(Recommended: 500 x 500 px)',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _primaryNavy,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _cardBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _logoUrl.isNotEmpty
                        ? (_logoUrl.startsWith('http')
                            ? Image.network(_logoUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => const Icon(Icons.storefront_rounded, size: 28, color: Colors.white))
                            : Image.asset(_logoUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => const Icon(Icons.storefront_rounded, size: 28, color: Colors.white)))
                        : const Center(child: Icon(Icons.storefront_rounded, size: 28, color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showChangeLogoDialog,
                          icon: const Icon(Icons.storefront_outlined, size: 16, color: _primaryNavy),
                          label: const Text(
                            'Change Logo',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _primaryNavy),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: _primaryNavy, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Displayed on voucher header and customer receipts.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(color: _cardBorder, height: 1),
              const SizedBox(height: 20),

              // Section 3: Theme Color Palette
              const Text(
                'Theme Color',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a brand color for the voucher background and accents',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Current swatch display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderGrey),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _themeColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${_themeColor.toARGB32().toRadixString(16).padLeft(8, "0").substring(2).toUpperCase()}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Swatch circles
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildColorCircle(const Color(0xFFE91E63), 'Pink'),
                        _buildColorCircle(const Color(0xFF082559), 'Navy'),
                        _buildColorCircle(const Color(0xFF10B981), 'Emerald'),
                        _buildColorCircle(const Color(0xFFF59E0B), 'Amber'),
                        _buildColorCircle(const Color(0xFF8B5CF6), 'Purple'),
                        _buildColorCircle(const Color(0xFFEF4444), 'Crimson'),
                        _buildColorCircle(const Color(0xFF2563EB), 'Blue'),
                        _buildColorCircle(const Color(0xFF1E293B), 'Slate'),
                        // Custom color button
                        InkWell(
                          onTap: _showThemeColorPaletteDialog,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _borderGrey),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.colorize_rounded, size: 14, color: Color(0xFF475569)),
                                SizedBox(width: 4),
                                Text('Custom', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(color: _cardBorder, height: 1),
              const SizedBox(height: 20),

              // Section 4: Text Color Palette
              const Text(
                'Text Color',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose contrasting color for voucher typography',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _borderGrey),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: _textColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.black26),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '#${_textColor.toARGB32().toRadixString(16).padLeft(8, "0").substring(2).toUpperCase()}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildTextColorCircle(Colors.white, 'White'),
                      _buildTextColorCircle(const Color(0xFF0F172A), 'Midnight'),
                      _buildTextColorCircle(const Color(0xFFFEF08A), 'Lemon'),
                      _buildTextColorCircle(const Color(0xFFE0F2FE), 'Ice Cyan'),
                      _buildTextColorCircle(const Color(0xFFFDE68A), 'Gold'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Bottom Navigation Row
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep = 1),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to Edit Reward', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                side: const BorderSide(color: _borderGrey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: _saveDraft,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryNavy,
                side: const BorderSide(color: _primaryNavy, width: 1.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('Save Draft', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                _syncWhatsappTemplateDefaults();
                setState(() => _currentStep = 3);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryNavy,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              child: const Row(
                children: [
                  Text('Next', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildColorCircle(Color color, String tooltip) {
    final isSelected = _themeColor.toARGB32() == color.toARGB32();
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _themeColor = color),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.black12,
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1),
                  ]
                : null,
          ),
          child: isSelected
              ? const Center(
                  child: Icon(Icons.check_rounded, color: Colors.white, size: 16),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildTextColorCircle(Color color, String tooltip) {
    final isSelected = _textColor.toARGB32() == color.toARGB32();
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _textColor = color),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? _primaryNavy : _borderGrey,
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: isSelected
              ? Center(
                  child: Icon(
                    Icons.check_rounded,
                    color: color == Colors.white ? const Color(0xFF0F172A) : Colors.white,
                    size: 16,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  // =========================================================================
  // 5. STEP 3: WHATSAPP REVIEW & META APPROVAL (Matching Image 2)
  // =========================================================================
  Widget _buildWhatsappReviewConfigurationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNeumorphicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Whatsapp Review',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review your WhatsApp campaign template and submit for Meta approval',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: _cardBorder, height: 1),
              const SizedBox(height: 20),

              // Section 1: Send Campaign Display Name
              const Text(
                'Send Campaign Display Name',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose which verified sender name customers see on WhatsApp',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildDisplayNameOption('Loyalty Restaurant', 'Restaurant Business Account'),
                  const SizedBox(width: 12),
                  _buildDisplayNameOption('Knowwu', 'Official Verified Business Account', isVerified: true),
                ],
              ),

              const SizedBox(height: 22),
              const Divider(color: _cardBorder, height: 1),
              const SizedBox(height: 20),

              // Section 2: Message Category & Choose Language
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Message Category',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _messageCategory,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Marketing', child: Text('Marketing (Promotional Offers)')),
                            DropdownMenuItem(value: 'Utility', child: Text('Utility (Account & Transactions)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _messageCategory = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose Language',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _templateLanguage,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'en', child: Text('English (en)')),
                            DropdownMenuItem(value: 'hi', child: Text('Hindi (hi)')),
                            DropdownMenuItem(value: 'hinglish', child: Text('Hinglish')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _templateLanguage = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),
              const Divider(color: _cardBorder, height: 1),
              const SizedBox(height: 20),

              // Section 3: Template Type / Body
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF15803D)),
                        SizedBox(width: 6),
                        Text('Custom Template', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF15803D))),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Formatting toolbar (B, I, S)
                  _buildFormattingToolbar(),
                ],
              ),
              const SizedBox(height: 10),

              // Variable Pills for dynamic insertion
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildVariableChip('{{1}} Customer Name', '{{1}}'),
                  _buildVariableChip('{{2}} Discount', '{{2}}'),
                  _buildVariableChip('{{3}} Coupon Code', '{{3}}'),
                  _buildVariableChip('{{4}} Expiry Date', '{{4}}'),
                ],
              ),
              const SizedBox(height: 10),

              // Multiline Body Field
              TextField(
                controller: _whatsappBodyController,
                maxLines: 5,
                maxLength: 1000,
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), height: 1.4),
                decoration: InputDecoration(
                  hintText: 'Enter your WhatsApp campaign message...',
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
                ),
              ),

              const SizedBox(height: 10),
              // Optional Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Footer (Optional)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    'Short text at the bottom',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _whatsappFooterController,
                maxLength: 60,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Reply STOP to unsubscribe',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(color: _cardBorder, height: 1),
              const SizedBox(height: 20),

              // Section 4: Header Media
              const Text(
                'Header media',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add an image or video to the top of your message to boost engagement',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildHeaderMediaRadio('default_media', 'Default media (Banner)'),
                  const SizedBox(width: 14),
                  _buildHeaderMediaRadio('custom_media', 'Add Custom Media'),
                  const SizedBox(width: 14),
                  _buildHeaderMediaRadio('no_media', 'No media'),
                ],
              ),
              if (_headerMediaOption == 'custom_media') ...[
                const SizedBox(height: 10),
                TextField(
                  onChanged: (val) => setState(() => _customHeaderMediaUrl = val),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/promo-image.jpg',
                    labelText: 'Custom Media Image URL',
                    prefixIcon: const Icon(Icons.link_rounded, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Tip callout for Android CTR
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF15803D)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'For Android users, header media ensures higher click-through rates. Images must be JPEG/PNG, under 5MB.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),
              const Divider(color: _cardBorder, height: 1),
              const SizedBox(height: 20),

              // Section 5: Interactive Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Interactive Actions',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Buttons that let customers take immediate action',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  // Segmented pills: None | All
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _borderGrey),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionPill('none', 'None'),
                        _buildActionPill('all', 'All'),
                      ],
                    ),
                  ),
                ],
              ),
              if (_interactiveActionsOption == 'all') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderGrey),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Button Title', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _ctaButtonTitleController,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'Offer details',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Website URL (with variable)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _ctaButtonUrlController,
                              style: const TextStyle(fontSize: 12.5),
                              decoration: InputDecoration(
                                hintText: 'https://loyalty.knowwu.me/b/{{1}}',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Bottom Navigation Row
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep = 2),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to Edit Theme', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                side: const BorderSide(color: _borderGrey),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: _saveDraft,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryNavy,
                side: const BorderSide(color: _primaryNavy, width: 1.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('Save Draft', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSubmittingApproval ? null : _submitForMetaApproval,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryNavy,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              child: _isSubmittingApproval
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      children: [
                        Text('Submit for Approval', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
            ),
          ],
        ),
        const SizedBox(height: 36),
      ],
    );
  }

  Widget _buildDisplayNameOption(String title, String subtitle, {bool isVerified = false}) {
    final isSelected = _sendCampaignDisplayName == title;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _sendCampaignDisplayName = title),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF10B981) : _cardBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: isSelected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                        ],
                      ],
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormattingToolbar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderGrey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolbarButton('B', () => _wrapTextWith('*'), isBold: true),
          const SizedBox(width: 2),
          _buildToolbarButton('I', () => _wrapTextWith('_'), isItalic: true),
          const SizedBox(width: 2),
          _buildToolbarButton('S', () => _wrapTextWith('~'), isStrike: true),
        ],
      ),
    );
  }

  Widget _buildToolbarButton(String label, VoidCallback onTap, {bool isBold = false, bool isItalic = false, bool isStrike = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            decoration: isStrike ? TextDecoration.lineThrough : null,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  void _wrapTextWith(String symbol) {
    final text = _whatsappBodyController.text;
    final selection = _whatsappBodyController.selection;
    if (selection.start >= 0 && selection.end > selection.start) {
      final selected = text.substring(selection.start, selection.end);
      final replaced = text.replaceRange(selection.start, selection.end, '$symbol$selected$symbol');
      _whatsappBodyController.text = replaced;
    } else {
      _whatsappBodyController.text = '$text$symbol$symbol';
    }
  }

  Widget _buildVariableChip(String label, String varToken) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
      backgroundColor: const Color(0xFFEFF6FF),
      side: const BorderSide(color: Color(0xFFBFDBFE)),
      onPressed: () {
        final text = _whatsappBodyController.text;
        _whatsappBodyController.text = '$text $varToken';
      },
    );
  }

  Widget _buildHeaderMediaRadio(String value, String label) {
    final isSelected = _headerMediaOption == value;
    return InkWell(
      onTap: () => setState(() => _headerMediaOption = value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 16,
            color: isSelected ? _primaryNavy : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill(String value, String label) {
    final isSelected = _interactiveActionsOption == value;
    return InkWell(
      onTap: () => setState(() => _interactiveActionsOption = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? _primaryNavy : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 6. META TEMPLATE APPROVAL WORKFLOW & MODAL
  // =========================================================================
  Future<void> _submitForMetaApproval() async {
    final body = _whatsappBodyController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter template message body before submitting for Meta approval.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSubmittingApproval = true);

    try {
      final title = _campaignTitleController.text.trim().isNotEmpty
          ? _campaignTitleController.text.trim()
          : 'Weekend Special Offer';

      final payload = {
        'name': title,
        'category': _messageCategory,
        'language': _templateLanguage,
        'body': body,
        'footerText': _whatsappFooterController.text.trim(),
        'headerType': _headerMediaOption == 'no_media' ? 'NONE' : 'IMAGE',
        'headerMediaUrl': _headerMediaOption == 'default_media'
            ? _bannerImageUrl
            : _customHeaderMediaUrl,
        'displayName': _sendCampaignDisplayName,
        'buttonText': _interactiveActionsOption == 'all'
            ? _ctaButtonTitleController.text.trim()
            : '',
        'buttonUrl': _interactiveActionsOption == 'all'
            ? _ctaButtonUrlController.text.trim()
            : '',
      };

      final template = await _campaignService.submitTemplateForApproval(payload);
      if (template != null) {
        setState(() {
          _submittedTemplate = template;
          _savedStatus = 'Template Submitted';
        });
        if (mounted) {
          _showMetaApprovalDialog(template);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to submit template to Meta. Please verify connection and retry.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[CreateCampaignWizardView] _submitForMetaApproval notice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notice: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingApproval = false);
    }
  }

  void _showMetaApprovalDialog(CampaignTemplateModel initialTemplate) {
    CampaignTemplateModel currentTemplate = initialTemplate;
    bool isChecking = false;
    bool isApproving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isApproved = currentTemplate.metaStatus == 'APPROVED';
          final isPending = currentTemplate.metaStatus == 'PENDING';
          

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Bar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isApproved ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isApproved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                            size: 24,
                            color: isApproved ? const Color(0xFF15803D) : const Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Meta WhatsApp Template Status',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Template: ${currentTemplate.name} • ${currentTemplate.id}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Status Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? const Color(0xFFF0FDF4)
                            : (isPending ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isApproved
                              ? const Color(0xFF86EFAC)
                              : (isPending ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isApproved
                                      ? const Color(0xFF15803D)
                                      : (isPending ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isApproved
                                      ? 'APPROVED'
                                      : (isPending ? 'PENDING APPROVAL' : 'REJECTED'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (isPending)
                                const Row(
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
                                    ),
                                    SizedBox(width: 6),
                                    Text('In review with Meta', style: TextStyle(fontSize: 11.5, color: Color(0xFFD97706))),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isApproved
                                ? 'Template has been approved by Meta! You can now send this campaign to your customers.'
                                : (isPending
                                    ? 'Your template has been submitted to Meta (WhatsApp) for review. Approval typically takes 2 to 15 minutes.'
                                    : 'Meta has rejected this template. Please modify the template wording and re-submit.'),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isApproved
                                  ? const Color(0xFF166534)
                                  : (isPending ? const Color(0xFF92400E) : const Color(0xFF991B1B)),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Hard Dispatch Rule Warning
                    if (!isApproved)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.block_rounded, size: 16, color: Color(0xFFDC2626)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Without Meta approval, this campaign cannot be sent to customers. Meta guarantees delivery only for approved templates.',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      children: [
                        if (isPending) ...[
                          // Check Status Button
                          OutlinedButton.icon(
                            onPressed: isChecking
                                ? null
                                : () async {
                                    setDialogState(() => isChecking = true);
                                    final statusData = await _campaignService.checkTemplateApprovalStatus(currentTemplate.id);
                                    if (statusData != null && statusData['metaStatus'] != null) {
                                      final updated = currentTemplate.copyWith(
                                        metaStatus: statusData['metaStatus'].toString(),
                                      );
                                      setDialogState(() {
                                        currentTemplate = updated;
                                        _submittedTemplate = updated;
                                      });
                                    }
                                    setDialogState(() => isChecking = false);
                                  },
                            icon: isChecking
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Check Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF334155),
                              side: const BorderSide(color: _borderGrey),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Sandbox Instant Approval Simulation Button
                          ElevatedButton.icon(
                            onPressed: isApproving
                                ? null
                                : () async {
                                    setDialogState(() => isApproving = true);
                                    final approved = await _campaignService.approveTemplate(currentTemplate.id);
                                    if (approved != null) {
                                      setDialogState(() {
                                        currentTemplate = approved;
                                        _submittedTemplate = approved;
                                      });
                                      setState(() {
                                        _submittedTemplate = approved;
                                      });
                                    }
                                    setDialogState(() => isApproving = false);
                                  },
                            icon: isApproving
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.verified_rounded, size: 16),
                            label: const Text('Simulate Approval (Sandbox)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF15803D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ] else if (isApproved) ...[
                          const Spacer(),
                          // Launch campaign button!
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              _publishApprovedCampaign(currentTemplate);
                            },
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: Text(
                              _hasSendSchedule ? 'Schedule Campaign Now' : 'Send Campaign to Customers',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryNavy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ] else ...[
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            style: ElevatedButton.styleFrom(backgroundColor: _primaryNavy),
                            child: const Text('Close & Revise', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _publishApprovedCampaign(CampaignTemplateModel approvedTemplate) async {
    final validationError = _validateForm();
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: const Color(0xFFDC2626)),
      );
      return;
    }

    setState(() => _isPublishing = true);
    final title = _campaignTitleController.text.trim().isNotEmpty
        ? _campaignTitleController.text.trim()
        : approvedTemplate.name;

    final reward = CampaignRewardDetailsModel(
      rewardType: _mapRewardTypeToKey(_selectedRewardType),
      discountAmount: double.tryParse(_discountValueController.text.trim()) ?? 300.0,
      discountScope: _discountScope,
      chosenProducts: _selectedProducts.map((p) => {'id': p.id, 'productId': p.id, 'name': p.name, 'price': p.price}).toList(),
      freeGiftProductId: _selectedFreeGiftProduct?.id ?? '',
      freeGiftProductName: _selectedFreeGiftProduct?.name ?? '',
      freeGiftProductPrice: _selectedFreeGiftProduct?.price ?? 0.0,
      hasMinSpend: _hasMinSpend,
      minSpendAmount: double.tryParse(_minSpendController.text.trim()) ?? 500.0,
      maxCashbackCap: double.tryParse(_maxCashbackController.text.trim()) ?? 200.0,
      campaignTitle: title,
      description: _descriptionController.text.trim(),
      bannerImageUrl: _bannerImageUrl,
      logoUrl: _logoUrl,
      themeColor: '#${_themeColor.toARGB32().toRadixString(16).padLeft(8, "0").substring(2)}',
      textColor: '#${_textColor.toARGB32().toRadixString(16).padLeft(8, "0").substring(2)}',
      restaurantName: _db.restaurant?.name ?? '',
      termsAndConditions: _buildTermsList(),
    );

    final coupon = CampaignCouponSettingsModel(
      useCustomCouponCode: _useCustomCouponCode,
      customCouponCode: _useCustomCouponCode ? _couponCodeController.text.trim().toUpperCase() : '',
      couponCode: _couponCodeController.text.trim().toUpperCase(),
      hasSendSchedule: _hasSendSchedule,
      sendDate: _sendDate,
      sendTime: '${_sendTime.hourOfPeriod}:${_sendTime.minute.toString().padLeft(2, "0")} ${_sendTime.period == DayPeriod.am ? "AM" : "PM"}',
      scheduledAt: _hasSendSchedule ? DateTime(_sendDate.year, _sendDate.month, _sendDate.day, _sendTime.hour, _sendTime.minute) : null,
      hasExpiryDate: _hasExpiryDate,
      expiryDate: _hasExpiryDate ? _expiryDate : null,
      redemptionPerCustomer: _redemptionPerCustomer,
      maxRedemptionsPerCustomer: int.tryParse(_maxRedemptionsPerCustomerController.text.trim()) ?? 1,
      displayCouponInProfile: false,
    );

    final audience = CampaignAudienceModel(
      source: 'group',
      groupName: _selectedGroup?.name ?? 'All Customers',
      recipientCount: _selectedGroup?.count ?? 320,
    );

    final channel = _selectedChannel ?? const CampaignChannelModel();

    final DateTime scheduledDateTime = DateTime(
      _sendDate.year,
      _sendDate.month,
      _sendDate.day,
      _sendTime.hour,
      _sendTime.minute,
    );

    final created = await _campaignService.createCampaign(
      name: title,
      type: 'marketing',
      status: _hasSendSchedule ? 'scheduled' : 'running',
      audience: audience,
      channel: channel,
      template: approvedTemplate,
      scheduleMode: _hasSendSchedule ? 'later' : 'now',
      scheduledAt: _hasSendSchedule ? scheduledDateTime : DateTime.now(),
      estimatedSendingTime: _hasSendSchedule
          ? '${DateFormat("dd MMM yyyy").format(_sendDate)}, ${_sendTime.format(context)}'
          : 'Start sending immediately',
      rewardDetails: reward,
      couponSettings: coupon,
      orderTypes: _selectedOrderTypes.map((e) => e.toLowerCase().replaceAll(' ', '_')).toList(),
    );

    setState(() => _isPublishing = false);

    if (created != null && mounted) {
      setState(() => _savedStatus = 'Published');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => CampaignSubmittedDialog(
          campaign: created,
          onViewCampaign: () {
            Navigator.pop(ctx);
            widget.onCampaignCreated(created);
          },
          onCreateAnother: () {
            Navigator.pop(ctx);
            setState(() {
              _savedStatus = 'Not saved yet';
              _persistedCampaignId = null;
              _currentStep = 1;
              _campaignTitleController.text = 'Weekend Special Offer';
            });
          },
        ),
      );
    }
  }

  void _syncWhatsappTemplateDefaults() {
    final discountVal = _discountValueController.text.trim().isNotEmpty
        ? _discountValueController.text.trim()
        : '150';
    final coupon = _couponCodeController.text.trim().isNotEmpty
        ? _couponCodeController.text.trim().toUpperCase()
        : 'KNOV2210';
    final expiry = DateFormat('dd/MM/yyyy').format(_expiryDate);

    if (_whatsappBodyController.text.trim().isEmpty ||
        _whatsappBodyController.text.contains('Kick-start')) {
      _whatsappBodyController.text =
          'We appreciate having you with us! Enjoy flat Rs. $discountVal OFF on your next order with code $coupon. Valid until $expiry. Order now:';
    }
    if (_whatsappFooterController.text.trim().isEmpty) {
      _whatsappFooterController.text = 'Reply STOP to unsubscribe';
    }
  }

  // =========================================================================
  // 7. DIALOGS: UNSPLASH, BANNER, LOGO & COLOR PICKERS
  // =========================================================================
  void _showUnsplashPhotoExplorerDialog() {
    final List<Map<String, String>> photos = [
      {'name': 'Festive Feast', 'category': 'Fine Dining', 'url': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1000&auto=format&fit=crop&q=80'},
      {'name': 'Hyderabadi Biryani', 'category': 'Biryani & Indian', 'url': 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=1000&auto=format&fit=crop&q=80'},
      {'name': 'Gourmet Burger & Fries', 'category': 'Burgers & Fast Food', 'url': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=1000&auto=format&fit=crop&q=80'},
      {'name': 'Artisan Woodfire Pizza', 'category': 'Pizza & Italian', 'url': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=1000&auto=format&fit=crop&q=80'},
      {'name': 'Royal Indian Thali', 'category': 'Biryani & Indian', 'url': 'https://images.unsplash.com/photo-1610057099443-fde8c4d50f91?w=1000&auto=format&fit=crop&q=80'},
      {'name': 'Decadent Chocolate Cake', 'category': 'Desserts', 'url': 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=1000&auto=format&fit=crop&q=80'},
      {'name': 'Espresso & Latte Art', 'category': 'Beverages & Coffee', 'url': 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=1000&auto=format&fit=crop&q=80'},
      {'name': 'Celebration Fireworks', 'category': 'Events', 'url': 'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?w=1000&auto=format&fit=crop&q=80'},
      {'name': 'App Banner Default', 'category': 'Presets', 'url': 'assets/images/campaign_hero_banner_full.png'},
    ];

    String selectedCat = 'All';
    final customUrlCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlg) {
          final filtered = selectedCat == 'All'
              ? photos
              : photos.where((p) => p['category'] == selectedCat).toList();

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB), size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Unsplash Photo Explorer for Restaurant Campaigns',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Custom URL Bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customUrlCtrl,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Paste any Unsplash or custom photo URL...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              prefixIcon: const Icon(Icons.link_rounded, size: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (customUrlCtrl.text.trim().isNotEmpty) {
                              setState(() => _bannerImageUrl = customUrlCtrl.text.trim());
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Banner image updated!'), backgroundColor: Color(0xFF15803D)),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: _primaryNavy),
                          child: const Text('Apply', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Category Filter Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Biryani & Indian', 'Burgers & Fast Food', 'Pizza & Italian', 'Desserts', 'Fine Dining'].map((cat) {
                          final isSel = selectedCat == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(cat, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
                              selected: isSel,
                              onSelected: (_) => setDlg(() => selectedCat = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Photos Grid
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.4,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, idx) {
                          final p = filtered[idx];
                          final url = p['url']!;
                          final name = p['name']!;

                          return InkWell(
                            onTap: () {
                              setState(() => _bannerImageUrl = url);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Selected "$name" as campaign banner!'), backgroundColor: const Color(0xFF15803D)),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _cardBorder),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  url.startsWith('http')
                                      ? Image.network(url, fit: BoxFit.cover)
                                      : Image.asset(url, fit: BoxFit.cover),
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      color: Colors.black.withValues(alpha: 0.65),
                                      child: Text(
                                        name,
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChangeBannerDialog() {
    final ctrl = TextEditingController(text: _bannerImageUrl.startsWith('http') ? _bannerImageUrl : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Campaign Banner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter public image URL or select from Unsplash presets:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'https://example.com/banner.jpg',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showUnsplashPhotoExplorerDialog();
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF2563EB)),
              label: const Text('Or explore photos on Unsplash', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                setState(() => _bannerImageUrl = ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryNavy),
            child: const Text('Save Banner', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangeLogoDialog() {
    final ctrl = TextEditingController(text: _logoUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Business Logo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter image URL or choose default brand icon:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: 'https://example.com/logo.png',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => _logoUrl = ctrl.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryNavy),
            child: const Text('Save Logo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showThemeColorPaletteDialog() {
    final hexCtrl = TextEditingController(text: _themeColor.toARGB32().toRadixString(16).padLeft(8, "0").substring(2).toUpperCase());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Theme Color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter 6-character hex color code (e.g. E91E63):', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            TextField(
              controller: hexCtrl,
              maxLength: 6,
              decoration: InputDecoration(
                prefixText: '#',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final hex = hexCtrl.text.trim();
              if (hex.length == 6) {
                final intVal = int.tryParse('FF$hex', radix: 16);
                if (intVal != null) {
                  setState(() => _themeColor = Color(intVal));
                }
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryNavy),
            child: const Text('Apply Color', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
