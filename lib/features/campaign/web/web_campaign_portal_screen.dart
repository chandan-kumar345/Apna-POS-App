import 'package:flutter/material.dart';
import '../models/campaign_models.dart';
import 'views/campaign_dashboard_view.dart';
import 'views/create_campaign_wizard_view.dart';
import 'views/create_auto_campaign_view.dart';
import 'views/campaign_details_monitoring_view.dart';
import 'views/audience_groups_view.dart';
import 'views/use_template_dispatch_view.dart';
import 'views/web_customers_view.dart';

class WebCampaignPortalScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final int initialTabIndex;

  const WebCampaignPortalScreen({
    super.key,
    this.onBack,
    this.initialTabIndex = 0,
  });

  @override
  State<WebCampaignPortalScreen> createState() =>
      _WebCampaignPortalScreenState();
}

class _WebCampaignPortalScreenState extends State<WebCampaignPortalScreen> {
  late String _currentView; // 'dashboard', 'create', 'create_auto', 'details', 'groups', 'customers', 'dispatch'
  CampaignModel? _selectedCampaign;
  CampaignModel? _selectedCampaignForEdit;
  CampaignTemplateModel? _selectedTemplateForCreate;
  CampaignTemplateModel? _selectedTemplateForDispatch;

  @override
  void initState() {
    super.initState();
    _currentView = widget.initialTabIndex == 1 ? 'groups' : 'dashboard';
  }

  void _navigateToDashboard() {
    setState(() {
      _currentView = 'dashboard';
      _selectedCampaign = null;
      _selectedCampaignForEdit = null;
      _selectedTemplateForCreate = null;
      _selectedTemplateForDispatch = null;
    });
  }

  void _navigateToCreate({CampaignModel? campaign, CampaignTemplateModel? template}) {
    setState(() {
      _currentView = 'create';
      _selectedCampaign = null;
      _selectedCampaignForEdit = campaign;
      _selectedTemplateForCreate = template;
      _selectedTemplateForDispatch = null;
    });
  }

  void _navigateToDispatch(CampaignTemplateModel template) {
    setState(() {
      _currentView = 'dispatch';
      _selectedCampaign = null;
      _selectedCampaignForEdit = null;
      _selectedTemplateForDispatch = template;
    });
  }

  void _navigateToGroups() {
    setState(() {
      _currentView = 'groups';
      _selectedCampaign = null;
      _selectedCampaignForEdit = null;
    });
  }

  void _navigateToCustomers() {
    setState(() {
      _currentView = 'customers';
      _selectedCampaign = null;
      _selectedCampaignForEdit = null;
    });
  }

  void _navigateToCreateAuto() {
    setState(() {
      _currentView = 'create_auto';
      _selectedCampaign = null;
      _selectedCampaignForEdit = null;
    });
  }

  void _navigateToDetails(CampaignModel campaign) {
    setState(() {
      _selectedCampaign = campaign;
      _currentView = 'details';
    });
  }

  void _handleSelectCampaignFromDashboard(CampaignModel campaign) {
    final status = campaign.status.toLowerCase();
    if (status == 'draft' || (status == 'approved' && campaign.stats.messagesSent == 0)) {
      _navigateToCreate(campaign: campaign);
    } else {
      _navigateToDetails(campaign);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget currentWidget;
    switch (_currentView) {
      case 'dispatch':
        if (_selectedTemplateForDispatch != null) {
          currentWidget = UseTemplateDispatchView(
            template: _selectedTemplateForDispatch!,
            onBack: _navigateToDashboard,
            onCampaignSent: (campaign) => _navigateToDetails(campaign),
          );
        } else {
          currentWidget = CampaignDashboardView(
            onCreateCampaign: () => _navigateToCreate(),
            onUseTemplate: _navigateToDispatch,
            onCreateGroup: _navigateToGroups,
            onViewCustomers: _navigateToCustomers,
            onCreateAutoCampaign: _navigateToCreateAuto,
            onSelectCampaign: _handleSelectCampaignFromDashboard,
          );
        }
        break;
      case 'groups':
        currentWidget = AudienceGroupsView(
          onBack: _navigateToDashboard,
          onViewCustomers: _navigateToCustomers,
        );
        break;
      case 'customers':
        currentWidget = WebCustomersView(
          onBack: _navigateToDashboard,
          onNavigateToGroups: _navigateToGroups,
        );
        break;
      case 'create':
        currentWidget = CreateCampaignWizardView(
          initialTemplate: _selectedTemplateForCreate,
          existingCampaign: _selectedCampaignForEdit,
          onCancel: _navigateToDashboard,
          onCampaignCreated: (campaign) => _navigateToDetails(campaign),
        );
        break;
      case 'create_auto':
        currentWidget = CreateAutoCampaignView(
          onCancel: _navigateToDashboard,
          onActivated: _navigateToDashboard,
        );
        break;
      case 'details':
        if (_selectedCampaign != null) {
          currentWidget = CampaignDetailsMonitoringView(
            campaign: _selectedCampaign!,
            onBack: _navigateToDashboard,
            onEditCampaign: (campaign) => _navigateToCreate(campaign: campaign),
            onFollowUpCampaign: (campaign) => _navigateToCreate(
              campaign: campaign.copyWith(
                id: '',
                name: 'Follow-up: ${campaign.name}',
              ),
            ),
          );
        } else {
          currentWidget = CampaignDashboardView(
            onCreateCampaign: () => _navigateToCreate(),
            onUseTemplate: _navigateToDispatch,
            onCreateGroup: _navigateToGroups,
            onViewCustomers: _navigateToCustomers,
            onCreateAutoCampaign: _navigateToCreateAuto,
            onSelectCampaign: _handleSelectCampaignFromDashboard,
          );
        }
        break;
      case 'dashboard':
      default:
        currentWidget = CampaignDashboardView(
          onCreateCampaign: () => _navigateToCreate(),
          onUseTemplate: _navigateToDispatch,
          onCreateGroup: _navigateToGroups,
          onViewCustomers: _navigateToCustomers,
          onCreateAutoCampaign: _navigateToCreateAuto,
          onSelectCampaign: _handleSelectCampaignFromDashboard,
        );
        break;
    }

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7047D6),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F2FC),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F2FC),
        appBar: _currentView == 'dashboard'
            ? AppBar(
                backgroundColor: const Color(0xFFF3F2FC),
                foregroundColor: const Color(0xFF132B4C),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  tooltip: 'Back',
                  onPressed: widget.onBack ?? () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                title: const Text(
                  'Campaign studio',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              )
            : null,
        body: SafeArea(child: currentWidget),
      ),
    );
  }
}
