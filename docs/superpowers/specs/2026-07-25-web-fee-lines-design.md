# Web admin: fee-line awareness (totals + sale detail)

Date: 2026-07-25
Surface: `web_admin/` only. No mobile, schema, or rules changes.

## Problem

Mobile now writes `feeLines` on sales (shipped 2026-07-25, APK +15). The web
admin's converter drops the field and `saleGrandTotal = partsRevenue +
laborRevenue`, so for a fee-bearing sale every web Total (sales table, sale
detail, printable receipt, recent-sales, CSV) understates the sale while the
payment-method breakdown (tender-derived) shows the full amount — two
different totals for the same sale on one screen.

## Decisions (user-approved as the shop-fees follow-up)

Minimal correctness slice, mobile-parity semantics:

1. `saleConverter.ts` parses `feeLines` (id/name/amount; absent → `[]`).
2. `Sale.ts`: add `feeLines` to the entity type; `saleFeesTotal(sale)`
   helper; `saleGrandTotal = partsRevenue + laborRevenue + feesTotal`.
   Parts/labor helpers unchanged.
3. Web sale detail (`SaleDetailPage.tsx`): fee lines itemized in their own
   block (mirroring how labor lines are shown) so the total visibly adds up.
   Printable `Receipt.tsx`: fee lines + a Shop fees recap row, mirroring
   labor's treatment (matches the mobile receipt shipped in +15).
4. Everything that consumes `saleGrandTotal` (SalesTable, RecentSales,
   csv.ts) is fixed automatically — verify, don't fork.
5. Reports aggregation: web `summarizeSales` gross/net stay parts-only
   (mirror mobile); if the web report screen shows a labor revenue line,
   add the matching Shop fees line; otherwise totals-by-tender already
   include fees and nothing more is needed — decide from the actual code
   at plan time and record which.

## Out of scope

Web POS fee ENTRY (web checkout gaining a fee section), web fee-catalog
management page — later slices if ever needed; the shop operates fees from
mobile.

## Testing (Vitest, from web_admin/)

- Converter: feeLines parsed; legacy doc → `[]`.
- Entity: `saleFeesTotal` + `saleGrandTotal` math (worked example incl.
  discount).
- Component: sale detail + receipt render fee blocks (and none for legacy
  sales); a totals-reconciliation assertion on the detail page.
- `npm run typecheck`, `npm run test`, `npm run build` all green.
