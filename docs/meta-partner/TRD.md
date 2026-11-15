# WhatsApp Business connection — TRD

Version 1.0 · 15 November 2026 · Implementation and deployment contract

## Current implementation review

| Previous behavior | Correction in this change |
|---|---|
| OAuth ignored the code and returned fixed account details | Server code exchange, WABA-phone membership validation |
| Hardcoded app secret and shared phone/WABA fallbacks | Server configuration; no defaults in Meta setup |
| Empty fleet synthesized a shared channel | Empty tenant returns an empty list |
| Registration/subscription swallowed provider errors | Timeouts, provider response checks, flags saved after confirmation |
| Default PIN | Six numeric digits explicitly provided by administrator |
| PIN/subscription could overwrite each other | Independent atomic field updates; enable only when both exist |
| Fake template sync and APPROVED defaults | Actual submissions and provider status; defaults NOT_SUBMITTED |
| Sample analytics | Tenant message aggregation, explicit coverage and unknown rates |
| Message ID synthesized on an incomplete response | Require Meta message ID; accepted is distinct from delivered |
| Chat used user/global token before tenant token | Enabled business credentials select the sender |
| Connection status restored a seed account and returned token | Authoritative business status; no token in that response |

## Components and boundaries

- Flutter: `MetaPartnerChannelScreen` owns presentation and async loading/action
  state; `MetaPartnerService` handles API requests and surfaces errors.
- Express: `metaPartnerRoutes` authenticates and applies owner/admin role checks
  to integration management. The public browser bridge is capability-bound.
- `MetaSignupSession`: hashed 256-bit session capability, bound business/user,
  expiry, lifecycle. TTL index removes expired records; expiry is also checked
  during consumption, independently of TTL deletion timing.
- `metaPartnerService`: provider operations, tenant validation and persisted
  connection facts. Graph requests have ten-second abort deadlines.
- Existing webhook controller and chat/message stores process inbound messages
  and delivery statuses. They are not replaced by the signup browser page.

```mermaid
sequenceDiagram
  participant App as Apna POS
  participant API as Backend
  participant Page as Signup browser
  participant Meta
  App->>API: Authenticated POST /onboarding/start
  API->>API: Save session hash, tenant, user, expiry
  API-->>App: Hosted URL with capability in fragment
  App->>Page: Open external browser
  Page->>Meta: Embedded Signup config, response_type=code
  Meta-->>Page: OAuth code + FINISH account/phone IDs
  Page->>API: Complete with capability, code, selected IDs
  API->>API: Atomically claim unexpired PENDING session
  API->>Meta: Exchange code, validate WABA phone membership
  API->>API: Save tenant connection as SETUP_REQUIRED
  API-->>Page: Connected account; return to app
  App->>API: Refresh and complete registration/subscription
```

## Provider configuration

Server-only environment variables:

| Key | Purpose |
|---|---|
| `META_APP_ID` | Provider app used by Embedded Signup |
| `META_APP_SECRET` | Server-side exchange and Graph appsecret_proof |
| `META_EMBEDDED_SIGNUP_CONFIG_ID` | Facebook Login for Business signup configuration |
| `META_PUBLIC_BASE_URL` | Public HTTPS backend origin hosting the bridge |
| `META_GRAPH_VERSION` | Explicit supported provider version; default v23.0 |
| `WHATSAPP_APP_SECRET` | Existing webhook/proof secret; same provider app as applicable |
| `WHATSAPP_WEBHOOK_VERIFY_TOKEN` | Existing webhook challenge configuration |

The local environment was checked for key presence only. The four `META_*`
signup keys above are absent; the existing WhatsApp app-secret key is present.
No values were copied into these documents or the redesigned client.

Configure the app's allowed JavaScript/domain and signup settings for the public
host. The browser page uses configuration-driven signup with `extras.setup`,
without the retired `sessionInfoVersion: 3` override. Use a current v4 signup
configuration. Validate the selected signup configuration's supported
event/version contract in Meta before release, particularly for coexistence or
non-default onboarding variants, which this release does not implement.

The previous source-contained app secret must be rotated in Meta and deployment
configuration. Removing it from the current file does not invalidate copies in
repository history or previous artifacts.

## HTTP contracts

Paths are relative to `/api/v1/meta-partner`.

| Method/path | Input | Result and rules |
|---|---|---|
| POST `/onboarding/start` | Authenticated owner/admin | Ten-minute capability URL; business from auth |
| GET `/onboarding` | No bearer token | Static bridge; no app secret/token; no-store and nonce CSP |
| POST `/onboarding/complete` | sessionToken, code, wabaId, phoneNumberId | One use; tenant taken from stored session |
| GET `/status` | Auth | Saved facts plus live phone health, canSend, signupAvailable |
| GET `/channels` | Auth | Only this business's actual records |
| POST `/connect` | WABA ID, phone ID, token | Verify membership, reject existing foreign tenant linkage, save pending |
| POST `/channels/:id/register-pin` | pin | Exact tenant channel and sender; confirmed provider success |
| POST `/channels/:id/subscribe-webhook` | — | Confirm app subscription under the channel WABA |
| PATCH `/channels/:id/toggle-active` | Boolean isActive | Enable requires both setup flags |
| POST `/test-message` | recipientPhone, optional templateName/language/message | Reply-window or approved template; return real message ID |
| GET `/templates` | — | Live statuses plus unsubmitted starter suggestions |
| POST `/templates/sync` | — | Submit missing starter definitions; returns PENDING until approved |
| PUT `/profile` | aboutBio, address, email, website | Apply to Meta first, then persist |
| POST `/disconnect` | — | Disable, clear credentials, mark channels disconnected |
| GET `/analytics` | — | Chat-store counts, coverage description and India date boundary |

The retained authenticated `/oauth/exchange` endpoint now requires selected WABA
and phone IDs as well as the code; it uses the same verification logic. The UI
uses the capability flow. `/co-manage` returns 501 rather than claiming an invite
was sent. Creating a draft channel does not assign a provider ID or enable it.

## Authentication, session and secrets logic

The capability is 32 random bytes, returned in a URL fragment rather than query
or path so ordinary request logs/referrers do not contain it. The page reads it
into memory and removes the fragment. Persist SHA-256 only. Atomically move an
unexpired PENDING session to PROCESSING; subsequent completions fail with 409.
Successful sessions become COMPLETED; failures become FAILED and require a new
session, rather than reusing a potentially consumed OAuth code.

Accept browser messages only from explicit trusted HTTPS Facebook origins and
the expected `WA_EMBEDDED_SIGNUP` type. Wait for both the code and FINISH asset
IDs, regardless of arrival order. Client IDs are untrusted: the server verifies
the phone through the token's WABA phone list. Do not return access tokens,
secrets or PINs in status responses. PINs are transmitted to Meta and not stored.

Graph appsecret_proof uses HMAC-SHA256 over the business token with the server's
provider secret. Provider code 190 maps to reconnect/409, not POS authentication
401, so an expired Meta token cannot trigger the POS logout interceptor.

## Persistence and state consistency

`Business.whatsappSettings` remains the primary sender configuration because
existing senders read it. Connection writes this business only; the new flow
does not mirror credentials into the user document. Channel flags are updated
independently to avoid a registration/webhook race. A guarded enable update
matches the current primary phone and both true flags. Changing the primary
phone invalidates an in-flight old-channel update.

`canSend` requires saved credentials, enabled primary channel, registration,
subscription and a successful current phone probe. `isPartnerManaged` alone
is not readiness. Unknown quality/limit/approval values remain unknown.

## Messaging and reporting rules

The test endpoint validates international numbers. A freeform test requires a
tenant conversation with `lastIncomingAt` within 24 hours. A template test
requires the exact live APPROVED name/language. The simple test endpoint rejects
templates requiring variables/media; a composer must supply these explicitly.
There is no automatic fallback to an arbitrary template, recipient or sender.

Use the real Meta response ID and return ACCEPTED. Existing delivery/read
webhooks are the source of later delivery states. Metrics aggregate stored
outgoing WhatsAppMessage statuses from midnight Asia/Kolkata. READ counts as
delivered. Pending is excluded from sent, FAILED is counted separately, and
zero-denominator rates are unknown. Test sends and other stores are not silently
included in this limited chat metric.

## Error and recovery table

| Condition | Outcome |
|---|---|
| Missing server keys | 503; no session or connection fabricated |
| Invalid/used/expired session | 400/409; no exchange |
| Invalid code | 502; no credential write |
| Foreign phone/WABA | 400/409; no binding |
| Meta timeout/unavailable | 503; retry, saved state retained |
| Registration/subscription rejection | 502; corresponding flag remains false |
| Meta token expired | Reconnect required; POS login retained |
| No current customer window | 409; ask recipient to message first or use approved template |
| Template submission partial failure | Report failure; refresh provider list before retry |
| Profile rejected | No local optimistic success |

## Validation and deployment gates

Automated evidence is under `build/meta_partner_redesign/`:

- Eight regression tests failed against the previous backend behavior.
- New service tests exercise real exchange requests with mocked Meta responses.
- Lifecycle tests use MongoMemoryServer for concurrent setup, session consumption,
  tenant isolation and disconnect persistence.
- Route tests cover integration role checks and browser CSP/secret boundaries.
- Flutter tests exercise phone/desktop layouts, large text, PIN validation,
  offline retry and honest template state; rendered PNGs are captured.

Provider calls in these tests are simulated. Local rendering or APK installation
does not establish provider approval, live webhook delivery or a real account
connection. Production acceptance requires owner signup with configured keys,
actual Meta callback verification, inbound message, outbound test and status
webhook. Do not send a customer message merely to run a deployment check.

### Remaining integration debt / follow-up boundaries

The audit also found older generic WhatsApp connect/settings/auth serialization
paths that can store or return user credentials, separate campaign/eBill sender
configuration, seed-account logic elsewhere, and permissive webhook behavior
when no signing secret is configured. These broader paths are not all migrated
by this setup-screen change. Audit them before claiming platform-wide credential
isolation; configure the webhook app secret before enabling a live deployment.

Token-at-rest encryption/key rotation, a durable webhook inbox/retry worker,
provider-wide usage aggregation, and database-enforced unique phone claims need
dedicated migrations. The current connection performs a pre-write duplicate
tenant check; that check alone is not a concurrency-safe global uniqueness
constraint. The current WABA/template list reads the first 100 records and
returns template `hasMore`; full paging is required for larger accounts.

Do not deploy an interface-only update against the old fake-success backend.
Deploy backend and client together, with environment configuration and a
separate live acceptance check. Roll back source/artifacts if needed; do not
copy credentials from another merchant to make rollback appear connected.

## Primary provider references

- [Meta WhatsApp Business Platform overview](https://developers.facebook.com/documentation/business-messaging/whatsapp/overview)
- [Meta Embedded Signup default flow](https://developers.facebook.com/documentation/business-messaging/whatsapp/embedded-signup/default-flow)
- [Meta official Cloud API collection](https://www.postman.com/meta/whatsapp-business-platform/documentation/wlk6lh4/whatsapp-cloud-api)
- [Meta register phone reference](https://www.postman.com/meta/whatsapp-business-platform/request/zb2u18b/register-phone)
- [Twilio's provider integration migration guidance](https://help.twilio.com/articles/54890520784027-How-to-update-your-Meta-configuration-for-Embedded-Signup-ESU-v4)

Meta developer pages rate-limited direct retrieval during this review. Endpoint
requirements for registration and app subscription were cross-checked against
Meta's official Postman collection; provider configuration/event compatibility
still requires the live acceptance gate above.
