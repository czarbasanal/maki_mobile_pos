# Web POS — Phase 2: Tenders (gcash / maya / mixed / salmon) — Design

**Date:** 2026-06-20
**Surface:** React web admin (`web_admin/`).
**Status:** Design — approved-in-brainstorm, pending `writing-plans`.
**Epic:** Web POS (full mobile parity, phased). Intent: **remote / back-office
sales** (phone/B2B orders, corrections from the office — not a live counter
register).

**Phase plan:** 1) cart + cash checkout ✅ · **2) tenders (this doc)** · 3) labor
+ mechanic · 4) drafts · 5) receipt + void.

## 1. Problem & intent

Phase 1 shipped a working cash register but hardcodes every sale to
`paymentMethod = 'cash'`, `tenders = { cash: grandTotal }`. Phase 2 lets the
cashier pick how a sale was paid: a single digital method (GCash / Maya), a
**Mixed** split (cash + one digital), or **Salmon** (a downpayment collected
today with the balance owed as a receivable).

### Key finding — the read side already exists

Everything that *consumes* tenders is already built and unchanged by this phase:

- **Data model:** `Sale.tenders: Partial<Record<PaymentMethod, number>>`, the
  full `PaymentMethod` enum (`cash | gcash | maya | salmon | mixed`),
  `realTenderMethods`, `paymentMethodHasFees`, and `saleEffectiveTenders`
  (normalizes a single-method sale to `{paymentMethod: grandTotal}`).
- **Reporting:** `summarizeSales` buckets each sale's **tenders** (not the
  label) into `byPaymentMethod`; `salmon` is its own bucket and `mixed` always
  stays 0.
- **Display:** `SalesReportPage` renders a cash/gcash/maya/**salmon** breakdown;
  `SaleDetailPage` lists the per-tender split for any multi-tender sale.
- **Persistence:** `FirestoreSaleRepository.create()` writes whatever
  `tenders` + `paymentMethod` it is handed — verbatim.

There is **no** EOD "cash on hand" reconciliation on web, so a Salmon balance
has nothing to pollute; it simply appears as the `salmon` bucket line in the
Sales report — money expected, never counted as cash.

**Therefore Phase 2 is a pure checkout-UI + pure-helper slice. No schema, repo,
reporting, store-shape, or display changes.**

## 2. Cross-surface contract (mirror mobile exactly)

From `docs/superpowers/specs/2026-05-28-salmon-mixed-payment-methods-design.md`.
`paymentMethod` is the cashier-chosen **label**; `tenders` is the actual money
by method and always sums to `grandTotal`.

| mode | `paymentMethod` (label) | `tenders` | `amountReceived` | `changeGiven` |
|---|---|---|---|---|
| cash | `cash` | `{cash: total}` | cashReceived | `max(0, cashReceived − total)` |
| gcash | `gcash` | `{gcash: total}` | total | 0 |
| maya | `maya` | `{maya: total}` | total | 0 |
| mixed | `mixed` | `{cash: total − split, [digital]: split}` | total | 0 |
| salmon | `salmon` | `{[dpMethod]: split, salmon: total − split}` | split (downpayment) | 0 |

- **Mixed** = cash + exactly one digital (GCash *or* Maya). The cash portion is
  the remainder; it is treated as exact (no change on the cash half).
- **Salmon** = a downpayment paid today by any method (cash / GCash / Maya) plus
  a `salmon` balance receivable. Only the downpayment is collected today; the
  sale is valid even though collected < `grandTotal`.

## 3. Pure helpers — new `src/domain/sales/payment.ts` (TDD, vitest)

The UI fills a `PaymentDraft`; pure functions derive the sale fields. Money is
pesos with 2 decimals — split remainders are **rounded to cents** to kill
floating-point dust.

```ts
export type PaymentMode = 'cash' | 'gcash' | 'maya' | 'mixed' | 'salmon';
export type DigitalMethod = 'gcash' | 'maya';
export type DpMethod = 'cash' | 'gcash' | 'maya';

export interface PaymentDraft {
  mode: PaymentMode;
  cashReceived: number;   // mode 'cash' only — cash handed (drives change)
  digitalMethod: DigitalMethod; // mode 'mixed' — which digital half
  dpMethod: DpMethod;     // mode 'salmon' — downpayment method
  splitAmount: number;    // 'mixed' = digital amount; 'salmon' = downpayment
}
```

Functions (each pure, `(draft, grandTotal) => …`):

- `paymentLabel(mode): PaymentMethod` — 1:1 map (mode values match enum values).
- `buildTenders(draft, total): Partial<Record<PaymentMethod, number>>` — per the
  table; cash portion / salmon balance rounded to cents.
- `amountReceivedFor(draft, total): number` — per the table.
- `changeGivenFor(draft, total): number` — cash → `max(0, cashReceived − total)`;
  every other mode → 0.
- `paymentError(draft, total): string | null` — `null` when valid, else a short
  human message:
  - cash → require `cashReceived ≥ total` ("Cash received is less than the total").
  - gcash / maya → always valid.
  - mixed → require `0 < splitAmount < total` ("Digital amount must be between
    ₱0 and the total").
  - salmon → require `0 < splitAmount < total` ("Downpayment must be between ₱0
    and the total").

`paymentError` returning `null` is the single source of "can complete" for the
button gate (combined with a non-empty cart).

## 4. State — local to PosPage via `usePaymentDraft` (no cartStore change)

Payment entry is transient: reset after each sale and **not** part of the cart
that Phase-4 drafts will persist. So it stays local — exactly how
`amountReceived` already lives as `useState` in PosPage today. A small
`usePaymentDraft(grandTotal)` hook (`src/presentation/hooks/`) holds the draft
and exposes setters plus the derived `{ tenders, paymentMethod, amountReceived,
changeGiven, error, isValid }`, so PosPage doesn't accumulate five `useState`s.

- `reset()` returns the draft to `{ mode: 'cash', cashReceived: 0, … }` and is
  called after a completed sale (alongside the existing cart `clear()`).
- Switching `mode` resets the entered amounts (`cashReceived` / `splitAmount` →
  0), mirroring mobile's discount-switch reset, so a stale amount can't carry
  into a different mode.

The cartStore keeps its Phase-1 shape (lines + discountType only).

## 5. Checkout UI (PosPage) — chip row + conditional inputs

The Phase-1 "Cash received" card becomes a **Payment** card:

- **Chip row** (wrap of selectable chips): Cash · GCash · Maya · Mixed · Salmon.
  Selected chip is emphasized; neutral styling otherwise (color discipline —
  no decorative color).
- **Conditional input area** swaps on the selected mode:
  - **Cash** — `Cash received` number input + `Change` row (unchanged from P1).
  - **GCash / Maya** — no amount input; a confirmation line ("Paid in full via
    GCash — ₱{total}"). `amountReceived = total`, change 0.
  - **Mixed** — a GCash | Maya sub-selector + `Digital amount` input +
    read-only `Cash portion: ₱{total − split}`.
  - **Salmon** — a Cash | GCash | Maya downpayment sub-selector + `Downpayment`
    input + read-only `Salmon balance: ₱{total − split}` (labeled a receivable).
- **Error line** renders `paymentError` when present.
- **Complete** button gated on `lines.length > 0 && isValid && !checkout.isPending`.

**Intentional web divergence:** mobile keeps an "amount received" box for
GCash/Maya; web drops it (a digital tender is always exact) — back-office tool,
less noise. Approved in brainstorming.

## 6. Wiring — `useCheckout`

`CheckoutInput` carries the computed payment fields instead of hardcoding cash:

```ts
interface CheckoutInput {
  lines: CartLine[];
  discountType: DiscountType;
  paymentMethod: PaymentMethod;
  tenders: Partial<Record<PaymentMethod, number>>;
  amountReceived: number;
  changeGiven: number;
}
```

`mutationFn` plugs these straight into `saleInput` (drops the hardcoded
`PaymentMethod.cash` and the `cashTenders(grandTotal)` call). The now-unused
`cashTenders` helper in `cart.ts` is removed (and its test, if any).

## 7. Testing

- **`payment.test.ts`** (pure, the core of the slice): for every mode assert
  `buildTenders`, `amountReceivedFor`, `changeGivenFor`, and `paymentError`,
  including boundaries — `splitAmount = 0`, `splitAmount = total`,
  `cashReceived < total`, `cashReceived ≥ total`, and cent-rounding of the cash
  portion / salmon balance (e.g. total 100.00, digital 33.33 → cash 66.67).
- **`useCheckout.test.ts`** — update to assert the passed `paymentMethod` +
  `tenders` reach `repo.create` unchanged (e.g. a mixed split persists
  `{cash, gcash}`).
- **Manual browser smoke** (mirror Phase 1): complete one **Mixed** sale and one
  **Salmon** sale; confirm the Sales report shows the split in the right
  buckets and Sale Detail shows the per-tender breakdown.

`npm run typecheck && npm run test` green before done.

## 8. Out of scope (carry mobile's)

- Next-day Salmon collection / settlement workflow (receivable is report-only).
- Mixed combinations beyond cash + one digital (no GCash+Maya, no 3-way).
- Change on the cash portion of a Mixed sale (exact remainder).
- Per-sale customer / contact records for Salmon.
- Labor + mechanic (Phase 3), drafts (Phase 4), receipt + void (Phase 5).
