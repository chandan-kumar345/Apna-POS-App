import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/crm_model.dart';
import '../../../core/services/crm_service.dart';
import '../../../core/database/database_service.dart';

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

class _CrmLeadsScreenState extends State<CrmLeadsScreen> with SingleTickerProviderStateMixin {
  final CrmService _crmService = CrmService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // State
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  String _selectedStageTab = 'All';
  String _activeQuickAction = 'All Leads';
  bool _isSearchVisible = false;
  bool _isSpeedDialOpen = false;

  List<CrmLeadModel> _leads = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  CrmStatsModel _stats = CrmStatsModel();

  final List<String> _stageTabs = [
    'All',
    'Leads',
    'Prospects',
    'Deals',
    'Wins',
    'Lost',
  ];

  late AnimationController _speedDialAnimController;
  late Animation<double> _speedDialAnim;

  @override
  void initState() {
    super.initState();
    _speedDialAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _speedDialAnim = CurvedAnimation(
      parent: _speedDialAnimController,
      curve: Curves.easeOut,
    );

    _scrollController.addListener(_onScroll);
    _loadLeads(reset: true);
  }

  @override
  void dispose() {
    _speedDialAnimController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _currentPage < _totalPages) {
        _loadLeads(reset: false);
      }
    }
  }

  Future<void> _loadLeads({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
        _leads = [];
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    final pageToFetch = reset ? 1 : _currentPage + 1;
    final stageParam = _selectedStageTab == 'All' ? null : _selectedStageTab;
    final searchParam = _searchController.text.trim().isEmpty ? null : _searchController.text.trim();

    try {
      final result = await _crmService.fetchLeads(
        page: pageToFetch,
        limit: 20,
        stage: stageParam,
        search: searchParam,
      );

      if (mounted) {
        if (result != null) {
          setState(() {
            if (reset) {
              _leads = result.leads;
            } else {
              _leads.addAll(result.leads);
            }
            _currentPage = result.page;
            _totalPages = result.totalPages;
            _totalCount = result.totalCount;
            _stats = result.stats;
            _isLoading = false;
            _isLoadingMore = false;
            _errorMessage = null;
          });
        } else {
          // If offline, populate from local DatabaseService customers
          final db = DatabaseService();
          final localCustomers = db.customers;
          final localLeads = localCustomers.map((c) {
            DateTime? parsedLastVisit;
            if (c.lastVisit != null && c.lastVisit!.isNotEmpty) {
              try {
                parsedLastVisit = DateTime.parse(c.lastVisit!);
              } catch (_) {}
            }
            return CrmLeadModel(
              id: c.phone,
              name: c.name.isNotEmpty ? c.name : 'Guest Customer',
              phone: c.phone,
              email: c.email,
              address: c.address,
              source: 'Dine In',
              stage: 'New Lead',
              status: 'New Lead',
              tags: const ['New Lead'],
              totalOrders: c.totalOrders,
              totalSpent: c.totalSpent,
              createdAt: parsedLastVisit ?? DateTime.now(),
              lastVisit: parsedLastVisit,
            );
          }).toList();

          setState(() {
            _leads = localLeads;
            _totalCount = localLeads.length;
            _stats = CrmStatsModel(total: localLeads.length, leads: localLeads.length);
            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Failed to load leads. Please check connection.';
        });
      }
    }
  }

  void _toggleSpeedDial() {
    setState(() {
      _isSpeedDialOpen = !_isSpeedDialOpen;
      if (_isSpeedDialOpen) {
        _speedDialAnimController.forward();
      } else {
        _speedDialAnimController.reverse();
      }
    });
  }

  void _closeSpeedDial() {
    if (_isSpeedDialOpen) {
      setState(() {
        _isSpeedDialOpen = false;
        _speedDialAnimController.reverse();
      });
    }
  }

  // Quick Action Handler
  void _onQuickActionTap(String action) {
    setState(() {
      _activeQuickAction = action;
    });

    if (action == 'Dashboard') {
      if (widget.onNavigateToDashboard != null) {
        widget.onNavigateToDashboard!();
      }
    } else if (action == 'All Leads') {
      _selectedStageTab = 'All';
      _loadLeads(reset: true);
    } else if (action == 'Add New Lead') {
      _showAddEditLeadModal(context);
    } else if (action == 'View Followup' || action == 'Schedule') {
      _showFollowupScheduleModal(context);
    }
  }

  // Stage Tab Selection Handler
  void _onStageTabSelected(String tab) {
    if (_selectedStageTab != tab) {
      setState(() {
        _selectedStageTab = tab;
      });
      _loadLeads(reset: true);
    }
  }

  // Direct Communication Helpers
  // Direct Communication Helpers
  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Could not launch phone dialer for $phone');
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    String cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      _showSnackBar('Phone number is empty or invalid', isError: true);
      return;
    }
    // Prefix 91 for Indian 10-digit phone numbers
    if (cleanDigits.length == 10) {
      cleanDigits = '91$cleanDigits';
    } else if (cleanDigits.length == 11 && cleanDigits.startsWith('0')) {
      cleanDigits = '91${cleanDigits.substring(1)}';
    }

    final nativeWhatsappUri = Uri.parse('whatsapp://send?phone=$cleanDigits');
    final webWhatsappUri = Uri.parse('https://wa.me/$cleanDigits');
    final apiWhatsappUri = Uri.parse('https://api.whatsapp.com/send?phone=$cleanDigits');

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

    try {
      await launchUrl(apiWhatsappUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _showSnackBar('Could not open WhatsApp for $phone', isError: true);
    }
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
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF082559),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: GestureDetector(
          onTap: _closeSpeedDial,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Stack(
                children: [
                  Column(
                    children: [
                      // 1. Top CRM Header with Animated Inline Search
                      _buildHeader(context),

                      // 2. Quick Action Cards (Horizontally Scrollable)
                      _buildQuickActionsRow(),

                      // 3. Lead Count & Sub-actions Bar (Tag, Stage, Like on Left; Count on Right)
                      _buildLeadCountBar(),

                      // 4. Stage Filter Tabs
                      _buildStageTabs(),

                      const Divider(height: 1, color: Color(0xFFE2E8F0)),

                      // 5. Leads Content List
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => _loadLeads(reset: true),
                          color: const Color(0xFF082559),
                          child: _buildLeadsContent(isMobile),
                        ),
                      ),
                    ],
                  ),

                  // 6. Floating Speed-Dial Actions (Add Lead, Export, Upload, Template)
                  _buildSpeedDialFab(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // HEADER WITH ALWAYS-VISIBLE CRM TITLE, INLINE SEARCH FIELD & CIRCULAR BUTTON
  // --------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          // CRM Title - Always Visible
          const Text(
            'CRM',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(width: 8),

          // Expanding Search Field beside CRM Title and Search Button
          Expanded(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.centerRight,
              child: _isSearchVisible
                  ? Container(
                      margin: const EdgeInsets.only(right: 8),
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF082559), width: 1.2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _loadLeads(reset: true),
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Search leads...',
                          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF082559)),
                          prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    _searchController.clear();
                                    _loadLeads(reset: true);
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),

          if (!_isSearchVisible) const Spacer(),

          // Circular Search Button with Transition Effect
          InkWell(
            onTap: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchController.clear();
                  _loadLeads(reset: true);
                }
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSearchVisible ? const Color(0xFF082559) : Colors.white,
                border: Border.all(
                  color: _isSearchVisible ? const Color(0xFF082559) : const Color(0xFFCBD5E1),
                  width: 1.1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: AnimatedRotation(
                turns: _isSearchVisible ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 240),
                child: Icon(
                  _isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
                  color: _isSearchVisible ? Colors.white : const Color(0xFF0F172A),
                  size: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TOP QUICK ACTION CARDS (Horizontal Scroll)
  // --------------------------------------------------------------------------
  Widget _buildQuickActionsRow() {
    final actions = [
      {'label': 'Dashboard', 'icon': Icons.speed_rounded},
      {'label': 'All Leads', 'icon': Icons.people_alt_rounded},
      {'label': 'Add New Lead', 'icon': Icons.person_add_alt_1_rounded},
      {'label': 'View Followup', 'icon': Icons.event_available_rounded},
      {'label': 'Schedule', 'icon': Icons.calendar_month_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: actions.map((item) {
            final label = item['label'] as String;
            final icon = item['icon'] as IconData;
            final isActive = _activeQuickAction == label;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () => _onQuickActionTap(label),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF082559) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive ? const Color(0xFF082559) : const Color(0xFFCBD5E1),
                      width: 1.1,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: const Color(0xFF082559).withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : const [
                            BoxShadow(
                              color: Color(0x04000000),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 19,
                        color: isActive ? Colors.white : const Color(0xFF0F172A),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isActive ? FontWeight.w900 : FontWeight.w800,
                          color: isActive ? Colors.white : const Color(0xFF0F172A),
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
    );
  }

  // --------------------------------------------------------------------------
  // LEAD COUNT & QUICK ACTIONS BAR (Tag, Stage, Like on Left; Count on Right)
  // --------------------------------------------------------------------------
  Widget _buildLeadCountBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          _buildPillAction('Tag', Icons.label_outline_rounded, () {
            _showTagActionSheet();
          }),
          const SizedBox(width: 5),
          _buildPillAction('Stage', Icons.alt_route_rounded, () {
            _showStageActionSheet();
          }),
          const SizedBox(width: 5),
          _buildPillAction('Like', Icons.thumb_up_alt_outlined, () {
            _showLikeActionSheet();
          }),
          const Spacer(),
          Text(
            '${_leads.length}/$_totalCount Leads',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillAction(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF082559),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10.5, color: Colors.white),
            const SizedBox(width: 3.5),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // STAGE FILTER TABS (All, Leads, Prospects, Deals, Wins, Lost)
  // --------------------------------------------------------------------------
  Widget _buildStageTabs() {
    return Container(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: _stageTabs.map((tab) {
            final isSelected = _selectedStageTab == tab;

            int badgeCount = 0;
            switch (tab) {
              case 'All':
                badgeCount = _stats.total;
                break;
              case 'Leads':
                badgeCount = _stats.leads;
                break;
              case 'Prospects':
                badgeCount = _stats.prospects;
                break;
              case 'Deals':
                badgeCount = _stats.deals;
                break;
              case 'Wins':
                badgeCount = _stats.wins;
                break;
              case 'Lost':
                badgeCount = _stats.lost;
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: InkWell(
                onTap: () => _onStageTabSelected(tab),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF082559) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF082559),
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tab,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                          color: isSelected ? Colors.white : const Color(0xFF082559),
                        ),
                      ),
                      if (badgeCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.3)
                                : const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$badgeCount',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? Colors.white : const Color(0xFF082559),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // LEADS CONTENT
  // --------------------------------------------------------------------------
  Widget _buildLeadsContent(bool isMobile) {
    if (_isLoading) {
      return _buildLoadingShimmer();
    }

    if (_errorMessage != null && _leads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadLeads(reset: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF082559),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_leads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2FE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_outline_rounded, color: Color(0xFF082559), size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'No leads in $_selectedStageTab',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tap "+ Add Lead" to capture new customer inquiries and start following up.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _showAddEditLeadModal(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Lead Now', style: TextStyle(fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF082559),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
      itemCount: _leads.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _leads.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF082559)),
              ),
            ),
          );
        }

        final lead = _leads[index];
        return _buildLeadCard(lead);
      },
    );
  }

  // --------------------------------------------------------------------------
  // INDIVIDUAL LEAD CARD (Compact, Sleek, High-Contrast)
  // --------------------------------------------------------------------------
  Widget _buildLeadCard(CrmLeadModel lead) {
    final dateFormat = DateFormat('MMM d, yyyy, h:mm:ss a');
    final formattedDate = dateFormat.format(lead.createdAt);

    // Initial character
    final initial = lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'G';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
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
          // Row 1: Avatar, Name, Timestamp, WhatsApp Icon (3-dot removed)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 4),
            child: Row(
              children: [
                // Avatar circle
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFF082559),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
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
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _openWhatsApp(lead.phone),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(5.5),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2FE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0284C7), size: 15),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Row 2: Action Icons (Share, Tag, Star, Like, Stage Dropdown)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
            child: Row(
              children: [
                // Share
                InkWell(
                  onTap: () => _shareLead(lead),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF082559),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_rounded, size: 10.5, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 5),

                // Tag
                InkWell(
                  onTap: () => _showTagEditModal(lead),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF082559),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.label_outline_rounded, size: 10.5, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 5),

                // Star
                InkWell(
                  onTap: () => _toggleStar(lead),
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(
                    lead.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                    color: lead.isStarred ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 5),

                // Like
                InkWell(
                  onTap: () => _toggleLike(lead),
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(
                    lead.isLiked ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                    color: lead.isLiked ? const Color(0xFF082559) : const Color(0xFF94A3B8),
                    size: 16,
                  ),
                ),

                const Spacer(),

                // Stage Dropdown Pill (High Visibility with White Card & Bold Dark Text)
                PopupMenuButton<String>(
                  initialValue: lead.stage,
                  color: Colors.white,
                  elevation: 6,
                  onSelected: (newStage) => _updateLeadStage(lead, newStage),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  itemBuilder: (context) => [
                    'New Lead',
                    'Prospect',
                    'Deal',
                    'Won',
                    'Lost',
                  ].map((s) {
                    final isSelected = lead.stage == s;
                    return PopupMenuItem<String>(
                      value: s,
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                            size: 14,
                            color: isSelected ? const Color(0xFF082559) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            s,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              color: isSelected ? const Color(0xFF082559) : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF082559), width: 1.1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lead.stage.isNotEmpty ? lead.stage : 'Select Stage',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF082559),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_drop_down_rounded, size: 17, color: Color(0xFF082559)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Row 3: Status / Tags Badges
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Wrap(
              spacing: 4,
              runSpacing: 2,
              children: lead.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 9.5, color: Color(0xFF059669)),
                      const SizedBox(width: 3),
                      Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Row 4: Phone & Source (Compact Single Row)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
            child: Row(
              children: [
                const Text(
                  'Phone: ',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                InkWell(
                  onTap: () => _makePhoneCall(lead.phone),
                  child: Text(
                    lead.phone.isNotEmpty ? lead.phone : 'Not provided',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0284C7),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Source: ',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                Text(
                  lead.source,
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),

          // Follow-up Reminder Banner (if scheduled)
          if (lead.followupDate != null)
            Container(
              margin: const EdgeInsets.fromLTRB(10, 2, 10, 4),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm_rounded, color: Color(0xFFD97706), size: 12),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Follow-up: ${DateFormat('dd MMM yyyy').format(lead.followupDate!)}${lead.followupNotes.isNotEmpty ? ' • ${lead.followupNotes}' : ''}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF78350F)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),

          // Row 5: Action Buttons (Details, Set Followup, Update, WhatsApp, Call)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLeadButton(
                    'Details',
                    const Color(0xFF082559),
                    () => _showLeadDetailsModal(context, lead),
                  ),
                  const SizedBox(width: 4),
                  _buildLeadButton(
                    'Set Followup',
                    const Color(0xFFEA580C),
                    () => _showSetFollowupModal(context, lead),
                  ),
                  const SizedBox(width: 4),
                  _buildLeadButton(
                    'Update',
                    const Color(0xFF0284C7),
                    () => _showAddEditLeadModal(context, existingLead: lead),
                  ),
                  const SizedBox(width: 4),
                  _buildLeadButton(
                    'WhatsApp',
                    const Color(0xFF16A34A),
                    () => _openWhatsApp(lead.phone),
                  ),
                  const SizedBox(width: 4),
                  _buildLeadButton(
                    'Call',
                    const Color(0xFF082559),
                    () => _makePhoneCall(lead.phone),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadButton(String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // FLOATING SPEED-DIAL (Add Lead, Export Excel, Upload CSV, Download Template)
  // --------------------------------------------------------------------------
  Widget _buildSpeedDialFab() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isSpeedDialOpen) ...[
            _buildSpeedDialItem('Add Lead', Icons.person_add_alt_1_rounded, () {
              _closeSpeedDial();
              _showAddEditLeadModal(context);
            }),
            const SizedBox(height: 10),
            _buildSpeedDialItem('Export Excel', Icons.description_rounded, () {
              _closeSpeedDial();
              _exportLeadsToCsv();
            }),
            const SizedBox(height: 10),
            _buildSpeedDialItem('Upload CSV', Icons.file_upload_rounded, () {
              _closeSpeedDial();
              _showUploadCsvModal();
            }),
            const SizedBox(height: 10),
            _buildSpeedDialItem('Download Template', Icons.download_rounded, () {
              _closeSpeedDial();
              _downloadTemplateCsv();
            }),
            const SizedBox(height: 14),
          ],
          FloatingActionButton(
            backgroundColor: const Color(0xFF082559),
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            onPressed: _toggleSpeedDial,
            child: AnimatedRotation(
              turns: _isSpeedDialOpen ? 0.125 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedDialItem(String label, IconData icon, VoidCallback onTap) {
    return ScaleTransition(
      scale: _speedDialAnim,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            elevation: 3,
            shape: const CircleBorder(),
            onPressed: onTap,
            child: Icon(icon, size: 18),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // LEAD ACTIONS / MODALS
  // --------------------------------------------------------------------------
  Future<void> _updateLeadStage(CrmLeadModel lead, String stage) async {
    final success = await _crmService.updateStage(lead.id, stage);
    if (success) {
      _showSnackBar('Stage updated to $stage');
      _loadLeads(reset: true);
    } else {
      _showSnackBar('Failed to update stage', isError: true);
    }
  }

  Future<void> _toggleLike(CrmLeadModel lead) async {
    final success = await _crmService.toggleLike(lead.id);
    if (success) {
      setState(() {
        final index = _leads.indexWhere((l) => l.id == lead.id);
        if (index != -1) {
          _leads[index] = lead.copyWith(isLiked: !lead.isLiked);
        }
      });
    }
  }

  Future<void> _toggleStar(CrmLeadModel lead) async {
    final success = await _crmService.toggleStar(lead.id);
    if (success) {
      setState(() {
        final index = _leads.indexWhere((l) => l.id == lead.id);
        if (index != -1) {
          _leads[index] = lead.copyWith(isStarred: !lead.isStarred);
        }
      });
    }
  }

  void _shareLead(CrmLeadModel lead) {
    final text = 'Customer Lead: ${lead.name}\nPhone: ${lead.phone}\nStage: ${lead.stage}\nSource: ${lead.source}';
    Share.share(text, subject: 'Apna POS Lead: ${lead.name}');
  }

  List<String> get _dynamicSources {
    final defaultSources = <String>[
      'Dine In',
      'Take Away',
      'Delivery',
      'Online',
      'WhatsApp',
      'Social Media',
      'Walk In',
      'Referral',
      'Phone Inquiry',
    ];
    final set = <String>{...defaultSources};
    for (final lead in _leads) {
      if (lead.source.trim().isNotEmpty) {
        set.add(lead.source.trim());
      }
    }
    return set.toList();
  }

  // --------------------------------------------------------------------------
  // ADD / EDIT LEAD MODAL SHEET
  // --------------------------------------------------------------------------
  void _showAddEditLeadModal(BuildContext context, {CrmLeadModel? existingLead}) {
    final isEditing = existingLead != null;
    final nameCtrl = TextEditingController(text: existingLead?.name ?? '');
    final phoneCtrl = TextEditingController(text: existingLead?.phone ?? '');
    final emailCtrl = TextEditingController(text: existingLead?.email ?? '');
    final sourceCtrl = TextEditingController(text: existingLead?.source ?? 'Dine In');
    final stageCtrl = TextEditingController(text: existingLead?.stage ?? 'New Lead');
    final tagsCtrl = TextEditingController(text: existingLead?.tags.join(', ') ?? 'New Lead');
    final notesCtrl = TextEditingController(text: existingLead?.notes ?? '');

    final availableSources = _dynamicSources;
    if (!availableSources.contains(sourceCtrl.text)) {
      availableSources.add(sourceCtrl.text);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Update Lead' : 'Add New Customer Lead',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Name
                    _buildPillTextField(
                      controller: nameCtrl,
                      label: 'Customer / Business Name *',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 10),

                    // Phone
                    _buildPillTextField(
                      controller: phoneCtrl,
                      label: 'Phone Number *',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),

                    // Email
                    _buildPillTextField(
                      controller: emailCtrl,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 10),

                    // Source & Stage Dropdowns (Dynamic Sources)
                    Row(
                      children: [
                        Expanded(
                          child: _buildPillDropdown(
                            value: sourceCtrl.text,
                            items: availableSources,
                            label: 'Source',
                            onChanged: (val) {
                              if (val != null) setModalState(() => sourceCtrl.text = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildPillDropdown(
                            value: stageCtrl.text,
                            items: ['New Lead', 'Prospect', 'Deal', 'Won', 'Lost'],
                            label: 'Stage',
                            onChanged: (val) {
                              if (val != null) setModalState(() => stageCtrl.text = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Tags
                    _buildPillTextField(
                      controller: tagsCtrl,
                      label: 'Tags (comma-separated)',
                      icon: Icons.label_outline_rounded,
                    ),
                    const SizedBox(height: 10),

                    // Notes
                    _buildPillTextField(
                      controller: notesCtrl,
                      label: 'Notes / Preferences',
                      icon: Icons.notes_rounded,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 18),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF082559),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: () async {
                          final phone = phoneCtrl.text.trim();
                          final name = nameCtrl.text.trim();
                          if (phone.isEmpty) {
                            _showSnackBar('Please enter a phone number', isError: true);
                            return;
                          }

                          final parsedTags = tagsCtrl.text
                              .split(',')
                              .map((t) => t.trim())
                              .where((t) => t.isNotEmpty)
                              .toList();

                          final leadData = {
                            'name': name.isNotEmpty ? name : 'Guest Customer',
                            'phone': phone,
                            'email': emailCtrl.text.trim(),
                            'source': sourceCtrl.text,
                            'stage': stageCtrl.text,
                            'status': stageCtrl.text,
                            'tags': parsedTags.isNotEmpty ? parsedTags : [stageCtrl.text],
                            'notes': notesCtrl.text.trim(),
                          };

                          Navigator.pop(ctx);

                          try {
                            if (isEditing) {
                              await _crmService.updateLead(existingLead.id, leadData);
                              _showSnackBar('Lead updated successfully');
                            } else {
                              await _crmService.createLead(leadData);
                              _showSnackBar('Lead added successfully');
                            }
                            _loadLeads(reset: true);
                          } catch (e) {
                            _showSnackBar('Failed to save lead: $e', isError: true);
                          }
                        },
                        child: Text(
                          isEditing ? 'Update Lead' : 'Save Lead',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

  // --------------------------------------------------------------------------
  // SET FOLLOW-UP MODAL SHEET
  // --------------------------------------------------------------------------
  void _showSetFollowupModal(BuildContext context, CrmLeadModel lead) {
    DateTime selectedDate = lead.followupDate ?? DateTime.now().add(const Duration(days: 2));
    final notesCtrl = TextEditingController(text: lead.followupNotes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Schedule Follow-up: ${lead.name}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Date Picker Tile
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF082559)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Follow-up Date: ${DateFormat('dd MMMM yyyy').format(selectedDate)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Follow-up Notes
                  _buildPillTextField(
                    controller: notesCtrl,
                    label: 'Follow-up Notes / Agenda',
                    icon: Icons.edit_note_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 18),

                  // Save Follow-up
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEA580C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final success = await _crmService.setFollowup(
                          lead.id,
                          followupDate: selectedDate,
                          followupNotes: notesCtrl.text.trim(),
                        );
                        if (success) {
                          _showSnackBar('Follow-up scheduled for ${DateFormat('dd MMM').format(selectedDate)}');
                          _loadLeads(reset: true);
                        } else {
                          _showSnackBar('Failed to set follow-up', isError: true);
                        }
                      },
                      child: const Text(
                        'Save Follow-up',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // LEAD DETAILS MODAL SHEET
  // --------------------------------------------------------------------------
  void _showLeadDetailsModal(BuildContext context, CrmLeadModel lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFF082559),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      lead.name.isNotEmpty ? lead.name[0].toUpperCase() : 'G',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lead.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Stage: ${lead.stage} • Source: ${lead.source}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              _buildDetailRow('Phone', lead.phone),
              _buildDetailRow('Email', lead.email.isNotEmpty ? lead.email : 'N/A'),
              _buildDetailRow('Total Orders', '${lead.totalOrders} orders'),
              _buildDetailRow('Total Spent', '₹${lead.totalSpent.toStringAsFixed(0)}'),
              _buildDetailRow('First Contact', DateFormat('dd MMM yyyy, h:mm a').format(lead.createdAt)),
              if (lead.notes.isNotEmpty) _buildDetailRow('Notes', lead.notes),

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openWhatsApp(lead.phone);
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('WhatsApp'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _makePhoneCall(lead.phone);
                      },
                      icon: const Icon(Icons.call_rounded, size: 16),
                      label: const Text('Call Lead'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF082559),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // CSV / EXCEL EXPORT & IMPORT ACTIONS
  // --------------------------------------------------------------------------
  Future<void> _exportLeadsToCsv() async {
    try {
      final exportData = await _crmService.exportLeads();
      if (exportData == null || exportData.isEmpty) {
        _showSnackBar('No leads available to export', isError: true);
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('Sr No,Name,Phone,Email,Source,Stage,Status,Total Orders,Total Spent,Followup Date,Followup Notes,Created At');

      for (final row in exportData) {
        final r = row as Map<String, dynamic>;
        buffer.writeln(
          '${r['srNo']},"${r['name']}","${r['phone']}","${r['email']}","${r['source']}","${r['stage']}","${r['status']}",${r['totalOrders']},${r['totalSpent']},"${r['followupDate']}","${r['followupNotes']}","${r['createdAt']}"',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/crm_leads_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles([XFile(file.path)], text: 'Exported CRM Leads (${exportData.length} records)');
    } catch (e) {
      _showSnackBar('Export failed: $e', isError: true);
    }
  }

  void _downloadTemplateCsv() async {
    try {
      const csvTemplate = 'Name,Phone,Email,Source,Stage,Notes\n'
          'Sanjeev Kumar,919868775091,sanjeev@example.com,Dine In,New Lead,Regular customer\n'
          'Rahul Sharma,919876543210,rahul@example.com,Online,Prospect,Inquired for party order\n';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/crm_leads_template.csv');
      await file.writeAsString(csvTemplate);

      await Share.shareXFiles([XFile(file.path)], text: 'Apna POS CRM Leads CSV Template');
    } catch (e) {
      _showSnackBar('Could not generate template: $e', isError: true);
    }
  }

  void _showUploadCsvModal() {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quick Paste / Import Leads', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste comma-separated leads (Name, Phone, Source, Stage):',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: textCtrl,
              maxLines: 5,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'John Doe, 9876543210, Dine In, New Lead\nJane Smith, 9123456780, Online, Prospect',
                hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF082559), width: 1.5)),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF082559),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              final raw = textCtrl.text.trim();
              if (raw.isEmpty) return;

              final lines = raw.split('\n');
              final leadsToImport = <Map<String, dynamic>>[];

              for (final line in lines) {
                final parts = line.split(',');
                if (parts.length >= 2) {
                  leadsToImport.add({
                    'name': parts[0].trim(),
                    'phone': parts[1].trim(),
                    'source': parts.length > 2 ? parts[2].trim() : 'Dine In',
                    'stage': parts.length > 3 ? parts[3].trim() : 'New Lead',
                  });
                }
              }

              Navigator.pop(ctx);

              if (leadsToImport.isNotEmpty) {
                final count = await _crmService.importLeads(leadsToImport);
                _showSnackBar('Imported $count leads successfully');
                _loadLeads(reset: true);
              }
            },
            child: const Text('Import', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // MISC ACTIONS (Tag sheet, Stage sheet, Context menu, etc.)
  // --------------------------------------------------------------------------
  void _showTagActionSheet() {
    _showSnackBar('Filter by tag: Tap on any lead tag or use search to filter by specific tag.');
  }

  void _showStageActionSheet() {
    _showSnackBar('Filter by stage: Use the stage tabs above to filter Leads, Prospects, Deals, Wins, or Lost.');
  }

  void _showLikeActionSheet() {
    setState(() {
      _leads.sort((a, b) => (b.isLiked ? 1 : 0).compareTo(a.isLiked ? 1 : 0));
    });
    _showSnackBar('Sorted liked leads to the top.');
  }

  void _showTagEditModal(CrmLeadModel lead) {
    final tagsCtrl = TextEditingController(text: lead.tags.join(', '));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Tags: ${lead.name}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter comma-separated tags:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: tagsCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'VIP, Regular, Corporate, etc.',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF082559), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF082559),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              final newTags = tagsCtrl.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
              Navigator.pop(ctx);
              await _crmService.updateLead(lead.id, {'tags': newTags});
              _loadLeads(reset: true);
            },
            child: const Text('Save Tags', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _showFollowupScheduleModal(BuildContext context) {
    final followupLeads = _leads.where((l) => l.followupDate != null).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upcoming Follow-ups',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            if (followupLeads.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No scheduled follow-ups. Tap "Set Followup" on any lead card to schedule.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ),
              )
            else
              for (final lead in followupLeads)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.alarm_rounded, color: Color(0xFFEA580C)),
                  title: Text(lead.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Date: ${DateFormat('dd MMM yyyy').format(lead.followupDate!)}${lead.followupNotes.isNotEmpty ? ' • ${lead.followupNotes}' : ''}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.call_rounded, color: Color(0xFF082559)),
                    onPressed: () => _makePhoneCall(lead.phone),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // FORM FIELD HELPERS WITH SOFT SEMI-CIRCLE (BorderRadius.circular(24))
  // --------------------------------------------------------------------------
  Widget _buildPillTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF082559)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFF082559), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPillDropdown({
    required String value,
    required List<String> items,
    required String label,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      items: items.map((e) => DropdownMenuItem(
        value: e,
        child: Text(
          e,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
        ),
      )).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFF082559), width: 1.5),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // LOADING SHIMMER
  // --------------------------------------------------------------------------
  Widget _buildLoadingShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 120, height: 14, color: const Color(0xFFF1F5F9)),
                      const SizedBox(height: 6),
                      Container(width: 160, height: 10, color: const Color(0xFFF1F5F9)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(width: double.infinity, height: 28, color: const Color(0xFFF8FAFC)),
              const SizedBox(height: 10),
              Container(width: 200, height: 12, color: const Color(0xFFF1F5F9)),
            ],
          ),
        );
      },
    );
  }
}
