import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/services/loyalty_service.dart';

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

  // App Theme Primary Color (Deep Navy Blue from App Theme)
  static const Color _primaryThemeColor = Color(0xFF082559);
  static const Color _tealAccentColor = Color(0xFF00A884);

  // Form Controllers - Theme Section
  late TextEditingController _programNameCtrl;
  late TextEditingController _sloganCtrl;
  late TextEditingController _minPurchaseCtrl;

  // Form Controllers - Points Section (from user screenshot)
  late TextEditingController _timesCustomerVisitCtrl;
  late TextEditingController _customerEarnsPointsCtrl;
  late TextEditingController _pointsNameCtrl;
  late TextEditingController _minSpendConditionCtrl;
  late TextEditingController _pointEarningGapCtrl;
  late TextEditingController _maxCashbackLimitCtrl;

  // Points Settings State & Toggles
  bool _isRewardPointSettingsExpanded = false;
  bool _pointBrandingEnabled = true;
  int _selectedPointPresetIndex = 0; // 0: Cookie, 1: Chilly, 2: Star, 3: Coin
  bool _minSpendConditionEnabled = false;
  bool _pointEarningGapEnabled = false;
  bool _maxCashbackLimitEnabled = false;

  // Active Navigation States
  int _activeStep = 0; // 0: Edit Theme, 1: Edit Rules, 2: Edit Channels, 3: Edit Earns, 4: Done
  int _activeBottomTab = 0; // 0: Theme, 1: Points, 2: Rewards, 3: Settings

  // Theme & Colors
  Color _bgGradientStart = const Color(0xFF4A082F); // Dark Burgundy
  Color _bgGradientEnd = const Color(0xFF8E1449); // Ruby / Magenta
  Color _rewardColorStart = const Color(0xFF4A082F);
  Color _rewardColorEnd = const Color(0xFF8E1449);

  // Multi-select Order Types (Delivery, Take-Away, Dine-In)
  Set<String> _selectedOrderTypes = {'Delivery', 'Take-Away', 'Dine-In'};

  // Media
  String _bannerImagePath = 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=800';
  String _logoUrl = '';

  String get _currentPointsName =>
      _pointsNameCtrl.text.trim().isNotEmpty ? _pointsNameCtrl.text.trim() : 'Cookie';

  // Stages
  List<RewardStageModel> _rewardStages = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Validation
  String? _programNameError;

  final List<String> _stepTitles = [
    'Edit Theme',
    'Edit Points',
    'Edit Rewards',
    'Edit Channels',
    'Done',
  ];

  @override
  void initState() {
    super.initState();
    _programNameCtrl = TextEditingController(
      text: widget.companyName.isNotEmpty ? widget.companyName : 'THE ROYAL GARDENIA',
    );
    _sloganCtrl = TextEditingController(text: 'Get rewarded on every purchase');
    _minPurchaseCtrl = TextEditingController(text: '100');
    _logoUrl = widget.companyLogo;

    // Points tab controllers
    _timesCustomerVisitCtrl = TextEditingController(text: '1');
    _customerEarnsPointsCtrl = TextEditingController(text: '10');
    _pointsNameCtrl = TextEditingController(text: 'Cookie');
    _minSpendConditionCtrl = TextEditingController(text: '0');
    _pointEarningGapCtrl = TextEditingController(text: '24');
    _maxCashbackLimitCtrl = TextEditingController(text: '0');

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
    _pointEarningGapCtrl.dispose();
    _maxCashbackLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingConfig() async {
    setState(() => _isLoading = true);
    final config = await _loyaltyService.getVisitRewardConfig(
      companyName: widget.companyName,
      companyLogo: widget.companyLogo,
    );

    if (mounted) {
      setState(() {
        if (config.programName.isNotEmpty) _programNameCtrl.text = config.programName;
        if (config.slogan.isNotEmpty) _sloganCtrl.text = config.slogan;
        if (config.minimumPurchase > 0) {
          _minPurchaseCtrl.text = config.minimumPurchase.toInt().toString();
          _minSpendConditionCtrl.text = config.minimumPurchase.toInt().toString();
        }
        if (config.orderType.isNotEmpty) {
          final types = config.orderType
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet();
          if (types.isNotEmpty) _selectedOrderTypes = types;
        }
        if (config.logoUrl.isNotEmpty) _logoUrl = config.logoUrl;
        if (config.bannerImageUrl.isNotEmpty) _bannerImagePath = config.bannerImageUrl;

        _rewardStages = List.from(config.rewardStages);
        if (_rewardStages.isEmpty) {
          _rewardStages = [
            RewardStageModel(
              id: 'stage_1',
              visitCount: 300,
              rewardType: '₹ Discount',
              rewardValue: 100.0,
              minimumPurchase: 100.0,
              freeItemName: 'Cheers ! Rs 100 off on your purchase.',
            ),
            RewardStageModel(
              id: 'stage_2',
              visitCount: 500,
              rewardType: '₹ Discount',
              rewardValue: 200.0,
              minimumPurchase: 100.0,
              freeItemName: 'Cheers ! Rs 200 off on your purchase.',
            ),
            RewardStageModel(
              id: 'stage_3',
              visitCount: 800,
              rewardType: '₹ Discount',
              rewardValue: 300.0,
              minimumPurchase: 100.0,
              freeItemName: 'Cheers ! Rs 300 off on your purchase.',
            ),
          ];
        }
        _isLoading = false;
      });
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
        if (_activeStep == 1) _activeBottomTab = 1;
        if (_activeStep == 2) _activeBottomTab = 2;
        if (_activeStep == 3) _activeBottomTab = 3;
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
      rewardType: '₹ Discount',
      rewardValue: 100.0,
      minimumPurchase: minSpend,
      rewardStages: _rewardStages,
      bannerImageUrl: _bannerImagePath,
      logoUrl: _logoUrl,
      orderType: _selectedOrderTypes.join(', '),
      termsNote:
          'Terms and conditions apply.\nMinimum purchase of ₹${minSpend.toInt()} required.\n3 offers cannot be clubbed.',
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              isBanner ? 'Banner image selected from gallery!' : 'Logo selected from gallery!',
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

  void _openAddEditStageModal({RewardStageModel? existingStage, int? index}) {
    int stageVisits = existingStage?.visitCount ??
        (_rewardStages.isNotEmpty ? _rewardStages.last.visitCount + 200 : 300);
    final stageValueCtrl = TextEditingController(
      text: existingStage != null ? existingStage.rewardValue.toInt().toString() : '100',
    );
    final stageMinSpendCtrl = TextEditingController(
      text: existingStage != null
          ? existingStage.minimumPurchase.toInt().toString()
          : _minPurchaseCtrl.text,
    );
    final stageDescCtrl = TextEditingController(
      text: existingStage?.freeItemName ?? 'Cheers ! Rs 100 off on your purchase.',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding:
                EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

                  // Required Cookies / Visits
                  Text('Required $_currentPointsName / Visits',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16),
                          onPressed: () {
                            if (stageVisits > 50) setModalState(() => stageVisits -= 50);
                          },
                        ),
                        Text(
                          '$stageVisits $_currentPointsName',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w900, color: _primaryThemeColor),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          onPressed: () {
                            setModalState(() => stageVisits += 50);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Reward Value
                  const Text('Reward Discount Value (₹)',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 5),
                  TextField(
                    controller: stageValueCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w600),
                    cursorColor: _primaryThemeColor,
                    onChanged: (val) {
                      setModalState(() {
                        stageDescCtrl.text = 'Cheers ! Rs $val off on your purchase.';
                      });
                    },
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(
                          fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _primaryThemeColor, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Min Purchase Spend
                  const Text('Minimum Purchase Required (₹)',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 5),
                  TextField(
                    controller: stageMinSpendCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w600),
                    cursorColor: _primaryThemeColor,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(
                          fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _primaryThemeColor, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Preview Subtitle
                  const Text('Preview Subtitle',
                      style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 5),
                  TextField(
                    controller: stageDescCtrl,
                    style: const TextStyle(
                        color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w600),
                    cursorColor: _primaryThemeColor,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _primaryThemeColor, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryThemeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final val = double.tryParse(stageValueCtrl.text.trim()) ?? 100.0;
                        final minSpend = double.tryParse(stageMinSpendCtrl.text.trim()) ?? 100.0;

                        final newStage = RewardStageModel(
                          id: existingStage?.id ??
                              'stage_${DateTime.now().millisecondsSinceEpoch}',
                          visitCount: stageVisits,
                          rewardType: '₹ Discount',
                          rewardValue: val,
                          minimumPurchase: minSpend,
                          freeItemName: stageDescCtrl.text.trim(),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    borderRadius: BorderRadius.circular(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
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
                              color: Colors.black.withOpacity(0.65),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                        colors: [preset['start'] as Color, preset['end'] as Color]),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
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
                    } else {
                      _rewardColorStart = preset['start'] as Color;
                      _rewardColorEnd = preset['end'] as Color;
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
      backgroundColor: const Color(0xFFFAFAFC),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _primaryThemeColor, strokeWidth: 2.5),
              )
            : Column(
                children: [
                  // Top Navigation Header
                  _buildTopHeader(),

                  // Horizontal Stepper (Visual Only, advances via Next button)
                  _buildProgressStepper(),

                  // Main Content Area (Wrapped & Compact)
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _mainScrollController,
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
                              // Subtitle / Intro
                              _buildIntroSubtitle(),
                              const SizedBox(height: 12),

                              if (isTabletLandscape)
                                // Tablet / Desktop: Two columns (Side-by-Side)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 5, child: _buildLiveLoyaltyPreview()),
                                    const SizedBox(width: 20),
                                    Expanded(flex: 6, child: _buildActiveConfigurationFields()),
                                  ],
                                )
                              else
                                // Mobile: Active Configuration Fields on TOP first, then Live Preview DOWNSIDE (sticks & scrolls smoothly!)
                                Column(
                                  children: [
                                    _buildActiveConfigurationFields(),
                                    const SizedBox(height: 20),
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

                  // Bottom 4-Icon Navigation Bar (with semi-circle top curved border)
                  _buildBottomNavBar(),
                ],
              ),
      ),
    );
  }

  // --- 1. TOP HEADER (Edit Theme & Next > button in App Theme Navy Color) ---
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
                      color: Colors.white.withOpacity(0.75),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              elevation: 0,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: _primaryThemeColor, strokeWidth: 2),
                  )
                : Text(
                    isLastStep ? 'Done ✓' : 'Next >',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: _primaryThemeColor,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- 2. PROGRESS STEPPER (Visual Stepper only, step forward via Next) ---
  Widget _buildProgressStepper() {
    final steps = [
      {'title': 'Theme', 'icon': Icons.palette_outlined},
      {'title': 'Points', 'icon': Icons.toll_rounded},
      {'title': 'Rewards', 'icon': Icons.card_giftcard_rounded},
      {'title': 'Channels', 'icon': Icons.alt_route_rounded},
      {'title': 'Done', 'icon': Icons.adjust_rounded},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isActive || isCompleted)
                            ? _primaryThemeColor
                            : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: (isActive || isCompleted)
                              ? _primaryThemeColor
                              : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_rounded : (step['icon'] as IconData),
                        size: 14,
                        color: (isActive || isCompleted) ? Colors.white : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      step['title'] as String,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        color: (isActive || isCompleted)
                            ? _primaryThemeColor
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 24,
                    height: 1.5,
                    margin: const EdgeInsets.only(bottom: 12, left: 3, right: 3),
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
  Widget _buildIntroSubtitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.35),
          children: [
            TextSpan(text: "We've designed a loyalty program just for you! "),
            TextSpan(
              text: "Feel free to review and make any changes",
              style: TextStyle(fontWeight: FontWeight.w900, color: _primaryThemeColor),
            ),
            TextSpan(text: " to suit your needs."),
          ],
        ),
      ),
    );
  }

  // --- 4. DYNAMIC CONFIGURATION SWITCHER (Theme vs Points vs Rewards vs Settings) ---
  Widget _buildActiveConfigurationFields() {
    switch (_activeBottomTab) {
      case 1:
        return _buildPointsConfigurationFields();
      case 2:
        return _buildRewardsConfigurationFields();
      case 3:
        return _buildSettingsConfigurationFields();
      case 0:
      default:
        return _buildThemeConfigurationFields();
    }
  }

  // --- TAB 1: POINTS SECTION (Matching Screenshot exactly) ---
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
        // 1. Visit & Cookie Ratio Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF4FAFD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Field 1: Number of times customer Visit*
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
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _timesCustomerVisitCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  cursorColor: _tealAccentColor,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Field 2: Number of customer earns Cookie*
              Text(
                'Number of customer earns $pointsName*',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _customerEarnsPointsCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  cursorColor: _tealAccentColor,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Reward Point Settings Dropdown
              InkWell(
                onTap: () {
                  setState(() {
                    _isRewardPointSettingsExpanded = !_isRewardPointSettingsExpanded;
                  });
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reward Point Settings',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Icon(
                          _isRewardPointSettingsExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF64748B),
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Points are calculated on the final payable amount (after tax & charges). Tap here to view or modify.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Customers Earn Banner Pill
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F8F5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC4EFE6)),
          ),
          child: Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                children: [
                  const TextSpan(text: 'Customers '),
                  TextSpan(
                    text: 'Earn $timesVisit Visit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _tealAccentColor,
                    ),
                  ),
                  const TextSpan(text: ' for every '),
                  TextSpan(
                    text: '$earnsCookies $pointsName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: _tealAccentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 3. Point Branding Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pointBrandingEnabled ? const Color(0xFF00BFA5) : const Color(0xFFE2E8F0),
              width: _pointBrandingEnabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Point Branding',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _pointBrandingEnabled,
                      activeColor: const Color(0xFF00BFA5),
                      activeTrackColor: const Color(0xFF00BFA5).withOpacity(0.4),
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
              const SizedBox(height: 10),

              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _pointsNameCtrl,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  cursorColor: _tealAccentColor,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 4 Preset Chips (Cookie, Chilly, Star, Coin)
              Row(
                children: [
                  _buildPointPresetChip(0, '🍪', 'Cookie'),
                  const SizedBox(width: 8),
                  _buildPointPresetChip(1, '🌶️', 'Chilly'),
                  const SizedBox(width: 8),
                  _buildPointPresetChip(2, '⭐', 'Star'),
                  const SizedBox(width: 8),
                  _buildPointPresetChip(3, '🪙', 'Coin'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 4. Minimum Spend Condition Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _minSpendConditionEnabled
                  ? const Color(0xFF00BFA5)
                  : const Color(0xFFE2E8F0),
              width: _minSpendConditionEnabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Minimum Spend Condition',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _minSpendConditionEnabled,
                      activeColor: const Color(0xFF00BFA5),
                      activeTrackColor: const Color(0xFF00BFA5).withOpacity(0.4),
                      onChanged: (val) {
                        setState(() => _minSpendConditionEnabled = val);
                      },
                    ),
                  ),
                ],
              ),
              const Text(
                'Define the minimum bill amount required for a customer to earn points.',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),

              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _minSpendConditionCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  cursorColor: _tealAccentColor,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 5. Point Earning Gap Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pointEarningGapEnabled
                  ? const Color(0xFF00BFA5)
                  : const Color(0xFFE2E8F0),
              width: _pointEarningGapEnabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Point Earning Gap',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _pointEarningGapEnabled,
                      activeColor: const Color(0xFF00BFA5),
                      activeTrackColor: const Color(0xFF00BFA5).withOpacity(0.4),
                      onChanged: (val) {
                        setState(() => _pointEarningGapEnabled = val);
                      },
                    ),
                  ),
                ],
              ),
              const Text(
                'Set a countdown period before customers can earn points on their next purchase.',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 6. Maximum Cashback Limit Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _maxCashbackLimitEnabled
                  ? const Color(0xFF00BFA5)
                  : const Color(0xFFE2E8F0),
              width: _maxCashbackLimitEnabled ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Maximum Cashback Limit',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _maxCashbackLimitEnabled,
                      activeColor: const Color(0xFF00BFA5),
                      activeTrackColor: const Color(0xFF00BFA5).withOpacity(0.4),
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
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: TextField(
                  controller: _maxCashbackLimitCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  cursorColor: _tealAccentColor,
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00BFA5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF00BFA5) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
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

  // --- TAB 0: THEME CONFIGURATION FIELDS ---
  Widget _buildThemeConfigurationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Order Type Card (Multi-select segment tabs)
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Order Type',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    '${_selectedOrderTypes.length} selected',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    _buildOrderTypeSegment('Delivery'),
                    Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                    _buildOrderTypeSegment('Take-Away'),
                    Container(width: 1, height: 32, color: const Color(0xFFCBD5E1)),
                    _buildOrderTypeSegment('Dine-In'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 2. Explore Stunning Free Photos on Unsplash Card
        _buildBoxContainer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    children: [
                      TextSpan(text: 'Explore Stunning Free Photos\non Unsplash '),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 0,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Try Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Banner Image Upload Box (Gallery Support)
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Banner Image',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  TextButton.icon(
                    onPressed: () => _pickImageFromGallery(isBanner: true),
                    icon: const Icon(Icons.photo_library_outlined, size: 14, color: _primaryThemeColor),
                    label: const Text('Gallery',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: _primaryThemeColor)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _pickImageFromGallery(isBanner: true),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryThemeColor.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _primaryThemeColor.withOpacity(0.3), style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primaryThemeColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.image_outlined, color: _primaryThemeColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Tap to pick from gallery (16:9, 9:16, or PNG up to 10MB)',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF475569), height: 1.25),
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

        // 4. Logo Upload Box (Gallery Support)
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Logo',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  TextButton.icon(
                    onPressed: () => _pickImageFromGallery(isBanner: false),
                    icon: const Icon(Icons.photo_library_outlined, size: 14, color: _primaryThemeColor),
                    label: const Text('Gallery',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: _primaryThemeColor)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _pickImageFromGallery(isBanner: false),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryThemeColor.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _primaryThemeColor.withOpacity(0.3), style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primaryThemeColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.spa_outlined, color: _primaryThemeColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Tap to pick brand logo from gallery (JPG or PNG up to 10MB)',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF475569), height: 1.25),
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

        // 5. Program Name & Slogan
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Program Name *',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 5),
              TextField(
                controller: _programNameCtrl,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: _primaryThemeColor,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  errorText: _programNameError,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _primaryThemeColor, width: 1.5)),
                ),
              ),
              const SizedBox(height: 10),
              const Text('Slogan',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 5),
              TextField(
                controller: _sloganCtrl,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: _primaryThemeColor,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _primaryThemeColor, width: 1.5)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 6. Theme Color Palettes (Background & Reward Palettes)
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customize Colors',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),

              // Background Gradient Palette Selector
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Background Palette',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _openColorPresetPicker(target: 'Background'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(colors: [_bgGradientStart, _bgGradientEnd]),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Reward Color Palette Selector
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reward Palette',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _openColorPresetPicker(target: 'Reward'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(colors: [_rewardColorStart, _rewardColorEnd]),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 2: REWARDS CONFIGURATION ---
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
                        fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryThemeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _openAddEditStageModal(),
                    icon: const Icon(Icons.add, size: 13),
                    label: const Text('Add Stage',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._rewardStages.map((stage) {
                final idx = _rewardStages.indexOf(stage);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _primaryThemeColor.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.card_giftcard_rounded,
                            color: _primaryThemeColor, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${stage.visitCount} $_currentPointsName  •  ₹${stage.rewardValue.toInt()} OFF',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A)),
                            ),
                            Text(
                              stage.freeItemName,
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16, color: _primaryThemeColor),
                        onPressed: () =>
                            _openAddEditStageModal(existingStage: stage, index: idx),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 16, color: Color(0xFFEF4444)),
                        onPressed: () {
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
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 3: SETTINGS CONFIGURATION ---
  Widget _buildSettingsConfigurationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBoxContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Minimum Purchase Required (₹)',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 5),
              TextField(
                controller: _minPurchaseCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w600),
                cursorColor: _primaryThemeColor,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 12.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _primaryThemeColor, width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Terms & Conditions Note',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  'Terms and conditions apply.\nMinimum purchase of ₹${_minPurchaseCtrl.text.trim()} required.\n3 offers cannot be clubbed.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 5. LIVE LOYALTY CARD PREVIEW (Downside stick container) ---
  Widget _buildLiveLoyaltyPreview() {
    final programName = _programNameCtrl.text.trim().isNotEmpty
        ? _programNameCtrl.text.trim()
        : 'THE ROYAL GARDENIA';
    final slogan =
        _sloganCtrl.text.trim().isNotEmpty ? _sloganCtrl.text.trim() : 'Get rewarded on every purchase';
    final minPurchase =
        _minPurchaseCtrl.text.trim().isNotEmpty ? _minPurchaseCtrl.text.trim() : '100';

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
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner Image with Edit Button
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  height: 135,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2D051C),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_bannerImagePath.startsWith('http'))
                        Image.network(
                          _bannerImagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.restaurant_rounded, color: Colors.white30, size: 40)),
                        )
                      else if (File(_bannerImagePath).existsSync())
                        Image.file(
                          File(_bannerImagePath),
                          fit: BoxFit.cover,
                        )
                      else
                        const Center(
                            child: Icon(Icons.restaurant_rounded, color: Colors.white30, size: 40)),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              _bgGradientStart.withOpacity(0.9),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: InkWell(
                  onTap: () => _pickImageFromGallery(isBanner: true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _primaryThemeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Theme',
                            style: TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        SizedBox(width: 3),
                        Icon(Icons.edit, size: 10, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Floating Brand Logo Badge
          Transform.translate(
            offset: const Offset(0, -28),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1E0213),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: ClipOval(
                child: _logoUrl.isNotEmpty && File(_logoUrl).existsSync()
                    ? Image.file(File(_logoUrl), fit: BoxFit.cover)
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.spa_rounded, color: Color(0xFFD4AF37), size: 20),
                            Text(
                              'ROYAL\nGARDENIA',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFFD4AF37),
                                fontSize: 6,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),

          // Program Title & Slogan
          Transform.translate(
            offset: const Offset(0, -18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(
                    programName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    slogan,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // Dynamic Conversion text: "1 Visit = 10 Cookie"
                  Text(
                    '$timesVisit Visit = $earnsCookies $pointsName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Milestone Cookie Progress Line
                  _buildMilestoneCookieBar(),
                  const SizedBox(height: 14),

                  // Configured Stages Cards
                  ..._rewardStages.map((stage) => _buildPreviewStageCard(stage)),
                  const SizedBox(height: 12),

                  // ADD REWARD STAGE Button (Dynamically matched to selected Reward Color!)
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

                  // Terms & conditions note
                  Text(
                    'Terms and conditions apply.\nMinimum purchase of ₹$minPurchase required.\n3 offers cannot be clubbed.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
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

  // --- Cookie Milestone Journey Progress Bar ---
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
                        color: const Color(0xFFD4A373),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.cookie_outlined, color: Color(0xFF3F1D0B), size: 14),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: Colors.white.withOpacity(0.5),
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
                style: const TextStyle(
                  color: Colors.white,
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

  // --- Stage Card in Preview ---
  Widget _buildPreviewStageCard(RewardStageModel stage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.confirmation_num_outlined, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFFD4A373),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cookie_outlined, color: Color(0xFF3F1D0B), size: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stage.visitCount} $_currentPointsName',
                  style: const TextStyle(
                    color: Colors.white,
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
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () =>
                _openAddEditStageModal(existingStage: stage, index: _rewardStages.indexOf(stage)),
            child:
                Icon(Icons.lock_outline_rounded, color: Colors.white.withOpacity(0.7), size: 15),
          ),
        ],
      ),
    );
  }

  // --- 6. BOTTOM NAVIGATION BAR (with Semi-Circle / Curved Top Border) ---
  Widget _buildBottomNavBar() {
    final navItems = [
      {'label': 'Theme', 'icon': Icons.palette_outlined},
      {'label': 'Points', 'icon': Icons.toll_rounded},
      {'label': 'Rewards', 'icon': Icons.card_giftcard_rounded},
      {'label': 'Settings', 'icon': Icons.settings_outlined},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(navItems.length, (idx) {
            final item = navItems[idx];
            final isSel = _activeBottomTab == idx;
            const activeColor = _tealAccentColor;

            return InkWell(
              onTap: () {
                setState(() => _activeBottomTab = idx);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSel ? activeColor : activeColor.withOpacity(0.08),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      size: 20,
                      color: isSel ? Colors.white : activeColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel ? activeColor : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  // --- Helper: Order Type Segment Button ---
  Widget _buildOrderTypeSegment(String type) {
    final isSel = _selectedOrderTypes.contains(type);

    return Expanded(
      child: InkWell(
        onTap: () => _toggleOrderType(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          color: isSel ? _primaryThemeColor : Colors.white,
          child: Text(
            type,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSel ? Colors.white : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper: White Rounded Container Box ---
  Widget _buildBoxContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
}
