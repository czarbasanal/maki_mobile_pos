# MAKI POS — Web Admin UI Redesign Roadmap

**Goal:** redesign the React web admin (`web_admin/`) with Claude Design, one bundle at a time —
same process that worked for the ~39-screen mobile refactor (`design/handoff/`).

**Process per bundle:** hand `current-ui.html` + `README.md` to Claude Design → get marked-up
design back → spec → plan → TDD → `/code-review` → `/verify` → finish branch. **One bundle at a time.**

Surface: React + Vite + TypeScript + Tailwind — `web_admin/src/presentation/`.

---

## ⚠️ STRONG NOTE TO CLAUDE DESIGN — read before designing

**Redesign what is currently present in these screens. Nothing more, nothing less.**

- **Do NOT remove any component.** Every screen, section, table column, form field, button,
  banner, badge, filter, state (loading / empty / error / success / disabled / capped), dialog,
  and popover inventoried in each bundle's README must exist in the redesign.
- **Do NOT add components.** No new features, fields, actions, nav items, or data that the
  current screen does not already show.
- **Single exception: charts/graphs are allowed.** You may add charts or graphs that visualize
  data *already present on that screen* (e.g. a sales-over-time chart on the Sales report, a
  tender-split donut, stock-status bar on Inventory). Nothing else may be added.
- **Role gating, copy, validation, and behavior are fixed.** Restyle freely; do not re-scope.

---

## Roles & access (context for every bundle)

Three roles: **admin · staff · cashier** (`domain/permissions/Permission.ts`, mirrors mobile).
**The web app is currently admin-only at the door**: `ProtectedRoute` bounces any non-admin to
`/access-denied` before per-route permissions run. But the sidebar + route guards faithfully
implement the full RBAC matrix, so the redesign must keep per-role structure:

| Role | Sidebar sees |
|---|---|
| **admin** | everything |
| **staff** | Dashboard, POS, Drafts, Inventory, Receiving, Expenses, Reports, Settings |
| **cashier** | Dashboard, POS, Drafts, Inventory, Expenses, Reports, Settings |

Admin-only routes: Reorder, Price History, Suppliers, Users, Activity Logs,
Profit report, Price-changes report, product add, cost-code settings, manage-lists, mechanics.
In-page gating is minimal by design (gating is at the router); the two in-page cases are:
users list hides row-menu on your own row, and Void button shows only on completed sales.

## Not in scope (placeholder routes — no UI to redesign)

`/pos/checkout` (phase 11) and `/drafts/:id` (phase 10) are **vestigial** placeholders —
checkout happens inline on `/pos` and drafts are edited by resume-into-POS, so nothing
navigates to them. `/expenses` + add/edit (phase 9) render the shared `PagePlaceholder`
("Not available yet") — genuine deferred work (Expenses is live on mobile, not yet ported
to web). All render no real screen; skip them.

**Petty Cash — removed 2026-07-07.** It was speculative scaffolding never built on any
surface (web UI was a placeholder; mobile has no petty-cash feature — the real cash feature
is `daily_closings`/EOD). The web nav item, routes, permissions (`managePettyCash`,
`performCutOff`), `PettyCash` entity + repository, `petty_cash` collection/query-keys, and
the `petty_cash`/`petty_cash_cutoff` activity-log types were all deleted (196 tests green,
typecheck clean; web-only, no Firestore rules or data change).

---

## Bundles (proposed order)

| # | Bundle | Screens | Modals / overlays |
|---|--------|---------|-------------------|
| w01 | **Shell + Login + Dashboard** | AdminShell + Sidebar chrome, OfflineBanner, Login (+ reset-password flow), Access Denied, Dashboard | account popover; login inline reset-confirm card |
| w02 | **POS + Drafts** | POS (search, cart, LaborSection, PaymentSection, totals, actions), Drafts list | Save-as-draft dialog; native confirms (resume/delete draft) |
| w03 | **Inventory** | Product list, Product form (add/edit), Product detail, Price history, Reorder suggestions | Change-SKU?, Crop image, Adjust stock, Delete product? |
| w04 | **Receiving** | Dashboard, Entry (new/resume draft), Bulk CSV, History, Detail | none (all pickers/panels inline) |
| w05 | **Suppliers** | Suppliers list, Supplier form (add/edit) | row-menu popover; Deactivate confirm |
| w06 | **Reports + Sale detail** | Hub, Sales report, Profit report, Labor report, Price changes, Sale detail + printable Receipt | Void-sale reason dialog |
| w07 | **Users** | Users list, User form (add/edit) | row-menu popover; Deactivate/Reactivate confirm |
| w08 | **Settings** | Settings hub, Cost codes, Manage lists, Mechanics, About | Change password, Edit display name, Password confirm (cost codes), Add/Edit entry, Add/Edit mechanic |
| w09 | **Activity Logs** | Activity logs (day-grouped) | type-filter popover |

Each bundle folder: `design/handoff-web/<NN-name>/{current-ui.html, README.md}` —
`current-ui.html` is a token-accurate static reconstruction of the current screens (light theme,
desktop) and the README holds per-screen structure/copy/states/role rules plus the constraint
note above and a "What I want" template.

---

## Full screen inventory (built UI only)

| Route | Screen | Source (presentation/…) | Access |
|---|---|---|---|
| `/login` | Login + reset password | features/auth/LoginPage | public |
| `/access-denied` | Access denied | features/access-denied/AccessDeniedPage | signed-in |
| `/` | Dashboard (5 summary tiles, recent sales, inventory status) | features/dashboard/DashboardPage | all roles |
| `/pos` | POS (search · cart · labor · payment · checkout) | features/pos/PosPage | all roles |
| `/drafts` | Drafts list (resume / delete) | features/drafts/DraftsPage | all roles |
| `/inventory` | Product list (3 stock stat-filters, search, category, inactive toggle) | features/inventory/InventoryListPage | all roles |
| `/inventory/add` | New product | features/inventory/InventoryFormPage | admin |
| `/inventory/edit/:id` | Edit product | features/inventory/InventoryFormPage | admin, staff |
| `/inventory/:id` | Product detail (+ adjust stock, delete/reactivate) | features/inventory/InventoryDetailPage | all roles |
| `/inventory/price-history` | Price history (sparklines + table) | features/inventory/PriceHistoryPage | admin |
| `/inventory/reorder` | Reorder suggestions (velocity × cover, CSV) | features/inventory/ReorderSuggestionsPage | admin |
| `/receiving` | Receiving dashboard (stats, drafts, recent) | features/receiving/ReceivingDashboardPage | admin, staff |
| `/receiving/new[/:id]` | Receiving entry (add items, save draft, receive) | features/receiving/ReceivingEntryPage | admin, staff |
| `/receiving/bulk` | Bulk receiving (CSV preview + receive) | features/receiving/BulkReceivingPage | admin, staff |
| `/receiving/history` | Receiving history (date range) | features/receiving/ReceivingHistoryPage | admin, staff |
| `/receiving/:id` | Receiving detail (read-only) | features/receiving/ReceivingDetailPage | admin, staff |
| `/suppliers` | Suppliers list | features/suppliers/SuppliersListPage | admin |
| `/suppliers/add`, `/suppliers/edit/:id` | Supplier form | features/suppliers/SupplierFormPage | admin |
| `/reports` | Reports hub (4 link cards) | features/reports/ReportsHubPage | all roles |
| `/reports/sales` | Sales report (summary, tenders, top products, table, CSV) | features/reports/SalesReportPage | all roles |
| `/reports/profit` | Profit report | features/reports/ProfitReportPage | admin |
| `/reports/labor` | Labor report (by mechanic) | features/reports/LaborReportPage | all roles |
| `/reports/price-changes` | Price changes (deltas, CSV) | features/reports/PriceChangeReportPage | admin |
| `/reports/sale/:id` | Sale detail + void + printable receipt | features/reports/SaleDetailPage, Receipt | all roles (void: admin) |
| `/users` | Users list (tiles, filters, table, row menu) | features/users/UsersListPage | admin |
| `/users/add`, `/users/edit/:id` | User form (role picker, password/reset) | features/users/UserFormPage | admin |
| `/settings` | Settings hub (profile + admin + general rows) | features/settings/SettingsPage | all roles |
| `/settings/cost-codes` | Cost codes (mapping grid, preview, password-gated save) | features/settings/CostCodeSettingsPage | admin |
| `/settings/lists` | Manage lists (4 kinds, add/edit dialog) | features/settings/ManageListsPage | admin |
| `/settings/mechanics` | Mechanics (add/edit dialog) | features/settings/MechanicsPage | admin |
| `/settings/about` | About | features/settings/AboutPage | all roles |
| `/logs` | Activity logs (filter, day groups, tone icons) | features/logs/ActivityLogsPage | admin |

Shared components (restyle once, reuse everywhere): `Sidebar`, `Dialog`, `DateRangePicker`,
`CappedNotice`, `EmptyState`, `ErrorView`, `LoadingView`/`Spinner`, `OfflineBanner`,
`PagePlaceholder`, `SummaryCard` (dashboard + reports), `RoleBadge`, `ReceivingStatusBadge`,
`Sparkline`.

Raw per-feature inventories captured 2026-07-07 live with the session that generated this
roadmap; the per-bundle READMEs are the durable copy.
