# Chotu AI — Product requirements

Date: 2026-11-12 · Version: 1.0 · Status: implementation specification

## Product decision

Chotu is an order automation agent for authenticated restaurant staff. Staff
speak or type an instruction; Chotu resolves the table and menu items, performs
the permitted POS actions, and explains the observed result. The current Chotu
microphone and overlay remain the interface. This work prioritises execution
over additional screens, animations or settings.

Python is feasible for the workflow policy. Flutter continues to handle speech
and display, and the Node/MongoDB backend remains the source of truth for orders,
prices, tax, stock, sales and restaurant isolation.

## Analysis of the existing implementation

| Area | Existing behavior | Consequence |
| --- | --- | --- |
| Speech | Flutter recognition plus optional desktop Python microphone script | A usable input foundation already exists |
| Understanding | Node Gemini/rule parser and Flutter fallbacks | Reuse menu matching and English/Hindi/Hinglish parsing |
| Execution | Flutter mutates its local draft before calling the backend | A failed request can still appear successful |
| Kitchen | Legacy Node SEND_KOT changes table status | A success message alone does not prove an order exists |
| Billing | Legacy Node GENERATE_BILL returns a message | No authoritative invoice is created by that handler |
| Settlement | Existing order service supports settlement; Chotu does not orchestrate it | Order completion is incomplete |
| Reliability | In-memory session and duplicate caches | Restart, concurrent requests and tenant scoping need stronger guarantees |

Sources: `lib/core/services/chotu_service.dart`,
`lib/features/pos/pos_register_screen.dart`,
`backend/src/services/chotu/chotuService.js`, and
`backend/src/services/orderService.js`.

## Users and outcomes

- Waiter: capture and correct a dine-in order, then submit it to the kitchen.
- Cashier/owner/admin: issue an unpaid invoice and record confirmed Cash, UPI or Card received.
- Manager: inspect request receipts and recover an uncertain action.

Success means fewer manual steps while keeping the same authoritative records
that the POS uses. A spoken acknowledgement is never evidence of payment or
physical printer delivery.

## Requirements and acceptance

| ID | Requirement | Acceptance |
| --- | --- | --- |
| C01 | Take multi-item English/Hindi/Hinglish orders | Matched menu IDs and quantities enter the selected table's cart |
| C02 | Remember the active table within an authenticated session | Follow-up adds use that table; switching clears pending confirmation |
| C03 | Clarify missing table, ambiguous item, low confidence and unsupported request | No partial item list is applied; a clear question is returned |
| C04 | Edit quantities and remove draft items | Positive bounded quantities are validated against authoritative products |
| C05 | Enforce menu availability, stock and prices | Unavailable, unknown or insufficient-stock requests do not change the cart |
| C06 | Submit KOT | A real unpaid order and kitchen snapshot exist; repeated unchanged submission is harmless |
| C07 | Generate bill | An immutable unpaid invoice snapshot exists with backend-calculated tax |
| C08 | Complete a paid order | Explicit receipt confirmation of enabled Cash/UPI/Card by a cashier/owner/admin creates one sale and frees the table |
| C09 | Keep digital payment truthful | Method selection alone leaves payment pending; staff must verify receipt before confirming. Chotu never initiates or verifies a bank transaction |
| C10 | Make retries safe | Same request ID and payload returns its durable receipt; changed payload is rejected |
| C11 | Survive uncertainty | Timeout or a partially failed mutation never causes a local success fallback or blind replay |
| C12 | Reuse current UI | No new Chotu page, extra decorative UI or checkout redesign |
| C13 | Scope all work to restaurant and actor | Identical session/request IDs in different restaurants cannot share state/results |
| C14 | Ask before clearing a draft | Confirmation applies to the same table; an issued order/invoice requires normal POS cancellation |
| C15 | Deliver KOT/bills to the saved printer | Immutable delta KOT/receipt jobs are claimed durably before sending; replay never auto-prints twice; uncertainty is visible |
| C16 | Activate with a foreground wake phrase | Opt-in two-minute standby opens Chotu after final exact Hello Chotu; background/lock/dispose stops capture; ambient orders never execute |
| C17 | Support Android assistant entry | ACTION_ASSIST opens the authenticated overlay after unlock and access checks; user selects Apna POS in assistant settings; OEM shortcut support varies |

## Version 1 journey

1. “Table 5 pe do butter naan aur ek paneer tikka laga do.” Chotu validates the
   complete item list and updates the cart.
2. “Butter naan ko 3 kar do.” Chotu updates the draft quantity.
3. “KOT kitchen bhej do.” Chotu creates or updates the real kitchen order.
4. “Bill bana do.” Chotu creates the unpaid invoice and dispatches its print
   snapshot to the configured printer. Failed delivery does not undo the bill.
5. “Settle bill UPI.” Chotu asks whether the full current total was received.
6. “Haan confirm.” An authorised cashier/owner/admin completes
   missing workflow steps, settles the bill, records the sale, and frees the table.

Items added after billing invalidate the old bill; completion regenerates it.
Changing/removing already submitted kitchen items requires the normal POS
correction/cancellation process. Read-only order inspection remains available.

## Boundaries

The current version supports dine-in and confirmed Cash/UPI/Card records.
Existing manual invoices retain their stored variants, discounts and round-off
when settled; new variant/modifier capture and discount editing stay in POS.
Takeaway/delivery automation, split payments, customer editing, refunds,
online-payment verification, always-on background hotword detection and automatic
recovery of ambiguous partial failures are follow-up work. Unsupported operations must
be explained without reporting success. Speech accuracy and provider latency
depend on the existing recognition and optional Gemini integration.

The legacy parse/execute API remains for old clients; the new agent uses a
separate endpoint. Enable the new path only on hosts with Python available.

The 2026-11-16 voice plan is in VOICE_IMPLEMENTATION_PLAN_2026-11-16.md.
The phrase corpus tests command normalization; no acoustic model was fine-tuned.

## Quality targets and release gates

- Deterministic fixtures: 100% of the tested lifecycle and failure criteria pass.
- Duplicate request: zero additional cart increments, orders, invoices or sales.
- No cross-restaurant state or product/order access in isolation tests.
- Planner timeout: bounded to five seconds; unavailable runtime is reported.
- Target agent overhead excluding speech/LLM/database: under one second on a
  supported POS host; measure in deployment before making a latency guarantee.
- Pilot metrics: clarification rate, completion rate, tool failure rate,
  duplicate rate, end-to-end latency and staff corrections. No production
  accuracy or performance claims are made from unit tests.

## Follow-up releases

1. Pilot and observe real speech, printers, tax configuration and recovery.
2. Add independent takeaway/delivery draft ownership and fulfilment details.
3. Integrate verified payment events, split payments and printer acknowledgements.
4. Extend controlled tools for discounts, customer details and kitchen corrections.
