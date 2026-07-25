# Web Fee-Line Awareness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Web admin parses `feeLines`, includes them in `saleGrandTotal`, and itemizes them on the sale detail, printable receipt, CSV, and sales summary — so every web total matches the payment breakdown.

**Architecture:** Mirror the LABOR pattern at every site: `FeeLine` entity beside `LaborLine`, `parseFeeLines` beside `parseLaborLines`, `saleFeesTotal` beside `saleLaborSubtotal`, fee rows beside labor rows in `SaleDetailPage`/`Receipt`/CSV, `feesRevenue` beside `laborRevenue` in `summarizeSales`. Consumers of `saleGrandTotal` (SalesTable, RecentSales, csv Total) are fixed automatically by the helper change.

**Tech Stack:** React + TypeScript + Vitest (run everything from `web_admin/`).

**Spec:** `docs/superpowers/specs/2026-07-25-web-fee-lines-design.md`

## Global Constraints

- Branch: `feat/web-fee-lines` (checked out; spec committed).
- `web_admin/` ONLY — no mobile, schema, or rules changes.
- Mobile-parity semantics: `FeeLine { id: string; name: string; amount: number }` (map key `feeLines`; absent → `[]`); `saleGrandTotal = salePartsRevenue + saleLaborRevenue + saleFeesTotal`; parts/labor helpers and profit fields UNCHANGED (fees are zero-cost revenue but NOT added to profit); `summarizeSales` gross/net stay parts-only, `feesRevenue` is its own field like `laborRevenue`.
- Fee names are prose (normal font); amounts use each surface's existing money formatting.
- Web POS fee ENTRY and a web fee-catalog page are OUT OF SCOPE.
- Verify per task with named Vitest files; `npm run typecheck` + `npm run test` + `npm run build` in the final task. All commands from `web_admin/`.

---

### Task 1: Domain + converter + summary (`feeLines` through the data layer)

**Files:**
- Create: `web_admin/src/domain/entities/FeeLine.ts`, `web_admin/src/data/converters/feeLines.ts`
- Modify: `web_admin/src/domain/entities/Sale.ts` (interface + helpers), `web_admin/src/domain/entities/index.ts` (barrel — READ to confirm export style), `web_admin/src/data/converters/saleConverter.ts` (to/from), `web_admin/src/domain/sales/summarizeSales.ts` (feesRevenue)
- Test: extend `web_admin/src/domain/entities/Sale.test.ts`, `web_admin/src/data/converters/saleConverter.test.ts`, `web_admin/src/domain/sales/summarizeSales.test.ts` (READ each; mirror their labor cases exactly)

**Interfaces:**
- Produces (Task 2 consumes): `FeeLine { id: string; name: string; amount: number }`; `parseFeeLines(value: unknown): FeeLine[]` (mirror `parseLaborLines` in `web_admin/src/data/converters/laborLines.ts` — READ it and clone its coercion/defaults, `amount` defaulting 0); `Sale.feeLines: FeeLine[]`; `saleFeesTotal(sale: Sale): number`; `saleGrandTotal` now includes fees; `summarizeSales(...).feesRevenue: number`.

- [ ] **Step 1: Write failing tests.** Mirror each file's labor tests:

`Sale.test.ts` — extend its sale fixture builder with `feeLines` (default `[]`; READ the fixture) and add:

```ts
  it('saleFeesTotal sums fee lines; saleGrandTotal includes them', () => {
    const s = sale({
      // fixture args mirroring the labor test: parts 1000 gross − 100 discount,
      // labor 300, fees [{ id: 'f1', name: 'Electric charge', amount: 150 }]
    });
    expect(saleFeesTotal(s)).toBe(150);
    expect(saleGrandTotal(s)).toBe(1350); // 900 parts + 300 labor + 150 fees
    expect(saleTotalProfit(s)).toBe(/* unchanged by fees — same value the labor test expects for parts+labor */);
  });

  it('legacy sale without feeLines totals as before', () => {
    const s = sale();
    expect(saleFeesTotal(s)).toBe(0);
    expect(saleGrandTotal(s)).toBe(/* the existing grand-total expectation */);
  });
```

(Resolve the `/* … */` values from the file's actual fixtures — they are placeholders for THIS plan only because the fixture shape lives in the test file; the committed test must contain literal numbers.)

`saleConverter.test.ts` — mirror its laborLines round-trip case: doc with `feeLines: [{ id, name, amount }]` parses; doc without → `[]`; `toFirestore` writes `feeLines`.

`summarizeSales.test.ts` — mirror the laborRevenue cases: fees roll up into `feesRevenue`; gross/net unchanged; voided sales excluded (follow the file's existing exclusion case).

- [ ] **Step 2:** `cd web_admin && npx vitest run src/domain/entities/Sale.test.ts src/data/converters/saleConverter.test.ts src/domain/sales/summarizeSales.test.ts` → FAIL (missing types/fields).
- [ ] **Step 3: Implement.**

`FeeLine.ts` (mirror `LaborLine.ts`'s comment style):

```ts
// Mirror of lib/domain/entities/fee_line_entity.dart. Stored INLINE on the
// sale document's `feeLines` array. Shop fees belong to the SHOP (management),
// are never discounted, and have zero cost — a third revenue track beside
// parts and labor.
export interface FeeLine {
  id: string;
  name: string;
  amount: number;
}
```

`feeLines.ts`: clone `laborLines.ts`'s parser shape for `{ id, name, amount }`.
`Sale.ts`: add `feeLines: FeeLine[]` to the interface; add

```ts
export function saleFeesTotal(sale: Sale): number {
  return sale.feeLines.reduce((sum, line) => sum + line.amount, 0);
}
```

and change `saleGrandTotal` to `salePartsRevenue(sale) + saleLaborRevenue(sale) + saleFeesTotal(sale)` (update the section comment: grandTotal = parts + labor + fees). Do NOT touch profit helpers.
`saleConverter.ts`: `toFirestore` gains `feeLines: sale.feeLines`; `fromFirestore` gains `feeLines: parseFeeLines(d.feeLines)`.
`summarizeSales.ts`: READ it; add `feesRevenue` accumulation + output field exactly as `laborRevenue` is done.
Barrel: export `FeeLine` + helper per the file's style.

- [ ] **Step 4:** Re-run the three test files → PASS. `npm run typecheck` → clean (this catches every `Sale` literal in tests/components missing `feeLines` — fix those fixtures by adding `feeLines: []`).
- [ ] **Step 5:** Commit: `feat(web): parse feeLines; grand total includes shop fees`

---

### Task 2: Displays — sale detail, receipt, CSV, summary line

**Files:**
- Modify: `web_admin/src/presentation/features/reports/SaleDetailPage.tsx` (fee rows beside the labor rows at ~142, and a `Row label="Shop fees"` beside the Labor row at ~157, both gated on `feeLines.length > 0`), `web_admin/src/presentation/features/reports/Receipt.tsx` (fee lines beside labor at ~52, `Line label="Shop fees"` beside Labor at ~63, gated), `web_admin/src/core/utils/csv.ts` (header gains `'fees'` after `'labor'`; row gains `cell(saleFeesTotal(s))` after the labor cell — Total column already fixed via Task 1)
- Modify: whichever component renders `summarizeSales(...).laborRevenue` (grep `laborRevenue` under `web_admin/src/presentation/` — mirror a `feesRevenue` line beside it with the same gating/visibility; if NO component renders laborRevenue, skip and say so in the report)
- Test: extend the existing tests covering these files (grep each file's name under `web_admin/src/` for `.test.`; mirror their labor assertions — fee rows render with fees, absent without; CSV row snapshot/values updated)

**Interfaces:** Consumes Task 1's `saleFeesTotal`/`Sale.feeLines`.

- [ ] **Step 1:** Failing tests per surface (mirror labor assertions; include one totals-reconciliation assertion on SaleDetailPage: rendered Total equals parts − discount + labor + fees for a composite fixture).
- [ ] **Step 2:** Run those test files → FAIL.
- [ ] **Step 3:** Implement the row/line/cell additions (fee name in the same text style the labor description uses on each surface).
- [ ] **Step 4:** Re-run → PASS; `npm run typecheck` clean.
- [ ] **Step 5:** Commit: `feat(web): sale detail, receipt, CSV, and summary show shop fees`

---

### Task 3: Full verification

- [ ] From `web_admin/`: `npm run typecheck` → clean; `npm run test` → ALL pass; `npm run build` → succeeds.
- [ ] `git status --short` clean (apart from the repo's two pre-existing untracked scripts).

After Task 3: final review, then finish per `superpowers:finishing-a-development-branch`. Hosting deploy is a separate user-gated step (`firebase deploy --only hosting` after merge, when the user wants web fees live).
