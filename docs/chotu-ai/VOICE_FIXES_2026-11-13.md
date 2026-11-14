# Chotu voice and product detection fixes

Scope: Chotu only. Manual POS order screens, cart execution, billing and table
service implementations are unchanged.

## Root causes and fixes

- The agent treated `can`/`could` as hypothetical language and rejected ordinary
  polite ordering requests. Polite item requests now reach the parser; payment
  questions and conditional/negated cash confirmation remain non-executable.
- Catalog matching removed Hindi characters. Product names and spoken text now
  share Unicode normalization/transliteration. Substring matching uses whole
  phrases, preventing `tea` from matching `Steak`. Ambiguous menu options still
  require clarification; no confidence threshold was lowered.
- Added table-number/no. phrasing, plus/ampersand separators, spelled-out K O T,
  `bhejo`, `banao`, and change-table selection. Quantity edits exclude the table
  number when extracting the requested quantity.
- Microphone startup no longer overlaps TTS. Restarting recognition clears old
  words without submitting them. Stale recognition callbacks are ignored, silence
  exits honestly, partial mobile speech waits for final results, and desktop
  Python must signal readiness before being considered started. Failed Python
  startup falls back to the native Windows listener. Web uses speech_to_text
  rather than only displaying a listening indicator. Permission errors do not
  falsely grant microphone access outside test simulation.
- Chotu offers Hinglish/Hindi/English selection and a scrollable navy interface
  with active table context, compact avatar, typing access and command examples.
  Attention results remain amber rather than appearing as successful orders.
- The validated Python agent is enabled unless explicitly disabled by
  `CHOTU_AGENT_ENABLED=false`. Missing/disabled backend execution displays a
  setup error; the Chotu screen does not execute the old local-first fallback.

Table changes select another table's context. They do not silently transfer an
existing kitchen order to a different table. Bills remain unpaid until explicit,
authorised payment confirmation. Ambiguous multi-action requests are clarified.

## Verification

- Backend: `npx cross-env NODE_ENV=test GEMINI_API_KEY= GOOGLE_API_KEY= jest --runInBand --forceExit --runTestsByPath tests/chotu_automation_agent.test.js tests/chotu_language_regression.test.js tests/chotu_order_flow.test.js`
  → 3 suites, **49 tests passed** in 58.985 seconds. Includes real Python/Mongo
  order -> quantity edit -> table selection -> empty bill refusal -> KOT -> bill,
  alongside existing stock, permissions, duplicate, billing and settlement checks.
- Flutter: voice/order/client/cache tests plus the build-directory screen preview
  → **27 tests passed**. Startup restart regression verifies stale words are not
  resubmitted; the preview asserts that a rejection is not presented as success.
- Targeted Flutter analysis: no issues found.
- Rendered/inspected `build/chotu_validation/chotu_overlay.png` and
  `build/chotu_validation/chotu_rejected.png` at 393 x 852 logical pixels.
- Initial restricted integration checks could not launch Python from its external
  SDK location. Re-running with approved runtime access passed; this was a sandbox
  restriction, not an order-flow fallback.

Recognition engines, audio and permissions are simulated in widget tests. Real
phone microphone accuracy, accents, noisy rooms, native platform permission
approval and physical printer output still require device verification. No app
deployment or production orders were performed.
