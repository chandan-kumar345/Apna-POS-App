# Chotu AI verification — 2026-11-12

## Delivered scope

PRD, TRD, architecture, stack, setup/recovery guide; a standard-library Python
workflow planner hosted by the existing Node API; durable Mongo session/turn
receipts and locks; authoritative cart/KOT/invoice/cash-settlement tools; existing
Flutter overlay integration without a visual redesign. See `docs/chotu-ai/`.

The new flow is online, dine-in and explicitly confirmed cash settlement.
Start from `backend` with `npm run start:chotu` or configure the documented
environment flag. The existing speech parser/provider remains optional.

## Observed evidence

1. `python -m unittest discover -s tests -v` from `backend/python`:
   `Ran 12 tests in 0.002s` / `OK` (exit 0).
2. `node src/scripts/startChotuAgent.js --check` from `backend`:
   `{"enabled":true,"available":true,"pythonVersion":"3.11.0"}` (exit 0).
3. Initial combined backend regression command:
   `npx cross-env NODE_ENV=test GEMINI_API_KEY= GOOGLE_API_KEY= jest --runInBand --detectOpenHandles --forceExit --runTestsByPath tests/chotu_automation_agent.test.js tests/chotu.test.js tests/chotu_order_flow.test.js`
   returned `Test Suites: 3 passed, 3 total` / `Tests: 38 passed, 38 total`
   (225.307 seconds, exit 0). Optional external Gemini calls were disabled.
4. After independent review corrections, the expanded agent API suite:
   `npm test -- --runTestsByPath tests/chotu_automation_agent.test.js`
   returned `Tests: 26 passed, 26 total`, one suite, 81.026 seconds (exit 0).
   It invokes the real Python process and disposable MongoDB. Regression cases
   include negatives/conditionals before normalization, concurrent duplicate
   requests, local draft conflicts, tenant/actor roles, changed stock, authoritative
   prices, empty orders, failed writes, unsent additions after kitchen status
   changes, immutable KOT quantities, 0%/12%/non-GST tax and a fresh order after
   settling the previous one.
5. Captured actual lifecycle output:
   `CHOTU_LIFECYCLE_EVIDENCE {"cartLines":2,"kot":"preparing","unpaidBillTotal":336,"paid":true,"table":"free","saleCount":1}`.
   Tests also query orders, print snapshots, stock, carts, table and sale records;
   they do not rely only on a response message.
6. Final Flutter command:
   `flutter test test/chotu_automation_client_test.dart test/chotu_automation_snapshot_test.dart test/chotu_order_flow_test.dart test/chotu_voice_test.dart build/chotu_validation/preview_test.dart --dart-define=API_URL=http://127.0.0.1:9/api/v1 --reporter expanded`
   returned `00:11 +26: All tests passed!` (exit 0). Covers pending-turn persistence,
   lost responses, account/origin isolation, no cross-origin retry/discovery POST,
   health-discovery scope changes, overlapping callbacks, preserving newer local
   draft notes/quantities, authoritative cache installation, tax metadata,
   settlement cleanup, existing voice/order behavior and phone rendering.
7. `flutter analyze --no-fatal-infos lib/core/services/chotu_automation_client.dart lib/core/services/chotu_service.dart lib/features/pos/widgets/chotu_voice_sheet.dart lib/features/pos/pos_register_screen.dart test/chotu_automation_client_test.dart test/chotu_automation_snapshot_test.dart`
   returned `No issues found! (ran in 5.8s)` (exit 0).
8. Syntax checks for the Node agent service and tools returned exit 0.
   Targeted `git diff --check` returned exit 0.

## Visual evidence

Rendered the real Chotu overlay at 393 x 852 logical pixels, with Roboto and
Material Icons loaded. Inspected:

- `build/chotu_validation/chotu_overlay.png`: robot, microphone state, feedback,
  keyboard control and close button remain visible in the existing layout.
- `build/chotu_validation/chotu_rejected.png`: rejection displays amber info
  feedback and Close; no green completion check is shown.

The preview test mocks the API and audio platform channels. It does not claim a
real microphone, printer or payment-provider test. The preview harness/artifacts
are in the ignored build directory; portable service/API tests are in test/ and
backend/tests/.

## Review and limits

Independent read-only backend and Flutter reviews found actionable issues in
negated payment confirmation, mutable order timestamps, unsent KOT quantities,
tax metadata, replayed local drafts, navigation/reconciliation precedence,
cross-origin retries, health-discovery races and success indicators. They were
corrected and regression-tested. No remaining high-confidence blocker was
reported in those reviewed cases.

Including the entire existing DatabaseService in analysis still reports four
pre-existing warnings: a catchError return type, two unused locals and an unused
storefront constant, plus informational diagnostics outside the inserted agent
methods. No analyzer errors were reported. The focused analysis above is clean.

Earlier Flutter attempts encountered transient compilation mismatches in other
work concurrently changing splash and notification settings; no such files were
changed by this task. An outdated Chotu test expected a Start button although
the existing overlay already listens on opening; its assertion now matches the
current behavior. Test-only plugin simulation/fallback messages in the legacy
voice tests remain non-failing.

No production database mutation, deployment, physical cash collection, noisy
microphone trial or hardware printer delivery was performed. Uncertain partial
writes deliberately require manual reconciliation and retain a table lock.
Manual POS writes do not share the agent lock; this MVP does not claim
distributed exactly-once execution or concurrent manual-edit guarantees.
Unrelated edits already present or concurrently made in the checkout were preserved.
