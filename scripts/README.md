# Operational scripts

One-off scripts run manually against the live project. Not part of the app build.

## backfill-product-skus.mjs

Backfills the `product_skus` SKU-uniqueness guard collection (one claim doc per product,
keyed by `sku.trim().toUpperCase()`). Idempotent — safe to re-run.

**Prereq:** the `product_skus` rules block is deployed (`firebase deploy --only
firestore:rules`). The script uses the **admin SDK** (bypasses rules) but the rules must
exist before slices B/C ship.

**Auth (application-default credentials):**
- `gcloud auth application-default login`  — OR —
- `export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json`

**Run:**
```
cd scripts
npm install
node backfill-product-skus.mjs
```

Exit code 0 + "Backfill complete" when every product owns a unique claim. Exit code 1 +
a collision report if two SKUs normalize to the same key — rename one product and re-run.

## wipe-db.mjs + import-inventory.mjs (one-shot, 2026-07-21)

Fresh-start sequence: `wipe-db.mjs` deletes transaction + inventory data (keeps users,
settings, units, expense_categories, void_reasons, motorcycle_models, mechanics), then
`import-inventory.mjs` loads the master inventory CSV
(`data/master-inventory-2026-07-21.csv`) into `products` + `product_skus` claims +
`product_categories` + `units` + `suppliers`. Spec:
`docs/superpowers/specs/2026-07-21-initial-inventory-import-design.md`.

- Wipe dry run:      `node wipe-db.mjs` (add `--execute` to delete — DESTRUCTIVE)
- Import dry run:    `node import-inventory.mjs data/master-inventory-2026-07-21.csv`
- Import:            add `--execute`
- Verify afterwards: `node import-inventory-verify.mjs`
- Emulator rehearsal: prefix commands with `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080`
- ⚠️ Go-live: freeze ALL shop app/POS usage from the moment the wipe starts until
  `import-inventory-verify.mjs` passes — a mid-window sale writes to collections
  being wiped or references vanished products.

Import is idempotent & resumable: existing product names (word-order-insensitive) are
skipped, the SKU claim + product doc are written atomically, and orphan import claims
are cleaned on reconcile. Everything written is tagged
`createdBy: 'initial-inventory-import'`.

## seed-shop-timezone.mjs

Writes the shop timezone into `settings/general` — the doc the mobile app, the web
admin and the Firestore rules (`phDay()`) all read to decide what "today" is. Spec:
`docs/superpowers/specs/2026-08-26-shop-timezone-design.md`.

- Dry run:  `node seed-shop-timezone.mjs` (prints before/after, writes nothing)
- Execute:  `node seed-shop-timezone.mjs --execute`
- Custom:   `node seed-shop-timezone.mjs --timezone=Asia/Tokyo --offset=540 --execute`
- Emulator: prefix with `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080`

Idempotent — it merges only `timezoneId` and `tzOffsetMinutes`, leaving any other keys
in the shared `general` doc untouched, so re-running is safe. Defaults to Asia/Manila
(+480), which is also what every surface falls back to when the doc is absent: seeding
the default changes no behaviour, it just makes the value explicit and editable from
the Time & Timezone settings screen. The offset is validated the same way the rules
validate it (an integer in -720..840).

## repair-preview-skus.mjs

Repairs the stale PEEKED-preview SKUs left behind before the `withAllocatedSku` fix in
`web_admin` (`productWrites.ts`, `executeReceivePlan.ts`, `FirestoreProductRepository.ts`).
A product created with an auto-generated SKU was written with a preview code and the real
code was only allocated inside the claiming transaction; when the scan moved past the
preview, two derived copies kept the stale value — `products/{id}.searchKeywords` and
`receivings/{id}.items[].sku`. The product's own `sku` field was always correct.

Planning is pure (`repair-preview-skus-lib.mjs` + node tests); the runner does the I/O.

- Report only:  `node repair-preview-skus.mjs`
- Receivings:   `node repair-preview-skus.mjs --execute`  (default scope)
- Keywords:     `node repair-preview-skus.mjs --scope=keywords --execute`
- Both:         `node repair-preview-skus.mjs --scope=all --execute`
- Emulator:     prefix with `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080`

Idempotent — re-running after a successful pass reports zero patches for that scope.

**Both scopes were run against production on 2026-08-27 and both now report zero patches.**

- Receivings: 16 docs / 155 lines carried a SKU belonging to another product (one code sat on
  10 lines of `RCV-20260824-005`). Repaired.
- Keywords: 950 of 1,625 products. Note these were NOT preview victims — they were
  `initial-inventory-import` products whose `searchKeywords` held no SKU tokens at all (so they
  could not be found by typing their own SKU) plus a consonant-skeleton token family
  (`pllybllpts` for "PULLEY BALL PITSBIKE") that no generator in this repo produces. The shop
  confirmed the skeleton tokens are unused, so the rebuild — which adds the SKU tokens and drops
  the skeletons — was the right call. It also cleared stale tokens from the pre-shortening
  category name (`cvt/transm` vs today's `CVT/TRANS`).

Pre-write snapshots of both collections were taken; ask before assuming they still exist, as they
were written to a session scratchpad rather than committed.

## backfill-product-name-keys.mjs

Backfills the `nameKey` duplicate-detection field (`productDuplicateKey(name, category)`) onto
every product, and reports the products that already share a name+category — the field consumed
by the duplicate-name-warning feature added to both surfaces. `nameKey` is additive and unread
until that feature ships, so this is safe to run before or after that deploy.

Planning is pure (`backfill-product-name-keys-lib.mjs` + node tests, sharing the same vector table
as `test/core/utils/product_name_key_test.dart` and `web_admin/src/domain/products/nameKey.test.ts`
so all three implementations stay in lock-step); the runner does the I/O.

- Dry run:  `node backfill-product-name-keys.mjs`
- Execute:  `node backfill-product-name-keys.mjs --execute`
- Emulator: `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node backfill-product-name-keys.mjs --execute`

Idempotent — a product whose stored `nameKey` already matches its current name and category is
skipped, so re-running after a successful pass reports zero patches. Renaming or re-categorising a
product later makes its `nameKey` stale again and it will be picked up by the next backfill run.

The duplicate-group listing (products that already share a name+category) is a **report only** —
this script never merges, deletes, or edits duplicate products; that is a separate, human-decided
job.

