# Chotu AI order automation

Status: FINALIZED
Date: 2026-11-12

User request: analyse Chotu AI, write its PRD and TRD, and implement a feasible
Python agent that takes orders and completes the order flow, with minimal UI work.

Scope: a Python workflow planner behind the existing authenticated Node API;
persistent, tenant-scoped sessions and request receipts; authoritative dine-in
cart edits, KOT creation, unpaid invoices, and explicitly confirmed cash
settlement. Reuse the existing Chotu overlay and POS services. Preserve the
unrelated work already in this checkout.

Acceptance: prove a real API sequence creates a cart, a kitchen order, an unpaid
invoice, then one paid sale and frees the table. Prove clarification, stock,
permissions, tenant boundaries, duplicates, and execution failure do not produce
false success. Run Python tests, focused backend tests, and Flutter checks.

See docs/chotu-ai/PRD.md and docs/chotu-ai/TRD.md for requirements and limits.

## Business entitlements follow-up, 2026-11-14

Status: FINALIZED

Implement the attached backend-only subscription/access request. Business
`isSubscription`, BSON Date `subscriptionExpiresAt`, and `isChotuAiActive` are
the only entitlement controls. Subscription requires a literal true flag and a
strictly future valid expiry; AI additionally requires its literal true flag.
Resolve authenticated business membership, reject ordinary entitlement writes,
read current BSON on every protected request, and gate paid routes/background AI
before usage. Preserve free POS/auth/status and verified renewal/payment paths.
Payments may extend dates once but cannot overwrite manual control flags.
Compatibility aliases must calculate access from canonical fields. Prepare a
dry-run-default, repeatable migration with ambiguity reports and no invented
expiry. Do not run it against production. No frontend edits. Verify access
matrix, expiry boundary, direct Mongo extension, permissions, tenant boundaries,
renewal idempotency, background notifications, migration and existing Chotu POS.

## Active subscriber screen regression, 2026-11-14

Status: FINALIZED

User reports an existing active subscription through 17 November being blocked.
Read-only inspection confirms pizza@gmail.com's three legacy sources agree on
2026-11-17T06:43:19.746Z while canonical fields are absent. User explicitly approved
repairing this single account by copying its existing flag/expiry, without
extension or AI activation. Preserve strict canonical access after that repair.
Fix client state/navigation logic so fresh active status prevents upgrade routes
and closes already-open locks; do not redesign layouts or change manual POS.
Verify active, inactive/expired, delayed refresh and account-switch responses,
existing subscriber navigation, and the exact approved database repair.

## Slower splash handwriting, 2026-11-14

Status: FINALIZED

Slow the current logo handwriting from 3600ms to 4800ms so each stroke is
readable. Scale the authored stroke timeline with playback; keep the existing
letter paths, artwork, captions, reduced-motion behavior and transition design.
Verify the existing splash/navigation checks and render the actual animation.

## Rapid POS quantity lag, 2026-11-14

Status: FINALIZED

Investigate rapid quantity increase/decrease using live connected-phone logs.
Keep every quantity edit immediate and exact while reducing redundant draft
serialization, whole-catalog rebuilds and concurrent per-tap cart HTTP writes.
Preserve variants, table isolation, KOT/billing, removal and clear ordering.
Repair observed tap-audio preparation/uncaught async errors without changing
notification/ringtone behavior. Verify burst edits, serialized synchronization,
local persistence, actual widget counts, existing POS/table/audio regressions
and a fresh Android build/runtime log. Preserve unrelated work and user data.
