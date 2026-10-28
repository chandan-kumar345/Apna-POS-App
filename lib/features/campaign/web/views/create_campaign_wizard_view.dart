import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/campaign_models.dart';
import '../../services/campaign_service.dart';
import '../widgets/campaign_submitted_dialog.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/models/menu_item_model.dart';
import '../../../../core/services/product_service.dart';

/// Campaign Creation & Reward Builder with Live Interactive Smartphone Preview
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

  bool _isLoading = true;
  bool _isSavingDraft = false;
  bool _isPublishing = false;
  String _savedStatus = 'Not saved yet'; // 'Not saved yet' | 'Saved as Draft' | 'Published'
  String? _persistedCampaignId;

  // Image 1: Order Types Selection
  final List<String> _selectedOrderTypes = ['Delivery', 'Take Away', 'Dine In'];

  // Image 2: Reward Details
  String _selectedRewardType = 'Flat Cash Discount';
  final List<String> _rewardTypeOptions = [
    'Flat Cash Discount',
    'Percentage Discount',
    'Free Gift / Item',
    'Buy 1 Get 1 (BOGO)',
    'Cashback',
  ];

  late TextEditingController _discountValueController;
  String _discountScope = 'whole_bill'; // 'whole_bill' | 'chosen_products'
  final List<MenuItemModel> _selectedProducts = [];

  bool _hasMinSpend = true;
  late TextEditingController _minSpendController;
  late TextEditingController _maxCashbackController;
  late TextEditingController _comboOfferTitleController;
  late TextEditingController _campaignTitleController;
  late TextEditingController _descriptionController;

  // Image 3: Coupon & Schedule Settings
  bool _useCustomCouponCode = false;
  late TextEditingController _couponCodeController;

  bool _hasSendSchedule = true;
  DateTime _sendDate = DateTime(2026, 10, 29);
  TimeOfDay _sendTime = const TimeOfDay(hour: 8, minute: 0);

  bool _hasExpiryDate = true;
  DateTime _expiryDate = DateTime(2026, 11, 28);

  String _redemptionPerCustomer = 'only_once'; // 'only_once' | 'multiple_times'
  bool _displayCouponInProfile = true;

  // Audience & Menu Products
  List<AudienceGroupModel> _audienceGroups = [];
  AudienceGroupModel? _selectedGroup;
  List<CampaignChannelModel> _channels = [];
  CampaignChannelModel? _selectedChannel;
  List<MenuItemModel> _menuProducts = [];

  @override
  void initState() {
    super.initState();

    final tpl = widget.initialTemplate;
    final initialTitle = tpl?.name ?? '🥂 New Year Special - Flat ₹300 OFF';
    final initialDesc = (tpl?.subtitle.isNotEmpty == true ? tpl!.subtitle : null) ??
        (tpl?.body.isNotEmpty == true ? tpl!.body : null) ??
        'Kick-start the New Year with guaranteed savings. Get a flat ₹300 OFF and enjoy stress-free shopping as you welcome the year with confidence and joy.';

    _discountValueController = TextEditingController(text: '300');
    _minSpendController = TextEditingController(text: '500');
    _maxCashbackController = TextEditingController(text: '200');
    _comboOfferTitleController = TextEditingController(text: '🥂 Grab Any 2 Combos & Enjoy 10% OFF!');
    _campaignTitleController = TextEditingController(text: initialTitle);
    _descriptionController = TextEditingController(text: initialDesc);
    _couponCodeController = TextEditingController(text: 'NEWYEAR300');

    // Attach listeners so live preview reacts immediately as user types
    _campaignTitleController.addListener(() => setState(() {}));
    _descriptionController.addListener(() => setState(() {}));
    _discountValueController.addListener(() => setState(() {}));
    _minSpendController.addListener(() => setState(() {}));
    _couponCodeController.addListener(() => setState(() {}));

    _loadInitialData();
  }

  @override
  void dispose() {
    _discountValueController.dispose();
    _minSpendController.dispose();
    _maxCashbackController.dispose();
    _comboOfferTitleController.dispose();
    _campaignTitleController.dispose();
    _descriptionController.dispose();
    _couponCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final groupsFuture = _campaignService.fetchAudienceGroups();
      final channelsFuture = _campaignService.fetchChannels();
      final productsFuture = _productService.fetchPosProducts(limit: 150);

      final results = await Future.wait([groupsFuture, channelsFuture, productsFuture]);

      if (mounted) {
        setState(() {
          _audienceGroups = results[0] as List<AudienceGroupModel>;
          _selectedGroup = _audienceGroups.isNotEmpty ? _audienceGroups.first : null;

          _channels = results[1] as List<CampaignChannelModel>;
          _selectedChannel = _channels.isNotEmpty ? _channels.first : null;

          _menuProducts = results[2] as List<MenuItemModel>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[CreateCampaignWizardView] _loadInitialData notice: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================================
  // SAVE DRAFT ACTION
  // =========================================================================
  Future<void> _saveDraft() async {
    setState(() => _isSavingDraft = true);

    final title = _campaignTitleController.text.trim().isNotEmpty
        ? _campaignTitleController.text.trim()
        : 'New Year Special - Flat ₹300 OFF';

    final reward = CampaignRewardDetailsModel(
      rewardType: _mapRewardTypeToKey(_selectedRewardType),
      discountAmount: double.tryParse(_discountValueController.text.trim()) ?? 300.0,
      discountScope: _discountScope,
      chosenProducts: _selectedProducts.map((p) => {'id': p.id, 'name': p.name, 'price': p.price}).toList(),
      hasMinSpend: _hasMinSpend,
      minSpendAmount: double.tryParse(_minSpendController.text.trim()) ?? 500.0,
      maxCashbackCap: double.tryParse(_maxCashbackController.text.trim()) ?? 200.0,
      comboOfferTitle: _comboOfferTitleController.text.trim(),
      campaignTitle: title,
      description: _descriptionController.text.trim(),
      termsAndConditions: [
        if (_hasMinSpend) 'Minimum purchase of ₹${_minSpendController.text.trim()} required.',
        '2 offers cannot be clubbed.',
        if (_selectedOrderTypes.isNotEmpty) 'Valid on ${_selectedOrderTypes.join(", ")}.',
      ],
    );

    final coupon = CampaignCouponSettingsModel(
      useCustomCouponCode: _useCustomCouponCode,
      customCouponCode: _couponCodeController.text.trim().toUpperCase(),
      hasSendSchedule: _hasSendSchedule,
      sendDate: _sendDate,
      sendTime: '${_sendTime.hourOfPeriod}:${_sendTime.minute.toString().padLeft(2, "0")} ${_sendTime.period == DayPeriod.am ? "AM" : "PM"}',
      hasExpiryDate: _hasExpiryDate,
      expiryDate: _expiryDate,
      redemptionPerCustomer: _redemptionPerCustomer,
      displayCouponInProfile: _displayCouponInProfile,
    );

    final audience = CampaignAudienceModel(
      source: 'group',
      groupName: _selectedGroup?.name ?? 'All Customers',
      recipientCount: _selectedGroup?.count ?? 320,
    );

    final channel = _selectedChannel ?? const CampaignChannelModel();
    final template = widget.initialTemplate ??
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
        scheduleMode: 'later',
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

  // =========================================================================
  // PUBLISH / NEXT ACTION
  // =========================================================================
  Future<void> _publishCampaign() async {
    final title = _campaignTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Campaign Title'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isPublishing = true);

    final reward = CampaignRewardDetailsModel(
      rewardType: _mapRewardTypeToKey(_selectedRewardType),
      discountAmount: double.tryParse(_discountValueController.text.trim()) ?? 300.0,
      discountScope: _discountScope,
      chosenProducts: _selectedProducts.map((p) => {'id': p.id, 'name': p.name, 'price': p.price}).toList(),
      hasMinSpend: _hasMinSpend,
      minSpendAmount: double.tryParse(_minSpendController.text.trim()) ?? 500.0,
      maxCashbackCap: double.tryParse(_maxCashbackController.text.trim()) ?? 200.0,
      comboOfferTitle: _comboOfferTitleController.text.trim(),
      campaignTitle: title,
      description: _descriptionController.text.trim(),
      termsAndConditions: [
        if (_hasMinSpend) 'Minimum purchase of ₹${_minSpendController.text.trim()} required.',
        '2 offers cannot be clubbed.',
        if (_selectedOrderTypes.isNotEmpty) 'Valid on ${_selectedOrderTypes.join(", ")}.',
      ],
    );

    final coupon = CampaignCouponSettingsModel(
      useCustomCouponCode: _useCustomCouponCode,
      customCouponCode: _couponCodeController.text.trim().toUpperCase(),
      hasSendSchedule: _hasSendSchedule,
      sendDate: _sendDate,
      sendTime: '${_sendTime.hourOfPeriod}:${_sendTime.minute.toString().padLeft(2, "0")} ${_sendTime.period == DayPeriod.am ? "AM" : "PM"}',
      hasExpiryDate: _hasExpiryDate,
      expiryDate: _expiryDate,
      redemptionPerCustomer: _redemptionPerCustomer,
      displayCouponInProfile: _displayCouponInProfile,
    );

    final audience = CampaignAudienceModel(
      source: 'group',
      groupName: _selectedGroup?.name ?? 'All Customers',
      recipientCount: _selectedGroup?.count ?? 320,
    );

    final channel = _selectedChannel ?? const CampaignChannelModel();
    final template = widget.initialTemplate ??
        CampaignTemplateModel(
          id: 'custom_reward_tpl',
          name: title,
          body: _descriptionController.text.trim(),
        );

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
      template: template,
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
              _campaignTitleController.text = 'Weekend Special Offer';
            });
          },
        ),
      );
    }
  }

  String _mapRewardTypeToKey(String label) {
    switch (label) {
      case 'Percentage Discount':
        return 'percent_discount';
      case 'Free Gift / Item':
        return 'free_gift';
      case 'Buy 1 Get 1 (BOGO)':
        return 'bogo';
      case 'Cashback':
        return 'cashback';
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

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Top Navigation & Action Header (Matching Image 2)
          _buildTopHeaderBar(),

          // Main 2-Column Responsive Body
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 920;

                if (isWide) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Interactive Smartphone Mockup
                        SizedBox(
                          width: 370,
                          child: _buildLiveSmartphonePreview(),
                        ),
                        const SizedBox(width: 28),

                        // Right Column: Configuration Form (Scrollable)
                        Expanded(
                          child: SingleChildScrollView(
                            child: _buildRightConfigurationForm(),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Column(
                      children: [
                        _buildLiveSmartphonePreview(),
                        const SizedBox(height: 24),
                        _buildRightConfigurationForm(),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. TOP HEADER BAR (Matching Image 2)
  // =========================================================================
  Widget _buildTopHeaderBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Back button + Title: "Edit Reward"
          InkWell(
            onTap: widget.onCancel,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF0F172A)),
                  SizedBox(width: 8),
                  Text(
                    'Edit Reward',
                    style: TextStyle(
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

          // Saved Status Indicator (e.g. "Not saved yet" or "Saved as Draft")
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _savedStatus == 'Saved as Draft'
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _savedStatus == 'Saved as Draft'
                    ? const Color(0xFF86EFAC)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _savedStatus == 'Saved as Draft' ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  size: 13,
                  color: _savedStatus == 'Saved as Draft' ? const Color(0xFF15803D) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
                Text(
                  _savedStatus,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _savedStatus == 'Saved as Draft' ? const Color(0xFF15803D) : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Save Draft Button (App Default Navy Outline)
          OutlinedButton(
            onPressed: _isSavingDraft || _isPublishing ? null : _saveDraft,
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

          // Next / Publish Button (App Default Navy Solid)
          ElevatedButton(
            onPressed: _isSavingDraft || _isPublishing ? null : _publishCampaign,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryNavy,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            child: _isPublishing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Row(
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. LEFT COLUMN: LIVE SMARTPHONE PREVIEW (Matching Image 2)
  // =========================================================================
  Widget _buildLiveSmartphonePreview() {
    final restName = _db.restaurant?.name.isNotEmpty == true
        ? _db.restaurant!.name
        : ((_db.currentUser?.companyName != null && _db.currentUser!.companyName!.isNotEmpty)
            ? _db.currentUser!.companyName!
            : 'Loyalty Restaurant');

    final discountVal = _discountValueController.text.trim().isNotEmpty
        ? _discountValueController.text.trim()
        : '300';

    final isPercent = _selectedRewardType == 'Percentage Discount';
    final discountBadgeText = isPercent ? '$discountVal% OFF' : 'Flat ₹$discountVal OFF';

    final campaignTitle = _campaignTitleController.text.trim().isNotEmpty
        ? _campaignTitleController.text.trim()
        : 'New Year Special - Flat ₹300 OFF';

    final campaignDesc = _descriptionController.text.trim().isNotEmpty
        ? _descriptionController.text.trim()
        : 'Kick-start the New Year with guaranteed savings. Get a flat ₹300 OFF and enjoy stress-free shopping as you welcome the year with confidence and joy.';

    final couponCode = _couponCodeController.text.trim().isNotEmpty
        ? _couponCodeController.text.trim().toUpperCase()
        : 'FLAT300';

    return Center(
      child: Container(
        width: 340,
        height: 660,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), // Dark phone chassis
          borderRadius: BorderRadius.circular(42),
          border: Border.all(color: const Color(0xFF334155), width: 3.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
            BoxShadow(
              color: Color(0x1A082559),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                // Phone Screen Top Notch / Dynamic Island
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 96,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E293B),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Live Preview Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Restaurant Brand Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00C4D4),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    restName.isNotEmpty ? restName[0].toUpperCase() : 'K',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
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

                        // Banner Image (Festive dining / food photo)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 140,
                              width: double.infinity,
                              child: Image.asset(
                                'assets/images/campaign_hero_banner_full.png',
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
                        ),
                        const SizedBox(height: 12),

                        // Vibrant Pink Reward Voucher Card (Matching Image 2)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE91E63), Color(0xFFD81B60)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x38E91E63),
                                  blurRadius: 14,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Campaign Title & Badge
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
                                              style: const TextStyle(
                                                color: Color(0xFFD81B60),
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            campaignTitle,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14.5,
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
                                    color: Colors.white.withValues(alpha: 0.92),
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Dotted / subtle divider
                                Divider(color: Colors.white.withValues(alpha: 0.25), height: 1),
                                const SizedBox(height: 12),

                                // Terms & Conditions section
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.verified_outlined, size: 13, color: Colors.white),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Terms & conditions',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (_hasMinSpend)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                                    child: Text(
                                      '✓ Minimum purchase of ₹${_minSpendController.text.trim()} required.',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                                  child: Text(
                                    '✓ 2 offers cannot be clubbed.',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                                  ),
                                ),
                                if (_selectedOrderTypes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                                    child: Text(
                                      '✓ Valid on: ${_selectedOrderTypes.join(", ")}',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11),
                                    ),
                                  ),

                                const SizedBox(height: 14),
                                // How to Redeem Button / Code Box
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.confirmation_num_outlined, size: 15, color: Color(0xFFD81B60)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'CODE: $couponCode',
                                        style: const TextStyle(
                                          color: Color(0xFFD81B60),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12.5,
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
  // 3. RIGHT COLUMN: FULL CAMPAIGN CONFIGURATION FORM
  // =========================================================================
  Widget _buildRightConfigurationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section A: Order Types Selection (Matching Image 1)
        _buildOrderTypesCard(),
        const SizedBox(height: 18),

        // Section B: Offer & Reward Details (Matching Image 2)
        _buildOfferDetailsCard(),
        const SizedBox(height: 18),

        // Section C: Coupon, Schedule & Expiry Cards (Matching Image 3)
        _buildCouponSettingsCard(),
        const SizedBox(height: 18),
        _buildScheduleSettingsCard(),
        const SizedBox(height: 18),
        _buildExpirySettingsCard(),
        const SizedBox(height: 18),
        _buildRedemptionRulesCard(),
        const SizedBox(height: 18),
        _buildDisplayInProfileCard(),
        const SizedBox(height: 36),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // CARD 1: SELECT MARKETING CHANNELS & ORDER TYPE (Image 1)
  // -------------------------------------------------------------------------
  Widget _buildOrderTypesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4), // Soft light teal/mint background matching Image 1
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34D399), width: 1.3),
      ),
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

                // Row of 3 Multi-Selectable Order Types
                Row(
                  children: [
                    _buildOrderTypeButton('Delivery'),
                    const SizedBox(width: 8),
                    _buildOrderTypeButton('Take Away'),
                    const SizedBox(width: 8),
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

    return Expanded(
      child: InkWell(
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
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _primaryNavy : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? _primaryNavy : _borderGrey,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CARD 2: OFFER & REWARD DETAILS (Image 2)
  // -------------------------------------------------------------------------
  Widget _buildOfferDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34D399), width: 1.3),
      ),
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
          const SizedBox(height: 18),

          // 1. Select Reward Type Dropdown
          const Text('Select reward type', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _borderGrey),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRewardType,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                items: _rewardTypeOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRewardType = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Discount Amount Input Field
          Text(
            _selectedRewardType == 'Percentage Discount' ? 'Discount Percentage (%)' : 'Discount Cash (₹)',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _discountValueController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: '300',
              prefixIcon: Icon(
                _selectedRewardType == 'Percentage Discount' ? Icons.percent_rounded : Icons.currency_rupee_rounded,
                size: 16,
                color: const Color(0xFF64748B),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Whole Bill vs Chosen Products Toggle
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _discountScope = 'whole_bill'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _discountScope == 'whole_bill' ? _primaryNavy : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _discountScope == 'whole_bill' ? _primaryNavy : _borderGrey),
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
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _discountScope == 'whole_bill' ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _discountScope = 'chosen_products'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _discountScope == 'chosen_products' ? _primaryNavy : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _discountScope == 'chosen_products' ? _primaryNavy : _borderGrey),
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
                            fontSize: 12.5,
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
            const SizedBox(height: 12),
            _buildProductSelectorSection(),
          ],
          const SizedBox(height: 18),

          // 4. Set Minimum Spend Checkbox & Amount
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
                'Define the lowest purchase amount required for using the reward.',
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
            const SizedBox(height: 16),
          ],

          // 5. Maximum Cashback Cap (?)
          const Text('Maximum Cashback Cap (?)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
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
          const SizedBox(height: 16),

          // 6. Combo Offer Title
          const Text('Combo Offer Title', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: _comboOfferTitleController,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: '🥂 Grab Any 2 Combos & Enjoy 10% OFF!',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),

          // 7. Campaign Title
          const Text('Campaign title', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: _campaignTitleController,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: '🥂 New Year Special - Flat ₹300 OFF',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),

          // 8. Description
          const Text('Description', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.35),
            decoration: InputDecoration(
              hintText: 'Kick-start the New Year with guaranteed savings...',
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

  Widget _buildProductSelectorSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Products (${_selectedProducts.length})',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              TextButton.icon(
                onPressed: _showProductPickerDialog,
                icon: const Icon(Icons.add_rounded, size: 16, color: _primaryNavy),
                label: const Text('Add Products', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _primaryNavy)),
              ),
            ],
          ),
          if (_selectedProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No products selected yet. Tap "Add Products" to choose menu items.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedProducts.map((p) {
                return Chip(
                  label: Text('${p.name} (₹${p.price.toInt()})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  backgroundColor: Colors.white,
                  deleteIcon: const Icon(Icons.close_rounded, size: 14),
                  onDeleted: () => setState(() => _selectedProducts.remove(p)),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _showProductPickerDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Select Products for Campaign', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              content: SizedBox(
                width: 420,
                height: 380,
                child: _menuProducts.isEmpty
                    ? const Center(child: Text('No menu products found'))
                    : ListView.builder(
                        itemCount: _menuProducts.length,
                        itemBuilder: (c, i) {
                          final prod = _menuProducts[i];
                          final isChecked = _selectedProducts.any((p) => p.id == prod.id);

                          return CheckboxListTile(
                            value: isChecked,
                            activeColor: _primaryNavy,
                            title: Text(prod.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            subtitle: Text('₹${prod.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  _selectedProducts.add(prod);
                                } else {
                                  _selectedProducts.removeWhere((p) => p.id == prod.id);
                                }
                              });
                              setState(() {});
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done', style: TextStyle(color: _primaryNavy, fontWeight: FontWeight.w800)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // CARD 3A: FAVORITE COUPON CODE (Image 3)
  // -------------------------------------------------------------------------
  Widget _buildCouponSettingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34D399), width: 1.3),
      ),
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
                  const Text('Enable', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                  const SizedBox(width: 8),
                  Switch(
                    value: _useCustomCouponCode,
                    activeThumbColor: _primaryNavy,
                    activeTrackColor: _primaryNavy.withValues(alpha: 0.5),
                    onChanged: (val) => setState(() => _useCustomCouponCode = val),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Enable this option to use your own favorite coupon code instead of an auto-generated one.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          if (!_useCustomCouponCode)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    'Auto-generated coupon code will be used for this campaign.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                  ),
                ],
              ),
            )
          else
            TextField(
              controller: _couponCodeController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'e.g. NEWYEAR300',
                prefixIcon: const Icon(Icons.confirmation_num_outlined, size: 16, color: Color(0xFF64748B)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _borderGrey)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primaryNavy, width: 1.5)),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CARD 3B: CAMPAIGN SEND DATE & TIME (Image 3)
  // -------------------------------------------------------------------------
  Widget _buildScheduleSettingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34D399), width: 1.3),
      ),
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
              Switch(
                value: _hasSendSchedule,
                activeThumbColor: _primaryNavy,
                activeTrackColor: _primaryNavy.withValues(alpha: 0.5),
                onChanged: (val) => setState(() => _hasSendSchedule = val),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose when this campaign should be sent to customers. The campaign will automatically be delivered on the selected date and time.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

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
  // CARD 3C: CAMPAIGN EXPIRES DATE (Image 3)
  // -------------------------------------------------------------------------
  Widget _buildExpirySettingsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentTeal, width: 1.3),
      ),
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
  // CARD 3D: REDEMPTION PER CUSTOMER (Image 3)
  // -------------------------------------------------------------------------
  Widget _buildRedemptionRulesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34D399), width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Redemption Per Customer',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _redemptionPerCustomer = 'only_once'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _redemptionPerCustomer == 'only_once' ? _primaryNavy : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _redemptionPerCustomer == 'only_once' ? _primaryNavy : _borderGrey),
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
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _redemptionPerCustomer == 'only_once' ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _redemptionPerCustomer = 'multiple_times'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _redemptionPerCustomer == 'multiple_times' ? _primaryNavy : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _redemptionPerCustomer == 'multiple_times' ? _primaryNavy : _borderGrey),
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
                            fontSize: 12.5,
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
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // CARD 3E: DISPLAY COUPON IN PROFILE (Image 3)
  // -------------------------------------------------------------------------
  Widget _buildDisplayInProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34D399), width: 1.3),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Display Coupon in Profile',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 4),
                Text(
                  'Show this coupon on customer profiles & online ordering menu.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch(
            value: _displayCouponInProfile,
            activeThumbColor: _primaryNavy,
            activeTrackColor: _primaryNavy.withValues(alpha: 0.5),
            onChanged: (val) => setState(() => _displayCouponInProfile = val),
          ),
        ],
      ),
    );
  }
}
