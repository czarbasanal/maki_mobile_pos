# Web POS — Atomic Draft Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert a resumed draft to a sale **inside the sale transaction** (atomic), aborting checkout if the draft was already converted, and delete the old best-effort client-side `markConverted` path.

**Architecture:** Add a pure `draftConversionOutcome` decision helper. In `FirestoreSaleRepository.create()`, when the sale has a `draftId`, read the draft in the transaction and convert/skip/abort accordingly. Remove the now-redundant client `markConverted` call, banner, hook, and repo method.

**Tech Stack:** React + Vite + TypeScript, TanStack Query, Firestore, Vitest. Run all commands from `web_admin/`.

## Global Constraints

- All commands run from `web_admin/`. Verify with `npm run typecheck` (`tsc -b`) and `npm run test`; `npm run build` for UI.
- Vitest resolves the `@/` alias.
- The conversion is **atomic with the sale**: convert/skip/abort all happen inside the existing `create()` `runTransaction`. Reads (counter + draft) precede all writes.
- **Outcomes:** draft missing → `skip` (sale still commits); draft already converted → `abort` (throw, whole sale rolls back); draft exists & not converted → `convert` (`tx.update` with `isConverted/convertedToSaleId/convertedAt`).
- **No `firestore.rules` change** — the transaction (run as the active admin) now also reads + updates a `drafts` doc; the `drafts` rule already allows admin update and any-active-user read.
- Implement **Task 2 before Task 3** — Task 2 adds the transactional conversion (so conversion always works); Task 3 then removes the now-redundant client path. Reversing the order would leave an intermediate where resumed drafts don't convert.
- Do NOT touch: `firestore.rules`, the drafts list / Save / Resume flow, the Sale entity.

---

### Task 1: `draftConversionOutcome` pure helper

**Files:**
- Create: `web_admin/src/domain/sales/draftConversion.ts`
- Test: `web_admin/src/domain/sales/draftConversion.test.ts`

**Interfaces:**
- Produces: `type DraftConversionOutcome = 'convert' | 'skip' | 'abort'`; `draftConversionOutcome(exists: boolean, isConverted: boolean): DraftConversionOutcome`.

- [ ] **Step 1: Write the failing test**

Create `web_admin/src/domain/sales/draftConversion.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { draftConversionOutcome } from './draftConversion';

describe('draftConversionOutcome', () => {
  it('skips when the draft no longer exists (deleted mid-checkout)', () => {
    expect(draftConversionOutcome(false, false)).toBe('skip');
    expect(draftConversionOutcome(false, true)).toBe('skip');
  });
  it('aborts when the draft is already converted (prevents a duplicate sale)', () => {
    expect(draftConversionOutcome(true, true)).toBe('abort');
  });
  it('converts an existing, not-yet-converted draft', () => {
    expect(draftConversionOutcome(true, false)).toBe('convert');
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm run test -- draftConversion`
Expected: FAIL — cannot resolve `./draftConversion`.

- [ ] **Step 3: Create the helper**

Create `web_admin/src/domain/sales/draftConversion.ts`:

```ts
export type DraftConversionOutcome = 'convert' | 'skip' | 'abort';

/** What a sale's transaction should do with its source draft.
 *  - missing draft (deleted mid-checkout) → skip; the sale still commits.
 *  - already converted → abort; the whole sale rolls back (no duplicate sale).
 *  - present & not converted → convert it atomically with the sale. */
export function draftConversionOutcome(
  exists: boolean,
  isConverted: boolean,
): DraftConversionOutcome {
  if (!exists) return 'skip';
  if (isConverted) return 'abort';
  return 'convert';
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `npm run test -- draftConversion`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add web_admin/src/domain/sales/draftConversion.ts web_admin/src/domain/sales/draftConversion.test.ts
git commit -m "feat(web): draftConversionOutcome helper (convert/skip/abort)"
```

---

### Task 2: Convert the draft inside the sale transaction

**Files:**
- Modify: `web_admin/src/data/repositories/FirestoreSaleRepository.ts`

**Interfaces:**
- Consumes: `draftConversionOutcome` (Task 1), `FirestoreCollections.drafts`, the existing `create()` transaction.
- Produces: `create()` now reads the source draft (when `input.draftId` is set), aborts if already converted, and converts it atomically; throws `This draft was already converted to a sale` on abort.

- [ ] **Step 1: Add the import**

In `web_admin/src/data/repositories/FirestoreSaleRepository.ts`, add after the `SaleStatus` import:

```ts
import { draftConversionOutcome } from '@/domain/sales/draftConversion';
```

- [ ] **Step 2: Pre-allocate the draft ref before the transaction**

In `create()`, after the `itemRefs` declaration (just before `await runTransaction(...)`), add:

```ts
    const draftRef = input.draftId
      ? doc(this.db, FirestoreCollections.drafts, input.draftId)
      : null;
```

- [ ] **Step 3: Read the draft + abort guard at the top of the transaction**

Replace the transaction's opening read block:

```ts
    await runTransaction(this.db, async (tx) => {
      // The only read — must precede every write.
      const counterSnap = await tx.get(counterRef);
      const seq =
        (counterSnap.exists() ? (counterSnap.data() as Record<string, number>)[key] ?? 0 : 0) + 1;
      const saleNumber = formatSaleNumber(now, seq);
```

with:

```ts
    await runTransaction(this.db, async (tx) => {
      // Reads first — must precede every write.
      const counterSnap = await tx.get(counterRef);
      const draftSnap = draftRef ? await tx.get(draftRef) : null;

      // A resumed draft converts atomically with the sale; an already-converted
      // draft aborts the whole sale (prevents a duplicate); a deleted draft is
      // skipped so the sale still commits.
      const outcome = draftSnap
        ? draftConversionOutcome(draftSnap.exists(), draftSnap.get('isConverted') === true)
        : 'skip';
      if (outcome === 'abort') {
        throw new Error('This draft was already converted to a sale');
      }

      const seq =
        (counterSnap.exists() ? (counterSnap.data() as Record<string, number>)[key] ?? 0 : 0) + 1;
      const saleNumber = formatSaleNumber(now, seq);
```

- [ ] **Step 4: Write the conversion at the end of the transaction**

Replace the transaction's closing stock-decrement block:

```ts
      tx.set(counterRef, { [key]: seq }, { merge: true });
      // Stock decrement — the products update rule permits ONLY these 4 keys.
      for (const item of input.items) {
        tx.update(doc(this.db, FirestoreCollections.products, item.productId), {
          quantity: increment(-item.quantity),
          updatedAt: serverTimestamp(),
          updatedBy: actorId,
          updatedByName: input.cashierName,
        });
      }
    });
```

with (append the conversion write after the stock loop):

```ts
      tx.set(counterRef, { [key]: seq }, { merge: true });
      // Stock decrement — the products update rule permits ONLY these 4 keys.
      for (const item of input.items) {
        tx.update(doc(this.db, FirestoreCollections.products, item.productId), {
          quantity: increment(-item.quantity),
          updatedAt: serverTimestamp(),
          updatedBy: actorId,
          updatedByName: input.cashierName,
        });
      }
      // Mark the source draft converted, atomically with the sale.
      if (draftRef && outcome === 'convert') {
        tx.update(draftRef, {
          isConverted: true,
          convertedToSaleId: saleRef.id,
          convertedAt: serverTimestamp(),
        });
      }
    });
```

- [ ] **Step 5: Typecheck**

Run: `npm run typecheck`
Expected: clean. (Conversion now happens in the tx; the client `markConverted` call still runs too — harmlessly idempotent — until Task 3 removes it.)

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/data/repositories/FirestoreSaleRepository.ts
git commit -m "feat(web): convert source draft atomically inside the sale transaction (abort if already converted)"
```

---

### Task 3: Remove the dead client-side markConverted path

**Files:**
- Modify: `web_admin/src/presentation/features/pos/PosPage.tsx`
- Modify: `web_admin/src/presentation/hooks/useDraftMutations.ts`
- Modify: `web_admin/src/domain/repositories/DraftRepository.ts`
- Modify: `web_admin/src/data/repositories/FirestoreDraftRepository.ts`

**Interfaces:**
- Consumes: nothing new.
- Produces: removes `useMarkConverted`, `DraftRepository.markConverted`, and `FirestoreDraftRepository.markConverted`; `PosPage` no longer references them.

- [ ] **Step 1: PosPage — drop the markConverted import + usage**

In `web_admin/src/presentation/features/pos/PosPage.tsx`:
- Change `import { useSaveDraft, useMarkConverted } from '@/presentation/hooks/useDraftMutations';` to:

```tsx
import { useSaveDraft } from '@/presentation/hooks/useDraftMutations';
```

- Delete the line `const markConverted = useMarkConverted();`.
- In `onComplete`, delete the post-sale conversion block:

```tsx
      if (draftId) {
        markConverted.mutate({ id: draftId, saleId: sale.id });
      }
```

(Leave the surrounding `setDone(sale.saleNumber);` / `pay.reset();` / `clear();` and the `draftId` passed into `checkout.mutateAsync` unchanged — the sale's `draftId` now drives conversion server-side.)

- Delete the `markConverted.error` banner block:

```tsx
        {markConverted.error ? (
          <p className="rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm text-bodySmall text-warning-dark">
            Sale completed, but its draft couldn’t be marked done — delete it from Drafts to avoid re-selling.
          </p>
        ) : null}
```

- [ ] **Step 2: Remove the useMarkConverted hook**

In `web_admin/src/presentation/hooks/useDraftMutations.ts`, delete the whole `useMarkConverted` export:

```ts
export function useMarkConverted() {
  const repo = useDraftRepo();
  return useMutation<void, Error, { id: string; saleId: string }>({
    mutationFn: ({ id, saleId }) => repo.markConverted(id, saleId),
  });
}
```

- [ ] **Step 3: Remove markConverted from the DraftRepository interface**

In `web_admin/src/domain/repositories/DraftRepository.ts`, delete the line:

```ts
  markConverted(id: string, saleId: string): Promise<void>;
```

- [ ] **Step 4: Remove the Firestore impl**

In `web_admin/src/data/repositories/FirestoreDraftRepository.ts`, delete the whole `markConverted` method:

```ts
  async markConverted(id: string, saleId: string): Promise<void> {
    await updateDoc(doc(this.db, FirestoreCollections.drafts, id), {
      isConverted: true,
      convertedToSaleId: saleId,
      convertedAt: serverTimestamp(),
    });
  }
```

(After this, check the file's imports: `updateDoc`, `doc`, `serverTimestamp` are still used by `update()`, so leave them. Only remove imports the typecheck flags as unused.)

- [ ] **Step 5: Typecheck + build + test**

Run: `npm run typecheck && npm run build && npm run test`
Expected: typecheck clean (no dangling `markConverted`/`useMarkConverted` references); build succeeds; all tests green.

- [ ] **Step 6: Commit**

```bash
git add web_admin/src/presentation/features/pos/PosPage.tsx \
  web_admin/src/presentation/hooks/useDraftMutations.ts \
  web_admin/src/domain/repositories/DraftRepository.ts \
  web_admin/src/data/repositories/FirestoreDraftRepository.ts
git commit -m "refactor(web): drop the dead client-side markConverted path (conversion is now atomic)"
```

---

### Task 4: Verify end-to-end

**Files:** none (verification only).

- [ ] **Step 1: Full typecheck + tests + build**

Run: `npm run typecheck && npm run test && npm run build`
Expected: typecheck clean; all suites green (incl. `draftConversion`); build succeeds.

- [ ] **Step 2: Browser smoke — atomic convert**

`npm run dev`, sign in. From `/pos` save a cart as a draft. Go to `/drafts` → **Resume** → complete the sale. ✅ The draft is gone from `/drafts` (converted) and the sale carries `draftId` (Sale Detail). No "draft couldn't be marked done" banner can appear (it's removed).

- [ ] **Step 3: Browser smoke — abort on already-converted (two tabs)**

Open the app in **two tabs**. In both, go to `/drafts` and **Resume** the same draft. Complete the sale in **tab A**. In **tab B**, complete the sale → ✅ checkout **fails** with "This draft was already converted to a sale" (shown via the existing checkout error), and **no second sale** is created (check Reports → Sales count).

- [ ] **Step 4: Browser smoke — skip on deleted draft**

Resume a draft in tab A. In tab B, **delete** that draft from `/drafts`. Back in tab A, complete the sale → ✅ the sale **still completes** (the deleted draft is skipped, not an error).

- [ ] **Step 5: Browser smoke — non-draft sale unchanged**

Ring a normal cart (never saved/resumed) and complete it → ✅ completes exactly as before.

- [ ] **Step 6: Commit (only if smoke-fix tweaks were needed)**

```bash
git add -A
git commit -m "fix(web): atomic draft-conversion smoke-test fixes"
```

---

## Notes for the implementer

- **Spec:** `docs/superpowers/specs/2026-06-20-web-pos-atomic-draft-conversion-design.md`.
- **Green between tasks:** Task 1 is additive; Task 2 adds the transactional conversion (client path still runs, idempotent); Task 3 removes the dead client path. Each leaves typecheck + tests green.
- **No deploy.** Deployment is a separate, explicitly-authorized step.
```
