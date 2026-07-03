# Purchase Orders — visual redesign + subtotal/grand-total lines

_Approved 2026-07-03. Implements the design handoff bundle at
`design/design_handoff_purchase_orders/` faithfully, plus one user-directed addition on top of the
(deliberately cost-free) mock: **subtotal and grand-total lines on every PO surface, never in the
CSV export**._

## Scope

Presentation-layer only. Every provider, repository, entity, lifecycle rule, permission, and the
CSV builder stays untouched (one exception: none — even totals reuse existing entity math).
In-place restyle of the existing screens, in dependency order: tokens → list → new-PO → detail →
add-products sheet → nav icon.

**Source of truth for all visuals:** `design/design_handoff_purchase_orders/README.md` +
`MAKI POS Purchase Orders.dc.html` (light + dark). This spec does not restate the mock; it records
the decisions the mock does not cover. Where this spec is silent, the mock and its README win.
Rule 1 (pixel-faithful, both themes, Lucide 1.75, exact copy) and Rule 2 (no new wiring beyond
what §Wiring confirms) apply in full.

## Files touched

| File | Change |
|---|---|
| `lib/core/theme/app_colors.dart` | Add PO status tokens: `poDraftFg/Bg`, `poOrderedFg/Bg`, `poReceivedFg/Bg`, `poCancelledFg/Bg` (light+dark values from handoff README §Design tokens), reusing existing tokens where values already match. |
| `lib/presentation/mobile/widgets/purchase_orders/purchase_order_status_style.dart` | Swap the 8 inline tint/text literals for the new tokens. |
| `lib/presentation/mobile/widgets/purchase_orders/purchase_order_status_pill.dart` | Restyle to mock (4px/10px padding, radius 999, 12px glyph + 12/600 label) — mostly already correct. |
| `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart` | List redesign + card total (§Totals 1). FAB → app-bar `plus`. Retry on error state. Tiled empty state. |
| `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart` | Params card + segmented controls + cover stepper, amber cap note, AppCard suggestion rows, pinned footer with live create-count + running total (§Totals 2–3), re-patterned add-products sheet. |
| `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart` | Detail redesign: mono-ref app bar, header card, qty-badge item rows with per-item subtotal (§Totals 4), pinned footer with grand-total row (§Totals 5). |
| `lib/config/router/route_guards.dart` | Nav-menu icon `Icons.shopping_cart_checkout` → `LucideIcons.clipboardList` (metadata read only by the nav menu — verify before swapping). |
| `test/…` mirrors | Updated + new widget tests (§Testing). |

Reuse, don't fork: `AppCard`, `AppDialog`/`showAppConfirmDialog`, `EmptyStateView(tiled: true)`,
`ErrorStateView`, `SummaryRow`, `SegmentedPillFilter` (if it fits the mock's segmented control;
else a local segmented matching the JO pattern), `ProductSearchField`, the POS/JO stepper-pill and
qty-badge row anatomy, `app_colors`/`app_text_styles`/`app_shadows`, `toCurrency()`,
friendly-date formatting (`MMM d, h:mm a` like sibling features).

## Totals (the addition on top of the mock)

Decisions (user-approved 2026-07-03): **everywhere** (list, new-PO, detail) · visible to
**staff + admin** (no extra gating — same audience as Bulk Receiving) · **CSV unchanged**.

All amounts are expected-cost snapshots already on the entity: `PurchaseOrderItemEntity.unitCost`,
`item.totalCost` (qty × unitCost), `PurchaseOrderEntity.totalCost` via `recalculateTotals()`.
No schema, model, or repo change. Format with the existing `num.toCurrency()` → `₱5,430.00`.
Money uses the Job Orders language: primary color (slate light / gold dark) for card totals,
the JO-editor summary-row pattern for footers. `unitCost == 0` renders `₱0.00` — no special case.

1. **List card** — header row stays mock-exact (glyph tile · supplier/ref · status pill). Meta
   row: left `4 items · 14 pcs · by Czar` (12, secondary, ellipsized); right becomes a
   right-aligned column of **`₱5,430.00`** (13/700, `colorScheme.primary`) over the friendly date
   (12, secondary).
2. **New PO footer** — summary line gains the running total of **checked lines only**:
   `4 items checked · 15 pcs · ₱5,430.00` (the ₱ span 600-weight, primary); the right caption
   `One PO per supplier` stays. Recomputes as checks/quantities change.
3. **New PO, By-supplier view** — each supplier section header's right-side count becomes
   `2 items · ₱3,800.00` — item count and subtotal of the **checked** lines in that group (= the
   projected cost of that supplier's PO). The By-status view gets **no** per-section subtotals
   (status buckets don't map to POs); it relies on the footer running total.
4. **Detail item rows** — one added line under the mono SKU line, inside the flexible text
   column: left `₱320.00 each` (12, secondary), right-aligned `₱3,200.00` (12.5/600, ink) — the
   per-item subtotal. Identical in draft (stepper) and locked (static qty) states; recomputes
   from the staged `_pending` buffer while editing.
5. **Detail footer** — a grand-total row pinned **above** the action buttons, present in every
   status (including cancelled, where the buttons collapse but the total row remains):
   `Total (3 items · 16 pcs)` left (15/700 + muted 12.5/500 count, JO-editor pattern),
   **`₱5,430.00`** right (18/700, onSurface). Live from the `_pending` buffer while dirty; the
   staged-edit Save changes / Discard buttons swap in below it, same slot as the status actions.
6. **CSV** — `buildPurchaseOrderCsv` untouched: header block + `SKU, Name, Qty, Unit`. A test
   asserts the output contains no `₱` and no cost column.

## Wiring (handoff Rule-2 items — confirmed 2026-07-03)

- **Cover-days stepper**: ±1 per tap, clamp 1–365 kept, recompute **debounced ~350ms** into
  `reorderSuggestionsProvider((windowDays, coverDays))` — the record family key re-fetches; the
  productId-keyed `_qty`/`_checkedOverride` maps already survive param changes.
- **"Create N purchase orders"**: N = supplier groups among checked lines, computed by the exact
  `_save` grouping (no-supplier lines form their own group). Disabled when nothing checked.
- **Add-products sheet**: stays open, accumulates picks into the Added section (checked);
  already-added rows show the "Added" chip; barcode scan reuses the `productByBarcodeProvider`
  path mirroring the JO `_AddPartsSheet`; pinned **Done** closes.
- **List**: app-bar `plus` and empty-state CTA both `push('/reorder/new')`; error state
  `ErrorStateView(onRetry: invalidate purchaseOrdersProvider)`; status filter chips stay
  client-side over the streamed list.
- **Untouched**: detail overflow menu (Cancel `canCancel` / Delete admin-only), the idempotent
  `startReceiving` Receive flow, the cancel/revert/delete receiving-cleanup invariant,
  `Permission.accessReceiving` gating, the CSV builder, all providers.
- **Nav icon swap** is metadata-only; confirm nothing but the nav menu reads
  `route_guards.dart`'s nav item before changing it.

## Testing

TDD per screen. Update existing widget tests for the new copy/anatomy ("Purchase Orders" app bar,
"Create N purchase orders" label, pinned footers, friendly dates). New tests:
- List card renders `₱` total in primary + friendly date; meta line intact.
- New-PO footer running total counts only checked lines; supplier-section subtotal math;
  create-button label matches supplier-group count.
- Detail per-item subtotal + footer grand total, including live recompute from staged edits and
  total-row presence on locked/cancelled states.
- CSV: `buildPurchaseOrderCsv` output has no `₱` / cost column (regression lock).
- Status style resolves the new `AppColors` tokens (light + dark).
Gate: `flutter analyze` + `flutter test` green.

## Out of scope

List search / supplier filter (handoff explicitly deferred), any provider/lifecycle change, web
admin, partial-delivery semantics, real-cost reconciliation (stays on the receiving).
