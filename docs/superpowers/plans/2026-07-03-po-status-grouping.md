# PO Status Grouping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** New Purchase Order screen defaults to status grouping (Recommended / Out of stock / Low stock / Added) with a toggle to the existing by-supplier view.

**Architecture:** `ReorderResult` gains `lowStock`/`outOfStock` product lists computed in `reorderSuggestionsProvider` from the already-fetched products. The screen tags each line with a source bucket, keeps selection/qty state keyed by productId (`Map<String, bool>` checked-override replaces the unchecked set so per-bucket defaults work), and renders either grouping from the same lines.

**Tech Stack:** Flutter + Riverpod 2; tests with flutter_test + fake overrides.

**Spec:** `docs/superpowers/specs/2026-07-03-mobile-purchase-orders-design.md` (§ New PO screen, updated 2026-07-03).

## Global Constraints

- Branch `feat/po-status-grouping`; TDD each task; `flutter analyze` + full `flutter test` before done.
- Save behavior unchanged: one draft PO per supplier across checked lines, both views.
- Low/out rows: unchecked by default, qty `max(1, reorderLevel − quantity)`.
- Bucket priority: recommended > out of stock > low stock > added; one appearance per item.

---

### Task 1: Provider buckets

**Files:**
- Modify: `lib/presentation/providers/purchase_order_provider.dart`
- Test: `test/presentation/providers/purchase_order_provider_test.dart` (extend)

**Interfaces:**
- Produces: `ReorderResult({required suggestions, this.lowStock = const [], this.outOfStock = const [], required capped})`; provider fills the two lists from active products not in `suggestions`: `quantity == 0` → `outOfStock`, else `quantity <= reorderLevel` → `lowStock`; both sorted by name.

- [ ] Step 1: failing test — provider buckets: product suggested → excluded from buckets; qty 0 → outOfStock; 0 < qty <= reorderLevel → lowStock; qty > reorderLevel → neither; inactive → neither.
- [ ] Step 2: run, expect FAIL (no such fields).
- [ ] Step 3: implement fields + computation in the provider.
- [ ] Step 4: run, PASS. Step 5: commit `feat(po): reorder result carries low/out-of-stock buckets`.

### Task 2: Screen — status view default + supplier toggle

**Files:**
- Modify: `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart`
- Test: `test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart` (update + extend)

**Interfaces:**
- `_LineSource { recommended, outOfStock, lowStock, added }` on `_Line`; `_byStatus` bool (default true) drives grouping; `Map<String, bool> _checkedOverride` replaces `_unchecked` (checked = override ?? per-source default: true for recommended/added, false for low/out); qty default per source (suggestedQty / top-up / 1).

- [ ] Step 1: update existing supplier-grouping test to tap the "By supplier" toggle first; add failing tests: status sections render in order with low/out rows; low row unchecked by default and excluded from save; low row qty = top-up; toggle switches grouping without losing an edited qty.
- [ ] Step 2: run, expect FAIL. Step 3: implement. Step 4: run, PASS (all screen tests).
- [ ] Step 5: commit `feat(po): status grouping default with supplier view toggle`.

### Task 3: Verification + merge

- [ ] `flutter analyze` clean; full `flutter test` green.
- [ ] Merge to main per finishing-a-development-branch.
