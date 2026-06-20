# Web POS — Phase 4: Drafts — Design

**Date:** 2026-06-20
**Surface:** React web admin (`web_admin/`).
**Status:** Design — approved-in-brainstorm, pending `writing-plans`.
**Epic:** Web POS (full mobile parity, phased). Intent: **remote / back-office
sales** (phone/B2B orders, corrections from the office).

**Phase plan:** 1) cart + cash checkout ✅ · 2) tenders ✅ · 3) labor + mechanic
✅ · **4) drafts (this doc)** · 5) receipt + void.

## 1. Problem & intent

A **draft** is a held POS order — the single "ongoing job" object (a parked
service ticket, a phone order to finish later). The web POS can build a cart
(parts + discount + labor + mechanic) but cannot hold it: `/drafts` and
`/drafts/:id` are placeholders, and there is no way to save/resume.

Phase 4 adds: **save the cart as a draft**, a **drafts list**, **resume** a draft
back into the cart, and **convert** a resumed draft to a sale on checkout.

### What already exists (and the stale-entity gap)

- **`Draft` entity** exists but is **stale** — it carries `items` +
  `discountType` only, with **no `laborLines` / `mechanicId` / `mechanicName`**,
  while mobile's `draft_entity`/`draft_model` *do* (and the `cartStore` now holds
  them). A held service job would silently lose its labor/mechanic. Phase 4
  extends the entity for parity.
- **`DraftRepository`** is an unimplemented domain *interface*
  (`getById`/`watchAll`/`create`/`update`/`delete`/`markConverted`). No
  `FirestoreDraftRepository`, no `draftConverter`, not in the DI container.
- **`Sale.draftId`** already exists (set when a sale originates from a draft);
  `buildSaleInput` currently hardcodes it `null`.
- **Routing:** `/drafts` is a `commonRoute` and `/drafts/*` has a dynamic allow
  in `routeGuards.ts` → **no `routeGuards` change** (unlike a `/settings/*`
  route). Routes are placeholders to be wired to real pages.
- **Rules:** the shared `drafts` rule is `read: isValidUser() && isActiveUser()`
  / `create: … && createdBy == request.auth.uid` / `update,delete: own || admin`.
  Web admins satisfy all of these → **no `firestore.rules` change** (the create
  path **must** set `createdBy = actor.id`).

### Locked decisions (from brainstorming)

| # | Decision |
|---|----------|
| 1 | **Convert = mark-converted, keep the draft** (mobile parity): `isConverted:true` + `convertedToSaleId` + `convertedAt`; it drops off the open-drafts list but remains as an audit record. |
| 2 | **The cart tracks the active draft** (`draftId`/`draftName`): resume → edit → Save **updates the same** draft (no duplicate); checkout converts it. |
| 3 | **Resume loads into `/pos`** — the POS cart is the editor. `/drafts/:id` stays a placeholder; no separate draft-edit screen (YAGNI). |
| 4 | **Drafts list shows open drafts only** (`isConverted === false`). |
| 5 | **Name required** on save; **empty cart cannot be saved**; **resume confirms** before replacing a non-empty cart. |
| 6 | Items + labor stored **inline** on the draft doc (mobile parity), with field names matching `draft_model` so drafts are cross-surface. |

## 2. Data model

### 2.1 `Draft` entity (extend) — `src/domain/entities/Draft.ts`

Add three fields (mirroring `draft_entity`):

```ts
laborLines: LaborLine[];
mechanicId: string | null;
mechanicName: string | null;
```

(Existing fields unchanged: `id, name, items, discountType, createdBy,
createdByName, createdAt, updatedAt, updatedBy, isConverted, convertedToSaleId,
convertedAt, notes`.)

### 2.2 `draftConverter` — `src/data/converters/draftConverter.ts`

`FirestoreDataConverter<Draft>`, field names matching mobile `draft_model`:

- **`toFirestore`** (reads-only converter; writes go through the repo inline for
  server timestamps) returns `name`, `items` (inline array of item maps **with
  id**), `laborLines` (inline `{id, description, fee}` array), `mechanicId`,
  `mechanicName`, `discountType`, `createdBy`, `createdByName`, `isConverted`,
  `convertedToSaleId`, `notes`, `updatedBy`.
- **`fromFirestore`** parses: `items` via the existing inline item shape
  (`SaleItem` fields), `laborLines` via the same `parseLaborLines` logic the
  `saleConverter` uses (reuse/extract it), `discountType` via
  `discountTypeFromString`, timestamps via `requireDate`/`toDate`, and the
  conversion/audit fields with null-coalescing. Missing `name` → `'Unnamed
  Draft'` (mobile default); missing `laborLines` → `[]`.

### 2.3 `FirestoreDraftRepository` — `src/data/repositories/FirestoreDraftRepository.ts`

Implements the existing `DraftRepository` interface on
`FirestoreCollections.drafts`:

- `getById(id)` → `getDoc` with converter, or `null`.
- `watchAll(cb)` → realtime `onSnapshot` over the collection, client-sorted by
  `createdAt` desc (small collection; no composite index). Returns all drafts;
  the **list page** filters to open.
- `create(draft)` → `addDoc` with `createdAt`/`updatedAt` server timestamps +
  the passed fields (incl. `createdBy`); read back via converter. **Caller must
  pass `createdBy = actor.id`** (rule requirement).
- `update(id, patch, actorId)` → `updateDoc` with `updatedBy: actorId` +
  `updatedAt` server timestamp + the patch fields (items/laborLines/mechanic/
  name/discountType serialized inline).
- `delete(id)` → `deleteDoc`.
- `markConverted(id, saleId)` → `updateDoc` `{ isConverted: true,
  convertedToSaleId: saleId, convertedAt: serverTimestamp() }`.

Register in the DI container: `draftRepo: DraftRepository` +
`useDraftRepo()`.

## 3. Cart store — the active draft

`cartStore` gains:

```ts
draftId: string | null;
draftName: string | null;
loadDraft: (draft: Draft) => void;   // hydrate lines + discountType + laborLines + mechanic + draftId/draftName
```

- `loadDraft(draft)` **replaces** the cart: `lines = draft.items`, `discountType
  = draft.discountType`, `laborLines = draft.laborLines`, `mechanicId/Name =
  draft.mechanicId/Name`, `draftId = draft.id`, `draftName = draft.name`.
- `clear()` additionally resets `draftId: null`, `draftName: null`.
- All other actions (addLine, etc.) leave `draftId`/`draftName` untouched —
  editing a resumed draft keeps it "active" until save/checkout/clear.

## 4. Save as draft (`/pos`)

A **"Save draft"** button beside **Complete**, enabled when `lines.length > 0`.
Clicking opens a small **name dialog** (prefilled with `draftName` when a draft
is active). On confirm, via a `useSaveDraft` mutation:

- Build the draft payload from the store: `name`, `items: lines`, `discountType`,
  `laborLines: describedLaborLines(laborLines)`, `mechanicId`, `mechanicName`,
  `createdBy: actor.id`, `createdByName`.
- If `draftId` is set → `update(draftId, payload, actor.id)`; else →
  `create(payload)`.
- On success → `clear()` (resets the cart **and** the active-draft state) and
  show a brief "Saved to drafts" confirmation.

(Labor is filtered to described lines on save — same rule as checkout, so a
parked draft and its eventual sale agree.)

## 5. Drafts list (`/drafts`)

Replace the placeholder `DraftsPage`:

- `useDrafts()` (subscribes `watchAll`), rendered as a list of **open** drafts
  (`isConverted === false`), each row showing **name · item count · total ·
  mechanic (if any) · created-at**. Total via the existing cart money helpers
  (`cartGrandTotal(items, laborLines, discountType)`).
- Row actions: **Resume** → `loadDraft(draft)` then navigate to `/pos`; if the
  current cart is non-empty, a confirm dialog warns it will be replaced.
  **Delete** → confirm, then `delete(id)`.
- Empty/loading/error states via the existing common components.
- A **"Drafts"** entry already exists in the nav (the route was a placeholder);
  no nav change beyond wiring the real page.

## 6. Convert on checkout

- `CheckoutInput` (in `buildSaleInput.ts`) gains `draftId: string | null`;
  `buildSaleInput` writes it onto the sale (replacing the hardcoded `null`).
- `PosPage.onComplete` passes `draftId` from the store. **After** a successful
  sale, if `draftId` was non-null, call `markConverted(draftId, sale.id)`
  (best-effort: a failure here does not undo the completed sale — log/surface but
  don't block). Then `clear()` resets the active-draft state (it already does).

## 7. Validation & edge cases

- **Name required** — Save disabled until the name is non-blank.
- **Empty cart** — Save button disabled when `lines.length === 0`.
- **Resume over a non-empty cart** — confirm before `loadDraft` replaces it.
- **A resumed draft that was converted/deleted on another device** — `update`/
  `markConverted` may target a missing doc; surface the error, keep the cart.
- Labor/mechanic ride along automatically (already in the store).

## 8. Testing

- **`draftConverter.test.ts`** — round-trip `items` + `laborLines` + `mechanicId`
  /`mechanicName` + `discountType` + conversion/audit fields; missing-`name`
  default; missing-`laborLines` → `[]`.
- **`cartStore.test.ts`** (extend) — `loadDraft` hydrates lines/discount/labor/
  mechanic/draftId/draftName; `clear()` resets draftId/draftName.
- **`buildSaleInput.test.ts`** (extend) — `draftId` carried onto the sale.
- **Manual browser smoke** — build a cart with parts + labor + mechanic →
  **Save draft** (name it) → cart clears → it appears under **/drafts** →
  **Resume** → cart rehydrates (labor + mechanic intact) → edit → **Complete** →
  the draft shows converted (drops off the open list) and the sale carries the
  `draftId`; separately, **Delete** a draft.

`npm run typecheck && npm run test` green before done.

## 9. Implementation sequencing

One spec, planned in three ordered slices:

- **4a — Draft data layer:** entity extend, `draftConverter` (+test),
  `FirestoreDraftRepository` (+DI), `useDrafts` hook.
- **4b — Save + list + delete:** `cartStore` `draftId`/`draftName`/`loadDraft`,
  `useSaveDraft`, the Save-draft button + name dialog on `/pos`, the `/drafts`
  list page with Delete.
- **4c — Resume + convert:** Resume action (loadDraft → `/pos`, confirm-replace),
  `CheckoutInput`/`buildSaleInput` `draftId`, `markConverted` on checkout.

## 10. Out of scope

- Receipt + void (Phase 5).
- A separate draft-edit screen (`/drafts/:id` stays a placeholder).
- Draft expiry / auto-cleanup / converted-draft browsing UI.
- Per-customer or plate-number structured fields (the free-text `name` covers it).
