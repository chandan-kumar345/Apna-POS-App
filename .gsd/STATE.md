# Current task state

2026-11-17: Chotu voice follow-up implemented and validated locally. Confirmed
enabled Cash/UPI/Card settlement, preserved issued invoice money, immutable
native print jobs with durable claims, Hindi/Hinglish normalization and mic
startup. Opt-in two-minute foreground Hello Chotu and Android assistant entry
are added; background/lock/logout cancel capture/startup. Always-on background
wake is a separate phase, not enabled here. Plan/guide/evidence are in
docs/chotu-ai/VOICE_IMPLEMENTATION_PLAN_2026-11-16.md, VOICE_COMMANDS.md and
VALIDATION_2026-11-17.md. No manual register/checkout/orderService logic changed.
112 backend tests and 12 Python tests pass; 76 Flutter regression/render checks
plus 19 final startup checks pass. Fourteen-file analysis clean. ARM64 profile
APK built in 211.7s / 95,884,250 bytes. Artifact:
build/chotu_voice_validation/apna-pos-chotu-voice.apk. Screenshot and logs/hash
are in the same folder. No connected phone, so physical mic/printer/OEM shortcut
checks remain unverified. No production DB changes, orders, payments or live
deployment. Existing journal mixed-encoding bytes were preserved; evidence is
linked from its appended entry.

2026-11-15 completed: QR/storefront order alerts and acceptance fixes are
published as e5698f8288ab4876a788c19c83dfcb49a86664e8 on origin/main.
49 Flutter and 18 backend checks pass. Profile
APK 109.8s / 91.3 MB installed successfully, artifact
build/product_details_validation/apna-pos-order-accept-fix.apk. Web release
83.9s built at build/web with production API and vercel.json. User explicitly
approved live publication. Render serves the new empty-cart validation handler,
Vercel apnaposs production deployment succeeded, and live main.dart.js contains
the new request identity and acceptance-label code. Public QR route HTTP 200,
R1/T02 binds to canonical Pizza 47 business and Table 2. No production order
was created. Real handset alert delivery was not exercised with a real order.
Evidence: build/product_details_validation/live-order-deployment.json and
backend-deployment-validation.json. Publication and requested verification done.
See final JOURNAL entry for diagnosis, changes and test files. Main branch,
related dirty storefront/network/view edits predate this task and are retained.
firestore.rules and scratch/ are unrelated dirty work and should not be shipped.

Previous media fitting fix is complete, built 201.9s, installed Success.
Artifact build/product_details_validation/apna-pos-media-fitting.apk.

2026-11-15: Product popup compact follow-up complete. Shorter photo, inline
category/stock, tighter size/section/footer spacing and compact nutrition.
Phone render height 679 -> 499 (26.5% shorter). All 11 dialog checks passed;
widget analysis clean. ARM64 profile build 252.2s / 91.4 MB, adb install Success.
APK: build/product_details_validation/apna-pos-product-details-compact.apk.
Preview/measurement/logs in the same folder. No cart or backend logic changed.

2026-11-15: POS product detail popup redesigned per the user's screenshot.
Smaller type (title 15, price 20, body 11.5), neutral card, no glow, aligned
size choices and compact estimated nutrition. Photo/video and stock/tax data
retained. Quantity/Add footer stays visible while body scrolls. Presentation
extracted into PosProductDetailDialog; existing register cart/variant callback
mapping preserved. Snapshot comparison confirms all unrelated register source
unchanged. 11 dialog/render checks and 14 media/checkout regressions pass;
three-file analysis clean. Previews and logs: build/product_details_validation/.
ARM64 profile APK built (344.3s, 91.4 MB), with the new widget markers verified
inside libapp.so, and installed on the connected phone (Success).
Artifact: build/product_details_validation/apna-pos-product-details.apk.
Preserve other uncommitted user/session work; no commit requested.

2026-11-15: Chotu access/startup and compact transparent overlay implemented.
Root cause for Pizza 47: active subscription, absent canonical AI permission.
After explicit user approval, a native Mongo compare-and-set changed only
isChotuAiActive to true; original expiry 2026-11-17T06:43:19.746Z preserved.
Read-back now reports chotuAiAccess true. Audit:
build/chotu_validation/ai-access-repair.json.
Health checks retry/coalesce and distinguish auth/subscription/AI/runtime errors.
Voice starts after verified access; typed and voice use the server agent. No
manual POS edits in this task. Glass overlay removes illustration/setup badges,
examples and extra sections. Client/widget/receipt checks: 32 pass including
render capture; backend access/lifecycle: 58 pass. Targeted analysis clean.
ARM64 profile APK built and installed on OPPO CPH2637. Phone is at Login;
the user explicitly chose to finish without a live microphone test. No real
production order was submitted. Details: docs/chotu-ai/ACCESS_AND_SCREEN_2026-11-15.md.
Preserve concurrent splash and product-video changes; no commit/deploy requested.

2026-11-14: Rapid POS quantity lag fix implemented and installed on connected
OPPO CPH2637 as an ARM64 profile APK (build 140.0s, install Success, PID 8919).
30 taps: requests reduced 30 -> 1; unchanged card rebuilds 30 -> 0. Local cart
memory remains immediate. 50 edits persist one latest snapshot/notification;
cart writes are ordered per context and audio reuses prepared click sources.
59 focused/regression tests pass; eight-file analysis clean, database retains
five existing diagnostics. Two older isolation-suite cases also fail with saved
before-change sources; new burst/table switching test passes. See DEBUG/JOURNAL.
Native test: 1 + 20 rapid taps -> exactly 21 units, then all 21 removed. Test
T-5 returned Free and existing table totals were preserved. No KOT/bill/payment.
New log has 0 unhandled errors/audio timeouts/fatal exceptions in observed run.
Phone remains thermally throttled; no claim that all rendering jank is fixed.
Runtime limit: cached user restored without a valid backend token, so the phone
test verifies local response; real cloud sync awaits optional user sign-in.
APK: build/app/outputs/flutter-apk/app-profile.apk. Evidence: build/quantity_performance/.

2026-11-14: Splash handwriting slowed from 3600ms to 4800ms. Painter timing now
scales the authored strokes with normalized playback, so letters and receipt are
visibly slower. Existing artwork/transition and reduced-motion behavior retained.
23 splash/startup checks pass; targeted analysis clean; 49-frame Flutter render
and Get Started handoff pass and were visually checked. Preview:
build/splash_validation/writing_animation.gif. Android debug APK built in 109.7s
and packaged kernel verified: build/app/outputs/flutter-apk/app-debug.apk.
No physical-device installation was performed for this timing change.
Other uncommitted user/performance/subscription/Chotu work preserved.

2026-11-14: Fixed active subscriber upgrade-screen regression. Read-only inspection
confirmed pizza@gmail.com's Business/User/premium legacy records all active through
2026-11-17T06:43:19.746Z, with canonical Business controls missing. After explicit
user approval, one compare-and-set update copied only isSubscription=true and the
exact original expiry. Fresh centralized evaluation confirms active=true; AI
permission unchanged. No blanket migration or other account updates.
Client navigation refreshes before upgrade routes; active status suppresses the
sheet, removes existing barriers and returns an open subscription page to its
feature. Concurrent refreshes coalesce; prior-account responses are ignored;
explicit false clears cached state; rejected activation cannot fake local access.
UI design/manual POS preserved. 16 Flutter checks and 38 backend checks pass;
focused service/widget/test analysis clean. Broader changed-file analysis has no
errors and 27 existing warnings/infos. Debug APK built (75.2s) and packaged kernel
verified: build/app/outputs/flutter-apk/app-debug.apk. Not installed on a phone.
Exact evidence and changed files are in JOURNAL.md. Live read-back evidence:
build/subscription-account-repair-verification.json.

2026-11-14: Backend business entitlement implementation completed for the user's
attached request. Strict raw-BSON Business controls are authoritative; subscription
requires true + future expiry, AI adds its own true switch. JWT/membership and
paid-route/provider/background guards are enforced. Status aliases are calculated;
watchers notify without syncing legacy grants, and expiry never disables flags.
Verified renewal intents extend expiry atomically once and preserve manual flags.
Startup no longer provisions administrator privilege/default credentials.
Dry-run-default migration and operational Mongo examples are prepared in
backend/docs/ENTITLEMENTS.md; no production migration or deployment was performed.
No frontend edits were made for this task; earlier dirty UI/Chotu/splash work remains.
Verification: 62 distinct focused access/migration/background/subscription/auth
checks, 46 Chotu/profile regression checks and 3 existing restaurant webhook checks
pass. Final two changed suites: 36/36 pass. Commands and logs are in JOURNAL.md.
Compatibility: valid JWT required; old UTR-only unlock cannot securely activate;
legacy staff grants and mirrored flags are not access controls. Existing device
provider keys/offline badges cannot be revoked by backend-only changes.

2026-11-13: Chotu recognition/startup/UI follow-up implemented. Backend tests
49/49 and Flutter/phone rendering 27/27 pass; targeted analysis clean. Manual
POS flow untouched. See docs/chotu-ai/VOICE_FIXES_2026-11-13.md. Physical
microphone/printing verification and deployment were not performed.

2026-11-12: Chotu AI analysis, PRD/TRD and Python order agent implemented and
verified for online dine-in/cash. Python policy 12 tests, expanded agent API 26
tests and final Flutter/phone-render run 26 tests pass; focused Chotu analysis
is clean. Setup and limits: `docs/chotu-ai/README.md`. Verification evidence:
`.gsd/chotu-ai-VERIFICATION.md`. Existing unrelated edits preserved; not deployed.

2026-11-12: Initial permission prompts now run after authenticated navigation.

The earlier onboarding overlay dialog was removed. Android overlay setup opens
the native permission section directly after the remaining system prompts.
Startup, splash, FCM initialization, and iOS local-notification initialization
do not request permissions. One persistent completion flag and one in-progress
future prevent repeated or concurrent automatic setup sequences.

Validation: nine Android/iOS permission-flow checks, the app smoke test, and one
mobile rendering check pass. Actual login and POS register screenshots show no
custom permission dialog. Info.plist parses successfully. Analysis has no errors
and one unchanged warning for an unused FCM background-handler variable.

Detailed commands, results, and image locations are recorded in JOURNAL.md.
Native system approval was mocked, and no device installation was performed.

Earlier broader settings-suite assertion failures remain documented in the
previous journal entry; that unrelated suite was not rerun for this change.

2026-11-12: Launcher sizing and branded splash work is implemented. Seven splash tests, five rendered previews, targeted analysis, and 25 native artwork/XML checks pass. Resolved one adaptive icon antialiasing pixel outside the safe circle by leaving a 0.2dp margin. Android build/package verification is in progress; evidence is appended to JOURNAL.md.

Completed launcher/splash task: Android debug APK built successfully (56.6s), and package read-back confirmed all 25 native images plus the Flutter logo match. Seven splash behavior/layout tests, five visually inspected Flutter previews, targeted analysis, safe-bound checks, and diff whitespace checks pass. Updated APK: build/app/outputs/flutter-apk/app-debug.apk. Phone preview: build/splash_validation/phone.png.

2026-11-12: Immediate startup and logo writing animation completed.
- The app draws branding before startup services, runs optional service setup behind the splash, and restores the saved session before choosing its destination.
- The original logo is revealed by writing paths over 2600ms, followed by captions; navigation waits for completed text and restored data. Reduced motion, muted tickers and disposal are covered.
- All 10 splash checks and 10 app/permission regression checks pass. Focused analysis reports no issues. A 40-frame Flutter animation render passes and is saved at build/splash_validation/writing_animation.gif.
- Debug APK built and verified against the compiled kernel and logo. It was installed successfully on the connected phone, and cold launches return Status: ok. Phone screenrecord/capture could not provide trustworthy current frames, so native visual timing remains unverified. See JOURNAL.md for exact evidence.
- Deliverable: build/app/outputs/flutter-apk/app-debug.apk.

2026-11-13: Applied the reviewed handwriting splash and Get Started branding.
A-p-n-a and P-O-S write in isolated brand-colored ink, followed by the receipt and a blend into the original glossy logo. The 3600ms writing sequence ends with a fade-through to Get Started for both new and restored sessions, while preserving saved user data. Get Started uses the new transparent logo, stays readable on wider layouts, respects reduced motion and does not request permissions on entry.
Validation: 23 focused/navigation/permission tests pass, focused analysis is clean, actual Flutter animation and handoff frames were visually inspected, and the final Android debug build passed in 63.1s. APK verification confirms the original logo, new ink atlas and compiled kernel match the final build. APK: build/app/outputs/flutter-apk/app-debug.apk. Animation: build/splash_validation/writing_animation.gif. Welcome preview: build/splash_validation/get_started_new_logo.png. Exact evidence is in JOURNAL.md.

2026-11-15 POS/Business Settings performance: hidden tab video pause/resume and suppressed hidden catalog redraws implemented; logo decoding sized to display and base64 cache bounded. 25 POS/media/cart/checkout checks and five selected Settings hub checks pass. Targeted analysis has no errors/warnings, three existing style infos. No physical FPS verification, install, or deployment. Details appended to JOURNAL.md.

2026-11-15: Incoming order accept redesign and table-number propagation fix implemented. Targeted incoming/storefront visual checks: 21 passed; backend suites: 7 passed; debug APK built. Preview: build/incoming-order-review/table-order-390.png. Preserve the prior workspace's storefront/table-QR-download edits. Broader test verification is limited by pre-existing incomplete model fixtures in test/table_ordering_flow_test.dart and the prior checkout's Ahem-font overflow; see JOURNAL.md for scope and evidence.

2026-11-15: Fixed notification inbox/settings text visibility caused by inheriting GlassTheme's dark styling on light surfaces. Added local theme isolation and readable responsive layouts. Verified actual dark parent theme with enlarged text at 320/390 px, 12 focused checks, clean focused analysis, final debug APK build (35.5s). Screenshots in build/notification-readability-review. Existing source/ringtone and notification actions retained.

2026-11-15: Campaign Studio redesign + focused code review complete. Dashboard presentation separated, actual wallet/metrics preserved, request race and fabricated creation-success paths fixed. Nine targeted tests pass; final debug APK builds (55.5s). Screenshots in build/campaign-review; remaining sender/offer/cache integration findings in docs/campaign-studio-review.md. No customer campaigns sent or live wallet changed.
