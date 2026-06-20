# Web Product Image Upload — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the web admin set a product image — pick → square-crop → compress → upload to `products/{id}/main.jpg` → store the download URL in `imageUrl` — with replace and remove, mirroring mobile.

**Architecture:** A storage helper + a canvas crop/compress util (browser APIs); the product mutation hooks gain optional image actions (create-then-upload-then-update; replace/remove/keep on edit); the form adds an image field with a `react-easy-crop` modal.

**Tech Stack:** TypeScript / React, `firebase/storage`, `react-easy-crop`, Vite. No node-unit-testable logic (canvas/Storage/crop are browser APIs) — gates are `tsc -b` + `npm run build` + manual.

## Global Constraints

- **Storage path `products/{productId}/main.jpg`**, `contentType: 'image/jpeg'`, overwritten on re-upload (mobile parity). Output = **1024×1024 JPEG, quality 0.82** (well under the existing 2 MB Storage rule).
- **No `storage.rules` / `firestore.rules` change, no backfill.** The rules already allow signed-in `image/.*` writes `< 2 MB`; web is admin-only.
- `imageUrl` already flows through `updateData`'s whitelist and the converter; the detail page already renders it.
- Tested modules under `src/domain/`/`src/core/` may import `@/`; follow each file's existing import style.

---

## Task 1: Dependency + storage helper + crop/compress util

**Files:**
- Modify: `web_admin/package.json` (+ `package-lock.json`) — add `react-easy-crop`
- Create: `web_admin/src/infrastructure/firebase/productImageStorage.ts`
- Create: `web_admin/src/core/utils/cropImage.ts`

**Interfaces:**
- Produces: `uploadProductImage(productId: string, blob: Blob): Promise<string>`, `deleteProductImage(productId: string): Promise<void>`, `getCroppedBlob(imageSrc: string, area: PixelArea): Promise<Blob>` where `PixelArea = { x: number; y: number; width: number; height: number }`.

- [ ] **Step 1: Install the crop dependency**

Run: `cd web_admin && npm install react-easy-crop`
Expected: `react-easy-crop` added to `package.json` dependencies (v5+, which ships its own types and injects its own styles — no CSS import needed).

- [ ] **Step 2: Storage helper**

Create `web_admin/src/infrastructure/firebase/productImageStorage.ts`:
```ts
import { deleteObject, getDownloadURL, ref, uploadBytes } from 'firebase/storage';
import { storage } from './storage';

const imagePath = (productId: string) => `products/${productId}/main.jpg`;

/** Uploads (overwriting) a product's single image and returns its download URL. */
export async function uploadProductImage(productId: string, blob: Blob): Promise<string> {
  const r = ref(storage, imagePath(productId));
  await uploadBytes(r, blob, { contentType: 'image/jpeg' });
  return getDownloadURL(r);
}

/** Deletes a product's image; a no-op when it doesn't exist. */
export async function deleteProductImage(productId: string): Promise<void> {
  try {
    await deleteObject(ref(storage, imagePath(productId)));
  } catch (e) {
    if ((e as { code?: string }).code === 'storage/object-not-found') return;
    throw e;
  }
}
```

- [ ] **Step 3: Crop/compress util**

Create `web_admin/src/core/utils/cropImage.ts`:
```ts
const OUTPUT_SIZE = 1024;
const JPEG_QUALITY = 0.82;

export interface PixelArea {
  x: number;
  y: number;
  width: number;
  height: number;
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.addEventListener('load', () => resolve(img));
    img.addEventListener('error', () => reject(new Error('Could not load the image')));
    img.src = src;
  });
}

/**
 * Draws the cropped `area` of `imageSrc` onto a square OUTPUT_SIZE canvas and
 * returns a compressed JPEG blob (well under the 2 MB Storage limit). `area` is
 * react-easy-crop's `croppedAreaPixels`.
 */
export async function getCroppedBlob(imageSrc: string, area: PixelArea): Promise<Blob> {
  const image = await loadImage(imageSrc);
  const canvas = document.createElement('canvas');
  canvas.width = OUTPUT_SIZE;
  canvas.height = OUTPUT_SIZE;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Canvas is not supported');
  ctx.drawImage(image, area.x, area.y, area.width, area.height, 0, 0, OUTPUT_SIZE, OUTPUT_SIZE);
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error('Could not encode the image'))),
      'image/jpeg',
      JPEG_QUALITY,
    );
  });
}
```

- [ ] **Step 4: Typecheck + build**

Run: `cd web_admin && npm run typecheck && npm run build`
Expected: both pass (the new files compile; the new dep resolves). If `vite build` breaks on the dep, `npm ci` / `npm rebuild esbuild` (known toolchain gotcha).

- [ ] **Step 5: Commit**

```bash
git add web_admin/package.json web_admin/package-lock.json web_admin/src/infrastructure/firebase/productImageStorage.ts web_admin/src/core/utils/cropImage.ts
git commit -m "feat(web): product image storage helper + canvas crop/compress util"
```

---

## Task 2: Hook image wiring (create-then-upload-then-update; replace/remove/keep)

The image inputs are **optional** so this task compiles and the existing form keeps working (it just never sends an image until Task 3).

**Files:**
- Modify: `web_admin/src/presentation/hooks/useProductMutations.ts`

**Interfaces:**
- Consumes: `uploadProductImage`/`deleteProductImage` (Task 1).
- Produces: `CreateProductInput.imageBlob?: Blob | null`; `UpdateProductInput.image?: { kind: 'keep' } | { kind: 'replace'; blob: Blob } | { kind: 'remove' }`.

- [ ] **Step 1: Import the storage helpers**

After the `diffBarcodeClaims` import, add:
```ts
import { uploadProductImage, deleteProductImage } from '@/infrastructure/firebase/productImageStorage';
```

- [ ] **Step 2: Extend `UpdateProductInput`**

In the `UpdateProductInput` interface (line 8), add after `priceChange`:
```ts
  /** Image change to apply before the doc write. Omitted = keep the current image. */
  image?: { kind: 'keep' } | { kind: 'replace'; blob: Blob } | { kind: 'remove' };
```

- [ ] **Step 3: Apply the image action in `useUpdateProduct`**

Change the `mutationFn` destructure to include `image`, and insert the image block right after `fullPatch` is created (before the `skuChanged`/`barcodesChanged` logic):
```ts
    mutationFn: async ({ id, oldSku, oldBarcodes, patch, priceChange, image }) => {
      if (!actor) throw new Error('Not signed in');
      const actorName = actor.displayName.trim() || null;
      const fullPatch: ProductUpdateInput = { ...patch, updatedByName: actorName };
      if (image?.kind === 'replace') {
        fullPatch.imageUrl = await uploadProductImage(id, image.blob);
      } else if (image?.kind === 'remove') {
        await deleteProductImage(id);
        fullPatch.imageUrl = null;
      }
```
(Everything below — the `newSku`/`diffBarcodeClaims` routing, the `priceChange` write, the invalidate — stays exactly as-is. `fullPatch.imageUrl` flows through `updateData`'s whitelist for both the claims path and the plain-update path.)

- [ ] **Step 4: Add `imageBlob` to `CreateProductInput`**

In the `CreateProductInput` interface (line 124), add after `notes`:
```ts
  imageBlob?: Blob | null;
```

- [ ] **Step 5: Upload on create in `useCreateProduct`**

Replace the body from the `actorName` line through the `repo.create(...)` call so the blob is split off and uploaded after create:
```ts
      const actorName = actor.displayName.trim() || null;
      const { imageBlob, ...fields } = input;
      const created = await repo.create(
        {
          ...fields,
          isActive: true,
          createdBy: actor.id,
          updatedBy: actor.id,
          createdByName: actorName,
          updatedByName: actorName,
          baseSku: null,
          variationNumber: null,
          imageUrl: null,
        } as ProductCreateInput,
        actor.id,
      );
      if (imageBlob) {
        const imageUrl = await uploadProductImage(created.id, imageBlob);
        await repo.update(created.id, { imageUrl }, actor.id);
        created.imageUrl = imageUrl;
      }
```
(The existing best-effort `recordPriceChange`, `invalidateQueries`, and `return created` below stay as-is. Splitting `imageBlob` out of `fields` keeps the Blob out of the Firestore write.)

- [ ] **Step 6: Typecheck + tests + build**

Run: `cd web_admin && npm run typecheck && npm run test -- --run && npm run build`
Expected: tsc clean; vitest all pass (135, unchanged); build OK.

- [ ] **Step 7: Commit**

```bash
git add web_admin/src/presentation/hooks/useProductMutations.ts
git commit -m "feat(web): hook image actions — upload on create, replace/remove on edit"
```

---

## Task 3: Form image field + crop modal

**Files:**
- Modify: `web_admin/src/presentation/features/inventory/InventoryFormPage.tsx`

**Interfaces:**
- Consumes: `getCroppedBlob` + `PixelArea` (Task 1), `CreateProductInput.imageBlob` / `UpdateProductInput.image` (Task 2), `react-easy-crop`.

- [ ] **Step 1: Imports**

- Change the React import (line 1) to add `ChangeEvent`:
```ts
import { useEffect, useMemo, useState, type ChangeEvent, type FormEvent, type ReactNode } from 'react';
```
- Add after the `cn` import (line 22):
```ts
import Cropper, { type Area } from 'react-easy-crop';
import { getCroppedBlob } from '@/core/utils/cropImage';
```

- [ ] **Step 2: Image + crop state**

After the `barcodeError` state (line 79), add:
```ts
  const [imageBlob, setImageBlob] = useState<Blob | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageRemoved, setImageRemoved] = useState(false);
  const [cropSrc, setCropSrc] = useState<string | null>(null);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<Area | null>(null);
```

- [ ] **Step 3: Revoke the preview object URL on change/unmount**

After the `reset(...)` effect (the one ending `}, [target, reset]);`), add:
```ts
  useEffect(() => {
    return () => { if (imagePreview) URL.revokeObjectURL(imagePreview); };
  }, [imagePreview]);
```

- [ ] **Step 4: Image handlers**

After `removeBarcode` (line 167-168), add:
```ts
  const onPickFile = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = ''; // allow re-picking the same file
    if (!file) return;
    setCropSrc(URL.createObjectURL(file));
    setCrop({ x: 0, y: 0 });
    setZoom(1);
  };
  const closeCrop = () => {
    if (cropSrc) URL.revokeObjectURL(cropSrc);
    setCropSrc(null);
  };
  const confirmCrop = async () => {
    if (!cropSrc || !croppedAreaPixels) return;
    const blob = await getCroppedBlob(cropSrc, croppedAreaPixels);
    setImageBlob(blob);
    setImagePreview(URL.createObjectURL(blob));
    setImageRemoved(false);
    closeCrop();
  };
  const removeImage = () => {
    setImageBlob(null);
    setImagePreview(null);
    setImageRemoved(true);
  };
  const shownImage = imagePreview ?? (!imageRemoved ? target?.imageUrl ?? null : null);
```

- [ ] **Step 5: Pass image state to the mutations in `doSave`**

- In the edit-path `update.mutateAsync({...})` (line 211), add after `priceChange: …,`:
```ts
          image: imageBlob
            ? { kind: 'replace', blob: imageBlob }
            : imageRemoved
              ? { kind: 'remove' }
              : { kind: 'keep' },
```
- In the add-path `create.mutateAsync({...})` (line 233), add after `notes: blank(values.notes),`:
```ts
        imageBlob,
```

- [ ] **Step 6: Image field in the Identity section**

Inside `<Section title="Identity">` (line 302), after the Barcodes `<Field>` block (the one whose label is `"Barcodes"`), add:
```tsx
          <Field label="Image"
            input={
              <div className="flex items-center gap-tk-md">
                {shownImage ? (
                  <img src={shownImage} alt="" className="h-16 w-16 rounded-md object-cover" />
                ) : (
                  <div className="flex h-16 w-16 items-center justify-center rounded-md border border-dashed border-light-border text-[11px] text-light-text-hint">
                    No image
                  </div>
                )}
                <div className="flex items-center gap-tk-sm">
                  <label className="cursor-pointer rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">
                    {shownImage ? 'Change' : 'Upload'}
                    <input type="file" accept="image/*" className="hidden" onChange={onPickFile} />
                  </label>
                  {shownImage ? (
                    <button type="button" onClick={removeImage}
                      className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text-secondary hover:bg-light-subtle">
                      Remove
                    </button>
                  ) : null}
                </div>
              </div>
            } />
```

- [ ] **Step 7: Crop modal**

After the closing `</Dialog>` of the SKU dialog (the `<Dialog open={skuDialog.open} …>` block near line 451), add a second dialog before the component's outermost closing `</div>`:
```tsx
      <Dialog open={!!cropSrc} onClose={closeCrop} title="Crop image" dismissable>
        <div className="space-y-tk-md">
          <div className="relative h-64 w-full overflow-hidden rounded-md bg-light-subtle">
            {cropSrc ? (
              <Cropper
                image={cropSrc}
                crop={crop}
                zoom={zoom}
                aspect={1}
                onCropChange={setCrop}
                onZoomChange={setZoom}
                onCropComplete={(_area, areaPixels) => setCroppedAreaPixels(areaPixels)}
              />
            ) : null}
          </div>
          <label className="flex items-center gap-tk-sm text-bodySmall text-light-text">
            Zoom
            <input type="range" min={1} max={3} step={0.1} value={zoom}
              onChange={(e) => setZoom(Number(e.target.value))} className="flex-1" />
          </label>
          <div className="flex justify-end gap-tk-sm">
            <button type="button" onClick={closeCrop}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">
              Cancel
            </button>
            <button type="button" onClick={confirmCrop}
              className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark">
              Save
            </button>
          </div>
        </div>
      </Dialog>
```

- [ ] **Step 8: Typecheck + build**

Run: `cd web_admin && npm run typecheck && npm run build`
Expected: both pass.

- [ ] **Step 9: Manual verify (dev server, deferred per standing pref — the smoke checklist)**

`npm run dev`: create a product with a cropped image → appears on detail/list; edit → Change replaces it; edit → Remove clears it (Storage object deleted, thumbnail gone); a large source photo still saves (crop+compress keeps it under 2 MB). Confirm the cropper renders inside the modal (square framing + zoom).

- [ ] **Step 10: Commit**

```bash
git add web_admin/src/presentation/features/inventory/InventoryFormPage.tsx
git commit -m "feat(web): product image field + square-crop modal on the form"
```

---

## Self-review notes (author)

- **Spec coverage:** §3 storage helper → T1 S2; §4 crop util → T1 S3; §5 form UI → T3; §6 hook wiring → T2 (+ doSave mapping T3 S5); §1 dep → T1 S1; §7 testing/rollout → build gates + T3 S9 smoke. Covered.
- **Type consistency:** `getCroppedBlob(imageSrc, area: PixelArea)` (T1) ← `croppedAreaPixels: Area` from react-easy-crop (T3) — `Area` is structurally `{x,y,width,height}` = `PixelArea`, assignable. `UpdateProductInput.image` union (T2 S2) is produced by doSave (T3 S5) and consumed in `useUpdateProduct` (T2 S3). `CreateProductInput.imageBlob` (T2 S4) ← doSave (T3 S5) → split off in `useCreateProduct` (T2 S5).
- **Optionality keeps tasks compiling:** T2 makes `imageBlob?`/`image?` optional, so the unmodified form still type-checks after T2; T3 then supplies them. The Blob is split out of the create spread so it never reaches Firestore.
- **Resource hygiene:** object URLs for the preview (revoked via effect, T3 S3) and the crop source (revoked in `closeCrop`/`confirmCrop`, T3 S4) are released; the file input is reset so re-picking the same file fires `onChange`.
- **No rules/backfill:** existing `storage.rules` already permit the write; `imageUrl` already whitelisted in `updateData` and rendered by the detail page.
