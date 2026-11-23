import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../mobile/mobile_campaign_dashboard.dart';
import '../mobile/mobile_customers_screen.dart';
import '../web/web_campaign_portal_screen.dart';

class CampaignScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final int initialTabIndex;

  const CampaignScreen({super.key, this.onBack, this.initialTabIndex = 0});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  late int _activeTab;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTabIndex;
  }

  @override
  void didUpdateWidget(CampaignScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      setState(() => _activeTab = widget.initialTabIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = IndexedStack(
          index: _activeTab.clamp(0, 1),
          children: [
            MobileCampaignDashboard(
              onBack: widget.onBack,
              onNavigateToCustomers: () => setState(() => _activeTab = 1),
            ),
            MobileCustomersScreen(
              onBack: widget.onBack,
              showHeader: false,
              onNavigateToCampaigns: () => setState(() => _activeTab = 0),
            ),
          ],
        );

        if (constraints.maxWidth > 720) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }
}
