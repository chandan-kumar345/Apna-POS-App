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


## 2026-11-14 ? Center splash handwriting and captions

Centered the actual Apna/POS letter bounds while they write, then eased that
centering into the complete glossy logo as the emblem appears. Updated the
Android startup vector from the same measured glyph bounds. Portrait/tablet
layouts anchor the logo to the screen center; changing captions or the preparing
footer no longer move it. Short screens and enlarged text use a centered,
scrollable composition. Caption rows reserve complete line heights but center
only the visible letters, removing the leftward offset from transparent suffixes.
Text measurement now inherits the same font/style as the rendered text.

Validation: 16 splash/alignment tests passed (alignment-tests.log) over phone and
tablet viewports, multiple reveal phases, enlarged text, initialization and route
changes. Targeted analysis: No issues found. Visually reviewed Roboto-rendered
frames centered-65.png and centered-100.png. Pixel measurement on 780x1688:
wordmark phase 65% center (390,844), exactly the screen center; finished logo
center (388,846.5), a 2px horizontal / 2.5px vertical optical difference.
Evidence: build/splash_alignment/pixel-centering.json and preview PNGs.
The phone is currently disconnected, so the rebuilt APK cannot be installed here.


Centered splash final build: assembleProfile 129.9s; Built app-profile.apk (91.5MB)
(build/splash_alignment/final-apk-build.log). Copied the finished artifact to
build/splash_alignment/apna-pos-centered-splash.apk for this task. Preview:
build/splash_alignment/centered-100.png. Device installation unavailable because
ADB device inventory is empty. Build, 16 focused tests, analysis and visual QA pass.

## 2026-11-14: Concurrent POS product videos

Request: every video product on the POS grid should stream concurrently.
Added opt-in independentPlayback for POS product media, including previews. Independent clients retain controller ownership and cleanup but do not consume or evict clients in the existing shared playback budget. Storefront retains its existing default coordination policy. No checkout or cart logic changed in this task.

Evidence: flutter test test/pos_product_media_playback_test.dart --reporter expanded: 7 passed, including three concurrent Android product videos, preview without stopping grid videos, cleanup on removal, and previous timeout/cancellation recovery. Player platform is mocked; physical Android decoder capacity is not exercised.
flutter test test/pos_checkout_recovery_test.dart test/checkout_roundoff_test.dart --reporter expanded: 5 passed.
flutter analyze --no-fatal-infos lib/features/pos/widgets/pos_product_media_box.dart test/pos_product_media_playback_test.dart: no errors or warnings; three pre-existing style infos. git diff --check passed.

## 2026-11-15: Chotu startup, access and transparent screen

Read-only diagnosis found Pizza 47 subscribed through 17 November but without
the separate canonical AI access flag. Python 3.11.0 passed
`node src/scripts/startChotuAgent.js --check`. The client previously swallowed
the access error and cached a failed startup for the same account/backend.

Added scoped readiness/error state, coalesced health requests and retry after
denied/unavailable health. Late 401/403 responses revoke client readiness. The
overlay starts voice after successful authorization and uses only the server
automation flow for both text and finalized speech; no local cart mutation
fallback. Removed the full opaque background, large robot, provider badge,
examples and instruction sections. The compact glass panel keeps table,
language, one status/result area, microphone and typed input. Async audio stop
and release setup failures are handled. Manual POS code was not edited here.

Verification: 32 Flutter checks passed across chotu_access_overlay_test,
chotu_voice_test, chotu_automation_snapshot_test and chotu_automation_client_test.
Access denial creates no order; retry works in the same business; startup checks
coalesce; text and finalized voice dispatch once; small keyboard/landscape
layouts do not overflow. The optional screenshot capture renders the actual
Chotu widget over a representative POS backdrop using Roboto and Material
icons. Evidence: build/chotu_validation/flutter-tests.log and PNG capture.
The first widget run needed a permission-channel fixture; the capture run
also exposed an unmocked global audio event channel. Added explicit platform
fixtures and reran successfully; these are simulated voice checks.

Backend command: npm test -- --runTestsByPath
tests/chotu_automation_agent.test.js tests/entitlement_access.test.js.
Both suites passed, 58 tests. Actual temporary-database lifecycle evidence:
2 cart lines, KOT preparing, unpaid bill 336, paid true, table free, one sale.
No production order was used. Existing server public /api/v1/health also
returned status ok. Targeted analysis reports No issues found.

After the user explicitly approved enabling Chotu AI, a guarded native Mongo
update matched/modified exactly one business. Full before/after comparison
showed the only changed key was isChotuAiActive. Expiry stayed
2026-11-17T06:43:19.746Z; calculated subscription and chotuAiAccess both true.
Audit: build/chotu_validation/ai-access-repair.json. No migration, extension,
provider configuration, role or other production data changed.

ARM64 profile build succeeded (initial assembleProfile 136.2s, 91.3 MB),
installed with adb install -r: Success. The phone opened normally to welcome
and Login. The user chose Finish without live microphone test; sign-in and
physical voice recognition therefore remain unverified. No credentials were
requested and no authentication token was issued. Preserve unrelated splash
and POS product-video edits. No commit/deployment requested.

Final verification after language font styling: all 12 overlay checks including
the rendered screenshot passed (final-overlay-tests.log); five-file analysis
clean (analyze.log). Final assembleProfile completed in 231.1s and produced the
91.4 MB APK; copied to build/chotu_validation/apna-pos-chotu.apk. Final capture
chotu-transparent.png was visually checked with readable controls and no extra
sections. The connected phone received the final build with adb install -r.


## Smooth splash handwriting

Confirmed the reported rough finish with a pixel regression: a 0.2ms step over
letter completion abruptly filled missing silhouette areas. Original mean RGBA
changes peaked at 0.601 (before-tests.log, failing). The revised painter eases
those edges in before completion, uses steady pen progress and slight letter
overlap, softly resolves the receipt instead of clipping it into a wedge, and
crossfades the ink out as the glossy logo appears. Centered layout is retained.
Android startup vectors now use matching linear timing, contour-length-based
stroke pacing and a gradual silhouette fill. Flutter's background and logo widget
instances remain stable on animation ticks, with separate repaint boundaries for
logo/captions/footer instead of rebuilding the full scaffold each frame.

Validation: 18 focused tests passed (final-tests.log); includes old and new letter
boundaries, receipt/gloss transition, centered layouts, retained widget instances,
startup handoff and session routing. Letter-boundary changes are below 0.01 after
fixing; all 17 boundary checks are below 0.05 (preview/letter-completion-deltas.json).
Targeted analysis: No issues found (final-analyze.log). Inspected motion-review.png
and created 217 rendered frames, 50fps GIF and 60fps MP4 previews. Preview rates
are rendered output rates, not measured device playback frame rates.

Final ARM64 profile APK built in 146.5s, 91.4MB (final-apk-build.log), copied as
apna-pos-smooth-splash.apk, installed with Success and cold-launched Status ok,
PID 14823. Device log counts 0 unhandled exceptions, fatal errors, ANRs or native
inflation errors. Evidence is under build/splash_smoothness/.
Device thermal status remains 3, so no controlled on-device FPS claim is made.
A native screenrecord attempt produced no frames and timed out; the sleeping
orphan recorder (PID 9008, CPU time 00:00:00) could not be signaled because Android
denied both normal stop and kill. No recording performance figures were used.


## Complete the splash logo before navigation

Two new regression tests failed on the prior code: native elapsed time could
jump directly to 1.0, skipping Flutter's receipt/gloss phase; normal completion
could navigate before the full artwork had a readable hold. Capped native handoff
at the receipt reveal start (2680/3600), preserving the ending animation after a
slow launch. The final painted frame now holds for 650ms before navigation.
The hold runs independently of initialization, with no extra wait once it has
already elapsed, and is skipped for reduced-motion/muted-ticker paths.

20 focused completion/splash/alignment/smoothness tests pass (final-tests.log).
Targeted analysis: No issues found (analyze.log). ARM64 profile build succeeded
in 159.9s (91.4MB), copied to apna-pos-complete-logo.apk and installed with Success.
Cold launch Status ok, TotalTime 2894ms / WaitTime 3141ms. Real phone screenshots
final-stage-1.png and final-stage-2.png visibly show the entire glossy original
logo, including receipt and flourish; final-stage-3.png shows the subsequent POS.
Evidence and installable artifact: build/splash_completion/.

## Restore the receipt in Android's launch animation (2026-11-15)

The user's small startup-logo screenshot exposed a separate native-artwork bug:
`tool/generate_android_startup_writing.py` explicitly skipped glyph 8 (receipt).
Flutter's complete glossy artwork was correct, but Android only drew the words
and right flourish. Removed the skip and traced the original atlas into blue
receipt border, white paper and navy print layers. All three reveal together at
2680-3040ms. The native artwork eases from wordmark-centered to full-logo-centered
coordinates, keeping the receipt inside Android's safe circular icon area.
Flutter's late-native handoff cap now reserves the glossy resolve at 3000/3600
without replaying the completed native receipt from invisible.

Evidence: build/native_receipt/. Three native XML regression checks failed
before the change and pass afterward (native-tests.log). The generated-vector
preview contains all three receipt layers and zero pixels outside the safe icon
circle (visual-check.log, native-screen-preview.png). 20 focused Flutter tests
pass (flutter-tests.log); the strengthened late-handoff test also passes
(handoff-tests.log). Targeted Dart analysis has no issues (analyze.log).
ARM64 profile APK built successfully in 182.1s (final-apk-build.log), copied to
apna-pos-receipt-logo.apk and installed with Success (final-install.log).
Cold launch Status ok, Activity 2734ms / WaitTime 2807ms (final-launch.log).
Inspected final-device-startup.png: full glossy receipt/paper/three printed lines
remain visible in Flutter. Native artwork verified through generated XML,
packaged resources and its rendered preview; the phone capture is the Flutter
stage. Startup log scan found no fatal, unhandled, ANR or XML inflation errors.

## 2026-11-15: POS and Business Settings tab-switch work reduction

User reports glitches when switching screens and opening dialogs, particularly POS and Business Settings. Preserved concurrent Chotu, splash, and product-video edits.

Changes: product media now respects the existing tab TickerMode, pauses native videos and slide timers while hidden, avoids starting decoders for initially hidden tabs, and resumes existing controllers on return. Multiple visible POS videos still play concurrently. In-flight initialization checks visibility before starting playback. POS skips database-driven catalog redraws while its tab is hidden and reads current shared data on return. No cart mutation, checkout calculation, KOT, or settings save rules changed.

Settings hub logos now decode at their actual display size times device pixel ratio (up to 1024 pixels) for memory/network/file/asset sources. Bounded the existing base64 cache to eight entries instead of retaining every edited logo indefinitely. UI appearance, form fields and controls are preserved.

Verification: combined media, quantity-performance, checkout-recovery and checkout-roundoff suites returned 25 passed. Includes two-video tab hide/resume without decoder recreation, initially hidden tab with zero decoder allocation, three-video simultaneous playback, hidden DB-update catalog test, quantity bursts, draft/table isolation, cancellation recovery and totals. Five selected Settings hub checks pass: profile edit/save, compact mobile layout, POS View, payment modal and PIN modal. Updated old test assumptions to allow both existing ONLINE badges and scroll the payment card into view before tapping. Targeted six-file analysis: no errors/warnings; three existing brace style infos. git diff --check passed.

Limits: no physical phone FPS/thermal profiling or installation was performed. These changes remove demonstrated background work; they do not establish that all reported device glitches are resolved. No new APK was built or deployed in this task.

## 2026-11-15: Compact professional product detail popup

Replaced the dense, glowing POS popup with a white card, smaller title/price
and secondary type, restrained stock/GST labels, equal-width size options and
one neutral nutrition panel. Photo/video and original nutritional estimates
remain; estimates are labeled. Quantity/Add are in a fixed footer, with scroll
in the body and responsive two-column tablet layout. Close remains reachable.

Extracted presentation to pos_product_detail_dialog.dart. The register retains
its original variant MenuItemModel mapping and _addToCart call. Comparison
against a pre-edit snapshot confirms all register code outside this method and
its replacement import is unchanged (Unrelated register source preserved: True).
No backend or production order changes. Other dirty files preserved.

Evidence: dialog-tests.log reports 11 tests passed: selected size/quantity and
exactly one callback; quantity floor and stock cap; out-of-stock denial; close
without cart mutation; single-price discount/Non-GST; 320x568, 390x844,
640x360, 1024x768 and 2x text scaling. The footer stays fixed while details
scroll. pos-regressions.log reports 14 media/checkout checks passed.
analyze.log reports No issues found for the new widget, register and tests.
The first stock test finder matched Flutter's RawTooltip instead of IconButton;
corrected the finder and reran. Capture initially needed an awaited memory
image decode; final capture asserts the photo is decoded before saving.

Visually reviewed product-details-390.png with the actual product photo,
Roboto and Material icons. Tablet layout also rendered at 1024x768. Evidence:
build/product_details_validation/. Android APK build pending at this entry.

Final product popup delivery: assembleProfile succeeded in 344.3s and produced
app-profile.apk (91.4 MB). Copied to
build/product_details_validation/apna-pos-product-details.apk. Verified the
product-detail-add, product-detail-scroll and Close product details markers
inside the packaged ARM64 libapp.so. adb install -r returned Success. Both
phone and tablet final photo previews were visually reviewed. No production
cart, KOT, bill or payment was submitted for verification.

## 2026-11-15: Reduce product popup height and whitespace

Shortened mobile media from 140-184 to 104-132 logical pixels and wide media
from 280 to 220. Reduced body/section/footer padding, combined category and
availability, tightened size choices and moved the health score into the
nutrition heading. Four metrics share a row on ordinary narrow phones; large
text retains two columns. Information, cart callback and stock rules preserved.

All 11 existing dialog/render checks passed (compact-tests.log), including
quantity/variant outcomes, stock cap, 320x568, landscape, tablet and 2x text.
Widget analysis: No issues found (compact-analyze.log). Visually reviewed final
phone capture with the actual pizza photo. PNG center-column bounds comparison
at 390x844: card height 679 -> 499 logical pixels, a 26.5% reduction. Evidence:
build/product_details_validation/compact-height-comparison.json and
product-details-390.png. Android profile build in progress at this entry.

Compact follow-up final delivery: assembleProfile succeeded in 252.2s,
91.4 MB. Copied to build/product_details_validation/apna-pos-product-details-compact.apk.
adb install -r returned Success on the connected phone. Phone and tablet
previews reviewed; all information and existing cart behavior retained.

## 2026-11-15: Correct product photo/video proportions

The very shallow compact frame plus cover fitting clipped the food. Also found
all seven image paths decoding to fixed 480x480, which changes non-square source
proportions. Kept the tight details but gave the popup a bounded 16:9-based media
frame (140-180 on phones), contain fitting and 960px photo decoding. Grid stays
cover/480px. Removed fixed decode height to retain natural aspect ratios for
asset, base64, network, local and fallback images. Contained initialized video
uses a neutral canvas, preventing a different thumbnail showing through the
video margins. No playback allocation, cart, quantity or backend changes.

Final tests: 24 passed across dialog, image fitting and media playback suites
(media-fitting-tests.log). New portrait/landscape photo checks verify actual
decoded proportions; portrait/landscape video checks verify the rendered frame
stays inside the canvas and preserves its ratio. Existing concurrent playback,
cancellation, failure recovery, quantity, variant and enlarged-text checks pass.
Initial real-image capture fixture needed precaching before opening the dialog;
loading the file inside fake async had stalled the fixture. Corrected it and
reran successfully. Final captures now use the actual PosProductMediaBox rather
than a stand-in Image widget. Visually reviewed product-details-390.png with
the full pizza photo visible. Build and analysis under
build/product_details_validation/ (media-fitting-*). Android build pending.
Media fitting analysis: no errors or warnings; three existing brace-style
infos in pos_product_media_box.dart. Other in-progress changes preserved.

## 2026-11-15 — Customer storefront redesign and Android build repair

- Replaced the generic loader with a menu skeleton using the requested restaurant identity/theme; removed the forced loading delay and retain the menu during refresh.
- Public menu/profile/categories/products/media/banners/status/hours/theme load from the restaurant API. Removed synthetic rating/review/ETA/coupon/banner fallbacks and global merchant-logo fallback. Unknown restaurants return 404 instead of another merchant's menu.
- Business settings persist storefront configuration; settings updates preserve allowed fields when profile history exists. Explicit merchant preview still uses that merchant's local data.
- Fixed pasted build errors: missing OrderStatus import, nonexistent MenuItemModel.portion, wrong socket rejectionReason argument (uses reason). Kept selected variant information in existing item name/notes. Corrected two invalid case-insensitive table regex patterns.
- UI verification initially caught banner horizontal overflow at 320/390 px; constrained banner text/actions and reran. Cart verification caught snackbar covering the cart action; moved feedback above the cart bar.
- Verification: flutter test test/storefront_dynamic_menu_test.dart test/storefront_restaurant_loader_test.dart — 7 passed. Covers loading/branding, API content, search/category, customization/cart, refresh/offline, unknown restaurant, compact currency layout, empty/refetched API catalogs.
- Verification: backend npm test -- --runTestsByPath tests/storefront_dynamic_data.test.js tests/table_qr_ordering.test.js — 2 suites, 7 tests passed. Covers tenant isolation, real configuration/media, branding query, empty menu/no fictional tables, unknown tenant orders, persisted settings with history, existing table ordering.
- Verification: focused Flutter analysis completed with 0 errors/0 warnings and 11 style infos. Broader analysis includes existing warnings in database/checkout/incoming order files.
- Verification: flutter build apk --debug — Built build/app/outputs/flutter-apk/app-debug.apk (31.5 seconds on final completed run).
- Captured and visually inspected build/storefront-review/restaurant-menu-390.png, restaurant-menu-320.png, restaurant-loading.png using API response fixtures and bundled asset images; no horizontal overflow. Test images use fixture content, not production data.
- Live backend deployment/device payment testing were not performed; the updated backend must be deployed for live storefront configuration changes.

## 2026-11-15 — Incoming order accept redesign / table number

- Redesigned incoming order review around a prominent Table N card, customer actions, item notes/variants, totals, a wrapping prep-time grid and fixed bottom actions. Visually inspected 390 px and 320 px screenshots (320 px includes 1.2 text scale). No layout overflow in the new view.
- Root cause: socket notification payload/metadata dropped tableNumber; null-only fallbacks accepted blank values over valid aliases/nested data. Added shared normalization at socket/FCM/local notification/screen entry points. Also stopped inferring table numbers from street-name T characters in stored order parsing. Explicit stored table-code formatting is retained.
- New view updates when a local order with table details arrives after the alert. Countdown updates only its timer widget. Existing accept/decline/prep-time/KOT/table-sync callbacks retained.
- flutter test test/incoming_order_payload_test.dart test/incoming_order_accept_screen_test.dart test/storefront_dynamic_menu_test.dart test/storefront_restaurant_loader_test.dart with capture font environment: 21 passed. Includes table aliases, empty/nested payloads, JSON FCM metadata, persisted code formatting, no false table from street, late table update, prep selection, mute/countdown isolation, decline dialog and compact layouts, plus prior storefront checks.
- Backend: npm test -- --runTestsByPath tests/table_qr_ordering.test.js tests/storefront_dynamic_data.test.js — 2 suites / 7 passed.
- flutter build apk --debug — Built build/app/outputs/flutter-apk/app-debug.apk; final log build/incoming-order-final-build.log, 63.2s.
- Static analysis found no compilation errors; existing protected notifyListeners warnings remain in the retained table-sync action. No AGP/Kotlin dependency upgrades were needed.
- Broader-suite limitations: existing test/table_ordering_flow_test.dart does not compile because its model fixtures omit required description/tagline/profile fields. A no-font-capture run of the prior storefront checkout test exposes a 13 px overflow with Flutter's Ahem test font; it passes with the real visual-test font. These failures are outside the redesigned incoming view and are not reported as a clean full-suite run. Production checkout behavior was not changed in this task.
- Evidence screenshots: build/incoming-order-review/table-order-390.png and table-order-320.png. No physical-device QR/payment/printer validation or deployment performed.
- Final default-environment check (without capture/font variables): incoming_order_payload_test + incoming_order_accept_screen_test — 14 passed in 4 seconds; build/incoming-order-default-tests.log.

## 2026-11-15 — Order source, saved ringtone and Notification Settings

- Order review shows an independent source label: WhatsApp, Online (storefront/profile/QR), or Store (store/POS/counter/local). Non-QR dine-in sources are labeled DINE-IN ORDER rather than incorrectly implying a QR origin.
- Root cause of locked-screen silence: native FCM notification was explicitly silent and deferred playback to Flutter. Added OrderRingtoneService, a single mediaPlayback foreground-service player using the saved local/preset audio and saved volume/mute preference. Native FCM starts it without waiting for the screen. MainActivity bridges foreground play/stop; Dart now loads saved preferences before playing and cancels delayed startup after stop. Existing non-Android audio fallback remains.
- Custom audio is persisted to a native-readable cached source; uncached/unavailable custom files fall back to the bundled order sound. Confirmed Android shared_preferences double encoding in the installed plugin source and decode the actual DOUBLE_PREFIX. Cached downloads run asynchronously so saving preferences does not wait on network audio.
- Native notification mute and accept/reject stop playback; matching handled-order events stop their active alert. Playback has a three-minute failsafe, loop deduplication, foreground notification, and OS notification fallback if service start is denied. Zero volume/global sound-off remain silent.
- Notification Settings now matches the rounded app surfaces, dark hero, green controls, real business name, wrapped section links and fixed Save footer. Preserved presets, custom upload/delete, previews, volume sliders, preferences and permission controls. Removed fabricated synced/merchant defaults. Cached controls stay visible but cannot be edited until loading finishes. Fixed API response map parsing in DatabaseService.fetchNotificationSettings.
- Validation: 27 tests passed in build/alerts-default-tests.log (11s), and 27 visual-font checks passed in build/alerts-final-tests.log. Includes all three source types, native bridge start/stop, stop-during-start race, zero volume, native saved selection, settings save interactions, 320/390 px layouts, and prior incoming-order/table payload regression cases.
- Static analysis: build/alerts-final-analysis.log — No issues found (5 focused files).
- Android compile: build/alerts-final-build.log — Built build/app/outputs/flutter-apk/app-debug.apk, 41.6s. Fixed a Kotlin outer action-variable shadowing Intent.action caught during final compilation.
- Visually inspected build/alerts-review/notification-settings-390.png and build/incoming-order-review/table-order-390.png; compact layout also captured at 320 px.
- Native design reference: https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start and https://developer.android.com/develop/background-work/services/fgs/service-types . Android high-priority FCM allows attempting foreground playback; denied starts use the notification fallback.
- Limits: did not install on the connected user's phone or submit synthetic orders to their live business. Real-device locked-screen delivery/audio, uploaded custom audio and vendor battery-policy behavior remain unverified. No backend deployment or external customer messages were performed.

## Meta/WhatsApp setup audit, redesign and PRD/TRD � 2026-11-15

Implemented the WhatsApp Business connection screen with Connection, Templates
and Business profile tabs, focused setup steps, real status/error states and
responsive layout. Reviewed generated 320/390/1280px Flutter captures under
build/meta_partner_redesign/; the real-font 390 and 1280 captures show the intended
layout. Added a service injection seam for deterministic UI/action testing.

Root causes fixed in Meta setup: OAuth code ignored and replaced with fixed
account IDs; missing account synthesized from shared defaults; PIN/subscription
provider failures swallowed; template sync/approval and analytics fabricated.
Implemented server-side code exchange and WABA-phone ownership validation,
short-lived hashed browser capabilities with atomic one-use consumption,
role-restricted setup routes, exact Facebook event-origin checks, nonce CSP,
configuration-driven signup without the retired sessionInfoVersion 3 override,
real registration/subscription responses, atomic independent setup flags,
real template submission/status and tenant chat-store analytics. Invalid Meta
tokens request reconnect via 409 rather than triggering POS auth logout.
Chat sends now select the enabled business sender; connection status no longer
restores a seed sender, mirrors credentials or returns its access token.
Broader legacy credential/settings paths remain documented TRD boundaries.

PRD: docs/meta-partner/PRD.md. TRD: docs/meta-partner/TRD.md. Local key-presence
check confirms META_APP_ID/META_APP_SECRET/META_EMBEDDED_SIGNUP_CONFIG_ID/
META_PUBLIC_BASE_URL are absent; no secrets printed by that check. Removed the
source-contained provider secret; rotation of historical copies remains a live
release prerequisite. No provider configuration or backend deployment performed.
No real customer messages or live Meta registration actions were performed.

Validation: 8 new service regressions failed against the old implementation.
Final backend setup/lifecycle/routes/appsecret/chat suite: 38 passed, 5 suites
(regression-tests.log). Existing chat fixtures now explicitly configure a tenant
sender and expect no token from connection-status responses. Lifecycle checks
use real MongoMemoryServer storage and simulated Meta calls. Latest browser
bridge changes rechecked in final-routes.log. Combined incoming order payload,
acceptance UI and Meta UI suite: 24 passed (combined-flutter-tests.log), including
narrow large text and PIN submission. Fixed test scrolling to wait for actual
hit-test visibility with either Ahem or real fonts. Targeted Dart analysis:
No issues found (analyze-final.log). git diff --check passed.

Additional Table 2 finding: orderService high-priority closed-app push omitted
tableNumber although sockets retained it. Added the field; actual generatePosOrder
integration regression passes and asserts the saved T02 reference in the emitted
push (table-qr-push-test.log). The shared-workspace incoming-order redesign and
payload normalization were preserved and their tests included above.

ARM64 profile APK built successfully in 411.8s (91.3 MB; apk-build.log), copied to
build/meta_partner_redesign/apna-pos-whatsapp-setup.apk. libapp.so marker check
confirms the redesigned headings/actions are packaged (packaged-check.json).
SHA256 c05b0cb55fc4807a619621865fb0e9e67237ba07df230ad4b460148c91e33a53.
Installation attempted but adb reported no devices/emulators; mDNS found none.
This APK was not installed. Live acceptance and remaining legacy-system hardening
are explicitly listed in the TRD rather than claimed complete.

## WhatsApp setup text visibility and UI refinement � 2026-11-15

Reproduced the actual app-theme mismatch: the new screen was painted light while
inheriting GlassTheme.themeData (dark). A regression test expected Brightness.light
and observed Brightness.dark before the fix (build/meta_ui_readability/before.log).
The root navigator also inherited a transparent dark dialog theme.

Added a scoped complete light theme for page and root-navigator dialogs, opaque
white dialog surfaces, dark input/cursor/label colors and explicit readable button
states. Retained the parent's font family in component typography so button and
dialog labels use the same fonts as the page. Refined the UI with white account
cards, blue full-width connection actions, outlined step actions, a shorter header,
14-15px supporting text, darker secondary text, setup progress and responsive app
bar height for enlarged text. PRD P08/P11 reflect these visibility requirements.

Evidence in build/meta_ui_readability/: 10 focused tests pass with the real dark
GlassTheme parent, including PIN validation/submission, offline retry, templates,
profile fields, 320/390/1280 widths and 1.4x/2x text. analyze.log: No issues found.
Computed contrasts (contrast.json): body/white 15.16:1, secondary/canvas 5.55:1,
primary action 5.44:1, disabled action 5.39:1. Captured and visually inspected
meta-setup-390.png, meta-pin-dialog-390.png, meta-profile-dialog-390.png and
meta-large-text-390.png. All labels/buttons are readable in the final captures.
Android build/device result recorded below after completion.

Android ARM64 profile build succeeded in 134.6s (91.3 MB; apk-build.log).
Copied to build/meta_ui_readability/apna-pos-readable-whatsapp.apk and verified
all four new UI markers in libapp.so (packaged-check.json). Wireless ADB was
briefly reconnected to the discovered phone but went offline before completion;
final adb devices list is empty and mDNS has no service. APK not installed and
no phone screenshot claimed. Final preview/test evidence remains locally verified.

Build verification detail: Gradle wrapper log records exit 0 and Flutter reports
Built app-profile.apk. PowerShell's outer process reported 1 after a Java
restricted-method WARNING was classified as NativeCommandError in redirected
stderr. The APK was generated and its new UI markers verified. This is not a
Dart/Gradle build failure; no unrelated toolchain upgrade was made.

## 2026-11-15 — Notification text visibility and readability

- Cause: main.dart installs GlassTheme.themeData (dark), while Notification Settings and inbox use light surfaces. Header/default control/dialog text inherited the wrong theme. Earlier settings visual tests used a standalone light ThemeData, so they did not exercise the app's real theme.
- Added a local NotificationScreenTheme with explicit light surface/text/control/dialog styling, preserving the parent font family. Public screen wrappers place the existing stateful content below that theme so dialogs inherit the same readable colors. The app-wide dark theme remains intact.
- Notification Settings now has a readable navy/white app bar, compact light introduction, larger labels, multiline ringtone names, stronger semantic colors, and the fixed Save footer. Existing selections, previews, uploads, sliders, saves and preferences retained.
- Redesigned inbox header to fit narrow screens with unread summary, refresh and existing menu actions. Notification titles now wrap at full card width; timestamps appear below titles; message text is larger. Grouping, navigation, read state, filters and API callbacks unchanged.
- Tests now mount both screens inside the actual GlassTheme with 1.2 text scale at 320 and 390 px. Settings verifies light-theme isolation/body contrast and saved ringtone selection. Inbox uses mocked API fixtures and checks mark-all-read and Inventory filtering. Fixed the test's app-lifetime polling timer ownership without changing production polling.
- Verification: build/notification-readability-final-tests.log — 12 passed (including prior saved/native ringtone checks). build/notification-readability-final-analysis.log — No issues found, 5 focused files. git diff --check clean apart from line-ending notices.
- Screenshots captured and visually inspected: build/notification-readability-review/notification-settings-390.png and notifications-inbox-320.png; companion 320/390 sizes also generated. Confirmed readable header, full notification titles and body contrast under real parent theme, enlarged text.
- Final APK: build/notification-readability-release-check.log — Built build/app/outputs/flutter-apk/app-debug.apk, 35.5s. App was not installed on the connected phone, and no production notifications/customer messages were sent.

## 2026-11-15 — Campaign Studio redesign and code review

- Reviewed the active CampaignScreen -> WebCampaignPortalScreen -> CampaignDashboardView path, dashboard service, and creation-result handling. Preserved shared NeumorphicTheme tokens referenced by other campaign views.
- Replaced the duplicated dashboard layout with CampaignStudioLayout: reference-inspired purple studio canvas, bundled phone artwork, create/automation/audience actions, live API performance tiles, actual wallet balance, status/category filters, template search, lazy template grid and campaign list. Mobile stacks panels; wide screens use side-by-side panels. Portal isolates light surfaces from the app's dark theme and includes safe-area/back handling.
- Removed fabricated wallet balance and invented performance campaign fallback. Fixed out-of-order status request handling while keeping status-specific API queries and existing detail/template/create callbacks.
- Creation API failures no longer synthesize local running campaigns, delivered-message totals, spent amounts or delivery timelines. Draft and dispatch/publish failure UI now reports unsuccessful creation instead of success.
- Detailed review and remaining integration findings: docs/campaign-studio-review.md. In particular, dispatch still has pre-existing fixed sender/offer values, service reads silently fall back to singleton caches, and setup/catalog defaults can imply connection/approval. These are documented follow-up integration risks rather than claimed verified live sending.
- Test development initially hit invalid mock JSON map typing; corrected fixtures to emulate decoded API JSON. Final: build/campaign-final-verified-tests.log — 9 passed. Also build/campaign-default-tests.log — 9 passed without visual capture/fonts. Coverage: 320/390/1100 px + enlarged text, live metrics/real zero wallet, callbacks, templates/search, draft API status filtering/detail selection, request ordering, no invented performance record, failed/successful backend creation, actual dark-parent theme isolation.
- Visually inspected phone and desktop captures in build/campaign-review/campaign-studio-390.png and campaign-studio-1100.png; 320 px capture also generated. Artwork and figures use API fixtures/bundled assets, not live merchant data.
- Focused analysis (build/campaign-final-analysis.log): no errors/warnings; 14 curly-brace style infos. git diff --check has no whitespace errors (line-ending notices only).
- Final Android build: build/campaign-final-verified-build.log — Built build/app/outputs/flutter-apk/app-debug.apk in 55.5s.
- No live campaigns, external customer messages, wallet top-ups, Meta account changes or deployment performed. Other dirty workspace changes were preserved.

## Incoming order push transport audit � 2026-11-15

Android urgent-order pushes were already data-only in both v1 and retained legacy
payloads; notification blocks are removed so client handlers can construct their
own full-screen/action notification. Found a separate zero-TTL delivery gap:
messages not immediately deliverable were discarded. Bounded urgent Android
order retention to 90 seconds while keeping HIGH priority, order-specific collapse
keys, serialized item/table details and existing general/iOS settings unchanged.

New transport regression before change: 2 failed / 2 passed (push-before.log).
After: 9 passed across 3 suites (push-tests.log): incoming transport contract,
actual Table 2 push reference generation, and existing accept/reject/broadcast
order flow. git diff --check for changed backend files passed. Evidence under
build/full_screen_orders/.

The existing order-flow suite initially contacted configured FCM for its explicit
invalid fixture token; provider rejected it (400, invalid registration token),
so no device received a notification. The suite now mocks service-account lookup,
OAuth and fetch; final test run performs no external provider sends or real orders.
No production database changes or real customer messages were made.

Official references: https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan
states ttl0 discards messages that cannot be delivered immediately. Force Stop
in Android Settings still requires manual app reopen, per
https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages .
Native audit: installed FlutterFire receiver directly routes to foreground LiveData
or its background service, while the Google SDK receiver is also merged. Root/native
agent notified that receiver/service dispatch must be verified and deduplicated;
manifest service priority alone does not prove which native alert path executes.

## Full-screen order alert permission (delegated permission work, 2026-11-15)

The manifest declared USE_FULL_SCREEN_INTENT but did not check Android 14's
special-access grant or offer its settings screen. Added native grant/requirement
checks plus app-specific ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT. Its method
channel result resolves after returning from system settings, via activity result
or resume fallback; no setting is granted by app code. Fresh permission setup is
runtime -> battery -> full-screen -> existing overlay, with full-screen awaited
before another settings screen can launch. Existing installs with the old
post-login flag still receive the new once-only full-screen request. Denials are
remembered to avoid reopening settings on every navigation. Android 13 and iOS
keep their existing flow.

Notification settings now exposes Full-screen order alerts / Allow when needed,
rechecks on resume and only shows Allowed after a fresh native check. Critical
Android alert readiness includes the special-access grant.

Evidence: build/full-screen-permission-tests.log: 20 tests passed, including the
15 post-login cases, 3 full-screen service/manual-settings cases, and 2 existing
notification settings/ringtone-save cases. Manual suite rechecked separately:
build/full-screen-permission-manual-test.log, 3 passed. Targeted five-file Dart
analysis: No issues found (build/full-screen-permission-analysis.log). Visually
reviewed build/order_full_screen/full-screen-order-permission-390.png; title,
help text and Allow action are readable. Native compilation/live system-settings
behavior is left for the parent agent's coordinated Android build/device check.
No live permission grants or order/API behavior changed in this subtask.

## Native incoming-order dispatch regression � 2026-11-15

FlutterFire 16.7 uses a manifest broadcast receiver to feed foreground LiveData
or its background engine; a custom FirebaseMessagingService alone does not cover
that path. The Google SDK receiver remains a separate service path, so both must
share a native dedupe gate. Replaced the FlutterFire receiver registration with
OrderWakeBroadcastReceiver (a subclass) that performs native order alert work
under goAsync on an executor, then forwards one explicit, marked internal
broadcast before delegating to the plugin's own receiver implementation. This
retains a distinct valid PendingResult for the plugin and keeps preference I/O
off the main receiver thread. Ordinary messages delegate directly.

Added IncomingOrderAlertDispatcher and pure OrderAlertPolicy: ignore local POS,
chat/payment order references, and handled orders; retain table/order data;
persist pending payload before launching; route foreground data through
MainActivity.notifyIncomingOrder; dedupe the two native entry points. Background
notifications use unique order/mode PendingIntent URIs, API35+ creator activity
start options, the real FSI permission state, notification-first presentation,
ordinary user-tappable fallback and the existing granted-overlay direct path.
Removed self-sending of a PendingIntent as a claimed BAL bypass and stopped
silencing alerts merely because the native ringtone was already running.
Existing ringtone service and explicit Accept/Reject actions remain.

Validation: JAVA_HOME points at Android Studio JBR; :app:testDebugUnitTest exited0,
BUILD SUCCESSFUL in1m54s, 418 tasks. Six pure Kotlin policy tests, 0 failures and
0 errors. build/order_fullscreen_native/gradle-tests.log and manifest-and-tests.json
record proof. The merged debug manifest contains the app receiver protected by
com.google.android.c2dm.permission.SEND, omits the replaced plugin receiver, and
retains Google's SDK receiver. Native source diff whitespace check passes.
The later tiny dispatcher.cancel helper must also compile in the root's final
profile build. No live FCM push or user order was submitted by this subtask.

## Incoming order full-screen presentation and permission � 2026-11-15

User requested the accept screen for foreground, background and normal app closure,
plus the full-screen notification permission request, preserving existing actions.

Coordinated native, Dart, permission and backend fixes. Native receiver/SDK service
now share a protected, deduped dispatcher; FSI notification is posted before screen
wake, activity PendingIntents are per-order/per-action and opt in where newer
Android requires it. Native receiver delegates to FlutterFire rather than dropping
normal delivery. A native-owned flag prevents a second Dart notification/ringtone.
Manifest merge retains Google's receiver and replaces the Flutter receiver with
our SEND-protected subclass.

Root fixed warm onNewIntent delivery through com.apnapos.app/incoming_order,
persisted launch payload reload (native/background cache mismatch), consistent
incoming/handled/local POS/chat classification, native notification cancellation
from Dart, action preservation on cold local-notification launch and splash,
explicit Accept/Reject forwarding to an already-open screen, and terminal updates
before UI presentation. Review found the in-memory native queue bypassed old stale
checks; the common handler now applies the existing15-minute limit. A bounded
native handled-key map prevents a paused in-memory queue from reopening an order
handled during background delivery. Native fresh review clears stale action keys.

Permission flow uses Android14+ canUseFullScreenIntent and app-specific settings.
New once-only migration flag prompts existing installs despite the old completed
post-login flag. Results wait for return before overlay request. Denials can be
retried manually in Notification settings without navigation repeatedly prompting.
Backend urgent Android data-only TTL was0, now90s; backend deployment is pending.
No live customer order or external test push was submitted.

Evidence: build/full_screen_orders/. Final Flutter regression suite62passed,
covering cache reload, cold/warm routes, duplicates, stale/handled queues, action
forwarding, permissions, table identity, ringtone and notification settings.
Six Kotlin tests pass and merged-manifest assertions pass (order_fullscreen_native/).
Nine mocked backend contract/order-notification tests pass. New action-forwarding
regression failed before fix (action-before.log). Targeted analysis has no issues
(final-analyze.log); accept-screen full analysis retains the existing two protected
notifyListeners warnings from pre-task code. Targeted git diff --check passed.

Final ARM64 profile build exit0 in84.0s,91.3MB (final-apk-build.log). Package markers
validate dispatcher/receiver, permission request, upgrade flag, native Dart bridge,
and handled-key storage. APK apna-pos-full-screen-orders.apk SHA256:
cfe8c5303bc3b265587dcebaae242e3654e9780d823e58825493451eb3431afa.
Installed final APK on OPPO CPH2637 with Success (final-install.log).
Earlier staged APK cold launch Status ok,3394ms Activity/3436ms WaitTime.
Inspected device-after-launch.png: native-backed Notification settings shows
Full-screen order alerts Allowed and Display Over Other Apps Allowed. No grant
was changed through automation. Device-launch log includes secure-storage key
recovery/decryption warnings; no FATAL/ANR observed in the captured startup.

Limits: live end-to-end closed-app FCM arrival was not exercised. Android controls
FSI versus heads-up on unlocked devices and blocks push after Settings Force Stop
until manual reopening. This is covered in docs/notifications/INCOMING_ORDER_ALERTS.md
with official Android/Firebase references; no claim of bypassing those restrictions.

## Logo animation GIF export � 2026-11-15
Rendered the unchanged LogoWritingReveal painter into 88 PNG frames (600x600, 25fps), then encoded exports/Apna-POS-Logo-Writing.gif with a shared 256-color palette and final-logo hold. Flutter renderer passed; decoded all 85 encoded GIF frames: 4680ms, infinite loop, 1,837,941 bytes. Inspected writing midpoint and completed receipt/glossy-logo frames. Copied GIF to the user's Downloads folder. Reusable rendering/encoding tools: tool/export_logo_gif_frames_test.dart and tool/export_logo_gif.py.

GIF export palette refinement: reserved exact #F7F9FE to keep the canvas uniform; regenerated and verified final file size 1,828,253 bytes. Downloads copy matches the exported GIF.
Final encoding preserves exact background pixels during palette conversion; all 42,000 pixels in the 70px-wide canvas margin verified uniform #F7F9FE. Final GIF remains 600x600, 85 encoded frames, 4680ms, infinite loop.
Media fitting delivery completed. Android profile build succeeded in 201.9s,
91.4 MB. Copied to build/product_details_validation/apna-pos-media-fitting.apk.
adb install -r returned Success. Continued with the user's new request to fix
missing table QR and customer storefront merchant order notifications.

## 2026-11-15: QR/storefront merchant alerts and acceptance

Found nested CartItemModel items sent to a flat Mongo order schema, ignored API
failures followed by local success, hardcoded delivery in the customer path,
and different client/server IDs across the Firestore mirror. Customer item
snapshots also retained catalog variants, causing selected-size price lookup
to return the first variant. Merchant Firestore listening used the profile ID,
seeded all cached pending IDs as already notified, and omitted the native
system notification call.

Implemented a shared public order submission service for both checkout paths.
It submits flat selected item snapshots, retains the requested type/table,
waits for a valid server receipt, caches canonical IDs, and mirrors the server
receipt to Firestore. Customer-local caching suppresses merchant alerts. API
failure keeps the cart and pending request identity for retry. Backend accepts
legacy nested items, returns canonical receipt metadata, and uses a tenant-
scoped deterministic order ID to make parallel retries atomic without a new
index or migration. Socket acceptance events carry source/table/status/date.

Merchant Firestore uses currentBusinessId, keeps pending orders eligible,
checks account scope and freshness, posts a native notification, and opens the
existing acceptance route. Restored guarded recent-pending recovery on resume.
Fixed two acceptance-view overflows and restored a compact channel label.
Tracking displays Awaiting restaurant acceptance while pending. Preserved the
other in-progress storefront profile, network, view and Firestore rule edits.

Verification: 49 Flutter tests passed (order-flow-tests.log), including both
checkout APIs for QR/delivery/takeaway, selected variant price, server rejection,
retry identity, incoming payloads, warm/cold/resume/native notification actions,
handled order suppression, source/table display and small/enlarged text.
18 backend tests in five suites passed (order-flow-backend-tests.log), including
actual public HTTP submissions in MongoMemoryServer, legacy item payloads,
parallel replay, three merchant pushes and WhatsApp notification regressions.
No production order was created. A production read-only GET confirmed the live
pizza-47 slug resolves to canonical business 6ad46853ea47d6b3e13d633d.

Acceptance screenshots rendered with the actual screen (10 tests pass),
visually reviewed incoming-previews/table-order-390.png. Broad analysis has
only existing database/storefront diagnostics; the new submission helper has
its brace-style infos corrected. Final profile APK built in 109.8s (91.3MB),
installed with adb install -r: Success. Artifact
build/product_details_validation/apna-pos-order-accept-fix.apk.
Web release built in 83.9s under build/web, with production API_URL and copied
vercel.json. Configured GitHub main pushes auto-deploy Vercel and Render.
Live deployment approval requested through the asynchronous question. Await
that approval before publishing. Current branch main; unrelated dirty
firestore.rules and scratch/ must remain outside the order-flow publication.

## 2026-11-15: Approved live order-flow publication completed

User answered Deploy the live fixes. Published commit
 e5698f8288ab4876a788c19c83dfcb49a86664e8 to origin/main. Remote SHA confirmed.
Kept the unrelated firestore.rules and scratch/ work outside this commit.
Render public health is healthy and the live handler returns the new
Add at least one product to place an order validation for the deployment
probe. Probe supplied an empty cart and negative totals, causing validation
failure under both old and new handlers. No valid production order was sent.

GitHub web release build succeeded. Its token-based deployment step was skipped,
while the connected Vercel Git integration completed the apnaposs production
release at https://vercel.com/chandanyaduvanshi190-3791s-projects/apnaposs/Drannd9yncpSepZGw9jUvc1bPnei.
The separate apna-pos project check failed; it is outside the requested public
apnaposs project, which deployed successfully. Live apnaposs main.dart.js now
contains storefront_pending_ and Awaiting restaurant acceptance. Public
/pizza-47/R=R1&T=T02 returns HTTP 200; backend QR binding returns isValid true,
business 6ad46853ea47d6b3e13d633d, Table 2, isTableOrdering true, restaurant R1.
Evidence saved in live-order-deployment.json and backend-deployment-validation.json
under build/product_details_validation/. Handset alert delivery was not tested
using a real production order. Local automated verification remains 67 passing
checks and the updated APK is installed. Live publication complete.


## 2026-11-17 - Chotu voice, printing and settlement

Finalized plan implemented locally: confirmed Cash/UPI/Card, preserved issued
invoice money, durable native print jobs, better Hindi/Hinglish normalization,
microphone startup and foreground wake/Android assistant entry. 112 backend
tests, 12 Python, 76 Flutter regression checks and 19 final startup checks pass;
analysis clean and final APK built in 211.7s. Full evidence, test corrections,
artifact hash, screenshots and limits: docs/chotu-ai/VALIDATION_2026-11-17.md.
No production DB changes/deployment. No connected phone; live mic/printer/OEM
shortcut checks unavailable. Always-on background hotword remains a separate
phase. Existing journal bytes preserved because this file has mixed encoding.

2026-11-20: Native Chotu popup fixed and installed. Native startup card, one scoped initialization, readable light theme and blur removal. 34 Flutter tests pass; three-file analysis clean; APK 198.7s / 91.5 MB, install Success. Window timing: old WARM 4694ms, new COLD 2793ms (different states; not a controlled benchmark). Phone appearance/mic startup checked without orders. Closed-app hotword remains unsupported pending offline keyword model/service. Details and logs: docs/chotu-ai/POPUP_2026-11-20.md and build/chotu_popup_validation/.
