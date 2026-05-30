# Admin-Editable SKU — Design

**Date:** 2026-05-30
**Status:** Approved (pending spec review)

## Goal

Allow an **admin** to change the SKU of an existing product from the product
edit form, safely and with full awareness of downstream effects. Staff and
cashier remain locked out of SKU edits (unchanged behavior).

Today the SKU field is hard-locked after creation for *everyone*
(`canEditSku = !widget.isEditing` in `product_form_screen.dart`). This was a
deliberate guard because of sale/receiving references and variation links. This
design lifts that lock for admins while handling those references correctly.

## Background: how identity and history work today

The key facts that make this safe (verified in code):

- **Products are identified by a stable Firestore auto-doc-ID** (`product.id`),
  created via `_productsRef.add(...)`. SKU is a separate, mutable field — it is
  **not** the document ID and not a foreign key.
- **Sales and receiving records snapshot the SKU and also store the stable
  `productId`:**
  - `SaleItemEntity` carries `productId` (stable link) plus `sku` documented as
    *"snapshot at time of sale"*, alongside `name`/`unitPrice`/`unitCost`
    snapshots.
  - `ReceivingItemModel` carries `productId` (nullable) plus `sku`/`name`
    snapshots.
- **Search keywords** are regenerated from the SKU on every update
  (`ProductModel.toUpdateMap` → `_generateSearchKeywords`).
- **Variations link child → parent by the parent's SKU string**, stored in the
  child's `baseSku` field. `getSkuVariations(baseSku)` matches
  `baseSku == X OR sku == X`; `getNextVariationNumber` queries
  `baseSku == X`. Variation numbering itself uses the structured
  `variationNumber` field, not SKU-string parsing.
- **Price history** is a subcollection keyed under the product doc id —
  independent of SKU.

### Consequence for "previously logged products"

Changing a SKU **does not rewrite or break historical logs.** Past sales and
receivings keep the SKU they were created with (correct audit behavior) and
still resolve to the live product through `productId`. The only data that
references a product by *SKU string* is **variation links**, which we handle via
cascade (below).

## Decisions (from brainstorming)

1. **Variation handling: cascade.** When a parent's SKU changes, automatically
   re-point every child's `baseSku` to the new SKU so the group stays intact.
2. **Old SKU stays scannable.** On change, append the previous SKU to the
   product's `barcodes[]` so scanning/typing the old code still resolves.
3. **Admin-only.** Staff and cashier cannot change SKU (enforced in form,
   use-case, and Firestore rules).
4. **Confirmation, not password.** Changing the SKU shows a confirmation dialog
   summarizing impact; it is not password-gated (password gating stays reserved
   for cost visibility, void, and cost-code mapping).

## Behavior

### Form (admin, editing an existing product)

- The SKU field is editable for admins on the edit screen. For staff/cashier it
  stays disabled exactly as today.
- The auto-generate toggle remains **create-only**; on admin edit the SKU is a
  plain editable text field (the admin is deliberately setting a value).
- Helper text under the field: *"Changing the SKU keeps past sales & receiving
  history intact and preserves the old code for scanning."*
- Validation:
  - Required (existing).
  - Format via `SkuGenerator.isValidSku` (alphanumeric + hyphen, ≤ 50 chars).
  - Optional inline async uniqueness via the existing
    `productOperationsProvider.skuExists(sku, excludeProductId: id)` for
    immediate feedback. Authoritative uniqueness is enforced server-side in the
    use-case regardless.
- On save, **if and only if the SKU changed**, show a confirmation dialog:
  - `OLD → NEW`
  - "Past sales/receiving records keep their original SKU."
  - "The old SKU stays scannable."
  - When the product has variations: "N linked variation(s) will be re-pointed
    to the new SKU."
  - Cancel aborts the save; Confirm proceeds.

### Data effects on change

- **History:** unchanged (snapshot + `productId` link).
- **Search:** new keywords regenerate automatically.
- **Old SKU:** appended to `barcodes[]` (deduped) so it still scans.
- **Variations:** all `baseSku == OLD` re-pointed to `baseSku == NEW`,
  atomically with the product write. Children keep their own SKUs and
  `variationNumber`.

## Changes by layer

### 1. Form — `lib/presentation/mobile/screens/inventory/product_form_screen.dart`

- `final bool isCreating = !widget.isEditing;`
- `final bool canEditSku = isCreating || userRole == UserRole.admin;`
- Auto-generate toggle (`SwitchListTile`) rendered only when `isCreating`.
- SKU `TextFormField.enabled`:
  `isCreating ? (canEditSku && !_autoGenerateSku) : (userRole == UserRole.admin)`.
- Regenerate suffix button shown only when `isCreating && _autoGenerateSku`.
- Add format validator (required + `SkuGenerator.isValidSku`); optional inline
  async uniqueness using the `skuExists` provider.
- In the admin **update** branch of `_handleSubmit`, add
  `sku: _skuController.text.trim()` to the `copyWith`, and gate the call behind
  the confirmation dialog when `sku` differs from `_existingProduct!.sku`.
- Helper text on the SKU field in edit mode.

### 2. Use-case — `lib/domain/usecases/product/update_product_usecase.dart`

- Treat `sku` as a **full-edit-only** field. In the limited-edit (staff) branch,
  add `sku` to the change-detection list so a staff SKU change returns the
  existing `restricted-fields` failure. (Cashier branch already rejects `sku`.)
- On an admin SKU change (`original.sku != product.sku`):
  - Validate format with `SkuGenerator.isValidSku`; on failure return
    `UseCaseResult.failure(code: 'invalid-sku', ...)`.
  - Enforce uniqueness via `_repository.skuExists(sku, excludeProductId:
    product.id)`; on collision return `UseCaseResult.failure(code:
    'duplicate-sku', ...)`.
  - Append `original.sku` to `product.barcodes` if not already present (dedup),
    so the entity passed to the repo already carries the old code as an alias.
  - Enrich the activity log: action/details record `OLD → NEW` and a relinked
    variation count; metadata includes `oldSku`, `newSku`, `relinkedVariations`.
    Reuse `ActivityType.inventory` (no new enum value).

### 3. Repository — `lib/data/repositories/product_repository_impl.dart`

- `updateProduct` already fetches `prior`. When `prior.sku != product.sku`:
  - Build a `WriteBatch`.
  - Update the product doc with `toUpdateMap(...)`.
  - Query children: `_productsRef.where('baseSku', isEqualTo: prior.sku).get()`.
  - For each child, `batch.update(childRef, {'baseSku': product.sku,
    'updatedAt': serverTimestamp, 'updatedBy': updatedBy, 'updatedByName':
    name?})`.
  - Commit the batch.
- `updateProduct`'s signature is **unchanged** (still returns the updated
  `ProductEntity`). The cascade is a side effect of the same call; the repo does
  not return a count.
- Price-history detection/append is unchanged.

### Variation count for the dialog and log

The relinked count is **not** sourced from the repo write. Instead:

- A small provider exposes a product's variation **children** count, wrapping
  `getSkuVariations(sku)` and excluding the parent itself (children are the docs
  whose `baseSku == sku`).
- The **form** reads it to populate the confirmation dialog ("N linked
  variation(s) will be re-pointed").
- The **use-case** re-derives the same count (one small read of children) to put
  `relinkedVariations` in the activity-log metadata. The slight redundancy (form
  read + use-case read + repo read, all tiny) is acceptable and keeps the
  repository contract stable.

### 4. Firestore rules — `firestore.rules`

- Add `'sku'` to the staff update denylist (currently `['price', 'cost',
  'costCode']`). Cashier branch already lists `sku`. This enforces admin-only
  SKU writes server-side.
- Safe for normal staff edits: `diff().affectedKeys()` only contains keys whose
  values changed, so a staff edit that leaves SKU unchanged does not trip the
  rule even though `toUpdateMap` writes the `sku` field.

## Edge cases & known limits

- **Uniqueness race (check-then-write):** acceptable for this single-store app.
  Not transaction-guarded in v1; documented limitation.
- **Old SKU collides with another product's existing barcode:** low risk (the
  old value was a unique SKU). Dedup within the product; skip the alias add if it
  would collide with another product's barcode.
- **Batch size:** variation counts per product are small, far below Firestore's
  500-write batch cap.
- **Renaming a child variation's own SKU:** safe and needs no cascade — nothing
  references a child by its SKU string; its link to the parent is via
  `baseSku` + `variationNumber`, which are untouched by a SKU edit.

## Testing

- **Use-case** — extend
  `test/domain/usecases/product/update_product_usecase_test.dart`:
  - Admin can change SKU (happy path).
  - Staff SKU change → `restricted-fields` failure.
  - Cashier SKU change → `restricted-fields` failure.
  - Duplicate SKU → `duplicate-sku` failure.
  - Invalid format → `invalid-sku` failure.
  - Old SKU appended to `barcodes` on change.
  - Activity log captures `oldSku`/`newSku`/`relinkedVariations`.
- **Repository** — `test/data/repositories/`:
  - SKU change re-points all `baseSku == old` children to the new SKU.
  - Non-SKU update leaves children untouched and runs no cascade.
  - Childless product SKU change updates cleanly.
- **Rules** — `tools/firestore-rules-test/test/rules.test.js`:
  - Staff SKU change denied.
  - Admin SKU change allowed.

## Out of scope

- Regenerating child SKUs to match the new parent prefix (children keep their
  own SKUs; only the `baseSku` link is updated).
- Bulk SKU editing across multiple products.
- A transactional / enforced-unique SKU index in Firestore.
