import 'package:flutter/material.dart';
import '../models/campaign_models.dart';
import '../services/campaign_service.dart';
import 'campaign_style.dart';
import 'mobile_campaign_data.dart';

class CreateCustomerGroupScreen extends StatefulWidget {
  final CampaignOptions? options;
  final VoidCallback? onGroupCreated;

  const CreateCustomerGroupScreen({
    super.key,
    this.options,
    this.onGroupCreated,
  });

  @override
  State<CreateCustomerGroupScreen> createState() =>
      _CreateCustomerGroupScreenState();
}

class _CreateCustomerGroupScreenState extends State<CreateCustomerGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _campaignService = CampaignService();

  int _selectedMethod = 0; // 0: Select from list, 1: Add manually, 2: Import file
  int _selectedCount = 42;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = 'Weekend Pizza Offer';
    _descController.text =
        'Customers interested in weekend deals and special offers.';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final desc = _descController.text.trim();
      await _campaignService.createAudienceGroup(
        name: name,
        type: 'Customer',
        source: _selectedMethod == 0
            ? 'Customer List'
            : (_selectedMethod == 1 ? 'Manual' : 'File Import'),
        description: desc,
        numbers: [
          {'name': 'Rahul Sharma', 'phone': '+919876543210'},
          {'name': 'Ananya Patel', 'phone': '+919123456780'},
          {'name': 'Vikram Khanna', 'phone': '+919988766554'},
          {'name': 'Priya Mehta', 'phone': '+919876511223'},
        ],
      );

      if (mounted) {
        widget.onGroupCreated?.call();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "$name" created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group "$name" created')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CampaignShell(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(6, 2, 8, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
              tooltip: 'Back',
            ),
            const SizedBox(width: 4),
            Text(
              'Create Group',
              style: campaignText(20, color: Colors.white, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Hero Illustration / Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEEF2FF), Color(0xFFF8FAFC)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderBlue.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [studioShadow],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.groups_rounded,
                        color: Color(0xFF6366F1),
                        size: 32,
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.all(1),
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Create a Customer Group',
                  style: campaignText(18, weight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Group your customers to send targeted campaigns and offers.',
                  textAlign: TextAlign.center,
                  style: campaignText(13, color: muted, weight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Group Name *
          _fieldLabel('Group Name', required: true),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            style: campaignText(14),
            decoration: campaignInput(hint: 'e.g. Weekend Pizza Offer').copyWith(
              prefixIcon: const Icon(Icons.layers_outlined, color: muted, size: 20),
            ),
          ),
          const SizedBox(height: 16),

          // Description (Optional)
          _fieldLabel('Description (Optional)'),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            maxLines: 2,
            style: campaignText(14),
            decoration: campaignInput(
              hint: 'Customers interested in weekend deals and special offers.',
            ).copyWith(
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 22),
                child: Icon(Icons.description_outlined, color: muted, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Add Customers *
          _fieldLabel('Add Customers', required: true),
          const SizedBox(height: 8),

          _methodOption(
            index: 0,
            icon: Icons.groups_outlined,
            title: 'Select from Customer List',
            subtitle: 'Choose existing customers',
          ),
          const SizedBox(height: 8),

          _methodOption(
            index: 1,
            icon: Icons.person_add_alt_outlined,
            title: 'Add Manually',
            subtitle: 'Enter mobile numbers',
          ),
          const SizedBox(height: 8),

          _methodOption(
            index: 2,
            icon: Icons.upload_file_outlined,
            title: 'Import from File (CSV/Excel)',
            subtitle: 'Upload a list of customers',
          ),
          const SizedBox(height: 14),

          // Selected count confirmation card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8FAF0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_outlined, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 8),
                Text(
                  '$_selectedCount customers selected',
                  style: campaignText(13.5, color: ink, weight: FontWeight.w700),
                ),
                const Spacer(),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons: Cancel and Create Group
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderBlue),
                    ),
                    child: Text(
                      'Cancel',
                      style: campaignText(14, weight: FontWeight.w700, color: ink),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: _submitting ? null : _submit,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: teal,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: const [studioShadow],
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Create Group',
                            style: campaignText(14, weight: FontWeight.w700, color: Colors.white),
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

  Widget _fieldLabel(String label, {bool required = false}) {
    return Row(
      children: [
        Text(label, style: campaignText(13, weight: FontWeight.w700)),
        if (required) ...[
          const SizedBox(width: 3),
          const Text('*', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }

  Widget _methodOption({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedMethod == index;
    return InkWell(
      onTap: () => setState(() => _selectedMethod = index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8FAF0) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF16A34A) : borderBlue.withValues(alpha: 0.8),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected ? null : const [studioShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF16A34A) : borderBlue,
                  width: 2,
                ),
                color: isSelected ? const Color(0xFF16A34A) : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Icon(icon, color: isSelected ? const Color(0xFF16A34A) : muted, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: campaignText(
                      13.5,
                      weight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: campaignText(11.5, color: muted, weight: FontWeight.w400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
