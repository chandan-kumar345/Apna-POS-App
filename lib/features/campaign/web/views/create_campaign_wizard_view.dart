import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/campaign_models.dart';
import '../../services/campaign_service.dart';
import '../widgets/whatsapp_phone_preview.dart';
import '../widgets/campaign_submitted_dialog.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/services/wallet_service.dart';

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
  final WalletService _walletService = WalletService();
  final DatabaseService _db = DatabaseService();

  int _currentStep = 1; // 1 to 6
  bool _isLoading = true;
  bool _isSubmitting = false;

  // Step 1: Type
  String _selectedType = 'marketing'; // 'marketing' or 'utility'

  // Step 2: Audience
  String _selectedAudienceSource = 'group'; // 'all', 'group', 'segment', 'upload', 'manual'
  AudienceGroupModel? _selectedGroup;
  List<AudienceGroupModel> _audienceGroups = [];
  String _groupSearch = '';

  // Step 3: Channel
  CampaignChannelModel? _selectedChannel;
  List<CampaignChannelModel> _channels = [];

  // Step 4: Message Template
  CampaignTemplateModel? _selectedTemplate;
  List<CampaignTemplateModel> _templates = [];
  String _templateSearch = '';

  // Step 5: Schedule
  String _scheduleMode = 'later'; // 'now', 'later', 'recurring'
  DateTime _scheduledDate = DateTime(2026, 10, 25);
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 11, minute: 0);

  // Step 6: Review & Campaign Name
  late TextEditingController _campaignNameController;
  WalletBalanceData? _walletBalance;

  @override
  void initState() {
    super.initState();
    final initialName = widget.initialTemplate?.name ?? 'Diwali Special Offer';
    _campaignNameController = TextEditingController(text: initialName);
    if (widget.initialTemplate != null) {
      _selectedTemplate = widget.initialTemplate;
      _selectedType = widget.initialTemplate!.category.toLowerCase() == 'utility' ? 'utility' : 'marketing';
    }
    _loadInitialData();
  }

  @override
  void dispose() {
    _campaignNameController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final groups = await _campaignService.fetchAudienceGroups();
    final channels = await _campaignService.fetchChannels();
    final templates = await _campaignService.fetchTemplates();
    WalletBalanceData? wallet;
    try {
      wallet = await _walletService.getWalletDetails();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _audienceGroups = groups;
        _selectedGroup = groups.isNotEmpty ? groups.first : null;
        _channels = channels;
        _selectedChannel = channels.isNotEmpty ? channels.first : null;
        _templates = templates;
        _selectedTemplate = widget.initialTemplate ?? (templates.isNotEmpty ? templates.first : null);
        _walletBalance = wallet ?? const WalletBalanceData(balance: 1250.50);
        _isLoading = false;
      });
    }
  }

  int get _recipientCount {
    if (_selectedAudienceSource == 'all') return 1450;
    return _selectedGroup?.count ?? 320;
  }

  double get _ratePerMessage => _selectedType == 'utility' ? 0.21 : 0.90;
  double get _subtotal => _recipientCount * _ratePerMessage;
  double get _gst => _subtotal * 0.18;
  double get _totalAmount => _subtotal + _gst;

  String get _estimatedSendingTimeString {
    if (_scheduleMode == 'now') return 'Start sending immediately';
    final dateStr = DateFormat('dd MMM yyyy').format(_scheduledDate);
    final timeStr = _scheduledTime.format(context);
    return '$dateStr, $timeStr';
  }

  void _nextStep() {
    if (_currentStep < 6) {
      setState(() => _currentStep++);
    } else {
      _submitCampaign();
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      widget.onCancel();
    }
  }

  Future<void> _submitCampaign() async {
    setState(() => _isSubmitting = true);

    final audience = CampaignAudienceModel(
      source: _selectedAudienceSource,
      groupName: _selectedAudienceSource == 'all' ? 'All Customers' : (_selectedGroup?.name ?? 'VIP Customers'),
      recipientCount: _recipientCount,
    );

    final channel = _selectedChannel ?? const CampaignChannelModel();
    final template = _selectedTemplate ??
        const CampaignTemplateModel(id: 'diwali_offer', name: 'Diwali Offer');

    final DateTime scheduledDateTime = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );

    final created = await _campaignService.createCampaign(
      name: _campaignNameController.text.trim().isNotEmpty
          ? _campaignNameController.text.trim()
          : 'Diwali Special Offer',
      type: _selectedType,
      audience: audience,
      channel: channel,
      template: template,
      scheduleMode: _scheduleMode,
      scheduledAt: _scheduleMode == 'now' ? DateTime.now() : scheduledDateTime,
      estimatedSendingTime: _estimatedSendingTimeString,
    );

    setState(() => _isSubmitting = false);

    if (created != null && mounted) {
      // Show Submission Dialog
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
              _currentStep = 1;
              _campaignNameController.text = 'New Menu Launch';
            });
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFF95B1C)));
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Wizard Stepper Bar
          _buildStepperHeader(),

          // Step Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: _buildCurrentStepBody(),
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildStepperHeader() {
    final steps = ['Type', 'Audience', 'Channel', 'Message', 'Schedule', 'Review'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _prevStep,
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 14),
          Text(
            _getStepTitle(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          // Numbered Stepper Chips
          Row(
            children: List.generate(steps.length, (idx) {
              final stepNum = idx + 1;
              final isCurrent = _currentStep == stepNum;
              final isDone = _currentStep > stepNum;

              return Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrent
                          ? const Color(0xFFF95B1C)
                          : (isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : Text(
                              '$stepNum',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    steps[idx],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    ),
                  ),
                  if (idx < steps.length - 1)
                    Container(
                      width: 28,
                      height: 1.5,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: isDone ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return 'Create Campaign';
      case 2:
        return 'Select Audience';
      case 3:
        return 'Channel Selection';
      case 4:
        return 'Message Template';
      case 5:
        return 'Schedule Campaign';
      case 6:
        return 'Review & Send';
      default:
        return 'Create Campaign';
    }
  }

  Widget _buildCurrentStepBody() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Type();
      case 2:
        return _buildStep2Audience();
      case 3:
        return _buildStep3Channel();
      case 4:
        return _buildStep4Template();
      case 5:
        return _buildStep5Schedule();
      case 6:
        return _buildStep6Review();
      default:
        return _buildStep1Type();
    }
  }

  // ==========================================
  // STEP 1: CAMPAIGN TYPE
  // ==========================================
  Widget _buildStep1Type() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Campaign Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose the type of campaign you want to send to your customers.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTypeCard(
                type: 'marketing',
                title: 'Marketing Campaign',
                subtitle: 'Send promotional offers, new items, discounts and announcements.',
                price: '₹0.90 + 18% GST',
                icon: Icons.campaign_rounded,
                iconColor: const Color(0xFFEA580C),
                iconBg: const Color(0xFFFFF7ED),
                features: [
                  'Promotional offers',
                  'New menu launch',
                  'Seasonal campaigns',
                  'Loyalty offers',
                  'Re-engagement messages',
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTypeCard(
                type: 'utility',
                title: 'Utility Campaign',
                subtitle: 'Send transactional and service related messages.',
                price: '₹0.21 + 18% GST',
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBg: const Color(0xFFEFF6FF),
                features: [
                  'Order updates',
                  'Booking confirmations',
                  'Order reminders',
                  'Feedback requests',
                  'Account notifications',
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required String type,
    required String title,
    required String subtitle,
    required String price,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required List<String> features,
  }) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0x1AF95B1C) : Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFFCBD5E1),
                      width: isSelected ? 6.5 : 1.5,
                    ),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFF0F172A),
                    ),
                  ),
                  const Text('  per message', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 16),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: iconColor),
                      const SizedBox(width: 8),
                      Text(
                        f,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 2: AUDIENCE SELECTION
  // ==========================================
  Widget _buildStep2Audience() {
    final audienceSources = [
      {'key': 'all', 'title': 'All Customers', 'subtitle': 'Send to all customers in your database', 'icon': Icons.people_outline_rounded},
      {'key': 'group', 'title': 'Customer Group', 'subtitle': 'Select from your saved customer groups', 'icon': Icons.groups_outlined},
      {'key': 'segment', 'title': 'Customer Segment', 'subtitle': 'Filter customers by conditions', 'icon': Icons.tune_rounded},
      {'key': 'upload', 'title': 'Upload Customers', 'subtitle': 'Upload mobile numbers via Excel/CSV', 'icon': Icons.upload_file_rounded},
      {'key': 'manual', 'title': 'Manual Selection', 'subtitle': 'Select customers manually', 'icon': Icons.person_add_outlined},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Audience',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose which customers will receive this campaign',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Audience Sources
            Expanded(
              flex: 5,
              child: Column(
                children: audienceSources.map((source) {
                  final isSelected = _selectedAudienceSource == source['key'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => setState(() => _selectedAudienceSource = source['key'] as String),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                source['icon'] as IconData,
                                color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFF64748B),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    source['title'] as String,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    source['subtitle'] as String,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFFCBD5E1),
                                  width: isSelected ? 5.5 : 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 24),

            // Right Column: Customer Groups Selection
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Group',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    TextField(
                      onChanged: (val) => setState(() => _groupSearch = val),
                      decoration: InputDecoration(
                        hintText: 'Search groups...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_audienceGroups.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No audience groups found.\nCreate a group using the "Create Group" button on the dashboard.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      )
                    else
                      ..._audienceGroups
                        .where((g) => g.name.toLowerCase().contains(_groupSearch.toLowerCase()))
                        .map((group) {
                      final isChecked = _selectedGroup?.id == group.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => setState(() => _selectedGroup = group),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isChecked ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isChecked ? const Color(0xFFF95B1C) : const Color(0xFFE2E8F0),
                                width: isChecked ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isChecked ? const Color(0xFFF95B1C) : const Color(0xFF94A3B8),
                                      width: isChecked ? 5.5 : 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    group.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    '${group.count} customers',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // STEP 3: CHANNEL SELECTION
  // ==========================================
  Widget _buildStep3Channel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Channel Selection',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose which WhatsApp sender channel will be used to deliver the campaign',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        Row(
          children: _channels.map((chan) {
            final isSelected = _selectedChannel?.id == chan.id;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: () => setState(() => _selectedChannel = chan),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFFE2E8F0),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected ? const Color(0x1AF95B1C) : Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: chan.channelType == 'business_whatsapp'
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: chan.channelType == 'business_whatsapp'
                                    ? const Icon(Icons.chat_rounded, color: Color(0xFF16A34A), size: 24)
                                    : const Text('🍕', style: TextStyle(fontSize: 20)),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: chan.badge == 'Connected' ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                chan.badge,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: chan.badge == 'Connected' ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          chan.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          chan.description,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chan.businessName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                chan.phoneNumber,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                              if (chan.phoneNumberId.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Phone Number ID: ${chan.phoneNumberId}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Helper Note Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'If you are not connected with your own Meta WhatsApp API, the campaign will be sent using Sooftcode shared number.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // STEP 4: MESSAGE TEMPLATE
  // ==========================================
  Widget _buildStep4Template() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Message Template',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose which approved template will be used to send the campaign',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Templates List
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search & Filters bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _templateSearch = val),
                          decoration: InputDecoration(
                            hintText: 'Search templates...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                            isDense: true,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          children: [
                            Text('All Categories', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                            Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF475569)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Text('EN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Template Cards
                  ..._templates
                      .where((t) => t.name.toLowerCase().contains(_templateSearch.toLowerCase()))
                      .map((t) {
                    final isSelected = _selectedTemplate?.id == t.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => setState(() => _selectedTemplate = t),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFF94A3B8),
                                    width: isSelected ? 5.5 : 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.name,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      t.body.replaceAll('\n', ' '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: t.category.toLowerCase() == 'marketing'
                                      ? const Color(0xFFFFF7ED)
                                      : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  t.category,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: t.category.toLowerCase() == 'marketing'
                                        ? const Color(0xFFEA580C)
                                        : const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('EN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(width: 28),

            // Right Column: Realistic WhatsApp Phone Mockup
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Template Preview',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  WhatsAppPhonePreview(
                    businessName: _db.restaurant?.name.isNotEmpty == true ? _db.restaurant!.name : 'Pizza 47',
                    messageBody: _selectedTemplate?.body ??
                        'Hi Rahul,\n🎉 Celebrate this Diwali with our special offers!\nGet 50% OFF on all Pizzas.\nUse Code: DIWALI50\nValid till 15 Nov.\nOrder now and make your celebrations special! 🍕',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // STEP 5: SCHEDULE CAMPAIGN
  // ==========================================
  Widget _buildStep5Schedule() {
    final scheduleOptions = [
      {'key': 'now', 'title': 'Send Now', 'subtitle': 'Start sending immediately', 'icon': Icons.bolt_rounded},
      {'key': 'later', 'title': 'Schedule for Later', 'subtitle': 'Select date and time', 'icon': Icons.schedule_rounded},
      {'key': 'recurring', 'title': 'Recurring Campaign', 'subtitle': 'Set up automatic recurring campaign', 'icon': Icons.update_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Schedule Campaign',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose when this campaign will be dispatched to your customers.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Options
            Expanded(
              flex: 5,
              child: Column(
                children: scheduleOptions.map((opt) {
                  final isSelected = _scheduleMode == opt['key'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => setState(() => _scheduleMode = opt['key'] as String),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.8 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                opt['icon'] as IconData,
                                color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFF64748B),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt['title'] as String,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  ),
                                  Text(
                                    opt['subtitle'] as String,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFFCBD5E1),
                                  width: isSelected ? 5.5 : 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 24),

            // Right Column: Date & Time Pickers
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Schedule Details',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 16),
                    // Date picker field
                    const Text('Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _scheduledDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setState(() => _scheduledDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(_scheduledDate),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Time picker field
                    const Text('Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _scheduledTime,
                        );
                        if (picked != null) setState(() => _scheduledTime = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _scheduledTime.format(context),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Estimated sending banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFEDD5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, color: Color(0xFFEA580C), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Estimated Sending Time', style: TextStyle(fontSize: 10, color: Color(0xFF9A3412))),
                                Text(
                                  _estimatedSendingTimeString,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFEA580C)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Gradual pacing notice
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 14),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Messages will be sent gradually to avoid blocking.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // STEP 6: REVIEW & SEND
  // ==========================================
  Widget _buildStep6Review() {
    final balance = _walletBalance?.balance ?? 1250.50;
    final hasEnoughBalance = balance >= _totalAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review & Send',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Please review all details before sending the campaign',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Campaign Details & Cost Estimation
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  // Campaign Details Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Campaign Details',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _currentStep = 1),
                              child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF95B1C))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Campaign Name Field
                        TextField(
                          controller: _campaignNameController,
                          decoration: InputDecoration(
                            labelText: 'Campaign Name',
                            labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 14),
                        _buildReviewRow('Campaign Type', _selectedType == 'utility' ? 'Utility' : 'Marketing'),
                        _buildReviewRow(
                          'Audience',
                          _selectedAudienceSource == 'all'
                              ? 'All Customers ($_recipientCount customers)'
                              : '${_selectedGroup?.name ?? 'VIP Customers'} ($_recipientCount customers)',
                        ),
                        _buildReviewRow('WhatsApp Channel', '${_selectedChannel?.businessName ?? 'Pizza 47'} (${_selectedChannel?.phoneNumber ?? '+91 98765 43210'})'),
                        _buildReviewRow('Template', _selectedTemplate?.name ?? 'Diwali Offer'),
                        _buildReviewRow('Schedule', _estimatedSendingTimeString),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Cost Estimation Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cost Estimation',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 12),
                        _buildCostRow('Messages', '$_recipientCount'),
                        _buildCostRow('Rate (per message)', '₹${_ratePerMessage.toStringAsFixed(2)}'),
                        _buildCostRow('Subtotal', '₹${_subtotal.toStringAsFixed(2)}'),
                        _buildCostRow('GST (18%)', '₹${_gst.toStringAsFixed(2)}'),
                        const Divider(height: 20, color: Color(0xFFE2E8F0)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              '₹${_totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFF95B1C)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),

            // Right Column: Message Preview & Wallet Balance
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  // Message Preview Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Message Preview',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _currentStep = 4),
                              child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF95B1C))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCF8C6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _selectedTemplate?.body ??
                                'Hi Rahul,\n🎉 Celebrate this Diwali with our special offers!\nGet 50% OFF on all Pizzas.\nUse Code: DIWALI50\nValid till 15 Nov.\nOrder now and make your celebrations special! 🍕',
                            style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF111827)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Wallet Balance Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wallet Balance',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${balance.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: hasEnoughBalance ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasEnoughBalance ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                                color: hasEnoughBalance ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                hasEnoughBalance
                                    ? 'Sufficient balance to send this campaign'
                                    : 'Insufficient balance. Please recharge wallet.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: hasEnoughBalance ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  // ==========================================
  // BOTTOM ACTION BAR
  // ==========================================
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _currentStep == 1 ? widget.onCancel : _prevStep,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              _currentStep == 1 ? 'Cancel' : 'Back',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF95B1C),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 28),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _currentStep == 6
                          ? (_scheduleMode == 'now' ? 'Send Campaign' : 'Schedule Campaign')
                          : 'Next',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
