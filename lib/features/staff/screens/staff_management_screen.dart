import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/staff_model.dart';
import '../../../core/services/staff_service.dart';
import 'create_staff_screen.dart';
import 'staff_settings_screen.dart';
import '../widgets/staff_id_card_dialog.dart';

class StaffManagementScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onNavigateToDashboard;

  const StaffManagementScreen({
    super.key,
    this.onOpenDrawer,
    this.onNavigateToDashboard,
  });

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  final StaffService _staffService = StaffService();
  final DatabaseService _db = DatabaseService();

  final TextEditingController _searchController = TextEditingController();

  // State
  String _selectedRole = 'All Roles';
  String _selectedStatus = 'All Status';
  int _currentPage = 1;
  static const int _pageSize = 8;
  int _totalCount = 0;
  int _totalPages = 1;
  bool _isLoading = true;

  List<StaffModel> _staffList = [];
  StaffStatsModel _stats = const StaffStatsModel();

  List<String> get _roleOptions {
    final list = ['All Roles', ..._db.allStaffRoles];
    return list.toSet().toList();
  }

  final List<String> _statusOptions = [
    'All Status',
    'Active',
    'Inactive',
  ];

  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _db.addListener(_onDbChanged);
    _applyLocalFilter();
    _isLoading = _db.staffList.isEmpty;
    _loadStaffData();
  }

  void _onDbChanged() {
    if (!mounted) return;
    _applyLocalFilter();
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaffData() async {
    if (_staffList.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final result = await _staffService.fetchStaff(
        page: _currentPage,
        limit: _pageSize,
        role: _selectedRole,
        status: _selectedStatus,
        search: _searchController.text.trim(),
      );

      if (result != null && mounted) {
        setState(() {
          _staffList = result.staff;
          _totalCount = result.totalCount;
          _totalPages = result.totalPages;
          _stats = result.stats;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[StaffManagementScreen] Error loading staff: $e');
    }

    if (mounted) {
      _applyLocalFilter();
      setState(() => _isLoading = false);
    }
  }

  void _applyLocalFilter() {
    List<StaffModel> list = List.from(_db.staffList);

    if (_selectedRole != 'All Roles') {
      list = list.where((s) => s.role.toLowerCase() == _selectedRole.toLowerCase()).toList();
    }

    if (_selectedStatus != 'All Status') {
      list = list.where((s) => s.status.toLowerCase() == _selectedStatus.toLowerCase()).toList();
    }

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((s) {
        return s.name.toLowerCase().contains(query) ||
            s.employeeId.toLowerCase().contains(query) ||
            s.phone.toLowerCase().contains(query) ||
            s.email.toLowerCase().contains(query) ||
            s.role.toLowerCase().contains(query);
      }).toList();
    }

    final total = list.length;
    final totalP = (total / _pageSize).ceil() > 0 ? (total / _pageSize).ceil() : 1;
    if (_currentPage > totalP) _currentPage = 1;

    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, total);

    final paginated = (startIndex < total)
        ? list.sublist(startIndex, endIndex)
        : <StaffModel>[];

    int act = 0;
    int inact = 0;
    int adm = 0;
    for (final s in _db.staffList) {
      if (s.isActive) act++;
      if (!s.isActive) inact++;
      if (s.isAdmin) adm++;
    }

    setState(() {
      _staffList = paginated;
      _totalCount = total;
      _totalPages = totalP;
      _stats = StaffStatsModel(
        total: _db.staffList.length,
        active: act,
        inactive: inact,
        admins: adm,
      );
    });
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _currentPage = 1);
      _loadStaffData();
    });
  }

  void _onRoleFilterChanged(String? val) {
    if (val == null) return;
    setState(() {
      _selectedRole = val;
      _currentPage = 1;
    });
    _loadStaffData();
  }

  void _onStatusFilterChanged(String? val) {
    if (val == null) return;
    setState(() {
      _selectedStatus = val;
      _currentPage = 1;
    });
    _loadStaffData();
  }

  void _goToPage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() => _currentPage = page);
    _loadStaffData();
  }

  Future<void> _toggleStatus(StaffModel staff) async {
    final updated = await _staffService.toggleStatus(staff.id);
    if (updated != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${staff.name} is now ${updated.status}'),
          backgroundColor: updated.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          duration: const Duration(seconds: 2),
        ),
      );
      _loadStaffData();
    }
  }

  Future<void> _deleteStaff(StaffModel staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Staff Member', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        content: Text('Are you sure you want to remove "${staff.name}" (${staff.employeeId}) from staff management?', style: const TextStyle(color: Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _staffService.deleteStaff(staff.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${staff.name} removed successfully'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        _loadStaffData();
      }
    }
  }

  Future<void> _openCreateStaffScreen() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => CreateStaffScreen(
          onStaffCreated: _loadStaffData,
        ),
      ),
    );
    if (created == true) {
      _loadStaffData();
    }
  }

  Future<void> _openStaffSettingsScreen(StaffModel staff) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => StaffSettingsScreen(
          staff: staff,
          onStaffUpdated: _loadStaffData,
        ),
      ),
    );
    if (updated == true) {
      _loadStaffData();
    }
  }

  void _showStaffFormDialog({StaffModel? existingStaff}) {
    if (existingStaff == null) {
      _openCreateStaffScreen();
      return;
    }
    _openStaffSettingsScreen(existingStaff);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        canvasColor: Colors.white,
        cardColor: Colors.white,
        dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2563EB),
          surface: Colors.white,
          onSurface: Color(0xFF0F172A),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.white,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 700;
              return RefreshIndicator(
                onRefresh: _loadStaffData,
                color: const Color(0xFF2563EB),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 24,
                    vertical: isMobile ? 14 : 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Top Header Row
                      _buildHeader(isMobile),
                      const SizedBox(height: 18),

                      // 2. Summary Metric Cards (4 Cards)
                      _buildSummaryCards(isMobile),
                      const SizedBox(height: 20),

                      // 3. Search & Filter Bar
                      _buildSearchAndFilters(isMobile),
                      const SizedBox(height: 16),

                      // 4. Staff Table / Card List
                      _buildStaffTable(isMobile),
                      const SizedBox(height: 16),

                      // 5. Pagination Footer
                      _buildPaginationFooter(isMobile),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Title & Subtitle (Without the 3-line hamburger menu icon)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Staff Management',
                style: TextStyle(
                  fontSize: isMobile ? 16.5 : 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Manage your team, roles and permissions',
                style: TextStyle(
                  fontSize: isMobile ? 10.5 : 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        // "+ Create Staff" CTA Button
        ElevatedButton.icon(
          onPressed: _openCreateStaffScreen,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 16,
              vertical: isMobile ? 7 : 10,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: Icon(Icons.add_rounded, size: isMobile ? 15 : 17),
          label: Text(
            'Create Staff',
            style: TextStyle(
              fontSize: isMobile ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(bool isMobile) {
    final cards = [
      _SummaryCardItem(
        icon: Icons.people_alt_outlined,
        iconBg: const Color(0xFFEEF2FF),
        iconColor: const Color(0xFF4F46E5),
        count: '${_stats.total}',
        label: 'Total Staff',
      ),
      _SummaryCardItem(
        icon: Icons.person_outline_rounded,
        iconBg: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF10B981),
        count: '${_stats.active}',
        label: 'Active',
        isDotGreen: true,
      ),
      _SummaryCardItem(
        icon: Icons.person_off_outlined,
        iconBg: const Color(0xFFFEF2F2),
        iconColor: const Color(0xFFEF4444),
        count: '${_stats.inactive}',
        label: 'Inactive',
        isDotRed: true,
      ),
      _SummaryCardItem(
        icon: Icons.verified_user_outlined,
        iconBg: const Color(0xFFF3E8FF),
        iconColor: const Color(0xFF8B5CF6),
        count: '${_stats.admins}',
        label: 'Admins',
      ),
    ];

    if (isMobile) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.15,
        ),
        itemBuilder: (context, index) {
          return _buildMetricCard(cards[index], isMobile: true);
        },
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _buildMetricCard(c, isMobile: false),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMetricCard(_SummaryCardItem item, {bool isMobile = false}) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: const [
            BoxShadow(color: Color(0x04000000), blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: item.iconBg,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 15),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.count,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.isDotGreen) ...[
                        Container(
                          width: 4.5,
                          height: 4.5,
                          decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 3),
                      ] else if (item.isDotRed) ...[
                        Container(
                          width: 4.5,
                          height: 4.5,
                          decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 3),
                      ],
                      Flexible(
                        child: Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 17),
          ),
          const SizedBox(height: 8),
          Text(
            item.count,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.isDotGreen) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
              ] else if (item.isDotRed) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: isMobile
          ? Column(
              children: [
                _buildSearchField(isMobile: true),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _buildRoleDropdown(isMobile: true)),
                    const SizedBox(width: 6),
                    Expanded(child: _buildStatusDropdown(isMobile: true)),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildSearchField(isMobile: false)),
                const SizedBox(width: 8),
                SizedBox(width: 150, child: _buildRoleDropdown(isMobile: false)),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: _buildStatusDropdown(isMobile: false)),
              ],
            ),
    );
  }

  Widget _buildSearchField({bool isMobile = false}) {
    return Container(
      height: isMobile ? 35 : 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: TextStyle(fontSize: isMobile ? 11.5 : 12.5, color: const Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search by name, email or role...',
          hintStyle: TextStyle(color: const Color(0xFF94A3B8), fontSize: isMobile ? 11 : 12),
          prefixIcon: Icon(Icons.search_rounded, color: const Color(0xFF94A3B8), size: isMobile ? 15 : 17),
          prefixIconConstraints: BoxConstraints(minWidth: isMobile ? 30 : 36),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, size: isMobile ? 14 : 16, color: const Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: isMobile ? 7 : 9),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown({bool isMobile = false}) {
    return Container(
      height: isMobile ? 34 : 38,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(8),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: const Color(0xFF64748B), size: isMobile ? 16 : 18),
          style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
          items: _roleOptions
              .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(
                      r,
                      style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                  ))
              .toList(),
          onChanged: _onRoleFilterChanged,
        ),
      ),
    );
  }

  Widget _buildStatusDropdown({bool isMobile = false}) {
    return Container(
      height: isMobile ? 34 : 38,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          isExpanded: true,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(8),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: const Color(0xFF64748B), size: isMobile ? 16 : 18),
          style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
          items: _statusOptions
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s,
                      style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                  ))
              .toList(),
          onChanged: _onStatusFilterChanged,
        ),
      ),
    );
  }

  Widget _buildStaffTable(bool isMobile) {
    if (_isLoading) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    if (_staffList.isEmpty) {
      final hasActiveFilters = _selectedRole != 'All Roles' || _selectedStatus != 'All Status' || _searchController.text.trim().isNotEmpty;
      return Container(
        height: 260,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: const Icon(Icons.group_off_rounded, color: Color(0xFF94A3B8), size: 32),
            ),
            const SizedBox(height: 10),
            Text(
              hasActiveFilters ? 'No Matching Staff Members' : 'No Staff Members Found',
              style: TextStyle(fontSize: isMobile ? 14.5 : 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 3),
            Text(
              hasActiveFilters
                  ? 'Try clearing your search query or role filter'
                  : 'Add your first team member to start managing permissions',
              style: TextStyle(fontSize: isMobile ? 11.5 : 13, color: const Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (hasActiveFilters)
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _selectedRole = 'All Roles';
                  _selectedStatus = 'All Status';
                  _currentPage = 1;
                  _loadStaffData();
                },
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Reset Filters'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _openCreateStaffScreen,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Staff Member'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Table Column Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 8 : 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            ),
            child: Row(
              children: [
                SizedBox(width: isMobile ? 22 : 28, child: Text('#', style: TextStyle(fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                SizedBox(width: isMobile ? 6 : 10),
                Expanded(flex: 3, child: Text('Staff Member', style: TextStyle(fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('Role', style: TextStyle(fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('Status', style: TextStyle(fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
                SizedBox(width: isMobile ? 32 : 40, child: Text('Actions', textAlign: TextAlign.center, style: TextStyle(fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)))),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _staffList.length,
            separatorBuilder: (_, _) => const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
            itemBuilder: (context, index) {
              final staff = _staffList[index];
              final rowNumber = ((_currentPage - 1) * _pageSize) + index + 1;
              return _buildStaffRow(staff, rowNumber, isMobile: isMobile);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStaffRow(StaffModel staff, int rowNumber, {bool isMobile = false}) {
    return InkWell(
      onTap: () => _openStaffSettingsScreen(staff),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 7 : 9),
        child: Row(
          children: [
            // # Index Column
            SizedBox(
              width: isMobile ? 22 : 28,
              child: Text(
                '$rowNumber',
                style: TextStyle(fontSize: isMobile ? 10.5 : 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
              ),
            ),
            SizedBox(width: isMobile ? 6 : 10),

            // Staff Member (Avatar + Name + EMP ID)
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _buildAvatar(staff, isMobile: isMobile),
                  SizedBox(width: isMobile ? 7 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff.name,
                          style: TextStyle(
                            fontSize: isMobile ? 11.5 : 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          staff.employeeId.isNotEmpty ? staff.employeeId : (staff.phone.isNotEmpty ? staff.phone : 'Staff'),
                          style: TextStyle(
                            fontSize: isMobile ? 9.5 : 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Role Badge Column
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: isMobile ? 2 : 3),
                  decoration: BoxDecoration(
                    color: staff.roleBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    staff.role,
                    style: TextStyle(
                      fontSize: isMobile ? 9.5 : 11,
                      fontWeight: FontWeight.w700,
                      color: staff.roleTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),

            // Status Badge Column
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: isMobile ? 2 : 3),
                  decoration: BoxDecoration(
                    color: staff.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isMobile ? 4.5 : 5.5,
                        height: isMobile ? 4.5 : 5.5,
                        decoration: BoxDecoration(
                          color: staff.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: isMobile ? 3 : 4),
                      Text(
                        staff.status,
                        style: TextStyle(
                          fontSize: isMobile ? 9.5 : 11,
                          fontWeight: FontWeight.w700,
                          color: staff.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions 3-dots Menu
            SizedBox(
              width: isMobile ? 32 : 40,
              child: PopupMenuButton<String>(
                color: Colors.white,
                surfaceTintColor: Colors.white,
                icon: Icon(Icons.more_vert_rounded, color: const Color(0xFF94A3B8), size: isMobile ? 16 : 18),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
                elevation: 4,
                onSelected: (action) {
                  if (action == 'edit') {
                    _showStaffFormDialog(existingStaff: staff);
                  } else if (action == 'view_id') {
                    StaffIdCardDialog.show(context, staff);
                  } else if (action == 'toggle') {
                    _toggleStatus(staff);
                  } else if (action == 'delete') {
                    _deleteStaff(staff);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                        SizedBox(width: 8),
                        Text('Edit Staff Details', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'view_id',
                    child: Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 15, color: Color(0xFF7C3AED)),
                        SizedBox(width: 8),
                        Text('View ID Card', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          staff.isActive ? Icons.toggle_off_outlined : Icons.toggle_on_outlined,
                          size: 15,
                          color: staff.isActive ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                        ),
                        SizedBox(width: 8),
                        Text(
                          staff.isActive ? 'Mark as Inactive' : 'Mark as Active',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: staff.isActive ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                        SizedBox(width: 8),
                        Text('Delete Staff', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(StaffModel staff, {bool isMobile = false}) {
    final double size = isMobile ? 26 : 32;
    if (staff.avatarUrl.isNotEmpty) {
      if (staff.avatarUrl.startsWith('http://') || staff.avatarUrl.startsWith('https://')) {
        return SizedBox(
          width: size,
          height: size,
          child: ClipOval(
            child: Image.network(
              staff.avatarUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(staff, size: size),
            ),
          ),
        );
      } else if (File(staff.avatarUrl).existsSync()) {
        return SizedBox(
          width: size,
          height: size,
          child: ClipOval(
            child: Image.file(
              File(staff.avatarUrl),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(staff, size: size),
            ),
          ),
        );
      }
    }
    return _buildAvatarFallback(staff, size: size);
  }

  Widget _buildAvatarFallback(StaffModel staff, {double size = 32}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [staff.roleTextColor.withValues(alpha: 0.85), staff.roleTextColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          staff.initials,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(bool isMobile) {
    final startNumber = _totalCount == 0 ? 0 : ((_currentPage - 1) * _pageSize) + 1;
    final endNumber = (_currentPage * _pageSize).clamp(0, _totalCount);
    final double btnSize = isMobile ? 26 : 30;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left text: Showing 1–8 of 12 staff
        Flexible(
          child: Text(
            'Showing $startNumber–$endNumber of $_totalCount staff',
            style: TextStyle(
              fontSize: isMobile ? 10.5 : 11.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Right pagination controls
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Previous button (<)
            InkWell(
              onTap: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: isMobile ? 15 : 18,
                  color: _currentPage > 1 ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Numbered Page buttons
            for (int p = 1; p <= _totalPages; p++) ...[
              InkWell(
                onTap: () => _goToPage(p),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: btnSize,
                  height: btnSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _currentPage == p ? const Color(0xFF2563EB) : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _currentPage == p ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    '$p',
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11.5,
                      fontWeight: FontWeight.w700,
                      color: _currentPage == p ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],

            // Next button (>)
            InkWell(
              onTap: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: btnSize,
                height: btnSize,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: isMobile ? 15 : 18,
                  color: _currentPage < _totalPages ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCardItem {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String count;
  final String label;
  final bool isDotGreen;
  final bool isDotRed;

  _SummaryCardItem({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.count,
    required this.label,
    this.isDotGreen = false,
    this.isDotRed = false,
  });
}
