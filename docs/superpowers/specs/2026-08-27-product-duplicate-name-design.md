# Product duplicate-name detection + variations that carry their own price

**Date:** 2026-08-27
**Status:** approved design, pending implementation plan

## Why

Cost variations exist and are well built — max+1 allocation, retry on race, a
one-centavo tolerance so rounding never spawns a phantom. They have also
**never once been used in production**. A scan of all 1,625 products found
zero `-N` variation SKUs. The only dashed SKU in the catalog, `17210-KZR`, is
a manufacturer part number.

Meanwhile **59 products across 29 groups (3.6% of the catalog) are accidental
same-name duplicates**, every one of them with unrelated SKUs:

```
00020152  vs  00020153                 "BELT BANDO SKYDRIVE SPORT 115I"
00220052  vs  00220058                 "TIRE TL MAXXIS MAV6 46P 90/90-14"
00200048  vs  00200052  vs  00200051   "YAMALUBE AT BLUE CORE 10W-40 MB 1L"
```

Consecutive sequences inside one category are the signature of the same part
being entered twice via auto-SKU, minutes apart.

The cause is that **variations trigger only on a SKU collision**:

- Web form: `offerVariation()` runs only after a create is rejected as a
  duplicate SKU.
- Receiving: `classifyReceivingRows` matches on a `bySku` map; a GENERATE row
  is returned `status: 'new'` unconditionally.

In the normal flow the SKU auto-generates, so there is no collision, so no
variation is ever offered. Nothing anywhere consults name or category.
Products have no name-uniqueness guard at all, though suppliers, mechanics and
shop fees each have `nameExists`.

Second, smaller defect: a variation **cannot carry its own selling price**.
`buildVariationInput` sets `price: existing.price` and `VariationOptions` has
no price field. The web dialog does disclose this ("the price you typed will
not be saved"), so it is honest rather than silent — but there is no one-step
way to record a batch that sells at a different SRP.

## Decisions

| Question | Decision |
|---|---|
| What counts as the same product | Word-order-insensitive name + same category |
| What happens on a duplicate | Stop and offer a choice; nothing saved until chosen |
| What a variation keeps from the form | Price and cost only |
| Scope | Web form, mobile form, and receiving (as a row status) |
| Receiving variation price | **Unchanged — keeps inheriting the base price entirely** |

## Design

### 1. Shared name key

New pure helper, mirrored in Dart and TypeScript the way `displaySku` and
`normalizeSkuQuery` already are, with a test asserting both agree:

```
productNameKey(name)      // lowercase, trim, collapse whitespace,
                          // split on spaces, SORT tokens, rejoin
productDuplicateKey(name, category)  // `${productNameKey(name)}|${category.toLowerCase().trim()}`
```

Punctuation stays inside tokens — it is meaningful in this catalog
(`90/90-14`, `428-120l`). Sorting tokens is what lets
`CHAIN GLOBAL 428-120L` match `GLOBAL CHAIN 428-120L`.

Measured against the live catalog: exact matching finds 29 groups,
word-order matching finds 37.

**Accepted risk:** in a parts catalog, token sorting can equate genuinely
different items (`BOLT M6 NUT` vs `NUT M6 BOLT`). The dialog is a choice, not
a block, so a false positive costs one extra click and never loses data.

### 2. Two lookup paths, one helper

- **Forms** need a targeted lookup, so products gain a stored `nameKey`
  field, queried `where('nameKey','==',key)` limit 1. Written on create and
  on rename, on both surfaces.
- **Receiving** already loads every active product into
  `classifyReceivingRows`, so it matches in memory. No stored field needed.

`nameKey` needs **no `firestore.rules` change**: product `create` is not
key-validated, and the staff-update guard forbids only
`sku/price/cost/costCode/sellingOptions`, so a staff rename still passes.

A backfill script writes `nameKey` to the existing 1,625 products, dry-run
first. Its report doubles as the inventory of the 29 existing duplicate
groups.

### 3. Form flow (web + mobile)

On save, before create: compute the key and look it up. If a match exists,
stop and show a dialog naming the existing product, its SKU, cost and price:

- **Make it a variation** → allocate `<base>-N` with the typed cost, cost code
  and **price**
- **Save as a separate product** → proceed with the normal create
- **Cancel** → back to the form, nothing written

The existing SKU-collision path is untouched; this is a second, earlier gate.

### 4. Variation carries its own price

- Web: `VariationOptions` gains `price`; `buildVariationInput` uses
  `opts.price` in place of `existing.price`.
- Mobile: `createVariation` gains an **optional** `newPrice`, defaulting to
  inherit.

The optional default is load-bearing. Mobile's `createVariation` is shared by
the mobile form **and** mobile receiving
(`receiving_repository_impl.dart:298`); a required parameter would have
silently changed receiving's behaviour, which this design explicitly keeps.

Web receiving needs no change at all — `planReceive` and
`applyReceivedItems` build their own product input and never call
`buildVariationInput`.

### 5. Receiving row status

`ReceivingRowStatus` gains `'duplicate-name'`, for a GENERATE row whose
name+category matches an active product. The preview row shows the matched
product and a per-row choice defaulting to **Make variation**, switchable to
**Create as new**. No dialogs — it fits the bulk paste flow.

## Testing

- Name key: Dart and TS unit tests, including a shared-vector test proving the
  two implementations agree, plus the `CHAIN GLOBAL` / `GLOBAL CHAIN` case and
  a punctuation case (`90/90-14`).
- Variation price: a variation built from the form carries the typed price;
  one built from receiving still inherits the base price. Asserted on both
  surfaces — this is the regression the optional parameter protects.
- Form flow: duplicate found → nothing written until a choice; each of the
  three buttons produces its documented outcome.
- Receiving: a GENERATE row matching an existing name+category classifies as
  `duplicate-name`; a non-matching one stays `new`; existing
  new/match/mismatch/error cases unchanged.
- Backfill: pure planner tested offline against catalog-shaped fixtures.

## Out of scope

Merging the 59 duplicates that already exist. The backfill lists them, but
combining stock, price history and sale references needs judgement per pair
and should be its own task.

## Rollout

`nameKey` is additive and unread until the new code ships, so the backfill can
run before or after deploy. Order: backfill (dry-run, then execute) → web
hosting → mobile APK. No rules deploy.
