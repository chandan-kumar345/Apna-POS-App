# Chotu voice validation — 2026-11-17

The implementation plan is VOICE_IMPLEMENTATION_PLAN_2026-11-16.md. PRD/TRD
and VOICE_COMMANDS.md describe current behavior and activation boundaries.

Diagnoses: Python deliberately refused digital settlement; its cash matcher did
not support ordinary follow-up confirmation. KOT tools created records without
a native printer job. The health callback did not start the mic. Compound table
numbers could split into separate values. Issued manual invoices could be
rejected by the simple-order guard. Legacy invoices omit variantName while
storing the selected price/description; the manual schema and services are
unchanged.

Fixes: deterministic Cash/UPI/Card receipt confirmation with enabled-method,
role, amount, expiry, table, order and draft checks. Existing invoices retain
stored prices, adjustments and rows. Immutable delta KOT/paid-bill jobs reuse
the native printer with durable claims, account checks and no uncertain auto
retry. The microphone starts after access; inactive capture and background/lock
startup are cancelled. Opt-in, two-minute foreground Hello Chotu opens the gated
overlay only after an exact finalized phrase. Android ACTION_ASSIST supports
system-selected assistant entry with unlock and expiring launch requests.

Evidence lives in build/chotu_voice_validation/:

| Evidence | Result |
| --- | --- |
| backend-pass.log | 112 tests / 5 suites passed |
| manual-invoice-final.log | Existing invoice with nonzero round-off passes; exact stored rows and money retained |
| language-complete.log | 34 corpus/language checks passed; corpus itself contains 23 examples |
| python.log | 12 policy tests, OK |
| flutter-complete.log | 76 regression/render checks passed |
| startup-final.log | 19 final overlay/activation checks passed, including the added async cancellation case |
| analysis-final.log | 14 items; no issues found |
| build-release-candidate.log | ARM64 profile APK built in 211.7s / 91.4 MB |
| apk-manifest.log / validation.json | ASSIST entry, native request expiry/bridge and foreground standby present |
| previews/chotu-transparent.png | Actual implemented overlay captured and visually inspected; small/keyboard/landscape tests pass |

The isolated API/Python lifecycle reports cartLines=2, KOT=preparing,
unpaidBillTotal=336, paid=true, table=free, saleCount=1. Coverage includes each
enabled payment method, duplicate receipts, delta KOT units, expired/changed/
negative confirmations, roles, disabled methods, tenants and draft conflicts.
Existing storefront delivery and incoming-order launch regressions also pass.

Artifact: build/chotu_voice_validation/apna-pos-chotu-voice.apk

Size: 95,884,250 bytes. SHA256:
a95b0b3982534a5e590c104f47e210e199e3460f2036708dce141de8fc6e0a0f

Earlier test failures were corrected for obsolete UI expectations, invalid
paused-to-resumed lifecycle simulation, legacy missing variantName and ObjectId
serialization. Legacy tests use offline fixtures rather than live AI providers.
No production DB writes, real orders or payments occurred.

No phone is connected. Physical microphone accuracy, paper printing and OEM
power-button behavior have not been exercised. These code changes/APK are local
and have not been deployed. Continuous background/screen-off wake requires the
separate offline keyword model/microphone-service phase in the plan. The command
corpus is deterministic regression material; no acoustic model was fine-tuned.
