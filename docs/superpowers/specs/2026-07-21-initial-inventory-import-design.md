# Initial Inventory Import — Design

**Date:** 2026-07-21
**Status:** Approved
**Source data:** `~/Downloads/MAKI_Master_Inventory - ALL ITEMS_latest (1).csv` (1,250 records = 1,249 item rows + 1 totals row)

## Goal

Load the shop's full physical inventory count into the live `products` collection in one
verified shot, via a Node Admin-SDK script (`scripts/import-inventory.mjs`), abiding by
every invariant the app maintains (SKU claims, cost codes, search keywords, variations,
audit fields). Items have no barcodes and no item codes yet — SKUs are auto-generated;
barcodes stay empty until scanned in later.

## Source-data facts (profiled 2026-07-21)

- Columns used: `NAME, CATEGORY, CODE, UNIT COST, SELLING PRICE, QTY, UNIT, REORDER_LEVEL, SUPPLIER`. Trailing `Column 3..18` are empty filler — ignored.
- **Cost-code cipher check:** 1,241/1,249 rows have `CODE == encode(UNIT COST)` under the
  app's default mapping (1→N 2→B 3→Q 4→M 5→F 6→Z 7→V 8→L 9→J 0→S, `SC`=00, `SCS`=000).
  The script re-verifies this at run time and warns on any new mismatch.
- **8 rows with unreadable cost tags** (letters outside the cipher — e.g. `URX`, `0IX`,
  `EX`, `45A`): rows 312, 512, 539, 679, 837, 838, 1044, 1121. Selling prices are known.
  **RESOLVED 2026-07-21** — user supplied the true tags/costs (see Decisions §2).
- **12 same-name different-batch pairs** (different cost and sometimes price):
  BELT BANDO SKYDRIVE SPORT 115I, BOLT HENG CNC-5G 6X35 CRANKCASE SILVER,
  DISC PLATE RR RAIDER150, HANDLE SWITCH DOMINO MIO LH, HANDLE SWITCH DOMINO MIO RH,
  MODULE LED WHT, TIRE TL BEAST 48P 110/70-13, TIRE TL MAXXIS MAG1 43P 80/80-14,
  TIRE TL MAXXIS MAV6 46P 90/90-14, TIRE TT IZUMI SPECIAL 2.75-17,
  TIRE TT LEO LAZER 70/80-17, TIRE TT LEO LAZER 80/80-17.
  (TOP GASKET AMCO W125 — same cost ₱35/QF both rows, only price differed — is NOT a
  variation; merged per Decisions §9.)
- **8 double-listed pairs** (same physical stock entered under two categories; identical
  qty — importing both would double-count): 5× OIL FILTER (LUBE&FLUIDS vs FUEL SYSTEM),
  2× SIGNAL LIGHT LENS (LENS vs ACCESSORIES), 1× CENTER STAND STEEL CSL XRM110
  (fully identical duplicate).
- **4 decimal quantities:** FUEL HOSE BLK 27.5 / FUEL HOSE GRN 25.5 (RULER),
  WIRE DOUBLE 39.5 / WIRE SINGLE RED 15.5 (METER).
- **Category spelling:** `CHAIN&SPROCKET` (37) and `CHAIN & SPROCKET` (23) both present.
- **Suppliers:** 5 rows carry codes (HD ×1, HMJ ×1, HNG ×1, KS ×2); the rest are `NA`.
- **Prod today:** 6 products / 6 SKU claims, 1 `product_categories` doc ("Parts"),
  1 supplier (HD), plus live transaction data (43 sales, 9 receivings, 6 drafts,
  5 expenses, 2 daily closings, 129 user_logs, 3 void_requests, 1 purchase order).
  NOTE: the app's category collection is **`product_categories`** (see
  `FirestoreCollections.productCategories`) — there is no `categories` collection.
  Admin name-lists (`product_categories`, `units`, `void_reasons`, …) all share the
  `CategoryModel` doc shape: `{name, isActive, createdAt, updatedAt, createdBy, updatedBy}`.
- **Units:** the admin-managed `units` collection holds kg, m, box, ml, g, l, pack, pcs.
  The CSV uses PC / SET / RULER / METER.

## Decisions (user-approved)

1. **Batch-cost pairs → variations** (12 pairs). First-listed row = base product; second =
   variation (`baseSku` = base's SKU, `variationNumber: 1`, its own SKU, costCode, cost,
   price, qty).
2. **Unknown-cost rows → RESOLVED with user-supplied corrections** (2026-07-21). All 8
   decode consistently under the default cipher. The corrections live as an explicit
   `COST_CORRECTIONS` table in the script lib (keyed by CSV row/name); the master CSV is
   not edited. No ₱0 imports, no VERIFY-COST notes:

   | CSV row | Item | costCode | cost |
   |---|---|---|---|
   | 312 | CARBURETOR SUNTAL CT150BOXER | `ZLS` | 680 |
   | 512 | FOOTREST ASSY W/ STAND CSL TMX | `BFS` | 250 |
   | 539 | FRONT FENDER SMASH115 MATTE BLK | `MFS` | 450 |
   | 679 | HEADLIGHT RS100 | `BQS` | 230 |
   | 837 | PISTON KIT M.DIALLO SMASH110 | `NZS` | 160 |
   | 838 | PISTON KIT M.DIALLO SMASH115 | `NZS` | 160 |
   | 1044 | SPROCKET RR CNKY NIKOYO CT100 45T | `NZF` | 165 |
   | 1121 | TAIL LIGHT COVER XRM110 BLK | `MS` | 40 |
3. **Double-listed pairs → merge to one product, qty NOT summed.** Categories:
   oil filters → `LUBE&FLUIDS`, signal-light lenses → `ACCESSORIES` (LENS category
   disappears), center stand → `CHASSIS`.
4. **Decimal qtys → round down**, original value preserved in `notes`.
5. **Category normalization:** `CHAIN & SPROCKET` → `CHAIN&SPROCKET` (matches the
   no-space style of `BOLT&NUT`, `LUBE&FLUIDS`).
6. **Existing-product name matches → skip + report** (normalized word-set comparison,
   catches `ASK BRAKE SHOE XRM` ≈ `BRAKE SHOE ASK XRM`). User reconciles the known
   brake-shoe qty conflict (15 vs 9) manually in the app.
7. The June "verify onsite" list (4 HEADLIGHT items, CENTER STAND NMAX V1) is assumed
   verified in this latest CSV — those rows import normally.
8. Totals row (and any nameless row) skipped.
9. **TOP GASKET AMCO W125 → merged, qty summed** (2026-07-21): one product, qty 15
   (10+5, genuinely two batches of the same-cost stock), price unified to ₱150,
   cost ₱35/`QF`.
10. **Rename** (2026-07-21): row 679 `HEADLIGHT RS100` → `HEADLIGHT RS100 BLK`
    (item is black; matches the CSV's BLK naming style). Lives in a `NAME_CORRECTIONS`
    entry beside `COST_CORRECTIONS` in the script lib.
11. **Pre-import wipe** (user-confirmed 2026-07-21, NO backup requested): before the
    import, a `scripts/wipe-db.mjs` script deletes (recursively, including
    subcollections) `products`, `product_skus`, `product_categories`, `suppliers`,
    `sales`, `receivings`, `drafts`, `purchase_orders`, `expenses`, `daily_closings`,
    `user_logs`, `void_requests`. KEPT: `users`, `settings` (cipher + receipt counters —
    receipt numbers continue, no reuse), `units`, `expense_categories`, `void_reasons`,
    `motorcycle_models`, `mechanics`. Storage files (product images, expense receipts)
    become orphans and are left alone. Consequences accepted by user: all transaction
    history gone; the 4 existing products not in the CSV (RS8 ULTRA 1L ×2-batch,
    PULLEY SET RS8 NMAX AEROX V1 V2, PULLEY BALL SRF 9G CLICK/PCX 6SET,
    JVT PIPE V3 NMAX/AEROX) vanish; job-order drafts confirmed all closed.
12. **Units mapped to the app vocabulary** (2026-07-21): PC→`pcs`, SET→`set`,
    RULER→`ruler`, METER→`m` (via a `UNIT_MAP` in the lib). The import creates the
    missing `units` docs (`set`, `ruler`) with the shared CategoryModel shape.
13. **Post-wipe consequences for matching:** with products wiped, the import expects
    **zero existing-name skips** and writes all 1,240 docs; `BRAKE SHOE ASK XRM`
    imports at the CSV count (qty 9) — the pre-wipe live doc said 15, so the user
    should physically verify that one item after go-live. Supplier HD is recreated by
    the import (4 suppliers created, not 3). The skip/resume machinery stays — it is
    the crash-resume safety net.

## Architecture

Two files in `scripts/` (ESM, same conventions as the backfill scripts):

- **`import-inventory-lib.mjs`** — pure, Firestore-free transform logic (unit-testable):
  - `parseMoney`, `parseQty` (₱/comma stripping; decimal → floor + note)
  - `encodeCostCode(cost)` — port of `CostCodeEntity.encode` (default mapping)
  - `generateSku(name, rand)` — port of `SkuGenerator.generateForName`
    (slug → keep first char → drop vowels → cap 10 → `-` + 6 chars of
    `ABCDEFGHJKMNPQRSTUVWXYZ23456789`); `normalizeSku` = trim + uppercase
  - `searchKeywordsFor({sku, name, category})` — byte-identical port of
    `ProductModel._generateSearchKeywords` + `toSearchKeywords` (lowercase,
    whitespace-split, per-word prefixes length 1..10, set-union; no barcodes)
  - `transform(rows)` — applies all decisions above; returns
    `{products, variations, categories, suppliers, report}` where `report` carries
    every disposition (created / variation / merged / skipped) and all flag tables
  - `nameKey(name)` — uppercase word-set key for dup detection & existing-product match
- **`import-inventory.mjs`** — CLI + Firestore I/O:
  - `node import-inventory.mjs <csv-path>` → **dry run** (default): full report, zero writes
  - `node import-inventory.mjs <csv-path> --execute` → writes, then reconciliation
  - Auth: ADC (`gcloud auth application-default login`), project `maki-mobile-pos`;
    honors `FIRESTORE_EMULATOR_HOST` for emulator runs

## Write plan (`--execute`)

Order matters; each step is idempotent so a crashed run is safely re-runnable:

1. **Load existing state:** all products (build name-key set), suppliers, categories,
   `product_skus` claims. (Post-wipe this is empty — the load is the crash-resume net.)
2. **Categories:** create missing docs in **`product_categories`** (24 after
   normalization) — `{name, isActive: true}` + audit fields. Existing names skipped.
3. **Units:** create missing docs in `units` for the mapped vocabulary (`set`,
   `ruler`; `pcs`/`m` already exist) — same CategoryModel shape.
4. **Suppliers:** create HD, HMJ, HNG, KS (all 4 post-wipe) — `{name: code,
   transactionType: 'na', isActive: true, searchKeywords, productCount,
   totalInventoryValue}` + audit fields. The 5 supplier-linked products get
   `supplierId`/`supplierName` denormalized; supplier aggregates (`productCount`,
   `totalInventoryValue` += cost×qty) are incremented, mirroring the app's
   denormalization.
5. **Products (incl. variations):** for each, in order —
   `product_skus/{normalizeSku(sku)}.create({sku, productId, claimedBy: 'initial-inventory-import', claimedAt})`
   first (claim collision → regenerate SKU, retry), then the product doc (auto-ID) with
   the full ProductModel field set: sku, name, costCode, cost, price, quantity,
   reorderLevel, unit, supplierId/Name (null unless linked), isActive: true,
   searchKeywords, baseSku/variationNumber (variations only), `barcodes: []`, category,
   notes (flags only), `createdAt`/`updatedAt` = serverTimestamp,
   `createdBy: 'initial-inventory-import'`, `createdByName: 'Initial Import'`
   (mirrored to updatedBy/updatedByName per `toMap(forCreate)`).
   Variations are written after their base so `baseSku` always references an existing SKU.
6. **Reconciliation printout:** products written vs expected, claims count == products
   count (existing 6 + new), categories, suppliers, skipped lists. Non-zero exit on any
   mismatch.

Expected volume: 1,240 product docs (1,228 standalone/base + 12 variations; 1,249 rows
minus 8 double-listed merges minus the TOP GASKET merge). Post-wipe there are zero
existing-name skips. Exact numbers come from the dry-run report — it is the source of
truth the user approves before `--execute`.

## Error handling

- Any row failing to parse (money, qty, missing name mid-file) → listed in the report;
  dry run exits non-zero on unexpected shapes so surprises surface before writes.
- Cipher mismatches beyond the known 8 → warn table in report (import proceeds with the
  numeric cost, CSV CODE kept verbatim).
- BulkWriter per-doc failures → collected, printed, non-zero exit; re-run resumes safely
  (claims `.create()` + name-key skip make it idempotent).

## Testing / verification

1. **Unit tests** (`node --test scripts/`) on the lib: money/qty parsing, cost-code
   encoding (55→FF, 285→BLF, 100→NSC, 10000→NSSSCS), SKU generation vs known Dart
   outputs (deterministic injected rand), searchKeywords parity vs an app-generated
   example, dedup/variation grouping, name-key matching.
2. **Emulator dress rehearsal:** seed junk data (kept + deleted collections incl.
   subcollections) → run `wipe-db.mjs --execute` → assert keeps survive and deletes are
   gone → run the import `--execute` with the real CSV → reconciliation + scripted
   spot-checks (variation pair, corrected-cost item, merged item, unit mapping,
   supplier link) → re-run import `--execute` to prove idempotency (0 new writes).
3. **Prod sequence** (each step user-gated): wipe dry-run report → user "go" → wipe
   `--execute` → import dry-run report (expect 0 skips / 1,240 to write) → user "go" →
   import `--execute` → reconciliation + verify script + user smoke in the live web
   admin.

## Out of scope

- No `receivings` record (initial load, not a restock).
- No barcodes / `product_barcodes` claims (none exist yet).
- No `firestore.rules` changes (Admin SDK bypasses rules; nothing client-facing changes).
- No product images.
- Storage cleanup (orphaned product images / expense receipts are left in place).
- Any post-import stock-drift corrections (handled later via normal adjustments) —
  including physically re-verifying BRAKE SHOE ASK XRM (imports at qty 9; pre-wipe
  live tracking said 15).
