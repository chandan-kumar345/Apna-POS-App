import 'package:flutter/material.dart';
import '../../models/campaign_models.dart';
import '../../services/campaign_service.dart';

class UseTemplateDispatchView extends StatefulWidget {
  final CampaignTemplateModel template;
  final VoidCallback onBack;
  final ValueChanged<CampaignModel>? onCampaignSent;

  const UseTemplateDispatchView({
    super.key,
    required this.template,
    required this.onBack,
    this.onCampaignSent,
  });

  @override
  State<UseTemplateDispatchView> createState() => _UseTemplateDispatchViewState();
}

class _UseTemplateDispatchViewState extends State<UseTemplateDispatchView> {
  final CampaignService _campaignService = CampaignService();
  final TextEditingController _campaignNameController = TextEditingController();
  final TextEditingController _phoneInputController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();

  final List<String> _enteredNumbers = [];
  final Set<String> _selectedGroupIds = {};
  List<AudienceGroupModel> _availableGroups = [];

  bool _isLoadingGroups = true;
  bool _isSending = false;
  String _sendMode = 'direct_number'; // 'direct_number' | 'groups' | 'both'
  double _walletBalance = 98.95;

  @override
  void initState() {
    super.initState();
    _campaignNameController.text = '${widget.template.name} - Broadcast';
    _customerNameController.text = 'Valued Customer';
    _loadAudienceGroupsAndWallet();
  }

  @override
  void dispose() {
    _campaignNameController.dispose();
    _phoneInputController.dispose();
    _customerNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAudienceGroupsAndWallet() async {
    setState(() => _isLoadingGroups = true);
    try {
      final groups = await _campaignService.fetchAudienceGroups();
      final stats = await _campaignService.fetchDashboardStats();
      if (mounted) {
        setState(() {
          _availableGroups = groups;
          _walletBalance = stats.walletBalance > 0 ? stats.walletBalance : 98.95;
          _isLoadingGroups = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingGroups = false);
    }
  }

  void _syncNumbersFromTextArea(String rawInput) {
    _enteredNumbers.clear();
    if (rawInput.trim().isEmpty) {
      setState(() {});
      return;
    }

    final parts = rawInput.split(RegExp(r'[\n,;]+'));
    for (var part in parts) {
      String clean = part.replaceAll(RegExp(r'[^0-9+]'), '').trim();
      if (clean.isEmpty) continue;

      if (!clean.startsWith('+')) {
        if (clean.length == 10) {
          clean = '+91$clean';
        } else if (clean.length == 12 && clean.startsWith('91')) {
          clean = '+$clean';
        } else {
          clean = '+91$clean';
        }
      }

      if (!_enteredNumbers.contains(clean)) {
        _enteredNumbers.add(clean);
      }
    }
    setState(() {});
  }

  void _quickAddMyNumber() {
    const myNum = '9709593705';
    final currentText = _phoneInputController.text.trim();
    if (currentText.isEmpty) {
      _phoneInputController.text = myNum;
    } else {
      final parts = currentText.split(RegExp(r'[\n,;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (!parts.any((p) => p.contains('9709593705'))) {
        _phoneInputController.text = '$currentText, $myNum';
      }
    }
    _syncNumbersFromTextArea(_phoneInputController.text);
  }

  void _removePhoneNumber(String phoneNum) {
    setState(() {
      _enteredNumbers.remove(phoneNum);
      // Remove country code prefix +91 for clean display in textarea if present
      final cleanList = _enteredNumbers.map((n) => n.startsWith('+91') ? n.substring(3) : n).toList();
      _phoneInputController.text = cleanList.join(', ');
    });
  }

  int get _totalRecipientCount {
    int count = _enteredNumbers.length;
    for (var grp in _availableGroups) {
      if (_selectedGroupIds.contains(grp.id)) {
        count += grp.totalNumbers > 0 ? grp.totalNumbers : 1;
      }
    }
    return count;
  }

  double get _estimatedCost {
    final count = _totalRecipientCount;
    final subtotal = count * 0.90;
    final gst = subtotal * 0.18;
    return subtotal + gst;
  }

  Future<void> _handleSendCampaign() async {
    if (_enteredNumbers.isEmpty && _phoneInputController.text.trim().isNotEmpty) {
      _syncNumbersFromTextArea(_phoneInputController.text);
    }

    if (_totalRecipientCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one mobile number or select an audience group'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final recipientsList = <CampaignRecipientModel>[];
      final custName = _customerNameController.text.trim().isNotEmpty
          ? _customerNameController.text.trim()
          : 'Valued Customer';

      // 1. Direct numbers
      for (final phone in _enteredNumbers) {
        recipientsList.add(
          CampaignRecipientModel(
            name: custName,
            phone: phone,
            status: 'pending',
          ),
        );
      }

      // 2. Audience groups contacts
      String groupNameSummary = 'Direct Numbers';
      if (_selectedGroupIds.isNotEmpty) {
        final selectedNames = <String>[];
        for (var grp in _availableGroups) {
          if (_selectedGroupIds.contains(grp.id)) {
            selectedNames.add(grp.name);
            for (var num in grp.numbers) {
              if (num.phone.isNotEmpty && !recipientsList.any((r) => r.phone == num.phone)) {
                recipientsList.add(
                  CampaignRecipientModel(
                    name: num.name.isNotEmpty ? num.name : custName,
                    phone: num.phone,
                    status: 'pending',
                  ),
                );
              }
            }
          }
        }
        if (selectedNames.isNotEmpty) {
          groupNameSummary = selectedNames.join(', ');
        }
      }

      final audienceModel = CampaignAudienceModel(
        source: _enteredNumbers.isNotEmpty && _selectedGroupIds.isEmpty ? 'manual' : 'group',
        groupName: _enteredNumbers.isNotEmpty && _selectedGroupIds.isNotEmpty
            ? 'Custom (${_enteredNumbers.length} numbers + $groupNameSummary)'
            : groupNameSummary,
        recipientCount: recipientsList.isNotEmpty ? recipientsList.length : _totalRecipientCount,
        recipients: recipientsList,
      );

      final channelModel = const CampaignChannelModel(
        id: 'business_whatsapp',
        channelType: 'business_whatsapp',
        name: 'Pizza 47 Official WhatsApp',
        phoneNumber: '+91 73036 32949',
        phoneNumberId: '1284061438133660',
        isConnected: true,
      );

      final campaignName = _campaignNameController.text.trim().isNotEmpty
          ? _campaignNameController.text.trim()
          : '${widget.template.name} - Instant Send';

      var createdCampaign = await _campaignService.createCampaign(
        name: campaignName,
        type: widget.template.metaCategory.toLowerCase() == 'utility' ? 'utility' : 'marketing',
        audience: audienceModel,
        channel: channelModel,
        template: widget.template,
        scheduleMode: 'now',
        status: 'running',
        rewardDetails: CampaignRewardDetailsModel(
          rewardType: 'flat_discount',
          discountAmount: 300,
          campaignTitle: widget.template.name,
          bannerImageUrl: widget.template.headerImageUrl,
        ),
        couponSettings: const CampaignCouponSettingsModel(
          useCustomCouponCode: true,
          customCouponCode: 'FLAT300D',
          couponCode: 'FLAT300D',
        ),
      );

      if (createdCampaign != null && createdCampaign.id.isNotEmpty) {
        final fresh = await _campaignService.fetchCampaignById(createdCampaign.id);
        if (fresh != null) {
          createdCampaign = fresh;
        }
      }

      if (mounted) {
        setState(() => _isSending = false);
        _showSuccessDialog(createdCampaign);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dispatch campaign: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showSuccessDialog(CampaignModel? campaign) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 36),
            ),
            const SizedBox(height: 18),
            const Text(
              'Campaign Dispatched Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'WhatsApp template message "${widget.template.name}" has been sent to $_totalRecipientCount recipient(s). Real-time delivery and read receipts are now tracking.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onBack();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Back to Dashboard',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569), fontSize: 13),
                    ),
                  ),
                ),
                if (campaign != null && widget.onCampaignSent != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onCampaignSent!(campaign);
                      },
                      icon: const Icon(Icons.analytics_rounded, size: 16),
                      label: const Text(
                        'View Performance',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF95B1C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Top Header Bar
          _buildHeaderBar(),

          // Main Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Template Preview & Message Details
                      Expanded(
                        flex: 5,
                        child: _buildTemplatePreviewCard(),
                      ),
                      const SizedBox(width: 24),

                      // Right Column: Enter Numbers & Select Groups
                      Expanded(
                        flex: 7,
                        child: _buildAudienceAndDispatchCard(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Back to Campaigns',
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Use Approved Template & Send',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 13, color: Color(0xFF16A34A)),
                        SizedBox(width: 4),
                        Text(
                          'Meta Approved',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Enter phone numbers or select customer groups to immediately dispatch this WhatsApp message.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const Spacer(),
          // Wallet Balance Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 16, color: Color(0xFFEA580C)),
                const SizedBox(width: 6),
                Text(
                  'Wallet: ₹${_walletBalance.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatePreviewCard() {
    // Generate formatted preview with live customer name substitution
    final custName = _customerNameController.text.trim().isNotEmpty
        ? _customerNameController.text.trim()
        : 'Customer';
    final previewBody = widget.template.body.replaceAll('{{1}}', custName);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'WhatsApp Message Preview',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.template.metaCategory,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // WhatsApp Chat Simulation Bubble
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEAE2), // WhatsApp wallpaper tone
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2D9C8)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      // Chat Bubble
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x10000000),
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image Header
                              if (widget.template.headerImageUrl.isNotEmpty)
                                SizedBox(
                                  height: 150,
                                  width: double.infinity,
                                  child: Image.network(
                                    widget.template.headerImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      color: const Color(0xFFE2E8F0),
                                      child: const Icon(Icons.image_rounded, size: 40, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ),

                              // Message Body
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      previewBody.isNotEmpty
                                          ? previewBody
                                          : 'Hi $custName We appreciate having you with us! Enjoy flat Rs. 300 OFF on your next order with code FLAT300D. Valid until 01/12/2026. Order now',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1E293B),
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${DateTime.now().hour % 12 == 0 ? 12 : DateTime.now().hour % 12}:${DateTime.now().minute.toString().padLeft(2, '0')} ${DateTime.now().hour >= 12 ? 'PM' : 'AM'}',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF3B82F6)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Interactive Action Button
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF2563EB)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Order Now / Claim Offer',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                    ),
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
                const SizedBox(height: 16),

                // Template Meta Specs info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildSpecRow('Template Name', widget.template.name),
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                      _buildSpecRow('Meta System Name', widget.template.metaTemplateName.isNotEmpty ? widget.template.metaTemplateName : 'diwali_holiday_offer____flat__300_off'),
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                      _buildSpecRow('Language', widget.template.language.toUpperCase()),
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                      _buildSpecRow('Meta Status', widget.template.metaStatus, isGreen: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isGreen ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAudienceAndDispatchCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            offset: Offset(0, 4),
            blurRadius: 16,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 1: Campaign Name
          const Text(
            'Campaign Name',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _campaignNameController,
            decoration: InputDecoration(
              hintText: 'e.g. Diwali WhatsApp Blast',
              prefixIcon: const Icon(Icons.campaign_rounded, size: 18, color: Color(0xFFF95B1C)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF95B1C), width: 1.5)),
            ),
          ),
          const SizedBox(height: 20),

          // Customer Name Placeholder
          const Text(
            'Customer Name (for {{1}} parameter)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _customerNameController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'e.g. Valued Customer',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF95B1C), width: 1.5)),
            ),
          ),
          const SizedBox(height: 24),

          // Step 2: Audience Selector (Direct Phone vs Groups)
          Row(
            children: [
              const Text(
                'Select Recipients',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const Spacer(),
              // Segmented Switch
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    _buildModeTab('direct_number', 'Enter Numbers'),
                    _buildModeTab('groups', 'Audience Groups'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_sendMode == 'direct_number') ...[
            // Quick Button for user test number
            InkWell(
              onTap: _quickAddMyNumber,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD4C2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFFEA580C)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Quick Add My Number (+91 97095 93705)',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFEA580C)),
                      ),
                    ),
                    Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFFEA580C)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Text Area Header with live count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.contact_phone_outlined, size: 16, color: Color(0xFFEA580C)),
                    SizedBox(width: 6),
                    Text(
                      'Enter Mobile Numbers (Separated by comma)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                if (_enteredNumbers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_enteredNumbers.length} Valid Numbers',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Big Multi-line Text Area for Multiple Numbers
            TextField(
              controller: _phoneInputController,
              maxLines: 12,
              minLines: 8,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.6,
                letterSpacing: 0.3,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w600,
              ),
              onChanged: (text) => _syncNumbersFromTextArea(text),
              decoration: InputDecoration(
                hintText: 'Paste or type multiple mobile numbers separated by commas or newlines...\n\nExample:\n9709593705, 9876543210, 8123456789,\n+917838710511, +919812345678',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.6),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.all(18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFF95B1C), width: 1.8)),
              ),
            ),
            const SizedBox(height: 8),

            // Helper Info & Clear All
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    'Paste or type 10-digit mobile numbers with or without +91, separated by commas.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
                if (_phoneInputController.text.isNotEmpty || _enteredNumbers.isNotEmpty)
                  InkWell(
                    onTap: () {
                      _phoneInputController.clear();
                      setState(() {
                        _enteredNumbers.clear();
                      });
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Clear All',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Added Numbers Chips List
            if (_enteredNumbers.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _enteredNumbers.map((phoneNum) {
                  return Chip(
                    backgroundColor: const Color(0xFFEFF6FF),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    label: Text(
                      phoneNum,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                    ),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF1D4ED8)),
                    onDeleted: () => _removePhoneNumber(phoneNum),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ] else ...[
            // Audience Groups Checkbox List
            if (_isLoadingGroups)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_availableGroups.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text('No audience groups found. You can switch to "Enter Numbers" to send to specific phone numbers.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              )
            else
              Column(
                children: _availableGroups.map((grp) {
                  final isSelected = _selectedGroupIds.contains(grp.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFFE2E8F0)),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedGroupIds.add(grp.id);
                          } else {
                            _selectedGroupIds.remove(grp.id);
                          }
                        });
                      },
                      activeColor: const Color(0xFFF95B1C),
                      title: Text(grp.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                      subtitle: Text('${grp.totalNumbers > 0 ? grp.totalNumbers : grp.count} contacts • ${grp.source}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ),
                  );
                }).toList(),
              ),
          ],
          const SizedBox(height: 24),

          // Recipient & Cost Calculation Summary Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Recipients:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                    Text('$_totalRecipientCount phone numbers', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Rate per Message:', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                    const Text('₹0.90 + 18% GST', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  ],
                ),
                const Divider(height: 16, color: Color(0xFFCBD5E1)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Estimated Cost:', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    Text('₹${_estimatedCost.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFEA580C))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons: Cancel & Next / Send WhatsApp Campaign
          Row(
            children: [
              OutlinedButton(
                onPressed: _isSending ? null : widget.onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _handleSendCampaign,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSending ? 'Sending via WhatsApp...' : 'Next: Send WhatsApp Message ($_totalRecipientCount)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF95B1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab(String mode, String label) {
    final isSelected = _sendMode == mode;
    return InkWell(
      onTap: () => setState(() => _sendMode = mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x10000000), offset: Offset(0, 1), blurRadius: 4)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
