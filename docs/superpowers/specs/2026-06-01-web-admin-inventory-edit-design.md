# Web Admin — Inventory Slice 2 (Edit + stock-adjust + deactivate) — Design

**Date:** 2026-06-01
**Status:** Approved (brainstorm complete; grounded by the `slice2-understand` workflow — 46 verified facts + 16 risks)
**Context:** Slice 2 of web inventory CRUD parity. Depends on Slice 1 (list + detail,
shipped) and the Manage Lists feature (category/unit dropdowns, shipped). Slice 3
(create new product) follows.

## 1. Overview

Make products mutable from the web admin: edit attributes, change SKU (with variation
relink), adjust stock, and deactivate/reactivate. Implements the three thrown repo
stubs (`adjustStock`/`setStock`/`deactivate`) and adds `reactivate`.

**The web admin is admin-only** — `ProtectedRoute` redirects any non-admin to
`/access-denied`, so the only actor is an admin. Therefore Slice 2 is **admin-only
full edit**; the mobile staff/cashier edit-tiers and the `restricted-fields` /
firestore-rules tier rejections **do not apply** (an admin satisfies every rule). This
removes a large risk class — we do not build per-role field gating.

## 2. Scope

In:
- Edit existing product via `/inventory/edit/:id` (a new `InventoryFormPage`, edit mode).
- Admin SKU change with confirm + **atomic variation relink** (re-point `baseSku`
  children to the new SKU) + self-excluding uniqueness check.
- Price-history recording on cost/price change (explicit, best-effort).
- Adjust-Stock dialog (Add / Remove / Set To).
- Delete (soft-delete = deactivate) + Reactivate.
- "Show inactive" toggle on the inventory list.
- Implement repo stubs + `reactivate` + `skuExists(excludeId)` + variation-relink batch.

Out (later / non-goals):
- **Create new product** (`/inventory/add`) — Slice 3 (needs costCode capture, SKU
  auto-gen, image upload, multi-barcode). The new form is built edit-first; Slice 3
  generalizes it to add mode.
- **Image upload / multiple barcodes** — Slice 3.
- **Per-role edit tiers** — N/A (web is admin-only).
- **Activity-log writes** — omitted (see §12; matches every other web mutation).
- **`barcodes[]` array model** — web keeps the singular `barcode`; the mobile
  "old SKU appended to barcodes (stays scannable)" side-effect is **dropped** (§5.3).
- Firestore **rules changes** — none (admin write already permits everything here).

## 3. Repository changes (`FirestoreProductRepository` + `ProductRepository`)

All writes stamp `updatedBy=actorId`, `updatedByName` (actor displayName), and
`updatedAt=serverTimestamp()`.

### 3.1 Fix `skuExists` to exclude self (risk: high)
`skuExists(sku)` today returns `(await getBySku(sku)) != null` — on edit it matches the
product's **own** doc and would falsely block every save. Change the contract to
`skuExists(sku: string, excludeId?: string): Promise<boolean>`, implemented like
`FirestoreSupplierRepository.nameExists`: query `where('sku','==',sku)` (limit 2) and
return `docs.some((d) => d.id !== excludeId)`. Existing callers pass no `excludeId`
(unchanged behavior).

### 3.2 Implement the three stubs (currently zero-arg + throw)
- `deactivate(id, actorId)` → `updateDoc(productDoc, { isActive:false, updatedBy, updatedByName, updatedAt })`.
- `setStock(id, quantity, actorId)` → `updateDoc(..., { quantity, updatedBy, updatedByName, updatedAt })`.
- `adjustStock(id, delta, actorId)` → `updateDoc(..., { quantity: increment(delta), updatedBy, updatedByName, updatedAt })` (`increment` from `firebase/firestore`).

`updatedByName` is a new param on these methods (the interface currently passes only
`actorId`; widen the signatures to also accept the actor's display name, or look it up
in the hook — **decision:** the **hook** passes `actorId` and the mutation also sets
`updatedByName` by including it; simplest is to add an `actorName` param to these
methods, mirroring how `create`/`update` already persist `updatedByName`). The spec
adds `actorName: string` to `setStock`/`adjustStock`/`deactivate`/`reactivate`.

### 3.3 Add `reactivate(id, actorId, actorName)`
New interface + impl method → `updateDoc(..., { isActive:true, updatedBy, updatedByName, updatedAt })`. (Web is the **first** surface to expose product reactivation — mobile has the repo method but no UI.)

### 3.4 Variation relink on SKU change (risk: high) — `updateProductWithSku`
`update()` does a single `updateDoc` and cannot relink variation children. Add:

- `countSkuVariations(baseSku: string): Promise<number>` — `getDocs(where('baseSku','==',baseSku))` count, for the confirm dialog. Single-field query, **no composite index**.
- `updateProductWithSku(id, patch, oldSku, newSku, actorId, actorName): Promise<void>` —
  a `writeBatch` that (a) sets the product doc to `{ ...updateData(patch), }` and (b) for
  every doc where `baseSku == oldSku`, sets `baseSku = newSku` (+ `updatedAt`). Commit
  atomically. Ports `product_repository_impl.dart:389-407`.

When the SKU is **unchanged**, the normal `update(id, patch, actorId)` path is used.

### 3.5 `update()` keyword rebuild (risk: medium)
`updateData` rebuilds `searchKeywords` only when `input.name` is present, from
`[sku ?? name, name, category]`. Since the edit form always sends `name`, `sku`, and
`category` together (admin-only, no tier tension), keywords always rebuild from
consistent values. The form **always includes `{name, sku, category}`** in the patch.

## 4. Hooks — `presentation/hooks/useProductMutations.ts`

Modeled on `useSupplierMutations` (`useMutation` + `useProductRepo()` +
`useAuthStore((s)=>s.user)`, throw `'Not signed in'` if no actor). Mutations do **not**
manually invalidate the live `watchAll` list (it auto-updates), but `useUpdateProduct`
**invalidates `['product', id]`** so the cached detail page (`useProduct`) refetches.

- **`useUpdateProduct`** — input `{ id, oldSku, patch, priceChange? }`. Logic:
  1. If `patch.sku && patch.sku !== oldSku`: call `skuExists(patch.sku, id)`; on true →
     throw a duplicate error (form maps to `setError('sku', …)`). Then
     `updateProductWithSku(id, patch, oldSku, patch.sku, actor.id, actor.displayName)`.
     Else `update(id, patch, actor.id /* +name via patch.updatedByName */)`.
  2. If `priceChange` (cost and/or price changed): **best-effort** (try/catch, don't fail
     the save) `recordPriceChange(id, { price, cost, changedBy: actor.id, reason })`.
  3. Invalidate `['product', id]`.
- **`useAdjustStock`** — `{ id, delta }` → `repo.adjustStock(id, delta, actor.id, name)`; invalidate `['product', id]`.
- **`useSetStock`** — `{ id, quantity }` → `repo.setStock(id, quantity, actor.id, name)`; invalidate `['product', id]`.
- **`useDeactivateProduct`** — `id` → `repo.deactivate(id, actor.id, name)`; invalidate `['product', id]`.
- **`useReactivateProduct`** — `id` → `repo.reactivate(id, actor.id, name)`; invalidate `['product', id]`.

## 5. Edit form page — `features/inventory/InventoryFormPage.tsx`

Mirrors `SupplierFormPage` (zod + react-hook-form, `Field`/`Section`/`inputCls`
helpers, edit-mode load via the **existing** `useProduct(editingId)` — NOT a new
`useProductById`). Edit mode only in Slice 2 (`/inventory/edit/:id`); add mode is Slice 3.

### 5.1 Fields (all admin-editable)
Identity: **name** (req), **SKU** (editable; see §5.3), **barcode** (single, optional).
Pricing: **cost** (number ≥ 0), **price** (number ≥ 0). Stock: **reorder level** (int ≥ 0;
**quantity is NOT here** — Adjust-Stock only, §6). Classification: **unit** (dropdown,
required, default `pcs`), **category** (dropdown + "(none)"), **supplier** (dropdown +
"No supplier").

### 5.2 Dropdown sources + orphan handling
- **Category** ← `useActiveCategories(CategoryKind.product)`; "(none)" option; Product.category is a free-text **name** string. If the saved category is now inactive/absent from the active list, still render it as a selectable option (don't drop the saved value).
- **Unit** ← `useActiveCategories(CategoryKind.unit)`; required; empty → `pcs`. Same orphan handling.
- **Supplier** ← `useSuppliers()` filtered to active client-side, **plus** the currently-saved supplier even if now-inactive (mirror mobile's stale-id guard); "No supplier" (null) first. On select, set **both** `supplierId` and the denormalized `supplierName` from the chosen supplier object.

### 5.3 SKU change (admin, full relink)
SKU field is editable. On submit, if `sku !== target.sku`:
1. `await repo.countSkuVariations(target.sku)` → N.
2. Show a **confirm Dialog** ("Change SKU?"): `old → new`, bullets — "Past sales and
   receiving records keep their original SKU"; if N>0 "N linked variation(s) will be
   re-pointed to the new SKU". (We **omit** the mobile "old SKU stays scannable" bullet —
   web `barcode` is singular; we do **not** append the old SKU.) Cancel aborts.
3. On confirm, the mutation runs the `updateProductWithSku` batch (§3.4) after a
   self-excluding `skuExists(newSku, id)` check (duplicate → inline `setError('sku')`).

Validation: SKU regex `^[A-Za-z0-9-]+$`, length 1–50 (mirror mobile `isValidSku`).

### 5.4 Cost change → price history + costCode
- **Price history:** after a successful save, if cost and/or price changed (EPS 0.01),
  best-effort `recordPriceChange` with reason from the pure helper (§7) — exactly
  `'Price update'` / `'Cost update'` / `'Price + cost update'` so the existing
  `derivePriceHistorySource` renders "Manual edit".
- **costCode re-encode (recommended):** the numeric `cost` and the encoded `costCode`
  string are linked on mobile. When `cost` changes, re-encode `costCode =
  encodeCostCode(newCost, mapping)` (the web already has `encodeCostCode` + the
  cost-code mapping via `useCostCode`) and include it in the patch, so mobile's
  cost-code display stays correct. *(If the cost-code mapping is unavailable, fall back
  to leaving `costCode` unchanged and log nothing — cost is still correct.)*

### 5.5 Save + audit
Patch always includes `{ name, sku, category }` (keyword rebuild) plus the other
editable fields + `updatedByName` (actor displayName). On success, navigate to
`/inventory`. Surface `duplicate-sku` as an inline `sku` error; other failures as a
banner. The form also shows an **Audit** section (created/updated by-name + when),
mirroring the detail page.

## 6. Adjust-Stock dialog — `features/inventory/AdjustStockDialog.tsx`

Opened from the detail page. Uses the shared `Dialog` (buttons authored in `children`;
`dismissable={!isPending}`). Three modes via a segmented control: **Add** / **Remove** /
**Set To**.
- Live **new-quantity preview**: add → `current + qty`, remove → `current - qty`, set → `qty`. Colour the preview by status vs `reorderLevel` (≤0 red, ≤ reorder amber, else green).
- Validation: integer-only input; `qty > 0` for Add/Remove; Set allows 0 but not negative; Remove cannot exceed current quantity.
- Dispatch: **Add/Remove** → `useAdjustStock({ id, delta: +qty | -qty })` (Firestore `increment`, concurrency-safe); **Set To** → `useSetStock({ id, quantity: qty })` (absolute; mobile-parity lost-update risk accepted).
- Optional **Reason/Note** field is **omitted** (mobile collects it but never persists it; no field exists to hold it — see §12). No price-history, no activity-log on stock change (parity).

## 7. Pure helpers (tested) — `domain/products/productEdit.ts`

- `priceHistoryReason(oldCost, oldPrice, newCost, newPrice): string | null` — EPS 0.01;
  returns `'Price + cost update'` (both), `'Cost update'` (cost only), `'Price update'`
  (price only), or `null` (neither). **Unit-tested.**
- `resolveStockChange(mode, current, qty): number` — new quantity for `'add'|'remove'|'set'`. **Unit-tested.**

## 8. Detail page actions — `InventoryDetailPage.tsx`

Add an action cluster (header or replacing the price-history link block):
- **Edit** → link to `/inventory/edit/:id` (`generatePath(RoutePaths.productEdit, {id})`).
- **Adjust stock** → opens `AdjustStockDialog`.
- **Delete** (red) when active → confirm Dialog → `useDeactivateProduct`; **Reactivate** when inactive → `useReactivateProduct`. Copy mirrors mobile: title "Delete Product?", body "…hidden from POS and inventory lists. Past sales and receivings that reference it remain intact." (State badge stays "Inactive"; restore action reads "Reactivate".)
- The existing **"View price history"** link is kept, gated on `hasPermission(role, viewProductCost)` (admin) and using the existing `?product=<id>` route (no new route).

## 9. List page — show-inactive toggle (`InventoryListPage.tsx`)

Add `showInactive` state; change the `active` memo to
`showInactive ? (products ?? []) : (products ?? []).filter(p => p.isActive)`. Place a
toggle in the existing filter row. Inactive rows render greyed with an "Inactive" badge.
(Counts/category/table all derive from that memo — no other call sites change.) This is
**net-new** vs mobile (mobile has no product show-inactive); it is the home for Reactivate.

## 10. Routing / guards

- `routes.tsx`: replace the `productEdit` placeholder with `<InventoryFormPage />`
  (`/inventory/add` stays a placeholder — Slice 3). React Router ranks static
  `/inventory/edit/:id` above `/inventory/:id`, so order is safe.
- `routeGuards.ts`: **no change** — `/inventory/edit/` already requires
  `editProduct || editProductLimited`; admins pass.

## 11. Firestore rules

**No change.** Admin update permits all fields; `price_history` write is admin-only
(only admins change price/cost anyway); quantity-only writes also satisfy the rules'
catch-all. `baseSku` relink and `isActive` toggles are covered by the admin update rule.

## 12. Notable decisions (from the adversarial workflow)

- **SKU edit:** full relink (chosen) — self-excluding uniqueness + atomic `baseSku`
  child relink; **drop** the "old SKU stays scannable" bullet (web `barcode` is singular).
- **Quantity:** edited **only** via the Adjust-Stock dialog, never the main form.
- **Activity logging:** **none** — matches every other web mutation; mobile logs only
  `deactivate`, which is a deliberate, acknowledged divergence (audit trails are
  production-affecting per CLAUDE.md — flagged, not added).
- **Reason/Note on stock adjust:** omitted (mobile's is a non-functional stub).
- **Reactivate:** net-new on web (no mobile UI to mirror).
- **costCode:** re-encoded on cost change to keep mobile's display consistent.
- **Price-history link:** existing `?product=` route, gated on `viewProductCost`.

## 13. Testing

- Vitest (node): `priceHistoryReason` (each combo + EPS boundary + no-change → null);
  `resolveStockChange` (add/remove/set incl. clamp). New `skuExists(excludeId)` and the
  relink batch are repo methods (not unit-tested — Firestore) and verified via `tsc` +
  build + manual smoke.
- `tsc --noEmit -p tsconfig.json` + `npm run build` green; full vitest suite green.

## 14. Acceptance criteria

1. An admin edits a product (name/price/cost/category/unit/supplier/barcode/notes); the
   detail + list reflect it live; a cost/price change appends a `price_history` entry
   that the Price History view labels "Manual edit".
2. An admin changes a SKU: a confirm shows old→new + the variation count; on confirm the
   product **and** every `baseSku` child are re-pointed atomically; a duplicate SKU is
   rejected inline; an **unchanged** SKU saves without a false duplicate block.
3. Adjust Stock supports Add/Remove (increment) and Set To (absolute) with a live
   preview and the three validations; the product quantity updates.
4. Delete soft-deletes (isActive=false) with a confirm; the product disappears from the
   default list; "Show inactive" reveals it greyed; Reactivate restores it.
5. Gates green: `priceHistoryReason`/`resolveStockChange` vitest;
   `tsc --noEmit -p tsconfig.json`; `npm run build`; full suite.

## 15. Resolved decisions

- Web is **admin-only** → admin-only full edit; no per-role tiers.
- **Full relink** SKU edit; drop barcode-scannable promise.
- Quantity only via Adjust-Stock; 3-mode dialog (increment for ±, absolute for set).
- Soft-delete labeled **"Delete"** (mobile copy) + net-new **Reactivate**; show-inactive toggle.
- No activity logging; `recordPriceChange` explicit best-effort with exact reason strings.
- Re-encode `costCode` on cost change; reuse the existing `?product=` price-history link.
- Use the **existing** `useProduct(id)` for edit-load (no redundant `useProductById`).
