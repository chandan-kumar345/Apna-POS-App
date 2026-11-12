# Chotu AI order automation

Status: FINALIZED
Date: 2026-11-12

User request: analyse Chotu AI, write its PRD and TRD, and implement a feasible
Python agent that takes orders and completes the order flow, with minimal UI work.

Scope: a Python workflow planner behind the existing authenticated Node API;
persistent, tenant-scoped sessions and request receipts; authoritative dine-in
cart edits, KOT creation, unpaid invoices, and explicitly confirmed cash
settlement. Reuse the existing Chotu overlay and POS services. Preserve the
unrelated work already in this checkout.

Acceptance: prove a real API sequence creates a cart, a kitchen order, an unpaid
invoice, then one paid sale and frees the table. Prove clarification, stock,
permissions, tenant boundaries, duplicates, and execution failure do not produce
false success. Run Python tests, focused backend tests, and Flutter checks.

See docs/chotu-ai/PRD.md and docs/chotu-ai/TRD.md for requirements and limits.
