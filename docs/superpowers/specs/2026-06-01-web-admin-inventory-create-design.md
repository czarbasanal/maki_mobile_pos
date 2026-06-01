# Web Admin — Inventory Slice 3 (Create new product) — Design

**Date:** 2026-06-01
**Status:** Approved (brainstorm complete)
**Context:** Final slice of web inventory CRUD parity. Builds on Slice 1 (browse/detail),
Slice 2a (edit), Slice 2b (stock/deactivate) — all shipped + deployed. Manage Lists
(category/unit dropdowns) shipped.

## 1. Overview

Let an admin **create a new product** at `/inventory/add`. The existing
`InventoryFormPage` (edit-only today) is **generalized to handle both add and edit**,
mirroring `SupplierFormPage`'s dual-mode pattern. This retires the last inventory
placeholder and completes inventory CRUD on the web.

**Admin-only** (the web shell redirects non-admins). `/inventory/add` is already
guarded by `Permission.addProduct`, which admins hold.

## 2. Scope

In:
- Add mode in `InventoryFormPage` (`/inventory/add`): the full create form + save.
- SKU auto-generate toggle (add-mode only) using the existing `generateSku`.
- costCode derived from cost on create; initial price-history ("Created") entry.
- `useCreateProduct` hook; "Add product" entry point on the list.

Out (deferred, per brainstorm decisions):
- **Image upload** — `imageUrl` stays null on create; no image picker/uploader is built
  (web `storage.ts` exposes only the Storage instance, no helper). A later slice.
- **Multiple barcodes** — the web `Product.barcode` is a single nullable string; create
  takes one optional barcode. A `barcodes[]` model migration is a separate slice.
- Firestore **rules** changes — none (admin create already permitted).
- Staff cost-code-only create (mobile lets staff create via a cost CODE) — N/A, web is
  admin-only and enters cost numerically.

## 3. Form generalization (add + edit in one component)

`InventoryFormPage.tsx` keys off the route param: `const { id } = useParams(); const
isEditing = !!id;`.

- **Edit mode** (`id` present): unchanged from Slice 2a — loads via `useProduct(id)`,
  SKU-change confirm + relink, no quantity field.
- **Add mode** (no `id`): renders immediately (no fetch); blank defaults; **no** SKU
  confirm/relink (there is no old SKU); submits via `create()`.

### 3.1 Fields by mode
| Field | Add | Edit |
|---|---|---|
| name, SKU, barcode, cost, price, reorderLevel, unit, category, supplier, notes | ✓ | ✓ |
| **Initial quantity** | ✓ (required, int ≥ 0) | ✗ (Adjust-Stock dialog only) |
| **Auto-generate SKU** toggle | ✓ (default ON) | ✗ |

Dropdowns (unit/category/supplier) and validation are identical to Slice 2a (SKU regex
`^[A-Za-z0-9-]+$` ≤ 50; name required; cost/price ≥ 0 via the blank-guarding `reqNumber`;
quantity/reorder int ≥ 0). Unit defaults to `pcs`.

### 3.2 SKU auto-generate (add mode)
A "Auto-generate SKU" toggle, **default ON**. When ON: the SKU field is read-only,
populated from `generateSku(name)` (the web helper, port of the mobile generator), with a
**Regenerate** button; it re-rolls when the **name field loses focus** (stable UX, no
per-keystroke churn). When OFF: the SKU field is editable (manual entry). On edit the
toggle is absent and SKU follows the Slice 2a rules.

## 4. costCode on create

`createData` requires a non-empty `costCode`. Derive it from the entered cost:
`costCode = encodeCostCode(mapping, cost)` (reusing the Slice 2a `useCostCode`
subscription + `encodeCostCode`). **Block submit** (inline `cost` error) if the cost-code
mapping hasn't loaded yet — a created product must carry a consistent code (same guard
Slice 2a uses on cost change).

## 5. Save path — `useCreateProduct`

New hook in `useProductMutations.ts`:

```ts
useCreateProduct(): useMutation<Product, Error, ProductCreateInput>
```

- Guards `if (!actor) throw 'Not signed in'`.
- Pre-check `if (await repo.skuExists(input.sku)) throw 'A product with this SKU already
  exists'` (no excludeId in add mode) → the form maps this to an inline `sku` error.
- `repo.create(input, actor.id)` (createData stamps createdBy/updatedBy = actorId and
  createdByName/updatedByName = input.createdByName, rebuilds searchKeywords).
- **Best-effort initial price-history:** after create, `recordPriceChange(product.id,
  { price, cost, changedBy: actor.id, reason: 'Initial price' })` (try/catch; the Price
  History view maps `'Initial price'` → **"Created"**).

The `ProductCreateInput` the form builds sets: `isActive: true`; `createdByName` /
`updatedByName` (initially same) = `actor.displayName.trim() || null` (the Slice 2b audit
fix); `baseSku` / `variationNumber` per the **mobile create convention for base (non-variation)
products** — verified against `createData` / `CreateProductUseCase` during planning (either
`baseSku = sku` or `null`; whichever mobile uses, so web- and mobile-created products are
identical and the Slice 2a relink behaves consistently); `imageUrl: null`; supplier id +
denormalized name from the picker; the rest from the form.

On success → navigate to `/inventory`. Mutation errors surface inline (banner +
`sku` duplicate), matching the form's existing error handling.

## 6. Routing + entry point

- `routes.tsx`: replace the `productAdd` placeholder with `<InventoryFormPage />`. The
  route guard already requires `addProduct` (admin passes); React Router ranks static
  `/inventory/add` above `/inventory/:id`.
- `InventoryListPage.tsx`: add an **"Add product"** button in the header (right-aligned,
  mirroring `SuppliersListPage`'s "Add supplier") → `/inventory/add`.

## 7. Testing

- No new pure helpers beyond what exists (`generateSku`, `priceHistoryReason` style logic
  isn't needed here; reason is the constant `'Initial price'`). The SKU generator is
  already unit-tested (`sku.test.ts`).
- Pages verified via `npx tsc --noEmit -p tsconfig.json` + `npm run build` + manual smoke,
  then an **adversarial multi-agent review** of the diff before merge (per the established
  Slice-2 practice — it caught 11 real bugs across 2a/2b that gates missed).

## 8. Files

**Modify:**
- `web_admin/src/presentation/features/inventory/InventoryFormPage.tsx` (add-mode branch +
  initial-quantity field + SKU auto-generate toggle + create path)
- `web_admin/src/presentation/hooks/useProductMutations.ts` (`useCreateProduct`)
- `web_admin/src/presentation/router/routes.tsx` (wire `/inventory/add`)
- `web_admin/src/presentation/features/inventory/InventoryListPage.tsx` ("Add product" button)

**No new files** (the form is generalized in place; the create logic rides existing
`create()`/`recordPriceChange`/`skuExists` repo methods).

## 9. Acceptance criteria

1. An admin clicks "Add product" → fills name (SKU auto-fills, default ON, re-rolls on
   name blur; can switch to manual), cost, price, initial quantity, reorder, unit,
   category, supplier, barcode, notes → Save creates the product; it appears in the list;
   its detail shows the values; its Price History shows a "Created" entry.
2. A duplicate SKU is rejected inline on the SKU field; a blank required number is rejected.
3. costCode is set from the cost (verifiable via the mobile cost-code display); submit is
   blocked until the cost-code mapping has loaded.
4. The `/inventory/add` placeholder is gone; edit mode is unaffected.
5. Gates green: `tsc --noEmit -p tsconfig.json`; `npm run build`; full vitest suite stays
   green (no new failures); adversarial review findings resolved.

## 10. Resolved decisions

- **Generalize** the one `InventoryFormPage` for add + edit (not a separate page).
- **Defer image upload**; **single barcode** (no model migration).
- SKU **auto-generate toggle default ON** (add-mode), re-roll on name blur, manual override.
- costCode **derived** from cost + **mapping-guarded**; initial **"Created"** price-history
  entry (best-effort).
- Initial **quantity** is an add-mode form field; edit still uses the Adjust-Stock dialog.
- `baseSku`/`variationNumber` per the mobile base-product convention (verified in planning);
  `isActive = true`, `imageUrl = null` on create.
