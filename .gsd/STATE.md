# Current task state

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
