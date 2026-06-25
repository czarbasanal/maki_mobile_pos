# Bundle 05 — Receiving Theme Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the five mobile Receiving surfaces (landing, bulk receiving, batch import, drafts, history) onto the elevated global theme — `AppCard` surfaces, Lucide icons, theme-aware status tokens with full dark parity — pixel-faithful to the handoff prototype, with zero behavior change.

**Architecture:** A pure visual + icon restyle. No providers, repositories, use-cases, Firestore schema, security rules, or business logic change. One foundation task adds the missing dark-parity status-color helpers to `AppColors`; the remaining tasks consume them screen-by-screen. Each screen is an independent, reviewable restyle whose existing tests must stay green (they assert text/types/role-gating, not icons — so they act as a regression guard).

**Tech Stack:** Flutter, Riverpod, `lucide_icons`, the in-repo theme layer (`lib/core/theme/`), shared `AppCard` (`lib/presentation/shared/widgets/common/app_card.dart`).

## Global Constraints

- **Source of truth = the prototype.** `design/handoff/05-receiving/MAKI-POS-Receiving.dc.html` — match every color/hex, font size/weight, icon, spacing, radius, shadow, padding, border, badge, and copy string as built, in **both light and dark themes**. If README and prototype disagree, prototype wins — flag it.
- **Behavior-preserving.** No change to data flow, providers, use-cases, navigation targets, or copy semantics. Existing receiving tests must stay green.
- **Role-gating unchanged.** Admin-only: unit cost, search cost, line totals, total-cost summary, cost-diff badges/warnings, price-change dialog. `Permission.addProduct` for CSV new-product rows.
- **Read-only completed view** (success banner + per-line "Adjust stock" pencil), SKU-variation-on-cost-change behavior + dialog copy, CSV format/GENERATE/variation logic, draft save/resume, supplier-optional — all preserved.
- **Currency** grouped via existing formatter (`₱1,234.00`). **Dates** `MMM d, y • h:mm a`; month header `MMMM y`.
- **Single import** for tokens: `import 'package:maki_mobile_pos/core/theme/theme.dart';` exposes `AppColors`, `AppRadius`, `AppShadows`, `AppTextStyles`.
- **Lucide import:** `import 'package:lucide_icons/lucide_icons.dart';` — usage `Icon(LucideIcons.camelCaseName, size: …, color: …)`.
- **Branch:** `theme/05-receiving` (already created off `main`). Commit per task. Merge at the end.
- **Verification bar:** after every task run `flutter analyze` (hold **0 issues**) and the touched screen's existing tests. Final task runs the whole `flutter test` suite.

---

## Token & Icon Reference (applies to every task)

### Cupertino → Lucide map (from the handoff)
| Cupertino | Lucide | Where |
|---|---|---|
| `back` | `chevronLeft` | every app-bar back button |
| `cloud_upload` | `uploadCloud` | batch-import action, CSV import |
| `add` | `plus` | New Receiving |
| `square_pencil` | `squarePen` | drafts icon, adjust-stock (read-only) |
| `checkmark_circle` | `checkCircle` | completed status, Complete Receiving, done |
| `calendar` | `trendingUp` | **Received/total summary card** (icon change + color → info) |
| `cube_box` | `package` | empty states |
| `briefcase` | `briefcase` | supplier |
| `search` | `search` | product search |
| `xmark` | `x` | clear search, remove item |
| `minus_circle` / `plus_circle` | `minusCircle` / `plusCircle` | qty stepper |
| `tray_arrow_down` | `save` | Save Draft |
| `arrow_up_right` / `arrow_down_right` | `arrowUpRight` / `arrowDownRight` | cost-diff warning |
| `arrow_up` / `arrow_down` | `arrowUp` / `arrowDown` | cost-diff badge |
| `arrow_right_circle` | `arrowRightCircle` | Import N rows |
| `arrow_right` | `arrowRight` | price-change preview |
| `pencil` | `squarePen` | item-row adjust-stock |
| `trash` | `trash2` | swipe-to-delete |
| `folder_open` | `folderOpen` | CSV dialog select file |
| `exclamationmark_circle` | `alertCircle` | error banner |
| `exclamationmark_triangle` | `alertTriangle` | errored state, summary error row |
| `check_mark_circled` | `checkCircle` | batch done |
| `chevron-down` (new) | `chevronDown` | dropdown affordance |

### Status color tokens (added in Task 1, consumed everywhere)
| Semantic | Light | Dark | Helper |
|---|---|---|---|
| success icon | `#4CAF50` | `#5FC86A` | `AppColors.successIcon(dark)` |
| success badge text | `#2E7D32` | `#8FE39A` | `AppColors.successText(dark)` *(exists)* |
| success tint fill | `success` @ α | `success` @ α | `AppColors.success.withValues(alpha: …)` |
| warning/draft icon | `#F57C00` | `#F5B547` | `AppColors.warningIcon(dark)` |
| draft badge text | `#9A6300` | `#F5B547` | `AppColors.warningBadgeText(dark)` |
| draft tint fill | `warningDark` @ α | `warningOnDark` @ α | base `.withValues(alpha: …)` |
| info icon | `#2196F3` | `#5AA9F0` | `AppColors.infoIcon(dark)` |
| info/new badge text | `#1976D2` | `#7FB6FF` | `AppColors.infoBadgeText(dark)` |
| cost-up (worse) | `#C62828` | `#FF6B5E` | `AppColors.costUp(dark)` |
| cost-down (better) | `#2E7D32` | `#8FE39A` | `AppColors.costDown(dark)` |
| muted text | `#8A9296` | `#93A0A3` | `theme.colorScheme.onSurfaceVariant` |

Tint alphas used by the prototype: status leading circle `.10` light / `.16` dark; list/badge fills `successLight`(#E8F5E9) or `.18` dark; draft `.12`–`.14` light / `.16`–`.18` dark; cost-warning `.10` light / `.14` dark; chip fills `.13` light / `.18`–`.20` dark. Read the exact alpha per element from the prototype.

### Reusable patterns (quoted from bundle 04 — mirror these)

**App-bar soft bottom shadow** — wrap the standard `AppBar` in `PreferredSize` only if a shadow line is needed; otherwise the base `AppBar` is fine (inventory uses the base bar). Prototype app bars are flat with no divider, so **keep the standard `AppBar`** unless a screen shows a shadow.

**Pinned footer (single primary button)** — bulk "Complete Receiving" and landing "New Receiving":
```dart
Widget _buildFooter(BuildContext context, {required Widget child}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return Container(
    decoration: BoxDecoration(
      color: theme.scaffoldBackgroundColor,
      boxShadow: AppShadows.pinnedFooter(dark: isDark),
    ),
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: child, // a DecoratedBox(primaryButton/Gold shadow) wrapping a 50-high FilledButton
    ),
  );
}
```
Primary button shadow: `isDark ? AppShadows.primaryButtonGold : AppShadows.primaryButton`; height 50; `RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field))`.

**Stat card** (summary row) — `AppCard(radius: AppRadius.field, …)` with vertical icon → value (`22/700`, or `20/700` for the wide ₱ stat) → muted label (`11`).

**AppCard** signature: `AppCard({required child, padding, margin, radius = AppRadius.lg, onTap, clipBehavior})`. Light = soft shadow; dark = `#18262A` + 1px `#243234`. Use `onTap` instead of wrapping in `InkWell`.

---

## Task 1: Foundation — dark-parity status color helpers

**Files:**
- Modify: `lib/core/theme/app_colors.dart` (append to the semantic-colors region, ~line 120)
- Test: `test/core/theme/app_colors_status_test.dart` (create)

**Interfaces:**
- Produces: `AppColors.successIcon(bool dark)`, `AppColors.warningIcon(bool dark)`, `AppColors.warningBadgeText(bool dark)`, `AppColors.infoIcon(bool dark)`, `AppColors.infoBadgeText(bool dark)`, `AppColors.costUp(bool dark)`, `AppColors.costDown(bool dark)`, and constants `warningOnDark`, `infoOnDarkIcon`, `infoOnDarkText`, `errorOnDark`, `successOnDarkIcon`. (`successText(bool)` and `successOnDark` already exist.)

- [ ] **Step 1: Write the failing test**

```dart
// test/core/theme/app_colors_status_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/theme/app_colors.dart';

void main() {
  group('AppColors status helpers — light/dark parity', () {
    test('success icon', () {
      expect(AppColors.successIcon(false), const Color(0xFF4CAF50));
      expect(AppColors.successIcon(true), const Color(0xFF5FC86A));
    });
    test('warning icon + badge text', () {
      expect(AppColors.warningIcon(false), const Color(0xFFF57C00));
      expect(AppColors.warningIcon(true), const Color(0xFFF5B547));
      expect(AppColors.warningBadgeText(false), const Color(0xFF9A6300));
      expect(AppColors.warningBadgeText(true), const Color(0xFFF5B547));
    });
    test('info icon + badge text', () {
      expect(AppColors.infoIcon(false), const Color(0xFF2196F3));
      expect(AppColors.infoIcon(true), const Color(0xFF5AA9F0));
      expect(AppColors.infoBadgeText(false), const Color(0xFF1976D2));
      expect(AppColors.infoBadgeText(true), const Color(0xFF7FB6FF));
    });
    test('cost-diff up/down', () {
      expect(AppColors.costUp(false), const Color(0xFFC62828));
      expect(AppColors.costUp(true), const Color(0xFFFF6B5E));
      expect(AppColors.costDown(false), const Color(0xFF2E7D32));
      expect(AppColors.costDown(true), const Color(0xFF8FE39A));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/theme/app_colors_status_test.dart`
Expected: FAIL — `successIcon` / `warningIcon` / etc. not defined.

- [ ] **Step 3: Add the helpers**

Append inside the `AppColors` class (after the existing `info*` block, before `draft`):

```dart
// ── Status dark-parity variants (Receiving bundle 05) ──
static const Color successOnDarkIcon = Color(0xFF5FC86A);
static Color successIcon(bool dark) => dark ? successOnDarkIcon : success;

static const Color warningOnDark = Color(0xFFF5B547);
static const Color warningTextLight = Color(0xFF9A6300);
static Color warningIcon(bool dark) => dark ? warningOnDark : warningDark;
static Color warningBadgeText(bool dark) => dark ? warningOnDark : warningTextLight;

static const Color infoOnDarkIcon = Color(0xFF5AA9F0);
static const Color infoTextLight = Color(0xFF1976D2);
static const Color infoOnDarkText = Color(0xFF7FB6FF);
static Color infoIcon(bool dark) => dark ? infoOnDarkIcon : info;
static Color infoBadgeText(bool dark) => dark ? infoOnDarkText : infoTextLight;

static const Color errorOnDark = Color(0xFFFF6B5E);
static Color costUp(bool dark) => dark ? errorOnDark : errorDark;
static Color costDown(bool dark) => dark ? successOnDark : successDark;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/theme/app_colors_status_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Analyze + commit**

```bash
flutter analyze lib/core/theme/app_colors.dart test/core/theme/app_colors_status_test.dart
git add lib/core/theme/app_colors.dart test/core/theme/app_colors_status_test.dart
git commit -m "feat(theme): dark-parity status color helpers for receiving migration"
```

---

## Task 2: ReceivingSummaryCardsRow (widget)

**Files:**
- Modify: `lib/presentation/mobile/widgets/receiving/receiving_summary_cards_row.dart` (221 lines)
- Test (regression, keep green): `test/presentation/widgets/receiving_summary_cards_row_test.dart`

**Prototype reference:** landing summary stats, prototype lines 60–63 (light) / 269–272 (dark).

**Consumes:** `AppColors.successIcon/warningIcon/infoIcon` (Task 1).

- [ ] **Step 1: Swap the card surface to `AppCard`.** The `_CountCard` `Container(decoration: BoxDecoration(color: …withValues(alpha:0.1), border:…, borderRadius:12))` (lines 126–132) → `AppCard(radius: AppRadius.field, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6), onTap: onTap, child: Column(...))`. Drop the manual `InkWell` (lines 171–175) — use `AppCard.onTap`.

- [ ] **Step 2: Restyle the card column** to icon (`size: 20`, status color) → value (`fontSize: 22, fontWeight: w700, height: 1`; the ₱ Received value uses `fontSize: 20`) → label (`fontSize: 11`, `theme.colorScheme.onSurfaceVariant`). Replace `Colors.grey[600]` (line 163) with the muted scheme color.

- [ ] **Step 3: Swap icons + colors.** Drafts: `CupertinoIcons.square_pencil`→`LucideIcons.squarePen`, color `AppColors.warningIcon(isDark)` (was `Colors.orange`, line 61–62). Completed: `checkmark_circle`→`checkCircle`, `AppColors.successIcon(isDark)` (was `Colors.green`, 71–72). Received: **`calendar`→`trendingUp`**, `AppColors.infoIcon(isDark)` (was `Colors.blue`, 82–83). Error row (line 201): `exclamationmark_triangle`→`alertTriangle`. Add `final isDark = Theme.of(context).brightness == Brightness.dark;` where needed and the two imports (`lucide_icons`, drop `flutter/cupertino.dart`).

- [ ] **Step 4: Verify tests + analyze.**

Run: `flutter test test/presentation/widgets/receiving_summary_cards_row_test.dart && flutter analyze lib/presentation/mobile/widgets/receiving/receiving_summary_cards_row.dart`
Expected: PASS (labels/peso/error/tap assertions unchanged) + 0 issues.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/receiving/receiving_summary_cards_row.dart
git commit -m "style(receiving): summary cards → AppCard + Lucide + status tokens (bundle 05)"
```

---

## Task 3: Receiving landing screen

**Files:**
- Modify: `lib/presentation/mobile/screens/receiving/receiving_screen.dart` (277 lines)
- Test (regression): none icon-based; run the suite at the end.

**Prototype reference:** screen 1, prototype lines 48–88 (light) / 258–297 (dark).

**Consumes:** Task 1 helpers + the pinned-footer pattern + Task 2 widget.

- [ ] **Step 1: App bar icons.** `CupertinoIcons.back`→`LucideIcons.chevronLeft` (line 29), `cloud_upload`→`LucideIcons.uploadCloud` (line 36). Keep the standard `AppBar` (prototype bar is flat). Imports: add `lucide_icons`, remove `flutter/cupertino.dart`.

- [ ] **Step 2: Recent-Receivings header** (the `_SectionHeader` near line 50) → "Recent Receivings" `fontSize: 16, fontWeight: w700` on the left + "View all" `fontSize: 13, fontWeight: w600` in `AppColors.brandSlate`/`primaryAccent` on the right (prototype line 65).

- [ ] **Step 3: List rows → `AppCard`.** Replace the `Card`+`ListTile` (lines 136–204) with an `AppCard(radius: AppRadius.field, padding: const EdgeInsets.all(12), onTap: …)` holding a `Row`: 40×40 status **leading circle** (`borderRadius: 11`, fill = status color `.withValues(alpha: isDark ? 0.16 : 0.10)`, centered status icon size 20) → middle `Column` (ref# `RobotoMono 13/600`, then `date · time · supplier` muted `12`, ellipsis) → trailing `Column` (status **badge** + `N items` muted `12` + ₱total `13/700` *admin*). Status icon/colors via Task 1 helpers; badge fill/text per prototype (completed `successLight`/`successText`; draft `warningDark`@.14 / `warningBadgeText`). Status mapping reuses the existing `status` switch (lines ~207–224) — swap its `CupertinoIcons` (`checkmark_circle`/`square_pencil`/`xmark` → `checkCircle`/`squarePen`/`x`) and its `Colors.green/orange/grey` → tokens.

- [ ] **Step 4: Empty state** (line 93) `cube_box`→`package`, `Colors.grey[400]`→muted; subtitle greys (lines 100, 106) → `onSurfaceVariant`.

- [ ] **Step 5: Pinned "New Receiving".** The current `BottomNavigationBar` (line 69) with `CupertinoIcons.add` (line 75) → the pinned-footer pattern (Global Constraints) wrapping a 50-high `FilledButton.icon(icon: Icon(LucideIcons.plus, size: 18), label: Text('New Receiving'))` with `primaryButton`/`primaryButtonGold` shadow. Wire to the same navigation callback the old button used.

- [ ] **Step 6: Verify.**

Run: `flutter analyze lib/presentation/mobile/screens/receiving/receiving_screen.dart`
Expected: 0 issues. Then `flutter test test/presentation/widgets/receiving_summary_cards_row_test.dart` (landing embeds it) — PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/mobile/screens/receiving/receiving_screen.dart
git commit -m "style(receiving): landing → AppCard rows, status circles, pinned footer, Lucide (bundle 05)"
```

---

## Task 4: ReceivingItemRow (widget)

**Files:**
- Modify: `lib/presentation/mobile/widgets/receiving/receiving_item_row.dart` (299 lines)

**Prototype reference:** bulk item rows, prototype lines 117–134 (light) / 323–340 (dark).

**Consumes:** Task 1 `costUp/costDown/infoBadgeText`.

- [ ] **Step 1: Surface → `AppCard`.** The `Card` (line 124) → `AppCard(radius: AppRadius.field, padding: const EdgeInsets.all(12), child: Row(...))`. Keep the `Dismissible` wrapper (lines 43–54); swipe bg `Colors.red`→`AppColors.error`, `CupertinoIcons.trash`→`LucideIcons.trash2` (line 50, keep `Colors.white` icon on the red bg).

- [ ] **Step 2: Quantity stepper.** `CupertinoIcons.minus_circle`→`LucideIcons.minusCircle` (line 218), `plus_circle`→`plusCircle` (line 248), size 22, color `AppColors.brandSlate` light / `primaryAccent` dark. Qty field box: `40×36`, `border: 1px lightInputBorder/darkInputBorder`, `borderRadius: AppRadius.sm (10)`, fill `lightSurfaceMuted`/`darkCanvas`, `14/600`.

- [ ] **Step 3: Badges.** New-Variant (lines 154–171): bg `AppColors.info.withValues(alpha: isDark?0.20:0.13)`, text `AppColors.infoBadgeText(isDark)`, `Figtree 10/600`, `borderRadius: 6` (replace `Colors.blue[100]/[700]`). Cost-diff badge (lines 96–121): outlined, `border` + text = `costUp(isDark)`/`costDown(isDark)`; arrow `CupertinoIcons.arrow_up/down`→`LucideIcons.arrowUp/arrowDown` (line 106), `size: 11`.

- [ ] **Step 4: Trailing + misc colors.** Remove `x`: `CupertinoIcons.xmark`→`LucideIcons.x` (line 283), `Colors.grey[400]`→muted. Adjust-stock (read-only): `CupertinoIcons.pencil`→`LucideIcons.squarePen` (line 289). SKU/unit greys (lines 148, 272) → `onSurfaceVariant`. Imports: add `lucide_icons`, drop `flutter/cupertino.dart`.

- [ ] **Step 5: Verify.**

Run: `flutter analyze lib/presentation/mobile/widgets/receiving/receiving_item_row.dart`
Expected: 0 issues. (No dedicated widget test; covered by bulk screen + analyze.)

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/widgets/receiving/receiving_item_row.dart
git commit -m "style(receiving): item row → AppCard, Lucide stepper, token badges (bundle 05)"
```

---

## Task 5: Bulk receiving screen

**Files:**
- Modify: `lib/presentation/mobile/screens/receiving/bulk_receiving_screen.dart` (807 lines)
- Test (regression): `test/presentation/providers/current_receiving_notifier_test.dart` (logic, unaffected — run to confirm).

**Prototype reference:** screen 2, prototype lines 90–141 (light) / 299–347 (dark). This is the largest screen — work top-to-bottom.

**Consumes:** Task 1 helpers, Task 4 item row, the pinned-footer pattern.

- [ ] **Step 1: App bar.** `back`→`chevronLeft` (line 82), title "Receive Stock"/"Receiving Details" + ref# subtitle `RobotoMono 12` muted (keep existing logic). `cloud_upload`→`uploadCloud` (line 102). Save Draft `TextButton.icon`: `CupertinoIcons.tray_arrow_down`→`LucideIcons.save` (line 109), label "Draft", `brandSlate`/`primaryAccent`, disabled-when-empty unchanged.

- [ ] **Step 2: Read-only banner** (lines 146–176): already uses `AppColors.successLight/successDark` — swap `CupertinoIcons.checkmark_circle`→`LucideIcons.checkCircle` (line 157); confirm dark parity uses `successFill(isDark)`/`successText(isDark)`.

- [ ] **Step 3: Supplier field** (lines 182–233): label "Supplier" `12` muted; field `min-height 48`, fill `lightSurfaceMuted`/`darkCard`, `border 1px lightInputBorder/darkInputBorder`, `borderRadius: AppRadius.md (14)`; `CupertinoIcons.briefcase`→`LucideIcons.briefcase` (line 186, color muted, drop bare `Colors.grey`); trailing `LucideIcons.chevronDown`. Keep `AppDropdown` behavior.

- [ ] **Step 4: Add-Product panel** (lines 237–376) → `AppCard(radius: AppRadius.field, padding: const EdgeInsets.all(14))` (replace the `Colors.grey[50]` container, line 239). Header "Add Product" `13/700`. Search row: `search`→`search` Lucide (line 268), clear `xmark`→`x` (line 272), hint `9AA0A3`/`6C797C`. **Two-up inputs:** Quantity (`flex: .85`) + Unit Cost (`flex: 1`, admin-only, ₱ prefix) on one `Row` with the slate **Add** button (`height 46`, `AppRadius.md`, `brandSlate`/`primaryAccent`), per prototype lines 109–113. Cost-diff warning (lines 393–425): bg `warningDark.withValues(alpha: isDark?0.14:0.10)`, border same @.30/.34, text `warningBadgeText(isDark)`, `arrow_up_right/arrow_down_right`→`arrowUpRight/arrowDownRight` (lines 406–407). Drop `Colors.orange/blue` (these were up/down-colored; prototype uses the single warning tint for the "will create variation" notice).

- [ ] **Step 5: Items list** — already renders Task 4 `ReceivingItemRow`; just confirm the surrounding `Card` (line 467) / empty-state greys (lines 439, 445, 451) → `package` icon + muted tokens.

- [ ] **Step 6: Pinned summary + Complete** (lines 498–588) → pinned-footer pattern. Summary row: left `N products / M total units` muted `13`; right `Total Cost` muted `12` + value `22/700` (admin). Button: `FilledButton.icon(icon: Icon(LucideIcons.checkCircle, size: 18), label: Text('Complete Receiving'))`, height 50, `primaryButton`/`primaryButtonGold`, spinner while processing (keep existing state). Replace the `Container` BoxShadow (lines 500–507) with `AppShadows.pinnedFooter(dark: isDark)`. Error text `Colors.red` (line 559)→`AppColors.error`. Price-change preview `arrow_right`→`arrowRight` (line 792).

- [ ] **Step 7: Verify.**

Run: `flutter analyze lib/presentation/mobile/screens/receiving/bulk_receiving_screen.dart && flutter test test/presentation/providers/current_receiving_notifier_test.dart`
Expected: 0 issues + PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/mobile/screens/receiving/bulk_receiving_screen.dart
git commit -m "style(receiving): bulk receive → AppCard panel, two-up inputs, pinned Complete, Lucide (bundle 05)"
```

---

## Task 6: Batch import (screen + ImportPreview + CsvImportDialog)

**Files:**
- Modify: `lib/presentation/mobile/screens/receiving/batch_import_screen.dart` (450 lines)
- Modify: `lib/presentation/mobile/widgets/receiving/import_preview.dart` (221 lines)
- Modify: `lib/presentation/mobile/widgets/receiving/csv_import_dialog.dart` (188 lines)
- Tests (regression): `test/presentation/widgets/csv_import_dialog_test.dart`, `test/core/utils/batch_import_test.dart` — keep green.

**Prototype reference:** screen 3, prototype lines 143–188 (light) / 349–391 (dark).

- [ ] **Step 1: Batch import screen icons.** `back`→`chevronLeft` (143), `cloud_upload`→`uploadCloud` (179, 400→ supplier filter `briefcase` stays Lucide `briefcase`), error banner `exclamationmark_circle`→`alertCircle` (219), import `arrow_right_circle`→`arrowRightCircle` (254), done `check_mark_circled`→`checkCircle` (272), errored `exclamationmark_triangle`→`alertTriangle` (310). Imports: add `lucide_icons`, drop `flutter/cupertino.dart`.

- [ ] **Step 2: Surfaces → `AppCard`.** CSV-format help `Card` (lines 337–365) → `AppCard(radius: AppRadius.md)`. Error banner `Container` (lines 430–448): bg `AppColors.error.withValues(alpha: isDark?0.12:0.07)`, border `error` @.40/.45, `borderRadius: AppRadius.field`, title `13/600` + rows `12` `errorDark`/`errorOnDark`. Bottom Cancel/Import bar → pinned-footer surface (`pinnedFooter` shadow); Cancel = outlined `AppCard`-style, Import = slate `primaryButton`.

- [ ] **Step 3: ImportPreview** (already token-based) — verify chips match prototype exactly: Match `successText/successFill`, Cost variation `warningBadgeText` on `warningDark`@.13/.18, New product `infoBadgeText` on `info`@.13/.20, Errors `errorDark/error`@.12. Classified row `Card` (lines 170–220) → `AppCard(radius: AppRadius.field)`; name `14/600`, sub `RobotoMono 12` muted, badge per class. Adjust the `_Chip` `borderRadius` to `AppRadius.pill` (already) and confirm dark alphas.

- [ ] **Step 4: CsvImportDialog icons.** `cloud_upload`→`uploadCloud` (129), `folder_open`→`folderOpen` (153). Drop `flutter/cupertino.dart`, add `lucide_icons`.

- [ ] **Step 5: Verify.**

Run: `flutter test test/presentation/widgets/csv_import_dialog_test.dart test/core/utils/batch_import_test.dart && flutter analyze lib/presentation/mobile/screens/receiving/batch_import_screen.dart lib/presentation/mobile/widgets/receiving/import_preview.dart lib/presentation/mobile/widgets/receiving/csv_import_dialog.dart`
Expected: PASS + 0 issues.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/screens/receiving/batch_import_screen.dart lib/presentation/mobile/widgets/receiving/import_preview.dart lib/presentation/mobile/widgets/receiving/csv_import_dialog.dart
git commit -m "style(receiving): batch import full pass → AppCard, token chips, Lucide (bundle 05)"
```

---

## Task 7: Drafts list screen

**Files:**
- Modify: `lib/presentation/mobile/screens/receiving/receiving_drafts_screen.dart` (101 lines)
- Test (regression): none direct; analyze + suite.

**Prototype reference:** screen 4, prototype lines 190–212 (light) / 393–415 (dark).

- [ ] **Step 1: Icons + surface.** `back`→`chevronLeft` (24), empty-state `square_pencil`→`squarePen` (33). `_DraftItem` `Card`+`ListTile` (lines 64–100) → `AppCard(radius: AppRadius.field, padding: const EdgeInsets.all(13), onTap: …)` with `Row`: 40×40 leading circle (`borderRadius: 11`, `warningDark.withValues(alpha: isDark?0.16:0.12)`, `LucideIcons.squarePen` size 20 `warningIcon(isDark)`) → middle `Column` (ref# `RobotoMono 13/600`; `N items · M units · date` muted `12`) → trailing "Resume" `13/600` `brandSlate`/`primaryAccent`.

- [ ] **Step 2: Colors.** Replace `Colors.orange[50]/[700]` (70, 73) with tokens; `Colors.grey[700]/[600]` (84, 88) → `onSurfaceVariant`. Imports: add `lucide_icons`, `theme.dart`; drop `flutter/cupertino.dart`.

- [ ] **Step 3: Verify + commit.**

Run: `flutter analyze lib/presentation/mobile/screens/receiving/receiving_drafts_screen.dart`
Expected: 0 issues.
```bash
git add lib/presentation/mobile/screens/receiving/receiving_drafts_screen.dart
git commit -m "style(receiving): drafts list → AppCard rows + tokens + Lucide (bundle 05)"
```

---

## Task 8: Receiving history screen

**Files:**
- Modify: `lib/presentation/mobile/screens/receiving/receiving_history_screen.dart` (192 lines)
- Test (regression): `test/presentation/widgets/receiving_history_screen_test.dart` — keep green (month ordering, empty state, draft filtering).

**Prototype reference:** screen 5, prototype lines 214–247 (light) / 417+ (dark).

- [ ] **Step 1: Icons + surface.** `back`→`chevronLeft` (31), empty `cube_box`→`package` (44), completed `checkmark_circle`→`checkCircle` (147). `_ReceivingHistoryItem` `Card` (line 137) → `AppCard(radius: AppRadius.field, padding: const EdgeInsets.all(12), onTap: …)` with `Row`: 40×40 success leading circle (`success`@.10/.16, `successIcon(isDark)` size 20) → middle (ref# `RobotoMono 13/600`; `date · supplier` muted `12`) → trailing (`N items` muted `12` + ₱total `13/700` *admin*).

- [ ] **Step 2: Month header** (`_MonthHeader`, lines ~60–63 / rendered near 224): `MMMM y` `12/600` uppercase `letterSpacing: .8` `onSurfaceVariant` + count `12` hint. Replace `Colors.green[50]/[700]` (143, 147) and `Colors.grey[600]` (160, 165) with tokens. Imports: add `lucide_icons`; drop `flutter/cupertino.dart`.

- [ ] **Step 3: Verify + commit.**

Run: `flutter test test/presentation/widgets/receiving_history_screen_test.dart && flutter analyze lib/presentation/mobile/screens/receiving/receiving_history_screen.dart`
Expected: PASS + 0 issues.
```bash
git add lib/presentation/mobile/screens/receiving/receiving_history_screen.dart
git commit -m "style(receiving): history → AppCard rows, month header, tokens, Lucide (bundle 05)"
```

---

## Task 9: Full-suite verification + branch finish

- [ ] **Step 1: Whole suite + analyze.**

Run: `flutter analyze` then `flutter test`
Expected: **0 issues**; all tests pass (baseline 722 + 4 new = 726).

- [ ] **Step 2: Cupertino sweep.** Confirm no stray Cupertino icons remain in receiving:

Run: `grep -rn "CupertinoIcons" lib/presentation/mobile/screens/receiving lib/presentation/mobile/widgets/receiving`
Expected: no matches (and no leftover `import 'package:flutter/cupertino.dart';` unless used for `CupertinoActivityIndicator`-style non-icon widgets — verify each).

- [ ] **Step 3: Manual pixel-fidelity check** (per `/verify`). Run the app (`flutter run`), open each of the 5 receiving screens in **light and dark**, and compare against `design/handoff/05-receiving/MAKI-POS-Receiving.dc.html` + `screenshots/`. Check: status colors, AppCard shadows/dark hairline, Lucide icons, two-up bulk inputs, pinned footers, badge tints. Note any deviation; fix and re-commit.

- [ ] **Step 4: `/code-review`** the branch diff for regressions (role-gating preserved, no behavior drift, no dead Cupertino imports).

- [ ] **Step 5: Finish branch** (`finishing-a-development-branch`): merge `theme/05-receiving` → `main` (mirror bundle 04's `--no-ff` merge commit), update the redesign memory + handoff `ROADMAP.md` to mark bundle 05 done.

---

## Self-Review

**Spec coverage:** ✅ All five screens (Tasks 3, 5, 6, 7, 8) + the three shared widgets (Tasks 2, 4, 6) + foundation tokens (Task 1). Status-color migration (Task 1 + consumed throughout), `AppCard` surfaces (every task), Cupertino→Lucide (every task + Task 9 sweep), bulk two-up inputs + pinned Complete (Task 5), batch full pass (Task 6), dark parity (every task, Task 9 manual check), all must-keeps preserved (role-gating noted per task; logic untouched). Currency/date formats untouched (no edits to formatters).

**Placeholder scan:** No "TBD"/"handle edge cases". Each task names exact files, line numbers, prototype reference lines, exact icon/color identifiers, and verification commands. The foundation task is full TDD code; screen tasks are precise transform lists keyed to the in-repo prototype (the stated pixel-faithful source of truth) rather than fabricated full-file rewrites — appropriate for a behavior-preserving restyle.

**Type consistency:** Task 1 produces `successIcon/warningIcon/warningBadgeText/infoIcon/infoBadgeText/costUp/costDown` (all `(bool dark) → Color`) + constants; Tasks 2–8 consume exactly those names. `successText(bool)`/`successFill(bool)`/`successOnDark` referenced as already-existing (confirmed in app_colors.dart). `AppCard` named params (`radius`/`padding`/`margin`/`onTap`) and `AppShadows.pinnedFooter(dark:)`/`primaryButton`/`primaryButtonGold` match the verified signatures.
