# Race riders — void-request pending claim + double-close message

Approved 2026-07-26. Two small concurrency hardenings; #1 of the gap list
(NAME-TOCTOU lists epic) is deliberately deferred to its own session.

## R2 — one pending void request per sale, by construction

Today `RequestVoidSaleUseCase` guards with `hasPendingForSale` (query) before
`createRequest` (add) — a check-then-write race can produce two pending
requests for one sale.

- New collection `void_request_pending/{saleId}` — the claim. Fields:
  `requestId` (filled inside the tx via pre-allocated doc ref), `requestedBy`,
  `createdAt` (serverTimestamp).
- `createRequest` becomes a transaction: read the claim ref — if it exists,
  throw a `DatabaseException(code: 'void-already-pending')`; else `tx.set`
  the claim and `tx.set` a pre-allocated `void_requests` doc. The use case
  keeps `hasPendingForSale` as the friendly fast-path check; the transaction
  is the authoritative backstop, and its failure maps to the same
  "A void request for this sale is already pending" message.
- `resolve()` gains `required String saleId` and deletes the claim in the same
  batch/tx as the status update (delete is idempotent — resolving a legacy
  request without a claim is fine). Call sites (approve/reject use cases)
  pass `request.saleId`.
- Rules (additive only — `void_requests` block unchanged so +17 clients keep
  working): `void_request_pending/{saleId}` — read any active user; create by
  active users with `requestedBy == request.auth.uid`; delete by admin
  (resolve path); update never. NO existsAfter cross-check yet: fleet still
  writes requests without claims until the next APK; revisit with the
  NAME-TOCTOU epic.
- Prod has zero void_requests (post-wipe) → no backfill needed.
- Rules tests: cashier can create claim; second create of the same saleId
  fails (doc exists → create doesn't match); non-admin cannot delete; admin can.

## R3 — double-close loser gets "already closed"

`daily_closings` rules are already create-only (`update, delete: if false`),
so a same-instant double close already converges to the first writer. The
loser's `set()` is denied and currently surfaces as a raw failure.

- `CloseDayUseCase`: when `saveClosing` throws a permission-denied
  `DatabaseException`, return the existing `already-closed` failure
  ("This day has already been closed.") instead of the generic message —
  mirroring the checkout permission-denied mapping pattern (`9280a88`).
- Test: repository stub throwing permission-denied → result is the
  already-closed failure. No rules change.

## Verification
TDD; `flutter test` + analyze; rules suite green. Deploy: rules only
(additive claim collection) — user-confirmed at ship time. Code rides +18.
