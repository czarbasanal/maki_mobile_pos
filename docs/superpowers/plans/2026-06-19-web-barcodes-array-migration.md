# Web `barcodes[]` Migration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the web admin's product model from a singular `Product.barcode` to a `barcodes: string[]` array (mobile parity), claim every barcode in `product_barcodes`, and give the form a multi-barcode chips UX.

**Architecture:** A field rename (`barcode`→`barcodes`) rippling through entity, converter, repository, hook, receiving, and fixtures; two pure helpers (`parseBarcodes`, `diffBarcodeClaims`) carry the union-read and set-diff logic; the just-shipped singular barcode guard is generalized to claim/free the whole set in the create + update transactions.

**Tech Stack:** TypeScript / React, `firebase/firestore` transactions, Vitest (pure helpers only), Vite.

## Global Constraints

- **`normalizeBarcode(code) = code.trim()`** (case-sensitive) — already in `src/domain/products/sku.ts`; the claim key + the stored `barcodes[]` values are both trimmed, so they coincide.
- **Canonical field `barcodes: string[]`**; the legacy singular `barcode` is read-only (lifted on read) and **deleted on write** (`deleteField()` in the update path).
- **One `product_barcodes/{normalizeBarcode(code)}` claim per element**, fields `{ barcode, productId, claimedBy, claimedAt }` — unchanged shape.
- **No data backfill, no `firestore.rules` change** (0 barcodes in use; the rules already permit per-element claims).
- Web has **no Firestore-mock test infra** — transaction paths are verified by `tsc -b` + `npm run build` + manual; only the pure helpers get unit tests.
- Tested modules under `src/domain/`/`src/data/` may import `@/` (vitest resolves the alias here per existing tests like `sku.test.ts`); follow each file's existing import style.

---

## Task 1: Pure helpers — `parseBarcodes` + `diffBarcodeClaims`

**Files:**
- Create: `web_admin/src/domain/products/barcodes.ts`
- Create: `web_admin/src/domain/products/barcodes.test.ts`

**Interfaces:**
- Consumes: `normalizeBarcode` from `./sku`.
- Produces: `parseBarcodes(raw: { barcodes?: unknown; barcode?: unknown }): string[]`, `diffBarcodeClaims(oldCodes: string[], nextCodes: string[]): { added: string[]; removed: string[] }`.

- [ ] **Step 1: Write the failing tests**

Create `web_admin/src/domain/products/barcodes.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { parseBarcodes, diffBarcodeClaims } from './barcodes';

describe('parseBarcodes', () => {
  it('reads the barcodes array, trimming and dropping empties', () => {
    expect(parseBarcodes({ barcodes: [' 123 ', '', '456'] })).toEqual(['123', '456']);
  });
  it('lifts a legacy singular barcode and unions it (de-duped)', () => {
    expect(parseBarcodes({ barcodes: ['123'], barcode: '123' })).toEqual(['123']);
    expect(parseBarcodes({ barcode: '789' })).toEqual(['789']);
  });
  it('tolerates missing / non-array / non-string inputs', () => {
    expect(parseBarcodes({})).toEqual([]);
    expect(parseBarcodes({ barcodes: 'nope' })).toEqual([]);
    expect(parseBarcodes({ barcodes: [1, null, 'x'] })).toEqual(['x']);
  });
  it('is case-sensitive (barcodes are exact tokens)', () => {
    expect(parseBarcodes({ barcodes: ['abc', 'ABC'] })).toEqual(['abc', 'ABC']);
  });
});

describe('diffBarcodeClaims', () => {
  it('computes added and removed by normalized key', () => {
    expect(diffBarcodeClaims(['1', '2'], ['2', '3'])).toEqual({ added: ['3'], removed: ['1'] });
  });
  it('treats trim-equal codes as unchanged', () => {
    expect(diffBarcodeClaims(['1'], [' 1 '])).toEqual({ added: [], removed: [] });
  });
  it('is empty on a no-op', () => {
    expect(diffBarcodeClaims(['1', '2'], ['1', '2'])).toEqual({ added: [], removed: [] });
  });
  it('is case-sensitive', () => {
    expect(diffBarcodeClaims(['abc'], ['ABC'])).toEqual({ added: ['ABC'], removed: ['abc'] });
  });
});
```

- [ ] **Step 2: Run them — verify they fail**

Run: `cd web_admin && npx vitest run src/domain/products/barcodes.test.ts`
Expected: FAIL — module/exports not found.

- [ ] **Step 3: Implement the helpers**

Create `web_admin/src/domain/products/barcodes.ts`:
```ts
import { normalizeBarcode } from './sku';

/**
 * A product's barcode set, read tolerantly from a Firestore doc: the canonical
 * `barcodes` array UNION a legacy singular `barcode`, each trimmed, empties
 * dropped, de-duped by normalized key (first-seen order preserved).
 */
export function parseBarcodes(raw: { barcodes?: unknown; barcode?: unknown }): string[] {
  const out: string[] = [];
  const seen = new Set<string>();
  const push = (v: unknown) => {
    if (typeof v !== 'string') return;
    const code = normalizeBarcode(v);
    if (code.length === 0 || seen.has(code)) return;
    seen.add(code);
    out.push(code);
  };
  if (Array.isArray(raw.barcodes)) for (const v of raw.barcodes) push(v);
  push(raw.barcode);
  return out;
}

/**
 * Claims to move when a product's barcode set changes, compared by normalized
 * key: `added` = in next not old, `removed` = in old not next. Returned values
 * are normalized keys (== the product_barcodes doc-ids).
 */
export function diffBarcodeClaims(
  oldCodes: string[],
  nextCodes: string[],
): { added: string[]; removed: string[] } {
  const oldKeys = new Set(oldCodes.map(normalizeBarcode).filter((k) => k.length > 0));
  const nextKeys = new Set(nextCodes.map(normalizeBarcode).filter((k) => k.length > 0));
  const added = [...nextKeys].filter((k) => !oldKeys.has(k));
  const removed = [...oldKeys].filter((k) => !nextKeys.has(k));
  return { added, removed };
}
```

- [ ] **Step 4: Run them — verify they pass**

Run: `cd web_admin && npx vitest run src/domain/products/barcodes.test.ts`
Expected: PASS (2 suites).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/products/barcodes.ts web_admin/src/domain/products/barcodes.test.ts
git commit -m "feat(web): parseBarcodes + diffBarcodeClaims helpers for barcodes[] migration"
```

---

## Task 2: Data-model migration + set-claims + hook (single-barcode parity preserved)

This is the atomic rename: it does not compile until every site is updated. The form keeps its single-barcode input here (mapped to a 0/1 array) so behavior is unchanged; Task 3 adds the multi-barcode UX.

**Files:**
- Modify: `web_admin/src/domain/entities/Product.ts`
- Modify: `web_admin/src/data/converters/productConverter.ts`
- Modify: `web_admin/src/data/products/productWrites.ts`
- Modify: `web_admin/src/data/receiving/applyReceivedItems.ts`
- Modify: `web_admin/src/data/receiving/planReceive.ts`
- Modify: `web_admin/src/domain/repositories/ProductRepository.ts`
- Modify: `web_admin/src/data/repositories/FirestoreProductRepository.ts`
- Modify: `web_admin/src/presentation/hooks/useProductMutations.ts`
- Modify: `web_admin/src/presentation/features/inventory/InventoryFormPage.tsx`
- Modify: `web_admin/src/presentation/features/inventory/InventoryDetailPage.tsx`
- Modify (test fixtures, `barcode: null,` → `barcodes: [],`): `web_admin/src/data/receiving/applyReceivedItems.test.ts`, `planReceive.test.ts`, `resolveDraftItems.test.ts`, `web_admin/src/domain/receiving/classifyReceivingRows.test.ts`, `receivableItem.test.ts`, `web_admin/src/domain/reorder/computeReorderSuggestions.test.ts`, `web_admin/src/domain/products/filterProducts.test.ts`

**Interfaces:**
- Consumes: `parseBarcodes`, `diffBarcodeClaims` (Task 1); `normalizeBarcode`, `isClaimableBarcode` (sku.ts); `DuplicateBarcodeError`, `DuplicateSkuError`.
- Produces: `Product.barcodes: string[]`; `updateProductWithClaims(..., barcode: { old: string[]; next: string[] }, ...)`; `CreateProductInput.barcodes`, `UpdateProductInput.oldBarcodes`.

- [ ] **Step 1: Entity field rename**

`Product.ts` — replace line `barcode: string | null;` with:
```ts
  barcodes: string[];
```

- [ ] **Step 2: Converter — read union, write array**

`productConverter.ts`:
- Add import below the existing imports:
```ts
import { parseBarcodes } from '@/domain/products/barcodes';
```
- In `toFirestore`, replace `barcode: product.barcode,` with:
```ts
      barcodes: product.barcodes,
```
- In `fromFirestore`, replace `barcode: d.barcode ?? null,` with:
```ts
      barcodes: parseBarcodes(d),
```

- [ ] **Step 3: `buildProductWrites` writes the array**

`productWrites.ts` — replace `barcode: input.barcode,` with:
```ts
      barcodes: input.barcodes,
```

- [ ] **Step 4: Receiving-created products carry an empty set**

Both files have the field on one line alongside `baseSku`/`variationNumber`:
- `applyReceivedItems.ts:44` — `baseSku: p.baseSku, variationNumber: p.variationNumber, barcode: null,`
- `planReceive.ts:48` — `baseSku: p.baseSku, variationNumber: p.variationNumber, barcode: null,`

In each, change the `barcode: null,` token to `barcodes: [],` (leave `baseSku`/`variationNumber` on that line intact), so the line reads:
```ts
    baseSku: p.baseSku, variationNumber: p.variationNumber, barcodes: [],
```

- [ ] **Step 5: Interface — `updateProductWithClaims` barcode param becomes a set**

`ProductRepository.ts` — replace the barcode parameter in the `updateProductWithClaims` declaration:
```ts
    barcode: { old: string[]; next: string[] },
```
(The `sku`, `actorId`, `actorName` params and `barcodeExists`/`getByBarcode` signatures are unchanged. `ProductCreateInput`/`ProductUpdateInput` inherit `barcodes` automatically via `Omit`/`Partial<Product>`.)

- [ ] **Step 6: Repository imports**

`FirestoreProductRepository.ts` — extend imports:
- Add `deleteField` to the `firebase/firestore` import list.
- Add `diffBarcodeClaims`:
```ts
import { diffBarcodeClaims } from '@/domain/products/barcodes';
```
(`normalizeBarcode`, `isClaimableBarcode`, `DuplicateBarcodeError`, `DuplicateSkuError` are already imported.)

- [ ] **Step 7: `getByBarcode` — array-contains + legacy fallback**

Replace the `getByBarcode` method body:
```ts
  async getByBarcode(barcode: string): Promise<Product | null> {
    const code = normalizeBarcode(barcode);
    const byArray = await getDocs(query(this.col(), where('barcodes', 'array-contains', code)));
    if (!byArray.empty) return byArray.docs[0].data();
    const byLegacy = await getDocs(query(this.col(), where('barcode', '==', code)));
    return byLegacy.empty ? null : byLegacy.docs[0].data();
  }
```

- [ ] **Step 8: `create` claims every barcode**

Replace the `create` method's barcode section. The full method becomes:
```ts
  async create(input: ProductCreateInput, actorId: string): Promise<Product> {
    const productId = newProductId(this.db);
    const { productRef, productData, claimRef, claimData } = buildProductWrites(
      this.db,
      input,
      actorId,
      productId,
    );
    // Unique, normalized, non-empty barcode keys (reuse the diff helper: every
    // code is "added" vs an empty old set).
    const barcodeKeys = diffBarcodeClaims([], input.barcodes).added;
    for (const key of barcodeKeys) {
      if (!isClaimableBarcode(key)) {
        throw new Error(`Invalid barcode "${key}" — it can't contain "/" or be "." or "..".`);
      }
    }
    const barcodeClaimRefs = barcodeKeys.map((k) =>
      doc(this.db, FirestoreCollections.productBarcodes, k),
    );

    await runTransaction(this.db, async (tx) => {
      const claim = await tx.get(claimRef);
      const barcodeClaims = await Promise.all(barcodeClaimRefs.map((r) => tx.get(r)));
      if (claim.exists()) throw new DuplicateSkuError();
      if (barcodeClaims.some((c) => c.exists())) throw new DuplicateBarcodeError();
      tx.set(productRef, productData);
      tx.set(claimRef, claimData);
      barcodeClaimRefs.forEach((r, i) => {
        tx.set(r, {
          barcode: barcodeKeys[i],
          productId,
          claimedBy: actorId,
          claimedAt: serverTimestamp(),
        });
      });
    });

    const created = await this.getById(productId);
    if (!created) throw new Error('Failed to load the created product');
    return created;
  }
```

- [ ] **Step 9: `updateProductWithClaims` moves the SKU claim + diffs the barcode set**

Replace the whole `updateProductWithClaims` method:
```ts
  async updateProductWithClaims(
    id: string,
    input: ProductUpdateInput,
    sku: { old: string; next: string; changed: boolean },
    barcode: { old: string[]; next: string[] },
    actorId: string,
    actorName: string | null,
  ): Promise<void> {
    const children = sku.changed
      ? await getDocs(
          query(
            collection(this.db, FirestoreCollections.products),
            where('baseSku', '==', sku.old),
          ),
        )
      : null;

    const { added, removed } = diffBarcodeClaims(barcode.old, barcode.next);
    for (const key of added) {
      if (!isClaimableBarcode(key)) {
        throw new Error(`Invalid barcode "${key}" — it can't contain "/" or be "." or "..".`);
      }
    }
    const newSkuClaimRef = doc(this.db, FirestoreCollections.productSkus, normalizeSku(sku.next));
    const addedRefs = added.map((k) => doc(this.db, FirestoreCollections.productBarcodes, k));
    const removedRefs = removed.map((k) => doc(this.db, FirestoreCollections.productBarcodes, k));

    await runTransaction(this.db, async (tx) => {
      // Reads first (Firestore requires reads-before-writes).
      const newSkuClaim = sku.changed ? await tx.get(newSkuClaimRef) : null;
      const addedClaims = await Promise.all(addedRefs.map((r) => tx.get(r)));
      if (
        sku.changed &&
        newSkuClaim!.exists() &&
        (newSkuClaim!.data() as { productId?: string }).productId !== id
      ) {
        throw new DuplicateSkuError();
      }
      if (
        addedClaims.some(
          (c) => c.exists() && (c.data() as { productId?: string }).productId !== id,
        )
      ) {
        throw new DuplicateBarcodeError();
      }
      // Writes. updateData writes the new sku + barcodes from input.
      tx.update(
        doc(this.db, FirestoreCollections.products, id),
        this.updateData(input, actorId),
      );
      if (sku.changed) {
        for (const child of children!.docs) {
          tx.update(child.ref, {
            baseSku: sku.next,
            updatedBy: actorId,
            updatedByName: actorName,
            updatedAt: serverTimestamp(),
          });
        }
        tx.delete(doc(this.db, FirestoreCollections.productSkus, normalizeSku(sku.old)));
        tx.set(newSkuClaimRef, {
          sku: sku.next,
          productId: id,
          claimedBy: actorId,
          claimedAt: serverTimestamp(),
        });
      }
      removedRefs.forEach((r) => tx.delete(r));
      addedRefs.forEach((r, i) => {
        tx.set(r, {
          barcode: added[i],
          productId: id,
          claimedBy: actorId,
          claimedAt: serverTimestamp(),
        });
      });
    });
  }
```

- [ ] **Step 10: `updateData` — whitelist `barcodes`, drop legacy `barcode`**

In `updateData`, change the whitelist entry `'barcode'` to `'barcodes'` in the `valueFields` array, then add the legacy-deletion right after the `for (const key of valueFields)` loop:
```ts
    // Drop the legacy singular `barcode` whenever we write the array form.
    if (input.barcodes !== undefined) data.barcode = deleteField();
```

- [ ] **Step 11: Hook — set-based pre-checks + routing**

`useProductMutations.ts`:
- Add import:
```ts
import { diffBarcodeClaims } from '@/domain/products/barcodes';
```
- `UpdateProductInput`: replace `oldBarcode: string | null;` with:
```ts
  oldBarcodes: string[];
```
- `CreateProductInput`: replace `barcode: string | null;` with:
```ts
  barcodes: string[];
```
- Replace the `useUpdateProduct` `mutationFn` body up to (and including) the create/else branch:
```ts
    mutationFn: async ({ id, oldSku, oldBarcodes, patch, priceChange }) => {
      if (!actor) throw new Error('Not signed in');
      const actorName = actor.displayName.trim() || null;
      const fullPatch: ProductUpdateInput = { ...patch, updatedByName: actorName };
      const newSku = (fullPatch.sku ?? oldSku) as string;
      const skuChanged = fullPatch.sku !== undefined && fullPatch.sku !== oldSku;
      const newBarcodes = (fullPatch.barcodes ?? oldBarcodes) as string[];
      const { added, removed } = diffBarcodeClaims(oldBarcodes, newBarcodes);
      const barcodesChanged = added.length > 0 || removed.length > 0;

      if (skuChanged || barcodesChanged) {
        if (skuChanged && (await repo.skuExists(newSku, id))) {
          throw new Error('A product with this SKU already exists');
        }
        for (const code of added) {
          if (await repo.barcodeExists(code, id)) {
            throw new Error('A product with this barcode already exists');
          }
        }
        await repo.updateProductWithClaims(
          id,
          fullPatch,
          { old: oldSku, next: newSku, changed: skuChanged },
          { old: oldBarcodes, next: newBarcodes },
          actor.id,
          actorName,
        );
      } else {
        await repo.update(id, fullPatch, actor.id);
      }
```
- In `useCreateProduct`, replace the singular barcode pre-check:
```ts
      for (const code of input.barcodes) {
        if (await repo.barcodeExists(code)) {
          throw new Error('A product with this barcode already exists');
        }
      }
```
(replacing the existing `if (input.barcode && (await repo.barcodeExists(input.barcode))) { … }` block.)

- [ ] **Step 12: Form — map the single input to a 0/1 array (parity)**

`InventoryFormPage.tsx` (the chips UX lands in Task 3; here just keep it compiling with single-barcode behavior):
- In the `reset({...})` effect, replace `barcode: target.barcode ?? '',` with:
```ts
      barcode: target.barcodes[0] ?? '',
```
- In `doSave`'s edit-path `patch`, replace `barcode: blank(values.barcode),` with:
```ts
        barcodes: blank(values.barcode) ? [blank(values.barcode) as string] : [],
```
- In the edit-path `update.mutateAsync({...})`, replace `oldBarcode: target.barcode,` with:
```ts
          oldBarcodes: target.barcodes,
```
- In the add-path `create.mutateAsync({...})`, replace `barcode: blank(values.barcode),` with:
```ts
        barcodes: blank(values.barcode) ? [blank(values.barcode) as string] : [],
```
(The zod `barcode` field, its `<input>`, the `setError('barcode', …)` mappings, and `defaultValues.barcode` stay as-is — Task 3 replaces them.)

- [ ] **Step 13: Detail page — render the list**

`InventoryDetailPage.tsx` — replace `<Field label="Barcode" value={product.barcode ?? '—'} />` with:
```tsx
          <Field label="Barcodes" value={product.barcodes.length ? product.barcodes.join(', ') : '—'} />
```

- [ ] **Step 14: Test fixtures — `barcode: null,` → `barcodes: [],`**

Run to enumerate, then edit each occurrence:
```bash
cd web_admin && grep -rn "barcode: null" src/
```
In each of these 7 files, replace `barcode: null,` with `barcodes: [],` (each is a `Product` object literal in a fixture):
`src/data/receiving/applyReceivedItems.test.ts`, `src/data/receiving/planReceive.test.ts`, `src/data/receiving/resolveDraftItems.test.ts`, `src/domain/receiving/classifyReceivingRows.test.ts`, `src/domain/receiving/receivableItem.test.ts`, `src/domain/reorder/computeReorderSuggestions.test.ts`, `src/domain/products/filterProducts.test.ts`.

- [ ] **Step 15: Typecheck + tests + build**

Run: `cd web_admin && npm run typecheck && npm run test -- --run && npm run build`
Expected: tsc clean (no remaining `barcode` references on `Product`); all vitest pass (incl. Task 1 helpers); build OK. If tsc flags any leftover `.barcode` site, fix it (the rename must be total).

- [ ] **Step 16: Commit**

```bash
git add web_admin/src
git commit -m "feat(web): migrate Product.barcode -> barcodes[] (model, converter, set-claims, hook)"
```

---

## Task 3: Multi-barcode chips UX on the form

**Files:**
- Modify: `web_admin/src/presentation/features/inventory/InventoryFormPage.tsx`

**Interfaces:**
- Consumes: `CreateProductInput.barcodes` / `UpdateProductInput.oldBarcodes` (Task 2).

- [ ] **Step 1: Remove the single-barcode zod field + default**

In `InventoryFormPage.tsx`:
- Delete the zod schema line `barcode: z.string().trim().optional().or(z.literal('')),`.
- In `defaultValues`, remove `barcode: '',`.
- In the `reset({...})` effect, remove the `barcode: target.barcodes[0] ?? '',` line.

- [ ] **Step 2: Add barcode-list state + handlers**

Add state near the other `useState` hooks (e.g. beside `loadNotice`):
```tsx
  const [barcodes, setBarcodes] = useState<string[]>([]);
  const [barcodeInput, setBarcodeInput] = useState('');
  const [barcodeError, setBarcodeError] = useState<string | null>(null);
```
In the `reset({...})` effect (the `if (!target) return;` one), after `reset({...})`, seed the list:
```tsx
    setBarcodes(target.barcodes);
```
Add the commit/remove helpers below `regenerateSku` (or near the other handlers):
```tsx
  const commitBarcode = (raw: string) => {
    const code = raw.trim();
    if (!code) return;
    if (barcodes.includes(code)) {
      setBarcodeError('Already added');
      return;
    }
    setBarcodes([...barcodes, code]);
    setBarcodeInput('');
    setBarcodeError(null);
  };
  const removeBarcode = (code: string) =>
    setBarcodes((prev) => prev.filter((b) => b !== code));
```

- [ ] **Step 3: Replace the Barcode `<Field>` with chips + add-input**

Replace the existing Barcode field block:
```tsx
          <Field label="Barcode" error={errors.barcode?.message}
            input={<input type="text" className={inputCls(!!errors.barcode)} {...register('barcode')} />} />
```
with:
```tsx
          <Field label="Barcodes" error={barcodeError ?? undefined}
            input={
              <div className="space-y-tk-sm">
                {barcodes.length ? (
                  <div className="flex flex-wrap gap-tk-xs">
                    {barcodes.map((code) => (
                      <span key={code} className="inline-flex items-center gap-tk-xs rounded-full bg-light-subtle px-tk-sm py-[2px] text-[12px] text-light-text">
                        <span className="font-mono">{code}</span>
                        <button type="button" onClick={() => removeBarcode(code)} className="text-light-text-hint hover:text-error" aria-label={`Remove ${code}`}>×</button>
                      </span>
                    ))}
                  </div>
                ) : null}
                <div className="flex items-center gap-tk-sm">
                  <input
                    type="text"
                    value={barcodeInput}
                    onChange={(e) => { setBarcodeInput(e.target.value); if (barcodeError) setBarcodeError(null); }}
                    onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); commitBarcode(barcodeInput); } }}
                    placeholder="Add barcode"
                    className={inputCls(false)}
                  />
                  <button type="button" onClick={() => commitBarcode(barcodeInput)}
                    className="inline-flex shrink-0 items-center rounded-md border border-light-border px-tk-md py-[10px] text-bodySmall text-light-text hover:bg-light-subtle">
                    Add
                  </button>
                </div>
              </div>
            } />
```

- [ ] **Step 4: Build the effective list in `doSave` (auto-commit pending input) + wire create/update**

In `doSave`, at the top (after `setLoadNotice(null);`), compute the effective list:
```tsx
    const pending = barcodeInput.trim();
    const allBarcodes = pending && !barcodes.includes(pending) ? [...barcodes, pending] : barcodes;
```
Then in the edit-path `patch`, replace the Task-2 line:
```tsx
        barcodes: blank(values.barcode) ? [blank(values.barcode) as string] : [],
```
with:
```tsx
        barcodes: allBarcodes,
```
And in the add-path `create.mutateAsync({...})`, replace:
```tsx
        barcodes: blank(values.barcode) ? [blank(values.barcode) as string] : [],
```
with:
```tsx
        barcodes: allBarcodes,
```

- [ ] **Step 5: Map the "barcode already exists" error to the chips field**

In both `catch` blocks in `doSave`, replace `else if (msg.toLowerCase().includes('barcode already exists')) setError('barcode', { type: 'duplicate', message: msg });` with:
```tsx
        else if (msg.toLowerCase().includes('barcode already exists')) setBarcodeError(msg);
```

- [ ] **Step 6: Typecheck + build**

Run: `cd web_admin && npm run typecheck && npm run build`
Expected: both pass. (No `errors.barcode` / `register('barcode')` references remain.)

- [ ] **Step 7: Manual verify (dev server, deferred per standing pref — record as the smoke checklist)**

`npm run dev`: add two barcodes to a new product (both claimed); create another product reusing one barcode (2nd blocked, error on the barcodes field); edit a product to remove a barcode then add that code to another (succeeds — freed); SKU rename still relinks variations.

- [ ] **Step 8: Commit**

```bash
git add web_admin/src/presentation/features/inventory/InventoryFormPage.tsx
git commit -m "feat(web): multi-barcode chips UX on the product form"
```

---

## Self-review notes (author)

- **Spec coverage:** §3 entity/converter → T2 S1–S2; §4 helpers → T1; §5 repo set-claims → T2 S7–S10; §6 hook/form/detail → T2 S11–S13 (parity) + T3 (chips); §7 ripple → T2 S3–S4 + S14 fixtures; §8 testing/rollout → T1 tests + T2 S15 gates + T3 S7 smoke. Covered.
- **Type consistency:** `updateProductWithClaims` barcode param is `{ old: string[]; next: string[] }` in the interface (T2 S5), the impl (T2 S9), and the hook call site (T2 S11). `CreateProductInput.barcodes` / `UpdateProductInput.oldBarcodes` defined T2 S11 and consumed by the form T2 S12 / T3 S4. `diffBarcodeClaims` reused for create-keys (T2 S8), update-diff (T2 S9), and change-detection (T2 S11).
- **Reads-before-writes:** both transactions read the SKU claim + all added/created barcode claims before any write; removed-claim deletes are blind (valid after reads).
- **Legacy handling:** `parseBarcodes` unions legacy on read; `updateData` deletes the legacy field on write; `getByBarcode` keeps the legacy `==` fallback. `toFirestore` is not a write path (no converter-based `setDoc`), so it only renames the field — the functional legacy-delete lives in `updateData`.
- **Atomicity of the rename:** T2 cannot pass `tsc -b` until all sites change; that's by design — it is one cohesive commit. T1 (helpers) and T3 (UI) are the cleanly separable, independently reviewable neighbors.
