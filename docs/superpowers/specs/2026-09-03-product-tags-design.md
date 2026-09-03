# Product Tags — Design

**Date:** 2026-09-03
**Status:** Approved design, pending implementation plan

## Purpose

Custom tags attachable to products, driven by a concrete need: a physical
inventory sweep. Some product counts don't match system quantities; the shop
will tag products whose physical count is verified ("intact") and use the
tag filter to see what's left to sweep. Tags are general-purpose, though —
any custom label works the same way.

## Requirements

- Full CRUD on tags, managed from the Lists settings section on **both
  surfaces** (web admin + mobile).
- Tag list CRUD available to **admin, staff, and cashier** (matching the
  existing `editLists` grant); deactivate/reactivate/hard-delete restricted
  to staff/admin (matching `manageCategories`), same as every other shared
  list.
- Attaching/detaching tags on a product: **all three roles**.
- Tag chips visible on the inventory list on both surfaces.
- Inventory filterable by tag, including an **Untagged** option (the
  "what's left to sweep" view).
- Quick attach from the inventory list (no full edit-form round trip), plus
  a normal Tags field in the product form.

## Data model

### New collection: `product_tags`

Bespoke entity (Mechanics pattern), one doc per tag:

```
{
  name: string,
  color: string,        // named token from a fixed palette (~8), not hex
  description: string?, // shown only in the tag editor, never on rows
  isActive: bool,
  createdAt, updatedAt, createdBy, updatedBy
}
```

- `color` tokens (e.g. `gray`, `red`, `amber`, `green`, `teal`, `blue`,
  `purple`, `pink`) are defined once per surface as mirrored constants
  (like `Permission`), each mapping to a soft tint + text color consistent
  with the app's muted aesthetic. Unknown token → render as `gray`.
- Name uniqueness: client-side `nameExists` check like other lists (no
  server claim; tags are not identity-critical).

### Product field: `tagIds: string[]`

- New optional array on the product doc; readers default missing/absent to
  `[]` (old docs and old APKs unaffected — **no backfill**).
- Chips resolve name/color live from the streamed tag list. Renames and
  recolors propagate instantly; nothing denormalized.

### Lifecycle

- **Deactivate tag** → chips hidden on inventory rows; ids stay on
  products, so reactivating restores chips. In tag pickers, a stale
  selected value follows the existing "(inactive)" orphan pattern.
- **Hard delete** → orphaned ids remain on products, are unresolvable, and
  are silently not rendered. No cleanup pass — harmless by construction.
- **Untagged** filter = product has no id resolving to an *active* tag
  (orphans don't count as tagged).

## Firestore rules

New `product_tags` block, copy of the shared-list template
(`units`/`void_reasons`/`mechanics`):

- read/create: any active valid user
- update: any active valid user, except only staff/admin may touch
  `isActive`
- delete: staff/admin

Product doc: **no rule change expected.** The cashier update branch is a
denylist (`sku`, `costCode`, `cost`, `price`, `quantity`, `isActive`,
`sellingOptions`) that does not include `tagIds`, so a `tagIds`-plus-audit
write already passes. Proven by rules tests, not assumed.

Rules deploy is production-affecting → show diff and get explicit
confirmation before deploying.

## Web admin

New feature files mirroring Mechanics + the reskinned inventory:

- `domain/entities/Tag.ts`; palette tokens in `domain/tags/` (with chip
  style mapping); `collections.ts` gains `product_tags`.
- `data/repositories/FirestoreTagRepository.ts`; `useTagRepo` in the DI
  container.
- Hooks: `useTags` / `useActiveTags`, `useTagMutations` (create / update /
  setActive / delete), each writing the standard settings activity log.
- **ProductTagsPage** at `/settings/tags` (Mechanics-page shape): shared
  Dialog for add/edit — name, color swatch row, description; deactivate /
  reactivate; confirm-dialog hard delete (staff/admin only). Settings row
  "Product tags" gated `editLists`. Route wiring touches all three files:
  `routePaths.ts`, `routes.tsx`, `routeGuards.ts` (known 3-edit gotcha).
- **Inventory list**: new Tags column — tinted chips, first 2 + "+n"
  overflow; tag names joined into the CSV export. Per-row tag icon button
  (click does not open the row's edit) → popover listing active tags with
  toggles; each toggle writes immediately via `updateProductTags`.
- **Tag filter**: `SelectFilter` in the filter band (All / Untagged / each
  active tag); `domain/products/filterProducts.ts` extended (pure).
- **ProductModal**: active tags as toggleable chips in Stock &
  classification (near Notes). Read-only in cashier name-only mode —
  cashiers use the row quick action, keeping the cashier save/rebase logic
  untouched.
- Writes go through a dedicated `updateProductTags(productId, tagIds)`
  repo method that writes **only** `tagIds` + audit fields.

## Mobile

Mirrors the Mechanics layering:

- `domain/entities/tag_entity.dart`, `data/models/tag_model.dart`,
  `domain/repositories/tag_repository.dart` + impl,
  `presentation/providers/tag_provider.dart` (`activeTagsProvider`,
  `allTagsProvider`, `tagOperationsProvider`). Palette tokens + chip style
  helper in core constants. `firestore_collections.dart` gains
  `product_tags`.
- **TagEditorScreen** at `/settings/tags` (mirrors
  `mechanic_editor_screen`): `SettingsCrudRow` list showing a chip preview
  + description subtitle; add-FAB form with name, ~8 color swatches,
  description. `manageCategories` gates deactivate/delete rows. New
  "Product Tags" tile in Settings → Lists section; route guard map entry →
  `editLists`.
- **ProductEntity/ProductModel**: add `tagIds` (default `[]`) through
  entity, model (`fromMap` tolerant of missing), `copyWith`, `props`.
- **Inventory tile** (`product_list_tile.dart`): tag chips beside the
  category chip, first 2 + "+n".
- **Quick attach**: long-press (currently admin-delete only) becomes an
  actions sheet for everyone — "Tags…" (all roles) and "Delete" (admin
  only, same behavior beneath). "Tags…" opens a bottom sheet of active
  tags with checkmarks; tap toggles write immediately via
  `updateProductTags`.
- **Product form**: chip-toggle Tags field in the Classification section,
  participating in dirty tracking; editable for staff/admin, read-only for
  cashier (quick action instead).
- **Filter**: Tag filter chip beside the Category chip; `InventoryState`
  gains `tagFilter` (tag id or `untagged` sentinel);
  `filteredProductsProvider` extended.

## Testing

TDD throughout.

- **Rules** (`tools/firestore-rules-test`): shared-list template coverage
  for `product_tags` (cashier create/rename OK, deactivate/delete denied;
  staff/admin full); product doc: cashier `tagIds`+audit-only update
  **passes**, cashier `tagIds`+`price` update **fails**.
- **Web** (Vitest): `filterProducts` tag cases (specific tag, Untagged,
  orphan tolerance); ProductTagsPage CRUD; quick-attach popover writes
  only `tagIds`; ProductModal tags field incl. cashier read-only.
- **Mobile** (`flutter test`, mirrored structure): `TagModel`
  serialization round-trip; inventory provider tag filtering; widget tests
  for TagEditorScreen and the long-press sheet.
- Verification gates: `flutter analyze` + `flutter test`;
  `npm run typecheck` + `npm run test` + `npm run build`.

## Rollout

1. **Rules** — additive block; confirm with user, then deploy.
2. **Web** — build + deploy hosting (firebase reauth currently pending).
3. **Mobile** — ships with the next APK (+33, already holding the
   receiving changes). Old APKs unaffected (never read `tagIds`).

Implementation branches off `feat/web-reskin-product-modal` (the web Tags
field lands in the reskinned ProductModal), or off `main` once that branch
merges.

## Out of scope (YAGNI)

- No per-product tag counts/analytics, no tag-based reports.
- No bulk "tag all filtered" action (revisit if the sweep proves two taps
  per product too slow).
- No server-side tag name uniqueness claim.
- No cleanup/backfill of orphaned `tagIds`.
