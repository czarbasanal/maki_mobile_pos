# Bundle 05 — Receiving theme migration (mobile)

**Date:** 2026-06-25
**Surface:** Flutter mobile app — `lib/presentation/mobile/screens/receiving/`
**Bundle:** 05 of the screen-by-screen mobile UI refactor (after 01 login/dashboard,
02 POS/checkout, 03 sale-detail, 04 inventory).
**Handoff:** `design/handoff/05-receiving/` — `MAKI-POS-Receiving.dc.html` (the migrated
prototype, **pixel-faithful source of truth**), `README.md` (token tables + per-screen
spec + icon map), `reference_current-ui.html` (before-state), `screenshots/01-light` +
`02-dark`.

## Goal

Bring all five Receiving surfaces onto the new global theme **behavior-preservingly**.
This is a **pure migration** (same class of change as bundles 02/03/04): visual + icon
layer only. No changes to providers, repositories, Firestore schema, security rules, or
any business logic.

**Acceptance bar = pixel fidelity to the prototype.** Per the handoff's implementation
directive, match every color/hex, font size/weight, icon, spacing, radius, shadow,
padding, border, badge, and copy string as built, in **both light and dark themes**.
Where a value isn't shown for an element, derive it from the README token tables (taken
from the same prototype), never from guesswork. If README and prototype ever disagree,
the **prototype wins** — and flag it.

## Scope

Five screens + four widgets:

- `receiving_screen.dart` — landing hub + `receiving_summary_cards_row.dart`
- `bulk_receiving_screen.dart` — main receive-stock form (edit + read-only) + `receiving_item_row.dart`
- `batch_import_screen.dart` — CSV import flow + `csv_import_dialog.dart` + `import_preview.dart`
- `receiving_drafts_screen.dart` — drafts list
- `receiving_history_screen.dart` — completed history (month-grouped)

## The three transforms (per the handoff README tables)

1. **Surfaces** — Material `Card` / flat bordered `Container` → shared `AppCard`
   (light = `AppShadows.card`; dark = `#18262A` + 1px `#243234` hairline). Pinned bottom
   bars (New Receiving, Complete Receiving) → footer `Container` with
   `AppShadows.pinnedFooter` + primary button (`AppShadows.primaryButton`). Summary/stat
   cards → `AppCard`, matching Inventory's stat style. App bars get the soft bottom
   shadow via `PreferredSize` + `DecoratedBox(boxShadow: AppShadows.pinnedHeader)`.

2. **Icons** — Cupertino → Lucide (`lucide_icons`) via the handoff's explicit map: back
   `chevron-left` · batch import `upload-cloud` · new/add `plus` · drafts `square-pen` ·
   completed `check-circle` · **total/received `trending-up`** (info) · supplier
   `briefcase` · dropdown `chevron-down` · search `search` · qty stepper
   `minus-circle`/`plus-circle` · remove `x` · save draft `save` · cost-up
   `arrow-up`/`arrow-up-right` · cost-down `arrow-down`/`arrow-down-right` · import action
   `arrow-right-circle` · adjust-stock (read-only) `square-pen` · delete (swipe) `trash-2`
   · empty-state `package`/`shopping-cart`.

3. **Status colors** — hardcoded `Colors.green/orange/blue/grey` → theme tokens with
   dark parity: completed = `AppColors.success*`, draft = `AppColors.warning*`,
   total/info = `AppColors.info`, cancelled/muted = muted tokens, new-variant badge =
   `AppColors.info` tint. Cost-diff up/down already use `AppColors.errorDark/successDark`
   (keep, ensure dark parity). Color discipline holds — color only carries status
   semantics, never decoration.

## Batch import — full pass

The batch-import preview (`import_preview.dart` / `csv_import_dialog.dart`) is already
*partly* on-system (semantic `AppColors` summary chips). Decision: **full pass** — beyond
migrating the remaining bordered cards → `AppCard` and Cupertino icons → Lucide, re-check
the chip and classified-row-tile styling so the whole flow (idle help card, parsing,
preview, Done, Errored) reads consistently with the other four screens.

## Must-keep (unchanged behavior)

- All admin role-gating: unit cost, cost-in-search, line totals, total-cost summary,
  cost-diff badges/warnings, price-change confirm dialog.
- `Permission.addProduct` gating for CSV new-product rows (banner + disabled import).
- Read-only completed-receiving view: success banner + per-line "Adjust stock" pencil.
- SKU-variation-on-cost-change behavior and all its warning/dialog copy.
- CSV format rules + GENERATE + variation logic; draft save/resume; supplier optional.
- Currency stays grouped (`₱1,234.00`); dates `MMM d, y • h:mm a`; month header `MMMM y`.
- Dark-theme parity across every migrated surface.

## Testing approach

Behavior is unchanged, so the primary test exposure is the **icon-matcher breakage** noted
in the redesign memory: any `find.byIcon(CupertinoIcons.*)` in receiving widget/screen
tests must move to the Lucide equivalent alongside the swap. Per screen: sweep its tests
for Cupertino matchers, update them, then run `flutter test` + `flutter analyze` and hold
the 0-warnings bar (established `43c3dbc`).

## Sequencing & branch

One screen at a time in handoff order (landing → bulk → batch → drafts → history); each is
a self-contained restyle + test-sweep so the diff stays reviewable — same cadence as 04.
Work on a single feature branch `theme/05-receiving`, commit per screen, merge to `main`
at the end (matches 04's merge-commit pattern `0d8cb5a`).

## Out of scope

`receipt_widget.dart` / `void_sale_dialog.dart` (still Cupertino, not in any handoff —
deferred). No layout/flow rethinks (add-product panel stays the inline grey search panel;
swipe-to-delete stays; summary cards stay 3-up). Reorder/web surfaces untouched.
