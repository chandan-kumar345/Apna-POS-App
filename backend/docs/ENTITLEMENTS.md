# Business subscription and Chotu AI access

Original implementation: 2026-11-14, backend only, without running the production
migration. The subsequent active-subscriber fix below includes an explicitly
approved single-account repair and client navigation logic. Tests use disposable
MongoDB databases and mocked payment providers.

## Active subscriber follow-up

The user's reported account had consistent active legacy entitlement through
2026-11-17T06:43:19.746Z in its Business, User and premium subscription records,
but the new canonical fields had not been migrated. Making canonical fields
authoritative before applying that data mapping caused a false lock.

With the user's explicit approval, exactly one matching business record was
updated: `isSubscription: true` and the original BSON expiry were copied. No
extension or AI permission change was made. A fresh read using the centralized
evaluator confirms active access; other businesses were not migrated.

Client feature navigation now refreshes subscription state before opening an
upgrade route. Active status suppresses the upgrade sheet, removes an existing
barrier and returns an already-open subscription page to its feature. Concurrent
status checks share one request; responses from a previous account are ignored.
Explicit server false clears cached active state, and failed payment activation
cannot manufacture a local subscription. Layouts/styling were unchanged.

Follow-up verification evidence is in `.gsd/JOURNAL.md` and
`build/subscription-account-repair-verification.json` at repository root.

## Previous problems

- Business, User, Staff and `premiumsubscriptions` each carried conflicting
  subscription flags. Some checks accepted active flags without a finite expiry.
- Status reads could select a different business or seed records. Legacy watchers
  copied flags between collections and broadcast access without checking expiry.
- Authentication could fall back to a client-supplied business when a JWT was
  absent/invalid. A contact email alone bypassed platform administrator checks.
- Subscription activation accepted an unverified UTR and manufactured access.
  Subscription update/list APIs and AI provider entry points were insufficiently
  protected.

## Authoritative controls

Only these fields on `businesses` grant access:

| Field | Stored type | Meaning |
| --- | --- | --- |
| `isSubscription` | Boolean | Administrator's manual subscription switch |
| `subscriptionExpiresAt` | BSON Date, or null | UTC expiry |
| `isChotuAiActive` | Boolean | Administrator's manual AI switch |

Subscription access requires `isSubscription === true` and a finite BSON expiry
strictly later than server time. Chotu additionally requires
`isChotuAiActive === true`. Missing fields, string booleans, ISO strings stored as
strings, null dates and reached expiry deny access. Mongoose setters validate
application writes; access reads use native BSON to prevent casts/defaults from
turning invalid manually stored values into grants.

Expiry never changes the manual switch. Extending an expired subscription with
its switch still true restores access on the next protected request, using the
same JWT. No entitlement cache or token subscription claims are used. Turning
off AI leaves other paid features available while the subscription remains active.

## Protected paths

All paths below are relative to `/api/v1`.

| Path/entry point | Enforcement |
| --- | --- |
| `/chotu/*`, including parse, transcribe, execute, agent, health and logs | Verified business member, POS permission, subscription, AI switch |
| Chotu service methods and Python agent orchestration | Fresh AI entitlement before provider/execution |
| WhatsApp `aiAgentService.generateReply` | Fresh AI entitlement before context/provider use |
| `/inventory`, `/loyalty`, `/campaigns`, `/staff`, `/crm`, `/coupons` | Authentication, business subscription, existing role permissions |
| Scheduled campaign execution and message dispatch | Fresh subscription before charge/dispatch |
| Subscription status, verify, checkout, activate/unlock | Authentication and business membership; available when expired |
| Subscription control updates, subscription listing, email diagnostic | Database-provisioned platform administrator |
| Profile/onboarding updates | Recursive rejection of entitlement keys, including nested/dotted keys |

Free starter POS, products, orders, carts, tables, basic reports, customer records,
authentication and existing restaurant payment flows remain available. This
follows the existing advertised starter plan; it does not disable manual POS.
There are no separate AI streaming routes in this backend.

JWT verification resolves the user from the database and verifies that the user
owns the resolved business or has a matching active Staff membership. A differing
`X-Business-ID` is rejected. Subscription request body/query IDs cannot select
another tenant. Platform administrator access requires stored `isSuperAdmin: true`
or `role: "superadmin"`; ordinary ownership/contact-email registration is insufficient.
Startup no longer creates/elevates that email, reactivates administrators, or
resets their passwords to a built-in credential. Existing administrator roles
and credentials remain in the database. Public legacy password recovery cannot
reset platform administrators; use a verified administrative recovery process.

## Response compatibility and realtime updates

`isSubscriptionActive`, `isActive`, `isSubscribed`, `status`, `expiresAt`,
`hasInventory`, `hasLoyalty` and `hasCampaign` are calculated aliases. Status
responses also include the canonical fields and `chotuAiAccess`.
Subscription status, login, phone-login, `/auth/me`, profile and administrator
listing responses use these calculations. `orderSettings.enableChotuVoice` in
these business responses is true only when its stored preference is true and AI
access is allowed. The stored preference cannot grant AI access.

Legacy plan, payment and UPI fields remain metadata for response compatibility.
They do not grant access. Watchers now emit calculated status only and never copy
entitlements between collections. A five-second read-only poll covers standalone
MongoDB and expiry transitions; protected requests always read immediately.
Expiry reminders use the canonical business date and switch.
Scheduled campaigns stay queued while access is disabled and can resume after a
manual extension; execution/dispatch recheck access before usage.

## Legitimate payment renewals

1. Authenticated `POST /subscription/payment-order` creates a server-owned
   Razorpay order and a `subscriptionpaymentintents` record for the current
   business. The existing legacy unlock offer is INR 300 for 30 days; price,
   currency, period and business cannot be supplied by the client.
2. `POST /subscription/activate` or `/unlock` accepts `razorpay_payment_id` and
   `razorpay_order_id`. The server fetches the payment using gateway credentials,
   verifies captured status, exact order, amount, currency and no refund against
   its stored intent. A UTR alone returns `PAYMENT_VERIFICATION_REQUIRED`.
3. A correctly signed `payment.captured` webhook uses the same verification.
   Missing/invalid webhook signatures are rejected, including in development.
   Ordinary restaurant-order payment webhooks retain their existing handling.
4. One atomic business update records the provider order in
   `subscriptionRenewalOrderIds` and extends the expiry from the later of its
   valid future date or server time. Replays/concurrent verification of that
   order cannot extend twice. **Neither manual boolean is changed.**

A paid renewal while `isSubscription` is false extends the date but leaves access
disabled. An administrator must enable the manual switch. Renewals never enable
Chotu automatically. Metadata/history flags are not synchronized as grants.
Gateway credentials and a webhook secret must already be configured to use this
verified path. Gateway calls are mocked in automated tests; no live charge was made.

## MongoDB examples (review and run manually)

Use `mongosh` against the intended database. Replace the ID and choose the desired
UTC date. These examples were not executed against production.

```javascript
const businessId = ObjectId("REPLACE_WITH_REAL_BUSINESS_ID");

// Enable subscription, with an explicit future BSON Date.
db.businesses.updateOne({_id: businessId}, {$set: {
  isSubscription: true,
  subscriptionExpiresAt: ISODate("2030-01-01T00:00:00Z")
}});

// Disable subscription; preserve expiry and AI switch.
db.businesses.updateOne({_id: businessId}, {$set: {isSubscription: false}});

// Extend expiry. Restores access immediately if isSubscription is still true.
db.businesses.updateOne({_id: businessId}, {$set: {
  subscriptionExpiresAt: ISODate("2030-02-01T00:00:00Z")
}});

// Independently enable or disable AI (subscription must also be active).
db.businesses.updateOne({_id: businessId}, {$set: {isChotuAiActive: true}});
db.businesses.updateOne({_id: businessId}, {$set: {isChotuAiActive: false}});
```

Use literal booleans and `ISODate`, not quoted booleans or date strings. Check
`matchedCount` and the authenticated status endpoint for the intended business.
Editing `User.subscription`, `Business.subscription`, Staff subscription or
`premiumsubscriptions` no longer changes access.

## Reviewed migration

The migration is explicit, read-only by default, and never runs during startup.
Back up the target database and inspect a staging dry run before rollout. Run
before the upgraded application serves business writes: hydrated legacy records
can acquire new schema defaults during ordinary saves, obscuring missing fields.
Pause business/entitlement writes while reviewing and applying the migration.

From `backend` in PowerShell, select the reviewed target yourself:

```powershell
$env:MONGODB_URI = 'mongodb://REPLACE_WITH_REVIEWED_TARGET/apna_pos'
node src/scripts/migrateEntitlements.js --dry-run > entitlement-dry-run.json
```

Review each record's `set` and `review`. Reliable, consistent finite BSON expiry
and strict legacy flags map from embedded business history or business-scoped
premium records. User/owner-only history is considered only for a uniquely
associated owner/business. Staff overrides never grant a business entitlement.
Expired records retain their reliable enabled flag and original expiry.

Existing valid canonical controls are preserved. Conflicting/invalid histories,
lifetime grants without a finite expiry, and contradictory partial canonical
fields are reported without applying a guessed mapping. No reliable history
defaults missing subscription controls to false/null and reports that outcome.
Missing AI control defaults false; an old user-editable voice preference is
reported for administrator approval. No arbitrary 30-day dates are invented.

Resolve ambiguous records explicitly in MongoDB, then rerun dry-run and inspect
the report. After review, application is an explicit separate command:

```powershell
node src/scripts/migrateEntitlements.js --apply > entitlement-apply.json
node src/scripts/migrateEntitlements.js --dry-run > entitlement-after.json
```

The script requires explicit `MONGODB_URI`, disables automatic index creation,
and checks original canonical values/presence before each write. Concurrent
canonical changes are skipped and reported. Reruns preserve later manual edits.
It does not delete legacy history or change payment records. Review remaining
reported records before resuming writes; take no access grants from legacy flags.

## Client limitations without frontend changes

- Old unauthenticated terminal fallback requests now receive 401. They must use
  a valid JWT; a business header alone is insufficient.
- An old UTR-only unlock screen cannot securely activate automatically. It needs
  administrator review or a client checkout integration using the verified API.
  No checkout UI was added in this task.
- Cached/offline badges and locally stored data can remain visible until the
  client refreshes status; the next protected backend request is still denied.
- A client calling an AI provider directly using its own/stored key bypasses this
  backend. Backend guards cannot revoke such provider keys; client integration
  and provider key restrictions require separate work. No frontend files changed.
- Individual staff subscription activation is now rejected: business access and
  staff role permissions determine access. Existing status aliases remain.
- A platform contact-email account that was never explicitly provisioned as an
  administrator cannot log into the admin API. The old built-in password hint
  is no longer valid; no client-side hint was changed.

## Implementation files and verification

Core additions: `src/services/entitlementService.js`,
`src/middleware/entitlementMiddleware.js`,
`src/services/subscriptionRenewalService.js`,
`src/models/SubscriptionPaymentIntent.js`,
`src/services/entitlementMigration.js`, `src/scripts/migrateEntitlements.js`.

Integration changes (relative to `backend`):

| Area | Changed files |
| --- | --- |
| Model and authentication | `src/models/Business.js`, `src/middleware/authMiddleware.js`, `src/middleware/superAdminMiddleware.js`, `src/services/authService.js`, `src/server.js` |
| Routes | `src/routes/index.js`, `src/routes/chotuRoutes.js`, `src/routes/profileRoutes.js`, `src/routes/onboardingRoutes.js`, `src/routes/subscriptionRoutes.js` |
| Controllers | `src/controllers/profileController.js`, `src/controllers/subscriptionController.js`, `src/controllers/paymentController.js` |
| Subscription/payment | `src/services/subscriptionService.js`, `src/services/superadminService.js`, `src/services/razorpayService.js` |
| AI/background services | `src/services/chotu/chotuService.js`, `src/services/chotu/automationAgentService.js`, `src/services/aiAgentService.js`, `src/services/campaignService.js`, `src/services/dbWatcherService.js`, `src/services/cronService.js` |
| Existing regression fixtures | `tests/chotu.test.js`, `tests/chotu_order_flow.test.js`, `tests/chotu_automation_agent.test.js`, `tests/subscription.test.js` |

Repository `.gsd` requirements, roadmap, journal and state record this follow-up.
Existing unrelated changes in this checkout were preserved.

Focused tests are in `tests/entitlement_access.test.js`,
`tests/entitlement_migration.test.js`, `tests/entitlement_background.test.js` and
`tests/subscription.test.js`. Existing Chotu positive fixtures explicitly seed
valid business controls through `tests/helpers/grantBusinessAccess.js`.
Final test results and commands are recorded in `.gsd/JOURNAL.md` at repository
root. Durable runner logs are under repository `build/entitlement-*-tests.log`.

Verification on the implementation:

| Checks | Result |
| --- | --- |
| Access, migration, background, subscription and auth suites | 60 passed in five suites; the two subsequently changed suites passed all 36 checks including two added cases (62 distinct checks across these five suites) |
| Existing Chotu automation, Chotu parse/execute, order flow and profile history | 46 passed in four suites |
| Existing restaurant payment webhook compatibility | 3 passed; 3 unrelated cases excluded by the test-name filter |
| Backend diff whitespace | Passed |

The final changes cover administrator login/detail aliases and scheduler queue
resumption in addition to the original access matrix. Production migration,
deployment and live payment verification were not performed.
