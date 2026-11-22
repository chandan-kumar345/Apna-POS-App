import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/services/loyalty_service.dart';
import '../../campaign/mobile/campaign_style.dart';
import '../../campaign/mobile/customer_style.dart';

class CreateLoyaltyProgramScreen extends StatefulWidget {
  final LoyaltyProgramModel? programToEdit;
  final VoidCallback? onSaved;

  const CreateLoyaltyProgramScreen({
    super.key,
    this.programToEdit,
    this.onSaved,
  });

  @override
  State<CreateLoyaltyProgramScreen> createState() =>
      _CreateLoyaltyProgramScreenState();
}

class _CreateLoyaltyProgramScreenState
    extends State<CreateLoyaltyProgramScreen> {
  final LoyaltyService _loyaltyService = LoyaltyService();
  final DatabaseService _db = DatabaseService();

  int _currentStep = 0; // 0: Reward, 1: Rules, 2: Message, 3: Review
  bool _isSaving = false;

  // Step 1: Reward state
  String _selectedProgramType = 'cashback'; // cashback, points, discount, rewards
  late TextEditingController _nameController;
  late TextEditingController _descController;
  String _cashbackType = 'percentage'; // 'percentage' or 'fixed'
  late TextEditingController _rateController; // percentage or fixed amount

  // Step 2: Rules state
  late TextEditingController _minOrderController;
  late TextEditingController _maxCashbackController;
  late TextEditingController _validityController;
  String _eligibleAudience = 'All Customers';
  bool _dineInEnabled = true;
  bool _takeawayEnabled = true;
  bool _deliveryEnabled = true;

  // Step 3: Message state
  late TextEditingController _messageController;
  bool _sendAutoNotification = true;

  // Step 4: Review state
  bool _activateImmediately = true;

  @override
  void initState() {
    super.initState();
    final edit = widget.programToEdit;
    _selectedProgramType = edit != null
        ? (edit.type == LoyaltyType.visitMade ? 'points' : 'cashback')
        : 'cashback';

    _nameController = TextEditingController(
      text: edit?.title.isNotEmpty == true
          ? edit!.title
          : 'Cashback on Every Order',
    );
    _descController = TextEditingController(
      text: edit?.description.isNotEmpty == true
          ? edit!.description
          : 'Give cashback to customers on every purchase to build long-term loyalty.',
    );

    _cashbackType = edit?.cashbackType ?? 'percentage';
    final initialRate = _cashbackType == 'percentage'
        ? (edit?.cashbackPercentage ?? 5).toStringAsFixed(0)
        : (edit?.cashbackAmount ?? 50).toStringAsFixed(0);
    _rateController = TextEditingController(text: initialRate);

    final now = DateTime.now();
    final expiry = now.add(const Duration(days: 90));
    final defaultValidity = '${DateFormat('dd MMM yyyy').format(now)} – ${DateFormat('dd MMM yyyy').format(expiry)}';

    _minOrderController = TextEditingController(
      text: (edit?.minimumOrder ?? 499).toStringAsFixed(0),
    );
    _maxCashbackController = TextEditingController(
      text: (edit?.maximumCashback ?? 150).toStringAsFixed(0),
    );
    _validityController = TextEditingController(
      text: edit?.validity ?? defaultValidity,
    );
    _eligibleAudience = edit?.eligibleCustomers ?? 'All Customers';

    if (edit != null && edit.orderTypes.isNotEmpty) {
      _dineInEnabled = edit.orderTypes.contains('Dine-In');
      _takeawayEnabled = edit.orderTypes.contains('Takeaway');
      _deliveryEnabled = edit.orderTypes.contains('Delivery');
    }

    _messageController = TextEditingController(
      text: edit?.messageTemplate.isNotEmpty == true
          ? edit!.messageTemplate
          : 'Hi {{name}}! 🎉 Earn {{cashback}} cashback on your next order at {{store}}. Valid till {{expiry}}. T&C apply.',
    );
    _activateImmediately = edit?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _rateController.dispose();
    _minOrderController.dispose();
    _maxCashbackController.dispose();
    _validityController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  double get _currentRateValue {
    return double.tryParse(_rateController.text.trim()) ?? 5.0;
  }

  String get _calculatedExampleText {
    final rate = _currentRateValue;
    if (_cashbackType == 'percentage') {
      final cb = (1000 * rate / 100).round();
      return 'Example: On a bill of ₹1,000, customer will get ₹$cb cashback.';
    } else {
      final cb = rate.round();
      return 'Example: On a bill of ₹1,000, customer will get ₹$cb cashback.';
    }
  }

  List<String> get _selectedOrderTypes {
    final list = <String>[];
    if (_dineInEnabled) list.add('Dine-In');
    if (_takeawayEnabled) list.add('Takeaway');
    if (_deliveryEnabled) list.add('Delivery');
    return list.isNotEmpty ? list : ['Dine-In', 'Takeaway', 'Delivery'];
  }

  Future<void> _saveProgram({required bool isDraft}) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a program name'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final progId = widget.programToEdit?.id ??
        'prog_cashback_${DateTime.now().millisecondsSinceEpoch}';
    final rate = _currentRateValue;
    final minOrder = double.tryParse(_minOrderController.text.trim()) ?? 499.0;
    final maxCashback =
        double.tryParse(_maxCashbackController.text.trim()) ?? 150.0;

    final programModel = LoyaltyProgramModel(
      id: progId,
      type: LoyaltyType.cashback,
      title: _nameController.text.trim(),
      description: _descController.text.trim(),
      earningRule: _cashbackType == 'percentage'
          ? 'Get ${rate.toStringAsFixed(0)}% cashback on all orders'
          : 'Get ₹${rate.toStringAsFixed(0)} cashback on orders above ₹${minOrder.toStringAsFixed(0)}',
      rewardCurrency: '₹',
      cashbackType: _cashbackType,
      cashbackPercentage: _cashbackType == 'percentage' ? rate : 5.0,
      cashbackAmount: _cashbackType == 'fixed' ? rate : 50.0,
      minimumOrder: minOrder,
      maximumCashback: maxCashback,
      validity: _validityController.text.trim(),
      startedDate: widget.programToEdit?.startedDate ?? DateFormat('dd MMM yyyy').format(DateTime.now()),
      eligibleCustomers: _eligibleAudience,
      orderTypes: _selectedOrderTypes,
      messageTemplate: _messageController.text.trim(),
      isActive: isDraft ? false : _activateImmediately,
      ordersCount: widget.programToEdit?.ordersCount ?? 0,
      cashbackGiven: widget.programToEdit?.cashbackGiven ?? 0.0,
      redemptionRate: widget.programToEdit?.redemptionRate ?? 0.0,
      membersCount: widget.programToEdit?.membersCount ?? 0,
    );

    bool ok;
    if (widget.programToEdit != null) {
      ok = await _loyaltyService.updateLoyaltyProgram(programModel);
    } else {
      ok = await _loyaltyService.createLoyaltyProgram(programModel);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDraft
                  ? 'Cashback program saved as draft'
                  : 'Cashback program created successfully!',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save program. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _onNext() {
    if (_currentStep < 3) {
      setState(() => _currentStep += 1);
    } else {
      _saveProgram(isDraft: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomerShell(
      header: _buildTopHeader(),
      body: Column(
        children: [
          // Wizard Stepper Bar
          _buildStepperHeader(),

          // Active Step Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: _buildCurrentStepBody(),
            ),
          ),
        ],
      ),
      footer: _buildFooterActions(),
    );
  }

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Text(
            widget.programToEdit != null
                ? 'Edit Loyalty Program'
                : 'Create Loyalty Program',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // Horizontal 4-step wizard bar matching Screen 2
  Widget _buildStepperHeader() {
    const stepNames = ['Reward', 'Rules', 'Message', 'Review'];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0F2942),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 0; i < stepNames.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 1.5,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: i <= _currentStep ? const Color(0xFF08435E) : const Color(0xFFE2E8F0),
                ),
              ),
            InkWell(
              onTap: () => setState(() => _currentStep = i),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: _currentStep == i ? 10 : 7,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _currentStep == i
                      ? const Color(0xFF08435E)
                      : (_currentStep > i ? const Color(0xFFE8F7F0) : Colors.transparent),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _currentStep == i
                        ? const Color(0xFF08435E)
                        : (_currentStep > i ? const Color(0xFF10B981) : Colors.transparent),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentStep > i)
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981))
                    else
                      Container(
                        width: 17,
                        height: 17,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _currentStep == i ? Colors.white.withOpacity(0.25) : const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _currentStep == i ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      stepNames[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _currentStep == i ? FontWeight.w700 : FontWeight.w500,
                        color: _currentStep == i
                            ? Colors.white
                            : (_currentStep > i ? const Color(0xFF065F46) : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCurrentStepBody() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Reward();
      case 1:
        return _buildStep2Rules();
      case 2:
        return _buildStep3Message();
      case 3:
      default:
        return _buildStep4Review();
    }
  }

  // STEP 1: Reward (Program type, name, description, cashback type, percentage, example)
  Widget _buildStep1Reward() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Program type', style: campaignText(14, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        _buildProgramTypeRow(),
        const SizedBox(height: 20),

        // Program Name
        RichText(
          text: TextSpan(
            text: 'Program name ',
            style: campaignText(14, weight: FontWeight.w600),
            children: const [
              TextSpan(
                text: '*',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildInputField(
          controller: _nameController,
          hint: 'e.g. Cashback on Every Order',
          prefixIcon: Icons.description_outlined,
        ),
        const SizedBox(height: 18),

        // Description
        Text(
          'Description (Optional)',
          style: campaignText(14, weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildInputField(
          controller: _descController,
          hint: 'Give cashback to customers on every purchase...',
          prefixIcon: Icons.subject_rounded,
          maxLines: 2,
        ),
        const SizedBox(height: 20),

        // Cashback Type Radio Selector
        Text('Cashback type', style: campaignText(14, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        _buildCashbackTypeRadios(),
        const SizedBox(height: 20),

        // Cashback percentage / amount
        RichText(
          text: TextSpan(
            text: _cashbackType == 'percentage'
                ? 'Cashback percentage '
                : 'Cashback amount ',
            style: campaignText(14, weight: FontWeight.w600),
            children: const [
              TextSpan(
                text: '*',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildRateInputField(),
        const SizedBox(height: 16),

        // Dynamic Example Info Box
        _buildExampleInfoBox(),
      ],
    );
  }

  // 4 Option cards in row: Cashback, Points, Discount, Rewards
  Widget _buildProgramTypeRow() {
    final types = [
      ('cashback', 'Cashback', Icons.currency_exchange_rounded, const Color(0xFF059669)),
      ('points', 'Points', Icons.card_giftcard_rounded, const Color(0xFF8B5CF6)),
      ('discount', 'Discount', Icons.local_offer_outlined, const Color(0xFFEC4899)),
      ('rewards', 'Rewards', Icons.military_tech_outlined, const Color(0xFFF59E0B)),
    ];

    return Row(
      children: [
        for (int i = 0; i < types.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedProgramType = types[i].$1),
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selectedProgramType == types[i].$1
                          ? const Color(0xFFE8F7F0)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selectedProgramType == types[i].$1
                            ? const Color(0xFF10B981)
                            : const Color(0xFFE2EAF2),
                        width: _selectedProgramType == types[i].$1 ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _selectedProgramType == types[i].$1
                              ? const Color(0x1810B981)
                              : const Color(0x0A0F2942),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(types[i].$3, color: types[i].$4, size: 21),
                        const SizedBox(height: 4),
                        Text(
                          types[i].$2,
                          style: campaignText(
                            11,
                            weight: _selectedProgramType == types[i].$1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _selectedProgramType == types[i].$1
                                ? const Color(0xFF065F46)
                                : ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedProgramType == types[i].$1)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Radio Options: Percentage Cashback (%) vs Fixed Cashback (₹)
  Widget _buildCashbackTypeRadios() {
    final isPercent = _cashbackType == 'percentage';
    final isFixed = _cashbackType == 'fixed';

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _cashbackType = 'percentage';
              _rateController.text = '5';
            });
          },
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isPercent ? const Color(0xFFEDF8F5) : Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isPercent ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                width: isPercent ? 1.5 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080F2942),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isPercent ? const Color(0xFF10B981) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPercent ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: isPercent
                      ? const Center(
                          child: CircleAvatar(radius: 4, backgroundColor: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  'Percentage Cashback (%)',
                  style: campaignText(
                    14,
                    weight: isPercent ? FontWeight.w700 : FontWeight.w500,
                    color: isPercent ? const Color(0xFF065F46) : ink,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            setState(() {
              _cashbackType = 'fixed';
              _rateController.text = '50';
            });
          },
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isFixed ? const Color(0xFFEDF8F5) : Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isFixed ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                width: isFixed ? 1.5 : 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080F2942),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isFixed ? const Color(0xFF10B981) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFixed ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                  ),
                  child: isFixed
                      ? const Center(
                          child: CircleAvatar(radius: 4, backgroundColor: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  'Fixed Cashback (₹)',
                  style: campaignText(
                    14,
                    weight: isFixed ? FontWeight.w700 : FontWeight.w500,
                    color: isFixed ? const Color(0xFF065F46) : ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRateInputField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F2942),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: campaignText(15, weight: FontWeight.w700, color: ink),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                hintText: _cashbackType == 'percentage' ? '5' : '50',
                prefixText: _cashbackType == 'fixed' ? '₹ ' : null,
                prefixStyle: campaignText(15, weight: FontWeight.w700, color: ink),
              ),
            ),
          ),
          if (_cashbackType == 'percentage')
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '%',
                style: campaignText(14, weight: FontWeight.w700, color: const Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExampleInfoBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFBAE6FD)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080284C7),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF0284C7),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _calculatedExampleText,
              style: campaignText(
                12,
                color: const Color(0xFF0369A1),
                weight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _calculatedExampleText,
              style: campaignText(
                13,
                color: const Color(0xFF1E40AF),
                weight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // STEP 2: Rules (Minimum Order, Max Cap, Validity, Order Types, Audience)
  Widget _buildStep2Rules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Earning Rules & Limits', style: campaignText(16, weight: FontWeight.w700)),
        const SizedBox(height: 14),

        // Minimum Order Value
        Text('Minimum Order Value (₹)', style: campaignText(14, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _minOrderController,
          hint: '499',
          prefixIcon: Icons.shopping_bag_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),

        // Maximum Cashback per Order
        Text('Maximum Cashback per Order (₹)', style: campaignText(14, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _maxCashbackController,
          hint: '150',
          prefixIcon: Icons.account_balance_wallet_outlined,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),

        // Validity
        Text('Validity Period', style: campaignText(14, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        _buildInputField(
          controller: _validityController,
          hint: 'e.g. 01 Jan 2026 – 31 Dec 2026',
          prefixIcon: Icons.calendar_today_outlined,
        ),
        const SizedBox(height: 16),

        // Applicable Order Types
        Text('Applicable Order Types', style: campaignText(14, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCheckboxChip('Dine-In', _dineInEnabled, (v) => setState(() => _dineInEnabled = v)),
            const SizedBox(width: 8),
            _buildCheckboxChip('Takeaway', _takeawayEnabled, (v) => setState(() => _takeawayEnabled = v)),
            const SizedBox(width: 8),
            _buildCheckboxChip('Delivery', _deliveryEnabled, (v) => setState(() => _deliveryEnabled = v)),
          ],
        ),
        const SizedBox(height: 16),

        // Eligible Customers
        Text('Eligible Customers', style: campaignText(14, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final audience in ['All Customers', 'VIP Customers', 'New Customers'])
              ChoiceChip(
                label: Text(audience),
                selected: _eligibleAudience == audience,
                onSelected: (val) {
                  if (val) setState(() => _eligibleAudience = audience);
                },
                selectedColor: const Color(0xFF08435E),
                labelStyle: TextStyle(
                  color: _eligibleAudience == audience ? Colors.white : ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckboxChip(String label, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFE6F7F0) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: value ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              color: value ? const Color(0xFF10B981) : muted,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: campaignText(12, weight: FontWeight.w600, color: value ? const Color(0xFF065F46) : ink),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 3: Message (Notification template, previews)
  Widget _buildStep3Message() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Customer Notification', style: campaignText(16, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          'Send an instant notification when customer earns cashback on their order.',
          style: campaignText(13, color: muted),
        ),
        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Auto-notify on order complete', style: campaignText(14, weight: FontWeight.w600)),
            Switch.adaptive(
              value: _sendAutoNotification,
              onChanged: (v) => setState(() => _sendAutoNotification = v),
              activeColor: const Color(0xFF10B981),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Text('Message Template', style: campaignText(14, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildInputField(
          controller: _messageController,
          hint: 'Template message...',
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Live Preview Bubble
        Text('Preview', style: campaignText(14, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFDCF8C6).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF16A34A), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _messageController.text
                      .replaceAll('{{name}}', 'Rahul')
                      .replaceAll('{{cashback}}', _cashbackType == 'percentage' ? '${_currentRateValue.toStringAsFixed(0)}%' : '₹${_currentRateValue.toStringAsFixed(0)}')
                      .replaceAll('{{store}}', _db.restaurant?.name.trim().isNotEmpty == true ? _db.restaurant!.name.trim() : 'Our Store')
                      .replaceAll('{{expiry}}', _validityController.text.contains('–') ? _validityController.text.split('–').last.trim() : '30 days'),
                  style: campaignText(13, color: ink, weight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 4: Review (Summary card, immediate activation toggle)
  Widget _buildStep4Review() {
    final rateStr = _cashbackType == 'percentage'
        ? '${_currentRateValue.toStringAsFixed(0)}% of order value'
        : '₹${_currentRateValue.toStringAsFixed(0)} per order';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review Program Details', style: campaignText(18, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Confirm the program terms before activating.', style: campaignText(13, color: muted)),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [studioShadow],
          ),
          child: Column(
            children: [
              _buildReviewRow(Icons.loyalty_rounded, 'Program Name', _nameController.text.trim()),
              const Divider(height: 16),
              _buildReviewRow(Icons.category_outlined, 'Program Type', 'Cashback'),
              const Divider(height: 16),
              _buildReviewRow(Icons.percent_rounded, 'Cashback', rateStr),
              const Divider(height: 16),
              _buildReviewRow(Icons.shopping_cart_outlined, 'Minimum Order', '₹${_minOrderController.text.trim()}'),
              const Divider(height: 16),
              _buildReviewRow(Icons.account_balance_wallet_outlined, 'Maximum Cashback', '₹${_maxCashbackController.text.trim()}'),
              const Divider(height: 16),
              _buildReviewRow(Icons.calendar_today_outlined, 'Validity', _validityController.text.trim()),
              const Divider(height: 16),
              _buildReviewRow(Icons.group_outlined, 'Eligible Customers', _eligibleAudience),
              const Divider(height: 16),
              _buildReviewRow(Icons.restaurant_outlined, 'Order Types', _selectedOrderTypes.join(', ')),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Activate immediately switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F7F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF10B981)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Activate program immediately',
                    style: campaignText(14, weight: FontWeight.w600, color: const Color(0xFF065F46)),
                  ),
                ],
              ),
              Switch.adaptive(
                value: _activateImmediately,
                onChanged: (v) => setState(() => _activateImmediately = v),
                activeColor: const Color(0xFF10B981),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF08435E)),
        const SizedBox(width: 10),
        Text(label, style: campaignText(13, color: muted)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: campaignText(13, weight: FontWeight.w600, color: ink),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    IconData? prefixIcon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F2942),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: campaignText(14, weight: FontWeight.w600, color: ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: hint,
          hintStyle: campaignText(13, color: const Color(0xFF94A3B8), weight: FontWeight.w400),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: const Color(0xFF64748B), size: 19)
              : null,
        ),
      ),
    );
  }

  // Footer Actions matching Screen 2: "Save Draft" on left, "Next ->" on right
  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _isSaving ? null : () => _saveProgram(isDraft: true),
            child: const Text(
              'Save Draft',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF08435E),
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          InkWell(
            onTap: _isSaving ? null : _onNext,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xFF08435E), Color(0xFF052B3C)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3308435E),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currentStep == 3 ? 'Create Program' : 'Next',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
