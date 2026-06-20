# Web Product Image Upload — Design

**Date:** 2026-06-19
**Surface:** React web admin (`web_admin/`). Mobile already has image upload.
**Status:** Design — approved, pending `writing-plans`.
**Context:** "Inventory polish" slice 2 (slice 1 = `barcodes[]` migration, shipped).

## 1. Problem & intent

The web admin can display a product's `imageUrl` (detail page thumbnail) but
has **no way to set one** — products created/edited on the web never get an
image. This slice adds upload (with a square crop + client-side compression),
replace, and remove, writing to the same Storage path mobile uses.

### Decisions locked in brainstorming
- **Square crop** before upload (user chose parity over resize-only) via a new
  dependency **`react-easy-crop`**.
- **Canvas compress** to a 1024×1024 JPEG at quality ~0.82 — comfortably under
  the existing 2 MB Storage rule; no extra compression dependency.
- **Storage path `products/{productId}/main.jpg`** (mobile parity; overwritten
  on re-upload), `contentType: 'image/jpeg'`, value stored in `imageUrl`.
- **Create-then-upload-then-update** ordering (mobile parity): the product is
  created first (so it has an id), then the image is uploaded, then `imageUrl`
  is written.
- **No `storage.rules` / `firestore.rules` change** — the existing rules already
  permit signed-in image writes `< 2 MB` of `image/.*`; web is admin-only.

## 2. Existing constraints (verified)

- `storage.rules` already governs `products/{productId}/{file=**}`: read =
  signed-in; write = signed-in `&& size < 2*1024*1024 && contentType.matches('image/.*')`.
- `src/infrastructure/firebase/storage.ts` exports a ready `storage` (with
  emulator wiring). No upload code exists yet on the web.
- `Product.imageUrl: string | null` is already on the entity/converter; the
  detail page renders it (`h-16 w-16 object-cover`, so a square image displays
  cleanly). `updateData`'s whitelist already includes `imageUrl`.

## 3. Storage helper — `src/infrastructure/firebase/productImageStorage.ts` (new)

- `uploadProductImage(productId: string, blob: Blob): Promise<string>` —
  `uploadBytes(ref(storage, 'products/${productId}/main.jpg'), blob, {
  contentType: 'image/jpeg' })` then `getDownloadURL(ref)`.
- `deleteProductImage(productId: string): Promise<void>` — `deleteObject(ref)`,
  swallowing the `storage/object-not-found` error (idempotent remove).

## 4. Crop + compress util — `src/core/utils/cropImage.ts` (new)

- `getCroppedBlob(imageSrc: string, area: { x: number; y: number; width: number;
  height: number }): Promise<Blob>` — loads `imageSrc` into an `Image`, draws the
  cropped `area` onto a **1024×1024** `<canvas>`, and resolves
  `canvas.toBlob(..., 'image/jpeg', 0.82)`. Rejects if the blob is null.
- `area` is `react-easy-crop`'s `croppedAreaPixels`. The util is browser-API
  (canvas/Image) — verified by build + manual, not node unit tests.

## 5. Form UI — `InventoryFormPage.tsx`

An **Image** field (new section or within Identity) showing the current
thumbnail and **Upload / Change / Remove** controls:
- Local state: `imageBlob: Blob | null`, `imagePreview: string | null`
  (object URL of the cropped blob), `imageRemoved: boolean` (edit only), and the
  crop modal's `cropSrc: string | null`, `crop`, `zoom`, `croppedAreaPixels`.
- Picking a file (hidden `<input type="file" accept="image/*">`) reads it to a
  data/object URL → opens a **crop modal** (`react-easy-crop`, `aspect={1}`,
  zoom slider, Save/Cancel). Save runs `getCroppedBlob` → sets `imageBlob` +
  `imagePreview`, clears `imageRemoved`, closes the modal.
- Thumbnail precedence: `imagePreview` → (edit & !removed) `target.imageUrl` →
  placeholder. **Remove** clears `imageBlob`/`imagePreview` and sets
  `imageRemoved = true` (edit) so save deletes the stored image.
- Revoke object URLs on replace/unmount to avoid leaks.

## 6. Mutation wiring — `useProductMutations.ts`

- `CreateProductInput` gains `imageBlob?: Blob | null`. `useCreateProduct`:
  create the product (imageUrl null, as today) → if `imageBlob`,
  `uploadProductImage(created.id, imageBlob)` then `repo.update(created.id, {
  imageUrl })`. An upload failure surfaces as the mutation error (the product
  still exists without an image — the user can add it via edit); the existing
  best-effort price-history write is unaffected.
- `UpdateProductInput` gains `image: { kind: 'keep' } | { kind: 'replace'; blob:
  Blob } | { kind: 'remove' }`. In `useUpdateProduct`, before composing the
  patch: `replace` → `uploadProductImage(id, blob)` → `patch.imageUrl = url`;
  `remove` → `deleteProductImage(id)` → `patch.imageUrl = null`; `keep` → leave
  `imageUrl` out of the patch. The rest of the update (sku/barcode claims, price
  history) is unchanged; `imageUrl` flows through `updateData`'s whitelist.
- `InventoryFormPage.doSave` maps its image state to these inputs: add-mode →
  `imageBlob`; edit-mode → `{ kind: 'replace', blob }` when a new blob exists,
  `{ kind: 'remove' }` when `imageRemoved`, else `{ kind: 'keep' }`.

## 7. Testing & rollout

- **No node-unit-testable pure logic** of substance (canvas/Storage/crop are
  browser APIs) — verified by `npm run typecheck` + `npm run build` + manual,
  consistent with prior web UI slices. If a thin pure helper emerges (e.g. an
  image-state→action mapper), unit-test it.
- **Manual smoke (deferred per standing pref; the checklist):** create a product
  with a cropped image (appears on detail/list); change it (new image replaces);
  remove it (thumbnail gone, Storage object deleted); confirm a large source
  photo still succeeds (crop+compress keeps it under 2 MB).
- **Rollout:** `npm install react-easy-crop` (committed to package.json) then
  `cd web_admin && npm run build && firebase deploy --only hosting`. No rules
  change. If `vite build` breaks on the new dep, `npm ci` / `npm rebuild esbuild`
  (known toolchain gotcha).

## 8. Out of scope

- Multiple images per product (still one `main.jpg`).
- Images on the receiving / bulk-receiving create paths (those products get no
  image, as today).
- Any mobile change (already has image upload).
- Reusing the crop modal elsewhere; deferred until a second caller appears.

## 9. Risks

- **New dependency (`react-easy-crop`):** small, popular, but adds bundle weight
  and must pass `vite build`. Mitigated by the toolchain note above.
- **Orphaned Storage object:** if a product is hard-deleted (web only soft-
  deletes, so N/A today) or a create succeeds but the follow-up `imageUrl` write
  fails, the object may linger. Low impact (2 MB cap, overwritten on re-upload).
- **Upload-then-update non-atomicity on create:** create + upload + update are
  three steps; a failure between them leaves a created product without its image
  (recoverable via edit). Acceptable — mirrors mobile.
- **No automated test coverage** for the upload path — manual smoke is the first
  real verification (as noted).
