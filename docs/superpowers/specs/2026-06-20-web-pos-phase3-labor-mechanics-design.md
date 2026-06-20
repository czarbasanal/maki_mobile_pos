# Web POS — Phase 3: Labor + Mechanic — Design

**Date:** 2026-06-20
**Surface:** React web admin (`web_admin/`).
**Status:** Design — approved-in-brainstorm, pending `writing-plans`.
**Epic:** Web POS (full mobile parity, phased). Intent: **remote / back-office
sales** (phone/B2B orders, corrections from the office).

**Phase plan:** 1) cart + cash checkout ✅ · 2) tenders ✅ · **3) labor +
mechanic (this doc)** · 4) drafts · 5) receipt + void.

## 1. Problem & intent

A service job (a motorcycle in the shop) charges **mechanic labor** on top of
the parts in the cart. The web POS is parts-only today. Phase 3 adds, mirroring
the mobile labor+mechanic feature
(`docs/superpowers/specs/2026-05-30-pos-labor-mechanics-design.md`):

1. **Labor lines** — free-form `{description, fee}` charges on the cart/sale,
   plus **one mechanic** assigned to the whole job. Labor is full price (never
   discounted) and reported as a **separate** revenue/profit track.
2. **A configurable Mechanics admin** — a dedicated `Mechanic` entity/repo and a
   `/settings/mechanics` page (name + isActive), feeding a cashier-facing
   mechanic picker.

### Key finding — most of the labor path already exists on web

Phase 1 left the labor/mechanic data + read + report side fully wired; only the
POS **entry** of labor/mechanic and the **mechanic admin** are missing:

- **Sale write:** `FirestoreSaleRepository.create()` already writes
  `laborLines` / `mechanicId` / `mechanicName` (lines 149–151) straight from its
  input; `buildSaleInput` just hardcodes them empty/null today.
- **Serialization:** `saleConverter.toFirestore` already serializes all three.
- **Display:** `SaleDetailPage` already renders the labor-lines list, the labor
  subtotal, and the mechanic name.
- **Reporting:** `summarizeSales` already runs the parallel labor revenue/profit
  track (`laborRevenue` / `laborProfit`); merchandise top-line stays parts-only.
- **Money math:** `saleGrandTotal = salePartsRevenue + saleLaborRevenue`; labor
  is full-price (`saleLaborSubtotal == saleLaborRevenue`) and zero-cost.
- **Rules:** `mechanics` is `read: isValidUser() && isActiveUser()` /
  `write: isAdmin() && isActiveUser()`; the web admin is admin-only, so it can
  read **and** write mechanics with **no `firestore.rules` change**. The sale
  write was already permitted in Phase 1.

**Therefore Phase 3 changes no sale-write, converter, reporting, or rules code.**

### Locked decisions (from brainstorming)

| # | Decision |
|---|----------|
| 1 | Mechanic is **optional always** — nullable even when labor lines exist (mobile parity). |
| 2 | **Labor-only ticket not allowed** — a sale still requires ≥1 part; the existing Complete gate (`lines.length > 0`) already enforces this. |
| 3 | Dedicated `Mechanic` entity/converter/repo on the shared `mechanics` collection (**not** a `CategoryKind`) — mobile parity, clean naming. |
| 4 | Dedicated **`/settings/mechanics`** admin page (not folded into Manage Lists). |
| 5 | Labor + mechanic live in the **`cartStore`** (persistent cart state — Phase-4 drafts will save them), unlike Phase-2's transient payment draft. |
| 6 | A labor line is counted/written **iff its description is non-blank**; blank-description rows are dropped at checkout. |
| 7 | Labor is **never discounted**, **zero cost** — structural (separate code path from item discounts). |
| 8 | Permission: reuse existing **`Permission.manageCategories`** (mobile uses the same for `/settings/mechanics`). |

## 2. Mechanic domain + data (new)

### 2.1 Entity — `src/domain/entities/Mechanic.ts`

Mirror of mobile `MechanicEntity`:

```ts
export interface Mechanic {
  id: string;
  name: string;        // display + match key
  isActive: boolean;   // soft-delete; inactive drops off the picker, stays valid on history
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string | null;
  updatedBy: string | null;
}
```

### 2.2 Converter — `src/data/converters/mechanicConverter.ts`

`FirestoreDataConverter<Mechanic>`: `toFirestore` writes `name`, `isActive`,
audit fields + server timestamps; `fromFirestore` reads them (Timestamp→Date,
missing `updatedAt`→null). Mirrors `categoryConverter`.

### 2.3 Repository — `src/data/repositories/FirestoreMechanicRepository.ts`

Implements a `MechanicRepository` domain interface against
`FirestoreCollections.mechanics` (add the constant if absent — value
`'mechanics'`, matching mobile):

- `watchActive(onData, onError)` — realtime `isActive == true`, **client-side**
  sort by name (no composite index; mirrors the category repos).
- `watchAll(onData, onError)` — realtime all, client-sorted by name.
- `getById(id): Promise<Mechanic | null>`.
- `create(name, actor): Promise<Mechanic>` — `isActive: true`, stamps
  `createdBy: actor.id` (the entity has id-only audit fields, no name-audit) +
  `createdAt` server timestamp.
- `update(id, patch: { name?: string; isActive?: boolean }, actor)` — stamps
  `updatedBy: actor.id` + `updatedAt` server timestamp.

Registered in the DI container as `useMechanicRepo()` alongside the others.

## 3. Mechanics admin page (new)

`/settings/mechanics` — modeled on `ManageListsPage` + `useCategories` /
`useCategoryMutations`:

- **Hooks:** `useMechanics()` (subscribes `watchAll` via the existing
  `useFirestoreSubscription` pattern) and `useMechanicMutations()`
  (`create` / `rename` / `setActive`, invalidating/refetching the subscription).
- **Page:** list of mechanics (active + inactive, inactive visually muted), an
  "Add mechanic" inline input, rename, and deactivate/reactivate buttons —
  reusing the same controls/markup idiom as `ManageListsPage`.
- **Route:** `/settings/mechanics`, gated by `Permission.manageCategories`
  (same dynamic-permission route guard pattern the other settings pages use).
- **Nav:** a "Mechanics" entry on `SettingsPage` next to "Manage lists".

## 4. Cart state + labor math

### 4.1 `cartStore` (extend)

Add to `CartState`:

```ts
laborLines: LaborLine[];
mechanicId: string | null;
mechanicName: string | null;
addLaborLine: () => void;                                   // appends { id: uuid, description: '', fee: 0 }
setLaborLine: (id: string, patch: Partial<Pick<LaborLine, 'description' | 'fee'>>) => void;
removeLaborLine: (id: string) => void;
setMechanic: (id: string | null, name: string | null) => void;
```

`clear()` also resets `laborLines: []`, `mechanicId: null`, `mechanicName: null`.
New labor-line ids via `crypto.randomUUID()` (already used elsewhere in the web
app). Discount-type change does **not** touch labor (labor is never discounted).

### 4.2 Pure helpers — `src/domain/sales/labor.ts` (TDD)

```ts
export function describedLaborLines(lines: LaborLine[]): LaborLine[]; // lines with description.trim() !== ''
export function cartLaborSubtotal(lines: LaborLine[]): number;        // Σ fee of describedLaborLines
```

So a row with a fee but no description is excluded from **both** the total and
the written sale — displayed Labor total always equals what gets written.

### 4.3 `cart.ts` (update)

`cartGrandTotal` gains a `laborLines` argument and includes labor:

```ts
export function cartGrandTotal(
  lines: CartLine[], laborLines: LaborLine[], discountType: DiscountType,
): number;   // = cartPartsRevenue(lines, discountType) + cartLaborSubtotal(laborLines)
```

The internal `asSale(...)` carries `laborLines` so it reuses `saleGrandTotal`
(parts revenue + labor revenue) — single-sourced with the Sale money helpers.
`cartSubtotal` / `cartDiscount` stay parts-only (unchanged signature).

## 5. POS UI (PosPage)

In the right-hand cart panel, between the cart lines and the summary:

- **Labor section** — an "Add labor" button; each labor line renders a
  `description` text input + a `fee` number input (string-backed for decimals,
  like the Phase-2 money inputs) + a remove (trash) button. Mirrors the cart-line
  row idiom. Extracted into a small `LaborSection` component for focus.
- **Mechanic picker** — a `<select>` listing active mechanics (from
  `useMechanics`/`watchActive`) plus a "None" option; on change calls
  `setMechanic(id, name)` (None → `(null, null)`).
- **Summary** — add a **Labor** row; **Total** = `cartGrandTotal(lines,
  laborLines, discountType)` (now labor-inclusive).

The Phase-2 `PaymentSection` is unchanged; PosPage passes it the
labor-inclusive `grandTotal`, so **tenders sum to parts + labor** automatically.

## 6. Checkout wiring

`CheckoutInput` (in `buildSaleInput.ts`) gains:

```ts
laborLines: LaborLine[];
mechanicId: string | null;
mechanicName: string | null;
```

`buildSaleInput` writes `input.laborLines` / `input.mechanicId` /
`input.mechanicName` (dropping today's hardcoded empties). `PosPage.onComplete`
passes `describedLaborLines(laborLines)` + the cart's mechanic from the store; on
success `clear()` already resets them.

## 7. Validation

- **Mechanic optional** — `mechanicId`/`mechanicName` may be null in any state.
- **Labor-only blocked** — `canComplete` already requires `lines.length > 0`;
  unchanged.
- **Labor never discounted / zero cost** — structural; nothing to gate.
- **Tenders** — Phase-2 `usePaymentDraft(grandTotal)` receives the
  labor-inclusive total, so the tender split/validation already covers labor.

## 8. Testing

- **`labor.test.ts`** — `describedLaborLines` (drops blank-description rows,
  keeps described ones incl. fee 0), `cartLaborSubtotal` (sums described fees
  only).
- **`cart.test.ts`** (update) — `cartGrandTotal` includes labor (parts net +
  labor); parts-only helpers unchanged.
- **`mechanicConverter.test.ts`** — round-trip name/isActive/audit; missing
  `updatedAt` → null.
- **`buildSaleInput.test.ts`** (update) — `laborLines` + `mechanicId` +
  `mechanicName` carried through verbatim.
- **Manual browser smoke** — create a mechanic at `/settings/mechanics`; in
  `/pos` add a part + a labor line + pick the mechanic + a tender; complete;
  confirm Sale Detail shows the labor line + labor subtotal + mechanic, and the
  Profit report's labor track moved.

`npm run typecheck && npm run test` green before done.

## 9. Implementation sequencing

One spec, but the plan should run in two ordered slices (the second depends on
the first only for the mechanic read-repo):

- **3a — Mechanic infra + admin:** entity, converter, repo (+DI), `useMechanics`
  / `useMechanicMutations`, `/settings/mechanics` page + nav. Independently
  shippable.
- **3b — POS labor + mechanic:** `labor.ts`, `cartStore` + `cart.ts` changes,
  `LaborSection` + mechanic picker in PosPage, `CheckoutInput` + `buildSaleInput`
  wiring.

## 10. Out of scope

- Drafts (Phase 4 — will persist this cart incl. labor + mechanic).
- Receipt + void (Phase 5).
- Mechanic commission / contact fields (mobile deferred too).
- Any service-vs-sale flag — labor is just an optional cart section.
- Editing labor/mechanic on already-completed sales.
