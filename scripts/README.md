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

Import is idempotent & resumable: existing product names (word-order-insensitive) are
skipped, the SKU claim + product doc are written atomically, and orphan import claims
are cleaned on reconcile. Everything written is tagged
`createdBy: 'initial-inventory-import'`.
