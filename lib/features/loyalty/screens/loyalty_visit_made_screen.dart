import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/services/loyalty_service.dart';

class SelectableProductItem {
  final String id;
  final String displayName;
  final double price;

  SelectableProductItem({
    required this.id,
    required this.displayName,
    required this.price,
  });
}

class LoyaltyVisitMadeScreen extends StatefulWidget {
  final String companyName;
  final String companyLogo;
  final LoyaltyProgramModel? program;
  final VoidCallback? onCompleted;

  const LoyaltyVisitMadeScreen({
    super.key,
    this.companyName = '',
    this.companyLogo = '',
    this.program,
    this.onCompleted,
  });

  @override
  State<LoyaltyVisitMadeScreen> createState() => _LoyaltyVisitMadeScreenState();
}

class _LoyaltyVisitMadeScreenState extends State<LoyaltyVisitMadeScreen> {
  final LoyaltyService _loyaltyService = LoyaltyService();
  final ImagePicker _imagePicker = ImagePicker();
  final ScrollController _mainScrollController = ScrollController();

  // App Theme Primary Color (Deep Navy Blue from App Header)
  static const Color _primaryThemeColor = Color(0xFF082559);

  // Form Controllers - Theme Section
  late TextEditingController _programNameCtrl;
  late TextEditingController _sloganCtrl;
  late TextEditingController _minPurchaseCtrl;

  // Form Controllers - Points Section
  late TextEditingController _timesCustomerVisitCtrl;
  late TextEditingController _customerEarnsPointsCtrl;
  late TextEditingController _pointsNameCtrl;
  late TextEditingController _minSpendConditionCtrl;
  late TextEditingController _maxCashbackLimitCtrl;

  // Form Controllers - Terms Section (Matching media_1787951020034.png)
  late TextEditingController _termsCtrl;
  late TextEditingController _customTermCtrl;
  bool _termNoMinLimit = true;
  bool _termNoClubbing = true;
  bool _termNoHolidays = false;
  bool _termInStoreOnly = false;
  bool _termCustom = false;

  // Form Controllers - Bonus Section (Matching media_1787951841070.png)
  bool _bonusPointsEnabled = true;
  late TextEditingController _bonusPointsAmountCtrl;

  // Points Settings State & Toggles
  bool _pointBrandingEnabled = true;
  int _selectedPointPresetIndex = 0; // 0: Cookie, 1: Chilly, 2: Star, 3: Coin
  bool _minSpendConditionEnabled = false;
  bool _maxCashbackLimitEnabled = false;

  // Active Navigation States
  int _activeStep = 0; // 0: Edit Theme, 1: Edit Bonus, 2: Reminders, 3: Edit Channels, 4: Edit Alert, 5: Done
  int _activeSectionTab = 0; // 0: Theme, 1: Points, 2: Rewards, 3: Terms

  // Theme Colors
  Color _bgGradientStart = const Color(0xFF4A082F); // Dark Burgundy
  Color _bgGradientEnd = const Color(0xFF8E1449); // Ruby / Magenta
  Color _rewardColorStart = const Color(0xFF4A082F);
  Color _rewardColorEnd = const Color(0xFF8E1449);
  Color _bodyTextColor = Colors.white;

  // Multi-select Order Types (Delivery, Take Away, Dine In)
  Set<String> _selectedOrderTypes = {'Delivery', 'Take-Away', 'Dine-In'};

  // Media
  String _bannerImagePath = 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800';
  String _logoUrl = '';

  String get _currentPointsName =>
      _pointsNameCtrl.text.trim().isNotEmpty ? _pointsNameCtrl.text.trim() : 'Cookie';

  /// Dynamic emoji reflecting the selected preset or user-typed point branding
  String get _currentPointsEmoji {
    if (_selectedPointPresetIndex == 0) return '🍪';
    if (_selectedPointPresetIndex == 1) return '🌶️';
    if (_selectedPointPresetIndex == 2) return '⭐';
    if (_selectedPointPresetIndex == 3) return '🪙';

    final name = _pointsNameCtrl.text.trim().toLowerCase();
    if (name.contains('chilly') || name.contains('chili') || name.contains('spice')) return '🌶️';
    if (name.contains('star')) return '⭐';
    if (name.contains('coin') || name.contains('rupee') || name.contains('cash')) return '🪙';
    if (name.contains('cookie') || name.contains('biscuit')) return '🍪';
    if (name.contains('point') || name.contains('score')) return '💎';
    if (name.contains('coffee') || name.contains('cup')) return '☕';
    if (name.contains('burger') || name.contains('food')) return '🍔';
    return '🍪';
  }

  // Stages
  List<RewardStageModel> _rewardStages = [];
  bool _isSaving = false;

  // Validation
  String? _programNameError;

  // Channel screen state (media_1787953660666.png)
  String _channelDisplayName = 'Apna POS';
  String _userCompanyName = 'THE ROYAL GARDENIA';
  bool _whatsappUtilityEnabled = true;

  final List<String> _stepTitles = [
    'Edit Theme',
    'Edit Bonus',
    'Edit Channel',
    'Done',
  ];

  @override
  void initState() {
    super.initState();
    final currentUser = DatabaseService().currentUser;
    final dbRestaurant = DatabaseService().restaurant;
    final initialName = widget.companyName.isNotEmpty
        ? widget.companyName
        : (currentUser?.companyName ?? (dbRestaurant?.name ?? 'THE ROYAL GARDENIA'));
    _userCompanyName = initialName;

    _programNameCtrl = TextEditingController(
      text: widget.program?.title.isNotEmpty == true
          ? widget.program!.title
          : initialName,
    );
    _sloganCtrl = TextEditingController(
      text: widget.program?.description.isNotEmpty == true
          ? widget.program!.description
          : 'Get rewarded on every purchase',
    );
    _minPurchaseCtrl = TextEditingController(text: '100');

    // Dynamic initial logo from profile create / user profile / widget
    _logoUrl = widget.companyLogo.isNotEmpty
        ? widget.companyLogo
        : (currentUser?.profilePhotoPath ?? '');

    // Points tab controllers
    _timesCustomerVisitCtrl = TextEditingController(text: '1');
    _customerEarnsPointsCtrl = TextEditingController(text: '10');
    _pointsNameCtrl = TextEditingController(text: 'Cookie');
    _minSpendConditionCtrl = TextEditingController(text: '0');
    _maxCashbackLimitCtrl = TextEditingController(text: '0');

    // Terms tab controllers (media_1787951020034.png)
    _termsCtrl = TextEditingController(text: 'No minimum purchase limit. 2 offers cannot be clubbed.');
    _customTermCtrl = TextEditingController();

    // Bonus tab controllers (media_1787951841070.png)
    _bonusPointsAmountCtrl = TextEditingController(text: '100');

    // Initialize default or existing reward stages immediately for instant 0ms screen rendering
    if (widget.program != null && widget.program!.milestones.isNotEmpty) {
      _rewardStages = widget.program!.milestones.map((m) => RewardStageModel(
        id: m.id,
        visitCount: m.value.toInt() > 0 ? m.value.toInt() : 300,
        rewardType: 'Redeem cash discount',
        rewardValue: m.rewardValue > 0 ? m.rewardValue : 100.0,
        minimumPurchase: 100.0,
        freeItemName: m.rewardText.isNotEmpty ? m.rewardText : 'Cheers ! Rs ${m.rewardValue.toInt()} off on your purchase.',
      )).toList();
    } else {
      _rewardStages = [
        RewardStageModel(
          id: 'stage_1',
          visitCount: 300,
          rewardType: 'Redeem cash discount',
          rewardValue: 100.0,
          minimumPurchase: 100.0,
          freeItemName: 'Cheers ! Rs 100 off on your purchase.',
        ),
        RewardStageModel(
          id: 'stage_2',
          visitCount: 500,
          rewardType: 'Redeem cash discount',
          rewardValue: 200.0,
          minimumPurchase: 100.0,
          freeItemName: 'Cheers ! Rs 200 off on your purchase.',
        ),
        RewardStageModel(
          id: 'stage_3',
          visitCount: 800,
          rewardType: 'Redeem cash discount',
          rewardValue: 300.0,
          minimumPurchase: 100.0,
          freeItemName: 'Cheers ! Rs 300 off on your purchase.',
        ),
      ];
    }

    // Load saved remote config asynchronously in background without blocking the UI
    _loadExistingConfig();
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _programNameCtrl.dispose();
    _sloganCtrl.dispose();
    _minPurchaseCtrl.dispose();
    _timesCustomerVisitCtrl.dispose();
    _customerEarnsPointsCtrl.dispose();
    _pointsNameCtrl.dispose();
    _minSpendConditionCtrl.dispose();
    _maxCashbackLimitCtrl.dispose();
    _termsCtrl.dispose();
    _customTermCtrl.dispose();
    _bonusPointsAmountCtrl.dispose();
    super.dispose();
  }

  void _rebuildTermsText() {
    final List<String> terms = [];
    if (_termNoMinLimit) terms.add('No minimum purchase limit.');
    if (_termNoClubbing) terms.add('2 offers cannot be clubbed.');
    if (_termNoHolidays) terms.add('Not redeemable on public holidays.');
    if (_termInStoreOnly) terms.add('Reward redeemable in-store only.');
    if (_termCustom && _customTermCtrl.text.trim().isNotEmpty) {
      terms.add(_customTermCtrl.text.trim());
    }
    if (terms.isEmpty) {
      terms.add('Terms and conditions apply.');
    }
    setState(() {
      _termsCtrl.text = terms.join(' ');
    });
  }

  Future<void> _loadExistingConfig() async {
    try {
      final currentUser = DatabaseService().currentUser;
      final dbRestaurant = DatabaseService().restaurant;
      final fallbackLogo = widget.companyLogo.isNotEmpty
          ? widget.companyLogo
          : (currentUser?.profilePhotoPath ?? '');
      final fallbackName = widget.companyName.isNotEmpty
          ? widget.companyName
          : (currentUser?.companyName ?? (dbRestaurant?.name ?? 'Swaad Chowpatty'));

      final config = await _loyaltyService.getVisitRewardConfig(
        companyName: fallbackName,
        companyLogo: fallbackLogo,
      );

      if (mounted) {
        setState(() {
          if (fallbackName.isNotEmpty) _userCompanyName = fallbackName;
          if (config.programName.isNotEmpty) {
            _programNameCtrl.text = config.programName;
            _userCompanyName = config.programName;
          }
          if (config.slogan.isNotEmpty) _sloganCtrl.text = config.slogan;
          if (config.minimumPurchase > 0) {
            _minPurchaseCtrl.text = config.minimumPurchase.toInt().toString();
          }
          if (config.orderType.isNotEmpty) {
            final types = config.orderType
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toSet();
            if (types.isNotEmpty) _selectedOrderTypes = types;
          }

          // Dynamic logo resolution
          if (config.logoUrl.isNotEmpty) {
            _logoUrl = config.logoUrl;
          } else if (fallbackLogo.isNotEmpty) {
            _logoUrl = fallbackLogo;
          }

          if (config.bannerImageUrl.isNotEmpty) _bannerImagePath = config.bannerImageUrl;

          if (config.termsNote.isNotEmpty) {
            _termsCtrl.text = config.termsNote;
          }

          // Points Conditions
          _minSpendConditionEnabled = config.minSpendConditionEnabled;
          _minSpendConditionCtrl.text = config.minSpendCondition > 0
              ? (config.minSpendCondition == config.minSpendCondition.toInt()
                  ? config.minSpendCondition.toInt().toString()
                  : config.minSpendCondition.toString())
              : '0';

          _maxCashbackLimitEnabled = config.maxCashbackLimitEnabled;
          _maxCashbackLimitCtrl.text = config.maxCashbackLimit > 0
              ? (config.maxCashbackLimit == config.maxCashbackLimit.toInt()
                  ? config.maxCashbackLimit.toInt().toString()
                  : config.maxCashbackLimit.toString())
              : '0';

          // Bonus points
          _bonusPointsEnabled = config.bonusPointsEnabled;
          _bonusPointsAmountCtrl.text = config.bonusPointsAmount > 0
              ? (config.bonusPointsAmount == config.bonusPointsAmount.toInt()
                  ? config.bonusPointsAmount.toInt().toString()
                  : config.bonusPointsAmount.toString())
              : '100';

          if (config.rewardStages.isNotEmpty) {
            _rewardStages = List.from(config.rewardStages);
          }
        });
      }
    } catch (_) {
      // Background fetch error handled gracefully without blocking UI
    }
  }

  // --- Step Forward when Next clicked ---
  void _handleNext() {
    if (_programNameCtrl.text.trim().isEmpty) {
      setState(() => _programNameError = 'Program name cannot be empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a program name.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _programNameError = null);

    if (_activeStep < _stepTitles.length - 1) {
      setState(() {
        _activeStep++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Step moved to ${_stepTitles[_activeStep]}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          backgroundColor: _primaryThemeColor,
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _saveAndComplete();
    }
  }

  Future<void> _saveAndComplete() async {
    setState(() => _isSaving = true);

    final minSpend = _minSpendConditionEnabled
        ? (double.tryParse(_minSpendConditionCtrl.text.trim()) ?? 0.0)
        : (double.tryParse(_minPurchaseCtrl.text.trim()) ?? 100.0);

    final config = VisitRewardConfig(
      programName: _programNameCtrl.text.trim(),
      slogan: _sloganCtrl.text.trim(),
      visitTrigger: 'Every Visit',
      triggerMinSpend: minSpend,
      visitCount: _rewardStages.isNotEmpty ? _rewardStages.first.visitCount : 300,
      rewardType: _rewardStages.isNotEmpty ? _rewardStages.first.rewardType : 'Redeem cash discount',
      rewardValue: 100.0,
      minimumPurchase: minSpend,
      rewardStages: _rewardStages,
      bannerImageUrl: _bannerImagePath,
      logoUrl: _logoUrl,
      orderType: _selectedOrderTypes.join(', '),
      termsNote: _termsCtrl.text.trim().isNotEmpty
          ? _termsCtrl.text.trim()
          : 'Terms and conditions apply.\nNo minimum purchase limit. 2 offers cannot be clubbed.',
      minSpendConditionEnabled: _minSpendConditionEnabled,
      minSpendCondition: double.tryParse(_minSpendConditionCtrl.text.trim()) ?? 0.0,
      maxCashbackLimitEnabled: _maxCashbackLimitEnabled,
      maxCashbackLimit: double.tryParse(_maxCashbackLimitCtrl.text.trim()) ?? 0.0,
      bonusPointsEnabled: _bonusPointsEnabled,
      bonusPointsAmount: double.tryParse(_bonusPointsAmountCtrl.text.trim()) ?? 100.0,
      bonusRequiredFields: const ['name', 'phone', 'gender', 'birthday', 'anniversary'],
    );

    await _loyaltyService.saveVisitRewardConfig(config);

    if (mounted) {
      setState(() => _isSaving = false);
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 36),
              ),
              const SizedBox(height: 14),
              const Text(
                'Loyalty Program Saved!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Your loyalty program settings for "${_programNameCtrl.text}" are saved and active.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryThemeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onCompleted?.call();
                    Navigator.pop(context);
                  },
                  child: const Text('Go to Loyalty Hub',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Pick Image From Gallery ---
  Future<void> _pickImageFromGallery({required bool isBanner}) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: isBanner ? 1920 : 512,
        maxHeight: isBanner ? 1080 : 512,
        imageQuality: 85,
      );

      if (picked != null && mounted) {
        setState(() {
          if (isBanner) {
            _bannerImagePath = picked.path;
          } else {
            _logoUrl = picked.path;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBanner ? 'Banner image selected!' : 'Logo updated successfully!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            backgroundColor: _primaryThemeColor,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open gallery: $e',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  // --- Multi-select Toggle ---
  void _toggleOrderType(String type) {
    setState(() {
      if (_selectedOrderTypes.contains(type)) {
        if (_selectedOrderTypes.length > 1) {
          _selectedOrderTypes.remove(type);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('At least one order type must be selected.',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
              backgroundColor: _primaryThemeColor,
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _selectedOrderTypes.add(type);
      }
    });
  }

  // --- Add / Edit Stage Modal (Matching media_1787949630097.png, media_1787949831491.png, media_1787949964231.png) ---
  void _openAddEditStageModal({RewardStageModel? existingStage, int? index}) {
    final pointsRequiredCtrl = TextEditingController(
      text: existingStage != null
          ? existingStage.visitCount.toString()
          : (_rewardStages.isNotEmpty ? (_rewardStages.last.visitCount + 200).toString() : '300'),
    );

    final rewardTypeOptions = [
      'Redeem cash discount',
      'Redeem % discount',
      'Redeem a free item',
    ];

    String selectedRewardType = 'Redeem cash discount';
    if (existingStage != null) {
      final raw = existingStage.rewardType.toLowerCase();
      if (raw.contains('%') || raw.contains('percent')) {
        selectedRewardType = 'Redeem % discount';
      } else if (raw.contains('free')) {
        selectedRewardType = 'Redeem a free item';
      } else {
        selectedRewardType = 'Redeem cash discount';
      }
    }

    final stageValueCtrl = TextEditingController(
      text: existingStage != null ? existingStage.rewardValue.toInt().toString() : '100',
    );

    String selectedScope = (selectedRewardType == 'Redeem a free item')
        ? 'Chosen products'
        : (existingStage?.discountScope ?? 'Whole bill');

    bool minSpendRedemptionEnabled = existingStage?.minSpendRedemptionEnabled ?? false;
    final stageMinSpendCtrl = TextEditingController(
      text: existingStage != null
          ? (existingStage.minimumPurchase > 0 ? existingStage.minimumPurchase.toInt().toString() : '0')
          : '0',
    );

    final stageTitleCtrl = TextEditingController(
      text: existingStage?.freeItemName.isNotEmpty == true
          ? existingStage!.freeItemName
          : (selectedRewardType == 'Redeem % discount'
              ? 'Cheers ! 10% Off On Your Purchase.'
              : (selectedRewardType == 'Redeem a free item'
                  ? 'Cheers ! Enjoy a free item.'
                  : 'Cheers ! Rs 100 Off On Your Purchase.')),
    );

    // Selected product IDs for "Chosen products" or "Redeem a free item"
    List<String> selectedItemIds = List.from(existingStage?.applicableProductIds ?? []);
    bool isProductDropdownOpen = false;
    bool isRewardTypeDropdownOpen = false;
    String productSearchQuery = '';

    // Load available menu items / products from DatabaseService and flatten variants with full price & name
    final List<MenuItemModel> rawMenuItems = DatabaseService().menuItems;
    final List<SelectableProductItem> allSelectableProducts = [];

    for (final item in rawMenuItems) {
      if (item.variants.isNotEmpty) {
        for (final v in item.variants) {
          final vPrice = v.effectivePrice > 0
              ? v.effectivePrice
              : (v.price > 0 ? v.price : (item.effectivePrice > 0 ? item.effectivePrice : 50.0));
          allSelectableProducts.add(
            SelectableProductItem(
              id: '${item.id}_${v.name.replaceAll(' ', '_')}',
              displayName: '${item.name} (${v.name})',
              price: vPrice,
            ),
          );
        }
      } else {
        final iPrice = item.effectivePrice > 0
            ? item.effectivePrice
            : (item.price > 0 ? item.price : 50.0);
        allSelectableProducts.add(
          SelectableProductItem(
            id: item.id,
            displayName: item.name,
            price: iPrice,
          ),
        );
      }
    }

    // Fallback catalog if menu is empty
    if (allSelectableProducts.isEmpty) {
      allSelectableProducts.addAll([
        SelectableProductItem(id: 'p1', displayName: 'Container5', price: 5.0),
        SelectableProductItem(id: 'p2', displayName: 'Container7', price: 7.0),
        SelectableProductItem(id: 'p3', displayName: 'A Mineral Water 500ml', price: 10.0),
        SelectableProductItem(id: 'p4', displayName: 'Container10', price: 10.0),
        SelectableProductItem(id: 'p5', displayName: 'Pav Single', price: 14.0),
        SelectableProductItem(id: 'p6', displayName: 'Jira Soda (250ml)', price: 15.0),
        SelectableProductItem(id: 'p7_r', displayName: 'Veg Burger (Regular)', price: 60.0),
        SelectableProductItem(id: 'p7_m', displayName: 'Veg Burger (Medium)', price: 90.0),
        SelectableProductItem(id: 'p7_l', displayName: 'Veg Burger (Large)', price: 120.0),
        SelectableProductItem(id: 'p8_h', displayName: 'Cold Coffee (Half)', price: 40.0),
        SelectableProductItem(id: 'p8_f', displayName: 'Cold Coffee (Full)', price: 70.0),
      ]);
    }

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (modalCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isFreeItem = selectedRewardType == 'Redeem a free item';
          final isPercent = selectedRewardType == 'Redeem % discount';
          final showProductPicker = isFreeItem || selectedScope == 'Chosen products';

          // Filter products based on search query
          final filteredProducts = allSelectableProducts.where((p) {
            if (productSearchQuery.isEmpty) return true;
            return p.displayName.toLowerCase().contains(productSearchQuery.toLowerCase());
          }).toList();

          // Summary string of chosen items
          final chosenItems = allSelectableProducts.where((p) => selectedItemIds.contains(p.id)).toList();
          final String chosenSummaryText;
          if (chosenItems.isEmpty) {
            chosenSummaryText = 'Choose Item';
          } else if (chosenItems.length == 1) {
            final item = chosenItems.first;
            chosenSummaryText = '${item.displayName} (₹${item.price.toStringAsFixed(2)})';
          } else {
            chosenSummaryText = '${chosenItems.length} Items Selected';
          }

          return Container(
            padding:
                EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingStage != null ? 'Edit Reward Stage' : 'Add Reward Stage',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                        onPressed: () => Navigator.pop(modalCtx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFE2E8F0), height: 16),

                  // 1. Points required to claim
                  const Text(
                    'Points required to claim',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: pointsRequiredCtrl,
                      keyboardType: TextInputType.number,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      cursorColor: _primaryThemeColor,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Select reward type (100% visible custom curved selector matching media_1787949630097.png)
                  const Text(
                    'Select reward type',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _primaryThemeColor, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setModalState(() => isRewardTypeDropdownOpen = !isRewardTypeDropdownOpen),
                          borderRadius: BorderRadius.circular(11),
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedRewardType,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _primaryThemeColor,
                                  ),
                                ),
                                Icon(
                                  isRewardTypeDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                  color: _primaryThemeColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isRewardTypeDropdownOpen) ...[
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          ...rewardTypeOptions.map((type) {
                            final isSel = selectedRewardType == type;
                            return InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedRewardType = type;
                                  isRewardTypeDropdownOpen = false;

                                  if (type == 'Redeem a free item') {
                                    selectedScope = 'Chosen products';
                                    final chosenNames = allSelectableProducts
                                        .where((p) => selectedItemIds.contains(p.id))
                                        .map((p) => p.displayName)
                                        .join(', ');
                                    stageTitleCtrl.text = chosenNames.isNotEmpty
                                        ? 'Cheers ! Free $chosenNames'
                                        : 'Cheers ! Enjoy a free item.';
                                  } else if (type == 'Redeem % discount') {
                                    final val = stageValueCtrl.text.trim().isNotEmpty ? stageValueCtrl.text.trim() : '10';
                                    stageTitleCtrl.text = 'Cheers ! $val% Off On Your Purchase.';
                                  } else {
                                    final val = stageValueCtrl.text.trim().isNotEmpty ? stageValueCtrl.text.trim() : '100';
                                    stageTitleCtrl.text = 'Cheers ! Rs $val Off On Your Purchase.';
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                color: isSel ? _primaryThemeColor.withValues(alpha: 0.06) : Colors.transparent,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      type,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w500,
                                        color: isSel ? _primaryThemeColor : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (isSel)
                                      const Icon(Icons.check, size: 16, color: _primaryThemeColor),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Discount Amount / Percentage Field (Hidden for Free Item, in Header Theme Navy Color)
                  if (!isFreeItem) ...[
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primaryThemeColor, width: 1.2),
                      ),
                      child: TextField(
                        controller: stageValueCtrl,
                        keyboardType: TextInputType.number,
                        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        cursorColor: _primaryThemeColor,
                        onChanged: (val) {
                          setModalState(() {
                            if (isPercent) {
                              stageTitleCtrl.text = 'Cheers ! $val% Off On Your Purchase.';
                            } else {
                              stageTitleCtrl.text = 'Cheers ! Rs $val Off On Your Purchase.';
                            }
                          });
                        },
                        decoration: InputDecoration(
                          labelText: isPercent ? 'Discount Percentage (%)' : 'Discount Amount (₹)',
                          labelStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                          prefixText: isPercent ? null : '₹ ',
                          suffixText: isPercent ? '%' : null,
                          prefixStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                          ),
                          suffixStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 4. Scope Segment (Whole bill vs Chosen products in Header Theme Navy Color)
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _primaryThemeColor, width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: isFreeItem ? null : () => setModalState(() => selectedScope = 'Whole bill'),
                              child: Container(
                                alignment: Alignment.center,
                                color: selectedScope == 'Whole bill'
                                    ? _primaryThemeColor
                                    : Colors.white,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (selectedScope == 'Whole bill') ...[
                                      const Icon(Icons.check, size: 14, color: Colors.white),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      'Whole bill',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: selectedScope == 'Whole bill'
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        color: selectedScope == 'Whole bill'
                                            ? Colors.white
                                            : const Color(0xFF334155),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(width: 1, color: _primaryThemeColor.withValues(alpha: 0.3)),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => selectedScope = 'Chosen products'),
                              child: Container(
                                alignment: Alignment.center,
                                color: selectedScope == 'Chosen products'
                                    ? _primaryThemeColor
                                    : Colors.white,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (selectedScope == 'Chosen products') ...[
                                      const Icon(Icons.check, size: 14, color: Colors.white),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      'Chosen products',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: selectedScope == 'Chosen products'
                                            ? FontWeight.w900
                                            : FontWeight.w600,
                                        color: selectedScope == 'Chosen products'
                                            ? Colors.white
                                            : const Color(0xFF334155),
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
                  ),
                  const SizedBox(height: 12),

                  // 5. Choose Item Dropdown (Variants & Prices Never 0, Matching media_1787949831491.png & media_1787949964231.png)
                  if (showProductPicker) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => setModalState(() => isProductDropdownOpen = !isProductDropdownOpen),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _primaryThemeColor,
                                width: isProductDropdownOpen ? 1.8 : 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    chosenSummaryText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: chosenItems.isNotEmpty ? FontWeight.w800 : FontWeight.w500,
                                      color: chosenItems.isNotEmpty ? _primaryThemeColor : const Color(0xFF64748B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  isProductDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                  color: _primaryThemeColor,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Dropdown Items List with Checkboxes & Variant Prices (media_1787949964231.png)
                        if (isProductDropdownOpen) ...[
                          const SizedBox(height: 4),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 190),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _primaryThemeColor.withValues(alpha: 0.35)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Search bar inside dropdown
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                                  child: Container(
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextField(
                                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
                                      cursorColor: _primaryThemeColor,
                                      decoration: const InputDecoration(
                                        hintText: 'Search products & variants...',
                                        hintStyle: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                        prefixIcon: Icon(Icons.search, size: 14, color: Color(0xFF94A3B8)),
                                        prefixIconConstraints: BoxConstraints(minWidth: 22),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(vertical: 7),
                                      ),
                                      onChanged: (q) => setModalState(() => productSearchQuery = q),
                                    ),
                                  ),
                                ),
                                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                                // Product List with Checkbox & Non-Zero Price
                                Flexible(
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    itemCount: filteredProducts.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (ctx, pIdx) {
                                      final prod = filteredProducts[pIdx];
                                      final isChecked = selectedItemIds.contains(prod.id);

                                      return InkWell(
                                        onTap: () {
                                          setModalState(() {
                                            if (isChecked) {
                                              selectedItemIds.remove(prod.id);
                                            } else {
                                              selectedItemIds.add(prod.id);
                                            }

                                            // Auto-update reward title if free item
                                            if (isFreeItem) {
                                              final selectedProds = allSelectableProducts
                                                  .where((p) => selectedItemIds.contains(p.id))
                                                  .map((p) => p.displayName)
                                                  .join(', ');
                                              stageTitleCtrl.text = selectedProds.isNotEmpty
                                                  ? 'Cheers ! Free $selectedProds'
                                                  : 'Cheers ! Enjoy a free item.';
                                            }
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          color: isChecked ? _primaryThemeColor.withValues(alpha: 0.06) : Colors.transparent,
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  color: isChecked ? _primaryThemeColor : Colors.white,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: isChecked ? _primaryThemeColor : const Color(0xFF94A3B8),
                                                    width: 1.2,
                                                  ),
                                                ),
                                                child: isChecked
                                                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                                                    : null,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  '${prod.displayName} (₹${prod.price.toStringAsFixed(2)})',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: isChecked ? FontWeight.w800 : FontWeight.w500,
                                                    color: isChecked ? _primaryThemeColor : const Color(0xFF334155),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
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
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 6. Set minimum spend for redemption Box (Matching media_1787948985353.png)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: minSpendRedemptionEnabled
                            ? _primaryThemeColor
                            : const Color(0xFFE2E8F0),
                        width: minSpendRedemptionEnabled ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Set minimum spend for redemption',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            InkWell(
                              onTap: () => setModalState(() =>
                                  minSpendRedemptionEnabled = !minSpendRedemptionEnabled),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: minSpendRedemptionEnabled
                                      ? _primaryThemeColor
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: minSpendRedemptionEnabled
                                        ? _primaryThemeColor
                                        : const Color(0xFF94A3B8),
                                    width: 1.5,
                                  ),
                                ),
                                child: minSpendRedemptionEnabled
                                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Define the lowest purchase amount required for using the reward.',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: minSpendRedemptionEnabled
                                  ? _primaryThemeColor
                                  : const Color(0xFFCBD5E1),
                              width: minSpendRedemptionEnabled ? 1.5 : 1.0,
                            ),
                          ),
                          child: TextField(
                            controller: stageMinSpendCtrl,
                            keyboardType: TextInputType.number,
                            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                            cursorColor: _primaryThemeColor,
                            decoration: const InputDecoration(
                              prefixText: '₹ ',
                              prefixStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                fontSize: 12.5,
                              ),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 7. Reward title
                  const Text(
                    'Reward title',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: stageTitleCtrl,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      cursorColor: _primaryThemeColor,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryThemeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final visits = int.tryParse(pointsRequiredCtrl.text.trim()) ?? 300;
                        final val = double.tryParse(stageValueCtrl.text.trim()) ?? 100.0;
                        final minSpend = minSpendRedemptionEnabled
                            ? (double.tryParse(stageMinSpendCtrl.text.trim()) ?? 0.0)
                            : 0.0;

                        final selectedProductsList = allSelectableProducts.where((p) => selectedItemIds.contains(p.id)).toList();
                        final itemsSummary = selectedProductsList.isNotEmpty
                            ? selectedProductsList.map((p) => p.displayName).join(', ')
                            : '';

                        String finalTitle = stageTitleCtrl.text.trim();
                        if (finalTitle.isEmpty) {
                          if (selectedRewardType == 'Redeem a free item') {
                            finalTitle = itemsSummary.isNotEmpty ? 'Cheers ! Free $itemsSummary' : 'Cheers ! Free Item';
                          } else if (selectedRewardType == 'Redeem % discount') {
                            finalTitle = 'Cheers ! ${val.toInt()}% Off On Your Purchase.';
                          } else {
                            finalTitle = 'Cheers ! Rs ${val.toInt()} Off On Your Purchase.';
                          }
                        }

                        final newStage = RewardStageModel(
                          id: existingStage?.id ??
                              'stage_${DateTime.now().millisecondsSinceEpoch}',
                          visitCount: visits,
                          rewardType: selectedRewardType,
                          rewardValue: val,
                          minimumPurchase: minSpend,
                          freeItemName: finalTitle,
                          discountScope: selectedScope,
                          minSpendRedemptionEnabled: minSpendRedemptionEnabled,
                          applicableProductIds: selectedItemIds,
                        );

                        setState(() {
                          if (index != null && index >= 0 && index < _rewardStages.length) {
                            _rewardStages[index] = newStage;
                          } else {
                            _rewardStages.add(newStage);
                          }
                          _rewardStages.sort((a, b) => a.visitCount.compareTo(b.visitCount));
                        });

                        Navigator.pop(modalCtx);
                      },
                      child: Text(
                        existingStage != null ? 'Update Stage' : 'Add Stage',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openUnsplashPicker() {
    final List<Map<String, String>> photos = [
      {
        'title': 'Restaurant Food Table',
        'url': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800',
      },
      {
        'title': 'Delicious Burger & Fries',
        'url': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?q=80&w=800',
      },
      {
        'title': 'Italian Pizza Slices',
        'url': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?q=80&w=800',
      },
      {
        'title': 'Dessert & Bakery',
        'url': 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?q=80&w=800',
      },
      {
        'title': 'Cafe Coffee & Drinks',
        'url': 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?q=80&w=800',
      },
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      backgroundColor: Colors.white,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Banner from Unsplash',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, idx) {
                  final photo = photos[idx];
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _bannerImagePath = photo['url']!;
                      });
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          Image.network(
                            photo['url']!,
                            width: 140,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.65),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              child: Text(
                                photo['title']!,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
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
    );
  }

  void _openColorPresetPicker({required String target}) {
    final List<Map<String, dynamic>> presets = [
      {
        'name': 'Burgundy & Magenta',
        'start': const Color(0xFF4A082F),
        'end': const Color(0xFF8E1449)
      },
      {'name': 'Deep Navy & Blue', 'start': const Color(0xFF082559), 'end': const Color(0xFF1E3A8A)},
      {'name': 'Emerald & Mint', 'start': const Color(0xFF064E3B), 'end': const Color(0xFF059669)},
      {'name': 'Golden & Bronze', 'start': const Color(0xFF78350F), 'end': const Color(0xFFD97706)},
      {'name': 'Ruby Red & Coral', 'start': const Color(0xFF881337), 'end': const Color(0xFFE11D48)},
      {'name': 'Dark Slate & Grey', 'start': const Color(0xFF0F172A), 'end': const Color(0xFF334155)},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      backgroundColor: Colors.white,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select $target Colors',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            ...presets.map((preset) {
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                leading: Container(
                  width: 40,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                        colors: [preset['start'] as Color, preset['end'] as Color]),
                    border: Border.all(color: _primaryThemeColor, width: 1.2),
                  ),
                ),
                title: Text(preset['name'] as String,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                onTap: () {
                  setState(() {
                    if (target == 'Background') {
                      _bgGradientStart = preset['start'] as Color;
                      _bgGradientEnd = preset['end'] as Color;
                    } else if (target == 'Reward') {
                      _rewardColorStart = preset['start'] as Color;
                      _rewardColorEnd = preset['end'] as Color;
                    } else {
                      _bodyTextColor = preset['end'] as Color;
                    }
                  });
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletLandscape = screenWidth >= 950;

    return Scaffold(
      backgroundColor: _primaryThemeColor,
      resizeToAvoidBottomInset: true,
      body: Container(
        color: _primaryThemeColor,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Top Header in Dark Navy
              _buildTopHeader(),

                    // Main Content Sheet with Semi-Circular Top Curve
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFAFAFC),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // 6-Step Progress Stepper Header Bar seamlessly positioned at the top of curved sheet
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 4),
                                  _buildProgressStepper(),
                                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                                ],
                              ),
                            ),

                            // Main Scrollable Content with smooth keyboard dismiss behavior
                            Expanded(
                              child: SingleChildScrollView(
                                controller: _mainScrollController,
                                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: isTabletLandscape ? 1150 : 640,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Step 1: Edit Bonus Screen (media_1787952853197.png)
                                        if (_activeStep == 1)
                                          _buildEditBonusScreen()
                                        // Step 2: Edit Channel Screen (media_1787953660666.png)
                                        else if (_activeStep == 2)
                                          _buildEditChannelScreen()
                                        // Step 3: Done Screen
                                        else if (_activeStep == 3)
                                          _buildDoneScreen()
                                        else if (isTabletLandscape)
                                          // Tablet / Desktop: Two columns
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 5,
                                                child: Column(
                                                  children: [
                                                    _buildSectionTabs(),
                                                    const SizedBox(height: 10),
                                                    _buildLiveLoyaltyPreview(),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 20),
                                              Expanded(
                                                  flex: 6, child: _buildActiveConfigurationFields()),
                                            ],
                                          )
                                        else
                                          // Mobile: Fields First, Then Section Tabs Placed Directly Upon Preview Card
                                          Column(
                                            children: [
                                              _buildActiveConfigurationFields(),
                                              const SizedBox(height: 18),
                                              // Tabs Placed Directly Upon Preview
                                              _buildSectionTabs(),
                                              const SizedBox(height: 10),
                                              _buildLiveLoyaltyPreview(),
                                            ],
                                          ),

                                        const SizedBox(height: 24),
                                      ],
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
            ),
    );
  }

  // --- 1. TOP HEADER (Edit Theme & Enriched Next > button in App Theme Navy Color) ---
  Widget _buildTopHeader() {
    final currentTitle = _stepTitles[_activeStep];
    final isLastStep = _activeStep == _stepTitles.length - 1;

    return Container(
      color: _primaryThemeColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Step ${_activeStep + 1} of ${_stepTitles.length}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _primaryThemeColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8.5),
              elevation: 1,
              shadowColor: Colors.black26,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: _primaryThemeColor, strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLastStep ? 'Done' : 'Next',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _primaryThemeColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (!isLastStep) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: _primaryThemeColor),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // --- 2. PROGRESS STEPPER in App Header Navy Color (Theme, Bonus, Channel, Done) ---
  Widget _buildProgressStepper() {
    final steps = [
      {'title': 'Edit Theme', 'icon': Icons.palette_outlined},
      {'title': 'Edit Bonus', 'icon': Icons.card_giftcard_rounded},
      {'title': 'Edit Channel', 'icon': Icons.alt_route_rounded},
      {'title': 'Done', 'icon': Icons.check_circle_outline_rounded},
    ];

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(steps.length, (index) {
            final step = steps[index];
            final isActive = _activeStep == index;
            final isCompleted = _activeStep > index;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _activeStep = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? _primaryThemeColor
                              : (isActive ? Colors.white : const Color(0xFFF8FAFC)),
                          border: Border.all(
                            color: (isActive || isCompleted)
                                ? _primaryThemeColor
                                : const Color(0xFFCBD5E1),
                            width: isActive ? 2 : 1.5,
                          ),
                        ),
                        child: Icon(
                          isCompleted ? Icons.check_rounded : (step['icon'] as IconData),
                          size: 16,
                          color: isCompleted
                              ? Colors.white
                              : (isActive ? _primaryThemeColor : const Color(0xFF94A3B8)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step['title'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                          color: (isActive || isCompleted)
                              ? _primaryThemeColor
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 38,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 14, left: 6, right: 6),
                    color: isCompleted ? _primaryThemeColor : const Color(0xFFE2E8F0),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // --- 3. SUBTITLE TEXT BANNER ---
  // Widget _buildIntroSubtitle() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 10),
  //     child: RichText(
  //       textAlign: TextAlign.center,
  //       text: const TextSpan(
  //         style: TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.35),
  //         children: [
  //           TextSpan(text: "We've designed a loyalty program just for you! "),
  //           TextSpan(
  //             text: "Feel free to review and make any changes",
  //             style: TextStyle(fontWeight: FontWeight.w900, color: _primaryThemeColor),
  //           ),
  //           TextSpan(text: " to suit your needs."),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // --- 4. SECTION TABS (Theme, Points, Rewards, Terms) ---
  Widget _buildSectionTabs() {
    final navItems = [
      {'label': 'Theme', 'icon': Icons.palette_outlined},
      {'label': 'Points', 'icon': Icons.toll_rounded},
      {'label': 'Rewards', 'icon': Icons.card_giftcard_rounded},
      {'label': 'Terms', 'icon': Icons.description_outlined},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _primaryThemeColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(navItems.length, (idx) {
          final item = navItems[idx];
          final isSel = _activeSectionTab == idx;

          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() => _activeSectionTab = idx);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: isSel ? _primaryThemeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 16,
                      color: isSel ? Colors.white : _primaryThemeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w700,
                        color: isSel ? Colors.white : _primaryThemeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- 5. DYNAMIC CONFIGURATION SWITCHER ---
  Widget _buildActiveConfigurationFields() {
    switch (_activeSectionTab) {
      case 1:
        return _buildPointsConfigurationFields();
      case 2:
        return _buildRewardsConfigurationFields();
      case 3:
        return _buildTermsConfigurationFields();
      case 0:
      default:
        return _buildThemeConfigurationFields();
    }
  }

  // --- TAB 0: REDESIGNED THEME SECTION ---
  Widget _buildThemeConfigurationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Order Type Box
        _buildBoxContainer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Order Type:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primaryThemeColor, width: 1.2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Row(
                      children: [
                        _buildOrderTypeSegmentPill('Delivery'),
                        Container(width: 1, color: _primaryThemeColor.withValues(alpha: 0.3)),
                        _buildOrderTypeSegmentPill('Take-Away', label: 'Take Away'),
                        Container(width: 1, color: _primaryThemeColor.withValues(alpha: 0.3)),
                        _buildOrderTypeSegmentPill('Dine-In', label: 'Dine In'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Banner Image & Unsplash Box
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        children: [
                          TextSpan(text: 'Explore Free Photos on Unsplash '),
                          TextSpan(
                            text: 'NEW',
                            style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _openUnsplashPicker,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryThemeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Try Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const Divider(color: Color(0xFFE2E8F0), height: 14),
              const Text(
                'Banner Image',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _pickImageFromGallery(isBanner: true),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _primaryThemeColor,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primaryThemeColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_photo_alternate_outlined, color: _primaryThemeColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Recommended size 512 x 512 px in JPG, GIF or PNG format up-to max size of 5MB.',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                            height: 1.25,
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
        const SizedBox(height: 10),

        // 3. Logo Box
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Logo',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _pickImageFromGallery(isBanner: false),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _primaryThemeColor,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primaryThemeColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_photo_alternate_outlined, color: _primaryThemeColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'For optimal display, use a 512x512px image in JPG, PNG, or SVG format (max 5MB).',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                            height: 1.25,
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
        const SizedBox(height: 10),

        // 4. Background Color Box
        _buildBoxContainer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Background Color',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              InkWell(
                onTap: () => _openColorPresetPicker(target: 'Background'),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _bgGradientStart,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _primaryThemeColor, width: 1.2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 48,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _bgGradientEnd,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _primaryThemeColor, width: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 5. Reward Color Box
        _buildBoxContainer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reward Color',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              InkWell(
                onTap: () => _openColorPresetPicker(target: 'Reward'),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _rewardColorStart,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _primaryThemeColor, width: 1.2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 48,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _rewardColorEnd,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _primaryThemeColor, width: 1.2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 6. Body Text Color Box
        _buildBoxContainer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Body Text color',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              InkWell(
                onTap: () => _openColorPresetPicker(target: 'Text'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 48,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _bodyTextColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _primaryThemeColor, width: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 7. Loyalty Program Naming Box
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What would you name your loyalty program to\nreward your customers?',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _programNameCtrl,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: _primaryThemeColor,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Header*',
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                  errorText: _programNameError,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryThemeColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _sloganCtrl,
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: _primaryThemeColor,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Subtitle*',
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryThemeColor, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 1: POINTS SECTION (Without Point Earning Gap) ---
  Widget _buildPointsConfigurationFields() {
    final timesVisit = _timesCustomerVisitCtrl.text.trim().isNotEmpty
        ? _timesCustomerVisitCtrl.text.trim()
        : '1';
    final earnsCookies = _customerEarnsPointsCtrl.text.trim().isNotEmpty
        ? _customerEarnsPointsCtrl.text.trim()
        : '10';
    final pointsName = _currentPointsName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Visit & Points Earning Core Box
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Number of times customer Visit*',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _timesCustomerVisitCtrl,
                  keyboardType: TextInputType.number,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  cursorColor: _primaryThemeColor,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Text(_currentPointsEmoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    'Number of customer earns $pointsName*',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _customerEarnsPointsCtrl,
                  keyboardType: TextInputType.number,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  cursorColor: _primaryThemeColor,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Points Conversion Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F8F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primaryThemeColor, width: 1.2),
          ),
          child: Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
                children: [
                  const TextSpan(text: 'Customers '),
                  TextSpan(
                    text: 'Earn $timesVisit Visit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _primaryThemeColor,
                    ),
                  ),
                  const TextSpan(text: ' for every '),
                  TextSpan(
                    text: '$earnsCookies $pointsName $_currentPointsEmoji',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _primaryThemeColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 3. Point Branding Box
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Point Branding',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: _pointBrandingEnabled,
                      activeThumbColor: Colors.white,
                      activeTrackColor: _primaryThemeColor,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                      onChanged: (val) {
                        setState(() => _pointBrandingEnabled = val);
                      },
                    ),
                  ),
                ],
              ),
              const Text(
                'Choose a plural name for your points',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),

              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _pointsNameCtrl,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  cursorColor: _primaryThemeColor,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  _buildPointPresetChip(0, '🍪', 'Cookie'),
                  const SizedBox(width: 6),
                  _buildPointPresetChip(1, '🌶️', 'Chilly'),
                  const SizedBox(width: 6),
                  _buildPointPresetChip(2, '⭐', 'Star'),
                  const SizedBox(width: 6),
                  _buildPointPresetChip(3, '🪙', 'Coin'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 4. Minimum Spend Condition Box
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Minimum Spend Condition',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: _minSpendConditionEnabled,
                      activeThumbColor: Colors.white,
                      activeTrackColor: _primaryThemeColor,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                      onChanged: (val) {
                        setState(() => _minSpendConditionEnabled = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Define the minimum bill amount required for a customer to earn points.',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF64748B),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _minSpendConditionEnabled ? _primaryThemeColor : const Color(0xFFCBD5E1),
                    width: _minSpendConditionEnabled ? 1.5 : 1.0,
                  ),
                ),
                child: TextField(
                  controller: _minSpendConditionCtrl,
                  keyboardType: TextInputType.number,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  cursorColor: _primaryThemeColor,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 5. Maximum Cashback Limit Box
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Maximum Cashback Limit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: _maxCashbackLimitEnabled,
                      activeThumbColor: Colors.white,
                      activeTrackColor: _primaryThemeColor,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFCBD5E1),
                      onChanged: (val) {
                        setState(() => _maxCashbackLimitEnabled = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _maxCashbackLimitEnabled ? _primaryThemeColor : const Color(0xFFCBD5E1),
                    width: _maxCashbackLimitEnabled ? 1.5 : 1.0,
                  ),
                ),
                child: TextField(
                  controller: _maxCashbackLimitCtrl,
                  keyboardType: TextInputType.number,
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  cursorColor: _primaryThemeColor,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      fontSize: 13,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPointPresetChip(int index, String emoji, String name) {
    final isSelected = _selectedPointPresetIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPointPresetIndex = index;
            _pointsNameCtrl.text = name;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? _primaryThemeColor : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? _primaryThemeColor : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 2: REWARDS CONFIGURATION (Redesigned with Curved Highlighted Boxes) ---
  Widget _buildRewardsConfigurationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Configured Reward Stages (${_rewardStages.length})',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryThemeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _openAddEditStageModal(),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Add Stage',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._rewardStages.map((stage) {
                final idx = _rewardStages.indexOf(stage);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _primaryThemeColor.withValues(alpha: 0.35), width: 1.2),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => _openAddEditStageModal(existingStage: stage, index: idx),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: _primaryThemeColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: _primaryThemeColor, width: 1.2),
                              ),
                              child: Center(
                                child: Text(_currentPointsEmoji, style: const TextStyle(fontSize: 14)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${stage.visitCount} $_currentPointsName  •  ${stage.rewardDisplayTitle}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    stage.freeItemName,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF64748B),
                                      height: 1.25,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Circular Edit Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    _openAddEditStageModal(existingStage: stage, index: idx),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _primaryThemeColor.withValues(alpha: 0.08),
                                  ),
                                  child: const Icon(Icons.edit_outlined, size: 15, color: _primaryThemeColor),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Circular Delete Button
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (_rewardStages.length > 1) {
                                    setState(() => _rewardStages.removeAt(idx));
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('At least one reward stage must be kept.'),
                                        backgroundColor: Color(0xFFEF4444),
                                      ),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFFEE2E2),
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 3: TERMS CONFIGURATION (Matching media_1787951020034.png) ---
  Widget _buildTermsConfigurationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Edit Terms & Conditions Box
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit Terms & Conditions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primaryThemeColor, width: 1.2),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom Terms',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _termsCtrl,
                      maxLines: 4,
                      minLines: 2,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                      cursorColor: _primaryThemeColor,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Preset Terms & Conditions Box (Matching media_1787951020034.png)
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Terms & Conditions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),

              _buildTermPresetCheckbox(
                title: 'No minimum purchase limit.',
                isChecked: _termNoMinLimit,
                onChanged: (val) {
                  _termNoMinLimit = val;
                  _rebuildTermsText();
                },
              ),
              const SizedBox(height: 8),

              _buildTermPresetCheckbox(
                title: '2 offers cannot be clubbed.',
                isChecked: _termNoClubbing,
                onChanged: (val) {
                  _termNoClubbing = val;
                  _rebuildTermsText();
                },
              ),
              const SizedBox(height: 8),

              _buildTermPresetCheckbox(
                title: 'Not redeemable on public holidays.',
                isChecked: _termNoHolidays,
                onChanged: (val) {
                  _termNoHolidays = val;
                  _rebuildTermsText();
                },
              ),
              const SizedBox(height: 8),

              _buildTermPresetCheckbox(
                title: 'Reward redeemable in-store only.',
                isChecked: _termInStoreOnly,
                onChanged: (val) {
                  _termInStoreOnly = val;
                  _rebuildTermsText();
                },
              ),
              const SizedBox(height: 8),

              _buildTermPresetCheckbox(
                title: 'custom add',
                isChecked: _termCustom,
                onChanged: (val) {
                  _termCustom = val;
                  _rebuildTermsText();
                },
              ),

              if (_termCustom) ...[
                const SizedBox(height: 8),
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primaryThemeColor, width: 1.2),
                  ),
                  child: TextField(
                    controller: _customTermCtrl,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    cursorColor: _primaryThemeColor,
                    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    onChanged: (_) => _rebuildTermsText(),
                    decoration: const InputDecoration(
                      hintText: 'Enter custom term...',
                      hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTermPresetCheckbox({
    required String title,
    required bool isChecked,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!isChecked),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isChecked ? _primaryThemeColor.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isChecked ? _primaryThemeColor : const Color(0xFFE2E8F0),
            width: isChecked ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isChecked ? _primaryThemeColor : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isChecked ? _primaryThemeColor : const Color(0xFF94A3B8),
                  width: 1.5,
                ),
              ),
              child: isChecked ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isChecked ? FontWeight.w800 : FontWeight.w600,
                  color: isChecked ? _primaryThemeColor : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 6. LIVE LOYALTY CARD PREVIEW (Updated per user specifications) ---
  Widget _buildLiveLoyaltyPreview() {
    final programName = _programNameCtrl.text.trim().isNotEmpty
        ? _programNameCtrl.text.trim()
        : 'Swaad Chowpatty';
    final slogan =
        _sloganCtrl.text.trim().isNotEmpty ? _sloganCtrl.text.trim() : 'Get rewarded on every purchase';

    final timesVisit = _timesCustomerVisitCtrl.text.trim().isNotEmpty
        ? _timesCustomerVisitCtrl.text.trim()
        : '1';
    final earnsCookies = _customerEarnsPointsCtrl.text.trim().isNotEmpty
        ? _customerEarnsPointsCtrl.text.trim()
        : '10';
    final pointsName = _currentPointsName;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgGradientStart, _bgGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _primaryThemeColor, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner Image (Cleanly visible with curved top, Theme button removed)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
              ),
              child: _bannerImagePath.startsWith('http')
                  ? Image.network(
                      _bannerImagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.restaurant_rounded, color: Colors.white30, size: 40)),
                    )
                  : File(_bannerImagePath).existsSync()
                      ? Image.file(
                          File(_bannerImagePath),
                          fit: BoxFit.cover,
                        )
                      : const Center(
                          child: Icon(Icons.restaurant_rounded, color: Colors.white30, size: 40)),
            ),
          ),

          // Floating Brand Logo Badge (Larger size 82x82, clickable to change manually)
          Transform.translate(
            offset: const Offset(0, -36),
            child: InkWell(
              onTap: () => _pickImageFromGallery(isBanner: false),
              borderRadius: BorderRadius.circular(42),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E0213),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD4AF37), width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: ClipOval(
                      child: _logoUrl.isNotEmpty && _logoUrl.startsWith('http')
                          ? Image.network(_logoUrl, fit: BoxFit.cover)
                          : _logoUrl.isNotEmpty && File(_logoUrl).existsSync()
                              ? Image.file(File(_logoUrl), fit: BoxFit.cover)
                              : Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.storefront_rounded,
                                          color: Color(0xFFD4AF37), size: 28),
                                      const SizedBox(height: 2),
                                      Text(
                                        programName.length > 10
                                            ? programName.substring(0, 10).toUpperCase()
                                            : programName.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Color(0xFFD4AF37),
                                          fontSize: 7,
                                          fontWeight: FontWeight.w900,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: _primaryThemeColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Program Title & Slogan
          Transform.translate(
            offset: const Offset(0, -24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(
                    programName,
                    style: TextStyle(
                      color: _bodyTextColor,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    slogan,
                    style: TextStyle(
                      color: _bodyTextColor.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // Dynamic Conversion text with selected emoji
                  Text(
                    '$timesVisit Visit = $earnsCookies $pointsName $_currentPointsEmoji',
                    style: TextStyle(
                      color: _bodyTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Milestone Progress Line with dynamic selected emoji
                  _buildMilestoneCookieBar(),
                  const SizedBox(height: 14),

                  // Configured Stages Cards (without ticket icon)
                  ..._rewardStages.map((stage) => _buildPreviewStageCard(stage)),
                  const SizedBox(height: 12),

                  // ADD REWARD STAGE Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _rewardColorEnd,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      onPressed: () => _openAddEditStageModal(),
                      child: const Text(
                        'ADD REWARD STAGE',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Terms Note (Dynamic from Terms section)
                  Text(
                    _termsCtrl.text.trim().isNotEmpty
                        ? _termsCtrl.text.trim()
                        : 'Terms and conditions apply.\nNo minimum purchase limit. 2 offers cannot be clubbed.',
                    style: TextStyle(
                      color: _bodyTextColor.withValues(alpha: 0.85),
                      fontSize: 10,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Dynamic Milestone Journey Progress Bar reflecting selected point emoji ---
  Widget _buildMilestoneCookieBar() {
    final stages = _rewardStages.take(3).toList();
    if (stages.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          Row(
            children: List.generate(stages.length, (idx) {
              final isLast = idx == stages.length - 1;

              return Expanded(
                flex: isLast ? 0 : 1,
                child: Row(
                  mainAxisSize: isLast ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(_currentPointsEmoji, style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stages.map((stage) {
              return Text(
                '${stage.visitCount} $_currentPointsName',
                style: TextStyle(
                  color: _bodyTextColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- Stage Card in Preview (Clean badge, Ticket icon removed, Tappable to edit) ---
  Widget _buildPreviewStageCard(RewardStageModel stage) {
    final idx = _rewardStages.indexOf(stage);
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _openAddEditStageModal(existingStage: stage, index: idx),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(_currentPointsEmoji, style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${stage.visitCount} $_currentPointsName',
                        style: TextStyle(
                          color: _bodyTextColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        stage.freeItemName.isNotEmpty
                            ? stage.freeItemName
                            : 'Cheers ! Rs ${stage.rewardValue.toInt()} off on your purchase.',
                        style: TextStyle(
                          color: _bodyTextColor.withValues(alpha: 0.85),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_outlined, color: Colors.white, size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper: Order Type Segment Pill Button ---
  Widget _buildOrderTypeSegmentPill(String typeKey, {String? label}) {
    final displayLabel = label ?? typeKey;
    final isSel = _selectedOrderTypes.contains(typeKey);

    return Expanded(
      child: InkWell(
        onTap: () => _toggleOrderType(typeKey),
        child: Container(
          alignment: Alignment.center,
          color: isSel ? _primaryThemeColor : Colors.white,
          child: Text(
            displayLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
              color: isSel ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper: Highlighted Semi-Curved Border Container Box in App Header Navy Color ---
  Widget _buildBoxContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryThemeColor, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // --- Step 1: Edit Bonus Screen (Refined Smaller Text & Prominent Button) ---
  Widget _buildEditBonusScreen() {
    final pointsName = _currentPointsName;
    final bonusAmount = _bonusPointsAmountCtrl.text.trim().isNotEmpty
        ? _bonusPointsAmountCtrl.text.trim()
        : '100';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 2),

            // 1. Transparent High-Resolution Treasure Chest Image (media_1787952853197.png)
            const TreasureChestArtwork(),
            const SizedBox(height: 8),

            // Title & Subtitle (Smaller, refined text)
            Text(
              'UNLOCK YOUR BONUS ${pointsName.toUpperCase()}!',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            const Text(
              'Share your details & sweeten the deal.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),

            // 2. Main White Rounded Configuration Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _primaryThemeColor.withValues(alpha: 0.16), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bonus Points Switch Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _primaryThemeColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(color: _primaryThemeColor.withValues(alpha: 0.2), width: 1),
                        ),
                        child: Center(
                          child: Text(_currentPointsEmoji, style: const TextStyle(fontSize: 15)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonus $pointsName',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Unlock bonus $pointsName by sharing your birthday, email, gender, and anniversary details.',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFF64748B),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: _bonusPointsEnabled,
                          activeThumbColor: Colors.white,
                          activeTrackColor: _primaryThemeColor,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFCBD5E1),
                          onChanged: (val) {
                            setState(() => _bonusPointsEnabled = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Bonus Points Amount Input Box
                  if (_bonusPointsEnabled) ...[
                    Text(
                      'Bonus $pointsName Amount',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _primaryThemeColor, width: 1.3),
                      ),
                      child: TextField(
                        controller: _bonusPointsAmountCtrl,
                        keyboardType: TextInputType.number,
                        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        cursorColor: _primaryThemeColor,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Enter the bonus ${pointsName.toLowerCase()} amount',
                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),

                    // Customer Gets Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _primaryThemeColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _primaryThemeColor.withValues(alpha: 0.2), width: 1.1),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _primaryThemeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.card_giftcard_rounded, color: _primaryThemeColor, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CUSTOMER GETS',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _primaryThemeColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Row(
                                children: [
                                  Text(
                                    bonusAmount,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(_currentPointsEmoji, style: const TextStyle(fontSize: 15.5)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 3. Info Notice Pill
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF64748B), size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Changes will be applied immediately.',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Large Next / Continue Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryThemeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  elevation: 1,
                  shadowColor: Colors.black26,
                ),
                onPressed: () {
                  setState(() {
                    _activeStep = 2; // Move to Step 2: Edit Channel
                  });
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text(
                  'CONTINUE TO EDIT CHANNEL',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 2: Edit Channel Screen (Matching media_1787953660666.png with App Theme) ---
  Widget _buildEditChannelScreen() {
    final companyNameDisplay = _userCompanyName.trim().isNotEmpty
        ? _userCompanyName.trim().toUpperCase()
        : 'THE ROYAL GARDENIA';

    // Default to user company name if not selected
    if (_channelDisplayName != companyNameDisplay && _channelDisplayName != 'Apna POS') {
      _channelDisplayName = companyNameDisplay;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),

            // 1. Heading
            const Text(
              'Want to know how your customers stay informed about loyalty?',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                height: 1.3,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),

            // 2. "View available pricing >" Pill Button in App Theme
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'WhatsApp Utility messaging is included with your Apna POS Loyalty plan!',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: _primaryThemeColor,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                decoration: BoxDecoration(
                  color: _primaryThemeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View available pricing',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 3. Card: Select Loyalty Display Name (Semi Curved Corners)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primaryThemeColor.withValues(alpha: 0.18), width: 1.3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Loyalty Display Name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Segmented Tabs: [ USER COMPANY NAME ] (First) | [ Apna POS ] (Second)
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        // First Option: User Company Name from API / Store Profile
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _channelDisplayName = companyNameDisplay;
                              });
                            },
                            child: Container(
                              color: _channelDisplayName == companyNameDisplay
                                  ? _primaryThemeColor
                                  : Colors.white,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_channelDisplayName == companyNameDisplay) ...[
                                    const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      companyNameDisplay,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: _channelDisplayName == companyNameDisplay
                                            ? Colors.white
                                            : const Color(0xFF334155),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(width: 1.2, color: const Color(0xFFE2E8F0)),
                        // Second Option: Apna POS
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _channelDisplayName = 'Apna POS';
                              });
                            },
                            child: Container(
                              color: _channelDisplayName == 'Apna POS'
                                  ? _primaryThemeColor
                                  : Colors.white,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_channelDisplayName == 'Apna POS') ...[
                                    const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    'Apna POS',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: _channelDisplayName == 'Apna POS'
                                          ? Colors.white
                                          : const Color(0xFF334155),
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
                  const SizedBox(height: 14),

                  // WhatsApp Utility Semi-Curved Row Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: _primaryThemeColor.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _primaryThemeColor.withValues(alpha: 0.18), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        // Green WhatsApp Icon
                        Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF25D366),
                          ),
                          child: const Icon(Icons.chat_bubble, color: Colors.white, size: 15),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Whatsapp Utility',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: 0.85,
                          child: Checkbox(
                            value: _whatsappUtilityEnabled,
                            activeColor: _primaryThemeColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) {
                              setState(() => _whatsappUtilityEnabled = val ?? true);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. "Demo Loyalty Message" Button in App Theme
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryThemeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 1,
                  shadowColor: Colors.black26,
                ),
                onPressed: () => _showDemoLoyaltyMessageDialog(context),
                child: const Text(
                  'Demo Loyalty Message',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 5. Continue to Done & Preview Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryThemeColor,
                  side: BorderSide(color: _primaryThemeColor, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 13.5),
                ),
                onPressed: () {
                  setState(() {
                    _activeStep = 3; // Move to Step 3: Done / Preview
                  });
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text(
                  'CONTINUE TO PREVIEW & FINISH',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 3: Done Screen with Live Loyalty Preview ---
  Widget _buildDoneScreen() {
    final companyNameDisplay = _userCompanyName.trim().isNotEmpty
        ? _userCompanyName.trim()
        : 'THE ROYAL GARDENIA';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 6),

            // Header Success Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _primaryThemeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _primaryThemeColor.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: _primaryThemeColor, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Setup Ready • Live Preview',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _primaryThemeColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Live Loyalty Card Preview
            _buildLiveLoyaltyPreview(),
            const SizedBox(height: 14),

            // Summary Details Card (Semi Curved Corners)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _primaryThemeColor.withValues(alpha: 0.16), width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LOYALTY PROGRAM SUMMARY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: _primaryThemeColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Business Name', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      Text(companyNameDisplay, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const Divider(color: Color(0xFFF1F5F9), height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Points Branding', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      Row(
                        children: [
                          Text(_currentPointsEmoji, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(_currentPointsName, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                        ],
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFF1F5F9), height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bonus Coins', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      Text(
                        _bonusPointsEnabled
                            ? '${_bonusPointsAmountCtrl.text.isNotEmpty ? _bonusPointsAmountCtrl.text : '100'} $_currentPointsEmoji'
                            : 'Disabled',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _bonusPointsEnabled ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFF1F5F9), height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Messaging Channel', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      Text('WhatsApp ($_channelDisplayName)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _primaryThemeColor)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Prominent Large Done Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryThemeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 2,
                  shadowColor: Colors.black26,
                ),
                onPressed: _isSaving ? null : _saveAndComplete,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: const Text(
                  'Done',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Demo Loyalty Message Bottom Sheet ---
  void _showDemoLoyaltyMessageDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryThemeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chat_bubble_rounded, color: _primaryThemeColor, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'WhatsApp Demo Message',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From: $_channelDisplayName',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _primaryThemeColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🎉 Hello Rahul! Thank you for visiting $_channelDisplayName.\n\n'
                    'You have earned ${_bonusPointsAmountCtrl.text.isNotEmpty ? _bonusPointsAmountCtrl.text : '100'} ${_currentPointsName.toLowerCase()}s! 🪙\n\n'
                    'Check your rewards anytime & visit us soon for exclusive discounts.',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryThemeColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('GOT IT', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- High-Quality Transparent Treasure Chest Graphic from media_1787952853197.png ---
class TreasureChestArtwork extends StatelessWidget {
  const TreasureChestArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Image.asset(
          'assets/images/treasure_bonus.png',
          width: 350,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(
              width: 320,
              height: 170,
              child: Center(
                child: Icon(Icons.inventory_2_rounded, size: 72, color: Color(0xFFF59E0B)),
              ),
            );
          },
        ),
      ),
    );
  }
}
