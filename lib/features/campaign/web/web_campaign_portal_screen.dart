import 'package:flutter/material.dart';
import '../models/campaign_models.dart';
import 'views/campaign_dashboard_view.dart';
import 'views/create_campaign_wizard_view.dart';
import 'views/create_auto_campaign_view.dart';
import 'views/campaign_details_monitoring_view.dart';
import 'views/audience_groups_view.dart';
import 'views/use_template_dispatch_view.dart';

class WebCampaignPortalScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const WebCampaignPortalScreen({super.key, this.onBack});

  @override
  State<WebCampaignPortalScreen> createState() => _WebCampaignPortalScreenState();
}

class _WebCampaignPortalScreenState extends State<WebCampaignPortalScreen> {
  String _currentView = 'dashboard'; // 'dashboard', 'create', 'create_auto', 'details', 'groups', 'dispatch'
  CampaignModel? _selectedCampaign;
  CampaignTemplateModel? _selectedTemplateForCreate;
  CampaignTemplateModel? _selectedTemplateForDispatch;

  void _navigateToDashboard() {
    setState(() {
      _currentView = 'dashboard';
      _selectedCampaign = null;
      _selectedTemplateForCreate = null;
      _selectedTemplateForDispatch = null;
    });
  }

  void _navigateToCreate({CampaignTemplateModel? template}) {
    setState(() {
      _currentView = 'create';
      _selectedCampaign = null;
      _selectedTemplateForCreate = template;
      _selectedTemplateForDispatch = null;
    });
  }

  void _navigateToDispatch(CampaignTemplateModel template) {
    setState(() {
      _currentView = 'dispatch';
      _selectedCampaign = null;
      _selectedTemplateForDispatch = template;
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
            onCreateAutoCampaign: _navigateToCreateAuto,
            onSelectCampaign: _navigateToDetails,
          );
        }
        break;
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
            onUseTemplate: _navigateToDispatch,
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
          onUseTemplate: _navigateToDispatch,
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
