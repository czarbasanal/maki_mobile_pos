# Drafts → Job Orders — full rename + schema migration (both surfaces)

**Date:** 2026-07-27 · **Status:** approved (user chose FULL migration incl. schema) · **Surfaces:** Flutter mobile + web admin + Firestore schema/rules/indexes/scripts

## Context

The product concept was renamed Drafts → Job Orders long ago in the UI
(routes, labels, JO-numbers), but code symbols and the persisted schema still
say draft: `DraftEntity`/`Draft`, `useDraftMutations`, `drafts` collection,
`sales.draftId`, rules block, indexes. User directive: update ALL terms and
names, including the schema. Nothing deploys without the user; the shop
phones run APK +17 (writes old names) until +18 installs.

## Naming decisions

- Firestore collection: `drafts` → **`job_orders`**; sale field: `draftId` →
  **`jobOrderId`**. Doc-internal field names (`isConverted`,
  `convertedToSaleId`, `convertedAt`, `notes`, …) unchanged.
- Code: `Draft*` → `JobOrder*`, `draft*` → `jobOrder*`, files/dirs renamed to
  match (`draft_provider.dart` → `job_order_provider.dart`,
  `features/../drafts/` → `job_orders/`, `Draft.ts` → `JobOrder.ts`, …).
  UI/error strings say "Job Order".
- Activity-log `entityType`: new writes use `'job_order'` (3 web writer
  sites; no reader filters on it — old `'draft'` rows stay valid).
- Permission enum members both surfaces IN LOCK-STEP: `saveDraft` →
  `saveJobOrder`, `viewDrafts` → `viewJobOrders`, `editDraft` →
  `editJobOrder`, `deleteDraft` → `deleteJobOrder` (code-level only;
  permissions are derived from roles, not persisted).
- Web legacy redirects `/drafts` → `/job-orders` in `routes.tsx` KEEP their
  literal `/drafts` path strings (they exist for old bookmarks).

## Do-NOT-rename collisions (guard rails)

Same word, different concept — every one of these stays untouched:
1. **Purchase-order status `draft`** (mobile `PurchaseOrderStatus.draft`,
   `isDraft`, `poDraftFg/Bg`, parse fallbacks).
2. **Receiving status `draft`** (both surfaces: `ReceivingStatus.draft`,
   `getDraftReceivings`, `draftReceivingsProvider`, `useDraftReceivings`,
   `resolveDraftItems`, `watchDrafts`, receiving UI copy "Drafts"/"Open
   drafts", `ReceivingDashboardPage`, `receiving_drafts_screen.dart`,
   `RoutePaths.receivingDrafts`, and web's live query literal
   `where('status','==','draft')`).
3. **Sale status `draft`** (`SaleStatus.draft` both surfaces,
   `AppColors.draft`).
4. In-memory form state: `DailyClosingDraft`/`draftExcluding`/
   `dailyClosingDraftProvider` (EOD), web `PaymentDraft`/`usePaymentDraft`,
   `usePayslipDraft`, `PosPage.noteDraft`.
5. Docs under `docs/superpowers/` and `design/` handoff bundles: historical,
   untouched.

Mechanical consequence: NO blanket `draft→jobOrder` replace. Every rename is
an explicit symbol mapping (word-boundary), file-scoped where ambiguous.

## Symbol maps (authoritative)

### Mobile (files: rename to match class names)
`DraftEntity→JobOrderEntity`, `DraftModel→JobOrderModel`,
`DraftRepository→JobOrderRepository` (+`Impl`), `_draftsRef→_jobOrdersRef`,
`Save/Update/DeleteDraftUseCase→…JobOrderUseCase`,
`DraftsListScreen→JobOrdersListScreen`, `DraftEditScreen→JobOrderEditScreen`,
`DraftListTile→JobOrderListTile`, `showDeleteDraftDialog→showDeleteJobOrderDialog`,
providers: `draftRepositoryProvider→jobOrderRepositoryProvider`,
`activeDraftsProvider→activeJobOrdersProvider`, `userActiveDraftsProvider→userActiveJobOrdersProvider`,
`draftByIdProvider/draftByIdStreamProvider→jobOrderById…`, `allDraftsProvider→allJobOrdersProvider`,
`activeDraftCountProvider→activeJobOrderCountProvider`,
`DraftOperationsNotifier/draftOperationsProvider→JobOrderOperations…`,
`selectedDraftProvider→selectedJobOrderProvider`, `AllDraftsParams→AllJobOrdersParams`,
repo methods `getDraftById→getJobOrderById`, `watchDraft→watchJobOrder`,
`watchActiveDrafts→watchActiveJobOrders`, `getDraftsByDateRange→getJobOrdersByDateRange`,
`createDraft/updateDraft/updateDraftItems/updateDraftName/deleteDraft→…JobOrder…`,
`markDraftAsConverted→markJobOrderAsConverted`, `deleteOldConvertedDrafts→deleteOldConvertedJobOrders`,
cart: `sourceDraftId→sourceJobOrderId`, `draftName→jobOrderName`,
`clearSourceDraftId/clearDraftName→clearSourceJobOrderId/clearJobOrderName`,
`canSaveAsDraft→canSaveAsJobOrder`, `isFromDraft→isFromJobOrder`,
`loadFromDraft→loadFromJobOrder`, `toDraft→toJobOrder`,
sale: `SaleEntity.draftId→jobOrderId`, `clearDraftId→clearJobOrderId`,
`SaleEntity.isFromDraft→isFromJobOrder`,
usecase: `_draftRepository→_jobOrderRepository`, `_reconcileDraft→_reconcileJobOrder`,
router: `RouteNames.drafts→jobOrders ('jobOrders')`, `draftEdit→jobOrderEdit`,
`RoutePaths.drafts '/drafts'→jobOrders '/job-orders'`, `draftEdit '/drafts/:id'→'/job-orders/:id'`
(mobile-internal paths — safe), guards + nav item follow (`Icons.drafts` icon
stays; it's a Material icon name), constants:
`FirestoreCollections.drafts→jobOrders = 'job_orders'`,
`maxDraftDescriptionLength→maxJobOrderDescriptionLength`,
`Validators.draftDescription→jobOrderDescription`,
`session_reset` references follow. Strings: `'Unnamed Draft'→'Unnamed Job Order'`,
`'From Draft'→'From Job Order'` (sale detail), repo/usecase error strings
`draft→Job Order`, `'Draft conversion failed'→'Job Order conversion failed'`.
Dead code DELETED instead of renamed: `draft_remote_datasource.dart` (zero
refs), `draft_detail_sheet.dart` + its 2 test files (zero call sites).

### Web
Entity `Draft→JobOrder` (file `Draft.ts→JobOrder.ts`),
`DraftRepository→JobOrderRepository`, `FirestoreDraftRepository→FirestoreJobOrderRepository`,
`draftConverter→jobOrderConverter` (`draftItemsToMaps→jobOrderItemsToMaps`,
`parseDraftItems→parseJobOrderItems`),
`draftConversion.ts→jobOrderConversion.ts` (`DraftConversionOutcome→JobOrderConversionOutcome`,
`draftConversionOutcome→jobOrderConversionOutcome`),
hooks `useDrafts→useJobOrders`, `useDraft→useJobOrder`,
`useDraftMutations.ts→useJobOrderMutations.ts` (`SaveDraftInput→SaveJobOrderInput`,
`useSaveDraft→useSaveJobOrder`, `DeleteDraftInput→DeleteJobOrderInput`,
`useDeleteDraft→useDeleteJobOrder`), `draftEditStore→jobOrderEditStore`
(`useDraftEditStore→useJobOrderEditStore`), DI `draftRepo→jobOrderRepo`,
`useDraftRepo→useJobOrderRepo`, `queryKeys.drafts→queryKeys.jobOrders`
(cache keys `['drafts']→['job_orders']` — client-side only),
cart store `draftId→jobOrderId`, `draftName→jobOrderName`, `loadDraft→loadJobOrder`,
`Sale.draftId→jobOrderId`, `CheckoutInput.draftId→jobOrderId`,
`FirestoreCollections.drafts→jobOrders = 'job_orders'` (collections.ts),
page-local: `saveDraft→saveJobOrder` (mutation var), `onSaveDraft→onSaveJobOrder`,
`deleteDraft→deleteJobOrder`, `loadDraft→loadJobOrder` callers,
`entityType 'draft'→'job_order'` (3 sites), sale-repo conversion vars
(`draftRef→jobOrderRef`, `draftSnap→jobOrderSnap`), error string
`'This draft was already converted to a sale'→'This Job Order was already billed out'`.

### Transition read-fallback (both surfaces, temporary)
Sale converters read `jobOrderId ?? draftId` (mobile
`sale_model.dart` map read; web `saleConverter.ts` read) with a dated
`// TODO(remove after +18 rollout + final sweep)` — insurance against
straggler sales written by +17 phones between migration and APK install.
Writes use ONLY `jobOrderId`.

## Schema migration

New script `scripts/migrate-drafts-to-job-orders.mjs` (service-account,
mirrors existing scripts’ conventions; `--dry-run` default, `--yes` to
execute; idempotent, re-runnable):
1. **Copy collection:** every `drafts/{id}` → `job_orders/{id}` (same doc
   id). Skip when the target exists and is not older (compare
   `updatedAt ?? createdAt`, and never overwrite a target whose
   `isConverted == true` with a source where it is false) — re-runs must not
   clobber post-cutover edits.
2. **Backfill sales:** every sale with a `draftId` field → set
   `jobOrderId = draftId`, `FieldValue.delete()` the old field. (Reads all
   sales, filters client-side — volume is small post-2026-07-24 reset.)
3. Old `drafts` docs are LEFT IN PLACE as backup; deleting them is a later
   manual cleanup (after phones confirmed on +18).

### firestore.rules / indexes
- Rules: duplicate the current `/drafts/{draftId}` block as
  `/job_orders/{jobOrderId}` (same conditions incl. the conversion-only
  exception). **Both blocks stay live during the transition** (+17 phones
  keep writing `drafts`); removing the old block is a post-rollout cleanup
  the user triggers. Rules tests mirror both blocks during transition.
- Indexes: add 3 `job_orders` copies of the existing `drafts` composite
  indexes (isConverted+updatedAt↓ / isConverted+createdBy+updatedAt↓ /
  isConverted+convertedAt↑); old ones removed at cleanup.
- Dev tooling: `scripts/wipe-transactions.mjs`, `scripts/wipe-db.mjs`,
  `tools/reset-db/lib/config.js` (+tests) get `job_orders` ADDED alongside
  `drafts` (both wiped during transition; `drafts` removed at cleanup).

## Cutover runbook (user-triggered; ALL code ships dark first)

Split-brain hazard: any period where one surface uses `drafts` and the other
uses `job_orders` makes JOs invisible cross-surface, and billing a
pre-migration JO through the OLD collection leaves the new copy unconverted
(double-billing risk). Hence:
1. **Any time (safe):** deploy rules (both blocks) + indexes; wait for
   `job_orders` indexes READY.
2. **Cutover window (shop idle, pause JO creation):**
   a. run migration script (`--yes`),
   b. deploy web hosting,
   c. install +18 APK on ALL phones (it also carries the held +18 manifest:
      race riders, auto-SKU mobile, uppercase inputs, JO notes),
   d. re-run migration script (sweeps stragglers; idempotent),
   e. verify: JO list matches on web + one phone; bill out a test JO; check
      the sale shows `jobOrderId`.
3. **Later cleanup (separate user go):** remove `/drafts` rules block + old
   indexes + `drafts` entries in wipe/reset tooling + converter read-
   fallbacks; optionally delete old `drafts` docs.

## Testing

- Both suites stay green through per-surface rename commits (pure renames —
  behavior pinned by existing 1599 flutter / 541 web tests; test files
  renamed alongside).
- Rules tests: `job_orders` block gets the full mirrored describe block
  (same matrix as `/drafts`).
- Migration script: node tests like `backfill-received-amount`’s (dry-run
  makes no writes; copy skips newer/converted targets; sales backfill moves
  the field; idempotent second run = 0 changes).

## Not in scope
- Renaming `Icons.drafts` (Material icon id), web `/drafts` redirect
  literals, any Do-NOT-rename collision above, historical docs/design
  bundles, memory notes.
