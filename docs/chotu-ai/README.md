# Chotu AI order agent

[PRD](PRD.md) · [TRD](TRD.md) · [Architecture](ARCHITECTURE.md) · [Stack](STACK.md)

## Run it

1. Install Python 3.11+ on the same host as the Node backend. The order planner
   needs no pip packages. The separate microphone script's dependencies are not
   required by this agent.
2. Keep the existing backend MongoDB/JWT configuration. If Python is not on PATH,
   add `CHOTU_PYTHON_BIN=C:/path/to/python.exe` to `backend/.env` (or the relevant
   executable path on Linux).
3. From `backend`, check the runtime:

   ```powershell
   node src/scripts/startChotuAgent.js --check
   ```

4. Start the backend with the agent enabled:

   ```powershell
   npm run start:chotu
   ```

   For normal deployment/startup, setting `CHOTU_AGENT_ENABLED=true` and using
   `npm start` is equivalent. The example environment defaults to disabled for
   a controlled rollout. The database account must be allowed to create the
   session/receipt/lock indexes; startup of agent turns waits for these indexes.

5. Sign in to Flutter, enable the existing Chotu voice setting, and open the
   current Chotu overlay. Its health request selects the agent automatically.
   No additional page or control is required. A new overlay starts a conversation
   for the selected table; follow-ups retain that table until explicitly changed.

Use a synced test restaurant first. A local draft that differs from the server
is preserved and the instruction is rejected: save/KOT or reconcile it in the
normal POS before using the agent. This version requires an online backend.

## Try a complete order

Use a real configured table and menu items for the signed-in restaurant:

1. “Table 5 pe do butter naan aur ek paneer tikka laga do.”
2. “Butter naan ko 3 kar do.”
3. “KOT kitchen bhej do.”
4. “Bill bana do.” The invoice remains unpaid.
5. After collecting cash: “Cash received, settle order.”

The final instruction also performs any missing KOT and billing steps. Only
owner/admin/cashier roles may settle. “Complete order” alone asks for cash
confirmation; saying “yes” does not establish that cash was received. Confirmations
expire after two minutes and are bound to the conversation/table. Speak item
changes and KOT/bill instructions in separate turns.

Takeaway/delivery, digital payment verification, discounts, custom modifiers,
variants, refunds and changes to already submitted kitchen quantities use the
normal POS in version 1. The agent creates kitchen/invoice/receipt records; it
does not claim that a physical printer has acknowledged delivery.

## API use

`POST /api/v1/chotu/agent/turn` requires a valid user Bearer token and POS
permission. Generate a new `requestId` for each new instruction and reuse that
same ID and payload for a retry:

```json
{
  "sessionId": "terminal-1-conversation-unique-id",
  "requestId": "unique-utterance-id",
  "text": "Table 5 pe do butter naan laga do",
  "currentTableContext": "T-5"
}
```

The Flutter client additionally sends `expectedDrafts` containing its non-empty
local table drafts as `{tableNumber, items: [{productId, quantity}]}`. A mismatch
for the target table rejects the turn without installing a replacement local
snapshot. These draft expectations are included in the request identity hash.

Business/user/role come from authentication. Client-supplied payment flags,
plans, prices or business IDs are not execution authority. Normal responses
have `data.status`, `data.steps`, `data.chotuMessage` and authoritative snapshots.
`needs_confirmation`, `needs_clarification`, `unsupported`, `rejected` and
`needs_review` must not be rendered as an executed order.

## Retry and recovery

The client persists a pending request before dispatch and reuses it after a
timeout/app restart. If staff speak another instruction while one is uncertain,
the old receipt is resolved first and staff are asked to repeat the new one.
Completed duplicates return an immutable receipt plus a separate current read
snapshot, so an old receipt does not roll back a newer displayed cart. Receipts
can still be read/replayed when the feature is disabled.

`GET /api/v1/chotu/agent/sessions/:sessionId` returns the caller's session, latest
turn and unresolved review turns. A failed tool may already have written to the
existing POS services. The agent retains its table lock, exposes successful
steps and the uncertain action, and stops further agent writes to that table.

For operator recovery:

1. Stop new agent work for the affected business/host and confirm that no old
   worker is still running.
2. Read the session/turn receipt and inspect that restaurant's cart, order,
   print snapshots, sale, inventory and table records. Do not repeat settlement
   merely because the receipt says it needs review.
3. Reconcile through the normal authorised POS process. A maintainer can then
   record the outcome on an interrupted processing turn and release only the
   exact affected session/table lock, scoped to business and request identity.
   Existing completed receipts stay immutable.
4. Resume with a new request ID after review. Automatic unlock/expiry is
   intentionally absent because a timed-out order/payment write may have committed.

There is no automatic rollback or claim of distributed exactly-once execution.
Manual POS writes do not take the agent's table lock; avoid concurrent manual
edits during an agent operation. Protecting every POS write with one shared
concurrency contract is follow-up work.

## Validation commands

From `backend/python`:

```powershell
python -m unittest discover -s tests -v
```

From `backend`:

```powershell
npm test -- --runTestsByPath tests/chotu_automation_agent.test.js
```

From the repository root:

```powershell
flutter test test/chotu_automation_client_test.dart test/chotu_automation_snapshot_test.dart --reporter expanded
```

See `.gsd/JOURNAL.md` for observed results, including broader checks and limits.
