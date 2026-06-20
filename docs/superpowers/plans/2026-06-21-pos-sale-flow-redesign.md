# POS Sale-Flow Redesign (Bundle 02) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the four mobile sale-flow surfaces (POS, Checkout, Barcode Scanner, post-sale Success dialog) — including the product-search dropdown — into the elevated global theme (soft-shadow cards, Lucide icons, hero numbers, pinned primary actions), light + dark, with no behavior changes.

**Architecture:** A new shared `AppCard` primitive encapsulates the light=soft-shadow / dark=1px-border surface and replaces Material `Card` across the flow. Two new `AppShadows` entries (`confirmButton` green glow, `pinnedFooter` top shadow) round out the token set. App bars get an explicit bottom shadow via a `PreferredSize` wrapper (Material `elevation` can't match the soft spread). Everything else is token swaps + Cupertino→Lucide icon migration, scoped to the sale-flow files only. No providers, repositories, Firestore, or `firestore.rules` are touched.

**Tech Stack:** Flutter, Material 3, Riverpod, `lucide_icons: ^0.257.0`, `mobile_scanner`. Theme layer in `lib/core/theme/`.

## Global Constraints

- **Do not invent tokens.** Use `lib/core/theme/` (`AppColors`, `AppShadows`, `AppSpacing`/`AppRadius`, `AppTextStyles`). All handoff token values already exist there.
- **Surfaces:** every card/panel in the flow uses the new `AppCard` (light = white + `AppShadows.card()`; dark = `AppColors.darkCard` + 1px `AppColors.darkHairline`). Never re-derive `isDark`/hairline inline once `AppCard` exists.
- **Icons:** Lucide (`package:lucide_icons/lucide_icons.dart`), stroke is the package default. Remove `package:flutter/cupertino.dart` imports from every sale-flow file touched. Mapping (verified present in 0.257.0): back `chevronLeft`, search `search`, no-results `searchX`, scan `scanLine`, drafts `inbox`, clear/trash `trash2`, remove/close `x`, qty `minus`/`plus`, discount `tag`, labor/mechanic `wrench`, edit `pencil`, add `plus`, save-draft `save`, proceed `arrowRight`, expand `chevronDown`, cash `banknote`, gcash `smartphone`, maya `wallet`, mixed `layers`, salmon `fish`, exact `checkCheck`, confirm/success `checkCircle2`/`check`, receipt `receipt`, torch `flashlight`/`flashlightOff`, flip `switchCamera`, error `alertTriangle`, empty-cart `shoppingCart`.
- **Currency:** `AppConstants.currencySymbol` (₱) at every call site — never hard-code "₱".
- **Testing posture (minimal):** keep the existing suite green and update icon matchers broken by the migration. No new behavior or golden tests. Gate every task on `flutter analyze` (no NEW issues) + `flutter test` (all green) before commit.
- **Preserve behavior:** role-gating (`applyDiscount`, `saveDraft`, `processSale`, `accessPos`), all 5 payment methods + Mixed/Salmon math, dark parity, pinned primary action, tablet ≥800px POS split, dropdown behavior (debounce, out-of-stock disable, tap-to-add, barcode-on-submit), scanner single-shot detect→haptic→pop.
- **Git:** work on branch `feat/pos-sale-flow-redesign` off `main`. Commit per task. Do NOT push or deploy (UI-only; follows bundle 01).
- **Currency/price text** for hero Total uses `theme.colorScheme.primary` (slate light / gold dark) — already the case in `cart_summary.dart`/`checkout_screen.dart`; keep it.

---

### Task 1: Foundation — branch, shadows, `AppCard`

**Files:**
- Modify: `lib/core/theme/app_shadows.dart`
- Create: `lib/presentation/shared/widgets/common/app_card.dart`
- Modify: `lib/presentation/shared/widgets/common/common_widgets.dart:8` (add export)
- Commit (already on disk): `docs/superpowers/specs/2026-06-21-pos-sale-flow-redesign-design.md`, this plan

**Interfaces:**
- Produces: `AppShadows.confirmButton({bool dark})` → `List<BoxShadow>`; `AppShadows.pinnedFooter({bool dark})` → `List<BoxShadow>`; `AppCard({Widget child, EdgeInsetsGeometry? padding, EdgeInsetsGeometry? margin, double radius = AppRadius.lg, VoidCallback? onTap, Clip clipBehavior = Clip.none})`.

- [ ] **Step 1: Create the branch and commit the spec + plan**

```bash
cd /Users/czar/Desktop/MAKI_Mobile_POS/maki_mobile_pos
git checkout -b feat/pos-sale-flow-redesign
git add docs/superpowers/specs/2026-06-21-pos-sale-flow-redesign-design.md docs/superpowers/plans/2026-06-21-pos-sale-flow-redesign.md
git commit -m "docs(pos): sale-flow redesign spec + plan (bundle 02)"
```

- [ ] **Step 2: Add the two shadow tokens**

In `lib/core/theme/app_shadows.dart`, add inside the `AppShadows` class (after `focusRing`):

```dart
  /// Pinned bottom action bar — soft shadow cast UPWARD (top edge).
  /// Mirror of [pinnedHeader] with a negative y-offset.
  static List<BoxShadow> pinnedFooter({bool dark = false}) => dark
      ? const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, -4))]
      : const [BoxShadow(color: Color(0x0F111C1D), blurRadius: 16, offset: Offset(0, -4))];

  /// Confirm-Payment (success-green) button glow. Distinct from the
  /// slate/gold [primaryButton]; signals the terminal "commit the sale" action.
  static List<BoxShadow> confirmButton({bool dark = false}) => dark
      ? const [BoxShadow(color: Color(0x734CAF50), blurRadius: 20, spreadRadius: -6, offset: Offset(0, 8))]
      : const [BoxShadow(color: Color(0x804CAF50), blurRadius: 20, spreadRadius: -6, offset: Offset(0, 8))];
```

- [ ] **Step 3: Create `AppCard`**

Create `lib/presentation/shared/widgets/common/app_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Soft-shadow surface for the refreshed theme.
///
/// Light: white fill + [AppShadows.card] (no border). Dark: [AppColors.darkCard]
/// fill + 1px [AppColors.darkHairline] border (no shadow — the border carries
/// the separation). Centralizes the light=shadow / dark=border duality so
/// callers never re-derive `isDark`/hairline. Replaces Material [Card] and
/// hand-rolled soft-shadow Containers across the sale flow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppRadius.lg,
    this.onTap,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;

  /// Clip the child to the rounded rect (e.g. a list whose rows must not
  /// bleed past the corners). The shadow is drawn on the outer container so
  /// it is never clipped.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);

    Widget inner = child;
    if (padding != null) {
      inner = Padding(padding: padding!, child: inner);
    }
    if (clipBehavior != Clip.none) {
      inner = ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: clipBehavior,
        child: inner,
      );
    }
    if (onTap != null) {
      inner = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: borderRadius, child: inner),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: borderRadius,
        border: isDark ? Border.all(color: AppColors.darkHairline) : null,
        boxShadow: AppShadows.card(dark: isDark),
      ),
      child: inner,
    );
  }
}
```

- [ ] **Step 4: Export `AppCard` from the barrel**

In `lib/presentation/shared/widgets/common/common_widgets.dart`, add after `export 'app_button.dart';`:

```dart
export 'app_card.dart';
```

- [ ] **Step 5: Verify analyze + tests, then commit**

```bash
flutter analyze lib/core/theme/app_shadows.dart lib/presentation/shared/widgets/common/app_card.dart
flutter test
```
Expected: analyze clean for the two files; full suite passes (no consumers yet).

```bash
git add lib/core/theme/app_shadows.dart lib/presentation/shared/widgets/common/app_card.dart lib/presentation/shared/widgets/common/common_widgets.dart
git commit -m "feat(theme): AppCard surface + confirmButton/pinnedFooter shadows"
```

---

### Task 2: POS — search pill + scan button + dropdown restyle

**Files:**
- Modify: `lib/presentation/mobile/widgets/pos/product_search_field.dart` (whole file)

**Interfaces:**
- Consumes: `AppCard`, `AppShadows`, `AppColors`, `AppRadius`, `AppSpacing`, `LucideIcons`. Public API of `ProductSearchField` (controller/focusNode/onProductSelected/onBarcodeScanned) is unchanged.
- Produces: nothing new (same widget API).

- [ ] **Step 1: Swap imports**

In `product_search_field.dart`, replace line 4 (`import 'package:flutter/cupertino.dart';`) with:

```dart
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
```

(Keeps `package:flutter/material.dart`, riverpod, theme, entities, providers, barcode screen imports.)

- [ ] **Step 2: Rewrite `build()` — elevated white pill + filled scan button**

Replace the `build` method (lines 145-184) with:

```dart
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return CompositedTransformTarget(
      link: _layerLink,
      child: AppCard(
        radius: AppRadius.field,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(LucideIcons.search, size: 20, color: muted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                decoration: const InputDecoration(
                  hintText: 'Search products or scan barcode...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  final trimmed = value.trim();
                  if (trimmed.isNotEmpty) {
                    widget.onBarcodeScanned(trimmed);
                  }
                },
              ),
            ),
            if (widget.controller.text.isNotEmpty)
              IconButton(
                icon: Icon(LucideIcons.x, size: 18, color: muted),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  widget.controller.clear();
                  widget.focusNode.requestFocus();
                },
              ),
            const SizedBox(width: 4),
            // Filled scan button — slate (light) / gold (dark).
            GestureDetector(
              onTap: _openBarcodeScanner,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  LucideIcons.scanLine,
                  size: 18,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
```

Note: `controller.text.isNotEmpty` already triggers a rebuild because `_onSearchChanged` calls `setState`; the clear `x` appears/disappears with typing as before.

- [ ] **Step 3: Restyle the dropdown overlay container**

In `_showOverlay` (lines 102-138), replace the `Material(...)` child of `CompositedTransformFollower` with a soft-shadow container that still hosts Material ink for the rows:

```dart
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: isDark ? Border.all(color: hairline) : null,
                boxShadow: AppShadows.card(dark: isDark),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                type: MaterialType.transparency,
                child: _buildSearchResults(),
              ),
            ),
```

Keep the existing `theme`/`isDark`/`hairline` locals defined at the top of the builder. Remove the now-unused `elevation: 0` Material wrapper.

- [ ] **Step 4: Lucide-ify the result rows**

In `_buildSearchResults` (lines 186-279): the empty/error leading icons change to Lucide. Replace `Icon(Icons.search_off)` (line 199) with `Icon(LucideIcons.searchX, color: muted)` (add a `muted` local from `Theme.of(context).colorScheme.onSurfaceVariant` if not present in that scope — it's already computed at line 205 for the data branch; for the empty branch inline `Theme.of(context).colorScheme.onSurfaceVariant`). Replace the error `CupertinoIcons.exclamationmark_circle` (line 271) with `LucideIcons.alertTriangle`. Leave the stock-circle avatar, titles, subtitles, out-of-stock disable, and `onTap` logic exactly as-is.

- [ ] **Step 5: Lucide-ify the scanner-open path**

No icon there, but confirm no remaining `CupertinoIcons.` references:

```bash
grep -n "CupertinoIcons\|cupertino" lib/presentation/mobile/widgets/pos/product_search_field.dart
```
Expected: no output.

- [ ] **Step 6: Verify + commit**

```bash
flutter analyze lib/presentation/mobile/widgets/pos/product_search_field.dart
flutter test
```
Expected: analyze clean; suite green.

```bash
git add lib/presentation/mobile/widgets/pos/product_search_field.dart
git commit -m "feat(pos): elevated search pill + filled scan button + soft-shadow results dropdown"
```

---

### Task 3: POS — `CartItemTile` restyle + icon-matcher test fix

**Files:**
- Modify: `lib/presentation/mobile/widgets/pos/cart_item_tile.dart`
- Modify: `test/presentation/widgets/cart_item_tile_test.dart:1,65`

**Interfaces:**
- Consumes: `AppCard`, `LucideIcons`. `CartItemTile` public API unchanged.

- [ ] **Step 1: Swap imports**

In `cart_item_tile.dart`, replace line 2 (`import 'package:flutter/cupertino.dart';`) with:

```dart
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
```

- [ ] **Step 2: Replace the `Card` with `AppCard`**

In `build` (lines 49-147), replace the `Card(margin: ..., child: Padding(...))` with:

```dart
      child: AppCard(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 5,
        ),
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Column(
```
…and at the close of that `Column`'s parent, change the matching `Card`'s closing `),` to `AppCard`'s `),` (structure is identical: `AppCard(... child: Column(...))`). The `Padding` wrapper is removed (AppCard now owns padding).

- [ ] **Step 3: Lucide-ify the icons in this file**

- Dismissible background trash (line 46): `Icon(LucideIcons.trash2, color: Colors.white)`.
- Remove button (line 71): `Icon(LucideIcons.x, size: 20)`.
- Quantity `−` (line 176): `Icon(LucideIcons.minus)`.
- Quantity `+` (line 197): `Icon(LucideIcons.plus)`.
- Discount `tag` (line 252): `Icon(LucideIcons.tag, size: 16, color: fgColor)`.

- [ ] **Step 4: Confirm no Cupertino left**

```bash
grep -n "CupertinoIcons\|cupertino" lib/presentation/mobile/widgets/pos/cart_item_tile.dart
```
Expected: no output.

- [ ] **Step 5: Update the broken icon matcher in the test**

In `test/presentation/widgets/cart_item_tile_test.dart`: replace line 1 (`import 'package:flutter/cupertino.dart';`) with `import 'package:lucide_icons/lucide_icons.dart';`, and line 65 (`await tester.tap(find.byIcon(CupertinoIcons.add));`) with:

```dart
      await tester.tap(find.byIcon(LucideIcons.plus));
```

- [ ] **Step 6: Run this test first, then full suite + analyze**

```bash
flutter test test/presentation/widgets/cart_item_tile_test.dart
```
Expected: 4 tests pass (the increment test now finds `LucideIcons.plus`).

```bash
flutter analyze lib/presentation/mobile/widgets/pos/cart_item_tile.dart test/presentation/widgets/cart_item_tile_test.dart
flutter test
```
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/mobile/widgets/pos/cart_item_tile.dart test/presentation/widgets/cart_item_tile_test.dart
git commit -m "feat(pos): CartItemTile on AppCard + Lucide icons"
```

---

### Task 4: POS — `LaborLineTile` + `MechanicPicker` restyle

**Files:**
- Modify: `lib/presentation/mobile/widgets/pos/labor_line_tile.dart`
- Modify: `lib/presentation/mobile/widgets/pos/mechanic_picker.dart`

**Interfaces:**
- Consumes: `AppCard`, `LucideIcons`. Both widgets' public APIs unchanged. (`cart_summary.dart` is intentionally NOT wrapped here — it has no card today; the POS screen wraps it in Task 5 so the summary card's margin lives with the screen layout.)

- [ ] **Step 1: `LaborLineTile` imports**

Replace line 2 (`import 'package:flutter/cupertino.dart';`) with:

```dart
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
```

- [ ] **Step 2: `LaborLineTile` — `Card`→`AppCard` + Lucide**

In `build` (lines 41-74): replace `Card(margin: ..., child: Padding(padding: ..., child: Row(...)))` with:

```dart
      child: AppCard(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        child: Row(
```
(close `AppCard` in place of `Card`). Swap icons: Dismissible trash (line 38) → `LucideIcons.trash2`; row wrench (line 50) → `LucideIcons.wrench`; edit pencil (line 66) → `LucideIcons.pencil`.

- [ ] **Step 3: `MechanicPicker` — Lucide prefix icon**

In `mechanic_picker.dart`: replace line 1 (`import 'package:flutter/cupertino.dart';`) with `import 'package:lucide_icons/lucide_icons.dart';`. Replace the dropdown prefix icon (line 42) `Icon(CupertinoIcons.wrench)` with `Icon(LucideIcons.wrench)`.

> Note: `AppDropdown`'s internal chevron uses `CupertinoIcons.chevron_up/down` (line 174-176 of `app_dropdown.dart`). That is a SHARED widget used app-wide and OUT OF SCOPE — leave it.

- [ ] **Step 4: Confirm no Cupertino left in the two files**

```bash
grep -n "CupertinoIcons\|cupertino" lib/presentation/mobile/widgets/pos/labor_line_tile.dart lib/presentation/mobile/widgets/pos/mechanic_picker.dart
```
Expected: no output.

- [ ] **Step 5: Verify + commit**

```bash
flutter analyze lib/presentation/mobile/widgets/pos/labor_line_tile.dart lib/presentation/mobile/widgets/pos/mechanic_picker.dart
flutter test
```
Expected: green (incl. `pos_labor_section_test.dart`, `checkout_labor_test.dart`, `cart_summary_labor_test.dart`).

```bash
git add lib/presentation/mobile/widgets/pos/labor_line_tile.dart lib/presentation/mobile/widgets/pos/mechanic_picker.dart
git commit -m "feat(pos): LaborLineTile on AppCard + Lucide; MechanicPicker Lucide prefix"
```

---

### Task 5: POS screen — app-bar shadow, canvas body, summary card, pinned action bar

**Files:**
- Modify: `lib/presentation/mobile/screens/pos/pos_screen.dart`

**Interfaces:**
- Consumes: `AppCard`, `AppShadows.pinnedFooter`, `AppShadows.primaryButton`/`primaryButtonGold`, `LucideIcons`, restyled `CartItemTile`/`CartSummary`/`LaborLineTile`/`MechanicPicker`/`ProductSearchField`.

- [ ] **Step 1: Swap imports**

Replace line 2 (`import 'package:flutter/cupertino.dart';`) with:

```dart
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
```

- [ ] **Step 2: App bar — Lucide icons + soft bottom shadow**

Replace the `appBar:` argument (lines 44-61) with a `PreferredSize` wrapper carrying `AppShadows.pinnedHeader` (the theme's `AppBar` is flat; this adds the soft bottom shadow the handoff specifies):

```dart
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.appBarTheme.backgroundColor,
            boxShadow: AppShadows.pinnedHeader(
              dark: theme.brightness == Brightness.dark,
            ),
          ),
          child: AppBar(
            leading: IconButton(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: () => context.goBackOr(RoutePaths.dashboard),
            ),
            title: const Text('Point of Sale'),
            actions: [
              _buildDraftsButton(),
              if (cart.isNotEmpty)
                IconButton(
                  icon: const Icon(LucideIcons.trash2),
                  tooltip: 'Clear Cart',
                  onPressed: _showClearCartDialog,
                ),
            ],
          ),
        ),
      ),
```

- [ ] **Step 3: Drafts badge → `inbox`**

In `_buildDraftsButton` (lines 503-525), replace all three `Icon(CupertinoIcons.envelope)` with `Icon(LucideIcons.inbox)`.

- [ ] **Step 4: Search section padding 14**

In `_buildSearchSection` (line 120), change `padding: const EdgeInsets.all(16)` to `padding: const EdgeInsets.fromLTRB(14, 14, 14, 8)`.

- [ ] **Step 5: Cart body — gaps + summary card, drop dividers**

Replace the scrollable `Column` children block (lines 222-258, the `SingleChildScrollView` child) with card-spaced layout (CartItemTile already carries its own AppCard margin; wrap labor + summary in cards, separate with spacing instead of `Divider`):

```dart
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cart.items.length,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemBuilder: (context, index) {
                          final item = cart.items[index];
                          return CartItemTile(
                            item: item,
                            discountType: cart.discountType,
                            onQuantityChanged: (qty) =>
                                _updateItemQuantity(item.id, qty),
                            onDiscountTap: () =>
                                _showDiscountDialog(item, cart.discountType),
                            onRemove: () => _removeItem(item.id),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: AppCard(child: _buildLaborSection(cart)),
                      ),
                      const SizedBox(height: AppSpacing.sm + 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: AppCard(child: CartSummary(cart: cart)),
                      ),
                    ],
                  ),
                ),
```

- [ ] **Step 6: Labor section — Lucide + transparent expansion divider**

In `_buildLaborSection` (lines 295-359): the `ExpansionTile` is now inside an `AppCard`. Swap icons: leading (line 302) `Icon(LucideIcons.wrench)`; the add-line button icon (line 352) `Icon(LucideIcons.plus)`. The `chevron-down` is `ExpansionTile`'s default trailing — leave it (Material draws it). The error builder in `_buildLaborError` (line 371) `CupertinoIcons.exclamationmark_circle` → `LucideIcons.alertTriangle`.

- [ ] **Step 7: Empty cart — Lucide cart**

In `_buildEmptyCart` (line 276), replace `Icon(CupertinoIcons.cart, ...)` with `Icon(LucideIcons.shoppingCart, size: 56, color: muted)`.

- [ ] **Step 8: Pinned action bar — top shadow + heights + Lucide + primary glow**

Replace `_buildActionButtons` (lines 461-496) with:

```dart
  Widget _buildActionButtons(CartState cart) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );
    final canProceed = cart.canSaveAsDraft;
    return Container(
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        boxShadow: AppShadows.pinnedFooter(dark: isDark),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: canProceed
                      ? (isDark
                          ? AppShadows.primaryButtonGold
                          : AppShadows.primaryButton)
                      : null,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: canProceed ? _proceedToCheckout : null,
                    icon: const Icon(LucideIcons.arrowRight),
                    label: const Text('Proceed to Checkout'),
                    style: FilledButton.styleFrom(shape: shape),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: canProceed ? _showSaveDraftDialog : null,
                  icon: const Icon(LucideIcons.save),
                  label: const Text('Save as Draft'),
                  style: OutlinedButton.styleFrom(shape: shape),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 9: Add-labor dialog + wide-layout results — Lucide**

In `_showAddLaborDialog` there are no Cupertino icons (text fields only) — skip. In `_buildProductSearchResults` (the tablet wide-layout list, lines 132-211): this is functional duplicate-styling of the dropdown rows; leave the structure but it has no Cupertino icons to swap (uses a stock-circle avatar). Confirm with the grep in Step 10.

- [ ] **Step 10: Confirm no Cupertino left**

```bash
grep -n "CupertinoIcons\|cupertino" lib/presentation/mobile/screens/pos/pos_screen.dart
```
Expected: no output.

- [ ] **Step 11: Verify + commit**

```bash
flutter analyze lib/presentation/mobile/screens/pos/pos_screen.dart
flutter test
```
Expected: green (incl. `pos_labor_section_test.dart`).

```bash
git add lib/presentation/mobile/screens/pos/pos_screen.dart
git commit -m "feat(pos): canvas body, card summary, pinned action bar w/ shadows, Lucide"
```

---

### Task 6: Checkout screen — AppCard surfaces, Lucide, green confirm glow

**Files:**
- Modify: `lib/presentation/mobile/screens/pos/checkout_screen.dart`

**Interfaces:**
- Consumes: `AppCard`, `AppShadows.pinnedHeader`/`pinnedFooter`/`confirmButton`, `LucideIcons`.

- [ ] **Step 1: Swap imports**

Replace line 2 (`import 'package:flutter/cupertino.dart';`) with:

```dart
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';
```

- [ ] **Step 2: Scaffold app bar — Lucide back + soft bottom shadow**

Replace the `appBar:` (lines 75-81) with the `PreferredSize` pattern (back disabled while processing):

```dart
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.appBarTheme.backgroundColor,
            boxShadow: AppShadows.pinnedHeader(
              dark: theme.brightness == Brightness.dark,
            ),
          ),
          child: AppBar(
            title: const Text('Checkout'),
            leading: IconButton(
              icon: const Icon(LucideIcons.chevronLeft),
              onPressed: _isProcessing ? null : () => Navigator.pop(context),
            ),
          ),
        ),
      ),
```

- [ ] **Step 3: Body padding + section gaps**

In the body `SingleChildScrollView` (line 87), change `padding: const EdgeInsets.all(AppSpacing.md)` to `padding: const EdgeInsets.all(14)`. Leave the `_SectionHeader` uppercase labels as-is (already match the handoff).

- [ ] **Step 4: ORDER ITEMS card → `AppCard` + Lucide wrench badge**

In `_buildItemsList` (lines 129-265): replace the outer `Card(margin: EdgeInsets.zero, child: Column(...))` with `AppCard(clipBehavior: Clip.antiAlias, child: Column(...))` (clip so the hairline row dividers meet the rounded corners). In the labor-row badge (line 237) replace `Icon(CupertinoIcons.wrench, ...)` with `Icon(LucideIcons.wrench, size: 14, color: theme.colorScheme.primary)`. Leave the `×N` outlined pill and net/fee text as-is.

- [ ] **Step 5: PAYMENT SUMMARY card → `AppCard`, hero Total**

In `_buildPaymentSummary` (lines 267-324): replace `Card(margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(...)))` with `AppCard(padding: const EdgeInsets.all(AppSpacing.md), child: Column(...))`. In `_buildSummaryRow` (lines 326-357) bump the total to the 26px hero: in the `isTotal` value branch change `theme.textTheme.titleLarge?.copyWith(...)` to:

```dart
              ? theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                )
```
and keep the label branch as `titleMedium` w600. (`headlineSmall` is 20; to hit ~26 use an explicit size.) Use:

```dart
              ? const TextStyle(fontWeight: FontWeight.w700, fontSize: 26).copyWith(
                  color: theme.colorScheme.primary,
                )
```

- [ ] **Step 6: PAYMENT card wrapper → `AppCard`**

In `build` (lines 101-113) replace the `Card(margin: EdgeInsets.zero, child: PaymentSection(...))` with `AppCard(child: PaymentSection(...))`. (PaymentSection itself is restyled in Task 7.)

- [ ] **Step 7: Error banner — Lucide**

In `_buildErrorMessage` (line 368) replace `CupertinoIcons.exclamationmark_circle` with `LucideIcons.alertTriangle`.

- [ ] **Step 8: Pinned Confirm — footer shadow, 52px, green glow, Lucide**

Replace `_buildConfirmButton` (lines 385-436) with:

```dart
  Widget _buildConfirmButton(ThemeData theme, CartState cart) {
    final isDark = theme.brightness == Brightness.dark;
    final enabled = !_isProcessing && cart.canCheckout;
    return Container(
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        boxShadow: AppShadows.pinnedFooter(dark: isDark),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: enabled ? AppShadows.confirmButton(dark: isDark) : null,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: enabled ? () => _processCheckout(cart) : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.success.withValues(alpha: 0.4),
                  disabledForegroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.checkCircle2, size: 22),
                          const SizedBox(width: AppSpacing.sm + 4),
                          Text(
                            'Confirm Payment • ${AppConstants.currencySymbol}'
                            '${cart.grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 9: Confirm no Cupertino left**

```bash
grep -n "CupertinoIcons\|cupertino" lib/presentation/mobile/screens/pos/checkout_screen.dart
```
Expected: no output.

- [ ] **Step 10: Verify + commit**

```bash
flutter analyze lib/presentation/mobile/screens/pos/checkout_screen.dart
flutter test
```
Expected: green (incl. `checkout_labor_test.dart`).

```bash
git add lib/presentation/mobile/screens/pos/checkout_screen.dart
git commit -m "feat(checkout): AppCard surfaces, hero Total, green confirm glow, Lucide"
```

---

### Task 7: Checkout — `PaymentSection` pill chips + filled Change box

**Files:**
- Modify: `lib/presentation/mobile/widgets/pos/payment_section.dart`

**Interfaces:**
- Consumes: `LucideIcons`, `AppColors`, `AppRadius`, `AppSpacing`. Public API unchanged.
- Produces: private `_PaymentMethodChip` (file-local).

- [ ] **Step 1: Swap imports**

Replace line 2 (`import 'package:flutter/cupertino.dart';`) with:

```dart
import 'package:lucide_icons/lucide_icons.dart';
```

- [ ] **Step 2: Replace the `ChoiceChip` `Wrap` with scrollable Lucide pill chips + right fade**

Replace the `Wrap(... ChoiceChip ...)` block (lines 41-57) with:

```dart
          ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [Colors.black, Colors.black, Colors.transparent],
              stops: const [0.0, 0.9, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 24),
              child: Row(
                children: [
                  for (final m in const [
                    PaymentMethod.cash,
                    PaymentMethod.gcash,
                    PaymentMethod.maya,
                    PaymentMethod.mixed,
                    PaymentMethod.salmon,
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: _PaymentMethodChip(
                        method: m,
                        selected: cart.paymentMethod == m,
                        onTap: () => onPaymentMethodChanged(m),
                      ),
                    ),
                ],
              ),
            ),
          ),
```

- [ ] **Step 3: Add the `_PaymentMethodChip` widget**

Append to `payment_section.dart` (after the `PaymentSection` class):

```dart
/// A single payment-method pill chip: filled slate/gold when selected,
/// card surface + hairline + muted icon otherwise.
class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon {
    switch (method) {
      case PaymentMethod.cash:
        return LucideIcons.banknote;
      case PaymentMethod.gcash:
        return LucideIcons.smartphone;
      case PaymentMethod.maya:
        return LucideIcons.wallet;
      case PaymentMethod.mixed:
        return LucideIcons.layers;
      case PaymentMethod.salmon:
        return LucideIcons.fish;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final surface = isDark ? AppColors.darkCard : AppColors.lightCard;
    final muted = theme.colorScheme.onSurfaceVariant;
    final fg = selected ? theme.colorScheme.onPrimary : muted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: selected ? null : Border.all(color: hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(
              method.displayName,
              style: theme.textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: "Exact" button → Lucide `checkCheck`**

In `_buildSingleInputs` (line 84) replace `Icon(CupertinoIcons.checkmark_circle)` with `Icon(LucideIcons.checkCheck)`.

- [ ] **Step 5: Filled success-tint Change box**

Replace `_buildChangeDisplay` (lines 196-243) with a filled-tint version (tint follows status; value stays green/red):

```dart
  Widget _buildChangeDisplay(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final change = cart.change;
    final isInsufficient = cart.amountReceived > 0 && !cart.isPaymentValid;
    final hasReceipt = cart.amountReceived > 0;

    // Filled tint carries status: success when sufficient, error when short,
    // quiet muted fill before any tender is entered.
    final Color fill;
    if (isInsufficient) {
      fill = AppColors.error.withValues(alpha: isDark ? 0.18 : 0.10);
    } else if (hasReceipt) {
      fill = isDark
          ? AppColors.success.withValues(alpha: 0.18)
          : AppColors.successLight;
    } else {
      fill = isDark ? AppColors.darkSurfaceMuted : AppColors.lightSurfaceMuted;
    }
    final valueColor = isInsufficient ? AppColors.error : AppColors.successDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isInsufficient ? 'Amount Short' : 'Change',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            isInsufficient
                ? '${AppConstants.currencySymbol}'
                    '${(cart.grandTotal - cart.amountReceived).toStringAsFixed(2)}'
                : '${AppConstants.currencySymbol}${change.toStringAsFixed(2)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: hasReceipt ? valueColor : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 6: Confirm no Cupertino left**

```bash
grep -n "CupertinoIcons\|cupertino" lib/presentation/mobile/widgets/pos/payment_section.dart
```
Expected: no output.

- [ ] **Step 7: Verify + commit**

```bash
flutter analyze lib/presentation/mobile/widgets/pos/payment_section.dart
flutter test
```
Expected: green (incl. `cart_tenders_test.dart`).

```bash
git add lib/presentation/mobile/widgets/pos/payment_section.dart
git commit -m "feat(checkout): Lucide payment pill chips + filled success-tint Change box"
```

---

### Task 8: Success dialog — filled check, CHANGE DUE hero

**Files:**
- Modify: `lib/presentation/mobile/widgets/pos/checkout_success_dialog.dart`

**Interfaces:**
- Consumes: `LucideIcons`, `AppColors`, `AppRadius`, `AppSpacing`. Public API unchanged.

- [ ] **Step 1: Swap imports**

Replace line 2 (`import 'package:flutter/cupertino.dart';`) with:

```dart
import 'package:lucide_icons/lucide_icons.dart';
```

- [ ] **Step 2: Success glyph → filled success-tint circle + Lucide check**

In `build`, replace the success-glyph `Container` (lines 101-112) with:

```dart
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AppColors.success.withValues(alpha: 0.18)
                      : AppColors.successLight,
                ),
                child: const Icon(
                  LucideIcons.check,
                  color: AppColors.successDark,
                  size: 48,
                ),
              ),
```

- [ ] **Step 3: Title size 20**

`Payment Successful!` (line 116) uses `headlineSmall` (already 20) w600 — leave it.

- [ ] **Step 4: Insert the CHANGE DUE hero and slim the amount card**

In `build`, the current order is: sale-number pill → `_buildAmountCard` → warnings → buttons. Replace the `_buildAmountCard(theme)` call (line 142) with a hero + slim amount card:

```dart
              _buildChangeDueHero(theme, isDark),
              const SizedBox(height: AppSpacing.md),
              _buildAmountCard(theme, mutedFill, hairline),
```

- [ ] **Step 5: Add `_buildChangeDueHero` and rewrite `_buildAmountCard`**

Replace `_buildAmountCard` (lines 190-224) and its row helper with:

```dart
  Widget _buildChangeDueHero(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.success.withValues(alpha: 0.18)
            : AppColors.successLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Text(
            'CHANGE DUE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.successDark,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${AppConstants.currencySymbol}'
            '${widget.sale.changeGiven.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: AppColors.successDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(ThemeData theme, Color fill, Color hairline) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: hairline),
      ),
      child: Column(
        children: [
          _buildAmountRow(
            theme,
            'Total',
            '${AppConstants.currencySymbol}'
            '${widget.sale.grandTotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildAmountRow(
            theme,
            'Received',
            '${AppConstants.currencySymbol}'
            '${widget.sale.amountReceived.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(ThemeData theme, String label, String value) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 6: Receipt + Warnings icons → Lucide**

Receipt button icon (line 159) `CupertinoIcons.doc_text` → `LucideIcons.receipt`. Warnings header icon (line 267) `CupertinoIcons.exclamationmark_triangle` → `LucideIcons.alertTriangle`.

- [ ] **Step 7: Confirm no Cupertino left**

```bash
grep -n "CupertinoIcons\|cupertino" lib/presentation/mobile/widgets/pos/checkout_success_dialog.dart
```
Expected: no output.

- [ ] **Step 8: Verify + commit**

```bash
flutter analyze lib/presentation/mobile/widgets/pos/checkout_success_dialog.dart
flutter test
```
Expected: green.

```bash
git add lib/presentation/mobile/widgets/pos/checkout_success_dialog.dart
git commit -m "feat(checkout): success dialog filled check + CHANGE DUE hero"
```

---

### Task 9: Barcode scanner — gold brackets, blurred pill, translucent controls

**Files:**
- Modify: `lib/presentation/mobile/screens/pos/barcode_scanner_screen.dart`

**Interfaces:**
- Consumes: `LucideIcons`, `AppColors`, `dart:ui` (`ImageFilter`). Detection/pop behavior unchanged.
- Produces: private `_CornerBracketsPainter`.

- [ ] **Step 1: Swap imports**

Replace line 1 (`import 'package:flutter/cupertino.dart';`) with:

```dart
import 'dart:ui';

import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
```

(Keep material, services, mobile_scanner.)

- [ ] **Step 2: App-bar chrome — Lucide + translucent circular buttons**

Replace the `appBar: AppBar(...)` (lines 60-90) with translucent circular controls:

```dart
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: _circleButton(
          icon: LucideIcons.x,
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Scan Barcode'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchOn = state.torchState == TorchState.on;
              return _circleButton(
                icon: torchOn ? LucideIcons.flashlight : LucideIcons.flashlightOff,
                tooltip: torchOn ? 'Turn torch off' : 'Turn torch on',
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          _circleButton(
            icon: LucideIcons.switchCamera,
            tooltip: 'Flip camera',
            onPressed: () => _controller.switchCamera(),
          ),
          const SizedBox(width: 4),
        ],
      ),
```

Add this helper method to `_BarcodeScannerScreenState` (after `_onDetect`):

```dart
  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 20),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      ),
    );
  }
```

- [ ] **Step 3: Rewrite the viewfinder overlay — gold brackets + gold scan line + blurred pill**

Replace `_ViewfinderOverlay` (lines 109-142) with:

```dart
class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  static const double _boxSize = 248;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _boxSize,
            height: _boxSize,
            child: CustomPaint(
              painter: _CornerBracketsPainter(),
              child: Center(
                child: Container(
                  width: _boxSize - 32,
                  height: 2,
                  color: AppColors.primaryAccent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Blurred dark instruction pill.
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.black.withValues(alpha: 0.45),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.scanLine,
                        color: AppColors.primaryAccent, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Hold a barcode inside the box',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints four gold L-shaped corner brackets on the viewfinder box.
class _CornerBracketsPainter extends CustomPainter {
  static const double _len = 28; // arm length
  static const double _r = 20; // corner radius

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, _r + _len)
        ..lineTo(0, _r)
        ..arcToPoint(Offset(_r, 0), radius: const Radius.circular(_r))
        ..lineTo(_r + _len, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - _r - _len, 0)
        ..lineTo(w - _r, 0)
        ..arcToPoint(Offset(w, _r), radius: const Radius.circular(_r))
        ..lineTo(w, _r + _len),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w, h - _r - _len)
        ..lineTo(w, h - _r)
        ..arcToPoint(Offset(w - _r, h), radius: const Radius.circular(_r))
        ..lineTo(w - _r - _len, h),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(_r + _len, h)
        ..lineTo(_r, h)
        ..arcToPoint(Offset(0, h - _r), radius: const Radius.circular(_r))
        ..lineTo(0, h - _r - _len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

- [ ] **Step 4: Confirm no Cupertino / old Material icons left**

```bash
grep -n "CupertinoIcons\|cupertino\|Icons.flash\|Icons.cameraswitch" lib/presentation/mobile/screens/pos/barcode_scanner_screen.dart
```
Expected: no output.

- [ ] **Step 5: Verify + commit**

```bash
flutter analyze lib/presentation/mobile/screens/pos/barcode_scanner_screen.dart
flutter test
```
Expected: green.

```bash
git add lib/presentation/mobile/screens/pos/barcode_scanner_screen.dart
git commit -m "feat(pos): scanner gold brackets, blurred instruction pill, translucent controls"
```

---

### Task 10: Full-suite verification + handoff

**Files:** none (verification only)

- [ ] **Step 1: Full analyze + test sweep**

```bash
flutter analyze
flutter test
```
Expected: analyze reports no new issues vs. baseline; all tests pass. If `flutter analyze` flags pre-existing issues unrelated to this work, note them but do not fix in this branch.

- [ ] **Step 2: Confirm the migration is complete across the flow**

```bash
grep -rn "CupertinoIcons\|package:flutter/cupertino.dart" \
  lib/presentation/mobile/screens/pos lib/presentation/mobile/widgets/pos
```
Expected: only `app_dropdown.dart` is out of scope and lives elsewhere — this grep should return NO output for the POS screens/widgets. (`receipt_widget.dart`, `void_sale_dialog.dart`, `request_void_dialog.dart` are NOT in the handoff; if they still import cupertino that is acceptable and out of scope.)

- [ ] **Step 3: Manual on-device verification (user)**

The agent can build but cannot install/smoke-test (see project memory `project_mobile_release`). Hand off this checklist to the user:
- Light + dark: POS (search pill, type a query → soft-shadow dropdown, out-of-stock row disabled, tap adds), cart cards, labor expansion, hero Total, pinned Proceed/Save bar.
- Checkout: order items card, hero Total, all 5 payment pill chips select + swap inputs, Cash Change box (filled tint; short → red "Amount Short"), Mixed/Salmon math, 52px green Confirm with glow + spinner.
- Success dialog: filled check, CHANGE DUE hero (₱ 40/700), Total/Received card, Receipt + Done.
- Scanner: gold brackets, gold scan line, blurred pill, translucent close/torch/flip; scan returns to search.

- [ ] **Step 4: Build the release APK (optional, for the user to install)**

```bash
flutter build apk --release
```
Expected: APK at `build/app/outputs/flutter-apk/app-release.apk` (debug-signed per project release process).

- [ ] **Step 5: Finish the branch**

Use the `finishing-a-development-branch` skill to merge to local `main` (do not push/deploy unless the user asks).

## Self-Review

**Spec coverage:**
- AppCard primitive → Task 1 ✓
- POS app bar / search pill / dropdown → Tasks 2, 5 ✓
- CartItemTile / CartSummary / Labor / Mechanic → Tasks 3, 4, 5 ✓
- Pinned action bar (POS) → Task 5 ✓
- Checkout surfaces / hero Total / error banner / green confirm → Task 6 ✓
- Payment pill chips / filled Change box / Exact → Task 7 ✓
- Success dialog filled check + CHANGE DUE hero → Task 8 ✓
- Scanner brackets / pill / translucent controls → Task 9 ✓
- Icon migration (sale-flow only) → every task + Task 10 grep ✓
- Minimal testing (keep green, fix matcher) → Task 3 + per-task gates + Task 10 ✓
- Branch/commit/no-deploy → Task 1 + Task 10 ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code or an exact old→new line reference. The print path stays a stub by design (out of scope).

**Type consistency:** `AppShadows.confirmButton({bool dark})` / `pinnedFooter({bool dark})` defined in Task 1, consumed in Tasks 5/6 with the same signature. `AppCard` named params (`child`, `padding`, `margin`, `radius`, `onTap`, `clipBehavior`) defined in Task 1, used consistently in Tasks 2-8. `_PaymentMethodChip` (Task 7) and `_CornerBracketsPainter` (Task 9) are file-local, no cross-task references. `PaymentMethod` cases match the enum (`cash/gcash/maya/mixed/salmon`).

**Note on `headlineSmall` for hero Total (Task 6 Step 5):** the explicit `TextStyle(fontWeight: w700, fontSize: 26)` is the source of truth for the 26px hero; the `headlineSmall` mention is illustrative only — use the explicit-size version.
