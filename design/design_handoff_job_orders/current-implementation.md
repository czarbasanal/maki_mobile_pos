# Job Orders — Current UI & Flow (redesign handoff)

_Documented 2026-07-02, against `main` (post-merge `53cf5cf`). Written so a future session can redesign this feature without re-exploring the codebase._

## What it is

Job Orders are motorcycle-service tickets. The feature **repurposes the old Drafts feature**: internally everything is still named `draft`/`Draft` (entity, repository, providers, routes, Firestore collection `drafts`), while all user-facing copy says "Job Order". A job order is a non-converted `DraftEntity`: an open ticket carrying parts, labor lines, a mechanic, and a motorcycle model, which is eventually "billed out" into a Sale (non-destructively — the ticket survives an abandoned checkout and is only marked converted when the sale is written).

Original design spec: `docs/superpowers/specs/2026-07-01-job-orders-from-drafts-design.md`.

**Visual preview:** `reference_current-ui.html` (this folder) — a self-contained HTML reproduction of all 8 surfaces (POS entry point, list, empty state, New dialog, editor, add-parts sheet, delete dialog, reports), built from the real theme tokens (slate `#283E46`, canvas `#F6F5F3`, Figtree, card radius 18/14, flat buttons, Lucide icons). Open it in a browser or render it as an artifact to see the current UI before redesigning.

## Entry points & routes

| Entry point | Where | Goes to |
|---|---|---|
| POS toolbar button | `lib/presentation/mobile/screens/pos/pos_screen.dart:548-575` (`_buildDraftsButton`) — shopping-cart icon with a `Badge` showing the **open job-order count** (`activeDraftCountProvider`), tooltip "Job Orders" | `/drafts` |
| Reports hub card | `lib/presentation/mobile/screens/reports/reports_hub_screen.dart:60-68` — `clipboardList` icon, "Job Orders / Models serviced + mechanic performance", gated by `viewJobOrderReports` | `/reports/job-orders` |

Routes (`lib/config/router/route_names.dart`, wired in `lib/config/router/app_routes.dart`):

- `/drafts` → `DraftsListScreen` (app_routes.dart:182-186)
- `/drafts/:id` (name `draftEdit`) → `DraftEditScreen` (app_routes.dart:187-194)
- `/reports/job-orders` (name `jobOrderReports`) → `JobOrderReportsScreen` (app_routes.dart:342-346)

⚠️ **Naming confusion worth fixing in the redesign:** the POS toolbar badge looks like a cart-count indicator (shopping-cart icon) but actually shows the count of open job orders. The real register-cart count is fed by `cartProvider` elsewhere on the POS screen. This confusion is also at the heart of the known bug below.

## Screens

### 1. Job Orders list — `lib/presentation/mobile/screens/drafts/drafts_list_screen.dart` (`/drafts`)

`ConsumerWidget` watching `activeDraftsProvider` (stream of non-converted drafts, newest-updated first).

- AppBar "Job Orders", back chevron (`goBackOr(RoutePaths.pos)`).
- Loading = `ListSkeleton`; error = `ErrorStateView` with retry (invalidates provider).
- **Empty state:** `clipboardList` icon, "No job orders yet", "Tap New Job Order to open a ticket for a bike being serviced.", plus a "New Job Order" filled button.
- List of `DraftListTile` inside `RefreshIndicator` (pull-to-refresh invalidates).
- FAB: `SettingsAddFab` "New Job Order" → new-job-order dialog.
- Delete on a tile is shown only to the creator or an admin (lines 105-107).

**List tile** — `lib/presentation/mobile/widgets/drafts/draft_list_tile.dart` (`AppCard`):
- Header: neutral shopping-cart glyph tile, ticket name, relative updated/created date; right column: grand total (primary color) + "N items".
- Middle: recessed preview box — a "Service job" outlined chip (wrench) when labor lines exist, then up to 3 items ("name ×qty gross"), then "+N more items".
- Footer: "By {createdByName}", optional red delete icon button, "Open" filled button (arrow-right).
- Deliberately neutral styling — no invented status/category colors (per the color-discipline rule).

### 2. New Job Order dialog — `lib/presentation/mobile/widgets/drafts/new_job_order_dialog.dart`

`AppDialog` (clipboardList icon, "New Job Order"):
- "Customer / plate" text field — becomes `draft.name`; hint "e.g. Juan / ABC-123"; required (warning snackbar if empty).
- `MotorcycleModelPicker` (optional at create; becomes required at bill-out).
- `MechanicPicker` (optional).

Returns `NewJobOrderInput{label, model, mechanicId, mechanicName}`. Creating a job order never touches the register cart. On success the list screen creates the draft via `draftOperationsProvider.createDraft` and immediately pushes the editor (`drafts_list_screen.dart:46-73`).

### 3. Job order editor — `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart` (`/drafts/:id`)

`ConsumerStatefulWidget` watching `draftByIdProvider(draftId)` (one-time fetch, not a stream). Keeps a local working copy `_working` so edits render instantly; **every edit persists immediately** via the full `updateDraft` path (not `updateDraftItems`, which would drop labor — see comment at lines 36-39). Wrapped in `LoadingOverlay` for delete.

- **AppBar:** ticket name (ellipsized), back chevron, red `trash2` delete action.
- **Info header** (lines 200-247): "Created {MMM d, y • h:mm a}" (clock icon), "Updated …" if present, notes text if present.
- **Parts section** (lines 250-288): header "Parts" (package icon) + "Add parts" text button. Empty state: shopping-cart icon, "No parts on this job order yet". Each item card: outlined "Nx" qty badge, name, "SKU: …" (mono), "… each" unit price, line gross, and minus / plus / remove icon buttons.
- **Labor & Service section** (lines 410-461): header (wrench) + "Add Labor" button; `MechanicPicker` for assignment; labor line rows (wrench icon, description, fee, remove; tap to edit).
- **Summary section** (lines 504-606): Subtotal; Discount row if any (green); "Labor (N services)"; Total row ("(N items)" + grand total); **"Bill out"** filled button (shopping-cart icon), disabled when no items.
- **Add-parts sheet** (`_AddPartsSheet`, lines 670-741): modal bottom sheet reusing the POS `ProductSearchField` (search + barcode scan via `productByBarcodeProvider`). Stays open so several parts accumulate; "Done" dismisses.
- **Labor dialog** (`_LaborLineDialog`, lines 744-836): "Add/Edit Labor" — Description (required) + Fee (currency prefix, must be > 0).

### 4. Delete confirmation — `lib/presentation/mobile/widgets/drafts/draft_dialogs.dart`

Destructive `AppDialog` "Delete job order?" (red trash2): `Delete "{name}"?`, recessed box with item count + "Total {grandTotal}", red "This action cannot be undone.", Cancel / red Delete.

### 5. Reports — `lib/presentation/mobile/screens/reports/job_order_reports_screen.dart` (`/reports/job-orders`)

Admin-only analytics over **completed (billed-out) sales**, not over open tickets.

- AppBar "Job Orders" + CSV download action.
- `DateRangePicker` (shared presets + custom; default today).
- `SegmentedButton`: **Models** / **Mechanics** views.
  - Models: `motorcycleModelReportProvider(params)` — rows of model name, "{jobCount} jobs", revenue. Empty: bike icon, "No job orders in this range".
  - Mechanics: `mechanicPerformanceReportProvider(params)` — mechanic name, "{jobCount} jobs", revenue. Empty: wrench icon, "No mechanic jobs in this range".
- Rows are simple `AppCard`s (`_row(title, sub, value)`).
- CSV via shared `saveReportCsv` (`job_orders_models_….csv` / `job_orders_mechanics_….csv`).

## Full user flow

1. **Create** — List FAB (or empty-state button) → New Job Order dialog (customer/plate, optional model + mechanic) → `createDraft` → editor opens.
2. **Work the ticket** — add parts via the search/scan bottom sheet, adjust quantities, assign mechanic, add/edit/remove labor lines. Every change writes through `updateDraft` immediately.
3. **Bill out** (`_billOut`, `draft_edit_screen.dart:612-635`):
   - Guard: motorcycle model must be set (`jobOrderReadyToBillOut`, `lib/core/utils/job_order_bill_out.dart`); otherwise warning "Set the motorcycle model to bill out".
   - If the register cart is non-empty: "Register in use" confirm dialog (the current sale will be cleared).
   - `cartProvider.notifier.loadFromDraft(draft)` loads items/labor/mechanic/model into the register cart and sets `CartState.sourceDraftId = draft.id` (the ticket is NOT deleted); `selectedDraftProvider` is cleared; navigate to `/checkout`.
4. **Checkout** — the standard POS checkout. The sale carries `draftId` (from `cart.toSale`, `cart_provider.dart:654`). On success, `ProcessSaleUseCase._reconcileDraft` (`lib/domain/usecases/pos/process_sale_usecase.dart:126-142`) calls `markDraftAsConverted(draftId, saleId)` → `isConverted=true`, `convertedToSaleId`, `convertedAt`. The ticket drops off the active list (`watchActiveDrafts` filters `isConverted == false`). Abandoning checkout leaves the ticket intact.
5. **Reporting** — billed-out sales feed the Models / Top Mechanics reports.

**Lifecycle:** open (`isConverted=false`) → billed out (`isConverted=true`, linked to the sale). No user-facing status enum. Old converted drafts can be bulk-purged via `deleteOldConvertedDrafts`. Delete allowed anytime (creator/admin only).

## State management (Riverpod)

`lib/presentation/providers/draft_provider.dart`:

- `draftRepositoryProvider` → `DraftRepositoryImpl` (Firestore collection `drafts`, items stored inline).
- `activeDraftsProvider` — `StreamProvider<List<DraftEntity>>`, auth-gated `watchActiveDrafts()`. Drives the list screen.
- `draftByIdProvider(id)` — `FutureProvider.family`, one-time fetch. Drives the editor. (`draftByIdStreamProvider` also exists.)
- `activeDraftCountProvider` — **non-autoDispose one-shot `FutureProvider<int>`** (lines 65-68). Drives the POS toolbar badge. ← implicated in the known bug.
- `userActiveDraftCountProvider` (lines 71-75) — currently unwatched; also never invalidated by the notifier (latent landmine).
- `draftOperationsProvider` — `StateNotifierProvider<DraftOperationsNotifier, AsyncValue<void>>`: `createDraft`, `updateDraft`, `updateDraftItems`, `updateDraftName`, `markAsConverted`, `deleteDraft`, `deleteOldConvertedDrafts`. Mutations go through use-case providers (`save/update/deleteDraftUseCaseProvider`) which own permission + owner-or-admin guards. The notifier's `_invalidateDraftProviders()` (lines 180-197, 231-234) refreshes list + count after mutations.
- `selectedDraftProvider` — `StateProvider<DraftEntity?>`, nulled on bill-out.

Cart side (`lib/presentation/providers/cart_provider.dart`): `CartState.sourceDraftId` (line 35), `isFromDraft` (258), `loadFromDraft` (598-612), `toDraft` (615), `toSale` (637, sets `draftId`), `resetAfterCheckout` (695-697).

Report providers (`lib/presentation/providers/sale_provider.dart:74-87`): `motorcycleModelReportProvider`, `mechanicPerformanceReportProvider` — `FutureProvider.autoDispose.family<…, DateRangeParams>`, derived from `salesByDateRangeProvider` with `SaleStatus.completed`.

Pickers: `MechanicPicker` (`lib/presentation/mobile/widgets/pos/mechanic_picker.dart`, watches `activeMechanicsProvider`); `MotorcycleModelPicker` (`…/motorcycle_model_picker.dart`, watches `activeMotorcycleModelsProvider`, supports adding a model inline).

## Data model

- **Entity:** `DraftEntity` (`lib/domain/entities/draft_entity.dart`) — `id, name, items (List<SaleItemEntity>), laborLines (List<LaborLineEntity>), mechanicId?, mechanicName?, motorcycleModel?, discountType, createdBy, createdByName, createdAt, updatedAt?, updatedBy?, isConverted, convertedToSaleId?, convertedAt?, notes?`. Computed money math (`subtotal, partsRevenue, laborSubtotal, grandTotal, totalProfit`, …) and immutable mutation helpers. Labor is never discounted.
- **Model/repo:** `lib/data/models/draft_model.dart`; `lib/data/repositories/draft_repository_impl.dart` — `watchActiveDrafts` (192-207), `markDraftAsConverted` (327), `getActiveDraftCount` (406), `deleteOldConvertedDrafts`.
- **Report structs:** `MotorcycleModelStat/ReportData` (`lib/core/utils/motorcycle_model_report.dart`); `MechanicPerformanceStat/ReportData` (`lib/core/utils/mechanic_performance_report.dart`) — computed from sales.

## Permissions

- `Permission.viewJobOrderReports` (`lib/core/constants/role_permissions.dart:54`), admin-only (line 193). Route-guarded: `route_guards.dart:48`; hub card gated by `canJobOrders`.
- List/editor have no dedicated view permission — any authenticated user reaches `/drafts` (guard at `route_guards.dart:80`). Delete restricted in-UI to creator/admin; mutations additionally guarded in the draft use cases (mirrors `firestore.rules`).

---

## KNOWN BUG — stale POS badge after bill-out (FIXED 2026-07-02, option 2 below: badge now derives from the live `activeDraftsProvider` stream; one-shot count providers + repo count methods deleted)

**Symptom:** after a job order is billed out, the badge on the POS toolbar's shopping-cart icon still shows the old count.

**Root cause (high confidence):** that badge is not a cart count — it shows the open job-order count from `activeDraftCountProvider`, a **non-autoDispose one-shot `FutureProvider`** (`draft_provider.dart:65-68`), so its cached value survives navigation indefinitely.

- Conversion happens deep in the domain layer: `ProcessSaleUseCase._reconcileDraft` calls `markDraftAsConverted` directly on the repository (`process_sale_usecase.dart:126-142`) — it has no Riverpod access, so it can't invalidate anything.
- The checkout success path (`checkout_screen.dart:453-461`) invalidates `todaysSalesProvider`, `todaysSalesSummaryProvider`, `activeDraftsProvider` (the list — that's why the list screen is correct), `productsProvider`, `lowStockProductsProvider` — **but not `activeDraftCountProvider`**.
- The presentation-layer path that would invalidate the count — `DraftOperationsNotifier.markAsConverted` → `_invalidateDraftProviders()` — has **zero call sites** (dead code).
- The badge only self-corrects when a draft is later created/updated/deleted through the notifier, or on app restart.

**Blast radius:** display-only. The register cart itself is fine (`resetAfterCheckout` clears it), the drafts list is fine, Firestore is correct. The idempotent-retry checkout path (`_handleAlreadyRecorded`) has the same missing invalidate. `userActiveDraftCountProvider` shares the never-invalidated problem but has no watchers yet.

**Fix options (in increasing robustness):**
1. One-liner: add `ref.invalidate(activeDraftCountProvider)` next to the existing invalidates in `checkout_screen.dart` (covers both success paths).
2. Derive the badge count from `activeDraftsProvider.length` and delete the one-shot count provider — removes the whole "forgot to invalidate the count" bug class and makes the badge real-time.
3. Make `activeDraftCountProvider` a stream (`watchActiveDrafts().map((d) => d.length)`) — same effect as 2 with less widget churn.

The redesign should also consider renaming/re-iconing this badge (it uses a shopping-cart icon for a job-order count) — the icon choice is what makes the bug read as "cart count not reset".
