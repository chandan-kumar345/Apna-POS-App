# Chotu AI access and screen repair

Pizza 47's paid subscription was valid, but its canonical Business record had
no `isChotuAiActive` flag. The server correctly denied Chotu access; the client
hid that reason behind a generic agent-unavailable message. Failed startup
checks were also treated as permanent for the current account/backend.

The client now distinguishes sign-in, subscription, AI access and connection
failures, verifies that Python is available, and can retry in the same account.
Concurrent health checks share one request. Responses from a different account
or backend cannot authorize an order. A rejected command does not execute
through a local cart fallback.

The overlay now has a transparent background and a compact glass panel: title,
table, language, one status/result area, microphone and typed input. The large
robot, provider setup badge, examples and extra instruction sections are gone.
Voice capture starts after access verification; typed and finalized voice input
use the same server agent. Manual POS behavior is unchanged by these edits.

After explicit owner approval, exactly one production field was changed:
`Business.isChotuAiActive = true` for business
`6ad46853ea47d6b3e13d633d`. A compare-and-set required the original owner,
active subscription, exact expiry and absent AI flag. Read-back confirmed only
that field changed, with `chotuAiAccess: true` and the unchanged expiry
`2026-11-17T06:43:19.746Z` (17 November, 12:13 PM IST).

Verification includes client access/retry and widget checks, duplicate voice
submission protection, small-screen/keyboard layouts, existing cart snapshot
and receipt recovery checks, plus 58 backend access/order lifecycle checks.
These run against fixtures and a temporary MongoDB; no production orders were
created. Evidence is under `build/chotu_validation/`.

The ARM64 profile APK was built and installed on the connected OPPO phone.
The app currently requires sign-in, so physical microphone recognition has not
yet been verified. Sign in as the owner, open Chotu from POS, and grant microphone
permission if Android requests it. A configured optional Gemini key is not
required for the healthy Python order agent.
