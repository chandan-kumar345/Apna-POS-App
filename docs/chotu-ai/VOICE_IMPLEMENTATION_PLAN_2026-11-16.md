# Chotu voice implementation plan

1. Diagnose parser, Python policy, Node tools, native printer bridge and speech
   lifecycle. Preserve receipt recovery and all manual POS paths.
2. Extend deterministic payment parsing and Python policy to enabled Cash/UPI/
   Card. Ask for method/receipt confirmation; bind follow-up approval to current
   table and fingerprint. Reuse orderService.settleOrder and existing sale logic.
3. Return immutable receipt print jobs (delta KOT and invoice/paid receipt).
   Dispatch once per device/origin/business using the saved printer. Persist a
   claim before transport and report uncertain printing without rerunning tools.
4. Extend Hindi/English ASR normalization and a checked-in phrase corpus. Start
   the mic after access succeeds; coordinate foreground wake listening with the
   overlay/TTS so audio cannot execute twice or hear its own replies.
5. Add opt-in foreground Hello Chotu and Android system-assistant invocation.
   Assistant selection is user controlled; OEM power-button behavior varies.
   Background/screen-off wake is a separate phase requiring a trained offline
   keyword model, Android microphone foreground service with visible stop
   notification, battery/noise evaluation and OS-compliant activation. Android's
   standard recognizer explicitly discourages continuous recognition.
6. Validate policy/API in temporary MongoDB, client printing/replay/activation,
   existing Chotu and manual order regressions; capture UI and build APK.

Known diagnosis: Python deliberately refuses digital settlement; only the exact
cash-received pattern confirms Cash, while generic yes does not. Node KOT tools
write PrintLog but return no native print job. The overlay health callback no
longer starts listening. No wake/assistant entry exists.

References: https://developer.android.com/reference/android/speech/SpeechRecognizer
and https://developer.android.com/reference/android/service/voice/VoiceInteractionService
and https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
