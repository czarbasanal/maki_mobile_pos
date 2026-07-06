# Web reorder engine — velocity-window parity with mobile POs

**Date:** 2026-07-05
**Status:** Draft — awaiting user review
**Scope:** web_admin only. Closes the "web-admin window parity" open item recorded after the mobile Purchase Orders work (mobile yesterday-cutoff window shipped in `3952062`).

## Problem

The web reorder page (`/inventory/reorder`) and mobile PO suggestions share the same
pure reorder formula, but the web velocity window still includes **today's partial
day**: `start = startOfDay(subDays(now, windowDays - 1))`, `end = endOfDay(now)`
(`web_admin/src/presentation/hooks/useReorderSuggestions.ts`). Early in the day this
dilutes velocity — today counts as a full day in the divisor while contributing
almost no sales — so web suggests less than mobile for the same window.

Mobile deliberately fixed this: `windowDays` **complete** days ending **yesterday**
(`lib/presentation/providers/purchase_order_provider.dart:68-84`).

Two adjacent gaps ride along:

- Web caps the sales sample at **2,000** docs vs mobile's **10,000**
  (`reorderSalesCap`), so a busy 90-day window can understate velocity.
- The hook already exposes a `capped` flag, but the page ignores it — the
  understatement is silent.

## Non-goals

- No low-stock / out-of-stock buckets on web (mobile-only for now; possible follow-up).
- No purchase-order entity, persistence, lifecycle, or receiving linkage on web —
  full PO-on-web is a separate epic with its own spec if wanted.
- No mobile changes, no Firestore schema or rules changes.

## Design

All changes in `web_admin/`:

### 1. Window parity (`useReorderSuggestions.ts`)

New window, matching mobile's semantics exactly:

```
start = startOfDay(subDays(now, windowDays))   // windowDays full days back
end   = endOfDay(subDays(now, 1))              // yesterday 23:59:59.999
```

`velocityPerDay` keeps dividing by `windowDays` — now every day in the divisor is a
complete day. Extract the window math into a small pure helper
`reorderWindow(now: Date, windowDays: number): { start: Date; end: Date }`
(in `web_admin/src/domain/reorder/`) so it is unit-testable without mocking the
sale repository.

### 2. Cap parity

`SALES_CAP`: 2000 → **10000** (match mobile's `reorderSalesCap`).

### 3. Surface the capped flag (`ReorderSuggestionsPage.tsx`)

When the hook reports `capped: true`, render a subtle warning near the window
controls: "Velocity computed from the most recent 10,000 sales — may be
understated for this window." Neutral styling per the app's color discipline
(color only for status semantics — this is a warning, so muted amber is fine).

## Testing

TDD — failing tests first:

- `reorderWindow` unit tests: window ends at yesterday end-of-day; starts
  `windowDays` days before today's start; today's sales excluded; correct across a
  month boundary.
- `useReorderSuggestions` / page: capped banner renders when `capped` is true and
  not otherwise.
- Existing `computeReorderSuggestions` / `unitsSoldByProduct` tests unchanged
  (pure engine untouched).

## Verification

`npm run typecheck` + `npm run test` in `web_admin/`, then browser-smoke
`/inventory/reorder`: confirm suggestions render, banner behavior, and that
velocity for a given window matches mobile's for the same product.
