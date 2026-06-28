# Cross-cutting — Modals & Bottom Sheets

Mobile Flutter restyle. **This folder is the *current* state, for hand-off to Claude Design.**
`reference_current-ui.html` is a token-accurate reconstruction of every overlay surface that ships
today (open it in a browser), grouped by **archetype** rather than by screen.
Mark up / redesign on top of it and drop the redesigned hand-off file back here.

Unlike the per-screen bundles (01–07), this is a **synchronization spec**: the deliverable is **one
dialog shell + one bottom-sheet shell** (with a small set of variants) that every overlay in the app
adopts — so the whole app speaks one modal language.

## Scope

**Every dialog (`showDialog` / `AlertDialog`) and bottom sheet (`showModalBottomSheet` /
`DraggableScrollableSheet`) app-wide.** Concretely:

### Dialogs

| Archetype | Source widget(s) |
|---|---|
| 2-action confirm (neutral) | `core/extensions/navigation_extensions.dart` → `showConfirmDialog`, **+ ~20 inline `AlertDialog`s** |
| Destructive confirm (red primary) | `mobile/widgets/pos/void_sale_dialog.dart`, `request_void_dialog.dart`, the delete-* inline confirms |
| Single-input dialog | `shared/widgets/common/discount_input_dialog.dart`, `shared/widgets/common/password_dialog.dart` |
| Password confirm (duplicate) | `shared/widgets/common/password_dialog.dart` **and** `shared/widgets/auth/password_confirm_dialog.dart` |
| Error feedback | inline error banners + `showErrorSnackBar`; `shared/widgets/common/error_dialog.dart` is an **empty file** |
| Success dialog | `mobile/widgets/pos/checkout_success_dialog.dart` (custom `Dialog`, elastic scale-in, already Lucide) |
| Heavy custom dialog | `mobile/widgets/receiving/csv_import_dialog.dart` (`AlertDialog` with hard-coded `width: 420`) |

> The **~20 inline `AlertDialog` 2-action confirms** are the biggest group to unify: delete category /
> delete mechanic / delete expense / delete user / delete supplier / close day / replace cart / switch
> discount type, etc. They are written by hand at each call site, not from a shared component.

### Bottom sheets

| Archetype | Source widget(s) |
|---|---|
| Action-list picker | `mobile/widgets/inventory/product_image_uploader.dart` (image source) |
| Radio picker | `mobile/screens/settings/settings_screen.dart` → `_showThemePicker` (`RadioGroup`) |
| Draggable scrollable + pinned footer | `mobile/widgets/drafts/draft_detail_sheet.dart` (0.7 / 0.5 / 0.95) |
| Resolve sheet (receipt breakdown) | `mobile/screens/sales/void_requests_screen.dart` (`DraggableScrollableSheet` 0.85) |
| Input / form sheet | `mobile/widgets/inventory/stock_adjustment_dialog.dart` (named "dialog" but is a `showModalBottomSheet`) |

## Current state — what's inconsistent (the problem to solve)

- **Two surface families, no shared shells.** Raw `AlertDialog`s (inherit theme radius `xl = 24`) sit
  next to custom `Dialog`s that pin their own radii (`password_dialog` hard-codes `16`;
  `checkout_success_dialog` pins buttons to `lg = 18`). Every bottom sheet hand-rolls its own grab
  handle, padding, header and footer — there are at least **three different grab-handle
  implementations** (`draft_detail_sheet`, `stock_adjustment_dialog`, and the theme picker has none).
- **Icons are Cupertino almost everywhere.** Only `checkout_success_dialog` has migrated to Lucide.
  `password_dialog`, `discount_input_dialog`, `void_sale_dialog`, `draft_detail_sheet`,
  `product_image_uploader`, the theme picker — all still ship `CupertinoIcons`.
- **No shared confirm / destructive / input component.** `showConfirmDialog` exists but most delete
  flows still inline their own `AlertDialog`, so destructive styling (`Colors.red` vs `AppColors.error`)
  and copy vary site to site.
- **Duplicate password dialogs.** `password_dialog.dart` (amber lock chip, blue info box, max-attempts
  lockout) and `password_confirm_dialog.dart` (activity-logging, plainer) do the same job differently.
- **Hard-coded, non-token colors.** `password_dialog` uses `Colors.amber[100]/[800]`, `Colors.blue[50]/
  [200]/[700]`, `Colors.grey[600]` — none theme-aware, no dark parity.
- **Action-button conventions vary.** Order and types differ across sites: `TextButton` Cancel +
  `FilledButton` confirm (most), but `draft_detail_sheet` uses an icon-only `OutlinedButton` (red) +
  `FilledButton.icon`, the resolve sheet uses `OutlinedButton` + `FilledButton`, and the discount
  dialog adds a third `Remove` text action on the left.
- **"Dialog" vs "sheet" naming is wrong.** `stock_adjustment_dialog.dart` is actually a bottom sheet;
  callers can't tell the surface from the name.

## States & rules to preserve (don't design these away)

- **Destructive actions stay red and require an explicit confirm.** Void / delete keep the
  `AppColors.error` primary button + a clear warning line ("This action cannot be undone…").
- **Password-gated actions stay gated.** Voiding a sale, viewing cost, etc. re-auth via an obscured
  password field with show/hide toggle; `password_dialog` keeps its 3-attempt lockout, and
  `password_confirm_dialog` keeps its `ActivityLogger` audit of verify/fail. (Consolidate to ONE
  component but retain both behaviors as options.)
- **Scrollable sheets keep drag-to-resize + `SafeArea` pinned footers.** `DraggableScrollableSheet`
  min/initial/max sizes and the keyboard-aware `viewInsets` padding (stock adjustment) must survive.
- **Form sheets stay keyboard-safe** (`isScrollControlled`, `useSafeArea`, bottom `viewInsets` inset).
- **Success / error feedback stays.** Checkout success keeps the change-due hero + receipt/done actions
  (animation optional to keep). Errors keep their semantic color.
- **Snackbars are adjacent, not modal.** `showSuccessSnackBar` / `showWarningSnackBar` /
  `showErrorSnackBar` (outlined + lightened-fill, dismissible) stay as a separate feedback channel —
  do **not** fold them into the dialog shell. Just make sure their language visually rhymes with it.
- **Currency grouped** `₱1,234.00`; dates via the app formatter (`MMM d, h:mm a`, etc.).

## Target language (what to design)

Define **one dialog shell** and **one bottom-sheet shell**, both on soft-shadow surfaces with
`AppCard`-consistent radii, theme-aware colors, and **full dark parity** (canvas `#0C1415`, card
`#18262A` + hairline `#243234`, gold `#E8B84C` primary).

**Dialog shell** — header (title + optional leading status glyph + optional close), content region,
action row pinned at the bottom:
- **Cancel** = text or outlined (left/secondary), **primary** = filled (right).
- **Destructive variant** = red filled primary + warning copy.
- Drop the per-site radius/color hard-codes; everything reads from tokens.

**Bottom-sheet shell** — grab handle, optional title row (leading glyph + title + sub + close),
scrollable body, **pinned `SafeArea` footer**. One handle/header/footer implementation reused by all.

**Variants to ship from these two shells:**
1. confirm (neutral)
2. destructive-confirm (red)
3. single-input (text/number/password, with show-hide for password; absorb both password dialogs)
4. error (a real shared error dialog — replace the empty `error_dialog.dart`)
5. success
6. action-list sheet (and radio-list sheet)
7. scrollable-content sheet (sectioned body + pinned footer)
8. form sheet (keyboard-safe)

**Tokens & references:**
- Migrate all icons **Cupertino → Lucide** (e.g. `lock` → `lock`, `xmark` → `x`, `trash` → `trash-2`,
  `square_pencil` → `square-pen`, `cube_box` → `package`).
- Radii: dialogs & sheets currently use `AppRadius.xl = 24`. **Decide whether to keep 24 or move to
  `hero = 22` / `lg = 18`** for parity with the redesigned `AppCard`. Fields stay `field = 16`, pills
  `pill = 999`.
- Colors from `AppColors` (success / warning / error + `*OnDark` variants), neutral-by-default
  discipline — color only for status/destructive intent. Mono numerals in `Roboto Mono`.
- Global theme tokens at `design/handoff/maki-theme/`. Theme defaults live in
  `lib/core/theme/app_theme.dart` (`dialogTheme` ~L259 light / ~L597 dark, `bottomSheetTheme` adjacent).
