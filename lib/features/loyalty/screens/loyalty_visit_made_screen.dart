import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/services/loyalty_service.dart';

class LoyaltyVisitMadeScreen extends StatefulWidget {
  final String companyName;
  final String companyLogo;
  final LoyaltyProgramModel? program;
  final VoidCallback? onCompleted;

  const LoyaltyVisitMadeScreen({
    super.key,
    this.companyName = 'THE ROYAL GARDENIA',
    this.companyLogo = '',
    this.program,
    this.onCompleted,
  });

  @override
  State<LoyaltyVisitMadeScreen> createState() => _LoyaltyVisitMadeScreenState();
}

class _LoyaltyVisitMadeScreenState extends State<LoyaltyVisitMadeScreen> {
  final LoyaltyService _loyaltyService = LoyaltyService();
  final ScrollController _mainScrollController = ScrollController();

  // Form Controllers
  late TextEditingController _programNameCtrl;
  late TextEditingController _sloganCtrl;
  late TextEditingController _rewardValueCtrl;
  late TextEditingController _minPurchaseCtrl;
  late TextEditingController _triggerMinSpendCtrl;
  late TextEditingController _freeItemNameCtrl;

  // State Variables
  String _visitTrigger = 'Every Visit'; // 'Every Visit', 'Minimum Spend', 'Specific Purchase'
  int _visitCount = 3;
  String _rewardType = '₹ Discount'; // '₹ Discount', '% Discount', 'Free Item', 'Cashback', 'Coupon'
  String _selectedOrderType = 'Dine-In';
  String _specificCategory = 'All Items';
  List<RewardStageModel> _rewardStages = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Validation Error Messages
  String? _rewardValueError;
  String? _minPurchaseError;
  String? _programNameError;

  @override
  void initState() {
    super.initState();
    _programNameCtrl = TextEditingController(
      text: widget.companyName.isNotEmpty ? widget.companyName : 'THE ROYAL GARDENIA',
    );
    _sloganCtrl = TextEditingController(text: 'Get rewarded on every purchase');
    _rewardValueCtrl = TextEditingController(text: '100');
    _minPurchaseCtrl = TextEditingController(text: '100');
    _triggerMinSpendCtrl = TextEditingController(text: '200');
    _freeItemNameCtrl = TextEditingController(text: 'Dessert / Beverage');

    _loadExistingConfig();
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    _programNameCtrl.dispose();
    _sloganCtrl.dispose();
    _rewardValueCtrl.dispose();
    _minPurchaseCtrl.dispose();
    _triggerMinSpendCtrl.dispose();
    _freeItemNameCtrl.dispose();
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
        _programNameCtrl.text = config.programName;
        _sloganCtrl.text = config.slogan;
        _visitTrigger = config.visitTrigger;
        _triggerMinSpendCtrl.text = config.triggerMinSpend.toInt().toString();
        _visitCount = config.visitCount;
        _rewardType = config.rewardType;
        _rewardValueCtrl.text = config.rewardValue.toInt().toString();
        _minPurchaseCtrl.text = config.minimumPurchase.toInt().toString();
        _selectedOrderType = config.orderType;
        _rewardStages = List.from(config.rewardStages);
        if (_rewardStages.isEmpty) {
          _rewardStages = [
            RewardStageModel(
              id: 'stage_1',
              visitCount: 3,
              rewardType: '₹ Discount',
              rewardValue: 100.0,
              minimumPurchase: 100.0,
            ),
            RewardStageModel(
              id: 'stage_2',
              visitCount: 5,
              rewardType: '₹ Discount',
              rewardValue: 200.0,
              minimumPurchase: 100.0,
            ),
            RewardStageModel(
              id: 'stage_3',
              visitCount: 8,
              rewardType: '₹ Discount',
              rewardValue: 300.0,
              minimumPurchase: 100.0,
            ),
          ];
        }
        _isLoading = false;
      });
    }
  }

  bool _validateForm() {
    bool isValid = true;
    setState(() {
      _programNameError = null;
      _rewardValueError = null;
      _minPurchaseError = null;

      if (_programNameCtrl.text.trim().isEmpty) {
        _programNameError = 'Program name cannot be empty';
        isValid = false;
      }

      final rewardVal = double.tryParse(_rewardValueCtrl.text.trim());
      if (_rewardType != 'Free Item') {
        if (rewardVal == null || rewardVal <= 0) {
          _rewardValueError = 'Please enter a valid positive reward value';
          isValid = false;
        } else if (_rewardType == '% Discount' && rewardVal > 100) {
          _rewardValueError = 'Percentage discount cannot exceed 100%';
          isValid = false;
        }
      } else {
        if (_freeItemNameCtrl.text.trim().isEmpty) {
          _rewardValueError = 'Please enter free item name';
          isValid = false;
        }
      }

      final minPurchase = double.tryParse(_minPurchaseCtrl.text.trim());
      if (minPurchase == null || minPurchase < 0) {
        _minPurchaseError = 'Please enter a valid minimum purchase amount';
        isValid = false;
      }

      if (_rewardStages.isEmpty) {
        isValid = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please configure at least one reward stage.'),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return isValid;
  }

  Future<void> _handleNext() async {
    if (!_validateForm()) {
      return;
    }

    setState(() => _isSaving = true);

    final config = VisitRewardConfig(
      programName: _programNameCtrl.text.trim(),
      slogan: _sloganCtrl.text.trim(),
      visitTrigger: _visitTrigger,
      triggerMinSpend: double.tryParse(_triggerMinSpendCtrl.text.trim()) ?? 100.0,
      visitCount: _visitCount,
      rewardType: _rewardType,
      rewardValue: double.tryParse(_rewardValueCtrl.text.trim()) ?? 100.0,
      minimumPurchase: double.tryParse(_minPurchaseCtrl.text.trim()) ?? 100.0,
      rewardStages: _rewardStages,
      logoUrl: widget.companyLogo,
      orderType: _selectedOrderType,
      termsNote: 'Terms and conditions apply.\nMinimum purchase of ₹${_minPurchaseCtrl.text.trim()} required.\nOffers cannot be clubbed.',
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF86EFAC), width: 2),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 40),
              ),
              const SizedBox(height: 18),
              const Text(
                'Visit Made Program Configured!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your visit-based loyalty program for "${_programNameCtrl.text}" is ready. Customers will earn rewards for their visits.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onCompleted?.call();
                    Navigator.pop(context);
                  },
                  child: const Text('Go to Loyalty Hub', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddEditStageModal({RewardStageModel? existingStage, int? index}) {
    int stageVisits = existingStage?.visitCount ?? (_rewardStages.isNotEmpty ? _rewardStages.last.visitCount + 2 : 3);
    String stageRewardType = existingStage?.rewardType ?? _rewardType;
    final stageValueCtrl = TextEditingController(
      text: existingStage != null ? existingStage.rewardValue.toInt().toString() : '150',
    );
    final stageMinSpendCtrl = TextEditingController(
      text: existingStage != null ? existingStage.minimumPurchase.toInt().toString() : _minPurchaseCtrl.text,
    );
    final stageFreeItemCtrl = TextEditingController(
      text: existingStage?.freeItemName ?? 'Dessert / Beverage',
    );
    int stageExpiry = existingStage?.expiryDays ?? 30;
    String? modalValueError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
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
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingStage != null ? 'Edit Reward Stage' : 'Add Reward Stage',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(modalCtx),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),

                  // Required Visits Stepper
                  const Text('Required Visits', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () {
                            if (stageVisits > 1) {
                              setModalState(() => stageVisits--);
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Icons.remove, size: 16, color: Color(0xFF0F172A)),
                          ),
                        ),
                        Text(
                          '$stageVisits ${stageVisits == 1 ? "Visit" : "Visits"}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0D9488)),
                        ),
                        InkWell(
                          onTap: () => setModalState(() => stageVisits++),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(Icons.add, size: 16, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Reward Type Pills
                  const Text('Reward Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['₹ Discount', '% Discount', 'Free Item', 'Cashback', 'Coupon'].map((type) {
                      final isSelected = stageRewardType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0D9488),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => stageRewardType = type);
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Reward Value Input
                  Text(
                    stageRewardType == 'Free Item' ? 'Free Item Name' : 'Reward Value',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 8),
                  if (stageRewardType == 'Free Item') ...[
                    TextField(
                      controller: stageFreeItemCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Free Brownie / Mocktail',
                        prefixIcon: const Icon(Icons.card_giftcard_rounded, color: Color(0xFF0D9488), size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8)),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: stageValueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      decoration: InputDecoration(
                        prefixText: stageRewardType.contains('%') ? '' : '₹ ',
                        suffixText: stageRewardType.contains('%') ? '%' : '',
                        prefixStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        suffixStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        errorText: modalValueError,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Min Purchase Input
                  const Text('Minimum Purchase Required (₹)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: stageMinSpendCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Expiry Days Selector
                  const Text('Reward Validity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [15, 30, 60, 90].map((days) {
                      final isSelected = stageExpiry == days;
                      return ChoiceChip(
                        label: Text('$days Days'),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0D9488),
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF334155),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => stageExpiry = days);
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final val = double.tryParse(stageValueCtrl.text.trim()) ?? 0.0;
                        if (stageRewardType != 'Free Item' && val <= 0) {
                          setModalState(() => modalValueError = 'Enter a valid reward value');
                          return;
                        }

                        final updatedStage = RewardStageModel(
                          id: existingStage?.id ?? 'stage_${DateTime.now().millisecondsSinceEpoch}',
                          visitCount: stageVisits,
                          rewardType: stageRewardType,
                          rewardValue: val,
                          minimumPurchase: double.tryParse(stageMinSpendCtrl.text.trim()) ?? 100.0,
                          expiryDays: stageExpiry,
                          freeItemName: stageFreeItemCtrl.text.trim(),
                        );

                        setState(() {
                          if (index != null && index >= 0 && index < _rewardStages.length) {
                            _rewardStages[index] = updatedStage;
                          } else {
                            _rewardStages.add(updatedStage);
                          }
                          _rewardStages.sort((a, b) => a.visitCount.compareTo(b.visitCount));
                        });

                        Navigator.pop(modalCtx);
                      },
                      child: Text(
                        existingStage != null ? 'Update Stage' : 'Add Stage',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletLandscape = screenWidth >= 950;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFC),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0D9488)),
              )
            : Column(
                children: [
                  // Top Navigation Header
                  _buildTopHeader(),

                  // Horizontal Stepper
                  _buildProgressStepper(),

                  // Main Content Area
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _mainScrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isTabletLandscape ? 1150 : 680,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Intro Section
                              _buildIntroSection(),

                              const SizedBox(height: 18),

                              if (isTabletLandscape)
                                // Tablet / Desktop Two-Column Layout
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left: Sticky Live Loyalty Preview
                                    Expanded(
                                      flex: 5,
                                      child: _buildLiveLoyaltyPreview(),
                                    ),
                                    const SizedBox(width: 24),
                                    // Right: Configuration Cards
                                    Expanded(
                                      flex: 6,
                                      child: _buildConfigurationCards(),
                                    ),
                                  ],
                                )
                              else
                                // Mobile Single-Column Layout
                                Column(
                                  children: [
                                    _buildLiveLoyaltyPreview(),
                                    const SizedBox(height: 20),
                                    _buildConfigurationCards(),
                                  ],
                                ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Navigation Bar (Mobile / Tablet Sticky Footer)
                  _buildBottomNavBar(),
                ],
              ),
      ),
    );
  }

  // --- TOP HEADER WIDGET ---
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Visit Made',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              elevation: 0,
            ),
            onPressed: _isSaving ? null : _handleNext,
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Next', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
            label: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
          ),
        ],
      ),
    );
  }

  // --- PROGRESS STEPPER WIDGET ---
  Widget _buildProgressStepper() {
    final steps = [
      {'title': 'Theme', 'icon': Icons.palette_outlined, 'status': 'completed'},
      {'title': 'Rules', 'icon': Icons.rule_folder_outlined, 'status': 'completed'},
      {'title': 'Channels', 'icon': Icons.hub_outlined, 'status': 'completed'},
      {'title': 'Visit Made', 'icon': Icons.card_giftcard_rounded, 'status': 'active'},
      {'title': 'Done', 'icon': Icons.check_circle_outline_rounded, 'status': 'upcoming'},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(steps.length, (index) {
            final step = steps[index];
            final status = step['status'] as String;
            final isCompleted = status == 'completed';
            final isActive = status == 'active';

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? const Color(0xFF0D9488)
                            : isCompleted
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: isActive
                              ? const Color(0xFF0D9488)
                              : isCompleted
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        isCompleted ? Icons.check_rounded : (step['icon'] as IconData),
                        size: 16,
                        color: isActive
                            ? Colors.white
                            : isCompleted
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step['title'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        color: isActive
                            ? const Color(0xFF0D9488)
                            : isCompleted
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 36,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
                    color: isCompleted ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // --- INTRO SECTION WIDGET ---
  Widget _buildIntroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 6),
        const Text(
          'Reward customers for every visit',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Create visit-based rewards that encourage customers to come back again and again.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // --- LIVE LOYALTY PREVIEW CARD (LEFT SIDE / TOP ON MOBILE) ---
  Widget _buildLiveLoyaltyPreview() {
    final programName = _programNameCtrl.text.trim().isNotEmpty ? _programNameCtrl.text.trim().toUpperCase() : 'THE ROYAL GARDENIA';
    final slogan = _sloganCtrl.text.trim().isNotEmpty ? _sloganCtrl.text.trim() : 'Get rewarded on every purchase';
    final minPurchase = _minPurchaseCtrl.text.trim().isNotEmpty ? _minPurchaseCtrl.text.trim() : '100';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A082F), Color(0xFF8E1449)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A082F).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top Food Banner with Theme badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2D051C),
                    image: DecorationImage(
                      image: AssetImage('assets/images/food_banner.png'),
                      fit: BoxFit.cover,
                      onError: null,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF4A082F).withValues(alpha: 0.9),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Theme', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      SizedBox(width: 4),
                      Icon(Icons.edit, size: 10, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Brand Logo Badge
          Transform.translate(
            offset: const Offset(0, -32),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF200313),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: ClipOval(
                child: widget.companyLogo.isNotEmpty && File(widget.companyLogo).existsSync()
                    ? Image.file(File(widget.companyLogo), fit: BoxFit.cover)
                    : const Center(
                        child: Icon(Icons.workspace_premium_rounded, color: Color(0xFFD4AF37), size: 34),
                      ),
              ),
            ),
          ),

          // Program Title & Slogan
          Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [
                  Text(
                    programName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slogan,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Rule Highlight Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      _visitTrigger == 'Minimum Spend'
                          ? '1 Visit = Min. Spend ₹${_triggerMinSpendCtrl.text}'
                          : _visitTrigger == 'Specific Purchase'
                              ? '1 Visit = Buy $_specificCategory'
                              : '1 Visit = 10 Cookie / Points',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Milestone Journey Progress Indicator
                  _buildMilestoneJourney(),

                  const SizedBox(height: 18),

                  // Configured Stages Cards in Preview
                  ..._rewardStages.map((stage) => _buildPreviewStageCard(stage)),

                  const SizedBox(height: 14),

                  // ADD REWARD STAGE Button inside Preview
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9E1B4F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      onPressed: () => _openAddEditStageModal(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text(
                        'ADD REWARD STAGE',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Terms and conditions footer
                  Text(
                    'Terms and conditions apply.\nMinimum purchase of ₹$minPurchase required.\n3 offers cannot be clubbed.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneJourney() {
    final stagesToShow = _rewardStages.take(3).toList();
    if (stagesToShow.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(stagesToShow.length, (idx) {
              final stage = stagesToShow[idx];
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.cookie, color: Color(0xFF4A082F), size: 16),
                      ),
                    ),
                    if (idx < stagesToShow.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: stagesToShow.map((stage) {
              return Text(
                '${stage.visitCount} Visits',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStageCard(RewardStageModel stage) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.confirmation_num_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stage.visitCount} Visits • ${stage.rewardDisplayTitle}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stage.previewSubtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_outline_rounded, color: Colors.white.withValues(alpha: 0.7), size: 16),
        ],
      ),
    );
  }

  // --- CONFIGURATION CARDS (RIGHT SIDE) ---
  Widget _buildConfigurationCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: How should visits be counted?
        _buildSectionCard(
          title: 'How should visits be counted?',
          subtitle: 'Choose what qualifies as a customer visit',
          icon: Icons.alt_route_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Every Visit', 'Minimum Spend', 'Specific Purchase'].map((trigger) {
                  final isSelected = _visitTrigger == trigger;
                  return ChoiceChip(
                    label: Text(trigger),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0D9488),
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _visitTrigger = trigger);
                      }
                    },
                  );
                }).toList(),
              ),
              if (_visitTrigger == 'Minimum Spend') ...[
                const SizedBox(height: 14),
                const Text('Trigger Minimum Spend (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                TextField(
                  controller: _triggerMinSpendCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8)),
                  ),
                ),
              ],
              if (_visitTrigger == 'Specific Purchase') ...[
                const SizedBox(height: 14),
                const Text('Required Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: ['All Items', 'Main Course', 'Beverages', 'Combos'].map((cat) {
                    final isSel = _specificCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSel,
                      selectedColor: const Color(0xFF0D9488),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF334155),
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onSelected: (val) {
                        if (val) setState(() => _specificCategory = cat);
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Section 2: Number of visits
        _buildSectionCard(
          title: 'Number of visits',
          subtitle: 'Target visits required for unlocking default milestone',
          icon: Icons.repeat_rounded,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    if (_visitCount > 1) {
                      setState(() => _visitCount--);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.remove, size: 18, color: Color(0xFF0F172A)),
                  ),
                ),
                Text(
                  '$_visitCount Visits',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0D9488)),
                ),
                InkWell(
                  onTap: () => setState(() => _visitCount++),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(Icons.add, size: 18, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Section 3: Reward Type
        _buildSectionCard(
          title: 'Reward type',
          subtitle: 'Select reward method to give when visits are reached',
          icon: Icons.card_giftcard_rounded,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['₹ Discount', '% Discount', 'Free Item', 'Cashback', 'Coupon'].map((type) {
              final isSelected = _rewardType == type;
              return ChoiceChip(
                label: Text(type),
                selected: isSelected,
                selectedColor: const Color(0xFF0D9488),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _rewardType = type;
                      if (_rewardType == '% Discount') {
                        _rewardValueCtrl.text = '15';
                      } else if (_rewardType == '₹ Discount') {
                        _rewardValueCtrl.text = '100';
                      }
                    });
                  }
                },
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // Section 4: Reward Value
        _buildSectionCard(
          title: _rewardType == 'Free Item' ? 'Free Item Name' : 'Reward value',
          subtitle: _rewardType == 'Free Item' ? 'Specify the gift item' : 'Amount or discount percentage',
          icon: Icons.confirmation_num_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_rewardType == 'Free Item') ...[
                TextField(
                  controller: _freeItemNameCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. Free Dessert / Cold Coffee',
                    prefixIcon: const Icon(Icons.redeem_rounded, color: Color(0xFF0D9488), size: 20),
                    errorText: _rewardValueError,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8)),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _rewardValueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixText: _rewardType.contains('%') ? '' : '₹ ',
                    suffixText: _rewardType.contains('%') ? '%' : '',
                    prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 15),
                    suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 15),
                    errorText: _rewardValueError,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8)),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Section 5: Minimum Purchase
        _buildSectionCard(
          title: 'Minimum purchase',
          subtitle: 'Customers must spend at least this amount to unlock the reward.',
          icon: Icons.currency_rupee_rounded,
          child: TextField(
            controller: _minPurchaseCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 15),
              errorText: _minPurchaseError,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8)),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Section 6: Reward Stages
        _buildSectionCard(
          title: 'Reward Stages',
          subtitle: 'Multi-milestone visit progression rewards',
          icon: Icons.stairs_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(_rewardStages.length, (idx) {
                final stage = _rewardStages[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Stage ${idx + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0D9488)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${stage.visitCount} Visits • ${stage.rewardDisplayTitle}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Min. spend ₹${stage.minimumPurchase.toInt()} • Valid ${stage.expiryDays}d',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0D9488)),
                        onPressed: () => _openAddEditStageModal(existingStage: stage, index: idx),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                        onPressed: () {
                          setState(() {
                            _rewardStages.removeAt(idx);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D9488),
                    side: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _openAddEditStageModal(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+ Add Reward Stage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Section 7: Program Name & Slogan (Mockup Customization)
        _buildSectionCard(
          title: 'Program Branding',
          subtitle: 'Customize program name and display text',
          icon: Icons.storefront_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What would you name your loyalty program?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextField(
                controller: _programNameCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  errorText: _programNameError,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8)),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Slogan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              TextField(
                controller: _sloganCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Applicable Order Types', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['Dine-In', 'Take-Away', 'Delivery'].map((type) {
                  final isSel = _selectedOrderType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: isSel,
                    selectedColor: const Color(0xFF0D9488),
                    backgroundColor: const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : const Color(0xFF334155),
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (val) {
                      if (val) setState(() => _selectedOrderType = type);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- REUSABLE SECTION CARD TEMPLATE ---
  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF0D9488), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // --- STICKY BOTTOM ACTION BAR (MOBILE / TABLET) ---
  Widget _buildBottomNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
              ),
              onPressed: _isSaving ? null : _handleNext,
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              label: const Icon(Icons.arrow_forward_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
