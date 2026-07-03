# Job Orders — Current UI & Flow (redesign handoff)

_Documented 2026-07-03, against `main` (`16280ad`). Written so a future session can redesign this feature without re-exploring the codebase._

> ⚠️ **`reference_current-ui.html` in this folder is STALE.** It reproduces the *pre-redesign* UI (as of `53cf5cf`, 2026-07-02). The feature has since been visually redesigned and shipped (commits `37fb818`, `d768129` — POS cart-card parity + red/white badge pill; `1ab4597` — live-derived badge count). Do not trust the HTML; **this markdown is the source of truth** for the current UI.

## What it is

Job Orders are motorcycle-service tickets. The feature **repurposes the old Drafts feature**: internally everything is still named `draft`/`Draft` (entity, repository, providers, routes, Firestore collection `drafts`), while all user-facing copy says "Job Order". A job order is a non-converted `DraftEntity`: an open ticket carrying parts, labor lines, a mechanic, and a motorcycle model, which is eventually "billed out" into a Sale (non-destructively — the ticket survives an abandoned checkout and is only marked converted when the sale is written).

Original design spec: `docs/superpowers/specs/2026-07-01-job-orders-from-drafts-design.md`. The approved visual redesign in this bundle (`MAKI POS Job Orders.dc.html`) has been **implemented** — the screens below already reflect it, with two deliberate deviations noted inline (red/white badge pill; add-parts sheet close affordance).

## Entry points & routes

| Entry point | Where | Goes to |
|---|---|---|
| POS app-bar badge | `lib/presentation/mobile/screens/pos/pos_screen.dart:66` — `JobOrderBadgeButton` (`lib/presentation/mobile/widgets/pos/job_order_badge_button.dart`): `clipboardList` icon (23px) with a **red pill** (white count, 2px ring in the app-bar surface color) showing the live open job-order count; hidden when 0; tooltip "Job Orders" | `/drafts` (`_navigateToDrafts`, pos_screen.dart:702-704) |
| POS footer "Save Job Order" | `pos_screen.dart:518-532` — outlined button (`clipboardPlus`), enabled when `cart.canSaveAsDraft` (`cart_provider.dart:252`); saves the register cart as a ticket | Save-as-Job-Order dialog → stays on POS |
| Reports hub card | `lib/presentation/mobile/screens/reports/reports_hub_screen.dart:60-67` — `clipboardList` icon, "Job Orders / Models serviced + mechanic performance", gated by `viewJobOrderReports` | `/reports/job-orders` |

Routes (`lib/config/router/route_names.dart:202-203, 244`, wired in `lib/config/router/app_routes.dart`):

- `/drafts` → `DraftsListScreen` (app_routes.dart:185-188)
- `/drafts/:id` (name `draftEdit`) → `DraftEditScreen` (app_routes.dart:190-196)
- `/reports/job-orders` (name `jobOrderReports`) → `JobOrderReportsScreen` (app_routes.dart:363-367)

The old naming confusion (a shopping-cart glyph showing a job-order count) was **fixed by the redesign**: the badge is now a `clipboardList` glyph, and its count derives from the live drafts stream (see "Badge-bug history" at the bottom).

## Screens

### 1. Job Orders list — `lib/presentation/mobile/screens/drafts/drafts_list_screen.dart` (`/drafts`)

`ConsumerWidget` watching `activeDraftsProvider` (stream of non-converted drafts, newest-updated first).

- AppBar "Job Orders", back chevron (`goBackOr(RoutePaths.pos)`), and a **`plus` icon action** "New Job Order" (lines 30-34) — the old FAB was removed per the redesign; create now lives in the app bar.
- Loading = `ListSkeleton`; error = `ErrorStateView` with retry (invalidates provider).
- **Empty state** (lines 82-95): `EmptyStateView` with `tiled: true` (soft square glyph tile), `clipboardList` icon, "No job orders yet", "Tap New Job Order to open a ticket for a bike being serviced.", plus a filled "New Job Order" button (`plus`).
- List of `DraftListTile` inside `RefreshIndicator` (pull-to-refresh invalidates + awaits the provider future, lines 97-101). `ListView` padding `vertical: 8`.
- Delete on a tile is shown only to the creator or an admin (lines 108-110, mirrors `firestore.rules`).
- Create flow (`_createJobOrder`, lines 48-75): dialog → build a blank `DraftEntity` → `createDraft` wrapped in `runWithWaiting` ("Creating…" blocking overlay) → push the editor.

**List tile** — `lib/presentation/mobile/widgets/drafts/draft_list_tile.dart` (`AppCard`, radius `AppRadius.lg` = 18, margin 16h/6v, padding 16):
- Header row: 40×40 neutral tile (`AppColors.neutralTileFill`, radius 11) with a muted **`clipboardList`** glyph (20px); ticket name (15/600, ellipsized); absolute date `MMM d, h:mm a` of `updatedAt ?? createdAt` (12, muted). Right column: grand total (15/700, `colorScheme.primary` — slate light / gold dark) + "N items" (12, muted).
- Middle: recessed preview box (fill `lightSurfaceMuted`/`darkCanvas`, hairline border, radius `AppRadius.md` = 14). Chips row (Wrap, 6px gaps): a **"Service job"** chip (`wrench`, primary color + primary outline) when labor lines exist, and a **neutral model chip** (`bike`, muted color, `neutralTileFill`) when a motorcycle model is set. Then up to 3 item rows — name (13), `×qty` (13 muted), **net** line amount (13/500; nets so preview lines sum to the tile total even with per-item discounts, lines 253-265) — then "+N more items" (12, muted italic).
- Footer: "By {createdByName}" (12, muted), optional red delete icon button (`trash2`, `AppColors.costUp`), filled **"Open"** button (`arrowRight` 18, radius 14).
- Deliberately neutral styling — no invented status/category colors (per the color-discipline rule). The only colored elements: primary total/chip/Open, red delete.

### 2. New Job Order dialog — `lib/presentation/mobile/widgets/drafts/new_job_order_dialog.dart`

`AppDialog` (`clipboardList` leading chip, "New Job Order"):
- "Customer / plate" text field — becomes `draft.name`; hint "e.g. Juan / ABC-123"; autofocus, word-capitalized; required (warning snackbar "Enter a customer or plate label" if empty).
- `MotorcycleModelPicker` (optional at create; becomes **required at bill-out**).
- `MechanicPicker` with `nonePlaceholder: '— Optional —'`.
- Actions: text "Cancel" + filled "Create" (`appDialogCancel`/`appDialogPrimary` helpers).

Returns `NewJobOrderInput{label, model, mechanicId, mechanicName}`. Creating a job order never touches the register cart.

### 3. Save-as-Job-Order dialog — `lib/presentation/mobile/widgets/drafts/save_job_order_dialog.dart`

The POS-side twin of the New dialog: `AppDialog` (**`clipboardPlus`** chip, "Save as Job Order"), same three fields, actions Cancel / **"Save"**. Prefilled from the cart (`initialModel`/`initialMechanicId`/`initialMechanicName`) so choices made in the POS Labor & Service section carry over.

Flow (`pos_screen.dart:634-692`): if the cart was loaded from a ticket, the original name is reused and the dialog is **skipped**; otherwise the dialog collects label/model/mechanic, writes them into the cart, then `_saveDraft` creates or updates via `draftOperationsProvider` under a `runWithWaiting` overlay ("Saving…"/"Updating…", double-submit guard), snackbars "Job order saved/updated", and resets the cart.

### 4. Job order editor — `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart` (`/drafts/:id`)

`ConsumerStatefulWidget` watching `draftByIdProvider(draftId)` (one-time fetch, not a stream). Keeps a local working copy `_working` so edits render instantly; **every edit persists immediately** via the full `updateDraft` path (not `updateDraftItems`, which would drop labor — comment at lines 40-43). If a write fails, the optimistic copy is discarded and the ticket reloads ("Failed to save changes — ticket reloaded", lines 53-68). Wrapped in `LoadingOverlay` for delete.

- **AppBar:** ticket name (17/600, ellipsized), back chevron, red `trash2` delete action (`AppColors.costUp`).
- **Info header** (lines 221-274, band with bottom hairline): an editable **`MotorcycleModelPicker`** (the bill-out gate — the serviced bike can change mid-job; clearing it re-arms the gate, lines 74-81), then "Created {MMM d, y • h:mm a}" (`clock` 14), "Updated …" (`squarePen` 14) if present, notes text if present.
- **Parts section** (header lines 277-303): `package` 16 + "Parts" (labelMedium/600, muted) + compact **"Add parts"** text button (`plus` 16). Empty state (lines 328-344): `shoppingCart` 56 muted, "No parts on this job order yet". Each item renders with the **POS `CartItemTile`** (lines 349-358 — cart-card parity from the redesign): `AppCard` with name + `x` remove, `SKU • ₱price / unit` line + compact cost-code pill, 40px outlined qty stepper (− count +, fill `lightSurfaceMuted`/`darkCanvas`), a **per-item Discount chip** (`tag`; quiet outline → green `successFill` when applied), net line total (17/700; strikethrough gross above when discounted), and swipe-to-delete (red `AppColors.error` background, white `trash2`).
- **Per-item discount** (lines 360-379): reuses the POS `DiscountInputDialog`; writes go through the ticket's persist path (`applyItemDiscount` / `changeDiscountType`).
- **Labor & Service section** (lines 381-431, band with top hairline): header `wrench` 16 + "Labor & Service" + "Add Labor" text button; `MechanicPicker` for assignment; labor line rows (lines 433-472) as tappable `AppCard`s (radius 14) — `wrench` 14, description, fee (bodyMedium/500), muted `x` remove; tap to edit.
- **Summary section** (lines 474-571, pinned footer on `scaffoldBackgroundColor`, top hairline): `SummaryRow`s — Subtotal; Discount row if any (green `successText`, `-₱…`); "Labor (N service/s)". Total row (lines 511-557): border-top (`darkHairline` / literal `Color(0xFFE5E3DE)`), "Total " 15/700 with inline "(N items)" 12.5/500 muted, value 18/700 `onSurface`. Then a full-width filled **"Bill out"** button (`shoppingCart` icon), disabled when no items.
- **Add-parts sheet** (`_AddPartsSheet`, lines 641-748): modal bottom sheet on the scaffold background, **fixed height** (62% of screen, clamped for the keyboard) so search results always have room. Grab handle (40×4), "Add parts" title (16/700) + muted `x` close button (there is **no pinned "Done" button** — the mock's Done became the header ✕), then the POS `ProductSearchField` with `inlineResults: true` (hint "Search name, SKU, or scan barcode"; barcode scan via `productByBarcodeProvider`, "Product not found: …" warning on miss). Selecting a product appends it (qty 1) via the persist path, clears the field, and refocuses — the sheet stays open so several parts accumulate; the editor behind updates live.
- **Labor dialog** (`_LaborLineDialog`, lines 751-844): `AppDialog` (`wrench` chip) "Add Labor"/"Edit Labor" — Description (required, hint "e.g. Engine tune-up") + Fee (currency prefix, must be > 0). Actions Cancel / Add-or-Save.
- **Not-found / error states** (lines 149-176): loading scaffold, error scaffold with "Back to Job Orders", and a "Job Order Not Found" empty state (note: uses Material `Icons.search_off`, not Lucide).

### 5. Delete confirmation — `lib/presentation/mobile/widgets/drafts/draft_dialogs.dart`

Destructive `AppDialog` "Delete job order?" (red `trash2` chip): `Delete "{name}"?`, recessed box (fill + hairline, radius 14) with item count + "Total {grandTotal}", red "This action cannot be undone." (`errorOnDark` in dark), Cancel / **Delete** (stays `AppColors.error` red in both themes). Used by both the list and the editor.

### 6. (Dead) Draft detail sheet — `lib/presentation/mobile/widgets/drafts/draft_detail_sheet.dart`

A full `DraggableScrollableSheet` detail view ("Load into Cart" footer, Items/Summary/Information/Notes cards) left over from the pre-Job-Orders Drafts era. **It has zero call sites** — the list now opens the editor directly. Still carries the old `shoppingCart` header glyph and cart copy. Candidate for deletion in the redesign.

### 7. Reports — `lib/presentation/mobile/screens/reports/job_order_reports_screen.dart` (`/reports/job-orders`)

Admin-only analytics over **completed (billed-out) sales**, not over open tickets.

- AppBar "Job Orders" + `download` CSV action.
- `DateRangePicker` (shared presets + custom; default today).
- `SegmentedButton`: **Models** (`bike` 16) / **Mechanics** (`wrench` 16), `showSelectedIcon: false`. Selected segment uses a **primary tint** (slate @10% light / gold @16% dark, lines 110-118) — a deliberate local override of the app-wide green segmented theme (green stays reserved for discounts).
  - Models: `motorcycleModelReportProvider(params)` — rows of model name, "{jobCount} jobs", revenue. Empty: `bike` icon, "No job orders in this range".
  - Mechanics: `mechanicPerformanceReportProvider(params)` — mechanic name, "{jobCount} jobs", revenue. Empty: `wrench` icon, "No mechanic jobs in this range".
- Rows (lines 190-241) are `AppCard`s (radius 16): 38×38 neutral glyph tile (`neutralTileFill`, radius 11, muted `bike`/`wrench` 18), title 15/600, sub 12 muted, revenue 15/700 in primary.
- Loading = `ListSkeleton` (240px); error = `ErrorStateView` + retry.
- CSV via shared `saveReportCsv` (`job_orders_models_….csv` / `job_orders_mechanics_….csv`); "Nothing to export in this range" snackbar when empty.

## Full user flow

1. **Create** — list app-bar `plus` (or empty-state button) → New Job Order dialog (customer/plate, optional model + mechanic) → `createDraft` under a waiting overlay → editor opens. Alternatively **from POS**: build a cart, "Save Job Order" → Save-as dialog → ticket created, cart resets.
2. **Work the ticket** — add parts via the search/scan bottom sheet, adjust quantities, apply per-item discounts, change the motorcycle model, assign a mechanic, add/edit/remove labor lines. Every change writes through `updateDraft` immediately (optimistic render, resync on failure).
3. **Bill out** (`_billOut`, `draft_edit_screen.dart:577-600`):
   - Guard: motorcycle model must be set (`jobOrderReadyToBillOut`, `lib/core/utils/job_order_bill_out.dart`); otherwise warning "Set the motorcycle model to bill out".
   - If the register cart is non-empty: "Register in use" confirm dialog (`refreshCw` icon; the current sale will be cleared).
   - `cartProvider.notifier.loadFromDraft(draft)` loads items/labor/mechanic/model into the register cart and sets `CartState.sourceDraftId = draft.id` (the ticket is NOT deleted); `selectedDraftProvider` is cleared; navigate to `/checkout`.
4. **Checkout** — the standard POS checkout. The sale carries `draftId` (from `cart.toSale`, `cart_provider.dart:642-659`). On success, `ProcessSaleUseCase._reconcileDraft` (`lib/domain/usecases/pos/process_sale_usecase.dart:126-142`, also on the idempotent-retry path at :119) calls `markDraftAsConverted(draftId, saleId)` → `isConverted=true`, `convertedToSaleId`, `convertedAt`. The ticket drops off the active list in real time (`watchActiveDrafts` filters `isConverted == false`, and the list + badge are stream-fed). Abandoning checkout leaves the ticket intact.
5. **Reporting** — billed-out sales feed the Models / Mechanics reports.

**Lifecycle:** open (`isConverted=false`) → billed out (`isConverted=true`, linked to the sale). No user-facing status enum. Old converted drafts can be bulk-purged via `deleteOldConvertedDrafts`. Delete allowed anytime (creator/admin only).

## State management (Riverpod)

`lib/presentation/providers/draft_provider.dart`:

- `draftRepositoryProvider` → `DraftRepositoryImpl` (Firestore collection `drafts`, items stored inline).
- `activeDraftsProvider` (lines 21-25) — auth-gated `StreamProvider<List<DraftEntity>>` over `watchActiveDrafts()`. Drives the **list screen** and (derived) the POS badge.
- `activeDraftCountProvider` (lines 67-69) — `Provider<AsyncValue<int>>` **derived from the live `activeDraftsProvider` stream** (`whenData((d) => d.length)`), so it can never go stale. Drives the POS badge (`job_order_badge_button.dart:20`). Replaced the old one-shot `FutureProvider` that caused the stale-badge bug.
- `draftByIdProvider(id)` (lines 46-50) — `FutureProvider.family`, one-time fetch. Drives the **editor**.
- `draftByIdStreamProvider`, `userActiveDraftsProvider`, `allDraftsProvider` (lines 28-62) — defined but currently have **no UI watchers**.
- `draftOperationsProvider` — `StateNotifierProvider<DraftOperationsNotifier, AsyncValue<void>>`: `createDraft`, `updateDraft`, `updateDraftItems`, `updateDraftName`, `markAsConverted`, `deleteDraft`, `deleteOldConvertedDrafts`. Mutations go through use-case providers (`save/update/deleteDraftUseCaseProvider`) which own permission + owner-or-admin guards; a converted ticket is frozen. `_invalidateDraftProviders()` (lines 226-229) now only invalidates `activeDraftsProvider` — the badge count derives from it, so it refreshes too; `updateDraft` additionally invalidates `draftByIdProvider(draft.id)` (line 144).
- `selectedDraftProvider` (line 248) — `StateProvider<DraftEntity?>`; nulled on bill-out, checkout success, and session reset. No current reader — vestigial.

Cart side (`lib/presentation/providers/cart_provider.dart`): `CartState.sourceDraftId` (:35) + retained `draftName` (:43), `canSaveAsDraft` (:252), `isFromDraft` (:258), `loadFromDraft` (:598-612), `toDraft` (:620), `toSale` (:642, sets `draftId` :659), `resetAfterCheckout` (:700).

Report providers (`lib/presentation/providers/sale_provider.dart:76-87`): `motorcycleModelReportProvider`, `mechanicPerformanceReportProvider` — `FutureProvider.autoDispose.family<…, DateRangeParams>`, derived from sales with `SaleStatus.completed`.

Pickers: `MechanicPicker` (`lib/presentation/mobile/widgets/pos/mechanic_picker.dart`, watches `activeMechanicsProvider`); `MotorcycleModelPicker` (`…/motorcycle_model_picker.dart`, watches `activeMotorcycleModelsProvider`, supports adding a model inline).

## Data model

- **Entity:** `DraftEntity` (`lib/domain/entities/draft_entity.dart`) — `id, name, items (List<SaleItemEntity>), laborLines (List<LaborLineEntity>), mechanicId?, mechanicName?, motorcycleModel?, discountType, createdBy, createdByName, createdAt, updatedAt?, updatedBy?, isConverted, convertedToSaleId?, convertedAt?, notes?`. Computed money math (`subtotal, partsRevenue, laborSubtotal, totalDiscount, grandTotal, totalProfit, totalItemCount`, …) and immutable mutation helpers (`addItem, updateItemQuantity, removeItem, applyItemDiscount, changeDiscountType, addLaborLine, updateLaborLine, removeLaborLine`). Labor is never discounted.
- **Model/repo:** `lib/data/models/draft_model.dart`; `lib/data/repositories/draft_repository_impl.dart` — `watchActiveDrafts`, `markDraftAsConverted`, `deleteOldConvertedDrafts`. (The old `getActiveDraftCount` count methods were deleted with the badge fix.)
- **Report structs:** `MotorcycleModelStat/ReportData` (`lib/core/utils/motorcycle_model_report.dart`); `MechanicPerformanceStat/ReportData` (`lib/core/utils/mechanic_performance_report.dart`) — computed from sales.

## Theming

Everything sits on the app's "elevated" theme: `AppCard` (soft shadow light / 1px `darkHairline` border dark), `AppDialog`/`AppBottomSheet` shells, Lucide icons, Figtree UI type + Roboto Mono for SKUs, `₱#,##0.00` currency via `toCurrency()`. Tokens used by these screens (`lib/core/theme/app_colors.dart`): `neutralTileFill` (glyph tiles), `lightSurfaceMuted`/`darkCanvas` + `lightHairline`/`darkInputBorder`/`darkHairline` (recessed boxes, steppers), `costUp`/`error`/`errorOnDark` (destructive), `successText`/`successFill` (discount only), `primaryAccent` (gold, via `colorScheme.primary` in dark). Radii from `AppRadius` (`lib/core/theme/app_spacing.dart:20-32`): lg 18 cards, field 16, md 14 recessed/rows, 11 glyph tiles.

## Permissions

- `Permission.viewJobOrderReports` (`lib/core/constants/role_permissions.dart:54`), admin-only (line 193). Route-guarded: `route_guards.dart:50`; hub card gated by `canJobOrders` (reports_hub_screen.dart:23-25, 60).
- List/editor have no dedicated view permission — any authenticated user reaches `/drafts` (common route, `route_guards.dart:22`; dynamic `/drafts/:id` allowed at :81-82). Delete restricted in-UI to creator/admin; mutations additionally guarded in the draft use cases (mirrors `firestore.rules`; note the rules carry a conversion-only exception so any cashier can bill out — see memory note 2026-07-02).

## Badge-bug history (RESOLVED)

The pre-redesign POS badge showed the open job-order count behind a shopping-cart glyph, fed by a non-autoDispose one-shot `FutureProvider` that nothing invalidated after checkout — so it went stale after bill-out. Fixed in `1ab4597`: the count is now **derived from the live `activeDraftsProvider` stream** (`draft_provider.dart:64-69`), the one-shot count providers and repo count methods were deleted, and the redesign re-iconed the badge to `clipboardList`. Firestore's snapshot stream means the badge self-corrects even when conversion happens deep in `ProcessSaleUseCase` with no Riverpod access. Nothing to carry forward except: don't reintroduce a cached count.

---

## Redesign starting points

Concrete, code-observable friction points (no invented user complaints):

1. **Dead widget:** `lib/presentation/mobile/widgets/drafts/draft_detail_sheet.dart` has zero call sites, still uses the pre-redesign `shoppingCart` header glyph (:45) and "Load into Cart" copy, and carries non-token color literals (`Color(0xFFF0F0F0)` :157, :269; notes-card literals `0x1AE8B84C`/`0x1FFFC107`/`0x47E8B84C`/`0x57B7831A`/`0xFF9A6B00` :410-412). Delete or resurrect deliberately.
2. **Draft/Job-Order naming split everywhere internal:** routes `/drafts` (`route_names.dart:202-203`), files `drafts_list_screen.dart`/`draft_edit_screen.dart`, providers `draft_provider.dart`, and even POS methods `_showSaveDraftDialog`/`_saveDraft` (`pos_screen.dart:634, 664`) vs. user-facing "Job Order". Any rename decision should be global or explicitly deferred.
3. **Non-token color literal in the editor:** the summary total hairline hard-codes `Color(0xFFE5E3DE)` in light (`draft_edit_screen.dart:519`) instead of an `AppColors` token (the dark side uses `darkHairline`).
4. **Material-icon stragglers:** the editor's not-found state uses `Icons.search_off` (`draft_edit_screen.dart:168`) — the only non-Lucide glyph on these screens (the Cupertino→Lucide sweep missed it); nav metadata also uses `Icons.drafts` (`route_guards.dart:238`).
5. **Leftover cart language in the editor:** the empty-parts state uses `shoppingCart` (`draft_edit_screen.dart:335`) and "Bill out" uses `shoppingCart` (:563) while the feature identity is `clipboardList`. Bill-out's cart icon is arguably meaningful (it loads the register), but the empty state's is not.
6. **Editor is a one-time fetch:** it watches `draftByIdProvider` (future) with a local `_working` copy (`draft_edit_screen.dart:146, 43-51`), so edits from another device never appear until re-entry; `draftByIdStreamProvider` exists unused (`draft_provider.dart:38-43`). Two mechanics on the same ticket silently diverge (last write wins).
7. **Fixed-column editor layout:** only the parts list scrolls (`draft_edit_screen.dart:305-315`); info header, Labor & Service (which grows unbounded with labor lines, :427), and the summary are all pinned. Several labor lines + keyboard can squeeze the parts viewport to near-zero on small phones.
8. **Add-parts sheet diverges from the mock/README:** the bundle documents a pinned right-aligned "Done" (README §6); shipped code has only a header ✕ (`draft_edit_screen.dart:708-714`). Fine, but the README is stale on this point.
9. **Badge pill deviates from the mock by user preference:** red `AppColors.error` fill + hard-coded `Colors.white` text (`job_order_badge_button.dart:40-52`) instead of the mock's slate/gold pill — documented in the widget comment (:10-11). Any restyle must respect that this was an explicit user choice.
10. **Spacing arithmetic idiom:** repeated `AppSpacing.sm + 4`/`AppSpacing.lg - 4` micro-adjustments (e.g. `draft_list_tile.dart:62, 106, 202, 252`; `draft_edit_screen.dart:443`) show the 12px step is missing from the `AppSpacing` scale (`app_spacing.dart:5-12`).
11. **Near-duplicate dialogs:** `new_job_order_dialog.dart` and `save_job_order_dialog.dart` are structurally identical (label + model + mechanic; different title/icon/primary label and prefill). One parameterized widget would remove the drift risk.
12. **Vestigial providers:** `selectedDraftProvider` is written in three places but read nowhere (`draft_provider.dart:248`); `userActiveDraftsProvider`, `allDraftsProvider`, `draftByIdStreamProvider` have no watchers (`draft_provider.dart:28-62`). Dead surface to prune or wire up.
