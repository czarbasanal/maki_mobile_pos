# Price Changes report v2 — per-product cards, prev→curr, sorting (mobile)

**Date:** 2026-07-02 · **Status:** approved
**Scope:** mobile only (`price_change_report_screen.dart` + pure helpers + repo/provider wiring). Web report unchanged (parity is a possible follow-up). CSV export unchanged (stays the per-change log).

## Problem

The mobile Price Changes report shows one card per change event with only the new value and a delta vs the prior in-range change. The user wants:

1. Cards clickable → product details.
2. Explicit **prev vs curr** for cost and SRP, each with the diff value.
3. Sorting by highest change: cost, SRP, or both.

## Design

### One card per product

The list becomes a per-product summary of the selected date range:

```
┌──────────────────────────────────┐
│ ASK BRAKE SHOE XRM (SKU-123)   › │
│ Cost  ₱120.00 → ₱150.00  ▲ ₱30.00│
│ SRP   ₱250.00 → ₱280.00  ▲ ₱30.00│
│ 3 changes · last Jun 25          │
└──────────────────────────────────┘
```

- Unchanged metric: muted `—` instead of arrow/diff.
- Tap → `/inventory/:id` (existing `RouteNames.productDetail`, ProductFormScreen), which already links to the full per-change price history.

### Prev vs curr semantics

- **curr** = newest in-range entry's `price`/`cost`.
- **prev** = value just before the range's first in-range change, fetched per product as a one-doc **baseline** query: `products/{id}/price_history where changedAt < rangeStart orderBy changedAt desc limit 1`. (Requires the COLLECTION-scope `changedAt` index — repaired + deployed 2026-07-02.)
- **No baseline** (product's history starts inside the range, e.g. lone "Initial price"): `prev` = oldest in-range entry; card marked **New** (`isNew`), diffs computed prev→curr as usual (0 if only one entry). No fake ₱0 jump.

### Sorting

Sort control above the list (chips row, matching the metric filter pattern in `price_history_screen.dart`):

| Option | Order |
|---|---|
| Latest change (default) | newest `lastChangedAt` first |
| Cost change | `\|costDiff\|` desc |
| SRP change | `\|priceDiff\|` desc |
| Cost + SRP | `\|costDiff\| + \|priceDiff\|` desc |

Ties break by newest `lastChangedAt`.

## Components

1. **Pure helper** (`lib/core/utils/price_change_report.dart`, unit-tested):
   - `class ProductPriceChangeSummary { productId, prevPrice, prevCost, currPrice, currCost, priceDiff, costDiff, changeCount, lastChangedAt, isNew }`
   - `List<ProductPriceChangeSummary> priceChangeProductSummaries(List<PriceChangeEntry> entries, Map<String, PriceHistoryEntry?> baselines)`
   - `enum PriceChangeSort { latest, cost, price, both }` + `List<ProductPriceChangeSummary> sortPriceChangeSummaries(list, sort)`
   - Existing `priceChangeRowsInRange` stays (CSV path untouched).
2. **Repo** (`ProductRepository` + impl): `Future<PriceHistoryEntry?> getPriceHistoryBaseline({required String productId, required DateTime before})` — limit-1 desc query; returns null when empty.
3. **Provider** (`product_provider.dart`): `priceChangeSummariesProvider = FutureProvider.autoDispose.family<List<ProductPriceChangeSummary>, DateRangeParams>` — fetches in-range changes, then baselines for each distinct productId (parallel `Future.wait`), builds summaries. Existing `priceChangeReportProvider` stays for CSV export.
4. **Screen** (`price_change_report_screen.dart`): sort chips state (`PriceChangeSort _sort`), per-product card widget (`InkWell`/AppCard onTap → `context.pushNamed(RouteNames.productDetail, ...)` — follow the screen's existing navigation idiom), prev→curr rows with diff, `New` badge for `isNew`, footer `N change(s) · last <date>`. CSV button unchanged.

## Error handling

- Baseline fetch failure for a product: fail the provider as a whole (same error surface as today — ErrorStateView with retry). No partial/silent data.
- Product label missing from `productsProvider` (inactive product): fall back to productId, as today. Card still navigates (ProductFormScreen loads by id).

## Testing

- TDD on the pure helpers: grouping, prev/curr from baseline, no-baseline `isNew` fallback, single-entry products, unchanged-metric zero diff, all four sorts + tie-breaks.
- Repo test (`fake_cloud_firestore`): baseline returns newest-before-date doc, null when none.
- Widget/provider tests follow existing patterns in `test/` mirror of the report screen if present.
