import 'package:flutter/material.dart';
import '../models/campaign_models.dart';
import 'views/campaign_dashboard_view.dart';
import 'views/create_campaign_wizard_view.dart';
import 'views/create_auto_campaign_view.dart';
import 'views/campaign_details_monitoring_view.dart';
import 'views/audience_groups_view.dart';

class WebCampaignPortalScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const WebCampaignPortalScreen({super.key, this.onBack});

  @override
  State<WebCampaignPortalScreen> createState() => _WebCampaignPortalScreenState();
}

class _WebCampaignPortalScreenState extends State<WebCampaignPortalScreen> {
  String _currentView = 'dashboard'; // 'dashboard', 'create', 'create_auto', 'details', 'groups'
  CampaignModel? _selectedCampaign;
  CampaignTemplateModel? _selectedTemplateForCreate;

  void _navigateToDashboard() {
    setState(() {
      _currentView = 'dashboard';
      _selectedCampaign = null;
      _selectedTemplateForCreate = null;
    });
  }

  void _navigateToCreate({CampaignTemplateModel? template}) {
    setState(() {
      _currentView = 'create';
      _selectedCampaign = null;
      _selectedTemplateForCreate = template;
    });
  }

  void _navigateToGroups() {
    setState(() {
      _currentView = 'groups';
      _selectedCampaign = null;
    });
  }

  void _navigateToCreateAuto() {
    setState(() {
      _currentView = 'create_auto';
      _selectedCampaign = null;
    });
  }

  void _navigateToDetails(CampaignModel campaign) {
    setState(() {
      _selectedCampaign = campaign;
      _currentView = 'details';
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget currentWidget;
    switch (_currentView) {
      case 'groups':
        currentWidget = AudienceGroupsView(
          onBack: _navigateToDashboard,
        );
        break;
      case 'create':
        currentWidget = CreateCampaignWizardView(
          initialTemplate: _selectedTemplateForCreate,
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
          );
        } else {
          currentWidget = CampaignDashboardView(
            onCreateCampaign: () => _navigateToCreate(),
            onUseTemplate: (tpl) => _navigateToCreate(template: tpl),
            onCreateGroup: _navigateToGroups,
            onCreateAutoCampaign: _navigateToCreateAuto,
            onSelectCampaign: _navigateToDetails,
          );
        }
        break;
      case 'dashboard':
      default:
        currentWidget = CampaignDashboardView(
          onCreateCampaign: () => _navigateToCreate(),
          onUseTemplate: (tpl) => _navigateToCreate(template: tpl),
          onCreateGroup: _navigateToGroups,
          onCreateAutoCampaign: _navigateToCreateAuto,
          onSelectCampaign: _navigateToDetails,
        );
        break;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: currentWidget,
    );
  }
}
