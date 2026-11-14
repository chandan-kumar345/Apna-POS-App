# Task journal

## 2026-11-13: Chotu product recognition, microphone startup and UI

Fixed polite order rejection, Hindi catalog normalization, table-number parsing,
quantity/table confusion, separated item syntax, voice startup/restart handling,
desktop readiness fallback and misleading local execution fallback. Refreshed
the Chotu overlay with language selection, table context, typing and scrollable
professional layout. Manual POS flow implementations were not changed.

Verification: backend 49/49; Flutter/phone-render 27/27; targeted analysis clean.
Detailed evidence and device limitations: `docs/chotu-ai/VOICE_FIXES_2026-11-13.md`.

## 2026-11-12: Chotu Python order automation

Analysed the existing Chotu voice and POS lifecycle, created PRD/TRD and operation
guides under `docs/chotu-ai/`, and implemented the Python planner, authenticated
backend order tools, durable request receipts and minimal existing-overlay
integration. Verified cart -> KOT -> unpaid invoice -> explicitly confirmed cash
sale -> free table with the real Python bridge and disposable MongoDB.

Evidence: Python 12/12, expanded agent API 26/26, final Flutter and visual checks
26/26; focused Flutter analysis reports no issues. The previous combined backend
run also passed both legacy Chotu suites. Actual lifecycle output:
`{"cartLines":2,"kot":"preparing","unpaidBillTotal":336,"paid":true,"table":"free","saleCount":1}`.

Full commands, review corrections, phone previews and limitations are recorded
in `.gsd/chotu-ai-VERIFICATION.md`. Setup: `npm run start:chotu` from `backend`.
Scope is online dine-in/cash; digital payment verification, physical printing and
takeaway/delivery remain documented follow-ups. No commit or deployment made.

## 2026-11-12: One-time Android order alert setup

Request: remove repeated permission interruptions from the client POS UI while
retaining Android's required manual approval for display over other apps.

Changes:
- Removed the delayed overlay prompt from MainLayout startup.
- Added the optional setup prompt after successful business onboarding, before
  the onboarding success dialog.
- Persisted that setup was offered, including skips and dismissals. Existing
  prompt timestamps from earlier app versions also suppress another prompt.
- Kept manual access through WhatsApp > App Info Permissions.
- Changed the primary action to Open Settings and made the explanation scroll
  so the buttons remain available on narrow screens.

Verification evidence:
- `flutter test test/order_alert_permission_service_test.dart --reporter expanded`
  returned `00:01 +5: All tests passed!` (exit 0).
  Checks cover persistence beyond the former 30-minute interval, old-version
  prompts, already granted access, explicit settings navigation without falsely
  reporting a grant, and overlapping setup calls.
- `flutter analyze --no-fatal-infos lib/core/services/order_alert_permission_service.dart lib/features/onboarding/business_settings_screen.dart test/order_alert_permission_service_test.dart`
  returned `No issues found! (ran in 5.9s)` (exit 0).
- `flutter test build/permission_validation/preview_test.dart --reporter expanded`
  returned `00:01 +1: All tests passed!` (exit 0).
  Visually inspected actual permission dialog renders at 300 x 617 logical
  pixels, with Roboto and Material Icons loaded, and the screen after skipping.
  Images: `build/permission_validation/setup_300x617.png` and
  `build/permission_validation/after_skip_300x617.png`.
- `git diff --check` returned exit 0.

Broader checks and limits:
- The existing WhatsApp chat and app smoke tests passed. The combined run with
  business_settings_hub_test.dart finished with 11 passing and 5 failing tests.
  Settings failures concerned UI assertions outside the permission flow, such
  as duplicate ONLINE labels and missing Payments Khazana and Autonomous
  Hospitality & Order Assistant text. Those screens and assertions were not
  changed by this task.
- Including main_layout.dart in analysis reported 25 informational diagnostics
  on unchanged code (deprecated withOpacity and unnecessary underscores).
- Native settings dispatch was mocked in widget validation; actual Android
  system permission approval was not exercised or silently granted.
- The user's existing order_model.dart modifications were preserved.

## 2026-11-12: System permission prompts after login

Updated request: move all initial permission prompts until after login and open
Android's display-over-other-apps settings directly, without a custom dialog.

Changes:
- Removed permission requests from main(), SplashScreen startup, FCM startup,
  and iOS local-notification initialization.
- Added PostLoginPermissionObserver to the app navigator. Authenticated page
  navigation starts setup after rendering; the initial splash and logged-out
  navigation do not request permissions. Restored authenticated sessions run
  setup after the splash routes to their destination.
- Consolidated notification, camera, microphone, location, media, Bluetooth,
  and platform-specific requests in the post-login helper. Granted and
  permanently denied runtime permissions are skipped.
- Android requests finish runtime and battery prompts before opening the native
  overlay settings section directly. Removed the custom overlay dialog and its
  onboarding call entirely.
- Persisted completion so declines, page changes, and later logins do not repeat
  the automatic setup. Concurrent callers share one sequence, and logout stops
  any remaining requests.
- FCM startup only reads notification authorization. Token retrieval requires
  existing authorization and a stored login token, so browser token fetching
  cannot open an early permission prompt. Browser permission requests run in
  the authenticated setup flow.
- Added required iOS privacy descriptions for camera, photos, microphone, and
  speech. The installed Apple permission plugin's Swift package derives these
  capabilities from Info.plist and enables notifications by default.
- Replaced the superseded onboarding-dialog tests with post-login flow checks.

Verification evidence:
- `flutter test test/post_login_permission_flow_test.dart test/widget_test.dart --reporter expanded`
  returned `00:01 +10: All tests passed!` (exit 0): nine Android/iOS flow checks
  plus the app smoke test.
- `flutter test build/permission_validation/post_login_preview_test.dart --reporter expanded`
  returned `00:02 +1: All tests passed!` (exit 0). This renders the actual login
  and POS register screens at 300 x 617, verifies no requests before login,
  verifies the runtime -> battery -> native overlay dispatch order after login,
  and checks that no custom permission dialog exists.
- Visually inspected `build/permission_validation/login_before_permissions_300x617.png`
  and `build/permission_validation/pos_after_login_300x617.png`.
- Analysis of main.dart, splash_screen.dart, the new observer, notification
  helper, order-alert service, FCM service, local-notification service, and
  post-login tests completed with no errors. One unchanged FCM background-handler
  warning remains: unused local variable isTableOrder at line 38.
- Python plistlib parsed the updated Info.plist successfully with all eight
  privacy descriptions present. `git diff --check` returned exit 0.

Limits: native permission results and Android settings dispatch were mocked in
widget validation. No app was installed on the connected phone, and no system
permission was silently granted. Existing launcher assets, order model, auth
widgets, and splash test edits from concurrent user work were preserved.

## 2026-11-12: Launcher sizing and splash redesign

Request: slightly enlarge the transparent Android launcher logo and redesign the splash screen with the new logo.

Changes:
- Increased standard and round launcher artwork and adaptive artwork while keeping the complete silhouette inside Android's visible bounds.
- Replaced the layered splash cards with a spacious light-blue brand screen, a prominent transparent logo, restrained typography, and a short fade/settle entrance.
- Kept the existing cached destination routing, 950ms entrance, and 1200ms fallback. Reduced-motion settings show the branding without entrance motion.
- Matched Android's native starting-window colors and added new-logo artwork for both older Android and Android 12+ in day/night resources.
- Regeneration: `dart run tool/generate_android_launcher_icons.dart` now produces launcher and native splash artwork at five densities.

Verification evidence:
- `flutter test test/splash_screen_test.dart --reporter expanded` returned `00:01 +7: All tests passed!` (exit 0). Checks cover automatic navigation, the fallback with disabled ticking, compact/phone/landscape/tablet layouts at 1.6x text, and reduced-motion rendering.
- `flutter analyze --no-fatal-infos lib/features/auth/splash_screen.dart lib/features/auth/widgets/splash_brand_view.dart test/splash_screen_test.dart tool/generate_android_launcher_icons.dart` returned `No issues found! (ran in 6.2s)` (exit 0).
- `flutter test build/splash_validation/preview_test.dart --reporter expanded` returned `00:02 +5: All tests passed!` (exit 0). Rendered and visually inspected actual Flutter frames with Roboto at phone (390x844), compact (320x568), landscape (740x320), tablet (1024x768), and 2x text sizes. Images are saved in `build/splash_validation/`.
- Read-back resource validation returned `Validated 25 transparent launcher/splash PNGs, density dimensions, circular safe bounds, and Android resource XML.` (exit 0).
- One antialiased edge pixel on the enlarged xxxhdpi adaptive foreground initially crossed the safe-circle check. Reduced the radius from 33dp to 32.8dp; all 25 final resources pass the bounds check.
- `git diff --check` returned exit 0.

Native APK build and package verification are being completed. Device installation was not part of this task.

Final Android verification:
- `flutter build apk --debug --no-pub` returned `Running Gradle task 'assembleDebug'... 56.6s` and `Built build\app\outputs\flutter-apk\app-debug.apk` (exit 0).
- APK read-back returned `APK verified: all 25 native launcher/splash images and the Flutter logo match the new resources.` (exit 0).
- Launcher sizing and splash redesign completed. The APK is ready for installation; native first-launch appearance was not exercised on a physical device.

## 2026-11-12: Immediate startup and logo writing animation

Request: remove the blank delay when opening the app; write Apna POS in the logo's style and enter the saved POS after the text is complete.

Cause and implementation:
- main() previously awaited Firebase, endpoint discovery, database restoration, audio and notification startup before runApp(), leaving Flutter unable to draw during service setup.
- The mobile app now paints SplashScreen immediately and invokes initialization from its first post-frame callback. Endpoint scanning, audio, notification setup and FCM run in the background; Firebase configuration remains ordered before local database restoration to preserve Firestore listeners.
- Added LogoWritingReveal: paths progressively reveal A-p-n-a, P-O-S and the receipt/pipe from the original logo bitmap, preserving its exact lettering and colors. The logo has a faint first-frame guide and a text fallback during image decoding.
- Captions type in without layout jumps. The timeline lasts 2600ms, and navigation waits for both complete lettering and restored session. Slow local startup retains the completed brand with a preparation indicator. Reduced-motion and muted-ticker fallbacks finish the branding safely.
- Native NormalTheme now retains launch_background in day/night modes so the logo remains visible before the first Flutter frame.

Verification evidence:
- `flutter test --no-pub test/splash_screen_test.dart --reporter expanded` returned `00:10 +10: All tests passed!` (exit 0). Tests cover completion-gated navigation, ticker fallback, responsive layouts, reduced motion, initialization after first paint, slow session restoration, initialization failure, and disposal during startup.
- Targeted analysis of main.dart, splash_screen.dart, both brand widgets and the focused test returned `No issues found! (ran in 56.1s)` (exit 0).
- `flutter test --no-pub test/widget_test.dart test/post_login_permission_flow_test.dart --reporter expanded` returned `00:10 +10: All tests passed!` (exit 0).
- `flutter test --no-pub build/splash_validation/writing_preview_test.dart --reporter expanded` returned `00:17 +1: All tests passed!` (exit 0). Rendered 40 real Flutter frames; visually inspected first frame, partial Apna, POS writing, receipt completion, typed captions and final text. Preview: `build/splash_validation/writing_animation.gif`; sampled PNG frames: `writing_0.png`, `writing_5.png`, `writing_13.png`, `writing_21.png`, `writing_29.png`, `writing_35.png`, `writing_39.png`.
- `flutter build apk --debug --no-pub` completed assembleDebug in 373.1s and built `build/app/outputs/flutter-apk/app-debug.apk` (exit 0).
- APK read-back confirmed the packaged original logo and compiled Dart kernel match the latest build inputs by SHA256.
- Native XML check confirmed NormalTheme day/night windows retain the logo, and `git diff --check` returned exit 0.
- Independent read-only review found no blockers in startup ordering, animation completion, or lifecycle guards.

Physical-device cold-start verification is in progress using the connected development phone; the debug APK update preserves existing app data.

Device verification and capture limit:
- `adb install -r -t build/app/outputs/flutter-apk/app-debug.apk` returned `Performing Streamed Install` / `Success`; app data was preserved.
- Three `am start -W` checks reported `Status: ok`, `LaunchState: COLD`, `Activity: com.apnapos.app/.MainActivity`. Observed debug cold-start TotalTime values were 5322ms, 3929ms and 4871ms. Activity/process inspection confirmed Apna POS remained running and visible.
- Full native visual timing could not be confirmed: the phone denied local screenrecord output, direct recording returned no frames, and the screenshot did not show the current app reported by the activity manager. No native no-blank visual claim is inferred from that capture. The writing animation and completed text were visually verified from 40 actual Flutter-rendered frames instead.
- The temporary screenrecord client was stopped after capture timed out.

Implementation, APK build, all 20 focused/regression tests, targeted analysis, animation preview and package verification are complete. Native startup code removes the pre-runApp service wait and keeps launch artwork in NormalTheme; a physical screen recording remains an environment limitation.

## 2026-11-12: Android uploaded product video and intermittent POS controls

Found autoplay explicitly disabled on POS grid and customer storefront list. Enabled shared muted playback with the existing one-mobile/two-desktop decoder limit. Shared media now owns controllers before initialization, disposes failed/cancelled loading controllers, times out stalled initialization after 15 seconds, ignores obsolete async results, and resumes waiting grid playback after priority previews close. Image list changes are compared by content. Removed play calls from build.

Aligned product video upload wait with UploadService's existing three-minute limit; preserved local/offline fallback. Previously save stopped waiting after 12 seconds and could persist only a local file path.

Checkout now rebuilds POS and mounted mobile cart after releasing its processing lock, including cancellation; payment-button text scales inside its existing bounds. Payment calculations, cart persistence, KOT, and ordering rules are unchanged.

Validation: five shared-media regression tests passed (failed initialization, unmount while loading, timeout slot handover, Android priority preview handover, stale async errors). Desktop payment cancellation test passed after a database update while payment was open. Static analysis of scoped production files had no errors (style information only). No physical Android playback of the customer's uploaded file was performed. Broader storefront/isolation suite includes failures and is not a clean release gate. Speculative cache rewrite was withdrawn because its network fixture was not reliable; existing cache pipeline retained.

## 2026-11-12: Preview-first character writing concept

Request: first make and show the splash animation with characters written one by one, becoming the full Apna POS logo.

Created a separate replayable draft at `output/previews/apna-pos-writing.html`. The sequence writes A-p-n-a, P-O-S, draws the pipe/receipt, and resolves the flat ink into the original glossy logo over 3.6 seconds. Character ownership masks prevent fragments of neighboring letters from appearing early. The existing logo is embedded locally; no network service is used by the preview. The draft honors reduced-motion preferences and offers Replay. App code, APK and device installation were not changed for this preview request.

Verification:
- Headless browser verification returned `Verified 41 rendered frames, sequential letter reveal, full-logo finish, replay, and 320px layout. No browser errors.` (exit 0).
- Visually inspected sequential stages at 300ms, 1000ms, 2000ms, 2800ms, the 3600ms finish, and narrow layout. Refinement removed early fragments below the p before P begins.
- Fragment size: 388432 bytes, within the 1MB inline limit.
- Supporting GIF: `build/splash_validation/apna-pos-writing-concept.gif`.
- This draft is presented for the user's visual review before application to the splash implementation.

## 2026-11-13: Apply handwriting preview and transition to Get Started

Request: write Apna POS character by character, resolve the completed text into the full logo, smoothly open Get Started, and use the new logo on that screen.

Implemented:
- Promoted the reviewed preview into Flutter: A-p-n-a, P-O-S, then the pipe/receipt; isolated glyph sprites prevent neighboring letters from showing early. Brand-colored flat ink blends into the original glossy logo near the end of the 3600ms timeline.
- Added a deterministic atlas generator using the project's existing image package. Inputs live in tool/branding; the generated atlas is assets/images/apna_pos_logo_ink_atlas.png. The original logo remains unchanged.
- Splash now opens Get Started for new and restored sessions without clearing saved user data. Public web storefront/admin entry logic is unchanged.
- Replaced the Get Started logo, constrained its layout to remain clean on wide screens, respected reduced motion, and used a portable Material loyalty badge icon.
- Added a fade-through: completed branding fades out over 160ms, then Get Started fades in over 320ms. A visual check found the initial crossfade overlapped both logos; the fade-through removes that overlap.
- Get Started's named route does not trigger automatic permission setup merely because an existing session is restored.

Verification so far:
- `dart run tool/generate_splash_ink_atlas.dart` returned `Generated 9 isolated handwriting glyphs in the splash ink atlas.`
- `flutter test --no-pub test/splash_screen_test.dart test/post_login_permission_flow_test.dart --reporter expanded` returned `00:05 +23: All tests passed!` (exit 0). Includes new/restored-session welcome routing, old-screen fade-out before welcome appears, new-logo loading on narrow/wide layouts, and avoiding permission prompts on Get Started.
- Targeted analysis of the splash, Get Started, observer, animation widgets, generator and focused tests returned `No issues found! (ran in 7.3s)` (exit 0).
- Real Flutter animation render returned `00:17 +2: All tests passed!`; final fade-through re-render returned `00:03 +1: All tests passed!`. Visually inspected flat-letter reveal, glossy finish, final Get Started and the halfway incoming fade without old-logo overlap. Images are build/splash_validation/get_started_new_logo.png and get_started_transition.png; the 40-frame GIF is writing_animation.gif.
- The first new-logo assertion incorrectly selected Semantics as Image; corrected the test finder and the final full suite passes. This did not affect app rendering.
- `git diff --check` passes for the changed auth screens and tests.

Final Android build/package verification is in progress. No physical-device installation or live capture was performed for this revision.

Final verification:
- `flutter build apk --debug --no-pub` returned `assembleDebug... 63.1s` and `Built build\app\outputs\flutter-apk\app-debug.apk` (exit 0).
- APK read-back returned `APK verified: original logo, isolated handwriting atlas, and latest compiled Dart kernel match the final build.` (exit 0).
- The reviewed handwriting-to-logo transition and Get Started rebranding are complete. The final APK has not been installed on a physical device for this revision.

## 2026-11-14 - Business subscriptions and Chotu access (backend only)

Implemented the attached request after auditing Business/User/Staff/premium
subscription mirrors, JWT fallback, status/activation/admin routes, payment
handlers, Chotu and WhatsApp AI entry points, campaign jobs and database watchers.
Earlier uncommitted frontend/Chotu/splash work was preserved; no frontend edits
were made for this request. No production database migration, deployment, live
charge or commit was performed/requested.

Canonical controls: `Business.isSubscription` strict boolean,
`subscriptionExpiresAt` finite BSON Date later than server time, and
`isChotuAiActive` strict boolean. Central raw-BSON reads reject invalid/missing
values and reflect manual Mongo changes immediately with the same token.
Expiry is calculated without ever turning off the manual switch. Authenticated
membership, POS/staff permissions, ordinary mass-assignment rejection, appropriate
paid route mounts and provider/background guards enforce access. Free core POS,
auth/status and payment/renewal paths stay available. Compatibility aliases are
calculated on status/profile/login/admin responses.

Verified server-owned Razorpay renewal intents match captured amount/currency,
business and order. An atomic receipt/date update prevents replay/concurrent
double extension without changing either manual boolean. Unsigned/forged webhooks
and UTR-only activation cannot grant access. Ordinary restaurant webhook handling
is preserved. Startup no longer elevates the platform contact email or resets
its password; public unverified recovery cannot reset platform administrators.

Legacy watcher synchronization was replaced by canonical, read-only status events
and polling. Reminders use canonical dates. Scheduled paid campaigns remain
queued while expired and retry after an extension; execution/dispatch recheck
before charge/provider work.

Migration is prepared only, defaults dry-run, preserves canonical controls and
reliable finite legacy dates, reports ambiguity/lifetime/missing dates, defaults
missing AI to false, and never invents expiry. Compare-and-set writes preserve
concurrent/manual changes. Raw migration fixture cleanup was fixed after a test
found records left behind by collections not registered with Mongoose.

Verification (backend working directory, all reported commands exited 0):

- `npm.cmd test -- --runTestsByPath tests/entitlement_access.test.js tests/entitlement_migration.test.js tests/entitlement_background.test.js tests/subscription.test.js tests/auth.test.js`
  returned `Test Suites: 5 passed, 5 total; Tests: 60 passed, 60 total; Time: 47.499 s`.
  Durable output: `build/entitlement-final-tests.log` from repository root.
- After the final administrator response and campaign queue changes,
  `npm.cmd test -- --runTestsByPath tests/entitlement_access.test.js tests/entitlement_background.test.js`
  returned `Test Suites: 2 passed, 2 total; Tests: 36 passed, 36 total; Time: 28.43 s`.
  This includes two additional cases, yielding 62 distinct checks across the five
  focused suites. Output: `build/entitlement-final-boundary-tests.log`.
- `npm.cmd test -- --runTestsByPath tests/chotu_automation_agent.test.js tests/chotu.test.js tests/chotu_order_flow.test.js tests/profile_history.test.js`
  returned `Test Suites: 4 passed, 4 total; Tests: 46 passed, 46 total; Time: 109.175 s`.
  Positive Chotu fixtures explicitly seed paid+AI access; cross-tenant fixtures
  also seed access before testing their independent tenant boundary.
  Output: `build/entitlement-regression-tests.log`.
- `npm.cmd test -- --runTestsByPath tests/razorpay_payment.test.js --testNamePattern='POST /api/v1/payments/webhook'`
  returned `Test Suites: 1 passed; Tests: 3 skipped, 3 passed, 6 total; Time: 9.087 s`.
  The three excluded cases are outside the selected webhook scope.
  Output: `build/entitlement-webhook-tests.log`.
- `git diff --check -- backend .gsd` passes (only Git line-ending notices).
- `node --check backend/src/services/superadminService.js` passes.

The focused HTTP tests cover literal flags, future/expired/missing/string dates,
exact expiry boundary, same-token Mongo extension, independent AI disable, all
Chotu route denial before provider work, tenant forgery/membership/staff checks,
nested/dotted entitlement writes, read-only status, verified renewals and signed
webhook replay. Pure/in-memory migration checks cover dry-run, repeatability,
unique-owner legacy association, contradictions, expired flags and no invented
expiry. Background checks prove canonical notifications and reminders, no legacy
grant syncing, and paid campaign blocking/resumption.

Changed file inventory, Mongo commands, migration instructions, payment semantics
and exact client limitations are in `backend/docs/ENTITLEMENTS.md`. Existing
UTR-only activation, unauthenticated terminal fallback, cached/offline badges,
legacy staff grants, and device-direct provider credentials have explicit limits;
no client UI was silently modified to hide these constraints.

## 2026-11-14 - Active subscription incorrectly opening upgrade screen

User reported a paid account expiring 17 November and explicitly requested that
active users never be sent to the subscription screen. Used debugger and
empirical-validation guidance. No design/layout changes were made.

Read-only Mongo inspection confirmed the reported account, pizza@gmail.com, has
business 6ad46853ea47d6b3e13d633d owned by user 6ad46853ea47d6b3e13d633a.
Business.subscription, User.subscription and its business premium ledger all
agreed on active=true and BSON expiry 2026-11-17T06:43:19.746Z. Canonical
isSubscription/subscriptionExpiresAt were absent. The previous backend change
made canonical fields authoritative before this account was migrated, causing a
false inactive result. It was not an expiry-time or payment problem.

The earlier no-production-writes restriction was honored until the user answered
"Apply this account repair" to the concrete account/date question. Rechecked
owner, business, all histories, exact future expiry and absent canonical fields.
One native update used _id+owner+missing-control+legacy-date/flag preconditions and
set only isSubscription=true and subscriptionExpiresAt to the existing BSON date.
Result: matched=1, modified=1, effectiveAccess=true, chotuPermissionUnchanged=true.
No subscription extension, AI activation, blanket migration or other business
write was performed. Read-back through the central evaluator returned:
isSubscription=true, isActive=true, isSubscribed=true,
subscriptionExpiresAt=2026-11-17T06:43:19.746Z,
exactOriginalExpiryPreserved=true, chotuAiAccess=false.
Durable whitelisted evidence: build/subscription-account-repair-verification.json.

Client changes:
- SubscriptionService shares concurrent status fetches, ignores responses from
  prior accounts, uses effective server flags before legacy status text and
  applies explicit false as well as true. Server-calculated expiry uses server
  time, avoiding a second decision using a mis-set device clock.
- Main sidebar and direct inventory/loyalty upgrade entry points refresh before
  navigating. Fast repeated sidebar taps are serialized. An active subscriber
  proceeds to the feature instead of an upgrade screen.
- An open SubscriptionScreen listens for active state and returns to its target;
  SubscriptionLockedBarrier listens and removes its overlay immediately.
  The modal helper also verifies status before showing a lock.
- Rejected/unverified activation returns false instead of manufacturing local
  active status after an API error.
- Added service/widget tests for stale false, explicit false, plan metadata,
  concurrent refresh, account switching, rejected payment, modal suppression,
  reactive barriers and delayed active-page dismissal. Existing test setup now
  explicitly resets subscription state between cases.
- Added migration regression for this exact 17 November expiry, including strict
  boundary denial. The ambiguous-owner fixture deliberately removes the unique
  owner index only inside its disposable test database to model legacy data.

Files changed for this follow-up:
lib/core/services/subscription_service.dart;
lib/features/dashboard/main_layout.dart;
lib/features/inventory/inventory_screen.dart;
lib/features/loyalty/screens/loyalty_landing_screen.dart;
lib/features/subscription/screens/subscription_screen.dart;
lib/features/subscription/widgets/subscription_locked_bottom_sheet.dart;
test/subscription_access_navigation_test.dart (new);
test/premium_subscription_flow_test.dart;
backend/tests/entitlement_migration.test.js;
backend/docs/ENTITLEMENTS.md and .gsd task records. Other dirty work preserved.

Verification:
- `flutter test --no-pub test/subscription_access_navigation_test.dart test/premium_subscription_flow_test.dart --reporter expanded`
  returned `00:02 +16: All tests passed!` (exit 0).
  Output: build/subscription-navigation-tests.log.
- `npm.cmd test -- --runTestsByPath tests/entitlement_migration.test.js tests/entitlement_access.test.js`
  returned `Test Suites: 2 passed, 2 total; Tests: 38 passed, 38 total; Time: 28.591 s`
  (exit 0). Output: build/subscription-account-backend-final-tests.log.
- Focused Flutter analysis of SubscriptionService, subscription lock widget and
  new tests returned `No issues found! (ran in 14.9s)` (exit 0).
  Broader seven-file analysis has no errors, with 27 pre-existing warnings/infos
  (dashboard deprecations/underscore style and unused legacy helpers), retained
  to avoid unrelated design/cleanup changes. Outputs are under build/subscription-*analysis.log.
- `flutter build apk --debug --no-pub` returned
  `Running Gradle task 'assembleDebug'... 75.2s` and
  `Built build/app/outputs/flutter-apk/app-debug.apk` (exit 0).
  Output: build/subscription-navigation-apk-build.log. Existing Android toolchain
  future-support warnings did not prevent the build.
- ZIP read-back verified the APK's assets/flutter_assets/kernel_blob.bin SHA-256
  matches the current build's compiled Flutter kernel. APK size: 333259197 bytes.
- Scoped `git diff --check` passes (exit 0).

Initial verification found test-harness issues: an adapter-start assertion ran
before Dio entered the adapter, leaving a pending future; fixed by awaiting an
explicit adapter-start signal and running the widget's async fetch outside fake
time. Also corrected the migration fixture's unique-index assumption after the
new evaluator test registered the Business model. Final runs above pass. No
physical-device installation, backend deployment or commit was performed.


## 2026-11-14 ? POS responsiveness investigation

Captured Android log evidence of skipped frames and repeated table broadcasts.
Fixed duplicate table persistence/notifications and batched local cart items with
their totals. Regression sequence: **102 notifications before, 1 after** for one
update plus 50 duplicate snapshots. Real total/metadata changes remain immediate.

`flutter test test/table_update_performance_test.dart test/table_timer_test.dart
test/pos_product_media_playback_test.dart --reporter expanded` returned
`00:02 +28: All tests passed!`. Android debug APK build returned
`Running Gradle task assembleDebug... 37.7s` and
`Built build/app/outputs/flutter-apk/app-debug.apk`.

Evidence in `build/performance_validation/`: `device.log`, `before-tests.log`,
`focused-tests.log`, `analyze.log`, `apk-build.log`. A separate pre-existing
realtime-table stale-settled-draft test fails identically on unmodified HEAD:
expected TableStatus.free, actual TableStatus.occupied (see
`baseline-existing-failure.log`). Analyzer has no errors, 2 pre-existing warnings
and 3 pre-existing infos. Investigation details and limits: `.gsd/DEBUG.md`.


POS follow-up: startup logs exposed a second Firestore pending-order listener
without asynchronous error handling. Added its `onError` callback. Rebuilt debug
APK (40.5s), installed and launched successfully. Device PID 24159 log confirms
both cloud permission-denied errors are handled and counts 0 unhandled
exceptions/crashes/ANRs. This does not grant Firestore access. Final focused
checks including checkout recovery: `00:05 +29: All tests passed!`
(`build/performance_validation/final-tests.log`). Startup jank remains visible in
debug; profiling an optimized ARM64 build before making performance claims.

## 2026-11-14 - Slower splash logo handwriting

User requested a slightly slower writing animation so the strokes are visible.
Increased LogoWritingReveal.duration from 3600ms to 4800ms. The painter's stroke
offsets are authored against 3600ms, so it now uses that fixed internal timeline
with normalized animation progress. This slows the actual letter/receipt strokes
and glossy blend along with captions; merely increasing the controller duration
while also multiplying progress by that new duration would leave strokes at the
old speed. Letter paths, colors, artwork and transition design were preserved.
Reduced motion, muted-ticker fallback and startup coordination remain intact.

Changed production file: lib/features/auth/widgets/logo_writing_reveal.dart.
Updated existing timing checks in test/splash_screen_test.dart to derive waits
from writingDuration; the first check now proves that writing is still underway
at the old 3600ms endpoint. Existing unrelated edits in the checkout preserved.

Verification:
- `flutter test --no-pub test/splash_screen_test.dart test/post_login_permission_flow_test.dart --reporter expanded`
  returned `00:02 +23: All tests passed!` (exit 0).
  Output: build/splash_validation/slower-writing-tests.log.
- `flutter analyze --no-pub lib/features/auth/widgets/logo_writing_reveal.dart lib/features/auth/splash_screen.dart test/splash_screen_test.dart`
  returned `No issues found! (ran in 6.2s)` (exit 0).
  Output: build/splash_validation/slower-writing-analysis.log.
- `flutter test --no-pub build/splash_validation/writing_preview_test.dart --reporter expanded`
  returned `00:10 +2: All tests passed!` (exit 0). The existing render harness was
  updated to capture 49 actual Flutter frames at 100ms intervals and the later
  handoff. Preview: build/splash_validation/writing_animation.gif.
  Visually inspected frame 16 (Apna), frame 36 (POS/receipt still writing at
  3600ms), and frame 48 (complete glossy logo and captions at 4800ms).
  Output: build/splash_validation/slower-writing-render.log.
- Scoped `git diff --check` passes (exit 0).

Final Android verification:
- `flutter build apk --debug --no-pub` returned
  `Running Gradle task 'assembleDebug'... 109.7s` and
  `Built build/app/outputs/flutter-apk/app-debug.apk` (exit 0).
  Output: build/splash_validation/slower-writing-apk-build.log.
- ZIP read-back verified the APK's Flutter kernel SHA-256 matches the current
  build's kernel. The GIF metadata confirms 49 frames, 4800ms writing and a
  separate 650ms preview-only hold on the final frame.
- Updated APK: build/app/outputs/flutter-apk/app-debug.apk. No physical-device
  installation was performed for this timing change.


Final device verification: ARM64 profile build succeeded in 189.1s (68.3MB).
Installed with Success and launched as PID 28755: Status ok, cold Activity
TotalTime 2887ms. Startup log reports 0 unhandled exceptions/crashes/ANRs;
64 startup frames were skipped. Device still reports thermal status 3 (severe
throttling), so no controlled FPS or latency improvement claim is made.
Profile APK is installed; debug APK is also built. Evidence:
`build/performance_validation/profile-apk-build.log`, `profile-device.log`,
`thermal-status.txt`. Firebase permissions remain denied; errors are now handled,
and access rules were not changed. Source changes and 29 focused tests validated.

## 2026-11-14 — Restore login and speed up splash

The splash always opened Get Started even when the cached account restored.
Added saved-session routing: completed owners/staff resume POS, signed-out users
see welcome, unfinished owners resume setup. Preserved setup metadata during
profile refresh. Writing is now 3600ms instead of 4800ms. Android startup draws
the same glyphs while Flutter starts and passes elapsed progress to continue the
animation. Removed the fade-to-background phase before the next screen.

Longer checks exposed credential deletion. Fixed partial token-cache reads during
startup, setters skipping restoration, repeated refresh after a resource 401 and
the broad catch clearing valid tokens. Concurrent requests share a refresh and
replay once; only an explicit refresh-endpoint 401 clears credentials. Rotated
refresh tokens persist before access tokens, and the existing disk backup writes
before slow native keystore operations. Also wrapped a narrow menu loading label
whose overflow was exposed by the restored-POS test.

Original refresh regression: expected 1 refresh, actual 2 (auth-refresh-before.log).
Final tests: 00:06 +47: All tests passed! (complete-session-tests.log).
Auth, animation, storage and their tests analyze with No issues found.
Final profile build: 97.1s, 91.5MB (session-fixed-build.log); installed with Success.
Cold start Status ok, PID 5023. Final log counts 0 unhandled exceptions, fatal
exceptions or ANRs (session-fixed-device.log). Visually inspected native writing
and restored POS (session-fixed-screen.png). Evidence: build/session_validation/.

The prior version had already cleared both token keys. The cached account resumes
into POS, but a fresh legitimate sign-in is needed to renew that server session.
Native API reference: https://developer.android.com/develop/ui/views/launch/splash-screen


## 2026-11-14 - Rapid quantity taps in POS

Used debugger/empirical-validation workflow to inspect the real cart path and
stream live logs from the connected OPPO CPH2637. Before-change evidence showed
30 per-tap HTTP writes, 30 untouched-card rebuilds and repeated full draft
serialization. Runtime process 20290 additionally logged skipped 3650 and 5636
frames and two unhandled AudioPlayer 30-second source preparation timeouts.
Thermal status 3 is a confounder for device timing.

Implemented lossless local edits, narrow quantity/cart rebuild signals, fixed
180ms quantity batching, ordered per-cart mutations and a fixed 200ms draft
persistence/notification buffer. Local memory changes remain synchronous. Scoped
snapshots serialize in order and flush on lifecycle/exit/account changes. Cart
removal, clear, variants, table changes and order finalization drain earlier
mutations so an old increment cannot land after a clear/checkout. Delta requests
use postOnce rather than an ambiguous connection retry. Tap sounds share init,
reuse prepared sources and handle async/overlap failures. Calculator debug
output is opt-in; billing arithmetic is unchanged.

Changed for this task: lib/core/database/database_service.dart;
lib/core/network/api_client.dart; lib/core/services/cart_api_service.dart;
lib/core/services/cart_mutation_queue.dart (new);
lib/core/services/sound_service.dart; lib/core/utils/order_calculator.dart;
lib/features/pos/pos_register_screen.dart;
test/pos_quantity_performance_test.dart (new);
test/short_feedback_playback_test.dart (new); .gsd task records.
Before-change copies and a task-only implementation.patch are in
build/quantity_performance; existing unrelated edits were preserved.

Verification commands/results:
- Before: flutter test --no-pub test/pos_quantity_performance_test.dart
  --reporter expanded failed both new regression checks: 30 requests instead
  of 1 and 30 unchanged-product rebuilds instead of 0 (before-tests.log).
- Final: flutter test --no-pub test/pos_quantity_performance_test.dart
  test/short_feedback_playback_test.dart test/table_update_performance_test.dart
  test/pos_checkout_recovery_test.dart test/sound_feedback_wrapper_test.dart
  test/notification_ringtone_test.dart test/pos_neumorphism_ui_test.dart
  test/table_timer_test.dart test/pos_product_media_playback_test.dart
  test/checkout_roundoff_test.dart --reporter expanded
  returned 00:07 +59: All tests passed! (exit 0, final-tests.log).
- Verified cases include exact fast-tap count/total, burst batching, later edits
  during in-flight requests, mixed add/reduce/remove/clear ordering, table/variant
  isolation, queued prior-account rejection, no lost-response replay, one latest
  durable snapshot, clear overriding a buffered save, table switching during a
  burst, async audio error/timeout handling and existing billing/media/table tests.
- Focused eight-file Flutter analysis: No issues found! (ran in 11.3s), exit 0
  (final-analysis.log). Separate database analysis has five existing diagnostics,
  including two unrelated warnings and three style infos; no errors/new findings.
- Additional multi_order_isolation_test suite: six pass, two fail. The two cases
  also fail using an isolated before-change source copy via a separate package
  alias, without replacing active sources (baseline-isolation-tests.log).
  This old fixture keeps stale drafts between scenarios; do not present it as a
  clean suite. The new deterministic table-switch/buffered-quantity test passes.
- flutter build apk --profile --target-platform android-arm64 --no-pub:
  assembleProfile 140.0s; Built app-profile.apk (91.5MB), exit 0
  (final-profile-build.log). APK ZIP read-back confirms lib/arm64-v8a/libapp.so
  SHA-256 matches the final compiled/stripped library.
- adb install -r build/app/outputs/flutter-apk/app-profile.apk: Success.
  adb shell am start -W -n com.apnapos.app/.MainActivity: Status ok,
  TotalTime 3034ms / WaitTime 3102ms, PID 8919. No app data was cleared.
- Live native UI: on previously free T-5, add 1 test item then send 20 rapid
  increments; UI reported 21 Items Added. Burst input took 2.494s including ADB
  wireless/shell overhead, so this is a correctness observation, not a tap-latency
  benchmark. Screenshot/device-burst-result.json retain the result.
- Cleanup: 21 decrement taps removed the test draft and cart bar. UI hierarchy
  confirms T-5 Free; T-1..T-4 retained their prior totals. A read-only Mongo check
  confirms T-5 Free with no current order or total and no matching server cart.
  No KOT, bill, settlement or payment was created. No entitlement data changed.
- New-device log observed 0 unhandled exceptions, 0 audio timeouts, 0 fatal
  exceptions. gfxinfo still shows short frame misses on the thermally throttled
  device; it does not establish that all rendering jank is gone.
- Scoped git diff --check passes.

Runtime limitation: the phone is displaying a cached user but the backend log
reports a missing bearer token. The device burst therefore verified local UI,
not authenticated cloud synchronization. Background queue/ordering is verified
using the mocked transport; optional fresh sign-in requested to check live cloud
sync. Authentication was not bypassed and no synthetic token was issued.

Test work corrected two harness details (mock storage returned a token for every
key, and repeated SharedPreferences resets left the singleton holding an older
cache). An extra await in dataset loading exposed an existing unawaited caller;
limited that await to actual pending drafts. Final focused checks above pass.
A baseline-compare harness initially hit Flutter custom package metadata errors;
using an absolute package configuration plus graph/pubspec metadata produced the
successful before-source comparison recorded above. No commit was requested.
