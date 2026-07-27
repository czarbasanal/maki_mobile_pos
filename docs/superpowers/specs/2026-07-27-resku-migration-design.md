# Re-SKU migration — convert old auto-generated SKUs to the coded scheme

Approved 2026-07-27 ("let's push the sku backfill"). One-script initiative;
runs pre-label-printing (P3), the cheapest window. Prod grounding: 1,259
products — 1,246 match the old auto patterns (all carry categories), 13
manual/coded stay untouched.

## Classification (exact — mirrors sku_generator.dart's alphabets)

Old-auto (rename): `^[A-Z0-9]{1,10}-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$`
(generateForName) or `^SKU-[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$` (generate).
Everything else (manual part numbers, already-coded 8-digit) is untouched.
Idempotent by construction: renamed products no longer match. Re-runs sweep
the +17 trickle (mobile mints old-style until +18 installs).

## Assignment

- Group renames by product `category` (name) → product_categories doc → its
  `code`; skip (and report) products whose category is missing/uncoded.
- Within a category: order by `createdAt` asc (tie: doc id); sequences start
  at the category's `category_codes/{code}.nextSequence`; after execution the
  registry's `nextSequence` advances past the last assigned.
- Variations are renamed like any product (own sequence). Second pass: every
  product whose `baseSku` equals a renamed old sku gets `baseSku` → new sku.

## Writes (admin SDK, batched ≤400)

Per rename: product doc `{sku: newSku}` (+ `baseSku` where remapped);
DELETE old `product_skus/{normalize(oldSku)}` claim; CREATE
`product_skus/{newSku}` claim carrying the old claim's `claimedBy` (fallback
`'resku-backfill'`) + fresh `claimedAt` + `{sku: newSku, productId}`.
Per category: registry `nextSequence` update. Nothing else — barcodes,
sales/receiving/JO snapshots, drafts all untouched by design (they snapshot
sku strings; old receipts keep old SKUs, accepted).

## Safety

- Dry-run default; `--execute` + `--yes`; stdin-EOF guard; zero-work exit.
- Dry-run writes the full old→new plan to `scripts/data/resku-plan.json`
  (user reviews before execute); execute writes the applied mapping to
  `scripts/data/resku-map-<timestamp>.json` (reversal insurance).
- Pre-write verification inside execute: every target claim id must be
  absent and no target sku duplicated in-plan; any conflict → ABORT whole
  run (re-run replans). Run during an idle window (no product creation).
- Pure lib (`classify`, `planResku`) + node:test coverage mirroring the
  category-codes backfill pattern; CLI never run against prod by agents —
  dry-run/execute happen with the user.

## Non-goals

No rules changes (admin SDK bypasses; runtime invariants unaffected). No
barcode changes. No re-SKU of the 13 manual products, ever. Mobile app
behavior unchanged (+18 unaffected).
