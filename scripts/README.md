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
