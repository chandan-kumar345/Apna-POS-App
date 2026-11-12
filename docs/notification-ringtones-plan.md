# Custom notification ringtones

Users must be able to independently choose, preview, upload and remove order
ringtones and notification sounds. Selections and volume must survive restart;
removing an active upload must restore a playable default.

1. Repair the existing upload flow and settings UI.
   Files: notification_settings_screen.dart, database_service.dart.
   Validate supported extensions and the 15 MB limit before upload, retain the
   returned library entry, use the backend's supported `custom` type and show
   actionable errors. Avoid saving stale library snapshots.
   Verify with Flutter regression tests and targeted analysis.
2. Repair playback and delivery.
   Files: sound_service.dart, local_notification_service.dart,
   pushNotificationService.js, ApnaPosFirebaseMessagingService.kt.
   Cache uploaded bytes in durable app storage, use stable cache names, stop
   preview/start races, and honor mute and zero volume. Android data messages
   and silent app-managed channels let the player use the selected sound without
   overlapping a hardcoded system chime. Retain APNs alerts on iOS.
   Verify persistence/source resolution tests and backend payload tests.
3. Restore defaults consistently after deleting active audio.
   Files: notification_setting_model.dart, notificationController.js, tests.
   Reset both selections if they share a removed file, on client and server.
   Verify deletion and independent selection tests.

Device verification: upload audio, preview, select for each category, restart,
receive foreground/background orders, mute, and delete the active file. iOS
OS-rendered remote alerts continue to use the APNs sound; arbitrary uploaded
audio is supported while the app can execute playback.
