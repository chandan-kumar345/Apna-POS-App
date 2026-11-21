# Chotu AI order automation

## Android campaign studio, 2026-11-21

Status: FINALIZED

Match the supplied Android dashboard, reward, message, actions and review screens.
Support all five reward forms, restaurant menu items, selected order types, a coupon
code, exact IST expiry, campaign image upload, audience groups, drafts and scheduling.
Store drafts and send decisions per business. The final editor action submits the
template to Meta for review. An approved campaign waits for an explicit merchant
send or schedule action before any delivery, wallet debit or coupon activation.
Show actual Meta approval and delivery
states. Offer Marketing, Utility and Auth categories and respect the OTP-only use of
authentication templates. Keep existing web studio, POS and customer login entry points.

## QR customer WhatsApp authentication 2026-11-21

Status: FINALIZED

Redesign phone login with a separate readable OTP/name bottom sheet. Deliver
authentication-template OTP from phone ID 1284061438133660, WABA
2525727467906581 using server-only credentials. Persist a CRM customer after
successful first dispatch; blank name defaults to Valued Customer. Only a
correct, unexpired, single-use server challenge grants a restaurant-scoped
customer session and phone-owned database order history. Returning login reuses
the customer; optional blank name preserves an existing name. Remove client OTP
bypasses; keep guest checkout and merchant sessions unchanged. Test using an
isolated database/mock Meta transport, not production messages/database writes.

## Customer storefront sheet/media follow-up 2026-11-20

Status: FINALIZED

Guest details must open as a readable bottom sheet; product details use 60% of
screen height with scrolling content and fixed purchase controls. Enable muted
independent product video playback and existing completion-driven video/image
carousel. Render up to ten available popular products, improve rounded search,
and preserve menu dimensions when keyboard insets appear. Preserve concurrent
order-tracking edits already present in this checkout; no production data writes.

## Native popup follow-up 2026-11-20

Status: FINALIZED

Show a readable native loading card during cold Flutter startup, restore the
assistant session once before checking access, and make popup text independent
of the host dark theme. Preserve manual ordering and server authorization.
Verify foreground wake behavior and document that closed/force-stopped app
hotword listening is unsupported without a dedicated offline wake model/service.

## Voice, KOT delivery and settlement follow-up — 2026-11-16

Status: FINALIZED

Improve grounded Hindi/Hinglish/English commands without changing manual POS.
Support explicitly confirmed Cash, UPI and Card payments when enabled for the
business and permitted for the actor. A method selection alone must never mark
an order paid. Bind follow-up confirmation to table, current totals and draft;
reject expired, changed, negative and hypothetical confirmations. Preserve
server receipt idempotency and one sale per order.

Dispatch immutable KOT/bill print jobs from successful Chotu receipts through
the configured native printer. Print only newly sent kitchen quantities. Keep
durable device claims so recovered/replayed receipts never auto-print twice;
report failed/uncertain delivery separately from successful order mutations.

Restore microphone startup after successful health/access checks, improve
recognition normalization and add a versioned command regression corpus.
Add opt-in foreground wake-phrase activation and Android default-assistant
entry through system settings; preserve login, subscription and AI access gates.
Do not intercept the power key, listen on boot, execute ambient commands, or
claim continuous background hotword support using Android SpeechRecognizer.
Document the dedicated offline wake-engine/foreground-service follow-up needed
for reliable screen-off/background hotword support.

Verify Python policy, isolated API lifecycle/permissions/retries, Flutter printer
and voice/activation flows, screenshots for UI and Android compilation. No
production test orders/payments/database changes.

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

## Chotu access and transparent overlay, 2026-11-14

Status: FINALIZED

Diagnose Chotu failures and implement a compact transparent overlay with only
the assistant title, current table/language, microphone, typed input and current
transcript/result. Remove provider setup badges, large robot/marketing sections,
example-command lists and redundant instructions. Preserve manual POS workflows
and server validation/confirmation. Report authentication/subscription/AI-access
and runtime errors distinctly, retry health after denied/unavailable results and
do not cache an access denial as permanent agent configuration. Do not call AI
or mutate orders through local fallbacks after denied server access.
Read-only inspection confirms Pizza 47 is subscribed but its manual AI permission
is missing/false. Prepare and verify code/UI before requesting explicit approval
for the targeted AI toggle, respecting the earlier production-write restriction.
Verify the Python planner, Flutter rendering and backend behavior, then check
the installed Android build when a signed-in phone is available. Report any
remaining authentication or live microphone verification limits explicitly.

## Product details visual redesign, 2026-11-15

Status: FINALIZED

Redesign the POS product detail popup shown by the user. Use smaller, readable
typography, neutral surfaces, subtle borders and a clear hierarchy. Remove the
glowing outer shadow and excessive colored badges. Keep photo/video, food type,
category, stock, description, GST, discounted prices, variants and nutritional
estimates. Keep quantity and Add visible while details scroll. Preserve the
existing cart callback, variant identity, stock limits and order workflows.
Support small phones, tablets and enlarged text without overflow. Verify the
rendered popup and existing relevant POS behavior; build the Android artifact.

## Compact product popup follow-up, 2026-11-15

Status: FINALIZED

Reduce the product popup's height and excessive spacing per the marked screen.
Use a shorter photo, inline category/availability, tighter section and variant
spacing and a compact nutrition grid. Keep all information, readable text,
accessible action controls, scrolling and the existing cart behavior. Render
phone/tablet layouts and verify quantity, size selection and enlarged text.

## Product photo/video fitting repair, 2026-11-15

Status: FINALIZED

Correct the cropped media in the compact product popup. Show the full photo or
video at its original aspect ratio in a balanced, bounded preview frame. Avoid
square image decoding and thumbnail ghosting behind contained video. Retain
compact details and existing grid playback, cart behavior and stock rules.
Verify landscape/portrait images and videos, render the actual media widget,
then build and install the Android update.

## Customer order notification and acceptance repair, 2026-11-15

Status: FINALIZED

Diagnose and repair missing merchant notifications and acceptance prompts for
table QR, customer storefront delivery and takeaway. Compare the working
WhatsApp flow, verify backend order persistence and transport payloads, and
ensure submitted items, type and table reach the correct restaurant. Verify
pending orders across supported receiving paths and guard against duplicate
prompts and previously handled orders. Exercise actual public API submissions
in an isolated database and the client notification acceptance flow.
