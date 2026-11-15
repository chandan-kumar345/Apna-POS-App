# Chotu AI implementation roadmap

## Product detail popup redesign, 2026-11-15

1. Isolate the existing product presentation while preserving its add callback.
2. Implement compact typography, a quiet card layout and a fixed action footer.
3. Verify variant/quantity/stock behavior and responsive layouts, render previews,
   run relevant POS regressions and create the updated Android APK.

## Chotu access and transparent screen follow-up, 2026-11-15

1. Inspect actual business access and Python runtime; distinguish disabled AI
   from subscription/authentication failures.
2. Replace the opaque assistant screen with a compact glass panel and remove
   the large illustration, setup badges, examples and redundant text.
3. Retry failed health checks, start voice after verified access, and send typed
   and voice instructions through the authoritative order agent.
4. Verify access denial, retry, duplicate voice submission, small layouts and
   existing order lifecycle; render the real widget and build/install Android.
5. Apply the explicitly approved one-field Pizza 47 AI access repair, preserve
   the original subscription expiry and record read-back evidence. Physical
   microphone verification requires the owner to sign in on the phone.

1. Analyse current speech, parsing, cart, KOT, invoice and settlement paths.
2. Write PRD, TRD, architecture, stack and operation instructions.
3. Implement the Python planner and bounded Node process bridge.
4. Implement authenticated, durable agent sessions, receipts and POS tools.
5. Connect the existing Chotu overlay without visual redesign or duplicate work.
6. Verify actual Python/API/Flutter behavior and record results in JOURNAL.md.

Implementation was sequential, followed by independent read-only backend and
Flutter reviews using collaboration agents. Review regressions were fixed and
verified. No commit or deployment is requested.

## Business entitlements follow-up, 2026-11-14

1. Audit business/legacy schemas, authentication, subscription APIs, payments,
   provider entry points and background synchronization.
2. Implement canonical raw-BSON access decisions, tenant/permission enforcement,
   guarded paid/AI execution, calculated response aliases and idempotent verified
   renewals that preserve manual switches.
3. Prepare reviewed dry-run migration and Mongo examples; verify HTTP/access,
   boundary/date extension, payment replay, migration, notifications and existing
   Chotu/profile behavior. Record results in JOURNAL.md and backend/docs/ENTITLEMENTS.md.

No frontend edits, production database mutation, deployment or commit requested.

## Active subscriber regression follow-up, 2026-11-14

1. Inspect the reported account read-only and compare all legacy/canonical dates.
2. Apply the explicitly approved single-business flag/date repair with strict
   compare-and-set preconditions; preserve original expiry and AI permissions.
3. Refresh active status before upgrade navigation, dismiss obsolete locks,
   isolate delayed account responses and test rejected-payment behavior.
4. Verify exact database outcome, Flutter subscription checks, backend regression,
   analysis and the updated Android debug APK. Preserve existing UI design.


## Rapid quantity performance follow-up, 2026-11-14

1. Capture connected-phone logs and reproduce per-tap request/rebuild/save work.
2. Keep local edits immediate, batch and serialize background cart operations,
   buffer persistence, rebuild only affected quantity/cart views, and repair
   repeated tap-audio preparation failures.
3. Verify burst counts, variants/tables/removal/clear ordering, lifecycle saves,
   billing/media/table regressions, baseline older failures, analysis and APK.
4. Install the profile build, repeat a reversible native-phone quantity burst,
   remove test items and inspect logs. Live authenticated cloud sync needs the
   device's missing token restored through normal sign-in.
