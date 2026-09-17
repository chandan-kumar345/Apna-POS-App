import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/crm_model.dart';
import '../../../core/services/crm_service.dart';

class CrmLeadsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onNavigateToDashboard;

  const CrmLeadsScreen({
    super.key,
    this.onOpenDrawer,
    this.onNavigateToDashboard,
  });

  @override
  State<CrmLeadsScreen> createState() => _CrmLeadsScreenState();
}

class _CrmLeadsScreenState extends State<CrmLeadsScreen> {
  final CrmService _crmService = CrmService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteInputController = TextEditingController();

  // State Variables
  String _selectedStageTab = 'All';
  String _selectedSourceFilter = 'All Sources';
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime(2026, 8, 1),
    end: DateTime(2026, 8, 31),
  );

  // Pagination
  int _currentPage = 1;
  int _pageSize = 8;
  int _totalCount = 0;
  int _totalPages = 1;
  bool _isLoading = false;

  // Detail Sub-tab
  String _activeDetailTab = 'Overview';

  // Leads
  List<CrmLeadModel> _allLeads = [];
  List<CrmLeadModel> _filteredLeads = [];
  CrmLeadModel? _selectedLead;

  // Dynamic Statistics
  CrmStatsModel _stats = CrmStatsModel(
    total: 8,
    leads: 3,
    prospects: 2,
    deals: 1,
    wins: 1,
    lost: 1,
  );

  final List<String> _stageTabs = [
    'All',
    'Leads',
    'Prospects',
    'Deals',
    'Won',
    'Lost',
  ];

  final List<String> _allSources = [
    'All Sources',
    'Dine In',
    'POS',
    'Online',
    'WhatsApp',
    'Social Media',
    'Referral',
    'Website',
  ];

  final List<String> _allStages = [
    'New Lead',
    'Prospect',
    'Deal',
    'Won',
    'Lost',
  ];

  @override
  void initState() {
    super.initState();
    _initDefaultLeads();
    _loadLeadsFromBackend();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteInputController.dispose();
    super.dispose();
  }

  /// Initial demo leads matching the exact 8 rows in the reference image
  void _initDefaultLeads() {
    _allLeads = [
      CrmLeadModel(
        id: '1',
        name: 'Jagat',
        phone: '7838710511',
        email: 'jagat@example.com',
        address: 'Noida, Uttar Pradesh',
        source: 'Dine In',
        stage: 'New Lead',
        status: 'New Lead',
        customerType: 'New Customer',
        tags: const ['New Customer', 'Dine In'],
        totalOrders: 3,
        totalSpent: 1240.0,
        createdAt: DateTime(2026, 8, 31, 19, 11),
        lastVisit: DateTime(2026, 8, 31, 19, 11),
      ),
      CrmLeadModel(
        id: '2',
        name: 'Chandan',
        phone: '9709593705',
        email: 'chandan@example.com',
        address: 'Patna, Bihar',
        source: 'Dine In',
        stage: 'New Lead',
        status: 'New Lead',
        customerType: 'Regular Customer',
        tags: const ['Regular Customer', 'Dine In'],
        totalOrders: 12,
        totalSpent: 4850.0,
        createdAt: DateTime(2026, 8, 31, 9, 40),
        lastVisit: DateTime(2026, 8, 31, 9, 40),
      ),
      CrmLeadModel(
        id: '3',
        name: 'Rohit Sharma',
        phone: '9876543210',
        email: 'rohit@example.com',
        address: 'Mumbai, Maharashtra',
        source: 'POS',
        stage: 'Prospect',
        status: 'Prospect',
        customerType: 'Walk-in',
        tags: const ['Walk-in', 'POS'],
        totalOrders: 1,
        totalSpent: 620.0,
        createdAt: DateTime(2026, 8, 30, 18, 20),
        lastVisit: DateTime(2026, 8, 30, 18, 20),
      ),
      CrmLeadModel(
        id: '4',
        name: 'Priya Singh',
        phone: '9543216780',
        email: 'priya@example.com',
        address: 'Delhi, India',
        source: 'Online',
        stage: 'Deal',
        status: 'Deal',
        customerType: 'Online Order',
        tags: const ['Online Order', 'Online'],
        totalOrders: 5,
        totalSpent: 2310.0,
        createdAt: DateTime(2026, 8, 30, 11, 15),
        lastVisit: DateTime(2026, 8, 30, 11, 15),
      ),
      CrmLeadModel(
        id: '5',
        name: 'Amit Verma',
        phone: '9956784321',
        email: 'amit@example.com',
        address: 'Lucknow, Uttar Pradesh',
        source: 'WhatsApp',
        stage: 'Won',
        status: 'Won',
        customerType: 'Campaign',
        tags: const ['Campaign', 'WhatsApp'],
        totalOrders: 8,
        totalSpent: 3950.0,
        createdAt: DateTime(2026, 8, 29, 16, 45),
        lastVisit: DateTime(2026, 8, 29, 16, 45),
      ),
      CrmLeadModel(
        id: '6',
        name: 'Sneha Kapoor',
        phone: '9876501234',
        email: 'sneha@example.com',
        address: 'Bengaluru, Karnataka',
        source: 'Social Media',
        stage: 'Prospect',
        status: 'Prospect',
        customerType: 'Instagram',
        tags: const ['Instagram', 'Social Media'],
        totalOrders: 2,
        totalSpent: 990.0,
        createdAt: DateTime(2026, 8, 29, 13, 20),
        lastVisit: DateTime(2026, 8, 29, 13, 20),
      ),
      CrmLeadModel(
        id: '7',
        name: 'Vikas Jain',
        phone: '9965432109',
        email: 'vikas@example.com',
        address: 'Jaipur, Rajasthan',
        source: 'Referral',
        stage: 'Lost',
        status: 'Lost',
        customerType: 'Referral',
        tags: const ['Referral'],
        totalOrders: 0,
        totalSpent: 0.0,
        createdAt: DateTime(2026, 8, 28, 10, 10),
        lastVisit: DateTime(2026, 8, 28, 10, 10),
      ),
      CrmLeadModel(
        id: '8',
        name: 'Neha Gupta',
        phone: '9812345678',
        email: 'neha@example.com',
        address: 'Gurgaon, Haryana',
        source: 'Website',
        stage: 'New Lead',
        status: 'New Lead',
        customerType: 'Website',
        tags: const ['Website'],
        totalOrders: 4,
        totalSpent: 1870.0,
        createdAt: DateTime(2026, 8, 28, 9, 30),
        lastVisit: DateTime(2026, 8, 28, 9, 30),
      ),
    ];

    _totalCount = _allLeads.length;
    _selectedLead = _allLeads.first;
    _filteredLeads = List.from(_allLeads);
  }

  /// Load leads dynamically from backend API with fallback
  Future<void> _loadLeadsFromBackend() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stageParam = _selectedStageTab == 'All' ? null : _selectedStageTab;
      final searchParam = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();
      final sourceParam = _selectedSourceFilter == 'All Sources' ? null : _selectedSourceFilter;

      final result = await _crmService.fetchLeads(
        page: _currentPage,
        limit: _pageSize,
        stage: stageParam,
        search: searchParam,
        source: sourceParam,
      );

      if (mounted) {
        if (result != null && result.leads.isNotEmpty) {
          setState(() {
            _allLeads = result.leads;
            _filteredLeads = result.leads;
            _totalCount = result.totalCount;
            _totalPages = result.totalPages;
            _stats = result.stats;

            if (_selectedLead == null || !_filteredLeads.any((l) => l.id == _selectedLead!.id)) {
              _selectedLead = _filteredLeads.isNotEmpty ? _filteredLeads.first : null;
            } else {
              _selectedLead = _filteredLeads.firstWhere((l) => l.id == _selectedLead!.id);
            }
          });
        } else if (result != null && result.leads.isEmpty) {
          setState(() {
            _allLeads = [];
            _filteredLeads = [];
            _totalCount = result.totalCount;
            _totalPages = result.totalPages;
            _stats = result.stats;
            _selectedLead = null;
          });
        } else {
          _applyLocalFilter();
        }
      }
    } catch (_) {
      if (mounted) {
        _applyLocalFilter();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyLocalFilter() {
    List<CrmLeadModel> list = List.from(_allLeads);

    // 1. Stage Tab Filter
    if (_selectedStageTab != 'All') {
      final target = _selectedStageTab.toLowerCase();
      list = list.where((lead) {
        final st = lead.stage.toLowerCase();
        if (target == 'leads') return st.contains('lead');
        if (target == 'prospects') return st.contains('prospect');
        if (target == 'deals') return st.contains('deal');
        if (target == 'won') return st.contains('win') || st.contains('won');
        if (target == 'lost') return st.contains('lost');
        return st == target;
      }).toList();
    }

    // 2. Source Filter
    if (_selectedSourceFilter != 'All Sources') {
      list = list.where((lead) => lead.source.toLowerCase() == _selectedSourceFilter.toLowerCase()).toList();
    }

    // 3. Search Filter
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((lead) {
        return lead.name.toLowerCase().contains(query) ||
            lead.phone.toLowerCase().contains(query) ||
            lead.email.toLowerCase().contains(query) ||
            lead.customerType.toLowerCase().contains(query);
      }).toList();
    }

    setState(() {
      _filteredLeads = list;
      _totalCount = _filteredLeads.length;
      if (_selectedLead == null || !_filteredLeads.any((l) => l.id == _selectedLead!.id)) {
        if (_filteredLeads.isNotEmpty) {
          _selectedLead = _filteredLeads.first;
        }
      }
      _recalculateStats();
    });
  }

  void _recalculateStats() {
    int total = _allLeads.length;
    int leads = 0;
    int prospects = 0;
    int deals = 0;
    int wins = 0;
    int lost = 0;

    for (final l in _allLeads) {
      final st = l.stage.toLowerCase();
      if (st.contains('lead')) {
        leads++;
      } else if (st.contains('prospect')) {
        prospects++;
      } else if (st.contains('deal')) {
        deals++;
      } else if (st.contains('win') || st.contains('won')) {
        wins++;
      } else if (st.contains('lost')) {
        lost++;
      } else {
        leads++;
      }
    }

    _stats = CrmStatsModel(
      total: total,
      leads: leads,
      prospects: prospects,
      deals: deals,
      wins: wins,
      lost: lost,
      trends: _stats.trends,
    );
  }

  // --- Dynamic Actions ---

  void _onSelectLead(CrmLeadModel lead) {
    setState(() {
      _selectedLead = lead;
    });
  }

  Future<void> _updateSelectedLeadStage(String newStage) async {
    if (_selectedLead == null) return;
    final updated = _selectedLead!.copyWith(stage: newStage, status: newStage);

    setState(() {
      final idx = _allLeads.indexWhere((l) => l.id == _selectedLead!.id);
      if (idx != -1) {
        _allLeads[idx] = updated;
      }
      _selectedLead = updated;
      final fIdx = _filteredLeads.indexWhere((l) => l.id == updated.id);
      if (fIdx != -1) {
        _filteredLeads[fIdx] = updated;
      }
      _recalculateStats();
    });

    _showSnackBar('Stage updated to "$newStage"');
    try {
      await _crmService.updateStage(updated.id, newStage);
      _loadLeadsFromBackend();
    } catch (_) {}
  }

  Future<void> _scheduleFollowup(CrmLeadModel lead) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final noteCtrl = TextEditingController(text: lead.followupNotes);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Schedule Follow-up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${DateFormat('dd MMM yyyy').format(pickedDate)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                labelText: 'Follow-up Reason / Notes',
                hintText: 'e.g. Call to confirm catering order',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final updated = lead.copyWith(
        followupDate: pickedDate,
        followupNotes: noteCtrl.text.trim(),
        followupStatus: 'pending',
      );

      setState(() {
        final idx = _allLeads.indexWhere((l) => l.id == lead.id);
        if (idx != -1) _allLeads[idx] = updated;
        if (_selectedLead?.id == lead.id) _selectedLead = updated;
      });

      _showSnackBar('Follow-up scheduled for ${DateFormat('dd MMM yyyy').format(pickedDate)}');
      try {
        await _crmService.setFollowup(
          lead.id,
          followupDate: pickedDate,
          followupNotes: noteCtrl.text.trim(),
          followupStatus: 'pending',
        );
      } catch (_) {}
    }
  }

  Future<void> _saveNoteForSelectedLead() async {
    if (_selectedLead == null) return;
    final noteText = _noteInputController.text.trim();
    if (noteText.isEmpty) {
      _showSnackBar('Please write a note before saving', isError: true);
      return;
    }

    final newNotes = _selectedLead!.notes.isNotEmpty
        ? '${_selectedLead!.notes}\n• $noteText'
        : noteText;

    final updatedNotesList = List<dynamic>.from(_selectedLead!.notesList)
      ..add({'note': noteText, 'createdAt': DateTime.now().toIso8601String()});

    final updated = _selectedLead!.copyWith(
      notes: newNotes,
      notesList: updatedNotesList,
    );

    setState(() {
      final idx = _allLeads.indexWhere((l) => l.id == _selectedLead!.id);
      if (idx != -1) {
        _allLeads[idx] = updated;
      }
      _selectedLead = updated;
      _noteInputController.clear();
    });

    _showSnackBar('Note saved successfully');
    try {
      await _crmService.addNote(updated.id, noteText);
    } catch (_) {}
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      _showSnackBar('Invalid phone number', isError: true);
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Could not open phone dialer for $phone');
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    String cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      _showSnackBar('Phone number is empty or invalid', isError: true);
      return;
    }
    if (cleanDigits.length == 10) {
      cleanDigits = '91$cleanDigits';
    } else if (cleanDigits.length == 11 && cleanDigits.startsWith('0')) {
      cleanDigits = '91${cleanDigits.substring(1)}';
    }

    final nativeWhatsappUri = Uri.parse('whatsapp://send?phone=$cleanDigits');
    final webWhatsappUri = Uri.parse('https://wa.me/$cleanDigits');

    try {
      if (await canLaunchUrl(nativeWhatsappUri)) {
        await launchUrl(nativeWhatsappUri, mode: LaunchMode.externalNonBrowserApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(webWhatsappUri)) {
        await launchUrl(webWhatsappUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    _showSnackBar('Could not open WhatsApp for $phone', isError: true);
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('$label copied to clipboard');
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- Date Range Picker Dialog ---
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime(2028, 12, 31),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _showSnackBar(
        'Filtered range: ${DateFormat('dd MMM yyyy').format(picked.start)} - ${DateFormat('dd MMM yyyy').format(picked.end)}',
      );
    }
  }

  // --- UI Colors & Badge Helpers ---
  Color _getSourceBgColor(String source) {
    switch (source.toLowerCase()) {
      case 'dine in':
      case 'pos':
        return const Color(0xFFE0F2FE); // light blue
      case 'online':
      case 'social media':
        return const Color(0xFFFCE7F3); // light pink
      case 'whatsapp':
        return const Color(0xFFDCFCE7); // light green
      case 'referral':
        return const Color(0xFFEDE9FE); // light purple
      case 'website':
        return const Color(0xFFFEF3C7); // warm yellow
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getSourceTextColor(String source) {
    switch (source.toLowerCase()) {
      case 'dine in':
      case 'pos':
        return const Color(0xFF0284C7); // blue
      case 'online':
        return const Color(0xFFDB2777); // pink/rose
      case 'social media':
        return const Color(0xFFE11D48); // rose
      case 'whatsapp':
        return const Color(0xFF16A34A); // green
      case 'referral':
        return const Color(0xFF7C3AED); // purple
      case 'website':
        return const Color(0xFFB45309); // amber
      default:
        return const Color(0xFF475569);
    }
  }

  Color _getStageBgColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'new lead':
        return const Color(0xFFDCFCE7); // light green
      case 'prospect':
        return const Color(0xFFF3E8FF); // light purple
      case 'deal':
        return const Color(0xFFFEF3C7); // soft amber
      case 'won':
        return const Color(0xFFDCFCE7); // emerald
      case 'lost':
        return const Color(0xFFFEE2E2); // light red
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStageTextColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'new lead':
        return const Color(0xFF16A34A);
      case 'prospect':
        return const Color(0xFF9333EA);
      case 'deal':
        return const Color(0xFFD97706);
      case 'won':
        return const Color(0xFF16A34A);
      case 'lost':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF475569);
    }
  }

  Color _getAvatarColor(String name) {
    final n = name.trim().toUpperCase();
    if (n.startsWith('J') || n.startsWith('C')) return const Color(0xFF0B192C);
    if (n.startsWith('R') || n.startsWith('P') || n.startsWith('A') || n.startsWith('S')) {
      return const Color(0xFF1D4ED8);
    }
    if (n.startsWith('V')) return const Color(0xFF0F172A);
    if (n.startsWith('N')) return const Color(0xFF854D0E);
    return const Color(0xFF1E293B);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 650;
            final isWide = constraints.maxWidth >= 980;

            return RefreshIndicator(
              onRefresh: _loadLeadsFromBackend,
              color: const Color(0xFF0B192C),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 20,
                  vertical: isMobile ? 12 : 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Header (Wrapped for Mobile)
                    _buildHeaderRow(isMobile),

                    SizedBox(height: isMobile ? 12 : 16),

                    // 2. 5 Metric Cards with Sparklines
                    _buildMetricCardsRow(isWide, isMobile),

                    SizedBox(height: isMobile ? 14 : 18),

                    // 3. Stage Tabs & Wrapped Filters
                    _buildStageTabsAndFiltersRow(isWide, isMobile),

                    SizedBox(height: isMobile ? 14 : 16),

                    // 4. Main Two-Column or Stacked Content
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Table (Flex 62)
                          Expanded(
                            flex: 62,
                            child: _buildTableCard(isMobile: false),
                          ),
                          const SizedBox(width: 16),
                          // Right Selected Lead Card (Flex 38)
                          Expanded(
                            flex: 38,
                            child: _buildCustomerDetailCard(isMobile: false),
                          ),
                        ],
                      )
                    else ...[
                      // Mobile & Tablet: Stacked Layout
                      _buildTableCard(isMobile: isMobile),
                      const SizedBox(height: 16),
                      _buildCustomerDetailCard(isMobile: isMobile),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ==========================================================================
  // 1. HEADER ROW: CRM, Subtitle, Import, + Add New Lead (Wrapped for Mobile)
  // ==========================================================================
  Widget _buildHeaderRow(bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Optional Back button if callback provided
        if (widget.onNavigateToDashboard != null) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 20, color: Color(0xFF0F172A)),
            onPressed: widget.onNavigateToDashboard,
            tooltip: 'Back to Dashboard',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
        ],

        // Optional Drawer toggle button on mobile
        if (widget.onOpenDrawer != null && isMobile) ...[
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 22, color: Color(0xFF0F172A)),
            onPressed: widget.onOpenDrawer,
            tooltip: 'Open Menu',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
        ],

        // Title & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CRM',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Manage customers, leads & relationships',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12.5,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Action Buttons: Import, + Add New Lead (Wrapped)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Import Button
            InkWell(
              onTap: _showImportModal,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 14,
                  vertical: isMobile ? 7 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.file_upload_outlined, size: 14, color: Color(0xFF0F172A)),
                    const SizedBox(width: 4),
                    Text(
                      'Import',
                      style: TextStyle(
                        fontSize: isMobile ? 11.5 : 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // + Add New Lead Button
            InkWell(
              onTap: () => _showAddEditLeadModal(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 7.5 : 8.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B192C),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 15, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Add Lead',
                      style: TextStyle(
                        fontSize: isMobile ? 11.5 : 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

  // ==========================================================================
  // 2. 5 METRIC CARDS ROW WITH SPARKLINES (Compact for Mobile)
  // ==========================================================================
  Widget _buildMetricCardsRow(bool isWide, bool isMobile) {
    final cards = [
      _MetricCardData(
        title: 'Total Contacts',
        value: '${_stats.total}',
        trend: _stats.trends.total,
        iconBgColor: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF2563EB),
        iconWidget: const Icon(Icons.people_alt_rounded, size: 17, color: Color(0xFF2563EB)),
        waveColor: const Color(0xFF3B82F6),
      ),
      _MetricCardData(
        title: 'Leads',
        value: '${_stats.leads}',
        trend: _stats.trends.leads,
        iconBgColor: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
        iconWidget: const CrownIcon(size: 17, color: Color(0xFFD97706)),
        waveColor: const Color(0xFFF59E0B),
      ),
      _MetricCardData(
        title: 'Prospects',
        value: '${_stats.prospects}',
        trend: _stats.trends.prospects,
        iconBgColor: const Color(0xFFF3E8FF),
        iconColor: const Color(0xFF9333EA),
        iconWidget: const Icon(Icons.handshake_rounded, size: 17, color: Color(0xFF9333EA)),
        waveColor: const Color(0xFFA855F7),
      ),
      _MetricCardData(
        title: 'Deals',
        value: '${_stats.deals}',
        trend: _stats.trends.deals,
        iconBgColor: const Color(0xFFDCFCE7),
        iconColor: const Color(0xFF16A34A),
        iconWidget: const Icon(Icons.shopping_bag_rounded, size: 17, color: Color(0xFF16A34A)),
        waveColor: const Color(0xFF22C55E),
      ),
      _MetricCardData(
        title: 'Won Customers',
        value: '${_stats.wins}',
        trend: _stats.trends.wins,
        iconBgColor: const Color(0xFFFFEDD5),
        iconColor: const Color(0xFFEA580C),
        iconWidget: const Icon(Icons.emoji_events_rounded, size: 17, color: Color(0xFFEA580C)),
        waveColor: const Color(0xFFF97316),
      ),
    ];

    if (isWide) {
      return Row(
        children: cards
            .map(
              (card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildSingleMetricCard(card, isMobile: false),
                ),
              ),
            )
            .toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: cards
            .map(
              (card) => Container(
                width: isMobile ? 175 : 195,
                margin: const EdgeInsets.only(right: 10),
                child: _buildSingleMetricCard(card, isMobile: isMobile),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSingleMetricCard(_MetricCardData data, {required bool isMobile}) {
    return Container(
      height: isMobile ? 80 : 88,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Sparkline Wave
          Positioned(
            right: 0,
            bottom: 0,
            width: isMobile ? 80 : 90,
            height: isMobile ? 42 : 48,
            child: CustomPaint(
              painter: SparklineWavePainter(color: data.waveColor),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 8 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon circle
                Container(
                  width: isMobile ? 36 : 40,
                  height: isMobile ? 36 : 40,
                  decoration: BoxDecoration(
                    color: data.iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: data.iconWidget,
                ),

                const SizedBox(width: 9),

                // Texts: Title, Big Number, Trend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        data.title,
                        style: TextStyle(
                          fontSize: isMobile ? 10.5 : 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        data.value,
                        style: TextStyle(
                          fontSize: isMobile ? 17 : 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          const Icon(Icons.north_east_rounded, size: 10, color: Color(0xFF16A34A)),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              data.trend,
                              style: TextStyle(
                                fontSize: isMobile ? 9.5 : 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF16A34A),
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
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 3. STAGE TABS & WRAPPED FILTERS ROW
  // ==========================================================================
  Widget _buildStageTabsAndFiltersRow(bool isWide, bool isMobile) {
    if (isWide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Stage Tabs on Left
          Expanded(
            child: _buildStagePillsRow(isMobile: false),
          ),

          const SizedBox(width: 12),

          // Filters on Right
          _buildFilterControlsRow(isMobile: false),
        ],
      );
    }

    // Mobile & Tablet: Stack tabs and wrapped filters
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stage Tabs (Horizontal scroll on mobile)
        _buildStagePillsRow(isMobile: isMobile),

        const SizedBox(height: 10),

        // Wrapped Filter Dropdowns
        _buildFilterControlsRow(isMobile: isMobile),
      ],
    );
  }

  Widget _buildStagePillsRow({required bool isMobile}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _stageTabs.map((tab) {
          final isSelected = _selectedStageTab == tab;
          int count = 0;
          switch (tab) {
            case 'All':
              count = _stats.total;
              break;
            case 'Leads':
              count = _stats.leads;
              break;
            case 'Prospects':
              count = _stats.prospects;
              break;
            case 'Deals':
              count = _stats.deals;
              break;
            case 'Won':
              count = _stats.wins;
              break;
            case 'Lost':
              count = _stats.lost;
              break;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedStageTab = tab;
                  _currentPage = 1;
                });
                _loadLeadsFromBackend();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 12,
                  vertical: isMobile ? 6 : 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0B192C) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0B192C) : const Color(0xFFCBD5E1),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$tab ($count)',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterControlsRow({required bool isMobile}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Sources Dropdown
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSourceFilter,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF475569)),
              style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
              items: _allSources.map((source) {
                return DropdownMenuItem<String>(
                  value: source,
                  child: Text(source),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedSourceFilter = val;
                    _currentPage = 1;
                  });
                  _loadLeadsFromBackend();
                }
              },
            ),
          ),
        ),

        // Date Range Picker
        InkWell(
          onTap: _pickDateRange,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF475569)),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('dd MMM').format(_selectedDateRange.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange.end)}',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF475569)),
              ],
            ),
          ),
        ),

        // Reset Filter Action Button
        InkWell(
          onTap: () {
            _searchController.clear();
            setState(() {
              _selectedStageTab = 'All';
              _selectedSourceFilter = 'All Sources';
              _currentPage = 1;
            });
            _loadLeadsFromBackend();
            _showSnackBar('Filters reset');
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF475569)),
                const SizedBox(width: 4),
                Text(
                  'Reset',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // 4. LEFT SECTION: TABLE CARD (Search, Mobile List / Desktop Table, Pagination)
  // ==========================================================================
  Widget _buildTableCard({required bool isMobile}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Search Bar inside card
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 8 : 12,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: isMobile ? 16 : 18, color: const Color(0xFF94A3B8)),
                SizedBox(width: isMobile ? 8 : 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _applyLocalFilter(),
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone or email...',
                      hintStyle: TextStyle(
                        fontSize: isMobile ? 11.5 : 12.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      suffixIcon: _searchController.text.isNotEmpty
                          ? InkWell(
                              onTap: () {
                                _searchController.clear();
                                _applyLocalFilter();
                              },
                              child: Icon(Icons.clear_rounded, size: isMobile ? 14 : 16, color: const Color(0xFF94A3B8)),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content: Loading State, Empty State, or Data (Mobile vs Desktop Table)
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF0B192C),
                ),
              ),
            )
          else if (_filteredLeads.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFFCBD5E1)),
                    const SizedBox(height: 8),
                    Text(
                      'No matching customers found',
                      style: TextStyle(
                        fontSize: isMobile ? 12.5 : 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (isMobile)
            _buildMobileLeadsList()
          else
            _buildDesktopTable(),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Table Footer / Pagination Bar (Wrapped & Responsive)
          _buildPaginationBar(isMobile: isMobile),
        ],
      ),
    );
  }

  // --- Mobile Leads List View ---
  Widget _buildMobileLeadsList() {
    final leadsToShow = _filteredLeads.take(_pageSize).toList();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: leadsToShow.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        final lead = leadsToShow[index];
        final isSelected = _selectedLead?.id == lead.id;
        return _buildMobileLeadCardItem(lead, isSelected);
      },
    );
  }

  // --- Mobile Lead Card Item ---
  Widget _buildMobileLeadCardItem(CrmLeadModel lead, bool isSelected) {
    final avatarColor = _getAvatarColor(lead.name);
    final initial = lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'G';
    final interactionDate = DateFormat('dd MMM').format(lead.lastVisit ?? lead.createdAt);

    return InkWell(
      onTap: () => _onSelectLead(lead),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F5F9) : Colors.white,
          border: isSelected
              ? const Border(left: BorderSide(color: Color(0xFF2563EB), width: 3.5))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name + Stage Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.name,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        lead.customerType,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: _getStageBgColor(lead.stage),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    lead.stage,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _getStageTextColor(lead.stage),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Middle Wrapped Row: Phone, Source, Last Visit
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Phone
                InkWell(
                  onTap: () => _makePhoneCall(lead.phone),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_rounded, size: 11, color: Color(0xFF2563EB)),
                      const SizedBox(width: 3),
                      Text(
                        lead.phone,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),

                // Source Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getSourceBgColor(lead.source),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    lead.source,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: _getSourceTextColor(lead.source),
                    ),
                  ),
                ),

                // Last Interaction
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text(
                      interactionDate,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Bottom Actions: WhatsApp, Call, Follow-up, More
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // WhatsApp
                InkWell(
                  onTap: () => _openWhatsApp(lead.phone),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const WhatsAppBubbleIcon(size: 14, color: Color(0xFF16A34A)),
                  ),
                ),

                const SizedBox(width: 8),

                // Call
                InkWell(
                  onTap: () => _makePhoneCall(lead.phone),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_rounded, size: 13, color: Color(0xFF2563EB)),
                  ),
                ),

                const SizedBox(width: 8),

                // Followup
                InkWell(
                  onTap: () => _scheduleFollowup(lead),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.event_rounded, size: 13, color: Color(0xFFD97706)),
                  ),
                ),

                const SizedBox(width: 8),

                // More Menu
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'details') {
                      _onSelectLead(lead);
                    } else if (val == 'edit') {
                      _showAddEditLeadModal(context, existingLead: lead);
                    } else if (val == 'delete') {
                      _confirmDeleteLead(lead);
                    } else if (val == 'share') {
                      SharePlus.instance.share(
                        ShareParams(
                          text: 'Customer Lead: ${lead.name}\nPhone: ${lead.phone}\nStage: ${lead.stage}',
                        ),
                      );
                    }
                  },
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'details', child: Text('View Details', style: TextStyle(fontSize: 12))),
                    const PopupMenuItem(value: 'edit', child: Text('Edit Lead', style: TextStyle(fontSize: 12))),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red))),
                    const PopupMenuItem(value: 'share', child: Text('Share', style: TextStyle(fontSize: 12))),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.more_horiz_rounded, size: 14, color: Color(0xFF475569)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Desktop Table View ---
  Widget _buildDesktopTable() {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
          ),
          child: Row(
            children: const [
              Expanded(
                flex: 30,
                child: Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              Expanded(
                flex: 18,
                child: Text(
                  'Phone',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  'Source',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  'Stage',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              Expanded(
                flex: 16,
                child: Text(
                  'Last Interaction',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: Text(
                  'Actions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        ..._filteredLeads.take(_pageSize).map((lead) {
          final isSelected = _selectedLead?.id == lead.id;
          return _buildTableRow(lead, isSelected);
        }),
      ],
    );
  }

  Widget _buildTableRow(CrmLeadModel lead, bool isSelected) {
    final avatarColor = _getAvatarColor(lead.name);
    final initial = lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'G';
    final interactionDate = DateFormat('MMM dd, yyyy').format(lead.lastVisit ?? lead.createdAt);
    final interactionTime = DateFormat('h:mm a').format(lead.lastVisit ?? lead.createdAt);

    return InkWell(
      onTap: () => _onSelectLead(lead),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F5F9) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF8FAFC), width: 1)),
        ),
        child: Row(
          children: [
            // 1. Name & Subtitle with Avatar
            Expanded(
              flex: 30,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: avatarColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.name,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          lead.customerType,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Phone
            Expanded(
              flex: 18,
              child: Text(
                lead.phone,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ),

            // 3. Source Badge
            Expanded(
              flex: 14,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getSourceBgColor(lead.source),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    lead.source,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _getSourceTextColor(lead.source),
                    ),
                  ),
                ),
              ),
            ),

            // 4. Stage Badge
            Expanded(
              flex: 14,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getStageBgColor(lead.stage),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    lead.stage,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: _getStageTextColor(lead.stage),
                    ),
                  ),
                ),
              ),
            ),

            // 5. Last Interaction Date & Time
            Expanded(
              flex: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    interactionDate,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  Text(
                    interactionTime,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

            // 6. Action Circular Buttons (WhatsApp, Phone, More)
            Expanded(
              flex: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // WhatsApp Icon Circle
                  InkWell(
                    onTap: () => _openWhatsApp(lead.phone),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const WhatsAppBubbleIcon(size: 13, color: Colors.white),
                    ),
                  ),

                  const SizedBox(width: 5),

                  // Phone Call Icon Circle
                  InkWell(
                    onTap: () => _makePhoneCall(lead.phone),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.call_rounded, size: 13, color: Colors.white),
                    ),
                  ),

                  const SizedBox(width: 5),

                  // More Context Menu Circle
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'details') {
                        _onSelectLead(lead);
                      } else if (val == 'edit') {
                        _showAddEditLeadModal(context, existingLead: lead);
                      } else if (val == 'delete') {
                        _confirmDeleteLead(lead);
                      } else if (val == 'share') {
                        SharePlus.instance.share(
                          ShareParams(
                            text: 'Customer Lead: ${lead.name}\nPhone: ${lead.phone}\nStage: ${lead.stage}',
                          ),
                        );
                      }
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'details', child: Text('View Details', style: TextStyle(fontSize: 12))),
                      const PopupMenuItem(value: 'edit', child: Text('Edit Lead', style: TextStyle(fontSize: 12))),
                      const PopupMenuItem(value: 'delete', child: Text('Delete Lead', style: TextStyle(fontSize: 12, color: Colors.red))),
                      const PopupMenuItem(value: 'share', child: Text('Share Lead', style: TextStyle(fontSize: 12))),
                    ],
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.more_horiz_rounded, size: 15, color: Color(0xFF475569)),
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

  // --- Pagination Bar (Responsive & Wrapped) ---
  Widget _buildPaginationBar({required bool isMobile}) {
    final startIdx = math.min((_currentPage - 1) * _pageSize + 1, _totalCount);
    final endIdx = math.min(_currentPage * _pageSize, _totalCount);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Showing $startIdx-$endIdx of $_totalCount',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _currentPage > 1
                      ? () {
                          setState(() {
                            _currentPage--;
                          });
                          _loadLeadsFromBackend();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.chevron_left_rounded, size: 16, color: Color(0xFF475569)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                InkWell(
                  onTap: _currentPage < _totalPages
                      ? () {
                          setState(() {
                            _currentPage++;
                          });
                          _loadLeadsFromBackend();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF475569)),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _pageSize,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF475569)),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                      items: [8, 10, 20, 50].map((size) {
                        return DropdownMenuItem<int>(
                          value: size,
                          child: Text('$size'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _pageSize = val;
                            _currentPage = 1;
                          });
                          _loadLeadsFromBackend();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startIdx - $endIdx of $_totalCount customers',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                        _loadLeadsFromBackend();
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.chevron_left_rounded, size: 17, color: Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 6),
              ...List.generate(math.min(_totalPages, 5), (i) {
                final p = i + 1;
                final isActive = _currentPage == p;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _currentPage = p;
                      });
                      _loadLeadsFromBackend();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF0B192C) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? const Color(0xFF0B192C) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$p',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              InkWell(
                onTap: _currentPage < _totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                        _loadLeadsFromBackend();
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.chevron_right_rounded, size: 17, color: Color(0xFF475569)),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pageSize,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: Color(0xFF475569)),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    items: [8, 10, 20, 50].map((size) {
                      return DropdownMenuItem<int>(
                        value: size,
                        child: Text('$size / page'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _pageSize = val;
                          _currentPage = 1;
                        });
                        _loadLeadsFromBackend();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 5. RIGHT SECTION: SELECTED CUSTOMER DETAIL CARD
  // ==========================================================================
  Widget _buildCustomerDetailCard({required bool isMobile}) {
    final lead = _selectedLead ?? (_allLeads.isNotEmpty ? _allLeads.first : null);
    if (lead == null) {
      return Container(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: const Center(
          child: Text(
            'Select a customer to view details',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    final avatarColor = _getAvatarColor(lead.name);
    final initial = lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'G';

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Avatar, Name & Subtitle, Stage Pill Badge with Dot
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: isMobile ? 38 : 42,
                height: isMobile ? 38 : 42,
                decoration: BoxDecoration(
                  color: avatarColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.name,
                      style: TextStyle(
                        fontSize: isMobile ? 15 : 16.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${lead.customerType} • ${lead.source}',
                      style: TextStyle(
                        fontSize: isMobile ? 10.5 : 11.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: _getStageBgColor(lead.stage),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _getStageTextColor(lead.stage),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      lead.stage,
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 11,
                        fontWeight: FontWeight.w700,
                        color: _getStageTextColor(lead.stage),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Secondary Navigation Tabs (Overview, Activity, Notes, Orders, Follow-ups)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Overview', 'Activity', 'Notes', 'Orders', 'Follow-ups'].map((tab) {
                final isActive = _activeDetailTab == tab;
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _activeDetailTab = tab;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 12,
                        vertical: isMobile ? 5.5 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 11.5,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                          color: isActive ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // Dynamic Tab Content Switcher
          _buildActiveTabContent(lead, isMobile: isMobile),

          const SizedBox(height: 16),

          // Bottom Action Buttons (Wrapped & Responsive)
          _buildDetailActionButtons(lead, isMobile: isMobile),
        ],
      ),
    );
  }

  // --- Dynamic Tab Body Builder ---
  Widget _buildActiveTabContent(CrmLeadModel lead, {required bool isMobile}) {
    switch (_activeDetailTab) {
      case 'Activity':
        return _buildActivityTab(lead, isMobile: isMobile);
      case 'Notes':
        return _buildNotesTab(lead, isMobile: isMobile);
      case 'Orders':
        return _buildOrdersTab(lead, isMobile: isMobile);
      case 'Follow-ups':
        return _buildFollowupsTab(lead, isMobile: isMobile);
      case 'Overview':
      default:
        return _buildOverviewTab(lead, isMobile: isMobile);
    }
  }

  // 1. Overview Tab
  Widget _buildOverviewTab(CrmLeadModel lead, {required bool isMobile}) {
    final formattedAddedDate = DateFormat('dd MMM yyyy, h:mm a').format(lead.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoItem(
          icon: const Icon(Icons.call_outlined, size: 15, color: Color(0xFF0F172A)),
          text: lead.phone,
          isLink: false,
          fontSize: isMobile ? 11.5 : 12.5,
          onTap: () => _makePhoneCall(lead.phone),
          trailing: InkWell(
            onTap: () => _copyToClipboard(lead.phone, 'Phone number'),
            child: const Icon(Icons.content_copy_rounded, size: 14, color: Color(0xFF64748B)),
          ),
        ),

        const SizedBox(height: 8),

        _buildInfoItem(
          icon: const WhatsAppBubbleIcon(size: 15, color: Color(0xFF16A34A)),
          text: 'Chat on WhatsApp',
          isLink: true,
          fontSize: isMobile ? 11.5 : 12.5,
          textColor: const Color(0xFF0F172A),
          onTap: () => _openWhatsApp(lead.phone),
        ),

        const SizedBox(height: 8),

        _buildInfoItem(
          icon: const Icon(Icons.email_outlined, size: 15, color: Color(0xFF2563EB)),
          text: lead.email.isNotEmpty ? lead.email : 'No email provided',
          isLink: lead.email.isNotEmpty,
          fontSize: isMobile ? 11.5 : 12.5,
          textColor: lead.email.isNotEmpty ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
          trailing: lead.email.isNotEmpty
              ? InkWell(
                  onTap: () => _copyToClipboard(lead.email, 'Email'),
                  child: const Icon(Icons.content_copy_rounded, size: 14, color: Color(0xFF64748B)),
                )
              : null,
        ),

        const SizedBox(height: 8),

        _buildInfoItem(
          icon: const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF0F172A)),
          text: lead.address.isNotEmpty ? lead.address : 'No address provided',
          fontSize: isMobile ? 11.5 : 12.5,
        ),

        const SizedBox(height: 8),

        _buildInfoItem(
          icon: const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF0F172A)),
          text: 'Added on $formattedAddedDate',
          fontSize: isMobile ? 11 : 12,
        ),

        const SizedBox(height: 12),

        // Source and Stage Dynamic Change Row
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Source',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getSourceBgColor(lead.source),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    lead.source,
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11,
                      fontWeight: FontWeight.w700,
                      color: _getSourceTextColor(lead.source),
                    ),
                  ),
                ),
              ],
            ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Stage',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _allStages.contains(lead.stage) ? lead.stage : _allStages.first,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: Color(0xFF475569)),
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 11.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                      items: _allStages.map((st) {
                        return DropdownMenuItem<String>(
                          value: st,
                          child: Text(st),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _updateSelectedLeadStage(val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // 2. Activity Tab
  Widget _buildActivityTab(CrmLeadModel lead, {required bool isMobile}) {
    final createdDate = DateFormat('dd MMM yyyy, hh:mm a').format(lead.createdAt);
    final visitDate = lead.lastVisit != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(lead.lastVisit!)
        : 'No recent activity';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTimelineItem(
          icon: Icons.person_add_rounded,
          iconColor: const Color(0xFF2563EB),
          title: 'Lead Created',
          subtitle: 'Added as "${lead.stage}" from ${lead.source}',
          timestamp: createdDate,
          isMobile: isMobile,
        ),
        const SizedBox(height: 10),
        _buildTimelineItem(
          icon: Icons.storefront_rounded,
          iconColor: const Color(0xFF16A34A),
          title: 'Last Interaction / Visit',
          subtitle: 'Customer recorded interaction',
          timestamp: visitDate,
          isMobile: isMobile,
        ),
        if (lead.followupDate != null) ...[
          const SizedBox(height: 10),
          _buildTimelineItem(
            icon: Icons.alarm_rounded,
            iconColor: const Color(0xFFD97706),
            title: 'Follow-up Scheduled',
            subtitle: lead.followupNotes.isNotEmpty ? lead.followupNotes : 'Scheduled reminder',
            timestamp: DateFormat('dd MMM yyyy').format(lead.followupDate!),
            isMobile: isMobile,
          ),
        ],
      ],
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String timestamp,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 11.5 : 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isMobile ? 10.5 : 11.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: isMobile ? 9.5 : 10.5,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. Notes Tab
  Widget _buildNotesTab(CrmLeadModel lead, {required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Note',
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _noteInputController,
          maxLines: 2,
          style: TextStyle(
            fontSize: isMobile ? 11.5 : 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'Write a note...',
            hintStyle: TextStyle(fontSize: isMobile ? 11 : 12, color: const Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.all(8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: _saveNoteForSelectedLead,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 14, vertical: isMobile ? 6 : 7),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Save Note',
                style: TextStyle(
                  fontSize: isMobile ? 11 : 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Display Existing Notes History
        if (lead.notesList.isNotEmpty) ...[
          Text(
            'Notes History',
            style: TextStyle(
              fontSize: isMobile ? 11.5 : 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          ...lead.notesList.reversed.map((n) {
            final text = n is Map ? (n['note']?.toString() ?? '') : n.toString();
            final timeStr = n is Map && n['createdAt'] != null
                ? DateFormat('dd MMM, hh:mm a').format(DateTime.tryParse(n['createdAt'].toString()) ?? DateTime.now())
                : '';
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(fontSize: isMobile ? 11 : 11.5, color: const Color(0xFF334155), height: 1.3),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      timeStr,
                      style: TextStyle(fontSize: isMobile ? 9 : 10, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ],
              ),
            );
          }),
        ] else if (lead.notes.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              lead.notes,
              style: TextStyle(fontSize: isMobile ? 11 : 11.5, color: const Color(0xFF475569), height: 1.3),
            ),
          ),
        ] else ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No notes added yet.',
                style: TextStyle(fontSize: isMobile ? 11 : 12, color: const Color(0xFF94A3B8)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 4. Orders Tab
  Widget _buildOrdersTab(CrmLeadModel lead, {required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Spent',
                      style: TextStyle(fontSize: isMobile ? 10 : 11, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${lead.totalSpend.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: isMobile ? 15 : 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Orders',
                      style: TextStyle(fontSize: isMobile ? 10 : 11, color: const Color(0xFF16A34A), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lead.totalOrders}',
                      style: TextStyle(fontSize: isMobile ? 15 : 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (lead.recentOrders.isNotEmpty) ...[
          Text(
            'Recent Orders',
            style: TextStyle(fontSize: isMobile ? 11.5 : 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 6),
          ...lead.recentOrders.map((ord) {
            final id = ord is Map ? (ord['id'] ?? ord['_id'] ?? 'Order') : 'Order';
            final amt = ord is Map ? (ord['totalAmount'] ?? ord['amount'] ?? 0) : 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$id', style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w600)),
                  Text('₹$amt', style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w700, color: const Color(0xFF16A34A))),
                ],
              ),
            );
          }),
        ] else ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No orders recorded yet.',
                style: TextStyle(fontSize: isMobile ? 11 : 12, color: const Color(0xFF94A3B8)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 5. Follow-ups Tab
  Widget _buildFollowupsTab(CrmLeadModel lead, {required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lead.followupDate != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Scheduled Date',
                      style: TextStyle(fontSize: isMobile ? 10.5 : 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        lead.followupStatus.toUpperCase(),
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, dd MMM yyyy').format(lead.followupDate!),
                  style: TextStyle(fontSize: isMobile ? 13 : 14, fontWeight: FontWeight.w800, color: const Color(0xFF78350F)),
                ),
                if (lead.followupNotes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    lead.followupNotes,
                    style: TextStyle(fontSize: isMobile ? 11 : 11.5, color: const Color(0xFF92400E)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ] else ...[
          Center(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'No follow-up scheduled yet.',
                style: TextStyle(fontSize: isMobile ? 11 : 12, color: const Color(0xFF94A3B8)),
              ),
            ),
          ),
        ],

        Center(
          child: OutlinedButton.icon(
            onPressed: () => _scheduleFollowup(lead),
            icon: const Icon(Icons.calendar_month_rounded, size: 15),
            label: Text(
              lead.followupDate != null ? 'Reschedule Follow-up' : 'Schedule Follow-up',
              style: TextStyle(fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              side: const BorderSide(color: Color(0xFF2563EB)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  // --- Detail Action Buttons (Wrapped & Responsive) ---
  Widget _buildDetailActionButtons(CrmLeadModel lead, {required bool isMobile}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // WhatsApp Button (Green Outline)
        InkWell(
          onTap: () => _openWhatsApp(lead.phone),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 12,
              vertical: isMobile ? 7 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const WhatsAppBubbleIcon(size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 5),
                Text(
                  'WhatsApp',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Call Button (Blue Outline)
        InkWell(
          onTap: () => _makePhoneCall(lead.phone),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 12,
              vertical: isMobile ? 7 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2563EB), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.call_rounded, size: 14, color: Color(0xFF2563EB)),
                const SizedBox(width: 5),
                Text(
                  'Call',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ••• More Button (Gray Outline)
        PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'edit') {
              _showAddEditLeadModal(context, existingLead: lead);
            } else if (val == 'followup') {
              _scheduleFollowup(lead);
            } else if (val == 'delete') {
              _confirmDeleteLead(lead);
            } else if (val == 'export') {
              _exportLeadsToCsv();
            }
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit Customer', style: TextStyle(fontSize: 12))),
            const PopupMenuItem(value: 'followup', child: Text('Schedule Follow-up', style: TextStyle(fontSize: 12))),
            const PopupMenuItem(value: 'export', child: Text('Export CSV', style: TextStyle(fontSize: 12))),
            const PopupMenuItem(value: 'delete', child: Text('Delete Customer', style: TextStyle(fontSize: 12, color: Colors.red))),
          ],
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 12,
              vertical: isMobile ? 7 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            ),
            child: Text(
              '••• More',
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required Widget icon,
    required String text,
    bool isLink = false,
    Color? textColor,
    VoidCallback? onTap,
    Widget? trailing,
    double fontSize = 12.5,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: textColor ?? const Color(0xFF334155),
                decoration: isLink ? TextDecoration.none : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  // ==========================================================================
  // MODALS: ADD/EDIT LEAD, IMPORT, EXPORT, DELETE
  // ==========================================================================
  void _showAddEditLeadModal(BuildContext context, {CrmLeadModel? existingLead}) {
    final isEditing = existingLead != null;
    final nameCtrl = TextEditingController(text: existingLead?.name ?? '');
    final phoneCtrl = TextEditingController(text: existingLead?.phone ?? '');
    final emailCtrl = TextEditingController(text: existingLead?.email ?? '');
    final addressCtrl = TextEditingController(text: existingLead?.address ?? '');
    final sourceCtrl = TextEditingController(text: existingLead?.source ?? 'Dine In');
    final stageCtrl = TextEditingController(text: existingLead?.stage ?? 'New Lead');
    final typeCtrl = TextEditingController(text: existingLead?.customerType ?? 'New Customer');
    final notesCtrl = TextEditingController(text: existingLead?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEditing ? 'Edit Customer Lead' : 'Add New Lead',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name *', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number *', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address / Location', isDense: true),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: sourceCtrl.text,
                        decoration: const InputDecoration(labelText: 'Source', isDense: true),
                        items: ['Dine In', 'POS', 'Online', 'WhatsApp', 'Social Media', 'Referral', 'Website']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) sourceCtrl.text = val;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: stageCtrl.text,
                        decoration: const InputDecoration(labelText: 'Stage', isDense: true),
                        items: _allStages
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) stageCtrl.text = val;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Type (e.g. New Customer, Walk-in)', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes', isDense: true),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B192C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final phone = phoneCtrl.text.trim();
              if (phone.isEmpty) {
                _showSnackBar('Phone number is required', isError: true);
                return;
              }

              final newLead = CrmLeadModel(
                id: isEditing ? existingLead.id : DateTime.now().millisecondsSinceEpoch.toString(),
                name: name.isNotEmpty ? name : 'Guest Customer',
                phone: phone,
                email: emailCtrl.text.trim(),
                address: addressCtrl.text.trim(),
                source: sourceCtrl.text,
                stage: stageCtrl.text,
                status: stageCtrl.text,
                customerType: typeCtrl.text.trim().isNotEmpty ? typeCtrl.text.trim() : 'New Customer',
                tags: [stageCtrl.text],
                notes: notesCtrl.text.trim(),
                createdAt: isEditing ? existingLead.createdAt : DateTime.now(),
                lastVisit: DateTime.now(),
              );

              Navigator.pop(ctx);

              setState(() {
                if (isEditing) {
                  final idx = _allLeads.indexWhere((l) => l.id == existingLead.id);
                  if (idx != -1) _allLeads[idx] = newLead;
                } else {
                  _allLeads.insert(0, newLead);
                }
                _selectedLead = newLead;
                _applyLocalFilter();
              });

              _showSnackBar(isEditing ? 'Customer updated' : 'New lead added successfully');

              try {
                if (isEditing) {
                  await _crmService.updateLead(newLead.id, newLead.toJson());
                } else {
                  await _crmService.createLead(newLead.toJson());
                }
              } catch (_) {}
            },
            child: Text(isEditing ? 'Update' : 'Add Lead'),
          ),
        ],
      ),
    );
  }

  void _showImportModal() {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Import Customers',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste comma-separated leads (Name, Phone, Source, Stage):',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textCtrl,
                maxLines: 4,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Aarav Kumar, 9876543211, Dine In, New Lead\nSimran Kaur, 9811223344, Online, Prospect',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFCBD5E1))),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0B192C), foregroundColor: Colors.white),
            onPressed: () {
              final raw = textCtrl.text.trim();
              if (raw.isEmpty) return;

              final lines = raw.split('\n');
              int count = 0;
              for (final line in lines) {
                final parts = line.split(',');
                if (parts.length >= 2) {
                  final lead = CrmLeadModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString() + count.toString(),
                    name: parts[0].trim(),
                    phone: parts[1].trim(),
                    source: parts.length > 2 ? parts[2].trim() : 'Dine In',
                    stage: parts.length > 3 ? parts[3].trim() : 'New Lead',
                    status: parts.length > 3 ? parts[3].trim() : 'New Lead',
                    customerType: 'New Customer',
                    createdAt: DateTime.now(),
                    lastVisit: DateTime.now(),
                  );
                  _allLeads.insert(0, lead);
                  count++;
                  // Persist asynchronously
                  _crmService.createLead(lead.toJson()).catchError((_) => lead);
                }
              }

              Navigator.pop(ctx);
              _applyLocalFilter();
              _showSnackBar('Imported $count customers successfully');
              _loadLeadsFromBackend();
            },
            child: const Text('Import Leads'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteLead(CrmLeadModel lead) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${lead.name}?'),
        content: const Text('Are you sure you want to delete this customer lead? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _allLeads.removeWhere((l) => l.id == lead.id);
                if (_selectedLead?.id == lead.id) {
                  _selectedLead = _allLeads.isNotEmpty ? _allLeads.first : null;
                }
                _applyLocalFilter();
              });
              _showSnackBar('Customer lead deleted');
              try {
                await _crmService.deleteLead(lead.id);
                _loadLeadsFromBackend();
              } catch (_) {}
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLeadsToCsv() async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('Name,Phone,Email,Source,Stage,Customer Type,Created At');
      for (final l in _allLeads) {
        buffer.writeln('"${l.name}","${l.phone}","${l.email}","${l.source}","${l.stage}","${l.customerType}","${l.createdAt}"');
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/crm_leads_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Exported CRM Leads (${_allLeads.length} records)',
        ),
      );
    } catch (e) {
      _showSnackBar('Export failed: $e', isError: true);
    }
  }
}

// ============================================================================
// DATA MODEL FOR TOP METRIC CARDS
// ============================================================================
class _MetricCardData {
  final String title;
  final String value;
  final String trend;
  final Color iconBgColor;
  final Color iconColor;
  final Widget iconWidget;
  final Color waveColor;

  _MetricCardData({
    required this.title,
    required this.value,
    required this.trend,
    required this.iconBgColor,
    required this.iconColor,
    required this.iconWidget,
    required this.waveColor,
  });
}

// ============================================================================
// CUSTOM PAINTER FOR SMOOTH SPARKLINE BEZIER WAVES
// ============================================================================
class SparklineWavePainter extends CustomPainter {
  final Color color;

  SparklineWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    // Gentle curved bezier wave matching the reference image
    path.moveTo(0, size.height * 0.7);
    path.cubicTo(
      size.width * 0.25,
      size.height * 0.85,
      size.width * 0.45,
      size.height * 0.2,
      size.width * 0.7,
      size.height * 0.45,
    );
    path.cubicTo(
      size.width * 0.85,
      size.height * 0.65,
      size.width * 0.92,
      size.height * 0.15,
      size.width,
      size.height * 0.05,
    );

    // Stroke line
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // Gradient fill under the wave
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.25),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant SparklineWavePainter oldDelegate) => oldDelegate.color != color;
}

// ============================================================================
// CUSTOM CROWN ICON (Used in Leads Card)
// ============================================================================
class CrownIcon extends StatelessWidget {
  final double size;
  final Color color;

  const CrownIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CrownPainter(color: color),
    );
  }
}

class _CrownPainter extends CustomPainter {
  final Color color;
  _CrownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    // Crown base and 3 peaks
    path.moveTo(size.width * 0.15, size.height * 0.75);
    path.lineTo(size.width * 0.15, size.height * 0.35);
    path.lineTo(size.width * 0.35, size.height * 0.55);
    path.lineTo(size.width * 0.5, size.height * 0.25);
    path.lineTo(size.width * 0.65, size.height * 0.55);
    path.lineTo(size.width * 0.85, size.height * 0.35);
    path.lineTo(size.width * 0.85, size.height * 0.75);
    path.close();

    canvas.drawPath(path, paint);

    // Bottom base band
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.12, size.height * 0.8, size.width * 0.76, size.height * 0.08),
      const Radius.circular(2),
    );
    canvas.drawRRect(baseRect, paint);

    // 3 small top balls
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.32), size.width * 0.045, paint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.22), size.width * 0.05, paint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.32), size.width * 0.045, paint);
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) => oldDelegate.color != color;
}

// ============================================================================
// CUSTOM WHATSAPP BUBBLE ICON
// ============================================================================
class WhatsAppBubbleIcon extends StatelessWidget {
  final double size;
  final Color color;

  const WhatsAppBubbleIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.chat_rounded, size: size, color: color);
  }
}
