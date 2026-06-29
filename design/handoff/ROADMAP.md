# MAKI POS — Mobile UI Refactor Roadmap

**Goal:** bring every mobile screen onto the global theme (soft-shadow `AppCard`,
`SummaryRow`, hero numbers, Lucide icons, theme-aware colors + dark parity).

**Process per bundle:** build handoff package (`current-ui.html` + README
"What I want") → mark up → spec → plan → TDD → `/code-review` → `/verify` →
finish branch. **One bundle at a time.**

Surface: Flutter mobile app — `lib/presentation/mobile/screens/`.

---

## ✅ Done

| # | Bundle | Screens | Status |
|---|--------|---------|--------|
| — | **maki-theme** | Global theme / token foundation | ✅ Shipped |
| 01 | **Login + Dashboard** | `dashboard_screen` (+ login) | ✅ Shipped |
| 02 | **POS + Checkout** | `pos_screen`, `checkout_screen`, `barcode_scanner_screen` | ✅ Shipped |
| 03 | **Sale Detail** | `sale_detail_screen` | ✅ Merged to `main` |
| 04 | **Inventory** | `inventory_screen`, `product_form_screen`, `price_history_screen` | ✅ Merged to `main` |
| 05 | **Receiving** | `receiving_screen`, `bulk_receiving_screen`, `batch_import_screen`, `receiving_drafts_screen`, `receiving_history_screen` | ✅ Merged to `main` |
| 06a | **Reports (hub / lists)** | `sales_list_screen`, `sales_report_screen`, `profit_report_screen`, `top_selling_screen` (+ shared `date_range_picker`, `sales_summary_card`, `top_products_card`; new `payment_method_style`, `reports_warning_banner`; dead `reports_screen` deleted) | ✅ Merged to `main` |
| 06b | **Closing** | `end_of_day_screen` (form + closed view), `daily_closing_history_screen` (+ new `variance_style`, `closing_widgets`) | ✅ Merged to `main` |
| 07 | **Void Requests** | `void_requests_screen` + resolve sheet + approve/reject dialogs (+ new `void_status_style`) | ✅ Merged to `main` |

## 🔜 Remaining (proposed order)

| # | Bundle | Screens in scope |
|---|--------|------------------|
| 08 | **Expenses** | `expenses_screen`, `expense_form_screen`, `expense_history_screen` |
| 09 | **Drafts** | `drafts_list_screen`, `draft_edit_screen` |
| 10 | **Settings** | `settings_screen`, `category_settings_screen`, `category_editor_screen`, `cost_code_settings_screen`, `mechanic_editor_screen`, `about_screen` |
| 11 | **Suppliers** | `suppliers_screen`, `supplier_form_screen` |
| 12 | **Users** | `users_screen`, `user_form_screen` |
| 13 | **Logs** | `activity_logs_screen` (⚠️ `user_logs_screen` is a 0-byte stub — `/logs` mounts `ActivityLogsScreen`; effectively one screen) |

**⚙️ Sequencing (updated 2026-06-29):** 07 shipped, then the cross-cutting **modals + bottom-sheets
sync — FOUNDATION shipped** ✅ (merged to `main`): shared `AppDialog` + `AppBottomSheet` shells +
variants (confirm/destructive/error/password/action-radio), real `error_dialog`, `showConfirmDialog`
→ shell, Lucide + dark-parity snackbars, dead `PasswordConfirmDialog` removed. **Follow-up (tracked):**
migrate the ~32 inline `AlertDialog` confirms + 8 bottom-sheet sites + `checkout_success` + 07's
bespoke sheet/dialogs onto the shells. Order now: **modals migration (follow-up) → 08 → 09 → …**.
08–13 await their redesign hand-off files.

**Current-UI capture packages are ready for every remaining bundle** (07–13):
`design/handoff/<NN-name>/{reference_current-ui.html, README.md}`. Hand each to Claude
Design; on return → spec → plan → TDD → code-review → verify → finish (the 06a/06b flow).
Per-bundle current-state notes (icons, surfaces, role gating, color discrepancies to
resolve — e.g. Users cashier=orange, Settings role-pill admin=red in source) live in
each bundle's README.

**Coverage:** 6 bundles done (13 screens incl. login) + 8 remaining (~28 screens)
= ~41 files ≈ the "~39-screen inventory" the handoffs reference.

## Notes on ordering

- Order is weighted by daily-use frequency and value (Inventory / Receiving /
  Reports first). Not locked — bundle footers vary (02 said "Inventory · Reports ·
  Receiving · Expenses · Settings"; 03 said "Inventory · Receiving · Reports ·
  Settings").
- **Bundle 04 (Inventory) is the agreed next step** in every version of the queue.
- Bundles can be split if a screen is heavy — e.g. Reports (7 screens) could
  become 06a (hub / lists) + 06b (EOD / closing).
