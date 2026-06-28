# End-of-Day Redesign (Bundle 06b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Migrate the cash-drawer closing flow (End-of-Day open form, closed read-only view, Closing History) onto the elevated theme — soft-shadow `AppCard` sections, Lucide icons, app field styling, variance color semantics — pixel-faithful to the 06b hand-off, behavior-preserving (no reconciliation math changed).

**Architecture:** Pure restyle of two files (`end_of_day_screen.dart`, `daily_closing_history_screen.dart`). One new pure helper `VarianceStyle` centralizes the balanced/short/over → color/tint/icon/word mapping, reused by the form, closed view, and every history row. Small shared presentation widgets (section card, KV row, variance panel/pill, labeled field) live in a new `closing_widgets.dart`.

**Tech Stack:** Flutter, Riverpod, `lucide_icons ^0.257.0`, bundled Figtree, `flutter_test`.

## Global Constraints

- **Source of truth:** `design/design_handoff_eod/MAKI POS End of Day.dc.html` — HTML wins over the README on any conflict. Match light + dark pixel-for-pixel.
- **Never change a figure or formula** — expected cash, variance, after-close totals are computed elsewhere; restyle only.
- Reuse `lib/core/theme/` tokens (`AppColors`, `AppRadius`, `AppShadows`) + `AppCard`; component-specific literal radii (13, 14) allowed inline. No new theme tokens.
- **`AppCard`** everywhere a section/card exists (no Material `Card`). Light = soft shadow; dark = `darkCard` + 1px `darkHairline`.
- **Icons → Lucide** (`package:lucide_icons/lucide_icons.dart`). Section icons: Sales `receipt`, Expenses `arrowDownCircle`, Plate `clipboardList`, Cash recon `calculator`, After close `clock` (amber); back `chevronLeft`, history action `history`, close `lock`, post-close `alertTriangle`, closed-by `badgeCheck`, history meta `user`, expand `chevronUp`/`chevronDown`; variance balanced `check` / short `trendingDown` / over `trendingUp`.
- **Variance color semantics (must keep), `counted − expected`:** balanced(=0) green (`success`/`successOnDark`), short(<0) red (`error`/`errorOnDark`), over(>0) amber (`warningDark`/`warningOnDark`). Form & closed view = tinted **panel** (radius 13, pad 12×14, value 17/700 nowrap); history rows = tinted **pill** (12/700, icon + signed amount).
- **Primary flips by theme:** `theme.colorScheme.primary` = slate light / gold dark — used for section icons, Expected-cash & Updated-cash values, Counted-cash focus border.
- Currency `toCurrencyWithoutSymbol()` + `₱` prefix. Dates `EEE, MMM d, y` and `MMM d, h:mm a`.
- App bars flat on canvas. Body scroll padding `14,16,20`. Sections `margin-bottom: 12`.
- Preserve: section order (Sales → Expenses → Plate No Orders → Cash reconciliation → Notes → Close Day); cash-recon order (Opening float → Expected cash emphasis → Counted cash required → Variance); conditional Sales rows render only when > 0 (incl. Salmon receivable); closed view immutable + confirm dialog before closing; post-close amber warning + After-close card (conditional).
- Verify after each task: `flutter test` (changed) + `flutter analyze` clean.

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `lib/presentation/mobile/widgets/reports/variance_style.dart` | Pure variance → {state, color, panelTint, pillTint, icon, word} per theme | Create |
| `lib/presentation/mobile/widgets/reports/closing_widgets.dart` | Shared `ClosingSectionCard`, `ClosingKvRow`, `VariancePanel`, `VariancePill`, `ClosingField` | Create |
| `lib/presentation/mobile/widgets/reports/reports_widgets.dart` | Barrel — export the two new files | Modify |
| `lib/presentation/mobile/screens/reports/end_of_day_screen.dart` | Open form + `_ClosedView` restyle | Modify |
| `lib/presentation/mobile/screens/reports/daily_closing_history_screen.dart` | Expandable `AppCard` rows + variance pill | Modify |
| `test/presentation/widgets/variance_style_test.dart` | Helper unit tests | Create |
| `test/presentation/widgets/daily_closing_history_test.dart` | Variance pill state + expand/collapse | Create |

---

## Task 1: VarianceStyle helper (TDD)

**Files:** Create `lib/presentation/mobile/widgets/reports/variance_style.dart`; Test `test/presentation/widgets/variance_style_test.dart`; Modify barrel.

**Interfaces — Produces:**
- `enum VarianceState { balanced, short, over }`
- `VarianceState varianceStateOf(double variance)` — `> 0.005 → over`, `< -0.005 → short`, else `balanced`.
- `VarianceStyle.of(double variance, {required bool dark}) → VarianceStyle` returning fields: `state`, `Color text`, `Color panelTint`, `Color pillTint`, `IconData icon`, `String word`.

Values (ARGB): text balanced `success`/`successOnDark`(0xFF8FE39A); short `error`(0xFFF44336)/`errorOnDark`(0xFFFF6B5E); over `warningDark`(0xFFF57C00)/`warningOnDark`(0xFFF5B547). panelTint light: balanced `0x144CAF50`(.08) / short `0x12F44336`(.07) / over `0x17F57C00`(.09); dark: balanced `0x294CAF50`(.16) / short `0x1FFF6B5E`(.12) / over `0x1FF5B547`(.12). pillTint light: balanced `0xFFE8F5E9` / short `0x1AF44336`(.10) / over `0x1FF57C00`(.12); dark: balanced `0x294CAF50` / short `0x24FF6B5E`(.14) / over `0x24F5B547`(.14). icon: balanced `LucideIcons.check` / short `LucideIcons.trendingDown` / over `LucideIcons.trendingUp`. word: "Balanced"/"Short"/"Over".

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/widgets/variance_style_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/variance_style.dart';

void main() {
  group('varianceStateOf', () {
    test('classifies by sign with a cent tolerance', () {
      expect(varianceStateOf(0), VarianceState.balanced);
      expect(varianceStateOf(0.004), VarianceState.balanced);
      expect(varianceStateOf(-20), VarianceState.short);
      expect(varianceStateOf(50), VarianceState.over);
    });
  });

  group('VarianceStyle.of', () {
    test('short = red trending-down, over = amber trending-up, balanced = green check', () {
      expect(VarianceStyle.of(-20, dark: false).icon, LucideIcons.trendingDown);
      expect(VarianceStyle.of(-20, dark: false).word, 'Short');
      expect(VarianceStyle.of(50, dark: false).icon, LucideIcons.trendingUp);
      expect(VarianceStyle.of(0, dark: false).icon, LucideIcons.check);
      expect(VarianceStyle.of(0, dark: false).word, 'Balanced');
    });

    test('text color flips with theme', () {
      expect(VarianceStyle.of(-20, dark: false).text, const Color(0xFFF44336));
      expect(VarianceStyle.of(-20, dark: true).text, const Color(0xFFFF6B5E));
    });
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`variance_style.dart` missing). `flutter test test/presentation/widgets/variance_style_test.dart`

- [ ] **Step 3: Implement** `variance_style.dart` per the values above (switch on `varianceStateOf`). Add `export 'variance_style.dart';` and `export 'closing_widgets.dart';` to `reports_widgets.dart` (closing_widgets created in Task 2 — add its export in Task 2 to keep this task compiling, or stub now).

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit** `feat(closing): variance style helper (balanced/short/over, dark parity)`

---

## Task 2: Shared closing widgets + Closing History (TDD)

**Files:** Create `closing_widgets.dart`; Modify `daily_closing_history_screen.dart`; Modify barrel; Test `test/presentation/widgets/daily_closing_history_test.dart`.

**Interfaces — Produces (in `closing_widgets.dart`):**
- `ClosingSectionCard({required IconData icon, required String title, required List<Widget> children})` — `AppCard(padding 16)`, header (icon 19 primary + title 15/700), then children.
- `ClosingKvRow({required String label, required String value, bool indented = false, bool dense = false})` — space-between row; label muted (hint when indented), value 600 (or 500 when `dense` for history); `dense` = 13px/pad 3, else 14px/pad 5; indented adds left pad 16 (14 in history) + value color `#5A6468`/`#AEC0C6`.
- `VariancePanel({required double variance})` — tinted panel per `VarianceStyle`: left "Variance" 14/600 + chip (icon+word 10/600), right value 17/700 nowrap.
- `VariancePill({required double variance})` — tinted pill (icon + signed amount 12/700).
- `ClosingField({required String label, String? value, String? hintText, bool focused = false, bool required = false})` — label-above (12, muted; primary when focused) + filled box (min-h 48, radius 14, fill `lightSurfaceMuted`/`darkCanvas`, border `lightInputBorder`/`darkInputBorder`; focused = 1.5px primary + focus-ring shadow) with a `₱` prefix; displays `value` or `hintText`. *(Display shell — the real `TextFormField` wiring stays in the screen; this widget renders the box; see Task 3 note.)*

**History row** (HTML 162–205): expandable `AppCard(radius 16)`. Header (pad 14×16, gap 12): left date 14/700 + sub (12 muted) "Cash on hand **₱…**" / "Closed {MMM d, h:mm a}"; trailing `VariancePill` + chevron (`chevronUp` open / `chevronDown` closed). Expanded (top hairline, pad 12×16×14): dense KV rows (Gross/Cash/Non-cash → indented GCash/Maya when >0, Total/Cash expenses, Opening float, Expected cash, Counted cash) + meta line (`user` 13 + "Closed by {name} · {MMM d, y · h:mm a}"). Empty = centered "No closings yet."

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/widgets/daily_closing_history_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/daily_closing_history_screen.dart';

// Build DailyClosingEntity fixtures (one short, one over) — read
// daily_closing_entity.dart for the constructor + variance getter, and
// daily_closing_provider.dart for dailyClosingHistoryProvider's type, then
// override it with AsyncData([...]). Mirror an existing provider-override test.

void main() {
  testWidgets('history shows a red short pill and an amber over pill', (tester) async {
    // pump DailyClosingHistoryScreen with two closings (variance -20 and +50)
    // expect(find.byIcon(LucideIcons.trendingDown), findsWidgets);
    // expect(find.byIcon(LucideIcons.trendingUp), findsWidgets);
  });

  testWidgets('tapping a row expands its reconciliation', (tester) async {
    // tap first row header → expect 'Expected cash' detail visible
  });
}
```
> Fill bodies by reading `lib/domain/entities/daily_closing_entity.dart` (ctor + `variance`) and `lib/presentation/providers/daily_closing_provider.dart` (`dailyClosingHistoryProvider`). Override with `AsyncData`.

- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3: Implement** `closing_widgets.dart` + restyle `daily_closing_history_screen.dart` (replace `ExpansionTile`/`Card` with a `StatefulWidget` expandable `AppCard` row using `VariancePill` + `ClosingKvRow`). Keep `dailyClosingHistoryProvider`, sort, empty state, and all displayed fields.
- [ ] **Step 4: Run — expect PASS** (+ existing `daily_closing_*` tests unaffected).
- [ ] **Step 5: Commit** `style(closing): Closing History → AppCard rows + variance pills (06b)`

---

## Task 3: End-of-Day open form restyle

**Files:** Modify `end_of_day_screen.dart` (`_buildReview` + section/row/field helpers).

Restyle per HTML 57–95:
- App bar: `chevronLeft` back · "End-of-Day Closing" · trailing `history` (→ `RouteNames.endOfDayHistory`). Body `SingleChildScrollView(padding 14,16,20)`.
- **Sales** `ClosingSectionCard(receipt)` — KV rows; indented GCash/Maya; **conditional rows only when > 0** (GCash, Maya, Labor revenue, Salmon receivable) exactly as current logic; Sales count last.
- **Expenses** `ClosingSectionCard(arrowDownCircle)` — Total / Cash expenses.
- **Plate No Orders** `ClosingSectionCard(clipboardList)` — two `TextFormField`s (Plate No DP, Plate No Delivery) styled as label-above filled boxes (₱ prefix, radius 14). Keep controllers + `onChanged: setState`.
- **Cash reconciliation** `ClosingSectionCard(calculator)`: Opening float field → **Expected cash** emphasis panel (slate-tint/gold-tint, value 17/700 primary) → **Counted cash \*** required field (focused style: 1.5px primary + focus ring; keep validator) → `VariancePanel(variance)`.
- **Notes** — label-above multiline field (min-h 64).
- **Close Day** — full-width red (`AppColors.error`) `FilledButton` height 52 radius 16 with `BoxShadow 0 8px 20px -6px rgba(244,67,54,.45/.4)` + `lock` icon; helper line below "Closing locks the day — it can't be edited afterward." Keep the confirm dialog + `_submit`.

Keep all controllers, getters (`_float`/`_counted`/`_plateDp`/`_plateDelivery`), `expectedCashFor`, validator, `_busy`, and the loading/error/closed branching.

- [ ] **Step 1: Restyle** `_buildReview` + helpers; convert `_section`/`_row`/`_rowText`/`_varianceRow` to use `ClosingSectionCard`/`ClosingKvRow`/`VariancePanel`. The two Plate fields + Opening float + Counted cash + Notes stay real `TextFormField`s with the new label-above + filled decoration (radius 14).
- [ ] **Step 2: Analyze** `flutter analyze lib/presentation/mobile/screens/reports/end_of_day_screen.dart` — expect clean.
- [ ] **Step 3: Commit** `style(closing): End-of-Day form → AppCard sections, fields, variance panel (06b)`

---

## Task 4: End-of-Day closed view restyle (TDD)

**Files:** Modify `end_of_day_screen.dart` (`_ClosedView` + `_postCloseBanner`/`_afterCloseSection`/`_card`/`_kvText`); Test: add to `daily_closing_history_test.dart` or a new `end_of_day_closed_test.dart`.

Restyle per HTML 99–148:
- **Post-close warning** (conditional — only `activity.hasChanged`): amber banner — bg `#FFF6E6`/`0x1FF5B547`, border `#F0C36B`/`0x66F5B547`, `alertTriangle` icon (`warningIcon(dark)`), text `#8A5E12`/`#F5B547` 12.5/lh1.45, top-aligned. Keep the existing message text.
- **Closed-by banner** (success): bg `#E8F5E9`/`0x244CAF50`, `badgeCheck` icon + text `successText(dark)` 13.5/600 — "Closed by {name} at {time}".
- **Sales** card (`receipt`) — same KV rows (no count, conditional rows >0).
- **Cash reconciliation** card (`calculator`) — Opening float / Expected cash / Counted cash flat KV, then `VariancePanel(closing.variance)`.
- **After close** card (`clock`, amber icon) — conditional: "Sales after close" / "Cash collected after close" KV, divider, "Updated cash on hand" 15/600 + value 18/700 primary. Keep existing computed strings/signs.

- [ ] **Step 1: Write a failing widget test** — closed view with post-close activity shows the amber warning + "After close" + "Updated cash on hand"; closed-by banner shows. (Build a closed `DailyClosingEntity` + override `dailyClosingForDateProvider` / `dailyClosingDraftProvider` to force `_ClosedView` with activity; mirror existing closing tests.)
- [ ] **Step 2: Run — expect FAIL.**
- [ ] **Step 3: Restyle** `_ClosedView` + helpers per above; preserve `PostCloseActivity` logic and every figure.
- [ ] **Step 4: Run — expect PASS** + existing closing tests green.
- [ ] **Step 5: Commit** `style(closing): closed view → banners + After-close card, variance panel (06b)`

---

## Task 5: Full verification

- [ ] **Step 1:** `flutter analyze` → `No issues found!`
- [ ] **Step 2:** `flutter test` → all green (≥752 + new). Sweep `grep -rn CupertinoIcons test/` for any reports/closing matcher breakage.
- [ ] **Step 3:** `/code-review` the diff; address findings.
- [ ] **Step 4:** `/verify` — device smoke all 3 states light+dark (user's gate).
- [ ] **Step 5:** Finish branch (`superpowers:finishing-a-development-branch`); update ROADMAP (06b done) + memory.

## Notes for the implementer

- `VarianceStyle` consolidates all variance coloring — never hand-roll the red/green/amber per site.
- Counted-cash focus styling is visual only on the redesign; keep the field a real, validated `TextFormField`.
- The reconciliation figures and `PostCloseActivity` math are computed — restyle only.
- Reuse `AppColors.hairline(dark)` (added in 06a) for dividers/borders.
