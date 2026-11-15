# WhatsApp Business connection — PRD

Version 1.0 · 15 November 2026 · Apna POS

## Product problem

Restaurant owners need to connect their own WhatsApp Business number, understand
what remains to be configured, and know whether messages were actually accepted
and delivered. The previous screen exposed a fleet dashboard before completing
onboarding, repeated technical labels, and displayed simulated success and metrics.

The code review found that OAuth did not exchange its code, channel registration
and subscription ignored provider failures, default templates appeared approved,
and some connection paths substituted a shared account. These are functional
defects, not evidence of a live merchant connection.

## Users and scope

- Owner or business administrator: connect, register, maintain and disconnect.
- Cashier/support staff: use conversations through existing chat permissions;
  cannot manage this integration's credentials or onboarding sessions.
- Platform administrator: configure the provider app, signup configuration,
  public HTTPS host and webhook in the deployment environment.

This release supports one primary sending number per business. It retains
channel records but does not advertise a multi-number sending fleet. Agency
co-management, coexistence/migration, provider billing and business verification
remain Meta/provider processes and must not be represented as completed locally.

## Redesigned information structure

The page is named **WhatsApp Business**. It uses Apna POS navy, blue, white and
restrained green confirmation marks. Three tabs replace the old fleet/settings
navigation: Connection, Templates, Business profile.

Connection contains:

1. Current number, business name, connection status and one connection action.
2. Three-step checklist: Meta account, number registration, incoming messages.
3. Optional measured chat activity when the number is ready.
4. Collapsed advanced connection for administrators with existing credentials.
5. Disconnect with a consequence-specific confirmation.

Remove unverified provider/partner badges, fake quality/limit figures, seeded
phone numbers, agency promises, and sample delivery/read percentages. Never
substitute another account when data is absent.

## Main journeys

### First connection

Owner opens Connection → Connect with Meta → short-lived browser session → Meta
selects the business, WABA and phone → server exchanges the code and validates
the selected phone under the selected WABA → return to Apna POS → register the
number using its six-digit PIN → enable the app's webhook subscription.

Opening a browser, receiving a FINISH event or entering a phone number alone
must not mark a business ready. On cancellation, keep the current connection.
On expiry or an already-used session, start a fresh session.

If server configuration is missing, report that signup is unavailable. Do not
launch a hardcoded app/callback or manufacture a successful account.

### Existing Cloud API account

Advanced connection accepts WABA ID, Phone Number ID and token. The server checks
the phone/WABA relationship before saving. Display name and phone are derived
from Meta. Connection begins in Setup required until registration and
subscription are confirmed. Client forms never request the provider app secret.

### Verification and test

Owner enters an international recipient number they control. The recipient must
have messaged this business within the current reply window for a freeform test.
The API also supports approved templates in their exact language; the current
test dialog uses the reply-window path. Variable/media templates require a
separate parameter-aware composer.

Receiving a message ID means **accepted by Meta**, not delivered. Delivery/read
confirmation comes from status webhooks and the existing conversation history.
Never claim delivery from an HTTP 200 alone or silently send a different template.

### Maintenance

Refresh and app resume retrieve current server state. Token expiry produces
Reconnect required without signing the owner out of Apna POS. Meta downtime
produces Could not verify connection. Profile updates are saved only after
Meta confirms them. Display-name changes follow Meta's approval process.

Disconnect disables the primary sender, clears its saved business credentials,
keeps conversation history and prevents chat sends from using old user/global
credentials. Disconnect does not claim to delete the merchant's WABA or revoke
every permission in Meta Business Manager.

## State and behavior contract

| State | Meaning | Primary response |
|---|---|---|
| Not configured | No complete tenant credentials | Connect |
| Setup required | Account linked; registration/subscription incomplete | Complete the outstanding step |
| Active | Saved setup complete and phone health probe succeeds | Test connection |
| Reconnect required | Meta rejects the saved token | Reconnect |
| Check failed | Health could not be established | Retry; retain credentials |
| Disconnected | Local sending disabled and credentials cleared | Connect again |

Registration and subscription are independent provider-confirmed facts. Both
must be present before enabling this integration. A successful WABA subscription
does not by itself prove that the deployment's callback is receiving events.

## Requirements and acceptance

| ID | Requirement | Acceptance evidence |
|---|---|---|
| P01 | Tenant-owned assets only | Foreign WABA/phone and cross-business reuse rejected |
| P02 | Real signup | Code exchange executes; invalid code writes no connection |
| P03 | Real setup outcomes | Rejected PIN/subscription does not set success flags |
| P04 | Recoverable errors | Offline retry and reconnect states are visible |
| P05 | No fabricated reporting | Empty message store shows zero/unknown, not sample metrics |
| P06 | Real template state | Drafts unsubmitted; only Meta-approved live templates selectable |
| P07 | Safe disconnect | Chat status remains disconnected; no credential fallback |
| P08 | Usable responsive UI | 320/390/1280px renders, 1.4×/2× text, and dark-parent theme checks |
| P09 | Honest message result | Accepted and delivered are distinct |
| P10 | No secret in browser page | CSP/nonce, origin checks and response contract tests |
| P11 | Readable controls and dialogs | Scoped light theme; opaque dialogs; labels and button states meet 4.5:1 contrast |

## Reporting definitions

Today means the Asia/Kolkata calendar day. Sent is recorded outgoing chat
messages with SENT, DELIVERED or READ status. Delivered includes READ. Failed is
recorded FAILED messages. With no sent messages, the delivery percentage is
unknown. These figures cover the chat message store; eBills, campaigns and setup
tests outside that store are excluded. Do not call them account-wide Meta usage.
No daily tier/limit is invented when the provider has not supplied it.

## Rollout and release gates

Local automated acceptance and rendered previews are available in
`build/meta_partner_redesign/`. Live onboarding remains gated by deployment
configuration and an owner completing Meta signup; no real customer test message
was sent during implementation.

Before a live release: configure the provider app and approved signup domains,
confirm requested permissions, configure/verify the webhook, rotate the app
secret formerly present in source, deploy the backend, then demonstrate one
owner signup, one inbound message, one outbound test and its delivery status.
Existing legacy credential/settings APIs require the broader hardening described
in the TRD; the new page does not imply that all such APIs have been migrated.

Success is measured by setup completion, failure reason distribution, signup
abandonment, time to first inbound event and verified delivery. No numeric growth
or latency claims are made without production measurements.
