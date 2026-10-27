import 'package:flutter/material.dart';
import '../../models/campaign_models.dart';
import '../../services/campaign_service.dart';

class AudienceGroupsView extends StatefulWidget {
  final VoidCallback onBack;
  final ValueChanged<AudienceGroupModel>? onGroupSelected;

  const AudienceGroupsView({
    super.key,
    required this.onBack,
    this.onGroupSelected,
  });

  @override
  State<AudienceGroupsView> createState() => _AudienceGroupsViewState();
}

class _AudienceGroupsViewState extends State<AudienceGroupsView> {
  final CampaignService _campaignService = CampaignService();

  List<AudienceGroupModel> _groups = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _itemsPerPage = 10;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    final list = await _campaignService.fetchAudienceGroups(search: _searchQuery);
    if (mounted) {
      setState(() {
        _groups = list;
        _isLoading = false;
      });
    }
  }

  void _openCreateGroupDialog({AudienceGroupModel? editGroup}) {
    final nameCtrl = TextEditingController(text: editGroup?.name ?? '');
    String selectedType = editGroup?.type ?? 'Mobile';
    final numbersCtrl = TextEditingController(
      text: editGroup != null
          ? editGroup.numbers.map((n) => n.phone).join('\n')
          : '',
    );

    showDialog(
      context: context,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final lines = numbersCtrl.text
              .split(RegExp(r'[\n,]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList();
          final count = lines.length;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            backgroundColor: Colors.white,
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(26),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.groups_rounded, color: Color(0xFF0052FF), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              editGroup != null ? 'Edit Audience Group' : 'Create Audience Group',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Group Name Input
                    const Text('Group Name *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. VIP Regulars, Weekend Diners',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0052FF), width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Type Dropdown
                    const Text('Source Type', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedType,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'Mobile', child: Text('Mobile (Direct Numbers)')),
                            DropdownMenuItem(value: 'Customer', child: Text('Customer (POS CRM)')),
                            DropdownMenuItem(value: 'Excel/CSV', child: Text('Excel/CSV Import')),
                            DropdownMenuItem(value: 'Segment', child: Text('Dynamic Segment')),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedType = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Numbers input
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Mobile Numbers', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: count > 0 ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$count numbers detected',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: count > 0 ? const Color(0xFF0052FF) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: numbersCtrl,
                      onChanged: (_) => setModalState(() {}),
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter phone numbers (separated by comma or newline)\ne.g.\n9876543210\n9123456789\n+919876543211',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0052FF), width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            final parsedNumbers = lines.map((p) => {'name': 'Contact', 'phone': p}).toList();

                            if (editGroup != null) {
                              await _campaignService.updateAudienceGroup(editGroup.id, {
                                'name': nameCtrl.text.trim(),
                                'type': selectedType,
                                'numbers': parsedNumbers,
                              });
                            } else {
                              await _campaignService.createAudienceGroup(
                                name: nameCtrl.text.trim(),
                                type: selectedType,
                                source: '$selectedType source',
                                numbers: parsedNumbers,
                              );
                            }

                            if (modalCtx.mounted) {
                              Navigator.pop(ctx);
                              _loadGroups();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0052FF),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            editGroup != null ? 'Save Changes' : 'Create Group',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openGroupGrabberDialog() {
    final groupNameCtrl = TextEditingController(text: 'POS Customers Grabbed');
    int minOrders = 0;

    showDialog(
      context: context,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            backgroundColor: Colors.white,
            child: Container(
              width: 520,
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.sync_alt_rounded, color: Color(0xFF0F172A), size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Group Grabber',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Extract phone numbers directly from your Apna POS customer history and orders into a new reusable audience group.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  const Text('Group Name *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: groupNameCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0052FF), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Filter By Minimum Orders', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildFilterChip('All Customers', minOrders == 0, () => setModalState(() => minOrders = 0)),
                      const SizedBox(width: 8),
                      _buildFilterChip('>= 2 Orders', minOrders == 2, () => setModalState(() => minOrders = 2)),
                      const SizedBox(width: 8),
                      _buildFilterChip('>= 5 Orders (VIP)', minOrders == 5, () => setModalState(() => minOrders = 5)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _campaignService.grabCustomerNumbers(
                            groupName: groupNameCtrl.text.trim(),
                            minOrders: minOrders,
                          );
                          if (modalCtx.mounted) {
                            Navigator.pop(ctx);
                            _loadGroups();
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Grab Contacts Now', style: TextStyle(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0052FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0052FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF0052FF) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _openViewMembersDialog(AudienceGroupModel group) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        child: Container(
          width: 540,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total: ${group.count} numbers • ${group.source}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: group.numbers.isEmpty
                    ? const Center(child: Text('No numbers saved in this group yet', style: TextStyle(color: Color(0xFF94A3B8))))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: group.numbers.length,
                        separatorBuilder: (context, index) => const Divider(height: 8, color: Color(0xFFE2E8F0)),
                        itemBuilder: (context, idx) {
                          final num = group.numbers[idx];
                          return Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                                child: const Center(child: Icon(Icons.phone, size: 14, color: Color(0xFF0052FF))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  num.phone,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                ),
                              ),
                              Text(num.name, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteGroup(AudienceGroupModel group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Audience Group?'),
        content: Text('Are you sure you want to delete "${group.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete Group'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _campaignService.deleteAudienceGroup(group.id);
      _loadGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Sub-Header / Breadcrumb Action Bar
          _buildSubHeaderBar(),

          // Scrollable Content Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: _buildGroupListCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeaderBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Back to Campaigns',
              ),
              const SizedBox(width: 14),
              Row(
                children: [
                  InkWell(
                    onTap: widget.onBack,
                    child: const Text(
                      'Campaigns',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('/', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                  ),
                  const Text(
                    'Audience Groups',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: Text(
                      '${_groups.length} Groups',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0052FF)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                height: 38,
                child: OutlinedButton.icon(
                  onPressed: _openGroupGrabberDialog,
                  icon: const Icon(Icons.sync_alt_rounded, size: 16),
                  label: const Text('Group Grabber', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: () => _openCreateGroupDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupListCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title & Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Group List',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: Text(
                            'Showing ${_groups.length} Groups',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0052FF)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Search through saved groups and manage their members and source types.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),

                // Search Input Field
                SizedBox(
                  width: 300,
                  height: 40,
                  child: TextField(
                    onChanged: (val) {
                      _searchQuery = val;
                      _loadGroups();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search groups by name or type...',
                      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                setState(() => _searchQuery = '');
                                _loadGroups();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0052FF), width: 1.5)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Standard Slate Table Header (Matches Dashboard View)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(width: 70, child: Text('SrNo#', style: _tableHeaderStyle)),
                Expanded(flex: 4, child: Text('Group Name', style: _tableHeaderStyle)),
                Expanded(flex: 3, child: Text('Type', style: _tableHeaderStyle)),
                Expanded(flex: 3, child: Text('Total Numbers', style: _tableHeaderStyle)),
                SizedBox(width: 120, child: Text('Action', style: _tableHeaderStyle)),
              ],
            ),
          ),

          // Table Rows
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(color: Color(0xFF0052FF)),
              ),
            )
          else if (_groups.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.groups_rounded, size: 28, color: Color(0xFF0052FF)),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No audience groups saved yet',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Click "Create Group" above or use Group Grabber to import contacts from your POS.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _openCreateGroupDialog(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create First Group'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0052FF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._groups.map((group) => _buildGroupRow(group)),

          // Bottom Pagination Bar
          _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildGroupRow(AudienceGroupModel group) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          // SrNo#
          SizedBox(
            width: 70,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '#${group.srNo}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          // Group Name
          Expanded(
            flex: 4,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0052FF),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        group.source,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Type
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  group.type,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0052FF)),
                ),
              ),
            ),
          ),

          // Total Numbers
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.contacts_rounded, size: 12, color: Color(0xFF16A34A)),
                    const SizedBox(width: 5),
                    Text(
                      '${group.count} Numbers',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Actions
          SizedBox(
            width: 120,
            child: Row(
              children: [
                // View numbers (Blue circle)
                _buildActionCircle(
                  icon: Icons.visibility_rounded,
                  color: const Color(0xFF0052FF),
                  bgColor: const Color(0xFFEFF6FF),
                  tooltip: 'View Numbers',
                  onTap: () => _openViewMembersDialog(group),
                ),
                const SizedBox(width: 8),

                // Edit group (Amber circle)
                _buildActionCircle(
                  icon: Icons.edit_rounded,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                  tooltip: 'Edit Group',
                  onTap: () => _openCreateGroupDialog(editGroup: group),
                ),
                const SizedBox(width: 8),

                // Delete group (Red circle)
                _buildActionCircle(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFDC2626),
                  bgColor: const Color(0xFFFEF2F2),
                  tooltip: 'Delete Group',
                  onTap: () => _deleteGroup(group),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCircle({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  Widget _buildPaginationBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('Items per page: ', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          DropdownButton<int>(
            value: _itemsPerPage,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 5, child: Text('5', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 20, child: Text('20', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _itemsPerPage = val);
            },
          ),
          const SizedBox(width: 20),
          Text(
            _groups.isNotEmpty ? '1 - ${_groups.length} of ${_groups.length}' : '0 - 0 of 0',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            icon: const Icon(Icons.chevron_left, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.chevron_right, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  static const TextStyle _tableHeaderStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: Color(0xFF64748B),
  );
}
