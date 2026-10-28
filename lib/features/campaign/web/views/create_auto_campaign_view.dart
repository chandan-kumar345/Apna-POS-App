import 'package:flutter/material.dart';
import '../../models/campaign_models.dart';
import '../../services/campaign_service.dart';

class CreateAutoCampaignView extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onActivated;

  const CreateAutoCampaignView({
    super.key,
    required this.onCancel,
    required this.onActivated,
  });

  @override
  State<CreateAutoCampaignView> createState() => _CreateAutoCampaignViewState();
}

class _CreateAutoCampaignViewState extends State<CreateAutoCampaignView> {
  final CampaignService _campaignService = CampaignService();
  int _currentStep = 1; // 1: Trigger, 2: Conditions, 3: Message, 4: Schedule, 5: Review

  String _selectedTrigger = 'birthday';
  final String _customerType = 'All Customers';
  final String _orderCountCondition = 'Greater Than';
  final int _orderCount = 0;
  final String _lastOrderCondition = 'More than';
  final int _lastOrderDays = 30;
  final String _customerGroup = 'VIP Customers';
  bool _sendOnlyOnce = true;

  late TextEditingController _nameController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'Birthday Special');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 5) {
      setState(() => _currentStep++);
    } else {
      _activateAutoCampaign();
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    } else {
      widget.onCancel();
    }
  }

  Future<void> _activateAutoCampaign() async {
    setState(() => _isSubmitting = true);
    await _campaignService.createCampaign(
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Birthday Special',
      type: 'marketing',
      audience: CampaignAudienceModel(
        groupName: '$_customerType - $_customerGroup',
        recipientCount: _orderCount > 0 ? 120 : 320,
      ),
      channel: const CampaignChannelModel(name: 'Pizza 47', phoneNumber: '+91 98765 43210'),
      template: const CampaignTemplateModel(
        id: 'bday_offer',
        name: 'Birthday Offer',
        body: 'Happy Birthday! Treat yourself to a free chocolate lava cake on orders above ₹299 at Pizza 47.',
      ),
      scheduleMode: 'recurring',
      estimatedSendingTime: '10:00 AM Daily ($_orderCountCondition $_orderCount, $_lastOrderCondition $_lastOrderDays d, singleSend: $_sendOnlyOnce)',
    );
    setState(() => _isSubmitting = false);
    if (mounted) widget.onActivated();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          _buildHeaderBar(),
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
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    final steps = ['Trigger', 'Conditions', 'Message', 'Schedule', 'Review'];

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
          const Text(
            'Create Auto Campaign',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const Spacer(),
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

  Widget _buildCurrentStepBody() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Trigger();
      case 2:
        return _buildStep2Conditions();
      case 3:
      case 4:
      case 5:
        return _buildStep5Review();
      default:
        return _buildStep1Trigger();
    }
  }

  Widget _buildStep1Trigger() {
    final triggers = [
      {'key': 'birthday', 'title': 'Customer Birthday', 'subtitle': 'Send birthday wishes & offers', 'icon': Icons.cake_outlined, 'color': const Color(0xFFEA580C)},
      {'key': 'new_customer', 'title': 'New Customer', 'subtitle': 'Send welcome message when a new customer registers', 'icon': Icons.person_add_outlined, 'color': const Color(0xFF2563EB)},
      {'key': 'inactive_x_days', 'title': 'No Order for X Days', 'subtitle': 'Re-engagement campaign', 'icon': Icons.hourglass_empty_rounded, 'color': const Color(0xFF7C3AED)},
      {'key': 'post_purchase', 'title': 'Post Purchase', 'subtitle': 'Send message after a successful order', 'icon': Icons.receipt_long_rounded, 'color': const Color(0xFF059669)},
      {'key': 'loyalty_points', 'title': 'Loyalty Points', 'subtitle': 'Notify when points earned or redeemed', 'icon': Icons.stars_rounded, 'color': const Color(0xFFD97706)},
      {'key': 'custom_date', 'title': 'Custom Date', 'subtitle': 'Send on specific dates (e.g. festivals)', 'icon': Icons.event_rounded, 'color': const Color(0xFFE11D48)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Trigger', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Choose when the campaign should be sent automatically.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.1,
          ),
          itemCount: triggers.length,
          itemBuilder: (context, idx) {
            final t = triggers[idx];
            final isSelected = _selectedTrigger == t['key'];
            final color = t['color'] as Color;

            return InkWell(
              onTap: () => setState(() => _selectedTrigger = t['key'] as String),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFF95B1C) : const Color(0xFFE2E8F0),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected ? const Color(0x1AF95B1C) : Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(t['icon'] as IconData, color: color, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            t['title'] as String,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t['subtitle'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep2Conditions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Set Conditions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Define when the campaign should be triggered', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Type
              Row(
                children: [
                  const SizedBox(width: 140, child: Text('Customer Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('All Customers', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                          Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Order Count
              Row(
                children: [
                  const SizedBox(width: 140, child: Text('Order Count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Greater than', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                          Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const Text('0', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Last Order Date
              Row(
                children: [
                  const SizedBox(width: 140, child: Text('Last Order Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('More than', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                          Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const Text('30  days ago', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Customer Group
              Row(
                children: [
                  const SizedBox(width: 140, child: Text('Customer Group', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('VIP Customers', style: TextStyle(fontSize: 13, color: Color(0xFF0F172A))),
                          Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // + Add Condition Button
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16, color: Color(0xFFF95B1C)),
                label: const Text('Add Condition', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFF95B1C))),
              ),
              const Divider(height: 28, color: Color(0xFFE2E8F0)),

              // Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Send only once to each customer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  Switch(
                    value: _sendOnlyOnce,
                    onChanged: (val) => setState(() => _sendOnlyOnce = val),
                    activeThumbColor: const Color(0xFFF95B1C),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep5Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Review Auto Campaign', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text('Please review all details before activating', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
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
                  const Text('Auto Campaign Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                  TextButton(
                    onPressed: () => setState(() => _currentStep = 1),
                    child: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF95B1C))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildReviewRow('Campaign Name', _nameController.text),
              _buildReviewRow('Trigger', 'Customer Birthday'),
              _buildReviewRow('Audience', 'All Customers'),
              _buildReviewRow('WhatsApp Channel', 'Pizza 47 (+91 98765 43210)'),
              _buildReviewRow('Template', 'Birthday Offer'),
              _buildReviewRow('Send Timing', '10:00 AM'),
              _buildReviewRow('Active', 'Yes', isHighlight: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isHighlight ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

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
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _currentStep == 5 ? 'Activate Campaign' : 'Next',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
