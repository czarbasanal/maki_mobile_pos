# Sale-Detail Screen Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring `sale_detail_screen.dart` onto the redesign system (`AppCard`, `SummaryRow`, design tokens), fixing its hardcoded-color dark-mode breakage, and fold the mechanic into the labor label.

**Architecture:** Pure visual restyle of one screen plus one label behavior change. Neutral cards → shared `AppCard`; payment breakdown → shared `SummaryRow`; tinted status cards → theme-aware tinted `Container`s using `AppColors`; section headers → bundle-02 uppercase style; Cupertino → Lucide icons. No providers/repositories/Firestore touched.

**Tech Stack:** Flutter, Riverpod, `flutter_test`. Shared primitives: `AppCard`, `SummaryRow` (both exported from `common_widgets.dart`, already imported). Tokens in `core/theme/theme.dart` (`AppColors`, `AppRadius`, `AppSpacing`). Lucide via `package:lucide_icons/lucide_icons.dart`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-06-24-sale-detail-redesign-design.md`. Conventions inherited from `docs/superpowers/specs/2026-06-21-pos-sale-flow-redesign-design.md`.
- **No new design tokens** — reuse `AppColors` / `AppRadius` / `AppSpacing` / `AppShadows`. No raw color literals (`Colors.grey[*]`, `Colors.red[*]`, `Colors.amber[*]`, `Colors.green[*]`), no raw radius/spacing literals where a token exists.
- **Minimal testing** (bundle-02 decision): colors/shadows/radii are not unit-tested. TDD only the one behavior change (labor label). Keep the existing suite green; fix any icon matchers broken by the Lucide swap. No new golden/dark-mode tests.
- **Both light and dark must work.** This pass should *fix* dark mode, not regress it.
- **Gate every task:** `flutter test` + `flutter analyze` must pass before committing. `flutter`/`dart` live at `/Users/czar/flutter/bin` (prepend to `PATH`).
- Branch `feat/pos-redesign-fidelity-pass`; one commit per task; **no deploy/push**.
- Scope is `lib/presentation/mobile/screens/sales/sale_detail_screen.dart` only. `receipt_widget.dart` and `checkout_success_dialog.dart` are NOT touched.
- Must-keep: void role-gating (`voidSale`/`requestVoidSale`/pending), voided rendering (banner, strikethrough total, void-info), multi-tender breakdown + Salmon labels, cost-code item rows, draft-origin row, receipt sheet via `ReceiptWidget`.

## File structure

- **Modify:** `lib/presentation/mobile/screens/sales/sale_detail_screen.dart` — all four tasks edit this one file.
- **Modify (test):** `test/presentation/widgets/sale_detail_screen_labor_test.dart` — Task 1 only.
- No new files. `AppCard`/`SummaryRow` already imported via `common_widgets.dart` (line 15); `AppColors`/`AppRadius`/`AppSpacing` via `core/theme/theme.dart` (line 9).

Helper reference (already exist — consume, do not redefine):
- `AppCard({required Widget child, EdgeInsetsGeometry? padding, EdgeInsetsGeometry? margin, double radius = AppRadius.lg, VoidCallback? onTap, Clip clipBehavior = Clip.none})`
- `SummaryRow({required String label, required String value, bool isTotal = false, Color? valueColor})`
- `AppColors.successText(bool dark)`, `AppColors.error`, `AppColors.warning`, `AppColors.lightHairline`/`darkHairline`
- `AppRadius`: `md 14`, `field 16`, `lg 18`, `hero 22`, `xl 24`.

---

### Task 1: Payment breakdown → SummaryRow + AppCard; fold `Labor · {mechanic}`

**Files:**
- Modify: `lib/presentation/mobile/screens/sales/sale_detail_screen.dart` (`_buildPaymentCard` ~419-462, `_tenderRows` ~464-490, `_buildPaymentRow` ~492-526)
- Test: `test/presentation/widgets/sale_detail_screen_labor_test.dart`

**Interfaces:**
- Consumes: `SummaryRow` (from `common_widgets.dart`), `AppCard`, `AppColors.successText(bool)`, `SaleEntity` (`subtotal`, `totalDiscount`, `hasDiscount`, `laborLines`, `laborSubtotal`, `mechanicName`, `grandTotal`, `amountReceived`, `changeGiven`, `effectiveTenders`, `paymentMethod`).
- Produces: nothing consumed by later tasks (later tasks edit other methods in the same file).

- [ ] **Step 1: Write the failing test** — add an assertion for the folded label in `sale_detail_screen_labor_test.dart`, after the existing line `expect(find.text('Juan Dela Cruz'), findsOneWidget);`:

```dart
    // Payment breakdown folds the mechanic into the labor row label.
    expect(find.textContaining('Labor · Juan Dela Cruz'), findsOneWidget);
```

- [ ] **Step 2: Run the test, verify it FAILS**

Run: `flutter test test/presentation/widgets/sale_detail_screen_labor_test.dart`
Expected: FAIL — current label is `Labor (1 service)`, so `find.textContaining('Labor · Juan Dela Cruz')` finds nothing.

- [ ] **Step 3: Replace `_buildPaymentCard` body** (the whole method) with `AppCard` + `SummaryRow`, folding the mechanic:

```dart
  Widget _buildPaymentCard(ThemeData theme, SaleEntity sale) {
    final isDark = theme.brightness == Brightness.dark;
    final green = AppColors.successText(isDark);
    final mechanic = sale.mechanicName;
    final laborLabel = (mechanic != null && mechanic.isNotEmpty)
        ? 'Labor · $mechanic'
        : 'Labor';
    final cur = AppConstants.currencySymbol;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          SummaryRow(
            label: 'Subtotal',
            value: '$cur${sale.subtotal.toStringAsFixed(2)}',
          ),
          if (sale.hasDiscount) ...[
            const SizedBox(height: AppSpacing.sm),
            SummaryRow(
              label: 'Discount',
              value: '-$cur${sale.totalDiscount.toStringAsFixed(2)}',
              valueColor: green,
            ),
          ],
          if (sale.laborLines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SummaryRow(
              label: laborLabel,
              value: '$cur${sale.laborSubtotal.toStringAsFixed(2)}',
            ),
          ],
          const Divider(height: 24),
          SummaryRow(
            label: 'Total',
            value: '$cur${sale.grandTotal.toStringAsFixed(2)}',
            isTotal: true,
          ),
          const Divider(height: 24),
          SummaryRow(
            label: 'Received',
            value: '$cur${sale.amountReceived.toStringAsFixed(2)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          SummaryRow(
            label: 'Change',
            value: '$cur${sale.changeGiven.toStringAsFixed(2)}',
            valueColor: green,
          ),
          if (sale.effectiveTenders.length > 1) ...[
            const Divider(height: 24),
            ..._tenderRows(theme, sale),
          ],
        ],
      ),
    );
  }
```

- [ ] **Step 4: Replace `_tenderRows` body** to emit `SummaryRow`s (drop the hand-rolled `Row`):

```dart
  List<Widget> _tenderRows(ThemeData theme, SaleEntity sale) {
    String label(PaymentMethod m) {
      if (sale.paymentMethod == PaymentMethod.salmon) {
        return m == PaymentMethod.salmon
            ? 'Salmon balance'
            : 'Downpayment (${m.displayName})';
      }
      return m.displayName;
    }

    return sale.effectiveTenders.entries
        .map((e) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: SummaryRow(
                label: label(e.key),
                value:
                    '${AppConstants.currencySymbol}${e.value.toStringAsFixed(2)}',
              ),
            ))
        .toList();
  }
```

- [ ] **Step 5: Delete the now-unused `_buildPaymentRow` method** (the entire `Widget _buildPaymentRow(...) { ... }`, ~492-526). It has no remaining callers.

- [ ] **Step 6: Run the labor test, verify it PASSES**

Run: `flutter test test/presentation/widgets/sale_detail_screen_labor_test.dart`
Expected: PASS (all assertions, including `Labor · Juan Dela Cruz`).

- [ ] **Step 7: Analyze + full-suite gate**

Run: `flutter analyze lib/presentation/mobile/screens/sales/sale_detail_screen.dart && flutter test`
Expected: No new analyzer issues in the file; all tests pass. (`_buildPaymentRow` removed cleanly — no "unused element".)

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/mobile/screens/sales/sale_detail_screen.dart test/presentation/widgets/sale_detail_screen_labor_test.dart
git commit -m "feat(sales): sale-detail payment breakdown → SummaryRow + AppCard; fold Labor · {mechanic}" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Items + Details cards → AppCard; detail rows + section headers theme-aware

**Files:**
- Modify: `lib/presentation/mobile/screens/sales/sale_detail_screen.dart` (`_buildSectionHeader` ~249-257, `_buildItemsList` ~259-417, `_buildDetailsCard` ~528-582, `_buildDetailRow` ~584-610)

**Interfaces:**
- Consumes: `AppCard`, `AppColors.lightHairline`/`darkHairline`, `theme.colorScheme.onSurfaceVariant`, `AppColors.successText`.
- Produces: nothing for later tasks.

- [ ] **Step 1: Replace `_buildSectionHeader`** with the bundle-02 uppercase style:

```dart
  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
```

- [ ] **Step 2: Convert `_buildItemsList` outer container to `AppCard` and de-hardcode row borders.** Replace the outer `Container(decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)), child: Column(...))` with `AppCard(clipBehavior: Clip.antiAlias, child: Column(...))`. Inside, compute `final hairline = theme.brightness == Brightness.dark ? AppColors.darkHairline : AppColors.lightHairline;` at the top of the method and replace **both** per-row `Border(bottom: BorderSide(color: Colors.grey[200]!))` with `Border(bottom: BorderSide(color: hairline))`. Replace the two muted subtitles' `color: Colors.grey[600]` with `color: theme.colorScheme.onSurfaceVariant`, and the item discount text `color: Colors.green[700]` with `color: AppColors.successText(theme.brightness == Brightness.dark)`. Keep the `×N` qty badge (primary) and `wrench` labor badge (secondary) as-is structurally.

- [ ] **Step 3: Convert `_buildDetailsCard` to `AppCard`.** Replace `Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)), child: Column(...))` with `AppCard(padding: const EdgeInsets.all(AppSpacing.md), child: Column(...))`. Leave the `_buildDetailRow` calls unchanged.

- [ ] **Step 4: Make `_buildDetailRow` theme-aware.** In its body, replace `Icon(icon, size: 20, color: Colors.grey[600])` → `Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant)` and the label `color: Colors.grey[600]` → `color: theme.colorScheme.onSurfaceVariant`.

- [ ] **Step 5: Analyze + full-suite gate**

Run: `flutter analyze lib/presentation/mobile/screens/sales/sale_detail_screen.dart && flutter test`
Expected: No new issues; all tests pass (the labor test still finds `'Mechanic'`, `'Juan Dela Cruz'`, item rows).

- [ ] **Step 6: Manual dark-mode check (emulator).** Boot emulator, open a sale's detail view in dark mode; confirm Items + Details + Payment cards now use the dark card surface (not grey), section headers are uppercase. *(Visual gate — no automated test.)*

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/mobile/screens/sales/sale_detail_screen.dart
git commit -m "feat(sales): sale-detail items + details cards → AppCard; uppercase section headers" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Tinted status cards + sale header + void buttons → AppColors

**Files:**
- Modify: `lib/presentation/mobile/screens/sales/sale_detail_screen.dart` (`_buildVoidedBanner` ~142-181, `_buildSaleHeader` ~183-247, `_buildVoidInfoCard` ~612-674, `_buildNotesCard` ~676-707, `_buildVoidAction`/`_buildVoidButton` ~710-782)

**Interfaces:**
- Consumes: `AppCard`, `AppColors.error`, `AppColors.warning`, `AppColors.success`, `theme.colorScheme`.
- Produces: nothing.

- [ ] **Step 1: `_buildVoidedBanner` → error-tinted Container.** Replace the decoration `color: Colors.red[50]` → `color: AppColors.error.withValues(alpha: isDark ? 0.18 : 0.10)`, `border: Border.all(color: Colors.red[300]!)` → `border: Border.all(color: AppColors.error.withValues(alpha: 0.4))`, `borderRadius` literal `12` → `AppRadius.md`. Add `final isDark = theme.brightness == Brightness.dark;` at method top. Replace icon/text `Colors.red[700]`/`red[600]` → `AppColors.error`.

- [ ] **Step 2: `_buildVoidInfoCard` → error-tinted Container.** Same treatment as Step 1 (`red[50]`→error 0.18/0.10 tint, `red[200]`→error 0.4 border, radius→`AppRadius.md`). Add `final isDark = theme.brightness == Brightness.dark;`. The inner reason `Icon(... color: Colors.grey[600])` → `theme.colorScheme.onSurfaceVariant`.

- [ ] **Step 3: `_buildNotesCard` → warning-tinted Container.** Replace `color: Colors.amber[50]` → `AppColors.warning.withValues(alpha: isDark ? 0.16 : 0.12)`, `border: Border.all(color: Colors.amber[200]!)` → `Border.all(color: AppColors.warning.withValues(alpha: 0.4))`, radius `12` → `AppRadius.md`, label `Colors.amber[700]` → `AppColors.warning` (icon + "Notes" text). Add `final isDark = theme.brightness == Brightness.dark;` (method currently takes `theme`).

- [ ] **Step 4: `_buildSaleHeader` theme-aware.** Wrap in `AppCard(radius: AppRadius.xl, padding: const EdgeInsets.all(20), child: Column(...))` replacing the `Container` with `surfaceContainerHighest`. Date `color: Colors.grey[600]` → `theme.colorScheme.onSurfaceVariant`. Voided total `color: Colors.grey` → `theme.colorScheme.onSurfaceVariant`. Status badge `color: sale.status == SaleStatus.voided ? Colors.red : Colors.green` → `... ? AppColors.error : AppColors.success`. Keep the `displaySmall` total hero + line-through-when-voided.

- [ ] **Step 5: Void buttons → AppColors.error.** In `_buildVoidAction` (Request Void) and `_buildVoidButton`, replace `foregroundColor: Colors.red` → `foregroundColor: AppColors.error` and `side: const BorderSide(color: Colors.red)` → `side: const BorderSide(color: AppColors.error)`. (`AppColors.error` is `const`, so the `const BorderSide` stays valid.)

- [ ] **Step 6: Analyze + full-suite gate**

Run: `flutter analyze lib/presentation/mobile/screens/sales/sale_detail_screen.dart && flutter test`
Expected: No new issues; all tests pass.

- [ ] **Step 7: Manual dark-mode check.** On the emulator, view a voided sale and a sale with notes in dark mode; confirm the red/amber tints read correctly on the dark canvas (not solid pale-light blocks). *(Visual gate.)*

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/mobile/screens/sales/sale_detail_screen.dart
git commit -m "feat(sales): sale-detail tinted cards, header & void buttons → AppColors (fix dark mode)" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Cupertino → Lucide icon migration

**Files:**
- Modify: `lib/presentation/mobile/screens/sales/sale_detail_screen.dart` (import line 2; all `CupertinoIcons.*` usages)
- Possibly modify: `test/presentation/widgets/sale_detail_screen_labor_test.dart` (only if it matches an icon — current assertions are text-only, so likely no change)

**Interfaces:**
- Consumes: `package:lucide_icons/lucide_icons.dart`.
- Produces: nothing.

- [ ] **Step 1: Add the Lucide import** at line 2 area:

```dart
import 'package:lucide_icons/lucide_icons.dart';
```

- [ ] **Step 2: Swap every `CupertinoIcons.*` to its Lucide equivalent** (bundle-02 mapping). Exact replacements in this file:
  - `CupertinoIcons.xmark_circle` (voided banner + void buttons) → `LucideIcons.xCircle`
  - `CupertinoIcons.person` (cashier / voided-by) → `LucideIcons.user`
  - `CupertinoIcons.wrench` (mechanic / labor badge) → `LucideIcons.wrench`
  - `CupertinoIcons.creditcard` (payment method) → `LucideIcons.creditCard`
  - `CupertinoIcons.bag` (items) → `LucideIcons.shoppingBag`
  - `CupertinoIcons.envelope` (from draft) → `LucideIcons.inbox`
  - `CupertinoIcons.clock` (voided at / pending) → `LucideIcons.clock`
  - `CupertinoIcons.doc_text` (void reason) → `LucideIcons.fileText`
  - `CupertinoIcons.square_list` (notes) → `LucideIcons.stickyNote`

- [ ] **Step 3: Remove the now-unused Cupertino import.** Delete `import 'package:flutter/cupertino.dart';` (line 2). Verify no other `CupertinoIcons.` / `Cupertino*` symbols remain in the file:

Run: `grep -n "Cupertino" lib/presentation/mobile/screens/sales/sale_detail_screen.dart`
Expected: no matches.

- [ ] **Step 4: Analyze + full-suite gate**

Run: `flutter analyze lib/presentation/mobile/screens/sales/sale_detail_screen.dart && flutter test`
Expected: No issues (no "unused import", no undefined `CupertinoIcons`); all tests pass. If any test fails on `find.byIcon(CupertinoIcons.*)`, update that matcher to the Lucide equivalent above.

- [ ] **Step 5: Manual check.** On the emulator, confirm icons render (no missing-glyph boxes) on the sale detail screen, light + dark.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/screens/sales/sale_detail_screen.dart
git commit -m "feat(sales): migrate sale-detail icons Cupertino → Lucide" -m "Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Final verification (after all tasks)

- [ ] `flutter analyze` (whole project) — no new issues attributable to `sale_detail_screen.dart`.
- [ ] `flutter test` — full suite green (727+ baseline + the new labor assertion).
- [ ] Emulator walk-through (light + dark): normal sale (cards lift, payment breakdown + Total hero, `Labor · {mechanic}`), voided sale (red tint banner + strikethrough total + void-info), sale with notes (amber tint), multi-tender sale (tender rows), receipt sheet opens.
- [ ] Consider `superpowers:finishing-a-development-branch` to wrap the branch (the user merges/deploys).
