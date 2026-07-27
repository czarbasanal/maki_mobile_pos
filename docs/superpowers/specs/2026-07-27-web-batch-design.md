# Web-admin 11-item batch (pre-label-printing)

Dictated + decisions locked 2026-07-27. Web only; ships via hosting deploy.
No firestore/storage rules changes expected (expenses + list-delete + employee
write rules already live; verify user_logs create permits web writes — flag if
not). Anchors from the 2026-07-27 exploration (see memory note).

## W1 — Users table scroll
`UsersListPage.tsx:200`: wrapper `overflow-hidden` → `overflow-x-auto`.

## W2 — Pagination (all main tables, 25/page)
New shared `components/common/Pager.tsx`: client-side pager (25/page, prev/next
+ "x–y of N"), applied to: Inventory list, Sales table (within the selected
range), Users, Activity logs (within its fetch limit), HR employees/payroll/
payslips lists, the new Expenses list (W6) and Job Orders list (W10). Small
settings lists (ManageLists tabs, Mechanics) stay unpaginated. Data loading
stays as-is (client-side slicing); no cursor work in this batch.

## W3 — Dashboard recent-sales rows clickable
`RecentSales.tsx:33` rows become Links to `/reports/sale/{id}`.

## W4 — Stat cards single row + de-emphasize gross sales
`DashboardPage.tsx:51-83`: grid → `lg:grid-cols-5` (one row on desktop);
remove `emphasized` from the Gross Sales card (no black bg).

## W5 — Recent sales "View all" → day sales list
"View all" link in the Recent-sales panel header → new route `/sales/day`
(guard: viewSalesReports) — a day-scoped sales list (date param, default
today, simple day-picker prev/next). Each sale = expandable tile (collapsed:
number/time/cashier/total/payment; expanded: item lines qty × name @ price,
labor/fees when present) with a "Full detail" link to `/reports/sale/{id}`.
Items fetched on first expand (existing sale-items read). Paginated (W2).

## W6 — Expenses screen (full mobile parity)
Entity/interface/permissions/routes/rules all exist; build the missing layer:
- `FirestoreExpenseRepository` impl + DI wire (container.tsx has the slot) +
  hooks (list by date range/category, totals for Today/Week/Month, CRUD).
- `/expenses` page: three summary cards + filterable list (date range preset,
  category) + Pager; rows → edit.
- `/expenses/add`, `/expenses/edit/:id` form: description, amount, category
  (expense_categories), paidVia, date, notes, receipt image (upload to
  `expenses/{id}/receipt.jpg` — storage rules live from mobile; view +
  replace + delete-cleanup best-effort, mirroring mobile's upload-before-
  create id-preset pattern), delete w/ destructive confirm.
- Route guards already declared; replace the three PagePlaceholders.

## W7 — Mechanics back button
`MechanicsPage.tsx` (and `ManageListsPage.tsx`, same gap) adopt the existing
`settings/PageHeader.tsx` back-to-Settings header.

## W8 — HR under /settings + back buttons
Paths move to `/settings/hr/employees|payroll|payslips|payslips/:id|config`
(constants-only in `routePaths.ts:58-62` — no hardcoded literals exist);
update `routes.tsx:109-113`, `routeGuards.ts:45-48,:109`, Sidebar HR section
(nested under Settings group). HR pages adopt `PageHeader` (back → /settings).

## W9 — Deletes (web parity)
- Repos gain delete: `FirestoreCategoryRepository.delete(kind, id)`,
  `FirestoreMechanicRepository.delete(id)`, `FirestoreEmployeeRepository.delete(id)`.
- ManageLists categories: direct delete w/ permanent-confirm (mobile-lists
  parity; page is admin-gated on web).
- Mechanics + Employees: DEACTIVATE-FIRST — Delete appears only on inactive
  entries, destructive confirm (mirrors mobile users model). Rules already
  permit (mechanics staff+admin delete; employees admin write).

## W10 — Drafts → Job Orders (full parity)
- Port `job_order_number.dart` → `domain/jobOrders/joNumber.ts`
  (`jobOrderPrefixFor`, `nextJobOrderNumber` — JO-MMDDYY-NNN from existing
  names; byte-parity header like sku.ts).
- POS save dialog: free-text name replaced by an auto-assigned JO number
  (shown, not editable) + optional notes; "Save as Job Order".
- Routes `/job-orders`, `/job-orders/:id` (old `/drafts*` redirect); nav +
  all UI copy "Job Orders"; list shows JO number (mono) + open/billed status
  pill + mechanic/total, Pager; converted JOs stay visible (mark-converted-
  keep, mobile parity). Entity/repo/conversion flow unchanged (name field
  carries the JO number; atomic draft→sale conversion untouched).

## W11 — Activity logging (web writes none today — wire it)
- Thin `application/activityLogger.ts` over the already-wired repo
  (fire-and-forget, never blocks the mutation).
- Log at every web mutation, matching mobile's action-string style (grep
  mobile's ActivityLogger call sites for exact wording where the same event
  exists): sale create (`sale`), void (`void_sale`), user create/update/
  deactivate/role change, receiving complete (`receiving`), stock/product
  edits (`inventory`/`stock_adjustment`), expense CRUD (`expense`), list/
  category/mechanic/shop-fee changes (`settings`), cost-code change +
  cost_viewed where applicable, login/logout (`login`/`logout`), JO
  save/delete (`other` w/ JO number), employee/HR changes (`user_management`).
- ActivityLogsPage: add `expense` (present in tones but missing from
  COMMON_TYPES:94-108) + any newly-used types to the filter list.
- Acceptance: every COMMON_TYPES filter option has at least one web write
  site (or is documented mobile-only, e.g. password_verified/failed).

## Verification & ship
TDD per item; `npm run typecheck` + `npm run test` green; final review;
merge; hosting deploy (user-gated). No APK involvement (+18 hold unaffected).
Sequencing: smalls (W1,W3,W4,W7,W8) → W2 pager → W5 → W9 → W6 → W10 → W11
(logging last so it covers the new screens' mutations too).
