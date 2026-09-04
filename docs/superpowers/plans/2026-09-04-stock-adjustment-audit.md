# Stock Adjustment Audit Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every stock adjustment becomes an append-only, attributable movement record written in the same transaction as the quantity change, with a required (configurable) reason — new audit modal on web per the design handoff, parity dialog on mobile, and a managed Adjustment Reasons list on both surfaces.

**Architecture:** New `products/{id}/stock_adjustments` subcollection (append-only, rules-enforced) + `adjustment_reasons` shared-list collection with a per-reason `requiresNote` flag, seeded with six defaults. One Firestore transaction per Apply: re-read on-hand, abort on stale/inactive/negative, atomically write product quantity + the record. UI per `design/maki-pos-stock-adjustment-modal/Stock Adjustment Modal - Implementation Guide.md`.

**Tech Stack:** Flutter + Riverpod (root), React + Vite + TS + Vitest (`web_admin/`), Firestore rules tests (`tools/firestore-rules-test/`).

**Spec:** `docs/superpowers/specs/2026-09-04-stock-adjustment-audit-design.md` (binding). UI authority: `design/maki-pos-stock-adjustment-modal/Stock Adjustment Modal - Implementation Guide.md`.

## Global Constraints

- Branch `feat/stock-adjustment-audit` (exists, spec committed). Commit per task; never push unless asked. Never stage anything under `design/` beyond what is already committed.
- Byte-identical names across surfaces: subcollection `stock_adjustments`, collection `adjustment_reasons`, modes exactly `'add' | 'remove' | 'set'`.
- Adjustment record fields exactly: `mode, quantity, delta, before, after, reasonId, reasonName, note, createdAt, createdBy, createdByName` (note null when empty; quantity always positive; delta signed = after − before).
- Seed reasons (exact names + requiresNote): Delivery/no, Count correction/yes, Damaged/yes, Lost/yes, Returned/no, Transfer/no.
- Access: create = staff+admin; `mode == 'set'` = admin only; cashiers cannot adjust (unchanged); records are NEVER updated or deleted (rules-enforced); parent product must be active.
- Stale guard: the transaction aborts when on-hand ≠ the `expectedOnHand` the dialog displayed; UI reopens with the fresh figure and the typed inputs kept.
- The in-repo Tags feature is the template for every reasons-CRUD layer: `web_admin/src/presentation/features/settings/ProductTagsPage.tsx`, `FirestoreTagRepository.ts`, `useTags.ts`/`useTagMutations.ts`, `lib/presentation/mobile/screens/settings/tag_editor_screen.dart`, `lib/data/models/tag_model.dart`, `lib/presentation/providers/tag_provider.dart`. "Copy X and adapt" always means: read X first, keep its structure byte-faithful, substitute only what the task names.
- No deploys inside tasks — rules/hosting deploys and APK +34 are the user-gated rollout in the final task.
- Gates: `cd tools/firestore-rules-test && npm test`; `flutter analyze && flutter test` (root); `npm run typecheck && npm run test && npm run build` (web_admin/). Heroicons on web, Lucide on mobile.

---

### Task 1: Firestore rules — `stock_adjustments` + `adjustment_reasons`

**Files:**
- Modify: `firestore.rules` (subcollection block inside `match /products/{productId}`, next to `price_history`; new `adjustment_reasons` top-level block next to the other shared lists)
- Test: `tools/firestore-rules-test/test/rules.test.js`

**Interfaces:**
- Produces: rules exactly per the spec's Firestore rules section. `adjustment_reasons` joins the shared-list template BUT with `requiresNote` guarded beside `isActive`.

- [ ] **Step 1: Write the failing tests**

Add `"adjustment_reasons"` to the `LISTS` array in the shared-list describe (the generic loop covers create/rename/isActive/delete). Then add a dedicated describe:

```js
describe("adjustment_reasons requiresNote guard", () => {
  const entry = { name: "Damaged", requiresNote: true, isActive: true };
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().collection("adjustment_reasons").doc("r1").set(entry)
    );
  });
  it("cashier cannot flip requiresNote", async () => {
    await assertFails(
      as("cashier").collection("adjustment_reasons").doc("r1").update({ requiresNote: false })
    );
  });
  it("staff can flip requiresNote", async () => {
    await assertSucceeds(
      as("staff").collection("adjustment_reasons").doc("r1").update({ requiresNote: false })
    );
  });
});

describe("/products/*/stock_adjustments (append-only audit)", () => {
  const adj = (over = {}) => ({
    mode: "add", quantity: 12, delta: 12, before: 100, after: 112,
    reasonId: "r1", reasonName: "Delivery", note: null,
    createdAt: new Date(), createdBy: "staff-1", createdByName: "Staff One",
    ...over,
  });
  const col = (u) => as(u).collection("products").doc("p-1").collection("stock_adjustments");
  // NOTE: /products beforeEach seeds p-1 ACTIVE — reuse it. For the
  // inactive case, seed a second product p-inactive with isActive: false
  // (withSecurityRulesDisabled) inside the test.

  it("staff can create an add adjustment", async () => {
    await assertSucceeds(col("staff").add(adj({ createdBy: "staff-1" })));
  });
  it("admin can create a set adjustment; staff cannot", async () => {
    await assertSucceeds(col("admin").add(adj({ mode: "set", quantity: 90, delta: -10, before: 100, after: 90, createdBy: "admin-1" })));
    await assertFails(col("staff").add(adj({ mode: "set", quantity: 90, delta: -10, before: 100, after: 90, createdBy: "staff-1" })));
  });
  it("cashier cannot create", async () => {
    await assertFails(col("cashier").add(adj({ createdBy: "cashier-1" })));
  });
  it("createdBy must be the caller", async () => {
    await assertFails(col("staff").add(adj({ createdBy: "someone-else" })));
  });
  it("structural: after must equal before + delta and be >= 0", async () => {
    await assertFails(col("staff").add(adj({ after: 999 })));
    await assertFails(col("staff").add(adj({ mode: "remove", quantity: 200, delta: -200, before: 100, after: -100 })));
  });
  it("inactive product blocks create", async () => {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().collection("products").doc("p-inactive").set({ name: "Dead", isActive: false, quantity: 5 })
    );
    await assertFails(
      as("admin").collection("products").doc("p-inactive").collection("stock_adjustments").add(adj({ createdBy: "admin-1" }))
    );
  });
  it("append-only: update and delete fail even for admin", async () => {
    await testEnv.withSecurityRulesDisabled((ctx) =>
      ctx.firestore().collection("products").doc("p-1").collection("stock_adjustments").doc("a1").set(adj())
    );
    await assertFails(col("admin").doc("a1").update({ note: "edited" }));
    await assertFails(col("admin").doc("a1").delete());
  });
  it("staff can read; cashier cannot", async () => {
    await assertSucceeds(col("staff").get());
    await assertFails(col("cashier").get());
  });
});
```

- [ ] **Step 2: Run to verify the new cases fail**

Run: `cd tools/firestore-rules-test && npm test` — expect every new case to FAIL (no rules yet). The suite currently passes 223.

- [ ] **Step 3: Add the rules**

Inside `match /products/{productId}` (after the `price_history` sub-match):

```
      // Append-only stock-adjustment audit records (spec 2026-09-04).
      // Created atomically with the quantity write by adjustStockAudited.
      // NEVER updated or deleted — an erroneous adjustment is superseded
      // by another adjustment.
      match /stock_adjustments/{adjustmentId} {
        allow read: if isStaffOrAdmin() && isActiveUser();
        allow create: if isStaffOrAdmin() && isActiveUser() &&
          // "Set to" can erase a discrepancy without recording its size —
          // admin only. Add/Remove always carry the delta.
          (request.resource.data.mode != 'set' || isAdmin()) &&
          // A deactivated part is out of circulation; reactivate first.
          get(/databases/$(database)/documents/products/$(productId)).data.isActive == true &&
          request.resource.data.after == request.resource.data.before + request.resource.data.delta &&
          request.resource.data.after >= 0 &&
          request.resource.data.createdBy == request.auth.uid;
        allow update: if false;
        allow delete: if false;
      }
```

New top-level block next to the other shared lists:

```
    // ==================== ADJUSTMENT REASONS COLLECTION ====================

    match /adjustment_reasons/{reasonId} {
      // All valid users can read reasons (adjust dialogs on both surfaces)
      allow read: if isValidUser() && isActiveUser();

      // Shared-list grants: any active user may add or rename; only
      // staff/admin may flip isActive OR requiresNote (the note policy is
      // policy, not naming); delete is staff/admin.
      allow create: if isValidUser() && isActiveUser();
      allow update: if isValidUser() && isActiveUser() &&
        (isStaffOrAdmin() ||
          !request.resource.data.diff(resource.data).affectedKeys()
            .hasAny(['isActive', 'requiresNote']));
      allow delete: if isStaffOrAdmin() && isActiveUser();
    }
```

- [ ] **Step 4: Run to green** — `npm test`: all pass (223 + new).

- [ ] **Step 5: Commit**

```bash
git add firestore.rules tools/firestore-rules-test/test/rules.test.js
git commit -m "feat(rules): append-only stock_adjustments audit records + adjustment_reasons list"
```

---

### Task 2: Web — adjustment domain: validity helper + AdjustmentReason entity/converter

**Files:**
- Modify: `web_admin/src/domain/products/resolveStockChange.ts` (add `adjustmentValidity`)
- Create: `web_admin/src/domain/entities/AdjustmentReason.ts`; export from `web_admin/src/domain/entities/index.ts`
- Create: `web_admin/src/domain/adjustments/seedReasons.ts`
- Create: `web_admin/src/data/converters/adjustmentReasonConverter.ts`
- Test: extend `web_admin/src/domain/products/resolveStockChange.test.ts` (create if absent), `web_admin/src/data/converters/adjustmentReasonConverter.test.ts`

**Interfaces:**
- Produces: `AdjustmentReason { id, name, requiresNote, isActive, createdAt, updatedAt, createdBy, updatedBy }`; `adjustmentReasonConverter` (mirror `tagConverter.ts` with `requiresNote: d.requiresNote ?? false` instead of color/description); `SEED_REASONS: ReadonlyArray<{ name: string; requiresNote: boolean }>` (the six, exact order/values from Global Constraints); and:

```ts
export interface AdjustmentDraft {
  mode: StockMode;
  qty: number | null;          // from parseStockQty
  onHand: number;
  reasonId: string | null;
  requiresNote: boolean;       // the picked reason's flag (false when none picked)
  note: string;
}
/** null when the draft can be applied; otherwise the blocking message.
 *  Negative results reuse the guide's copy:
 *  `Removing ${qty} would leave ${after}. Stock cannot go negative.` */
export function adjustmentValidity(d: AdjustmentDraft): string | null;
```

Rules: qty null → 'Enter a quantity'; add/remove qty ≤ 0 → 'Quantity must be greater than 0'; resulting `after < 0` → the guide's sentence; no reasonId → 'Pick a reason'; requiresNote && note.trim()==='' → 'A note is required for this reason'.

- [ ] **Step 1: Failing tests** — real cases for every rule above plus a fully-valid draft returning null, and converter tests mirroring `tagConverter.test.ts` (full read, defaults: missing requiresNote → false, missing isActive → true).
- [ ] **Step 2: RED** — `npx vitest run` the two test files.
- [ ] **Step 3: Implement** (converter is a byte-faithful adaptation of `tagConverter.ts`; `seedReasons.ts` exports only the constant with a comment pointing at the spec table).
- [ ] **Step 4: GREEN + `npm run typecheck`.**
- [ ] **Step 5: Commit** — `feat(web): adjustment validity + AdjustmentReason entity/converter/seeds`

---

### Task 3: Web — AdjustmentReasonRepository + DI

**Files:**
- Create: `web_admin/src/domain/repositories/AdjustmentReasonRepository.ts`
- Create: `web_admin/src/data/repositories/FirestoreAdjustmentReasonRepository.ts`
- Modify: `web_admin/src/infrastructure/firebase/collections.ts` (`adjustmentReasons: 'adjustment_reasons',`)
- Modify: `web_admin/src/infrastructure/di/container.tsx` (all four touchpoints, mirror `tagRepo`)
- Test: `web_admin/src/data/repositories/FirestoreAdjustmentReasonRepository.test.ts`

**Interfaces:**
- Produces: `AdjustmentReasonRepository { watchAll(cb, opts?): Unsubscribe; create({name, requiresNote?}, actorId): Promise<AdjustmentReason>; update(id, {name?, requiresNote?, isActive?}, actorId): Promise<void>; delete(id): Promise<void>; nameExists(name): Promise<boolean>; seedDefaults(actorId): Promise<void> }`; `useAdjustmentReasonRepo()`.
- `seedDefaults`: one `writeBatch` creating the six SEED_REASONS docs with full audit fields — callers only invoke it when the watched list is empty (first-run auto-seed) or from the editor's "Seed defaults" action; it does NOT check emptiness itself (both callers already know).

- [ ] **Step 1: Failing test** — copy the `FirestoreTagRepository.test.ts` fake-SDK template; cases: create writes into `adjustment_reasons` with `requiresNote` defaulted false + audit fields; delete by id; seedDefaults stages exactly 6 `set`s in one batch (fake `writeBatch` capturing `set` calls + one `commit`).
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement** — byte-faithful adaptation of `FirestoreTagRepository.ts` (color/description → requiresNote), plus:

```ts
  async seedDefaults(actorId: string): Promise<void> {
    const batch = writeBatch(this.db);
    for (const seed of SEED_REASONS) {
      batch.set(doc(collection(this.db, FirestoreCollections.adjustmentReasons)), {
        name: seed.name,
        requiresNote: seed.requiresNote,
        isActive: true,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        createdBy: actorId,
        updatedBy: actorId,
      });
    }
    await batch.commit();
  }
```

- [ ] **Step 4: GREEN + typecheck.** — [ ] **Step 5: Commit** — `feat(web): adjustment_reasons repository + DI wiring`

---

### Task 4: Web — reason hooks + AdjustmentReasonsPage + routes

**Files:**
- Create: `web_admin/src/presentation/hooks/useAdjustmentReasons.ts`, `useAdjustmentReasonMutations.ts`
- Create: `web_admin/src/presentation/features/settings/AdjustmentReasonsPage.tsx`
- Modify: `routePaths.ts` (`adjustmentReasons: '/settings/adjustment-reasons',`), `routeGuards.ts` (`Permission.editLists`), `routes.tsx` (handle title `Adjustment reasons`, subtitle `Why stock was corrected — shown in the adjust-stock dialog.`), `SettingsPage.tsx` (row under Product tags, icon `ClipboardDocumentListIcon`, gated `editLists`)
- Test: `web_admin/src/presentation/features/settings/AdjustmentReasonsPage.test.tsx`

**Interfaces:**
- Produces: `useAdjustmentReasons({includeInactive?})` / `useActiveAdjustmentReasons()`; `useCreateAdjustmentReason` / `useUpdateAdjustmentReason` / `useDeleteAdjustmentReason` / `useSeedAdjustmentReasons` (activity log entityType `'adjustment_reason'`).

- [ ] **Step 1: Failing page test** — copy the `ProductTagsPage.test.tsx` harness (tagRepo → adjustmentReasonRepo). Cases: lists reasons with a "Note required" chip on flagged rows; create with the note-required checkbox unticked → `create` called with `{name, requiresNote: false}`; cashier sees no Deactivate/Delete AND no note-required toggle on edit; staff sees all three; empty list shows a "Seed defaults" button that calls `seedDefaults`.
- [ ] **Step 2: RED.**
- [ ] **Step 3: Implement** — hooks mirror `useTags.ts`/`useTagMutations.ts`. Page mirrors `ProductTagsPage.tsx`: color swatches → a labeled checkbox `Note required` in the dialog (visible to all on create, but on EDIT only rendered for `canManage` since rules guard the flag; row shows a small neutral chip `Note required` when set; description line dropped). Empty state renders the Seed-defaults button (any editLists holder — rules allow creates).
- [ ] **Step 4: GREEN + typecheck + `npx vitest run src/presentation/features/settings/`.**
- [ ] **Step 5: Commit** — `feat(web): Adjustment Reasons settings page at /settings/adjustment-reasons`

---

### Task 5: Web — `adjustStockAudited` transaction + hook

**Files:**
- Modify: `web_admin/src/infrastructure/firebase/collections.ts` (`Subcollections.stockAdjustments: 'stock_adjustments',`)
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts`, `web_admin/src/data/repositories/FirestoreProductRepository.ts`
- Create: `web_admin/src/domain/products/adjustmentErrors.ts`
- Modify: `web_admin/src/presentation/hooks/useProductMutations.ts` (add `useApplyStockAdjustment`; leave `useAdjustStock`/`useSetStock` in place — POS/receiving do not use them, only the dialog did; they are removed in Task 6 when the dialog stops calling them)
- Test: `web_admin/src/data/repositories/FirestoreProductRepository.adjustAudited.test.ts`

**Interfaces:**
- Produces:

```ts
// adjustmentErrors.ts
export class StaleOnHandError extends Error {
  constructor(public readonly currentOnHand: number) { super('stale-on-hand'); }
}
export class ProductInactiveError extends Error { constructor() { super('product-inactive'); } }
export class NegativeResultError extends Error { constructor() { super('negative-result'); } }

// ProductRepository
export interface StockAdjustmentInput {
  mode: StockMode; quantity: number; expectedOnHand: number;
  reasonId: string; reasonName: string; note: string | null;
}
adjustStockAudited(productId: string, input: StockAdjustmentInput, actorId: string, actorName: string | null): Promise<{ before: number; after: number; delta: number }>;
```

- Transaction body (spec steps verbatim): `runTransaction` → `tx.get(productRef)`; throw `ProductInactiveError` when `!data.isActive`; throw `StaleOnHandError(data.quantity)` when `data.quantity !== input.expectedOnHand`; compute after via `resolveStockChange`; throw `NegativeResultError` when `after < 0`; `tx.update(productRef, { quantity: after, updatedAt: serverTimestamp(), updatedBy: actorId, ...(actorName ? { updatedByName: actorName } : {}) })`; `tx.set(doc(collection(productRef, Subcollections.stockAdjustments)), { mode, quantity, delta, before, after, reasonId, reasonName, note, createdAt: serverTimestamp(), createdBy: actorId, createdByName: actorName })`.
- `useApplyStockAdjustment()`: mutation `{ id, productName, sku, input }` → repo call, then activity log `ActivityType.stockAdjustment` with `action: 'Adjusted stock for ${productName}'`, `details: '${before} → ${after} (${delta >= 0 ? '+' : ''}${delta}) · ${reasonName}${note ? ' · ' + note : ''}'`. Do NOT catch `StaleOnHandError` here — the dialog handles it.

- [ ] **Step 1: Failing test** — fake `runTransaction` executing the callback against a stubbed `tx` (get → product snapshot; capture `update`/`set` payloads): asserts the four abort paths throw the right error types (incl. stale carrying `currentOnHand`), and the happy path writes the exact product-key set and the exact record field set.
- [ ] **Step 2: RED.** — [ ] **Step 3: Implement.** — [ ] **Step 4: GREEN + typecheck.**
- [ ] **Step 5: Commit** — `feat(web): transactional adjustStockAudited with stale-count guard + audit record`

---

### Task 6: Web — rebuild AdjustStockDialog per the handoff

**Files:**
- Modify: `web_admin/src/presentation/features/inventory/AdjustStockDialog.tsx` (full rebuild — read the current file AND the handoff guide §2–3 first)
- Modify: `web_admin/src/presentation/features/inventory/ProductModal.tsx` (call site: pass a close-both callback; toast copy `Stock adjusted`, description `` `${delta >= 0 ? '+' : ''}${delta} → ${after} ${product.unit}` ``)
- Modify: `web_admin/src/presentation/hooks/useProductMutations.ts` (delete now-unused `useAdjustStock`/`useSetStock` and their tests' usages)
- Test: rewrite `web_admin/src/presentation/features/inventory/ProductModal.adjustStock.test.tsx`

**Interfaces:**
- Consumes: `useActiveAdjustmentReasons`, `useSeedAdjustmentReasons`, `useApplyStockAdjustment`, `adjustmentValidity`, `parseStockQty`, `resolveStockChange`, `StaleOnHandError`.
- Behavior contract (each is a test target): preview strip `ON HAND → NEW QUANTITY` + signed delta chip, `—` until qty typed, red when negative; three mode chips, `Set to` rendered only for admins (`Permission.editProduct`), selecting it relabels the field `Counted quantity`; −/+ steppers (− floors at 0), digits-only input (`replace(/[^0-9]/g,'')`), unit as static text; reason chips required — on first open with an empty reason list, call `seedDefaults` once and render from the stream; note optional unless the picked reason's `requiresNote` (then amber border + label loses `(optional)` BEFORE submit); footer `Recorded against ${displayName} · today` + Cancel + `Apply adjustment` at 45% opacity until `adjustmentValidity` returns null; Enter applies when valid; full state reset on every open (`useEffect` on `open`); on apply success → reset, close both modals, toast; on `StaleOnHandError` → stay open, swap in `error.currentOnHand` as the new on-hand base, KEEP mode/qty/reason/note, show `Someone else moved this stock — on hand is now N. Review and apply again.`
- The dialog owns an `onHand` state seeded from `product.quantity` on open (that is the `expectedOnHand` it sends) so the stale-retry flow has a mutable base.

- [ ] **Step 1: Failing tests** — rewrite `ProductModal.adjustStock.test.tsx` (keep its harness): validity gating (Apply disabled until qty+reason+note-when-required), note-required cue appears when picking a flagged reason, staff sees no `Set to` chip / admin does, apply calls `adjustStockAudited` with the exact input incl. `expectedOnHand`, stale error keeps inputs and shows the fresh figure, seed called when reasons stream is empty. Override `adjustmentReasonRepo` + `productRepo.adjustStockAudited` in the harness.
- [ ] **Step 2: RED.** — [ ] **Step 3: Implement** (Dialog shell stays `Dialog`; visual tokens follow the existing page vocabulary, the guide's px values where they map cleanly).
- [ ] **Step 4: Full web gate:** `npm run typecheck && npm run test && npm run build` — everything green, including deleting dead `useAdjustStock`/`useSetStock` fallout.
- [ ] **Step 5: Commit** — `feat(web): audit-grade adjust-stock dialog — preview strip, required reason, stale-count retry`

---

### Task 7: Mobile — AdjustmentReasonEntity/Model

**Files:**
- Create: `lib/domain/entities/adjustment_reason_entity.dart`, `lib/data/models/adjustment_reason_model.dart`; export from both barrels
- Test: `test/data/models/adjustment_reason_model_test.dart`

**Interfaces:**
- Produces: `AdjustmentReasonEntity { id, name, requiresNote (bool, default false), isActive, createdAt, updatedAt?, createdBy?, updatedBy? }` + copyWith + empty(); `AdjustmentReasonModel` mirroring `tag_model.dart` byte-faithfully (color/description → `requiresNote`, `fromMap` default `map['requiresNote'] as bool? ?? false`).

- [ ] Steps: failing model test (mirror `tag_model_test.dart`: fromMap full + legacy defaults + toMap + toCreateMap stamps) → RED → implement → `flutter test test/data/models/adjustment_reason_model_test.dart` + targeted analyze → commit `feat(mobile): AdjustmentReasonEntity + model`.

---

### Task 8: Mobile — reason repository + providers

**Files:**
- Create: `lib/domain/repositories/adjustment_reason_repository.dart`, `lib/data/repositories/adjustment_reason_repository_impl.dart`, `lib/presentation/providers/adjustment_reason_provider.dart` (+ barrel export in `providers.dart`)
- Modify: `lib/core/constants/firestore_collections.dart` (`adjustmentReasons = 'adjustment_reasons'`; also `stockAdjustments = 'stock_adjustments'` under SUBCOLLECTIONS for Task 10)
- Test: `test/presentation/providers/adjustment_reason_provider_test.dart`

**Interfaces:**
- Produces: repository mirroring `tag_repository.dart` (`watchActive/watchAll/getById/create/update/setActive/delete/nameExists`) plus `Future<void> seedDefaults(String createdBy)` — a `WriteBatch` creating the six seeds (constant `kSeedAdjustmentReasons` list of `({String name, bool requiresNote})` records in the repository file, values from Global Constraints); providers mirroring `tag_provider.dart` (`adjustmentReasonRepositoryProvider`, `activeAdjustmentReasonsProvider`, `allAdjustmentReasonsProvider`, `AdjustmentReasonOperationsNotifier` + provider, with an added `Future<bool> seedDefaults()` op).

- [ ] Steps: failing notifier test (mirror `tag_provider_test.dart`'s recording-fake pattern; cases: create routes with actor id asserting `createdBy`; seedDefaults op calls the repo with the actor) → RED → implement (impl byte-faithful to `tag_repository_impl.dart` + the batch) → `flutter test <file> && flutter analyze` → commit `feat(mobile): adjustment_reasons repository + providers`.

---

### Task 9: Mobile — Adjustment Reasons editor + routing

**Files:**
- Create: `lib/presentation/mobile/screens/settings/adjustment_reason_editor_screen.dart`
- Modify: `lib/config/router/route_names.dart` (`adjustmentReasons` name + path `/settings/adjustment-reasons`), `app_routes.dart` (GoRoute after `tags`), `route_guards.dart` (`Permission.editLists`), `settings_screen.dart` (tile after Product Tags: icon `LucideIcons.clipboardList`, title `Adjustment Reasons`, subtitle `Why stock was corrected`)
- Test: `test/presentation/mobile/screens/settings/adjustment_reason_editor_screen_test.dart`

**Interfaces:**
- Consumes: providers (Task 8), `SettingsCrudRow` (its `subtitle` param shows `Note required` on flagged rows), the Tags editor as the structural template.
- Dialog fields: Name (same validator), a `SwitchListTile` `Note required` — on CREATE visible to everyone; on EDIT only for `manageCategories` holders (rules parity); Active switch as in the tags dialog. Empty state's `Add` FAB stays; the AppBar overflow gains `Seed default reasons` (mirror the category editor's seed action) calling the notifier's `seedDefaults`.

- [ ] Steps: failing widget test (mirror `tag_editor_screen_test.dart`: lists reasons with `Note required` subtitle; cashier hides archive/delete; create dialog saves `requiresNote` from the switch via a recording fake notifier; seed action visible) → RED → SettingsCrudRow needs NO changes (subtitle exists) → implement screen + wiring → `flutter test test/presentation/mobile/screens/settings/ && flutter analyze` → commit `feat(mobile): Adjustment Reasons editor at /settings/adjustment-reasons`.

---

### Task 10: Mobile — pure adjustment helper + transactional repo method

**Files:**
- Create: `lib/core/utils/stock_adjustment.dart`
- Modify: `lib/domain/repositories/product_repository.dart`, `lib/data/repositories/product_repository_impl.dart`
- Modify: `lib/core/errors/exceptions.dart` (three exception types)
- Test: `test/core/utils/stock_adjustment_test.dart`

**Interfaces:**
- Produces (pure, mirrors web Task 2 exactly — same messages):

```dart
enum AdjustmentMode { add, remove, set }
class AdjustmentResult { final int before, after, delta; }
AdjustmentResult resolveAdjustment(AdjustmentMode mode, int onHand, int qty);
String? adjustmentValidity({required AdjustmentMode mode, required int? qty,
  required int onHand, required String? reasonId, required bool requiresNote,
  required String note});
```

- Exceptions: `StaleOnHandException(currentOnHand)`, `ProductInactiveException`, `NegativeResultException` (extend the file's base `AppException` pattern — read neighbors first).
- Repository:

```dart
Future<AdjustmentResult> adjustStockAudited({
  required String productId,
  required AdjustmentMode mode,
  required int quantity,
  required int expectedOnHand,
  required String reasonId,
  required String reasonName,
  String? note,
  required String updatedBy,
  String? updatedByName,
});
```

Impl: `_firestore.runTransaction` — read product, throw the three exceptions per the spec's numbered steps, `tx.update` product `{quantity, updatedAt: serverTimestamp, updatedBy, if(updatedByName!=null) updatedByName}`, `tx.set` a new doc in `_productsRef.doc(id).collection(FirestoreCollections.stockAdjustments)` with the exact record field set (mode as `mode.name`). Mode string must serialize `'add'|'remove'|'set'` — `AdjustmentMode.set.name == 'set'` ✓.

- [ ] Steps: failing pure-helper tests (each validity rule incl. the guide's negative-copy sentence, resolve math for all three modes) → RED → implement helper + exceptions + repo method (transaction body is thin glue over the tested helper; its abort logic is covered by Task 1's rules tests + Task 12's dialog tests with a recording fake — note this in the report) → `flutter test test/core/utils/stock_adjustment_test.dart && flutter analyze` → commit `feat(mobile): resolve/validity helpers + transactional adjustStockAudited`.

---

### Task 11: Mobile — activity logger reason support

**Files:**
- Modify: `lib/services/activity_logger.dart` — read `logStockAdjustment`'s current signature first; extend it with `required String reasonName, String? note` and fold them into the details string (`'$old → $new ($signedDelta) · $reasonName'` + `' · $note'` when non-empty). Update ALL call sites the grep finds (`grep -rn "logStockAdjustment" lib/ test/`).
- Test: extend the existing activity-logger test if one covers this method (`grep -rn "logStockAdjustment" test/`), else the dialog test in Task 12 covers it.

- [ ] Steps: adapt → `flutter analyze && flutter test` (full — call-site fallout) → commit `feat(mobile): stock-adjustment log entries carry reason + note`.

---

### Task 12: Mobile — rebuild StockAdjustmentDialog

**Files:**
- Modify: `lib/presentation/mobile/widgets/inventory/stock_adjustment_dialog.dart` (full rebuild — read the current file first; keep `StockAdjustmentDialog.show` entry contract and the AppBottomSheet shell)
- Test: rewrite `test/presentation/mobile/widgets/inventory/stock_adjustment_dialog_test.dart`

**Interfaces:**
- Consumes: `activeAdjustmentReasonsProvider` + ops `seedDefaults` (auto-seed once when the stream emits empty), `resolveAdjustment`/`adjustmentValidity` (Task 10), `adjustStockAudited`, `logStockAdjustment` (Task 11), `currentUserProvider`.
- Behavior contract (mirrors web Task 6): preview strip (current AppCard row upgraded: `On hand → New quantity` + signed delta chip, red when negative); mode as three choice chips with `Set to` only for admins (`ref.currentUser` role) and the label switching to `Counted quantity`; −/+ stepper buttons flanking the digits-only quantity field, unit shown after it; required reason chip wrap; note field with the required-cue when the picked reason demands it; footer text `Recorded against <displayName>`; Apply disabled until `adjustmentValidity` is null; on `StaleOnHandException` → keep inputs, rebase the displayed on-hand to `e.currentOnHand`, show the same copy as web; on success → pop with `true`, success snackbar `Stock adjusted · +12 → 90 pcs`; full state is per-open (the widget is constructed fresh per `show`, which already guarantees reset).

- [ ] Steps: failing widget tests (fake repo recording `adjustStockAudited` args incl. `expectedOnHand`; staff sees no Set chip / admin does; Apply gating incl. note-required; stale exception path rebases and keeps qty; reason auto-seed fires on empty stream) → RED → implement → `flutter test test/presentation/mobile/widgets/inventory/ && flutter analyze` → commit `feat(mobile): audit-grade stock adjustment dialog`.

---

### Task 13: Mobile suite green + old-path retirement check

**Files:** possibly none.

- [ ] **Step 1:** `grep -rn "updateStock\|setStock" lib/ --include=*.dart` — confirm the ONLY remaining callers are non-dialog flows (sale deduction, receiving, POS). The dialog must no longer reference them. If dead code remains (e.g. `productOperationsProvider.updateStock` now unused), remove it and its tests.
- [ ] **Step 2:** Full gate: `flutter analyze && flutter test` — clean/green.
- [ ] **Step 3:** Commit (only if Step 1 removed something) — `chore(mobile): retire dialog-only stock write paths`.

---

### Task 14: Final verification, review, rollout handoff

- [ ] **Step 1:** All three suites end-to-end (rules / flutter / web incl. build) — paste outputs.
- [ ] **Step 2:** `/code-review` the branch diff; apply/triage findings. Then `/verify`-style walk: web dev server — adjust a product's stock (reason required, note cue, preview strip), check the `stock_adjustments` doc in the emulator or console copy.
- [ ] **Step 3 (user-gated rollout):** show the firestore.rules diff → on OK `firebase deploy --only firestore:rules` (IPv4 env workaround); web hosting deploy on OK; mobile rides APK +34 — do NOT build it here.
- [ ] **Step 4:** finishing-a-development-branch (merge target: main).
