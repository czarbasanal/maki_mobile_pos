# Handoff: Purchase Orders / "Reorder" — MAKI POS (visual redesign)

> **Status (2026-07-03): feature SHIPPED, awaiting its FIRST design pass.** This bundle captures the
> **as-shipped UI** on `main` (`ed3e394`) so a future design session can redesign and improve it
> without re-exploring the codebase. Unlike the Job Orders bundle, there is **no approved mock yet**
> — the two reference files below describe what exists today, not a target.

---

## Overview

**Reorder turns stock movement into purchase orders.** From the dashboard's "Reorder" quick-action
pill (staff + admin), the shop drafts what to buy: a velocity engine (`unitsSold(window)/windowDays`,
target = velocity × cover days) suggests quantities, out-of-stock and low-stock items are offered as
unchecked top-ups, anything else can be search-added, and **Save creates one draft PO per supplier**.
A PO then walks a real lifecycle — `draft ⇄ ordered → received / cancelled` — with a costs-free CSV
to send the supplier, and **Receive** spawns a linked Bulk Receiving draft whose completion atomically
closes the PO as received. Data lives in the shared Firestore collection `purchase_orders`.

The feature shipped functional-first: real theme tokens (AppCard, Lucide, status pill) but otherwise
Material defaults — bare ChoiceChips doing three different jobs, plain checkbox/stepper rows, a Wrap
of mixed buttons for actions, a FAB the rest of the redesigned app no longer uses, and AppCards
rendered with no inner padding. `current-implementation.md` ends with a concrete, code-observable
**"Redesign starting points"** list.

## Files in this bundle

- **`current-implementation.md`** — the authoritative map: real Dart file paths with line refs,
  routes/guards, Riverpod providers, suggestion math, lifecycle semantics, data model, CSV format,
  theming inventory, permissions, and the redesign starting points. Documented 2026-07-03 against
  `main` (`ed3e394`).
- **`reference_current-ui.html`** — as-shipped visual preview: 9 light-mode panels (dashboard entry
  point, list + empty state, new-PO in both views, add-product sheet, detail draft/ordered, cancel
  confirm). Self-contained — inline SVG icons, system font stack, no external requests. Open in a
  browser. Sample data is illustrative but internally consistent across panels.
- *(No `.dc.html` mock yet — producing the approved redesign is the future session's job. When it
  exists, follow the two hard rules in `design/design_handoff_job_orders/CLAUDE.md`: recreate mocks
  faithfully in Flutter with existing widgets/tokens, and ask before wiring any behavior.)*

## Pointers

- **Design spec (approved, behavior source of truth):**
  `docs/superpowers/specs/2026-07-03-mobile-purchase-orders-design.md` — lifecycle, receiving
  integration guards, cleanup invariants, suggestion engine, rules.
- **Screens:** `lib/presentation/mobile/screens/receiving/purchase_orders/`
  (`purchase_orders_screen.dart`, `new_purchase_order_screen.dart`,
  `purchase_order_detail_screen.dart`).
- **Status language:** `lib/presentation/mobile/widgets/purchase_orders/purchase_order_status_style.dart`
  + `purchase_order_status_pill.dart` (draft neutral · ordered amber · received green · cancelled red).
- **Engine:** `lib/core/utils/reorder_suggestions.dart` (Dart port of
  `web_admin/src/domain/reorder/computeReorderSuggestions.ts`).
- **Providers:** `lib/presentation/providers/purchase_order_provider.dart`.
- **CSV:** `lib/core/utils/purchase_order_csv.dart` (SKU/Name/Qty/Unit — no costs, by design).
- **Sibling bundle for the target design language:** `design/design_handoff_job_orders/`
  (elevated theme tokens, light+dark parity, Lucide stroke 1.75, neutral-by-default color discipline
  — note POs *do* have a real status enum, so the existing four-status color language is legitimate
  semantic color, unlike Job Orders).
