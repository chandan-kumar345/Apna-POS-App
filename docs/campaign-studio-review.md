# Campaign Studio review

Reviewed 15 November 2026. Scope: the active `CampaignScreen → WebCampaignPortalScreen → CampaignDashboardView` route, its service, and creation-result handling. This is not a complete backend/Meta delivery audit.

## Implemented

- Rebuilt the dashboard around the supplied reference: purple studio canvas, existing phone artwork, create/automation/audience actions, performance tiles, wallet balance, status filters, search and image template cards. Mobile stacks the main panels; desktop places them alongside each other. Template and campaign lists use slivers to build visible cards lazily.
- Split presentation into `campaign_studio_layout.dart`. Preserved the public dashboard callbacks and the shared `NeumorphicTheme` tokens used by other campaign views.
- Isolated the campaign portal from the app's dark theme on its light surfaces and added safe-area handling and dashboard back navigation.
- Removed the fabricated ₹98.95 wallet fallback. Zero is now displayed as the actual API balance.
- Removed invented campaign details when the performance action is used with no campaigns.
- Added request generations so an older status request cannot replace the newest tab's list. Kept status-specific API requests so filters still retrieve the relevant records rather than filtering only an unfiltered first page.
- Removed the service's synthetic campaign-creation success after an API failure. It previously generated local campaign IDs, delivery totals, spending and a delivery timeline without a successful backend response. Creation now returns null on failure or missing ID. Dispatch and draft/publish UI report failure instead of showing a success dialog/toast.

## Remaining integration findings

1. **Hard-coded dispatch configuration:** `use_template_dispatch_view.dart` still contains a fixed business sender, phone-number ID, ₹300 reward, coupon `FLAT300D`, and offer copy. These pre-existing values need a business/channel and offer-configuration integration pass before generic live template sends can be considered verified. This redesign does not establish that messages will be delivered.
2. **Offline catalog and channel defaults:** `CampaignService.fetchTemplates`, `fetchChannels`, and several DTO defaults can supply example content or connected/approved labels when API data is absent. The dashboard no longer invents template offer text or approval badges based on names, but the remaining setup/default logic needs server-authoritative connection/approval handling.
3. **Caching and errors:** service read failures generally return singleton caches without exposing an error state, and those caches are not explicitly keyed by business. Account-switch/outage behavior needs a separate audit.
4. **Status vocabulary/pagination:** the existing Pending/Approved/Rejected mapping aliases running/completed/cancelled. The list service also does not expose pagination metadata. Backend status contracts and large-history pagination deserve dedicated coverage.
5. **Dormant UI:** `campaign_screen.dart` still contains a legacy marketing/pricing implementation below its build method, but build currently returns the campaign portal. It was not removed in this pass.

## Validation

Nine focused tests cover 320/390/1100 px layouts with enlarged text, API metrics and a zero wallet, create/automation/audience/template callbacks, search and draft filtering/detail selection, status-query preservation, out-of-order requests, empty performance behavior, rejected API creation, real successful creation, and light surfaces under the actual dark parent theme.

Visual captures use mocked API responses and existing bundled artwork. No campaign was sent to customers, no wallet was topped up, and no production Meta account was modified. Android debug APK build and focused static-analysis results are recorded in `.gsd/JOURNAL.md` and `build/campaign-*.log`.
