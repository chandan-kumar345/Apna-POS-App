import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/campaign_models.dart';
import '../services/campaign_service.dart';
import 'campaign_editor.dart';
import 'campaign_style.dart';
import 'mobile_campaign_data.dart';

class CustomerGroupDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  final CampaignOptions? options;
  final VoidCallback? onGroupUpdated;

  const CustomerGroupDetailsScreen({
    super.key,
    required this.group,
    this.options,
    this.onGroupUpdated,
  });

  @override
  State<CustomerGroupDetailsScreen> createState() =>
      _CustomerGroupDetailsScreenState();
}

class _CustomerGroupDetailsScreenState
    extends State<CustomerGroupDetailsScreen> {
  final CampaignService _campaignService = CampaignService();
  late Map<String, dynamic> _g;

  @override
  void initState() {
    super.initState();
    _g = Map<String, dynamic>.from(widget.group);
  }

  void _sendCampaign() async {
    CampaignOptions currentOptions = widget.options ??
        await MobileCampaignApi().options().catchError((_) => CampaignOptions({}));

    if (!mounted) return;

    final draft = MobileCampaignDraft();
    draft.group = (_g['id'] ?? _g['_id'] ?? '').toString();
    draft.title = 'Special for ${_g['name']}';

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CampaignEditor(
          api: MobileCampaignApi(),
          approved: false,
          options: currentOptions,
          draft: draft,
        ),
      ),
    );
  }

  void _addCustomers() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Add Customers to ${_g['name']}',
                style: campaignText(16, weight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1_outlined, color: teal),
                title: Text('Select from Customer List', style: campaignText(14)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _g['count'] = (_g['count'] as int? ?? 2480) + 1;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Customer added to group')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined, color: teal),
                title: Text('Import from CSV/Excel', style: campaignText(14)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Importing customer list...')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeCustomers() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Select customers to remove from this group')),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: teal),
              title: Text('Rename group', style: campaignText(14)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined, color: teal),
              title: Text('Export group contacts', style: campaignText(14)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contacts exported successfully')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
              title: Text(
                'Delete group',
                style: campaignText(14, color: const Color(0xFFDC2626)),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final id = (_g['id'] ?? _g['_id'] ?? '').toString();
                if (id.isNotEmpty) {
                  await _campaignService.deleteAudienceGroup(id);
                }
                widget.onGroupUpdated?.call();
                if (mounted) Navigator.pop(context, true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _g['name'] ?? 'Pizza Lovers';
    final count = _g['count'] ?? _g['totalNumbers'] ?? 2480;
    final fmt = NumberFormat.decimalPattern('en_IN');
    final desc = _g['description'] ??
        'Customers who frequently order pizza and are interested in new offers.';

    final createdDateStr = _g['createdDate'] ??
        (_g['createdAt'] != null
            ? DateFormat('d MMM yyyy').format(DateTime.parse(_g['createdAt'].toString()))
            : '12 Oct 2026');

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
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: campaignText(20, color: Colors.white, weight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => _showMoreMenu(),
              icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
              tooltip: 'Edit group',
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Top Group Banner Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF3EBFF), Color(0xFFEDE9FE), Color(0xFFE5D5FB)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFDDD6FE)),
              boxShadow: const [studioShadow],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_pizza_outlined,
                      color: Color(0xFFE65100),
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: campaignText(20, weight: FontWeight.w800, color: ink),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.people_alt_outlined,
                            size: 15,
                            color: Color(0xFF6B21A8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${fmt.format(count)} Customers',
                            style: campaignText(
                              13,
                              color: const Color(0xFF6B21A8),
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4 Action Buttons Row
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.campaign_outlined,
                  label: 'Send\nCampaign',
                  isPrimary: true,
                  onTap: _sendCampaign,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.person_add_alt_outlined,
                  label: 'Add\nCustomers',
                  onTap: _addCustomers,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.person_remove_outlined,
                  label: 'Remove\nCustomers',
                  iconColor: const Color(0xFFDC2626),
                  onTap: _removeCustomers,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.more_horiz_rounded,
                  label: '\nMore',
                  onTap: _showMoreMenu,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Group Details Section
          Text(
            'Group Details',
            style: campaignText(16, weight: FontWeight.w800),
          ),
          const SizedBox(height: 10),

          // Card 1: Description
          Container(
            padding: const EdgeInsets.all(14),
            decoration: campaignCard(radius: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEDE9FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.card_giftcard_outlined,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: campaignText(14, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        desc,
                        style: campaignText(13, color: muted, weight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Card 2: Created On
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: campaignCard(radius: 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF0284C7),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Created On',
                      style: campaignText(14, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      createdDateStr,
                      style: campaignText(13, color: muted),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: borderBlue, size: 22),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Card 3: Group Members
          InkWell(
            onTap: () {
              // Could navigate to member list
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: campaignCard(radius: 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.people_alt_outlined,
                      color: Color(0xFF16A34A),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group Members',
                        style: campaignText(14, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fmt.format(count),
                        style: campaignText(13, color: muted),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, color: borderBlue, size: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    bool isPrimary = false,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 78,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isPrimary ? teal : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: borderBlue.withValues(alpha: 0.7)),
          boxShadow: const [studioShadow],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isPrimary ? Colors.white : (iconColor ?? ink),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: campaignText(
                11,
                weight: FontWeight.w600,
                color: isPrimary ? Colors.white : (iconColor ?? ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
