# Avg Daily info button + auto-SKU convention fix

**Date:** 2026-07-29
**Surfaces:** Flutter app (`lib/`), React web admin (`web_admin/`)

Two independent items, batched because they were reported together. They share no
code and can be implemented in either order.

---

## Item 1 — Avg Daily card: fix the maths, then explain it

### Problem

The dashboard's Avg Daily card divides a total that **includes today** by a day
count that **excludes today**:

- Numerator — `monthToDateSummaryProvider` (`sale_provider.dart:168-188`) queries
  `1st 00:00 → today 23:59:59.999`.
- Denominator — `monthToDate(now).daysElapsed` is `now.day - 1`
  (`week_range.dart:64`), i.e. completed days only.

So on the 2nd, with ₱10,000 taken on the 1st and ₱3,000 so far today, the card
reads **₱13,000** as the average day. The error shrinks as the month goes on but
is never zero.

Separately, on the 1st `daysElapsed` is 0, `avgDailyFromGross` returns its
defensive `0`, and the card shows **₱0.00** — indistinguishable from "a day with
no sales".

### Decision

Make the number mean **completed days only**. Today is excluded from both sides.

### Changes

**Numerator.** The summary's end bound moves from end-of-today to
**end-of-yesterday**. When `daysElapsed == 0` (the 1st) the provider
short-circuits to an empty `SalesSummary` without issuing a Firestore read —
the range would be empty anyway, and the card renders `—` regardless.

**Rename.** `monthToDateSummaryProvider` → `monthCompletedDaysSummaryProvider`.
"Month-to-date" will no longer include today, so the old name would mislead.
Only three non-test references exist: `avgDailySalesProvider`
(`sale_provider.dart:197`), a refresh line in `dashboard_screen.dart:132`, and
two test files.

**Null on the 1st.** `avgDailySalesProvider` becomes
`Provider<AsyncValue<double?>>`, returning `null` when `daysElapsed <= 0`. The
card's existing `avgDaily != null ? _money(...) : '—'` branch
(`sales_summary_section.dart:44-46`) then renders `—` with no further change.

`avgDailyFromGross` in `week_range.dart` is **not** changed — the provider
returns early before calling it. Leaving the shared helper alone keeps this
change local.

### The info button

`_StatCard` (`sales_summary_section.dart:219`) gains an optional
`VoidCallback? onInfo`. When supplied, the card's leading-icon row becomes a
`Row` with the icon on the left and a small tappable ⓘ (`LucideIcons.info`) on
the right. Label and value layout are untouched. Only the Avg Daily card passes
`onInfo`; COGS and Profit render exactly as today.

Tapping opens the house dialog (`lib/presentation/shared/widgets/common/app_dialog.dart`):

> **Avg Daily**
>
> Your average sales per day this month, counting only days that have finished.
>
> It adds up sales from the 1st up to yesterday, then divides by that many days.
> Today isn't counted yet because it's still going.

Tap-to-open, not a long-press tooltip — a tooltip is undiscoverable on a phone.

### Testing

- `monthCompletedDaysSummaryProvider` queries `1st → end of yesterday`, and issues
  **no** query on the 1st.
- `avgDailySalesProvider` returns `null` on the 1st and
  `gross / (day - 1)` otherwise.
- The card renders `—` on the 1st and a peso value otherwise.
- The ⓘ appears only on Avg Daily, and tapping it opens a dialog containing the
  explanation.

---

## Item 2 — Auto-SKU: stop emitting the old convention

### Problem

The canonical auto-SKU is a 4-digit category code plus a 4-digit sequence
(`0007-0153`), composed by `SkuGenerator.composeAutoSku`. But the product form
falls back to the **old** random/name-based generator whenever no coded category
is driving the field:

- `product_form_screen.dart:144` seeds the field with `generateForName(null)` →
  `SKU-A3B7K9M2` the moment Add Product opens.
- Lines 469, 481, 532, 548 re-roll `generateForName(name)` on name change, on
  blur, and when a chosen category has no code or its peek fails.

Web behaves identically (`InventoryFormPage.tsx:200, 221, 233, 423`) — this is
**not** mobile lagging behind web.

### Decision

With auto-generate on, the SKU field is **category-driven or empty**. It never
shows a generated value in the old format.

### Changes (both surfaces, kept identical)

| Situation | Behavior |
|---|---|
| Add Product opens, auto on | Field **empty**. Helper: *"Pick a category to generate the SKU."* |
| Product name typed / blurred | Nothing generated. Name no longer drives the SKU at all. |
| Category **with** a 4-digit code chosen | Field fills with `composeAutoSku(code, sequence)` — unchanged from today. |
| Category **without** a code chosen | Field stays empty. Helper: *"This category has no code — pick another, or turn off auto-generate and type a SKU."* |
| Category peek fails (network/error) | Field stays empty. Helper: *"Couldn't reach the server — try again, or turn off auto-generate and type a SKU."* |

**Why the failure case gets its own message** (decided 2026-07-29, after review): an
earlier draft of this spec reused the no-code helper for a failed peek. That tells the
admin their category is misconfigured when the category is fine and the network merely
blipped — sending them to hunt for a settings problem that does not exist. A coded
category whose sequence lookup failed is a transient condition, and the copy has to say
so. Three strings total, all shared byte-for-byte across both surfaces.
| Auto-generate toggled **off** | Manual entry, verbatim. Unchanged. |
| Editing an existing product | Unchanged — auto-SKU has always been create-only. |

**Submitting blank** surfaces the existing "SKU is required" validation rather
than saving a placeholder. That is the intended dead end: it forces either a
coded category or a deliberate manual SKU.

**The regenerate button is removed on both surfaces.** Its only purpose was
re-rolling the name-based SKU. On mobile it renders solely when
`isCreating && _autoGenerateSku` (`product_form_screen.dart:758-762`) — precisely
the state where, after this change, there is nothing for it to generate: either
no category is chosen (nothing to compose from) or a coded category is driving
the field, where `_regenerateSku` already no-ops via `_categoryDrivesSku()`. It
is never offered in manual mode today, so removing it loses no capability.
Confirm the equivalent condition on web (`InventoryFormPage.tsx:497`) during
implementation and remove it on the same reasoning.

**Helper text placement.** Mobile uses the field's existing `helperText` on
`InputDecoration`, matching the established pattern at
`product_form_screen.dart:220`, `:261` and `:295`. Web uses its existing
field-hint pattern in `InventoryFormPage.tsx`.

### Explicitly out of scope

`SkuGenerator.generateForName` / `generate` (mobile) and `generateSku` (web) are
**kept**. They are still used by Receiving to mint SKUs for products created
during a goods-in:

- `lib/domain/usecases/receiving/receiving_import_resolver.dart:77`
- `web_admin/src/data/receiving/planReceive.ts:111`
- `web_admin/src/data/receiving/applyReceivedItems.ts:112`
- `web_admin/src/presentation/features/receiving/ReceivingEntryPage.tsx:50`

**This means Receiving still produces old-format SKUs.** That is a real remaining
inconsistency in the auto-SKU rollout, but it is a separate problem — products
created mid-receiving have no category selected at that point, so giving them a
category-coded SKU needs its own design. Flagged, not fixed here.

### Testing

- Opening Add Product issues no SKU generation: the field is empty and the
  hint is shown.
- Typing and blurring a name leaves the field empty.
- Selecting a coded category fills the 8-digit SKU.
- Selecting an uncoded category leaves the field empty with the no-code hint.
- Submitting with an empty SKU raises the existing required-field error.
- Turning auto off allows free text and restores the regenerate control.
- Web: the same six cases in `InventoryFormPage.test.tsx`.

---

## Gates

Mobile: `flutter analyze` clean, `flutter test` passing.
Web (from `web_admin/`): `npm run typecheck`, `npm run test`, `npm run build`.

No Firestore rules, index, or schema change. Nothing to deploy beyond the usual
hosting deploy and an APK.
