# Auto-SKU revamp — Code 128 numeric scheme (category code + sequence)

Approved 2026-07-26 after brainstorm (all decisions user-confirmed). Replaces
the name-slug + random auto-SKU (`MLKCHCLT50-A3B7K9`) for NEW products only.

## Format

- Auto-SKU = **4-digit category code + 4-digit per-category sequence**.
  Stored canonical: `00070153` (8 digits, string — never numeric).
  Displayed: `0007-0153` (UI formatting only; mono font per the identifier
  convention). Encoded as Code 128 (all-digit → 128C double density).
- Variations keep today's pattern: `{parentSku}-1`, `-2`, … (unchanged
  `SkuGenerator.generateVariation`).
- Exactly 8 digits ≠ UPC/EAN 12–13 → scans never length-ambiguous against
  supplier barcodes.
- Codes start at `0001`; no reserved ranges.
- Existing 1,240 product SKUs are UNTOUCHED; old and new formats coexist under
  the existing `product_skus` claim. Manual SKU entry stays allowed everywhere.

## Category codes

- Assigned inside the category-create transaction from a monotonic counter doc
  (sale-number pattern). Monotonic ⇒ codes are NEVER reused, including after
  the (staff+admin) hard delete shipped 2026-07-26.
- Registry: `category_codes/{code}` created in the same tx — fields
  `categoryId`, `nameSnapshot`, `assignedAt`. Never updated/deleted; enforces
  uniqueness by doc-id construction; decodes old prefixes after a category is
  gone.
- Category editor (Product Categories, staff+admin) shows a READ-ONLY chip
  with the code. No edit affordance anywhere.
- Backfill script assigns codes to all existing product categories ordered by
  `createdAt`, creating registry docs + setting `code` on each category doc;
  idempotent (skips categories that already carry a code).
- Scope: product categories only (not expense categories/units/etc.).

## Product numbering — peek-then-claim

- Per-category sequence counter: a `nextSequence` field on the
  `category_codes/{code}` registry doc (single source; keeps the category doc
  clean and the counter co-located with the code it feeds). Registry docs are
  otherwise immutable — rules must permit updating ONLY `nextSequence`.
- Form UX (mobile + web): picking a category auto-fills the SKU field with the
  next number (a PEEK — counter untouched), field stays editable.
- On save, inside the existing product-create claim transaction:
  - If the SKU still matches the auto pattern for the chosen category → claim
    the SKU; if taken (raced or manually pre-claimed), advance to the next
    free number (skip-and-retry loop) and bump the counter to the consumed
    number. The saved SKU may silently differ from the peeked one.
  - If the user overwrote the field (doesn't match the pattern) → manual SKU:
    normal claim behavior, counter untouched.
- Abandoned forms consume nothing (peek only). Overflow at 9999 items fails
  loudly: "Category is full — split it into two categories."
- Recategorizing a product NEVER changes its SKU (prefix = birth category).
  Reports/filters must use the category field, never the SKU prefix.

## Cross-surface + guardrails

- Web admin product creation switches in the same phase — both surfaces share
  the Firestore counters and claim tx, so numbering is consistent.
- Spreadsheet boundary: every CSV export quotes SKUs as text; import scripts
  never parse SKUs numerically (leading zeros).
- Rules: additive — `category_codes` (read: active users; create: via the
  category-create path, staff+admin per the product-categories tighten;
  update/delete: never) + whatever counter doc shape needs. `product_skus`
  claim rules unchanged. Old APKs unaffected until the new build.

## Phases

1. **P1 (this initiative):** category-code counter + registry + chip; new
   generator + peek-then-claim on mobile AND web product forms; backfill;
   CSV text-quoting guardrails; rules.
2. **P2:** POS scan lookup falls back to SKU (claim read) so printed house
   labels sell. No barcodes[] copying.
3. **P3 (separate workstream):** label printing — hardware selection first.

## Testing

TDD throughout: counter/registry tx tests (fake_cloud_firestore incl. race =
two creates → distinct codes), generator peek/claim/skip-retry/overflow tests,
form auto-fill widget tests (mobile + web), backfill dry-run/idempotency tests,
rules suite additions, recategorize-keeps-SKU regression test.

## Explicit non-goals

- No re-SKU of existing products, ever, under this initiative.
- No prefix-based reporting.
- Name-duplicate prevention for categories stays with the N8 lists epic; when
  N8 lands, fold the name claim into this same category-create tx.
