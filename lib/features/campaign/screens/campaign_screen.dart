import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../mobile/mobile_campaign_dashboard.dart';
import '../mobile/mobile_customers_screen.dart';
import '../web/web_campaign_portal_screen.dart';

class CampaignScreen extends StatelessWidget {
  final VoidCallback? onBack;
  final int initialTabIndex;

  const CampaignScreen({super.key, this.onBack, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (initialTabIndex == 1) {
        return MobileCustomersScreen(onBack: onBack);
      }
      return MobileCampaignDashboard(onBack: onBack);
    }
    return WebCampaignPortalScreen(onBack: onBack, initialTabIndex: initialTabIndex);
  }
}
