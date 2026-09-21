import 'package:flutter/material.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/staff_model.dart';
import '../../../core/services/staff_service.dart';
import 'create_staff_screen.dart';

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
  bool _isLoading = false;

  List<StaffModel> _staffList = [];
  StaffStatsModel _stats = const StaffStatsModel();

  final List<String> _roleOptions = [
    'All Roles',
    'Admin',
    'Manager',
    'Cashier',
    'Sales',
    'Inventory',
    'Support',
    'Chef',
    'Waiter',
  ];

  final List<String> _statusOptions = [
    'All Status',
    'Active',
    'Inactive',
  ];

  @override
  void initState() {
    super.initState();
    _applyLocalFilter();
    _loadStaffData();
  }

  @override
  void dispose() {
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
    setState(() => _currentPage = 1);
    _loadStaffData();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Staff Member', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        content: Text('Are you sure you want to remove "${staff.name}" (${staff.employeeId}) from staff management?'),
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

  void _showStaffFormDialog({StaffModel? existingStaff}) {
    if (existingStaff == null) {
      _openCreateStaffScreen();
      return;
    }
    final staff = existingStaff;
    final nameCtrl = TextEditingController(text: staff.name);
    final empIdCtrl = TextEditingController(text: staff.employeeId);
    final phoneCtrl = TextEditingController(text: staff.phone);
    final emailCtrl = TextEditingController(text: staff.email);
    final passwordCtrl = TextEditingController();
    String formRole = staff.role;
    String formStatus = staff.status;
    final Set<String> formPermissions = Set.from(staff.permissions);

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 580,
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Modal Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.badge_rounded, color: Color(0xFF2563EB), size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Staff Member',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Update details, role and permissions',
                                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 16),

                    // Scrollable Form Body
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Full Name
                              const Text('Full Name *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: nameCtrl,
                                decoration: _inputDecoration(hint: 'e.g. Amit Sharma', icon: Icons.person_outline_rounded),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter staff name' : null,
                              ),
                              const SizedBox(height: 16),

                              // Employee ID & Role Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Employee ID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: empIdCtrl,
                                          decoration: _inputDecoration(hint: 'EMP001', icon: Icons.tag_rounded),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Role *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          value: formRole,
                                          decoration: _inputDecoration(hint: 'Select Role', icon: Icons.work_outline_rounded),
                                          items: _roleOptions
                                              .where((r) => r != 'All Roles')
                                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                              .toList(),
                                          onChanged: (v) {
                                            if (v != null) setModalState(() => formRole = v);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Phone & Email Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: phoneCtrl,
                                          keyboardType: TextInputType.phone,
                                          decoration: _inputDecoration(hint: 'e.g. 9876543210', icon: Icons.phone_outlined),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Email Address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: emailCtrl,
                                          keyboardType: TextInputType.emailAddress,
                                          decoration: _inputDecoration(hint: 'staff@domain.com', icon: Icons.email_outlined),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Password & Status Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('New Password (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                                        const SizedBox(height: 6),
                                        TextFormField(
                                          controller: passwordCtrl,
                                          obscureText: true,
                                          decoration: _inputDecoration(hint: 'Leave blank to keep unchanged', icon: Icons.lock_outline_rounded),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          value: formStatus,
                                          decoration: _inputDecoration(hint: 'Status', icon: Icons.toggle_on_outlined),
                                          items: const [
                                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                                            DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                                          ],
                                          onChanged: (v) {
                                            if (v != null) setModalState(() => formStatus = v);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // Permissions Checklist
                              const Text('Module Permissions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _permissionChip('POS Billing', 'pos', formPermissions, setModalState),
                                  _permissionChip('Table Management', 'tables', formPermissions, setModalState),
                                  _permissionChip('Orders', 'orders', formPermissions, setModalState),
                                  _permissionChip('Menu & Items', 'menu', formPermissions, setModalState),
                                  _permissionChip('Inventory', 'inventory', formPermissions, setModalState),
                                  _permissionChip('Reports', 'reports', formPermissions, setModalState),
                                  _permissionChip('CRM Leads', 'crm', formPermissions, setModalState),
                                  _permissionChip('Loyalty', 'loyalty', formPermissions, setModalState),
                                  _permissionChip('Discounts', 'discounts', formPermissions, setModalState),
                                  _permissionChip('Settings', 'settings', formPermissions, setModalState),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFE2E8F0), height: 1),
                    const SizedBox(height: 16),

                    // Actions Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700)),
                          onPressed: () async {
                            if (formKey.currentState?.validate() != true) return;

                            final updatedStaff = staff.copyWith(
                              name: nameCtrl.text.trim(),
                              employeeId: empIdCtrl.text.trim(),
                              phone: phoneCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              role: formRole,
                              status: formStatus,
                              password: passwordCtrl.text.trim().isNotEmpty ? passwordCtrl.text.trim() : null,
                              permissions: formPermissions.toList(),
                              updatedAt: DateTime.now(),
                            );

                            Navigator.pop(ctx);
                            await _staffService.updateStaff(updatedStaff);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Staff member updated successfully'),
                                  backgroundColor: Color(0xFF16A34A),
                                ),
                              );
                              _loadStaffData();
                            }
                          },
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

  Widget _permissionChip(String label, String key, Set<String> perms, StateSetter setModalState) {
    final isSelected = perms.contains(key);
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF475569))),
      selected: isSelected,
      onSelected: (val) {
        setModalState(() {
          if (val) {
            perms.add(key);
          } else {
            perms.remove(key);
          }
        });
      },
      backgroundColor: const Color(0xFFF8FAFC),
      selectedColor: const Color(0xFFDBEAFE),
      checkmarkColor: const Color(0xFF1D4ED8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0)),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 19),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Title & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onOpenDrawer != null && isMobile) ...[
                    IconButton(
                      icon: const Icon(Icons.menu_rounded, color: Color(0xFF0F172A), size: 24),
                      onPressed: widget.onOpenDrawer,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Text(
                    'Staff Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage your team, roles and permissions',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
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
              horizontal: isMobile ? 14 : 20,
              vertical: isMobile ? 11 : 13,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(
            'Create Staff',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
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
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
        children: cards.map((c) => _buildMetricCard(c)).toList(),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _buildMetricCard(c),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildMetricCard(_SummaryCardItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon Container
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          // Count
          Text(
            item.count,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          // Label with optional green / red dot
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.isDotGreen) ...[
                Container(
                  width: 6.5,
                  height: 6.5,
                  decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
              ] else if (item.isDotRed) ...[
                Container(
                  width: 6.5,
                  height: 6.5,
                  decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 12.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: isMobile
          ? Column(
              children: [
                _buildSearchField(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildRoleDropdown()),
                    const SizedBox(width: 10),
                    Expanded(child: _buildStatusDropdown()),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 12),
                SizedBox(width: 170, child: _buildRoleDropdown()),
                const SizedBox(width: 12),
                SizedBox(width: 160, child: _buildStatusDropdown()),
              ],
            ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: 'Search by name, email or role...',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          items: _roleOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: _onRoleFilterChanged,
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const CircularProgressIndicator(color: Color(0xFF2563EB)),
      );
    }

    if (_staffList.isEmpty) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
              child: const Icon(Icons.group_off_rounded, color: Color(0xFF94A3B8), size: 36),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Staff Members Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your search query or role filter',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Table Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            ),
            child: const Row(
              children: [
                SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                SizedBox(width: 12),
                Expanded(flex: 3, child: Text('Staff Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
                SizedBox(width: 46, child: Text('Actions', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)))),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _staffList.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 1),
            itemBuilder: (context, index) {
              final staff = _staffList[index];
              final rowNumber = ((_currentPage - 1) * _pageSize) + index + 1;
              return _buildStaffRow(staff, rowNumber);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStaffRow(StaffModel staff, int rowNumber) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // # Index Column
          SizedBox(
            width: 32,
            child: Text(
              '$rowNumber',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 12),

          // Staff Member (Avatar + Name + EMP ID)
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _buildAvatar(staff),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        staff.employeeId.isNotEmpty ? staff.employeeId : (staff.phone.isNotEmpty ? staff.phone : 'Staff'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: staff.roleBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  staff.role,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: staff.roleTextColor,
                  ),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: staff.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: staff.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      staff.status,
                      style: TextStyle(
                        fontSize: 12,
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
            width: 46,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF94A3B8), size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
              onSelected: (action) {
                if (action == 'edit') {
                  _showStaffFormDialog(existingStaff: staff);
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
                      Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                      SizedBox(width: 10),
                      Text('Edit Staff Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        staff.isActive ? Icons.toggle_off_outlined : Icons.toggle_on_outlined,
                        size: 18,
                        color: staff.isActive ? const Color(0xFFEA580C) : const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        staff.isActive ? 'Mark as Inactive' : 'Mark as Active',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      SizedBox(width: 10),
                      Text('Delete Staff', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
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

  Widget _buildAvatar(StaffModel staff) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [staff.roleTextColor.withOpacity(0.85), staff.roleTextColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          staff.initials,
          style: const TextStyle(
            fontSize: 13,
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left text: Showing 1–8 of 12 staff members
        Text(
          'Showing $startNumber–$endNumber of $_totalCount staff members',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),

        // Right pagination controls
        Row(
          children: [
            // Previous button (<)
            InkWell(
              onTap: _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: _currentPage > 1 ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Numbered Page buttons
            for (int p = 1; p <= _totalPages; p++) ...[
              InkWell(
                onTap: () => _goToPage(p),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _currentPage == p ? const Color(0xFF2563EB) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _currentPage == p ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    '$p',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _currentPage == p ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Next button (>)
            InkWell(
              onTap: _currentPage < _totalPages ? () => _goToPage(_currentPage + 1) : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
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
