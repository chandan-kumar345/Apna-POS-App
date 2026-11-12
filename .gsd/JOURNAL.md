# Task journal

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
