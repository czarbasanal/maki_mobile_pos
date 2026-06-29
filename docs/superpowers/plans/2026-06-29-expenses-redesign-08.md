# Expenses Redesign (Bundle 08) Plan

> REQUIRED SUB-SKILL: superpowers:executing-plans.

**Goal:** Migrate Expenses (dashboard · empty · form · delete · history) onto the elevated theme — `AppCard` rows, `SummaryCard` totals, Lucide, neutral-by-default discipline, **delete via the shared `showAppConfirmDialog(destructive)` shell**, currency in **Figtree (no mono)** — pixel-faithful to the 08 hand-off, behavior-preserving.

**Source of truth:** `design/design_handoff_expenses/MAKI POS Expenses.dc.html` (+ README). HTML wins. Light + dark.

## Constraints
- Neutral discipline: every row = one muted `file-text` in a neutral tile (40×40 r11, `0x0F283E46` light / `0x1F93A0A3` dark); **no per-category/payment colors**. Color = primary (slate/gold) + red on delete path only.
- `AppCard` rows (radius 16, gap 12, pad 11×13): tile + title 14.5/600 ellipsis + subtitle 12 muted + amount 15/600 (Figtree).
- Totals: `SummaryCard(compact:true)` 3-up gap 8, Lucide sun/calendar/barChart3; re-scope to category; `…`/`—` states (already wired).
- Delete (swipe + long-press + form trash) → `showAppConfirmDialog(title:'Delete expense?', message:'"{desc}" will be permanently deleted.', confirmLabel:'Delete', destructive:true, icon: trash2)` → snackbar. Swipe bg `AppColors.error` both themes, trash2.
- Lucide: back `chevronLeft`, filter `tag`, totals sun/calendar/barChart3, row `fileText`, View-all `chevronRight`, Add `plus`, form trash `trash2`, date `calendar`, dropdowns `chevronDown`, amount `₱` prefix text (no peso glyph).
- Preserve: role gating (addExpense hides Add; editExpense tap-to-edit; deleteExpense swipe/long-press/form-trash), filter re-scopes list+totals, `{name} (inactive)` orphan, empty "No Expenses"/"No matches", form field order + validation (amount>0, date max today, category-required, empty-categories error, Paid via default Cash), Add/Update label flip + spinner, history month-year groups (count • total) + deep-link category. Currency `₱1,234.00`.
- Reuse `lib/core/theme/`, `AppCard`, `SummaryCard`, `AppDropdown`, `EmptyStateView`, `groupExpensesByMonthYear`, `showAppConfirmDialog`. App field styling for form.

## Files / Tasks
1. **Shared `_ExpenseRow`** (private, in expenses_screen + reused in history via a small shared widget `lib/presentation/mobile/widgets/expenses/expense_row.dart`) — neutral AppCard row (title, subtitle, amount, onTap). Create the widget file (dashboard subtitle = date•time; history subtitle = date•category) via a `subtitle` param.
2. **expenses_screen** restyle: Lucide, SummaryCard Lucide icons, filter (tag), Recent header (chevronRight), AppCard rows + Dismissible (error bg, trash2), pinned Add (plus), empty (file-text 76 tile), delete→shell. (TDD: delete routes through 'Delete expense?' shell + deletes; Add hidden w/o permission; empty/no-matches copy.)
3. **expense_form_screen** restyle: Lucide icons, labeled fields, ₱ prefix, app-bar trash2 (red), Date field calendar, delete→shell, Add/Update flip. analyze.
4. **expense_history_screen** restyle: Lucide, AppCard rows (date•category) via shared `_ExpenseRow`, month headers, filter. analyze.
5. Verify: analyze + `flutter test` + `/code-review` + `/verify` + finish; update ROADMAP + memory.

Verify each: `flutter test` (changed) + `flutter analyze` clean.
