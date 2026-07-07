# Shared CappedNotice — unify the two capped-sales-sample warnings

**Date:** 2026-07-06
**Status:** Approved (deferred finding from the 2026-07-05 reorder-parity review)
**Scope:** web_admin only; presentational refactor, no data/behavior change.

## Problem

Two near-duplicate "sales sample was truncated" warnings exist:

- `presentation/features/inventory/CappedNotice.tsx` (reorder page) — cap passed
  as a prop, sourced from `REORDER_SALES_CAP`.
- `SalesReportPage.tsx` — inline block that **hardcodes "2,000" in the copy**
  while the real cap lives in `useReportData`'s private `SALES_FETCH_CAP`.
  Bumping the constant would silently make the banner lie.

Styling has also forked (`border-warning bg-warning-light` vs
`border-warning-light bg-warning-light/40`).

## Design

One shared presentational wrapper; each page owns its sentence and interpolates
its own exported cap constant.

- **Create `presentation/components/common/CappedNotice.tsx`:**
  `({ capped, children }: { capped: boolean; children: ReactNode })` — renders
  `null` unless capped, else the soft warning paragraph
  (`rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm
  text-bodySmall text-warning-dark` — the InventoryFormPage precedent). Test
  alongside: renders children when capped; renders nothing when not.
- **Delete** `features/inventory/CappedNotice.{tsx,test.tsx}`.
- **Reorder page:** import from common; body =
  `Velocity is computed from the most recent
  {REORDER_SALES_CAP.toLocaleString('en-US')} sales — it may be understated for
  this window.`
- **Reports page:** `useReportData` exports `SALES_FETCH_CAP`; inline block →
  `<CappedNotice capped={capped}>Showing the most recent
  {SALES_FETCH_CAP.toLocaleString('en-US')} sales — narrow the date range for
  exact totals.</CappedNotice>`. (Its banner style softens slightly to the
  shared one.)

## Non-goals

No message-template props, no cap changes, no other banner sites.

## Verification

`npm run typecheck` + `npm run test`; emulator run seeding 2,001 sales so the
reports banner actually renders end-to-end with the interpolated "2,000".
