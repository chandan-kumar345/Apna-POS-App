

## POS delays / duplicate realtime work ? 2026-11-14

User report: app gets stuck or responds late during operation.

Evidence: `build/performance_validation/device.log` captured the running Android
process (9234, OPPO CPH2637). Choreographer reported skipped 31, 34 and 66 frames
around 01:01:52?55. Repeated identical table updates and order recalculations were
present while ordering. Video decoder pipelineFull messages were also present.

Hypotheses:
1. Duplicate socket snapshots cause redundant persistence and screen rebuilds.
   Confirmed: existing single-table callback always saves tables and notifies;
   positive totals additionally serialize all carts and notify again. A test with
   one update plus 50 duplicates generated 102 notifications before the fix.
2. Concurrent video decoding contributes to stalls. Logs show decoder pressure,
   but the existing coordinator already limits Android to one decoder. No new
   video behavior change made without evidence of a specific lifecycle defect.
3. Network waits block responses. No matching timeout/connection failure in the
   captured ordering log; do not change API timeouts speculatively.

Fix: merge single/batch table snapshots through one path; compare effective table
state after preserving the original occupied timer; persist/notify only changes;
update batch totals without nested notifications. Preserve local draft protection
and clear stale totals even when the free table itself is unchanged. Ignore
identical live-total assignments. Save local POS items and totals atomically so
normal cart entry serializes the draft once instead of twice.

Validation:
- Before: 5 new regression cases failed, 1 passed (`before-tests.log`).
- After: all 28 focused performance/table timer/video tests pass
  (`focused-tests.log`), including 7 performance cases.
- Duplicate sequence now generates 1 notification instead of 102; changes back
  to an earlier value are still delivered; a changed batch notifies once.
- Broader table suite: existing stale-settled-draft test fails. Reproduced using
  unmodified HEAD source with exactly the same expected free / actual occupied
  result (`baseline-existing-failure.log`). Not introduced by this change.
- Targeted analyzer: no errors, 2 existing warnings and 3 existing infos
  (`analyze.log`); no new diagnostics in POS screen or new tests.
- Android debug build succeeded in 37.7s (`apk-build.log`).

Runtime limitation: hot reload reported 0 libraries, then disconnected and the
app process was absent. This is not evidence of improved on-device frame timing.
A fresh APK installation/relaunch is being checked; no smoothness claim is made
from unit tests alone.


Follow-up runtime evidence: fresh Android PID 19893/20243 exposed an unhandled
`cloud_firestore/permission-denied` error at startup. The secondary pending-order
subscription lacked an `onError` callback (the primary cloud subscription already
had one). Added asynchronous stream error handling; access rules are unchanged.

Final focused run, including POS checkout recovery: `00:05 +29: All tests passed!`
(`final-tests.log`). Final debug build succeeded in 40.5s
(`final-apk-build.log`), installed successfully, and cold launched as PID 24159.
`final-device.log` contains both handled cloud permission messages and **0**
unhandled exceptions/FATAL EXCEPTION/ANR entries. Debug startup still reports 359
skipped frames and cold Activity launch 7709ms; do not claim all frame drops were
fixed. Comparing an ARM64 profile build to identify debug compilation overhead.


Device thermal evidence: `thermal-status.txt` reports Thermal Status 3 and
SKIN sensor ~50.2 C, status 3. Installed Android SDK sources
`C:/Android/sources/android-36/android/os/PowerManager.java:2758` describe
THERMAL_STATUS_SEVERE as severe throttling where UX is largely impacted.
This is a confounder for all timings on the current phone; profile/debug launch
numbers must not be treated as a controlled benchmark. No thermal overrides or
settings changes were made.


Completion evidence: ARM64 profile APK built successfully in 189.1s, 68.3MB
(`profile-apk-build.log`), installed with `adb install -r` Success, and cold-launched
with Activity Status ok, TotalTime 2887ms / WaitTime 2964ms, PID 28755. The first
profile startup log has 0 unhandled exceptions/FATAL EXCEPTION/ANR entries and
64 skipped startup frames (`profile-device.log`). Thermal status remains 3.
Profile APK is the version currently installed. This launch timing is observational,
not a controlled performance benchmark, and does not prove every POS interaction
is smooth. No user data was cleared. Debug APK remains available alongside profile.


## Session resume and duplicate launch logo ? 2026-11-14

Report: reopening appears to log the account out; remove static logo screen and
start with the animated splash.

Hypotheses and evidence:
- Session deleted on process exit: refuted on the connected phone. Private
  preferences were inspected without exposing tokens or identity: session flag
  true, cached user and user ID present. Cached user setup flag was false/step 0,
  while the matching business profile was onboarded.
- Incorrect startup destination: confirmed. Splash unconditionally constructed
  GetStartedScreen after initialization. Updated restored-session widget test
  failed before the fix (`session_validation/before-tests.log`).
- Profile refresh loses setup metadata: confirmed. DatabaseService reconstructed
  the refreshed UserModel without onboarding fields. AuthService.getMe also
  replaced cached fields with model defaults when the response omitted them.
- Separate Android static splash: both launch_background variants drew splash_logo;
  API 31 light/dark themes additionally requested splash_icon.

Changes: startup resolves the restored user after initialization and animation;
completed owners/staff open MainLayout, signed-out users open Get Started,
unfinished owners resume their saved setup step. Preserve same-account/business
onboarding state during profile refresh, and retain it in the DB snapshot.
Remove static native artwork, use a transparent Android 12 starting-window icon
on the same background, and remove the native exit view on first Flutter frame.
Launcher icons and handwritten Flutter animation are retained.

Validation so far: 36 focused session/profile/splash/permission tests pass
(`build/session_validation/final-tests.log`). Targeted analysis has no new
issues; only the same 2 DB warnings and 3 infos as before. ARM64 profile APK
built successfully in 133.0s (`final-apk-build.log`) and installed with Success.
Recording and checking two real cold reopens before completion.


### Follow-up: faster writing and no blank Android handoff

User asked to speed up lettering and remove the blank area before Flutter.
Timing changed from 4800ms to 3600ms (25% shorter). Initial Flutter progress is
0.04 so the first real frame contains ink. Generated native animated vector
resources from the existing isolated glyph contours and authored stroke JSON;
Android 12+ writes the logo during engine startup, then passes elapsed animation
time via `com.apnapos.app/startup_brand` to continue Flutter without reversing
or replaying completed lettering. The native exit view fades over 100ms.
Older Android's starting background contains the initial ink vector.

Before these final changes, real cold reopens already reached POS with saved
tokens/session flags. First identity comparison changed once during profile sync,
so the assertion was not accepted as final proof. A fresh backend identity check
confirms local user and business match /auth/me, and secure/session user IDs match
(`backend-identity-check.json`, all four booleans true). No credentials or account
identifiers are included in that artifact.

37 focused tests pass (`final-faster-tests.log`), including native handoff progress,
no rewinding, restored routing, setup preservation and permission timing.
Targeted final analysis: No issues found (`native-writing-analyze.log`).
Native vector generation: `python tool/generate_android_startup_writing.py`.
This asset is derived from code-native glyph paths and existing raster masks;
launcher icons and existing logo artwork are unchanged.


Further on-device inspection caught the old outgoing AnimatedOpacity reaching 0
before the replacement route painted (`launch-3.0s.png` from that interim run).
Removed this fade-through-background phase. The completed SplashBrandView now
stays painted underneath the incoming route's fade, eliminating that deliberate
blank interval. Updated widget assertion verifies the source artwork remains in
the route tree during transition with no outgoing AnimatedOpacity.

Final transition tests: `00:03 +37: All tests passed!` (`no-blank-tests.log`).
Final changed auth/animation files and tests analyze with `No issues found!`
(`no-blank-analyze.log`). Rebuilding the profile APK for the final device check.
Interim native build installed and ran without native vector inflation errors or
unhandled Flutter exceptions. A preferences diagnostic read overlapped a live
SharedPreferences write and returned incomplete XML; the diagnostic now retries
that read. No production storage change was made for this diagnostic race.


### Session credential investigation after UI routing was fixed

The final reopen read initially showed an access token disappearing, then a later
read confirmed both access and refresh keys were absent despite the saved account
and session flag remaining. Do not report this as successful credential retention.
The current cached account still opens POS; deleted/rejected credentials cannot be
reconstructed without a fresh legitimate sign-in.

Confirmed client defects and fixes:
1. AuthInterceptor retried a resource 401 by recursively refreshing, with the broad
   catch also able to treat a denied replay as a rejected refresh. Regression on
   original implementation (only injecting a fake refresh client): expected one
   refresh, actual two (`auth-refresh-before.log`). New logic allows one replay,
   coalesces concurrent refreshes, reuses a rotated token for late old-token 401s,
   and only clears credentials on an explicit refresh-endpoint 401. Offline and
   malformed refresh responses preserve credentials. Refresh token is saved before
   access token, so a close during access persistence can recover on next launch.
2. SecureStorageService marked `_isLoaded=true` before its asynchronous prefs read
   completed, and saveBusinessId/saveUserId could mark a partial cache loaded.
   Concurrent startup calls could observe missing tokens before restoration.
   All readers now await one loading future; writes first restore the full cache;
   logout waits for any read so the old session cannot resurrect afterward.
   Existing token backup is written before slow keystore writes.
3. The full restored-POS test exposed a real narrow-width overflow in the empty
   menu loading message. Wrapped that text in Flexible; the same narrow restored
   route test now passes without suppressing layout errors.

47 focused tests pass (`complete-session-tests.log`), covering six refresh cases,
four storage restore/persistence cases, startup resolution, handwriting handoff,
route transition and permission timing. Storage/interceptor analysis has no issues
(`storage-analysis.log`). Final profile rebuild includes these session fixes.

Final installed build: session-fixed-build.log reports assembleProfile 97.1s,
app-profile.apk 91.5MB. Installation returned Success. Cold start Status ok,
TotalTime 4107ms / WaitTime 4132ms, PID 5023. session-fixed-device.log contains
0 unhandled exceptions, fatal exceptions or ANRs. Visually inspected
session-fixed-screen.png: restored account's POS. Session flag, cached account
and completed setup remain present in session-fixed-state.json. Both previously
cleared token keys remain absent; a legitimate fresh sign-in is required to renew
the server session. No account data was cleared for testing.

Native startup writing was visually confirmed in final-launch-0.2s.png. That
filename is a requested capture offset, not measured latency; ADB returned the
image after about 7.9s on the busy device. Do not interpret it as first-frame timing.


## Rapid POS quantity lag - 2026-11-14

Observed the connected OPPO CPH2637 using live ADB logcat. Original process 20290
reported skipped 3650/5636 frames and unhandled 30-second AudioPlayer preparation
timeouts after button playback. The phone also reported thermal status 3 (SKIN
about 47 C), so no controlled device speedup ratio is inferred.

Reproductions before the fix:
- 30 quantity increments launched 30 HTTP mutations.
- 30 quantity taps rebuilt an untouched product card 30 times.
- Each tap encoded the entire saved draft collection, then persisted multiple
  copies; each audio click called play(source), re-preparing a preloaded asset.

Fix:
- CartMutationQueue batches adjacent identical deltas in a fixed 180ms window,
  serializes writes per cart, preserves add/reduce/remove/clear ordering and
  isolates tables/variants/account scopes. Pending edits are flushed before
  order finalization/print or moving a cart. Lost responses are not automatically
  replayed as another increment on a rediscovered API origin.
- Immediate local cart memory/quantities are retained. Only the changed product,
  cart summary and open cart panel rebuild for normal quantity edits.
- Disk snapshots/global draft notifications are combined within 200ms. Captured
  keys/values and ordered writes prevent older writes from overtaking new ones.
  Lifecycle, context exits, account switches and logout flush pending local data.
- Button/key sounds resume prepared sources, reject overlapping playback work,
  catch async errors and share initialization. Notification/ringtone paths remain.
- Per-calculation console output is opt-in via POS_CALCULATION_LOGS.

Evidence: build/quantity_performance/.
- New + focused/related existing suites: 59 passed (final-tests.log).
- 30 delta calls -> 1 request; 30 unrelated card rebuilds -> 0.
- 50 immediate local edits -> 1 serialized snapshot, 1 global notification,
  persisted final quantity 50.
- Eight-file focused analysis clean; database file retains five pre-existing
  diagnostics (two warnings/three infos), no new errors.
- Two older multi_order_isolation_test cases still fail. An isolated copy using
  before-change POS/database/cart/audio sources reproduces the same two failing
  cases (baseline-isolation-tests.log); this comparison did not replace active
  workspace files. The new buffered-burst table-switch case passes.
- Final ARM64 profile APK built in 140.0s, installed with Success, cold-started
  Status ok (3034ms), PID 8919. Packaged ARM64 library matches the final build.
- Physical-device test on previously free T-5: 1 initial unit + 20 rapid taps ->
  exactly 21 displayed units; 21 decrement taps removed the test draft and T-5
  returned to Free. Existing occupied T-1..T-4 totals stayed unchanged. No KOT,
  bill, settlement or payment was generated. Screenshot: device-burst.png.
- New process live log: 0 unhandled errors, 0 audio preparation timeouts and
  0 fatal exceptions in the observed run. Android gfxinfo still records short
  frame misses under thermal throttling; do not claim all rendering jank fixed.

Runtime limit: the phone restored its cached account but its subscription-status
HTTP request had no bearer token. Physical taps therefore prove local response;
real authenticated cloud-cart sync remains unverified. The queue/ordering/cloud
error cases pass against a mocked HTTP transport. Fresh sign-in requested from
user without bypassing authentication. Read-only backend check: T-5 Free, no
current order/total and no matching server cart. No entitlement changes made.
