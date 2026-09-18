import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/database_service.dart';
import '../../../core/models/crm_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/crm_service.dart';
import '../../../core/services/customer_service.dart';

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
  final CustomerService _customerService = CustomerService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteInputController = TextEditingController();

  // Signature Theme Colors (Lighter shade of top navy header Color(0xFF051C48))
  static const Color headerNavy = Color(0xFF051C48);
  static const Color primaryNavy = Color(0xFF0A2B66); // Lighter header color for buttons & active boxes
  static const Color textDark = Color(0xFF0F172A);
  static const Color textSubtle = Color(0xFF64748B);
  static const Color boxBorder = Color(0xFFCBD5E1);
  static const Color boxBg = Color(0xFFF8FAFC);

  // State Variables
  String _selectedStageTab = 'All';
  String _selectedSourceFilter = 'All Sources';
  DateTimeRange? _selectedDateRange;

  // Pagination (Fixed 5 leads per page)
  int _currentPage = 1;
  static const int _pageSize = 5;
  int _totalCount = 0;
  int _totalPages = 1;
  bool _isLoading = false;

  // Persisted local lead stage overrides across user edits
  static final Map<String, String> _persistedLeadStages = {};

  // Detail Sub-tab
  String _activeDetailTab = 'Overview';

  // Leads
  List<CrmLeadModel> _allLeads = [];
  List<CrmLeadModel> _filteredLeads = [];
  CrmLeadModel? _selectedLead;

  // Dynamic Statistics
  CrmStatsModel _stats = CrmStatsModel(
    total: 0,
    leads: 0,
    prospects: 0,
    deals: 0,
    wins: 0,
    lost: 0,
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
    _loadLeadsFromBackend();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteInputController.dispose();
    super.dispose();
  }

  /// Load leads dynamically from all sources (CRM API + Customer DB + POS Live Orders)
  Future<void> _loadLeadsFromBackend() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stageParam = _selectedStageTab == 'All' ? null : _selectedStageTab;
      final searchParam = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();
      final sourceParam = _selectedSourceFilter == 'All Sources' ? null : _selectedSourceFilter;
      final startParam = _selectedDateRange?.start.toIso8601String();
      final endParam = _selectedDateRange?.end.toIso8601String();

      // 1. Fetch from CRM Backend API (Source of Truth for leads, orders, visits & spend)
      CrmFetchResult? crmApiResult;
      try {
        crmApiResult = await _crmService.fetchLeads(
          page: _currentPage,
          limit: _pageSize,
          stage: stageParam,
          search: searchParam,
          source: sourceParam,
          startDate: startParam,
          endDate: endParam,
        );
      } catch (e) {
        debugPrint('[CrmLeadsScreen] API fetch error: $e');
      }

      if (crmApiResult != null) {
        // Direct binding from API
        final leads = crmApiResult.leads.map((l) {
          final key = l.phone.trim().isNotEmpty ? l.phone.trim() : l.name.trim();
          final stageOverride = _persistedLeadStages[key] ?? _persistedLeadStages[l.id];
          if (stageOverride != null && stageOverride != l.stage) {
            return l.copyWith(stage: stageOverride, status: stageOverride);
          }
          return l;
        }).toList();

        if (mounted) {
          _allLeads = leads;
          _totalCount = crmApiResult.totalCount;
          _totalPages = crmApiResult.totalPages;
          _stats = crmApiResult.stats;
          _applyLocalFilter();
        }
        return;
      }

      // 2. Offline Fallback: Fetch from Customer Database & synced orders
      List<CustomerModel> dbCustomers = [];
      try {
        dbCustomers = await _customerService.fetchCustomers(
          search: searchParam,
          limit: 100,
        );
      } catch (_) {}

      final Map<String, CrmLeadModel> aggregatedMap = {};
      for (final cust in dbCustomers) {
        final key = cust.phone.trim().isNotEmpty ? cust.phone.trim() : cust.name.trim();
        if (key.isEmpty) continue;

        final stageOverride = _persistedLeadStages[key] ?? _persistedLeadStages[cust.id];
        final isRegular = cust.totalOrders > 1;
        final defaultStage = isRegular ? 'Won' : 'New Lead';
        final effStage = stageOverride ?? defaultStage;

        aggregatedMap[key] = CrmLeadModel(
          id: cust.id.isNotEmpty ? cust.id : 'cust_${cust.phone}',
          name: cust.name.isNotEmpty ? cust.name : 'Customer',
          phone: cust.phone,
          email: cust.email,
          address: cust.address,
          source: 'POS',
          stage: effStage,
          status: effStage,
          customerType: isRegular ? 'Regular Customer' : 'New Customer',
          tags: isRegular ? const ['Regular Customer', 'POS'] : const ['New Customer', 'POS'],
          totalOrders: cust.totalOrders,
          totalSpent: cust.totalSpent,
          visitCount: cust.totalOrders > 0 ? cust.totalOrders : 0,
          returnCount: 0,
          createdAt: DateTime.now(),
          lastVisit: cust.lastVisit != null ? DateTime.tryParse(cust.lastVisit!) : DateTime.now(),
        );
      }

      final dynamicList = aggregatedMap.values.toList();

      if (mounted) {
        _allLeads = dynamicList;
        _applyLocalFilter();
      }
    } catch (e) {
      debugPrint('[CrmLeadsScreen] Error loading dynamic leads: $e');
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
      final target = _selectedStageTab.toLowerCase().trim();
      list = list.where((lead) {
        final st = lead.stage.toLowerCase().trim();
        if (target == 'leads' || target == 'lead') {
          return st == 'lead' || st == 'new lead' || (st.contains('lead') && !st.contains('deal'));
        }
        if (target == 'prospects' || target == 'prospect') {
          return st == 'prospect' || st.contains('prospect');
        }
        if (target == 'deals' || target == 'deal') {
          return st == 'deal' || st.contains('deal');
        }
        if (target == 'won' || target == 'wins' || target == 'won customers') {
          return st == 'won' || st.contains('won') || st.contains('win');
        }
        if (target == 'lost') {
          return st == 'lost' || st.contains('lost');
        }
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

    // 4. Date Filter
    if (_selectedDateRange != null) {
      final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
      final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
      list = list.where((lead) {
        final d = lead.lastVisit ?? lead.createdAt;
        return d.isAfter(start.subtract(const Duration(seconds: 1))) && d.isBefore(end.add(const Duration(seconds: 1)));
      }).toList();
    }

    setState(() {
      _filteredLeads = list;
      _totalCount = _filteredLeads.length;
      _totalPages = math.max(1, (_filteredLeads.length / _pageSize).ceil());
      if (_currentPage > _totalPages) _currentPage = _totalPages;
      if (_currentPage < 1) _currentPage = 1;

      if (_selectedLead == null || !_filteredLeads.any((l) => l.id == _selectedLead!.id)) {
        if (_filteredLeads.isNotEmpty) {
          _selectedLead = _filteredLeads.first;
        } else {
          _selectedLead = null;
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
      final st = l.stage.toLowerCase().trim();
      if (st == 'prospect' || st.contains('prospect')) {
        prospects++;
      } else if (st == 'deal' || st.contains('deal')) {
        deals++;
      } else if (st == 'won' || st.contains('won') || st.contains('win')) {
        wins++;
      } else if (st == 'lost' || st.contains('lost')) {
        lost++;
      } else {
        // default / new lead
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
    );
  }

  // --- Actions ---

  void _onSelectLead(CrmLeadModel lead) {
    setState(() {
      _selectedLead = lead;
    });

    if (lead.id.isNotEmpty && !lead.id.startsWith('cust_') && !lead.id.startsWith('ord_')) {
      _crmService.fetchLeadById(lead.id).then((freshLead) {
        if (freshLead != null && mounted && _selectedLead?.id == lead.id) {
          setState(() {
            _selectedLead = freshLead;
            final idx = _allLeads.indexWhere((l) => l.id == freshLead.id);
            if (idx != -1) {
              _allLeads[idx] = freshLead;
            }
          });
        }
      }).catchError((_) {});
    }
  }

  Future<void> _updateSelectedLeadStage(String newStage) async {
    if (_selectedLead == null) return;
    final updated = _selectedLead!.copyWith(stage: newStage, status: newStage);
    final key = updated.phone.trim().isNotEmpty ? updated.phone.trim() : updated.name.trim();
    if (key.isNotEmpty) {
      _persistedLeadStages[key] = newStage;
    }
    _persistedLeadStages[updated.id] = newStage;

    setState(() {
      final idx = _allLeads.indexWhere((l) => l.id == _selectedLead!.id);
      if (idx != -1) {
        _allLeads[idx] = updated;
      }
      _selectedLead = updated;
      _applyLocalFilter();
    });

    _showSnackBar('Stage updated to "$newStage"');
    try {
      await _crmService.updateStage(updated.id, newStage);
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
              primary: primaryNavy,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textDark,
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Schedule Follow-up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textDark)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date: ${DateFormat('dd MMM yyyy').format(pickedDate)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryNavy),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 12.5, color: textDark),
              decoration: InputDecoration(
                labelText: 'Follow-up Reason / Notes',
                labelStyle: const TextStyle(color: textSubtle, fontSize: 12),
                hintText: 'e.g. Call to confirm catering order',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                isDense: true,
                filled: true,
                fillColor: boxBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: boxBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: boxBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryNavy, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: boxBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel', style: TextStyle(color: textSubtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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

  /// Launch phone dialer directly with the customer number
  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      _showSnackBar('Invalid phone number', isError: true);
      return;
    }

    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(uri);
      return;
    } catch (_) {}

    _copyToClipboard(cleanPhone, 'Phone number');
    _showSnackBar('Calling $phone (copied to clipboard)');
  }

  /// Launch WhatsApp chat directly with cleaned phone number across Windows and Mobile
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

    final universalWaUri = Uri.parse('https://wa.me/$cleanDigits');
    final nativeWhatsappUri = Uri.parse('whatsapp://send?phone=$cleanDigits');
    final apiWhatsappUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanDigits');
    final webWhatsappUri = Uri.parse('https://web.whatsapp.com/send?phone=$cleanDigits');

    // 1. Try launching native WhatsApp app (on Windows desktop app or mobile app)
    try {
      if (await canLaunchUrl(nativeWhatsappUri)) {
        final ok = await launchUrl(nativeWhatsappUri, mode: LaunchMode.externalNonBrowserApplication);
        if (ok) return;
      }
    } catch (_) {}

    // 2. Launch universal wa.me URI in external application (WhatsApp Web / Browser / Mobile App)
    try {
      if (await canLaunchUrl(universalWaUri)) {
        final ok = await launchUrl(universalWaUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    } catch (_) {}

    // 3. Fallback to api.whatsapp.com
    try {
      if (await canLaunchUrl(apiWhatsappUri)) {
        final ok = await launchUrl(apiWhatsappUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
    } catch (_) {}

    // 4. Web WhatsApp fallback
    try {
      await launchUrl(webWhatsappUri, mode: LaunchMode.externalApplication);
      return;
    } catch (_) {}

    _showSnackBar('Could not open WhatsApp for $phone', isError: true);
  }

  /// Show quick popup modal to Add or Edit Delivery Address
  Future<void> _showAddressDialog(CrmLeadModel lead) async {
    final addrCtrl = TextEditingController(text: lead.address);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          lead.address.isNotEmpty ? 'Edit Delivery Address' : 'Add Delivery Address',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textDark),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer: ${lead.name} (${lead.phone})',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSubtle),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addrCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textDark),
              decoration: InputDecoration(
                labelText: 'Delivery Address / Area / Landmark',
                labelStyle: const TextStyle(color: textSubtle, fontSize: 12),
                hintText: 'e.g. Flat 302, Green Valley Apts, Sector 62, Noida',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                filled: true,
                fillColor: boxBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: boxBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: boxBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryNavy, width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: boxBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel', style: TextStyle(color: textSubtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save Address'),
          ),
        ],
      ),
    );

    if (saved == true && mounted) {
      final newAddr = addrCtrl.text.trim();
      final updated = lead.copyWith(address: newAddr);

      setState(() {
        final idx = _allLeads.indexWhere((l) => l.id == lead.id);
        if (idx != -1) _allLeads[idx] = updated;
        if (_selectedLead?.id == lead.id) _selectedLead = updated;
        final fIdx = _filteredLeads.indexWhere((l) => l.id == lead.id);
        if (fIdx != -1) _filteredLeads[fIdx] = updated;
      });

      _showSnackBar(newAddr.isNotEmpty ? 'Delivery address updated' : 'Address cleared');

      try {
        await _customerService.saveCustomer(
          name: updated.name,
          phone: updated.phone,
          email: updated.email,
          address: newAddr,
        );
        await _crmService.updateLead(updated.id, {'address': newAddr});
      } catch (_) {}
    }
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
        backgroundColor: isError ? const Color(0xFFDC2626) : primaryNavy,
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==========================================================================
  // REDESIGNED POPUP MODAL FOR DATE FILTER SELECTION
  // ==========================================================================
  Future<void> _showDateFilterPopup() async {
    DateTime? tempStart = _selectedDateRange?.start ?? DateTime.now().subtract(const Duration(days: 30));
    DateTime? tempEnd = _selectedDateRange?.end ?? DateTime.now();
    String activePreset = _selectedDateRange == null ? 'All Time' : 'Custom';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    final monthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void applyPreset(String preset) {
              setDialogState(() {
                activePreset = preset;
                switch (preset) {
                  case 'Today':
                    tempStart = today;
                    tempEnd = today;
                    break;
                  case 'Yesterday':
                    tempStart = yesterday;
                    tempEnd = yesterday;
                    break;
                  case 'Last 7 Days':
                    tempStart = sevenDaysAgo;
                    tempEnd = today;
                    break;
                  case 'This Month':
                    tempStart = monthStart;
                    tempEnd = today;
                    break;
                  case 'Last Month':
                    tempStart = lastMonthStart;
                    tempEnd = lastMonthEnd;
                    break;
                  case 'All Time':
                    tempStart = null;
                    tempEnd = null;
                    break;
                }
              });
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryNavy.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.date_range_rounded, size: 20, color: primaryNavy),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Date Range',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: textDark,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Filter customers by interaction date',
                                style: TextStyle(fontSize: 11.5, color: textSubtle),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 18, color: textSubtle),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Preset Chips
                    const Text(
                      'Quick Presets',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Today',
                        'Yesterday',
                        'Last 7 Days',
                        'This Month',
                        'Last Month',
                        'All Time',
                      ].map((preset) {
                        final isSelected = activePreset == preset;
                        return InkWell(
                          onTap: () => applyPreset(preset),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryNavy : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? primaryNavy : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              preset,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Custom Date Inputs (From - To)
                    const Text(
                      'Custom Range',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Start Date
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempStart ?? DateTime.now(),
                                firstDate: DateTime(2024, 1, 1),
                                lastDate: DateTime(2030, 12, 31),
                                builder: (context, child) => Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: primaryNavy,
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: textDark,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  tempStart = picked;
                                  activePreset = 'Custom';
                                  if (tempEnd != null && tempEnd!.isBefore(tempStart!)) {
                                    tempEnd = tempStart;
                                  }
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: boxBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: boxBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'FROM',
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 13, color: primaryNavy),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          tempStart != null ? DateFormat('dd MMM yyyy').format(tempStart!) : 'Start Date',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: tempStart != null ? textDark : const Color(0xFF94A3B8),
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
                          ),
                        ),

                        const SizedBox(width: 8),

                        // End Date
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempEnd ?? tempStart ?? DateTime.now(),
                                firstDate: tempStart ?? DateTime(2024, 1, 1),
                                lastDate: DateTime(2030, 12, 31),
                                builder: (context, child) => Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: primaryNavy,
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: textDark,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  tempEnd = picked;
                                  activePreset = 'Custom';
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: boxBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: boxBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'TO',
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 13, color: primaryNavy),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          tempEnd != null ? DateFormat('dd MMM yyyy').format(tempEnd!) : 'End Date',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: tempEnd != null ? textDark : const Color(0xFF94A3B8),
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
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _selectedDateRange = null;
                                _currentPage = 1;
                              });
                              _applyLocalFilter();
                              _loadLeadsFromBackend();
                              _showSnackBar('Date filter reset (All Time)');
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: boxBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            child: const Text('Reset All', style: TextStyle(color: textSubtle, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (tempStart != null && tempEnd != null) {
                                setState(() {
                                  _selectedDateRange = DateTimeRange(start: tempStart!, end: tempEnd!);
                                  _currentPage = 1;
                                });
                                _applyLocalFilter();
                                _loadLeadsFromBackend();
                                _showSnackBar(
                                  'Filtered: ${DateFormat('dd MMM').format(tempStart!)} - ${DateFormat('dd MMM yyyy').format(tempEnd!)}',
                                );
                              } else {
                                setState(() {
                                  _selectedDateRange = null;
                                  _currentPage = 1;
                                });
                                _applyLocalFilter();
                                _loadLeadsFromBackend();
                              }
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryNavy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            child: const Text('Apply Filter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
    if (n.startsWith('J') || n.startsWith('C')) return headerNavy;
    if (n.startsWith('R') || n.startsWith('P') || n.startsWith('A') || n.startsWith('S')) {
      return primaryNavy;
    }
    if (n.startsWith('V')) return const Color(0xFF1E293B);
    if (n.startsWith('N')) return const Color(0xFF854D0E);
    return primaryNavy;
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
              color: primaryNavy,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 20,
                  vertical: isMobile ? 12 : 18,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Header (Without Back Button)
                    _buildHeaderRow(isMobile),

                    SizedBox(height: isMobile ? 12 : 16),

                    // 2. 5 Dynamic Metric Cards with Sparklines & Distinct Icons (Matching Image)
                    _buildMetricCardsRow(isWide, isMobile),

                    SizedBox(height: isMobile ? 14 : 18),

                    // 3. Stage Tabs & Curved Dropdowns / Filters
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
  // 1. HEADER ROW: CRM, Subtitle, Import, + Add Lead (Clean Modern Header)
  // ==========================================================================
  Widget _buildHeaderRow(bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
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
                  color: textDark,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Manage customers, leads & relationships',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textSubtle,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Action Buttons: Import, + Add Lead (Styled with primaryNavy)
        Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Import Button
            InkWell(
              onTap: _showImportModal,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 14,
                  vertical: isMobile ? 7 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: boxBorder, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.file_upload_outlined, size: 14, color: textDark),
                    const SizedBox(width: 4),
                    Text(
                      'Import',
                      style: TextStyle(
                        fontSize: isMobile ? 11.5 : 12,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // + Add New Lead Button (Primary Header Navy Tone)
            InkWell(
              onTap: () => _showAddEditLeadModal(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 7.5 : 8.5,
                ),
                decoration: BoxDecoration(
                  color: primaryNavy,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x180A2B66),
                      blurRadius: 5,
                      offset: Offset(0, 2),
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
  // 2. 5 DYNAMIC METRIC CARDS ROW (Matching Image)
  // ==========================================================================
  Widget _buildMetricCardsRow(bool isWide, bool isMobile) {
    final cards = [
      _MetricCardData(
        title: 'Total Contacts',
        value: '${_stats.total}',
        stageTab: 'All',
        iconBgColor: const Color(0xFFE0F2FE),
        iconColor: const Color(0xFF0284C7),
        iconWidget: Icon(Icons.people_alt_rounded, size: isMobile ? 22 : 24, color: const Color(0xFF0284C7)),
        waveColor: const Color(0xFF38BDF8),
      ),
      _MetricCardData(
        title: 'Leads',
        value: '${_stats.leads}',
        stageTab: 'Leads',
        iconBgColor: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFD97706),
        iconWidget: CrownIcon(size: isMobile ? 22 : 24, color: const Color(0xFFD97706)),
        waveColor: const Color(0xFFF59E0B),
      ),
      _MetricCardData(
        title: 'Prospects',
        value: '${_stats.prospects}',
        stageTab: 'Prospects',
        iconBgColor: const Color(0xFFF3E8FF),
        iconColor: const Color(0xFF9333EA),
        iconWidget: Icon(Icons.handshake_rounded, size: isMobile ? 22 : 24, color: const Color(0xFF9333EA)),
        waveColor: const Color(0xFFA855F7),
      ),
      _MetricCardData(
        title: 'Deals',
        value: '${_stats.deals}',
        stageTab: 'Deals',
        iconBgColor: const Color(0xFFDCFCE7),
        iconColor: const Color(0xFF16A34A),
        iconWidget: Icon(Icons.shopping_bag_rounded, size: isMobile ? 22 : 24, color: const Color(0xFF16A34A)),
        waveColor: const Color(0xFF22C55E),
      ),
      _MetricCardData(
        title: 'Won Customers',
        value: '${_stats.wins}',
        stageTab: 'Won',
        iconBgColor: const Color(0xFFFEF3C7),
        iconColor: const Color(0xFFEA580C),
        iconWidget: Icon(Icons.emoji_events_rounded, size: isMobile ? 22 : 24, color: const Color(0xFFEA580C)),
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
                width: isMobile ? 165 : 185,
                margin: const EdgeInsets.only(right: 10),
                child: _buildSingleMetricCard(card, isMobile: isMobile),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildSingleMetricCard(_MetricCardData data, {required bool isMobile}) {
    final isSelected = _selectedStageTab == data.stageTab;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStageTab = data.stageTab;
          _currentPage = 1;
          _applyLocalFilter();
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isMobile ? 78 : 86,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primaryNavy : const Color(0xFFF1F5F9),
            width: isSelected ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? primaryNavy.withValues(alpha: 0.12) : const Color(0x06000000),
              blurRadius: isSelected ? 8 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 0,
              width: isMobile ? 85 : 100,
              height: isMobile ? 42 : 50,
              child: Opacity(
                opacity: 0.9,
                child: CustomPaint(
                  painter: SparklineWavePainter(color: data.waveColor, isSelected: isSelected),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 12, vertical: isMobile ? 8 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: isMobile ? 40 : 44,
                    height: isMobile ? 40 : 44,
                    decoration: BoxDecoration(
                      color: data.iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: data.iconWidget,
                  ),
                  const SizedBox(width: 9),
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
                            color: textSubtle,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.value,
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.w800,
                            color: textDark,
                            letterSpacing: -0.4,
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
    );
  }

  // ==========================================================================
  // 3. STAGE TABS & CURVED FILTER CONTROLS
  // ==========================================================================
  Widget _buildStageTabsAndFiltersRow(bool isWide, bool isMobile) {
    if (isWide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: _buildStagePillsRow(isMobile: false),
          ),
          const SizedBox(width: 12),
          _buildFilterControlsRow(isMobile: false),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStagePillsRow(isMobile: isMobile),
        const SizedBox(height: 10),
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
                  _applyLocalFilter();
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 12,
                  vertical: isMobile ? 6 : 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? primaryNavy : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? primaryNavy : boxBorder,
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
    final dateLabel = _selectedDateRange == null
        ? 'All Dates'
        : '${DateFormat('dd MMM').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Sources Dropdown (Curved Shape Box with High Visibility Text)
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: boxBorder, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSourceFilter,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF475569)),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDark),
              items: _allSources.map((source) {
                return DropdownMenuItem<String>(
                  value: source,
                  child: Text(
                    source,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDark),
                  ),
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

        // Redesigned Date Filter Popup Button (Curved Shape Box)
        InkWell(
          onTap: _showDateFilterPopup,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _selectedDateRange != null ? primaryNavy.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _selectedDateRange != null ? primaryNavy : boxBorder,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: _selectedDateRange != null ? primaryNavy : const Color(0xFF475569),
                ),
                const SizedBox(width: 6),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 11.5,
                    fontWeight: _selectedDateRange != null ? FontWeight.w700 : FontWeight.w600,
                    color: _selectedDateRange != null ? primaryNavy : textDark,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: _selectedDateRange != null ? primaryNavy : const Color(0xFF475569),
                ),
              ],
            ),
          ),
        ),

        // Reset Filter Action Button (Curved Shape Box)
        InkWell(
          onTap: () {
            _searchController.clear();
            setState(() {
              _selectedStageTab = 'All';
              _selectedSourceFilter = 'All Sources';
              _selectedDateRange = null;
              _currentPage = 1;
            });
            _loadLeadsFromBackend();
            _showSnackBar('Filters reset');
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: boxBorder, width: 1),
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
                    color: textDark,
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
  // 4. LEFT SECTION: TABLE CARD (Wrapped in Horizontal Scroll)
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
                      color: textDark,
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

          // Content: Loading, Empty, or Data View
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: primaryNavy,
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
                        color: textSubtle,
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

          // Dynamic Pagination: ONLY rendered if leads are present!
          if (_filteredLeads.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _buildPaginationBar(isMobile: isMobile),
          ],
        ],
      ),
    );
  }

  // --- Mobile Leads List View with Dynamic Paging ---
  Widget _buildMobileLeadsList() {
    final start = (_currentPage - 1) * _pageSize;
    final leadsToShow = _filteredLeads.skip(start).take(_pageSize).toList();

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

  // --- Mobile Lead Card Item (Optimized Area Management & Standalone Action Icons) ---
  Widget _buildMobileLeadCardItem(CrmLeadModel lead, bool isSelected) {
    final avatarColor = _getAvatarColor(lead.name);
    final initial = lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'G';
    final interactionDate = DateFormat('dd MMM').format(lead.lastVisit ?? lead.createdAt);

    return InkWell(
      onTap: () => _onSelectLead(lead),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryNavy : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name + Regular Tag + Stage Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 13.5,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          if (lead.isRegularCustomer) ...[
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: primaryNavy.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Regular',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: primaryNavy,
                                ),
                              ),
                            ),
                          ],
                          Flexible(
                            child: Text(
                              lead.displayCustomerType,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: lead.isRegularCustomer ? FontWeight.w700 : FontWeight.w500,
                                color: lead.isRegularCustomer ? primaryNavy : textSubtle,
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
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getStageBgColor(lead.stage),
                    borderRadius: BorderRadius.circular(8),
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
              ],
            ),

            const SizedBox(height: 7),

            // Middle Row: Phone (One-Tap Dial), Source Badge, Spent & Orders Summary
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  onTap: () => _makePhoneCall(lead.phone),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF2563EB)),
                      const SizedBox(width: 3),
                      Text(
                        lead.phone,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: _getSourceBgColor(lead.source),
                    borderRadius: BorderRadius.circular(6),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '₹${lead.totalSpend.toStringAsFixed(0)} • ${lead.totalOrders} ${lead.totalOrders == 1 ? 'order' : 'orders'}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Bottom Action Strip: Last interaction & Standalone Action Icons (Enlarged, No Circles)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text(
                      'Active: $interactionDate',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: textSubtle,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Standalone Enlarged WhatsApp Icon
                    InkWell(
                      onTap: () => _openWhatsApp(lead.phone),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: WhatsAppBubbleIcon(size: 24),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Standalone Enlarged Call Icon
                    InkWell(
                      onTap: () => _makePhoneCall(lead.phone),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: CallActionIcon(size: 24),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Followup Button
                    InkWell(
                      onTap: () => _scheduleFollowup(lead),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.event_note_rounded, size: 22, color: Color(0xFFD97706)),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // More Menu
                    PopupMenuButton<String>(
                      color: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      elevation: 6,
                      onSelected: (val) {
                        if (val == 'details') {
                          _onSelectLead(lead);
                        } else if (val == 'edit') {
                          _showAddEditLeadModal(context, existingLead: lead);
                        } else if (val == 'address') {
                          _showAddressDialog(lead);
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
                        const PopupMenuItem(
                          value: 'details',
                          child: Text(
                            'View Details',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text(
                            'Edit Lead',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'address',
                          child: Text(
                            'Delivery Address',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Text(
                            'Share Lead',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete Lead',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.more_vert_rounded, size: 22, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Desktop Table View (Wrapped in Horizontal Scroll to Eliminate Overflow) ---
  Widget _buildDesktopTable() {
    final start = (_currentPage - 1) * _pageSize;
    final leadsToShow = _filteredLeads.skip(start).take(_pageSize).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth = math.max(constraints.maxWidth, 680.0);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: minWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 26,
                        child: Text(
                          'Name',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 17,
                        child: Text(
                          'Phone',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 13,
                        child: Text(
                          'Source',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 13,
                        child: Text(
                          'Stage',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 14,
                        child: Text(
                          'Last Interaction',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 17,
                        child: Text(
                          'Actions',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table Rows
                ...leadsToShow.map((lead) {
                  final isSelected = _selectedLead?.id == lead.id;
                  return _buildTableRow(lead, isSelected);
                }),
              ],
            ),
          ),
        );
      },
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F5F9) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF8FAFC), width: 1)),
        ),
        child: Row(
          children: [
            // 1. Name & Regular Customer Subtitle
            Expanded(
              flex: 26,
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: avatarColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 12.5,
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            if (lead.isRegularCustomer) ...[
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: primaryNavy.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Regular',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: primaryNavy,
                                  ),
                                ),
                              ),
                            ],
                            Flexible(
                              child: Text(
                                lead.displayCustomerType,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: lead.isRegularCustomer ? FontWeight.w700 : FontWeight.w500,
                                  color: lead.isRegularCustomer ? primaryNavy : textSubtle,
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

            // 2. Phone
            Expanded(
              flex: 17,
              child: Text(
                lead.phone,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ),

            // 3. Source Badge
            Expanded(
              flex: 13,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: _getSourceBgColor(lead.source),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    lead.source,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _getSourceTextColor(lead.source),
                    ),
                  ),
                ),
              ),
            ),

            // 4. Stage Badge
            Expanded(
              flex: 13,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: _getStageBgColor(lead.stage),
                    borderRadius: BorderRadius.circular(8),
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
              ),
            ),

            // 5. Last Interaction Date & Time
            Expanded(
              flex: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    interactionDate,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  Text(
                    interactionTime,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),

            // 6. Action Buttons (Standalone Enlarged WhatsApp, Green Call, More Menu) - No Outer Circles!
            Expanded(
              flex: 17,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // WhatsApp Standalone Enlarged Icon
                  InkWell(
                    onTap: () => _openWhatsApp(lead.phone),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: WhatsAppBubbleIcon(size: 24),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Phone Call Standalone Enlarged Icon
                  InkWell(
                    onTap: () => _makePhoneCall(lead.phone),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: CallActionIcon(size: 24),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // More Context Menu
                  PopupMenuButton<String>(
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 6,
                    onSelected: (val) {
                      if (val == 'details') {
                        _onSelectLead(lead);
                      } else if (val == 'edit') {
                        _showAddEditLeadModal(context, existingLead: lead);
                      } else if (val == 'address') {
                        _showAddressDialog(lead);
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
                      const PopupMenuItem(
                        value: 'details',
                        child: Text(
                          'View Details',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text(
                          'Edit Lead',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'address',
                        child: Text(
                          'Delivery Address',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: Text(
                          'Share Lead',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete Lead',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.more_vert_rounded, size: 20, color: Color(0xFF64748B)),
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

  // --- Dynamic Pagination Bar (Hidden if 0 leads, Shows 1 if 1 page, Counts if 2-4+ pages) ---
  Widget _buildPaginationBar({required bool isMobile}) {
    if (_filteredLeads.isEmpty) return const SizedBox.shrink();

    final startIdx = (_currentPage - 1) * _pageSize + 1;
    final endIdx = math.min(_currentPage * _pageSize, _totalCount);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Showing $startIdx-$endIdx of $_totalCount',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textSubtle,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Prev Button
                InkWell(
                  onTap: _currentPage > 1
                      ? () {
                          setState(() {
                            _currentPage--;
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: boxBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chevron_left_rounded,
                          size: 16,
                          color: _currentPage > 1 ? primaryNavy : const Color(0xFFCBD5E1),
                        ),
                        Text(
                          'Prev',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _currentPage > 1 ? primaryNavy : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Page $_currentPage of $_totalPages',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                ),

                // Next Button
                InkWell(
                  onTap: _currentPage < _totalPages
                      ? () {
                          setState(() {
                            _currentPage++;
                          });
                        }
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: boxBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _currentPage < _totalPages ? primaryNavy : const Color(0xFFCBD5E1),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: _currentPage < _totalPages ? primaryNavy : const Color(0xFFCBD5E1),
                        ),
                      ],
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
              color: textSubtle,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prev Button
              InkWell(
                onTap: _currentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: boxBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 16,
                        color: _currentPage > 1 ? primaryNavy : const Color(0xFFCBD5E1),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Prev',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _currentPage > 1 ? primaryNavy : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Dynamic Page Number Pills (1 if 1 page, 2-4+ if multiple pages)
              ...List.generate(_totalPages, (i) {
                final p = i + 1;
                final isActive = _currentPage == p;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _currentPage = p;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isActive ? primaryNavy : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive ? primaryNavy : boxBorder,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$p',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                          color: isActive ? Colors.white : textDark,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Next Button
              const SizedBox(width: 6),
              InkWell(
                onTap: _currentPage < _totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: boxBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _currentPage < _totalPages ? primaryNavy : const Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: _currentPage < _totalPages ? primaryNavy : const Color(0xFFCBD5E1),
                      ),
                    ],
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
            style: TextStyle(fontSize: 12.5, color: textSubtle),
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
          // Top Row: Avatar, Name & Regular Customer Subtitle, Stage Pill
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
                        color: textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        if (lead.isRegularCustomer) ...[
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                            decoration: BoxDecoration(
                              color: primaryNavy.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Regular',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: primaryNavy,
                              ),
                            ),
                          ),
                        ],
                        Flexible(
                          child: Text(
                            '${lead.displayCustomerType} • ${lead.source}',
                            style: TextStyle(
                              fontSize: isMobile ? 10.5 : 11.5,
                              fontWeight: FontWeight.w500,
                              color: lead.isRegularCustomer ? primaryNavy : textSubtle,
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
                        color: isActive ? primaryNavy : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 11.5,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                          color: isActive ? Colors.white : textSubtle,
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

          // Bottom Action Buttons
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
          icon: const Icon(Icons.call_outlined, size: 16, color: textDark),
          text: lead.phone,
          isLink: false,
          fontSize: isMobile ? 11.5 : 12.5,
          onTap: () => _makePhoneCall(lead.phone),
          trailing: InkWell(
            onTap: () => _copyToClipboard(lead.phone, 'Phone number'),
            child: const Icon(Icons.content_copy_rounded, size: 14, color: textSubtle),
          ),
        ),

        const SizedBox(height: 8),

        _buildInfoItem(
          icon: const WhatsAppBubbleIcon(size: 16),
          text: 'Chat on WhatsApp',
          isLink: true,
          fontSize: isMobile ? 11.5 : 12.5,
          textColor: textDark,
          onTap: () => _openWhatsApp(lead.phone),
        ),

        const SizedBox(height: 8),

        _buildInfoItem(
          icon: const Icon(Icons.email_outlined, size: 16, color: Color(0xFF2563EB)),
          text: lead.email.isNotEmpty ? lead.email : 'No email provided',
          isLink: lead.email.isNotEmpty,
          fontSize: isMobile ? 11.5 : 12.5,
          textColor: lead.email.isNotEmpty ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
          trailing: lead.email.isNotEmpty
              ? InkWell(
                  onTap: () => _copyToClipboard(lead.email, 'Email'),
                  child: const Icon(Icons.content_copy_rounded, size: 14, color: textSubtle),
                )
              : null,
        ),

        const SizedBox(height: 8),

        // Delivery Address Row with Location Icon & Edit / + Add Address button
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.location_on_outlined, size: 16, color: textDark),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lead.address.isNotEmpty ? lead.address : 'No delivery address provided',
                style: TextStyle(
                  fontSize: isMobile ? 11.5 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: lead.address.isNotEmpty ? const Color(0xFF334155) : const Color(0xFF94A3B8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _showAddressDialog(lead),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  lead.address.isNotEmpty ? 'Edit' : '+ Add Address',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: primaryNavy,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        _buildInfoItem(
          icon: const Icon(Icons.calendar_today_outlined, size: 15, color: textDark),
          text: 'Added on $formattedAddedDate',
          fontSize: isMobile ? 11 : 12,
        ),

        const SizedBox(height: 12),

        // Quick Stats Strip: Total Spent, Orders, Returns
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: boxBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              // Spent
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Spent', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textSubtle)),
                    const SizedBox(height: 2),
                    Text('₹${lead.totalSpend.toStringAsFixed(0)}', style: TextStyle(fontSize: isMobile ? 12.5 : 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF2563EB))),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
              const SizedBox(width: 10),
              // Orders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Orders', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textSubtle)),
                    const SizedBox(height: 2),
                    Text('${lead.totalOrders}', style: TextStyle(fontSize: isMobile ? 12.5 : 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF16A34A))),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
              const SizedBox(width: 10),
              // Visits
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Visits', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textSubtle)),
                    const SizedBox(height: 2),
                    Text('${lead.visitCount}', style: TextStyle(fontSize: isMobile ? 12.5 : 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF7C3AED))),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Source and Stage Dynamic Change Row with Curved Dropdown Box
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Source',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSubtle,
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
                const Text(
                  'Stage',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textSubtle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: boxBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _allStages.contains(lead.stage) ? lead.stage : _allStages.first,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: Color(0xFF475569)),
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 11.5,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                      items: _allStages.map((st) {
                        return DropdownMenuItem<String>(
                          value: st,
                          child: Text(
                            st,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textDark),
                          ),
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
        color: boxBg,
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
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isMobile ? 10.5 : 11.5,
                    fontWeight: FontWeight.w500,
                    color: textSubtle,
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
        const Text(
          'Add Note',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: textDark,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _noteInputController,
          maxLines: 2,
          style: TextStyle(
            fontSize: isMobile ? 11.5 : 12.5,
            fontWeight: FontWeight.w600,
            color: textDark,
          ),
          decoration: InputDecoration(
            hintText: 'Write a note...',
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: boxBg,
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: boxBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: boxBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: primaryNavy, width: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: _saveNoteForSelectedLead,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 14, vertical: isMobile ? 6 : 7),
              decoration: BoxDecoration(
                color: primaryNavy,
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

        if (lead.notesList.isNotEmpty) ...[
          const Text(
            'Notes History',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
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
                color: boxBg,
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
              color: boxBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              lead.notes,
              style: TextStyle(fontSize: isMobile ? 11 : 11.5, color: const Color(0xFF475569), height: 1.3),
            ),
          ),
        ] else ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No notes added yet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Spent',
                      style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${lead.totalSpend.toStringAsFixed(0)}',
                      style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w800, color: textDark),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Orders',
                      style: TextStyle(fontSize: 10, color: Color(0xFF16A34A), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lead.totalOrders}',
                      style: TextStyle(fontSize: isMobile ? 14 : 16, fontWeight: FontWeight.w800, color: textDark),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Visits',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lead.visitCount}',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (lead.recentOrders.isNotEmpty) ...[
          const Text(
            'Recent Orders',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: textDark),
          ),
          const SizedBox(height: 6),
          ...lead.recentOrders.map((ord) {
            final id = ord is Map ? (ord['id'] ?? ord['_id'] ?? 'Order') : 'Order';
            final amt = ord is Map ? (ord['totalAmount'] ?? ord['amount'] ?? 0) : 0;
            final dateRaw = ord is Map ? ord['date'] : null;
            final dateStr = dateRaw != null
                ? DateFormat('dd MMM yyyy').format(DateTime.tryParse(dateRaw.toString()) ?? DateTime.now())
                : '';
            final statusStr = ord is Map ? (ord['status']?.toString() ?? '') : '';

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: boxBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$id',
                          style: TextStyle(
                            fontSize: isMobile ? 11.5 : 12.5,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                        ),
                        if (dateStr.isNotEmpty || statusStr.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            [dateStr, statusStr].where((s) => s.isNotEmpty).join(' • '),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: textSubtle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '₹$amt',
                    style: TextStyle(
                      fontSize: isMobile ? 12.5 : 13.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            );
          }),
        ] else ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No orders recorded yet.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
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
                    const Text(
                      'Scheduled Date',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
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
          const Center(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No follow-up scheduled yet.',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
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
              foregroundColor: primaryNavy,
              side: const BorderSide(color: primaryNavy),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  // --- Detail Action Buttons ---
  Widget _buildDetailActionButtons(CrmLeadModel lead, {required bool isMobile}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // WhatsApp Button
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
                const WhatsAppBubbleIcon(size: 19),
                const SizedBox(width: 6),
                Text(
                  'WhatsApp',
                  style: TextStyle(
                    fontSize: isMobile ? 11.5 : 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Call Button with Custom Green Call Icon
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
              border: Border.all(color: const Color(0xFF22C55E), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CallActionIcon(size: 19),
                const SizedBox(width: 6),
                Text(
                  'Call',
                  style: TextStyle(
                    fontSize: isMobile ? 11.5 : 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ),

        // More Options
        PopupMenuButton<String>(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 6,
          onSelected: (val) {
            if (val == 'edit') {
              _showAddEditLeadModal(context, existingLead: lead);
            } else if (val == 'address') {
              _showAddressDialog(lead);
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
            const PopupMenuItem(
              value: 'edit',
              child: Text(
                'Edit Customer',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ),
            const PopupMenuItem(
              value: 'address',
              child: Text(
                'Edit Delivery Address',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ),
            const PopupMenuItem(
              value: 'followup',
              child: Text(
                'Schedule Follow-up',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Text(
                'Export CSV',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete Customer',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
              ),
            ),
          ],
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 12,
              vertical: isMobile ? 7 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: boxBorder, width: 1.2),
            ),
            child: const Text(
              '••• More',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
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
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ==========================================================================
  // REDESIGNED ADD/EDIT LEAD MODAL (High-Visibility Text & Responsive Wrapping)
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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Title & Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Customer Lead' : 'Add New Lead',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: textDark),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded, size: 18, color: textSubtle),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Name Input
                _buildModalTextField(
                  controller: nameCtrl,
                  label: 'Customer Name *',
                  hint: 'e.g. Rahul Sharma',
                ),
                const SizedBox(height: 10),

                // Phone Input
                _buildModalTextField(
                  controller: phoneCtrl,
                  label: 'Phone Number *',
                  hint: 'e.g. 9876543210',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),

                // Email Input
                _buildModalTextField(
                  controller: emailCtrl,
                  label: 'Email Address',
                  hint: 'e.g. customer@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),

                // Address Input
                _buildModalTextField(
                  controller: addressCtrl,
                  label: 'Address / City',
                  hint: 'e.g. Sector 62, Noida',
                ),
                const SizedBox(height: 10),

                // Source & Stage Dropdowns (Curved boxes with visible text)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _allSources.contains(sourceCtrl.text) && sourceCtrl.text != 'All Sources'
                            ? sourceCtrl.text
                            : 'Dine In',
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textDark),
                        decoration: InputDecoration(
                          labelText: 'Source',
                          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSubtle),
                          filled: true,
                          fillColor: boxBg,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: boxBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: boxBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryNavy, width: 1.5)),
                        ),
                        items: ['Dine In', 'POS', 'Online', 'WhatsApp', 'Social Media', 'Referral', 'Website']
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDark)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) sourceCtrl.text = val;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _allStages.contains(stageCtrl.text) ? stageCtrl.text : 'New Lead',
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textDark),
                        decoration: InputDecoration(
                          labelText: 'Stage',
                          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSubtle),
                          filled: true,
                          fillColor: boxBg,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: boxBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: boxBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryNavy, width: 1.5)),
                        ),
                        items: _allStages
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textDark)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) stageCtrl.text = val;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Customer Type Input
                _buildModalTextField(
                  controller: typeCtrl,
                  label: 'Customer Type',
                  hint: 'e.g. New Customer, Regular Customer, Walk-in',
                ),
                const SizedBox(height: 10),

                // Notes Input
                _buildModalTextField(
                  controller: notesCtrl,
                  label: 'Notes / Preferences',
                  hint: 'e.g. Prefers window table, vegetarian meals',
                  maxLines: 2,
                ),

                const SizedBox(height: 18),

                // Dialog Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: boxBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: textSubtle, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                      child: Text(
                        isEditing ? 'Update Customer' : 'Add Lead',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModalTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSubtle),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: boxBg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: boxBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: boxBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryNavy, width: 1.5),
        ),
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
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: textDark),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste comma-separated leads (Name, Phone, Source, Stage):',
                style: TextStyle(fontSize: 12, color: textSubtle),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textCtrl,
                maxLines: 4,
                style: const TextStyle(fontSize: 12.5, color: textDark),
                decoration: InputDecoration(
                  hintText: 'Aarav Kumar, 9876543211, Dine In, New Lead\nSimran Kaur, 9811223344, Online, Prospect',
                  hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: boxBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: boxBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: boxBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primaryNavy, width: 1.5)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: boxBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel', style: TextStyle(color: textSubtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete ${lead.name}?', style: const TextStyle(fontWeight: FontWeight.w800, color: textDark)),
        content: const Text('Are you sure you want to delete this customer lead? This action cannot be undone.', style: TextStyle(fontSize: 12.5, color: textSubtle)),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: boxBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel', style: TextStyle(color: textSubtle)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
  final String stageTab;
  final Color iconBgColor;
  final Color iconColor;
  final Widget iconWidget;
  final Color waveColor;

  _MetricCardData({
    required this.title,
    required this.value,
    required this.stageTab,
    required this.iconBgColor,
    required this.iconColor,
    required this.iconWidget,
    required this.waveColor,
  });
}

// ============================================================================
// CUSTOM PAINTER FOR SMOOTH SPARKLINE BEZIER WAVES & GRAPHICS
// ============================================================================
class SparklineWavePainter extends CustomPainter {
  final Color color;
  final bool isSelected;

  SparklineWavePainter({required this.color, this.isSelected = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path();
    path.moveTo(0, h * 0.78);
    path.cubicTo(
      w * 0.22,
      h * 0.90,
      w * 0.38,
      h * 0.22,
      w * 0.58,
      h * 0.50,
    );
    path.cubicTo(
      w * 0.72,
      h * 0.72,
      w * 0.86,
      h * 0.12,
      w,
      h * 0.25,
    );

    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: isSelected ? 0.38 : 0.22),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = isSelected ? color : color.withValues(alpha: 0.85)
      ..strokeWidth = isSelected ? 2.6 : 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    // Peak decorative glowing dot
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w, h * 0.25), 3.0, dotPaint);

    final innerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w, h * 0.25), 1.5, innerDotPaint);
  }

  @override
  bool shouldRepaint(covariant SparklineWavePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isSelected != isSelected;
}

// ============================================================================
// CUSTOM CROWN ICON (Golden Crown with Blue Gem matching image)
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
    final goldPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.75);
    path.lineTo(size.width * 0.15, size.height * 0.35);
    path.lineTo(size.width * 0.35, size.height * 0.55);
    path.lineTo(size.width * 0.5, size.height * 0.25);
    path.lineTo(size.width * 0.65, size.height * 0.55);
    path.lineTo(size.width * 0.85, size.height * 0.35);
    path.lineTo(size.width * 0.85, size.height * 0.75);
    path.close();

    canvas.drawPath(path, goldPaint);

    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.12, size.height * 0.8, size.width * 0.76, size.height * 0.08),
      const Radius.circular(2),
    );
    canvas.drawRRect(baseRect, goldPaint);

    // 3 small top balls
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.32), size.width * 0.045, goldPaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.22), size.width * 0.05, goldPaint);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.32), size.width * 0.045, goldPaint);

    // Blue jewel in center of crown matching reference
    final gemPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.6), size.width * 0.06, gemPaint);
  }

  @override
  bool shouldRepaint(covariant _CrownPainter oldDelegate) => oldDelegate.color != color;
}

// ============================================================================
// CUSTOM WHATSAPP BUBBLE ICON WITH LOGO ASSET & HIGH-RES FALLBACK
// ============================================================================
class WhatsAppBubbleIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const WhatsAppBubbleIcon({super.key, required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size * 1.25;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Image.asset(
          'assets/images/whatsapp_logo.png',
          width: effectiveSize,
          height: effectiveSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.chat_rounded,
              size: size,
              color: color ?? const Color(0xFF22C55E),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOM CALL ACTION ICON (Using User Provided Green Phone Icon)
// ============================================================================
class CallActionIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const CallActionIcon({super.key, required this.size, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/call_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.call_rounded,
          size: size,
          color: color ?? const Color(0xFF22C55E),
        );
      },
    );
  }
}
