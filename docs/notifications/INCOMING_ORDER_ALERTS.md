# Incoming order presentation

Updated 15 November 2026.

## Behavior

| App/device state | Presentation |
|---|---|
| App visible | Flutter immediately routes to the matching incoming-order screen |
| App background or process removed normally | Native receiver persists the payload and posts a high-priority notification with review/accept/reject intents |
| Locked screen with full-screen access | Android can launch the full-screen review activity |
| Unlocked, background | Android may show heads-up; the existing user-granted overlay path also attempts direct activity presentation |
| Full-screen access denied | Keep the notification and its tap/actions; do not assume self-sending a PendingIntent bypasses Android restrictions |
| Splash/startup | Retain pending order until session routing completes |
| Already showing same order | Do not stack a duplicate screen; forward explicit Accept/Reject actions to it |
| Already handled, local POS or customer chat | Do not open a new incoming-order prompt |
| Android Settings Force Stop | Android blocks push delivery until the user reopens the app |

This is not a guarantee that Android will always interrupt an unlocked phone.
User permissions, notification channel choices, connectivity and manufacturer
background restrictions still apply.

## Permission flow

Android 14+ `canUseFullScreenIntent()` is checked independently of overlay
permission. Missing access opens the app-specific Android settings screen once
after authenticated navigation. Existing installations get this new check even
if the old post-login permissions sequence already ran. Settings results are
awaited so full-screen and overlay screens do not race. A denial is not repeatedly
prompted; Notification settings provides a manual **Allow** retry. Already-granted
access does not open a redundant permission screen.

## Implementation

The app's protected Firebase receiver runs a shared native dispatcher and then
forwards delivery to FlutterFire. Google SDK service delivery shares the same
dispatcher and native dedupe. A forwarded data flag prevents a second Dart system
notification. Each order/action has a distinct PendingIntent URI, with the
required creator options for newer Android versions. Native cancellation is
bridged from Dart because Java and Dart notification IDs differ.

`MainActivity` commits pending payloads before launch and emits a separate warm
intent event to Flutter. Queue consumption reloads preferences so native and
background-isolate writes are visible. Order classification is consistent across
Dart foreground, background and launch paths. Notification dedupe does not drop
the order-screen handoff. Accept/Reject still use the existing order handlers.

Urgent Android pushes remain HIGH-priority/data-only; their server-side TTL is
now 90 seconds instead of zero. This backend change is prepared locally and
requires deployment to affect the hosted push sender. No backend deployment or
customer push was performed during this task.

## Validation

- 62 Flutter regression checks: permission upgrade, sequential prompts, denial,
  manual retry, warm intent, cold splash, native cache reload, same-screen action,
  table identity, duplicate suppression, ringtone and existing order UI. These
  also cover stale launch payloads, actions queued during splash, and handled
  updates received before presentation. A bounded native handled-order cache
  prevents a paused Flutter queue from reopening a background-handled order.
- Six Kotlin policy tests; merged-manifest checks for the protected receiver,
  replacement of the Flutter receiver and retention of Google's receiver.
- Nine backend push-contract/order-notification checks with provider transport
  mocked; no live FCM order sent.
- Profile ARM64 build succeeded, installed on OPPO CPH2637 with `Success`, and
  cold activity launch returned `Status: ok`.
- Device Notification settings visibly reports full-screen access and display
  over other apps as **Allowed**. No grant was performed by automation.

Evidence and APK: `build/full_screen_orders/`. The device captures confirm
installation, launch and permission state. They do not constitute an end-to-end
closed-app FCM order test; that remains a separate live acceptance check.

## Platform references

- [Android 14 full-screen access](https://developer.android.com/about/versions/14/behavior-changes-14#secure-fsi)
- [Android background activity launches](https://developer.android.com/guide/components/activities/secure-bal)
- [FCM app states and force-stop limits](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
- [FCM message lifespan](https://firebase.google.com/docs/cloud-messaging/customize-messages/setting-message-lifespan)
