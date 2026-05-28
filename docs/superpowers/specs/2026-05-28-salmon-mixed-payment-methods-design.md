# Salmon & Mixed Payment Methods — Design

**Date:** 2026-05-28
**Status:** Approved (pending spec review)

## Problem

Add two new payment methods to the POS:

1. **Mixed** — a single sale paid partly in cash and partly via one digital method
   (GCash or Maya). Example: ₱300 cash + ₱700 GCash on a ₱1,000 sale.
2. **Salmon** — the customer pays a **downpayment** at checkout (any method) and the
   **remaining balance is covered by Salmon the next day**. Only the downpayment is
   collected today; the balance is a **receivable**. End-of-day reporting must surface
   the Salmon receivable, and the balance must never count as cash on hand.

Today a sale carries a single `paymentMethod`, and the whole `grandTotal` is attributed
to it (for `amountReceived`/change and for the `SalesSummary.byPaymentMethod` breakdown).
Both new methods break that single-method assumption.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Salmon balance tracking | **Report-only receivable** — no next-day collection/settlement workflow. Surface the receivable at EOD. |
| Salmon downpayment method | **Any method** (cash / GCash / Maya). Only a cash downpayment is cash on hand. |
| Mixed combinations | **Cash + one digital** (cash+GCash or cash+Maya); exactly two tenders, one must be cash. |
| Data model | **Approach A** — a per-sale tender breakdown (`Map<PaymentMethod, double>`). |

## Architecture: per-sale tender breakdown

A sale gains `tenders: Map<PaymentMethod, double>` — the actual money by method, always
summing to `grandTotal`. `paymentMethod` remains the cashier-chosen **label**.

| Scenario | `paymentMethod` (label) | `tenders` |
|---|---|---|
| Cash (single) | `cash` | `{cash: grandTotal}` |
| GCash / Maya (single) | `gcash` / `maya` | `{gcash: grandTotal}` etc. |
| Mixed | `mixed` | `{cash: x, gcash: y}` (x + y = grandTotal) |
| Salmon | `salmon` | `{<dpMethod>: dp, salmon: balance}` (dp + balance = grandTotal) |

Reporting sums the **tenders**, never the label — so a Mixed sale feeds the cash + digital
buckets, and a Salmon sale's balance lands in a dedicated `salmon` bucket. `mixed` never
appears as a tender bucket.

## Data model

### `PaymentMethod` enum (`lib/core/enums/payment_method.dart`)

Add two values:

- `salmon('salmon', 'Salmon')` — a real **tender bucket** representing the receivable.
- `mixed('mixed', 'Mixed')` — a sale-level **label only**; never a tender key.

`hasFees` stays false for both. `fromString` continues to default to `cash` for unknown
values (backward compatible).

### `SaleEntity` / `SaleModel`

Add `final Map<PaymentMethod, double> tenders;`

- Constructor default: `const {}` (so legacy/programmatic construction is safe).
- `SaleModel.fromMap`: read `tenders` as `Map<String, num>` keyed by `PaymentMethod.value`.
  **If absent or empty, derive `{paymentMethod: grandTotal}`** — backward compatibility for
  all existing sales.
- `toMap` / `toCreateMap`: serialize `tenders` as `{ '<method.value>': amount }`.
- `copyWith` and `props` updated.

Helper getters on `SaleEntity`:

- `double get cashCollected => tenders[PaymentMethod.cash] ?? 0;`
- `double get salmonBalance => tenders[PaymentMethod.salmon] ?? 0;`

### Payment validity

`amountReceived` / `changeGiven` semantics:

- **Single cash:** `amountReceived` = cash handed (may exceed total); `changeGiven` = excess.
- **Single GCash/Maya, Mixed:** `amountReceived` = `grandTotal`; `changeGiven` = 0.
- **Salmon:** `amountReceived` = downpayment (collected today); `changeGiven` = 0. The sale
  is valid even though collected < `grandTotal` (the balance is a receivable).

Validation rules enforced at checkout (cart) and in `ProcessSaleUseCase`:

- Single/Mixed: tenders sum to `grandTotal` (cash single may exceed → change on cash).
- Mixed: `0 < digitalAmount < grandTotal`; cash portion = remainder.
- Salmon: `0 < downpayment < grandTotal`; `salmon` balance = remainder.

## Reporting & End-of-Day

### `SalesSummary` (`lib/domain/repositories/sale_repository.dart`) + `getSalesSummary` impl

- `byPaymentMethod` is computed by **summing each sale's `tenders`** (not adding
  `grandTotal` to the single method). Buckets: cash / gcash / maya / salmon.
- `Σ byPaymentMethod == netAmount` still holds (tenders per sale sum to grandTotal).
- Add `double get salmonReceivable => byPaymentMethod[PaymentMethod.salmon] ?? 0;`
- The sales-report "Payment Methods" card iterates `byPaymentMethod`, so a **Salmon** line
  appears automatically.
- **`mixed` is never a tender**, so it must not appear as a bucket. The impl currently
  pre-seeds `byPaymentMethod` with every `PaymentMethod.values` at 0; do **not** seed
  `mixed` (and the breakdown card should skip zero-amount buckets) so no empty "Mixed"
  line renders.

### End-of-Day

`DailyClosingDraft.fromData` (`lib/domain/entities/daily_closing_entity.dart`):

- `cashSales` = `byPaymentMethod[cash]` (unchanged mechanism; now correctly only cash
  tenders, including cash downpayments and Mixed cash portions).
- `nonCashSales` = sum of `byPaymentMethod` entries where key is **neither `cash` nor
  `salmon`** (i.e., gcash + maya collected). *(Change: currently sums all non-cash keys.)*
- New `salmonReceivable` = `byPaymentMethod[salmon] ?? 0`, carried onto `DailyClosingDraft`.
- `expectedCashFor` / `varianceFor` unchanged — Salmon balances never affect cash on hand.

`DailyClosingEntity` + `DailyClosingModel` gain a `salmonReceivable` field (snapshotted at
close, serialized like the other doubles, defaulting to 0 on read).

`CloseDayUseCase` populates `salmonReceivable` from the draft.

### EOD screen + history

- **`EndOfDayScreen`** Sales block: add a **"Salmon receivable"** row (shown when > 0),
  clearly separate from the cash reconciliation — it is money expected from Salmon the next
  day, not cash on hand.
- **`DailyClosingHistoryScreen`** detail: add the Salmon receivable line.

## Checkout UX

`PaymentSection` (`lib/presentation/mobile/widgets/pos/payment_section.dart`):

- Replace the 3-way `SegmentedButton` with a **wrap of selectable chips**: Cash, GCash,
  Maya, Mixed, Salmon.
- Selecting a method swaps the input area:
  - **Cash / GCash / Maya** — unchanged: `Amount Received` input + change display (change
    only meaningful for cash).
  - **Mixed** — a digital sub-selector (GCash | Maya) + a `Digital amount` input. Cash
    portion = `grandTotal − digital` shown read-only. Builds `tenders {cash, <digital>}`.
  - **Salmon** — a downpayment method sub-selector (Cash | GCash | Maya) + a `Downpayment`
    input. `Salmon balance = grandTotal − downpayment` shown read-only. Builds
    `tenders {<dpMethod>, salmon: balance}`.

`CartState` extends to hold the selected mode/label, the sub-method, and the entered amount,
and computes the `tenders` map + `amountReceived`/`changeGiven` per the rules above. The
Confirm button is gated on the validation rules. `ProcessSaleUseCase` writes `tenders` onto
the created sale.

## Display

- **Sale Detail — Payment section:** when a sale has more than one tender, list the
  breakdown under the Payment Method row:
  - Mixed → `Cash ₱300 · GCash ₱700`
  - Salmon → `Downpayment (Cash) ₱500 · Salmon balance ₱1,500`
- **Receipt:** add tender lines in the totals area for multi-tender sales; single-tender
  receipts unchanged.

## Testing

Unit tests:

- **`SaleModel`**: `tenders` round-trip through `toMap`/`fromMap`; a legacy map with no
  `tenders` derives `{paymentMethod: grandTotal}`.
- **`getSalesSummary`** (repository impl): Mixed splits into cash + digital buckets; Salmon
  downpayment → cash bucket and balance → salmon bucket; `Σ byPaymentMethod == netAmount`.
- **`DailyClosingDraft.fromData`**: `cashSales` = cash only; `nonCashSales` excludes salmon;
  `salmonReceivable` = salmon bucket; `expectedCash` unaffected by Salmon balances.
- **Tender builder / cart validation**: Mixed must sum to total with a positive digital
  amount strictly less than total; Salmon downpayment strictly within `(0, grandTotal)`.

Checkout, receipt, and sale-detail UI verified manually in the running app.

## Out of scope

- Next-day Salmon collection / settlement workflow (receivable status, marking collected).
  This release reports the receivable only.
- Mixed combinations beyond cash + one digital (no GCash+Maya, no 3-way splits).
- Change calculation on the cash portion of a Mixed sale (treated as exact remainder).
- Per-sale customer records for Salmon (no customer/contact tracking).
