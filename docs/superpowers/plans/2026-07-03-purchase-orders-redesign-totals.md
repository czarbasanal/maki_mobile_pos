# Purchase Orders Redesign + Totals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recreate the approved Purchase Orders visual redesign (`design/design_handoff_purchase_orders/`) in the Flutter app, plus user-approved subtotal/grand-total lines on every PO surface — never in the CSV export.

**Architecture:** In-place presentation-layer restyle of the three existing PO screens + status pill, in dependency order: shared tokens/widgets first, then list → detail → new-PO → add-products sheet → nav icon. Zero provider, repository, entity, lifecycle, permission, or CSV-builder changes; totals reuse existing entity math (`item.totalCost`, `recalculateTotals()`).

**Tech Stack:** Flutter (root app), Riverpod, `lucide_icons_flutter 3.1.14+2`, `fake_cloud_firestore` for widget tests. All commands run from the repo root. Spec: `docs/superpowers/specs/2026-07-03-purchase-orders-redesign-totals-design.md`. Work happens on the existing branch `feat/po-redesign-totals`.

## Global Constraints

- **Rule 1 (handoff):** pixel-faithful to `design/design_handoff_purchase_orders/MAKI POS Purchase Orders.dc.html`, **both light and dark**, exact copy strings, Lucide icons only. When a value is missing here, read the mock/README — do not invent.
- **Rule 2 (handoff):** no new wiring beyond what this plan specifies (all items were user-confirmed 2026-07-03).
- Totals visible to staff + admin (no role gating); amounts always via `num.toCurrency()` → `₱5,430.00`; `unitCost == 0` renders `₱0.00` with no special case.
- CSV (`lib/core/utils/purchase_order_csv.dart`) must NOT change.
- Providers (`purchase_order_provider.dart`), repos, entities, `firestore.rules`: untouched.
- Copy decision (approved): the create button reads `Create N purchase order(s)` with live supplier-group count; when nothing is checked it reads `Create purchase orders` (disabled).
- Test gate per task: named `flutter test` targets green; final task runs `flutter analyze` + full `flutter test`.
- Commit after every task (already on branch `feat/po-redesign-totals`; do not push).

---

### Task 1: Foundation — AppColors tokens, friendly date, tokenized status style, shared PO widgets

**Files:**
- Modify: `lib/core/theme/app_colors.dart` (append inside the SEMANTIC COLORS region, after `neutralTileFill`, ~line 175)
- Modify: `lib/core/extensions/datetime_extensions.dart` (after `toShortDateTime()`, ~line 22)
- Modify: `lib/presentation/mobile/widgets/purchase_orders/purchase_order_status_style.dart`
- Create: `lib/presentation/mobile/widgets/purchase_orders/po_widgets.dart`
- Test (create): `test/presentation/mobile/widgets/purchase_orders/purchase_order_status_style_test.dart`
- Test (create): `test/core/extensions/datetime_extensions_test.dart`
- Test (create): `test/presentation/mobile/widgets/purchase_orders/po_widgets_test.dart`

**Interfaces:**
- Consumes: existing `AppColors` statics, `AppRadius`, `AppShadows.card(dark:)`, `theme.colorScheme` (primary = slate light / gold dark).
- Produces (used by Tasks 2–5):
  - `AppColors.poDraftFg/poDraftBg/poOrderedFg/poOrderedBg/poReceivedFg/poReceivedBg/poCancelledFg/poCancelledBg(bool dark) → Color`
  - `AppColors.checkboxBorder(bool dark) → Color`
  - `AppColors.amberNoteFill/amberNoteBorder/amberNoteText/amberNoteIcon(bool dark) → Color`
  - `DateTime.toFriendlyDateTime() → String` ("Jul 3, 9:41 AM")
  - `PoGlyphTile({required IconData icon})` — 40px neutral tile
  - `PoStepperButton({required IconData icon, VoidCallback? onTap, double size = 26, double radius = 8})`
  - `PoQtyBadge({required int quantity, required bool locked})`
  - `PoAmberNote({required String text})`
  - `PoSectionHeader({required IconData icon, required String label, String? trailing})`
  - `poFooterDecoration(bool dark) → BoxDecoration` — pinned-footer surface (white/darkCard + up-shadow)

- [ ] **Step 1: Write the failing tests**

`test/core/extensions/datetime_extensions_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/extensions/datetime_extensions.dart';

void main() {
  test('toFriendlyDateTime renders "Jul 3, 9:41 AM"', () {
    expect(DateTime(2026, 7, 3, 9, 41).toFriendlyDateTime(), 'Jul 3, 9:41 AM');
    expect(DateTime(2026, 12, 25, 14, 5).toFriendlyDateTime(), 'Dec 25, 2:05 PM');
  });
}
```

`test/presentation/mobile/widgets/purchase_orders/purchase_order_status_style_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/purchase_order_status_style.dart';

void main() {
  test('status styles resolve to the AppColors PO tokens in both themes', () {
    for (final dark in [false, true]) {
      final draft =
          PurchaseOrderStatusStyle.of(PurchaseOrderStatus.draft, dark: dark);
      expect(draft.textColor, AppColors.poDraftFg(dark), reason: 'dark=$dark');
      expect(draft.tint, AppColors.poDraftBg(dark));

      final ordered =
          PurchaseOrderStatusStyle.of(PurchaseOrderStatus.ordered, dark: dark);
      expect(ordered.textColor, AppColors.poOrderedFg(dark));
      expect(ordered.tint, AppColors.poOrderedBg(dark));

      final received =
          PurchaseOrderStatusStyle.of(PurchaseOrderStatus.received, dark: dark);
      expect(received.textColor, AppColors.poReceivedFg(dark));
      expect(received.tint, AppColors.poReceivedBg(dark));

      final cancelled = PurchaseOrderStatusStyle.of(
          PurchaseOrderStatus.cancelled,
          dark: dark);
      expect(cancelled.textColor, AppColors.poCancelledFg(dark));
      expect(cancelled.tint, AppColors.poCancelledBg(dark));
    }
  });

  test('token values match the handoff table (light)', () {
    expect(AppColors.poOrderedFg(false), const Color(0xFFC8881A));
    expect(AppColors.poDraftBg(false), const Color(0x14000000));
    expect(AppColors.poCancelledBg(false), const Color(0x1AF44336));
  });
}
```

(Add `import 'package:flutter/widgets.dart';` if `Color` is unresolved.)

`test/presentation/mobile/widgets/purchase_orders/po_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/po_widgets.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))));

  testWidgets('PoQtyBadge shows Nx and switches locked style', (tester) async {
    await pump(tester, const PoQtyBadge(quantity: 10, locked: false));
    expect(find.text('10x'), findsOneWidget);
    await pump(tester, const PoQtyBadge(quantity: 4, locked: true));
    expect(find.text('4x'), findsOneWidget);
  });

  testWidgets('PoStepperButton fires onTap only when enabled', (tester) async {
    var taps = 0;
    await pump(tester,
        PoStepperButton(icon: LucideIcons.plus, onTap: () => taps++));
    await tester.tap(find.byIcon(LucideIcons.plus));
    expect(taps, 1);
    await pump(tester, const PoStepperButton(icon: LucideIcons.minus));
    await tester.tap(find.byIcon(LucideIcons.minus));
    expect(taps, 1, reason: 'disabled button must not fire');
  });

  testWidgets('PoAmberNote renders the warning text with the alert glyph',
      (tester) async {
    await pump(tester, const PoAmberNote(text: 'Careful now'));
    expect(find.text('Careful now'), findsOneWidget);
    expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
  });

  testWidgets('PoSectionHeader shows label and trailing', (tester) async {
    await pump(
        tester,
        const PoSectionHeader(
            icon: LucideIcons.trendingUp, label: 'Recommended', trailing: '3'));
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/extensions/datetime_extensions_test.dart test/presentation/mobile/widgets/purchase_orders/`
Expected: FAIL — `toFriendlyDateTime` undefined, `AppColors.poDraftFg` undefined, `po_widgets.dart` missing (compile errors count as the failing state).

- [ ] **Step 3: Implement**

**3a — `lib/core/theme/app_colors.dart`:** append after the `neutralTileFill` block (before `// ==================== POS SPECIFIC COLORS`):

```dart
  // ── Purchase-order status pill (PO redesign handoff §Design tokens) ──
  // draft neutral · ordered amber (in flight) · received green · cancelled
  // red. Values are the handoff table, verbatim; existing semantic tokens are
  // reused where they already match.
  static Color poDraftFg(bool dark) =>
      dark ? darkTextSecondary : lightTextSecondary;
  static Color poDraftBg(bool dark) =>
      dark ? const Color(0x1FFFFFFF) : const Color(0x14000000);
  static Color poOrderedFg(bool dark) =>
      dark ? warningOnDark : const Color(0xFFC8881A);
  static Color poOrderedBg(bool dark) =>
      dark ? const Color(0x24F5B547) : const Color(0x1FF57C00);
  static Color poReceivedFg(bool dark) => dark ? successOnDark : successDark;
  static Color poReceivedBg(bool dark) =>
      dark ? const Color(0x294CAF50) : successLight;
  static Color poCancelledFg(bool dark) => dark ? errorOnDark : error;
  static Color poCancelledBg(bool dark) =>
      dark ? const Color(0x24FF6B5E) : const Color(0x1AF44336);

  /// Unchecked-checkbox border (PO suggestion rows).
  static Color checkboxBorder(bool dark) =>
      dark ? const Color(0xFF3A4A4D) : const Color(0xFFC9CFD2);

  // ── Amber inline note (PO cap warning). Mock-exact palette — softer than
  // the reports' warningBanner*, so it gets its own tokens. ──
  static Color amberNoteFill(bool dark) =>
      dark ? const Color(0x1AE8B84C) : const Color(0xFFFBF3DE);
  static Color amberNoteBorder(bool dark) =>
      dark ? const Color(0x47E8B84C) : const Color(0x52B7831A);
  static Color amberNoteText(bool dark) =>
      dark ? const Color(0xFFD8B15A) : const Color(0xFF7A6320);
  static Color amberNoteIcon(bool dark) =>
      dark ? primaryAccent : const Color(0xFF9A7B1F);
```

**3b — `lib/core/extensions/datetime_extensions.dart`:** insert after `toShortDateTime()`:

```dart
  /// Friendly compact date-time for card/detail meta (PO redesign).
  ///
  /// Example: "Jul 3, 9:41 AM"
  String toFriendlyDateTime() {
    return DateFormat('MMM d, h:mm a').format(this);
  }
```

**3c — `lib/presentation/mobile/widgets/purchase_orders/purchase_order_status_style.dart`:** replace the whole `of` method body so every literal comes from the new tokens (icons unchanged):

```dart
  static PurchaseOrderStatusStyle of(PurchaseOrderStatus status,
      {required bool dark}) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.pencilLine,
          textColor: AppColors.poDraftFg(dark),
          tint: AppColors.poDraftBg(dark),
        );
      case PurchaseOrderStatus.ordered:
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.send,
          textColor: AppColors.poOrderedFg(dark),
          tint: AppColors.poOrderedBg(dark),
        );
      case PurchaseOrderStatus.received:
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.packageCheck,
          textColor: AppColors.poReceivedFg(dark),
          tint: AppColors.poReceivedBg(dark),
        );
      case PurchaseOrderStatus.cancelled:
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.ban,
          textColor: AppColors.poCancelledFg(dark),
          tint: AppColors.poCancelledBg(dark),
        );
    }
  }
```

(The "deep amber has no token" comment is now obsolete — delete it.)

**3d — Create `lib/presentation/mobile/widgets/purchase_orders/po_widgets.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Small building blocks shared by the redesigned purchase-order screens
/// (list · new · detail). Mock: design/design_handoff_purchase_orders.

/// 40px neutral glyph tile — list card + detail header.
class PoGlyphTile extends StatelessWidget {
  const PoGlyphTile({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.neutralTileFill(dark),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// Bordered square icon button — the 26px stepper-pill cells ([−] [+] [×])
/// and the 30px params cover stepper. Disabled = null [onTap] (glyph fades
/// to hint).
class PoStepperButton extends StatelessWidget {
  const PoStepperButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 26,
    this.radius = 8,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: dark ? AppColors.darkSurfaceMuted : Colors.white,
          border: Border.all(
            color: dark ? AppColors.darkInputBorder : AppColors.lightInputBorder,
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(
          icon,
          size: 14,
          color: onTap != null
              ? theme.colorScheme.onSurfaceVariant
              : (dark ? AppColors.darkTextHint : AppColors.lightTextHint),
        ),
      ),
    );
  }
}

/// 40px quantity badge on detail item rows — primary outline while the PO is
/// editable (draft), neutral tint once locked.
class PoQtyBadge extends StatelessWidget {
  const PoQtyBadge({super.key, required this.quantity, required this.locked});

  final int quantity;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: locked
          ? BoxDecoration(
              color: AppColors.neutralTileFill(dark),
              borderRadius: BorderRadius.circular(10),
            )
          : BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary, width: 1.4),
              borderRadius: BorderRadius.circular(10),
            ),
      child: Text(
        '${quantity}x',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: locked
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Amber inline note (cap warning) — mock-exact palette via AppColors.amberNote*.
class PoAmberNote extends StatelessWidget {
  const PoAmberNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.amberNoteFill(dark),
        border: Border.all(color: AppColors.amberNoteBorder(dark)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(LucideIcons.triangleAlert,
                size: 15, color: AppColors.amberNoteIcon(dark)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppColors.amberNoteText(dark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header row — 16px glyph · 13/600 label · right-aligned trailing.
class PoSectionHeader extends StatelessWidget {
  const PoSectionHeader({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: muted),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    dark ? AppColors.darkTextHint : AppColors.lightTextHint,
              ),
            ),
        ],
      ),
    );
  }
}

/// Pinned-footer surface — white card + soft up-shadow in light, darkCard +
/// hairline top border in dark (mock footer elevation).
BoxDecoration poFooterDecoration(bool dark) => BoxDecoration(
      color: dark ? AppColors.darkCard : Colors.white,
      border: dark
          ? const Border(top: BorderSide(color: AppColors.darkHairline))
          : null,
      boxShadow: [
        BoxShadow(
          color: dark ? const Color(0x66000000) : const Color(0x0F111C1D),
          offset: const Offset(0, -4),
          blurRadius: 16,
        ),
      ],
    );
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/extensions/datetime_extensions_test.dart test/presentation/mobile/widgets/purchase_orders/`
Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/theme/app_colors.dart lib/core/extensions/datetime_extensions.dart lib/presentation/mobile/widgets/purchase_orders/ test/core/extensions/datetime_extensions_test.dart test/presentation/mobile/widgets/purchase_orders/
git commit -m "feat(po): PO status/amber/checkbox tokens, friendly date, shared PO widgets

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Purchase Orders list — redesign + card total

**Files:**
- Modify: `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart` (full rewrite below)
- Test (modify): `test/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen_test.dart`

**Interfaces:**
- Consumes (Task 1): `PoGlyphTile`, `toFriendlyDateTime()`, `toCurrency()` (existing `num_extensions.dart`).
- Produces: filter pills keyed `Key('po-filter-all')` / `Key('po-filter-<status.name>')`; app-bar create action with tooltip `'New purchase order'`. No API other tasks consume.

- [ ] **Step 1: Rewrite the tests to describe the redesigned screen**

Replace the whole test file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';

void main() {
  PurchaseOrderEntity po(String ref, PurchaseOrderStatus status,
          {double totalCost = 0}) =>
      PurchaseOrderEntity(
        id: ref,
        referenceNumber: ref,
        supplierName: 'Acme',
        items: const [
          PurchaseOrderItemEntity(
            id: 'p1',
            productId: 'p1',
            sku: 'SKU-1',
            name: 'Brake Pad',
            quantity: 3,
            unit: 'pcs',
            unitCost: 55,
            costCode: 'NBF',
          ),
        ],
        totalCost: totalCost,
        totalQuantity: 3,
        status: status,
        createdAt: DateTime(2026, 7, 3, 9, 41),
        createdBy: 'u1',
        createdByName: 'Admin',
      );

  Future<void> pump(WidgetTester tester, List<PurchaseOrderEntity> pos) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        purchaseOrdersProvider.overrideWith((ref) => Stream.value(pos)),
      ],
      child: const MaterialApp(home: PurchaseOrdersScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('lists purchase orders with supplier, pill, total, friendly date',
      (tester) async {
    await pump(tester, [
      po('PO-20260703-001', PurchaseOrderStatus.draft, totalCost: 5430),
      po('PO-20260703-002', PurchaseOrderStatus.ordered, totalCost: 165),
    ]);
    expect(find.text('PO-20260703-001'), findsOneWidget);
    expect(find.text('PO-20260703-002'), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Ordered'), findsWidgets);
    // Totals addition: PO grand total on the card, primary-colored.
    expect(find.text('₱5,430.00'), findsOneWidget);
    expect(find.text('₱165.00'), findsOneWidget);
    // Friendly dates + meta line.
    expect(find.text('Jul 3, 9:41 AM'), findsNWidgets(2));
    expect(find.text('1 item · 3 pcs · by Admin'), findsNWidgets(2));
  });

  testWidgets('status pill filters the list', (tester) async {
    await pump(tester, [
      po('PO-20260703-001', PurchaseOrderStatus.draft),
      po('PO-20260703-002', PurchaseOrderStatus.ordered),
    ]);
    await tester.tap(find.byKey(const Key('po-filter-ordered')));
    await tester.pumpAndSettle();
    expect(find.text('PO-20260703-001'), findsNothing);
    expect(find.text('PO-20260703-002'), findsOneWidget);
    await tester.tap(find.byKey(const Key('po-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('PO-20260703-001'), findsOneWidget);
  });

  testWidgets('empty state is tiled with a New purchase order CTA; create is an app-bar action',
      (tester) async {
    await pump(tester, []);
    expect(find.text('No purchase orders yet'), findsOneWidget);
    expect(
        find.text(
            'Suggestions come from your stock movement. Start one to draft what to buy.'),
        findsOneWidget);
    expect(find.text('New purchase order'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('New purchase order'), findsOneWidget);
    expect(find.byIcon(LucideIcons.plus), findsWidgets);
  });

  testWidgets('error state offers retry', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        purchaseOrdersProvider
            .overrideWith((ref) => Stream.error(Exception('boom'))),
      ],
      child: const MaterialApp(home: PurchaseOrdersScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget,
        reason: 'retry re-subscribes (same failing override) without crashing');
  });
}
```

- [ ] **Step 2: Run to verify the new expectations fail**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen_test.dart`
Expected: FAIL — no `Key('po-filter-ordered')`, `₱5,430.00` not found, FAB still present, etc. (`lists purchase orders…` partially passes on ref/pill finds; the new finds fail.)

- [ ] **Step 3: Rewrite the screen**

Replace the entire file `purchase_orders_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/extensions/datetime_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/po_widgets.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/purchase_order_status_pill.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/state_views.dart';

/// Purchase orders list — status filter pills over streamed PO cards.
/// Redesign: design/design_handoff_purchase_orders (screen 1 + 2).
class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  ConsumerState<PurchaseOrdersScreen> createState() =>
      _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
  PurchaseOrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(purchaseOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          // Top-level destination (dashboard Reorder pill uses `go`) — there
          // may be nothing to pop.
          onPressed: () => context.goBackOr(RoutePaths.dashboard),
        ),
        title: const Text('Purchase Orders'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            tooltip: 'New purchase order',
            onPressed: () => context.push(RoutePaths.purchaseOrderNew),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterPill(
                  key: const Key('po-filter-all'),
                  label: 'All',
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final status in PurchaseOrderStatus.values) ...[
                  const SizedBox(width: 8),
                  _FilterPill(
                    key: Key('po-filter-${status.name}'),
                    label: status.displayName,
                    selected: _filter == status,
                    onTap: () => setState(() => _filter = status),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorStateView(
                message: 'Failed to load: $e',
                onRetry: () => ref.invalidate(purchaseOrdersProvider),
              ),
              data: (orders) {
                final visible = _filter == null
                    ? orders
                    : orders.where((o) => o.status == _filter).toList();
                if (visible.isEmpty) {
                  return EmptyStateView(
                    tiled: true,
                    icon: LucideIcons.clipboardList,
                    title: 'No purchase orders yet',
                    subtitle: 'Suggestions come from your stock movement. '
                        'Start one to draft what to buy.',
                    action: FilledButton.icon(
                      onPressed: () =>
                          context.push(RoutePaths.purchaseOrderNew),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('New purchase order'),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _OrderCard(order: visible[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 34px status filter pill — selected = solid primary fill (slate/gold),
/// unselected = card surface + hairline border.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : (dark ? AppColors.darkCard : AppColors.lightCard),
          border: selected
              ? null
              : Border.all(color: AppColors.hairline(dark)),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final PurchaseOrderEntity order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    final items = order.uniqueProductCount;
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(13),
      onTap: () => context.push('${RoutePaths.purchaseOrders}/${order.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PoGlyphTile(icon: LucideIcons.clipboardList),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.supplierName ?? 'No supplier',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.referenceNumber,
                      style: TextStyle(
                        fontFamily: AppTextStyles.monoFontFamily,
                        fontSize: 11,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PurchaseOrderStatusPill(status: order.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '$items ${items == 1 ? 'item' : 'items'} · '
                  '${order.totalQuantity} pcs · by ${order.createdByName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Totals addition (user-approved; not in the mock): PO grand
                  // total in the Job Orders money language.
                  Text(
                    order.totalCost.toCurrency(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.createdAt.toFriendlyDateTime(),
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen_test.dart`
Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart test/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen_test.dart
git commit -m "feat(po): redesign PO list — filter pills, glyph-tile cards, card totals, app-bar create

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: PO detail — redesign + per-item subtotals + footer grand total

**Files:**
- Modify: `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart`
- Test (modify): `test/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen_test.dart`

**Interfaces:**
- Consumes (Task 1): `PoGlyphTile`, `PoQtyBadge`, `PoStepperButton`, `PoSectionHeader`, `poFooterDecoration`, `toFriendlyDateTime()`, `toCurrency()`.
- Produces: no API other tasks consume. Behavior preserved verbatim: `_pending` buffering, `_run`, `_receive`, `_shareCsv`, `_onMenu`, `_stageQty`, `_stageRemove`, `_saveChanges` — do not modify those methods except where shown.

- [ ] **Step 1: Update tests for the new anatomy + totals**

In `purchase_order_detail_screen_test.dart`, apply these edits:

1. In `'draft shows items and Mark ordered'`: the PO ref now renders twice (mono app-bar title + header card):

```dart
  testWidgets('draft shows items and Mark ordered', (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    expect(find.text('PO-20260703-001'), findsNWidgets(2));
    expect(find.text('Brake Pad'), findsOneWidget);
    expect(find.text('Mark ordered'), findsOneWidget);
    expect(find.text('Receive delivery'), findsNothing);
  });
```

2. In `'Mark ordered transitions to ordered with Receive'` and `'Receive creates a linked draft receiving'`: replace `find.text('Receive')` with `find.text('Receive delivery')`.

3. In `'qty edits are buffered locally and flushed by Save changes'`: the staged qty now renders inside the qty badge as `6x` (no bare `6` text):

```dart
    expect(find.text('6x'), findsOneWidget);
```

(keep every other line of that test unchanged).

4. Append these new tests before the closing `}` of `main`:

```dart
  testWidgets('shows per-item subtotal line and footer grand total',
      (tester) async {
    final po = await seed(); // 4 × ₱55 = ₱220
    await pump(tester, po.id, UserRole.staff);
    expect(find.text('₱55.00 each'), findsOneWidget);
    // Row subtotal + footer grand total are the same amount here.
    expect(find.text('₱220.00'), findsNWidgets(2));
    expect(find.textContaining('Total '), findsOneWidget);
  });

  testWidgets('staged qty edits recompute subtotal and grand total live',
      (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.byIcon(LucideIcons.plus).first);
    await tester.pumpAndSettle();
    // 5 × ₱55 — row and footer both update before any write.
    expect(find.text('₱275.00'), findsNWidgets(2));
    final doc = await fake.collection('purchase_orders').doc(po.id).get();
    expect((doc.data()!['items'] as List).first['quantity'], 4,
        reason: 'recompute is local; nothing written yet');
  });

  testWidgets('cancelled PO keeps the grand total but drops all actions',
      (tester) async {
    final po = await seed();
    await repo.cancelPurchaseOrder(po.id);
    await pump(tester, po.id, UserRole.staff);
    expect(find.text('₱220.00'), findsNWidgets(2));
    expect(find.text('Share CSV'), findsNothing);
    expect(find.text('Mark ordered'), findsNothing);
  });

  testWidgets('item remove control is the × stepper button', (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.text('Last item — delete the purchase order instead'),
        findsOneWidget);
  });
```

- [ ] **Step 2: Run to verify the new expectations fail**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen_test.dart`
Expected: FAIL — `Receive delivery` not found, `₱55.00 each` not found, `6x` not found, `LucideIcons.x` not found.

- [ ] **Step 3: Restyle the screen**

Keep all logic methods untouched. Apply exactly these changes to `purchase_order_detail_screen.dart`:

**3a — imports:** add:

```dart
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/po_widgets.dart';
```

and delete the now-unused `import ... datetime_extensions.dart`? **No — keep it**: `toFriendlyDateTime` lives there.

**3b — app bar** (replace the `AppBar` in `build`): mono PO-ref title + Lucide overflow glyph. The rest of `build` (poAsync.when / states) stays as-is.

```dart
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(
          poAsync.valueOrNull?.referenceNumber ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AppTextStyles.monoFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          poAsync.maybeWhen(
            data: (po) {
              if (po == null || (!po.canCancel && !isAdmin)) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                icon: const Icon(LucideIcons.ellipsisVertical, size: 20),
                onSelected: (v) => _onMenu(v, po),
                itemBuilder: (_) => [
                  if (po.canCancel)
                    const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                  if (isAdmin)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
```

**3c — replace `_buildBody`:**

```dart
  Widget _buildBody(PurchaseOrderEntity po) {
    final items = _pending ?? po.items;
    final totalQuantity =
        items.fold<int>(0, (sum, item) => sum + item.quantity);
    final totalCost =
        items.fold<double>(0, (sum, item) => sum + item.totalCost);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            children: [
              _headerCard(po),
              PoSectionHeader(
                icon: LucideIcons.package,
                label: 'Items',
                trailing: '${items.length} '
                    '${items.length == 1 ? 'item' : 'items'} · '
                    '$totalQuantity pcs',
              ),
              for (final item in items) _itemRow(po, item),
            ],
          ),
        ),
        _footer(po, items, totalQuantity, totalCost),
      ],
    );
  }
```

**3d — add `_headerCard` and `_metaLine`** (replacing the old inline `AppCard` block that `_buildBody` used to hold):

```dart
  Widget _headerCard(PurchaseOrderEntity po) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final secondary = theme.colorScheme.onSurfaceVariant;
    return AppCard(
      radius: AppRadius.lg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PoGlyphTile(icon: LucideIcons.truck),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      po.supplierName ?? 'No supplier',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      po.referenceNumber,
                      style: TextStyle(
                        fontFamily: AppTextStyles.monoFontFamily,
                        fontSize: 11,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PurchaseOrderStatusPill(status: po.status),
            ],
          ),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 11),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.hairline(dark))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _metaLine(LucideIcons.clock,
                    'Created ${po.createdAt.toFriendlyDateTime()} · by ${po.createdByName}'),
                if (po.orderedAt != null) ...[
                  const SizedBox(height: 4),
                  _metaLine(LucideIcons.send,
                      'Ordered ${po.orderedAt!.toFriendlyDateTime()}'),
                ],
                if (po.receivedAt != null) ...[
                  const SizedBox(height: 4),
                  _metaLine(LucideIcons.packageCheck,
                      'Received ${po.receivedAt!.toFriendlyDateTime()}'),
                ],
                if (po.notes != null && po.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(po.notes!,
                      style: TextStyle(fontSize: 12.5, color: secondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaLine(IconData icon, String text) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 14, color: secondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12.5, color: secondary)),
        ),
      ],
    );
  }
```

**3e — replace `_itemRow`:** qty badge + mono SKU + subtotal line + `[− + ×]` stepper pill (draft) / static qty (locked). `trash2` is gone — removal is the `×` cell.

```dart
  Widget _itemRow(PurchaseOrderEntity po, PurchaseOrderItemEntity item) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        radius: AppRadius.field,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            PoQtyBadge(quantity: item.quantity, locked: !po.canEdit),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'SKU: ${item.sku}',
                    style: TextStyle(
                      fontFamily: AppTextStyles.monoFontFamily,
                      fontSize: 11,
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Subtotal line (user-approved totals addition).
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.unitCost.toCurrency()} each',
                          style: TextStyle(fontSize: 12, color: secondary),
                        ),
                      ),
                      Text(
                        item.totalCost.toCurrency(),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (po.canEdit)
              Row(
                children: [
                  PoStepperButton(
                    icon: LucideIcons.minus,
                    onTap: _busy || item.quantity <= 1
                        ? null
                        : () => _stageQty(po, item, item.quantity - 1),
                  ),
                  const SizedBox(width: 4),
                  PoStepperButton(
                    icon: LucideIcons.plus,
                    onTap: _busy
                        ? null
                        : () => _stageQty(po, item, item.quantity + 1),
                  ),
                  const SizedBox(width: 4),
                  PoStepperButton(
                    icon: LucideIcons.x,
                    onTap: _busy ? null : () => _stageRemove(po, item),
                  ),
                ],
              )
            else
              Text(
                '${item.quantity} ${item.unit}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: secondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
```

**3f — replace `_editBar` and `_actionBar` with the pinned footer.** Delete both old methods; the `SafeArea(child: _dirty ? _editBar(po) : _actionBar(po))` line is gone (footer is composed inside `_buildBody` step 3c). Add:

```dart
  /// Pinned footer: grand-total row (always, every status — totals addition)
  /// over the per-status actions. Staged edits swap the actions to
  /// Save changes / Discard in the same slot.
  Widget _footer(PurchaseOrderEntity po, List<PurchaseOrderItemEntity> items,
      int totalQuantity, double totalCost) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final actions = _dirty ? _editActions(po) : _statusActions(po);

    return Container(
      decoration: poFooterDecoration(dark),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'Total ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(
                        text: '(${items.length} '
                            '${items.length == 1 ? 'item' : 'items'} · '
                            '$totalQuantity pcs)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  totalCost.toCurrency(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (actions != null) ...[
              const SizedBox(height: 12),
              actions,
            ],
          ],
        ),
      ),
    );
  }

  Widget _editActions(PurchaseOrderEntity po) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: _busy ? null : () => _saveChanges(po),
            child: const Text('Save changes'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: _busy ? null : () => setState(() => _pending = null),
            child: const Text('Discard'),
          ),
        ),
      ],
    );
  }

  Widget? _statusActions(PurchaseOrderEntity po) {
    switch (po.status) {
      case PurchaseOrderStatus.draft:
        return Row(
          children: [
            Expanded(
              flex: 5,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _shareCsv(po),
                icon: const Icon(LucideIcons.share2, size: 17),
                label: const Text('Share CSV'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => ref
                            .read(purchaseOrderRepositoryProvider)
                            .markOrdered(po.id),
                        'Marking ordered…'),
                icon: const Icon(LucideIcons.send, size: 17),
                label: const Text('Mark ordered'),
              ),
            ),
          ],
        );
      case PurchaseOrderStatus.ordered:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => ref
                                .read(purchaseOrderRepositoryProvider)
                                .revertToDraft(po.id),
                            'Reopening…'),
                    icon: const Icon(LucideIcons.undo2, size: 17),
                    label: const Text('Back to draft'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _shareCsv(po),
                    icon: const Icon(LucideIcons.share2, size: 17),
                    label: const Text('Share CSV'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _receive(po),
                icon: const Icon(LucideIcons.packageCheck, size: 18),
                label: const Text('Receive delivery'),
              ),
            ),
          ],
        );
      case PurchaseOrderStatus.received:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : () => _shareCsv(po),
                icon: const Icon(LucideIcons.share2, size: 17),
                label: const Text('Share CSV'),
              ),
            ),
            if (po.receivingId != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context
                      .push('${RoutePaths.bulkReceiving}/${po.receivingId}'),
                  child: const Text('View receiving'),
                ),
              ),
            ],
          ],
        );
      case PurchaseOrderStatus.cancelled:
        // Actions collapse; the grand-total row above still renders.
        return null;
    }
  }
```

Everything else in the file (`_stageQty`, `_stageRemove`, `_saveChanges`, `_run`, `_receive`, `_shareCsv`, `_onMenu`, states handling) stays byte-identical.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen_test.dart`
Expected: ALL PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart test/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen_test.dart
git commit -m "feat(po): redesign PO detail — mono-ref bar, qty-badge rows, item subtotals, pinned footer grand total

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: New Purchase Order — params card, segmented controls, row cards, live-count footer with running total

**Files:**
- Modify: `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart`
- Test (modify): `test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart`

**Interfaces:**
- Consumes (Task 1): `PoStepperButton`, `PoAmberNote`, `PoSectionHeader`, `poFooterDecoration`, `toCurrency()`.
- Produces (Task 5 relies on these staying stable): `_manual`, `_checkedOverride`, `_showAddProductSheet()` (old sheet still in place after this task — Task 5 replaces it). Test keys: `po-window-30/60/90`, `po-view-byStatus/bySupplier`, `po-cover-minus/plus`, `po-check-<productId>`, `po-create-button`.
- **The `_save` method and `_buildLines` bucket logic do not change.**

- [ ] **Step 1: Update tests**

Apply these edits to `new_purchase_order_screen_test.dart`:

1. `'default view groups by status'`: the low-stock top-up qty `4` still renders as the stepper qty text — keep `expect(find.text('4'), findsOneWidget)`. No changes needed to this test.

2. `'supplier toggle shows supplier groups'`: replace the ChoiceChip tap:

```dart
    await tester.tap(find.byKey(const Key('po-view-bySupplier')));
```

3. `'low/out rows are unchecked by default and excluded from save'` and `'save creates one draft PO per supplier'`: replace `find.text('Save drafts')` with `find.byKey(const Key('po-create-button'))`.

4. `'manually added product keeps its qty when params change'`: replace the window ChoiceChip tap:

```dart
    await tester.tap(find.byKey(const Key('po-window-30')));
```

(the sheet interaction lines stay as-is until Task 5).

5. `'unchecking a row excludes it from the save'`: replace the Checkbox tap and save tap:

```dart
    await tester.tap(find.byKey(const Key('po-check-p2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('po-create-button')));
```

6. Append new tests before the closing `}`:

```dart
  testWidgets('create button carries the live supplier-group count',
      (tester) async {
    await pump(tester, suggestions: [
      suggestion(product('p1'), 9),
      suggestion(product('p2', supplier: null), 4),
    ]);
    expect(find.text('Create 2 purchase orders'), findsOneWidget);
    await tester.tap(find.byKey(const Key('po-check-p2')));
    await tester.pumpAndSettle();
    expect(find.text('Create 1 purchase order'), findsOneWidget);
  });

  testWidgets('footer shows running total of checked lines only',
      (tester) async {
    // p1: 9 × ₱55 = ₱495; p2: 4 × ₱55 = ₱220 → both: ₱715.00
    await pump(tester, suggestions: [
      suggestion(product('p1'), 9),
      suggestion(product('p2', supplier: null), 4),
    ]);
    expect(find.textContaining('₱715.00'), findsOneWidget);
    expect(find.text('One PO per supplier'), findsOneWidget);
    await tester.tap(find.byKey(const Key('po-check-p2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('₱495.00'), findsOneWidget);
  });

  testWidgets('supplier view headers show checked subtotal', (tester) async {
    await pump(tester, suggestions: [suggestion(product('p1'), 9)]);
    await tester.tap(find.byKey(const Key('po-view-bySupplier')));
    await tester.pumpAndSettle();
    expect(find.text('1 item · ₱495.00'), findsOneWidget);
  });

  testWidgets('cover stepper applies after the debounce', (tester) async {
    final received = <({int coverDays, int windowDays})>[];
    final fake = FakeFirebaseFirestore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(fake),
        productsProvider
            .overrideWith((ref) => Stream.value([product('p1')])),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        reorderSuggestionsProvider.overrideWith((ref, params) async {
          received.add(params);
          return ReorderResult(
              suggestions: [suggestion(product('p1'), 9)],
              lowStock: const [],
              outOfStock: const [],
              capped: false);
        }),
      ],
      child: const MaterialApp(home: NewPurchaseOrderScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('po-cover-plus')));
    await tester.pump();
    expect(find.text('31'), findsOneWidget,
        reason: 'display updates instantly');
    expect(received.map((p) => p.coverDays), isNot(contains(31)),
        reason: 'refetch waits for the debounce');

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(received.map((p) => p.coverDays), contains(31));
  });

  testWidgets('cap note renders the amber warning copy', (tester) async {
    final fake = FakeFirebaseFirestore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(fake),
        productsProvider
            .overrideWith((ref) => Stream.value([product('p1')])),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        reorderSuggestionsProvider.overrideWith((ref, params) async =>
            ReorderResult(
                suggestions: [suggestion(product('p1'), 9)],
                lowStock: const [],
                outOfStock: const [],
                capped: true)),
      ],
      child: const MaterialApp(home: NewPurchaseOrderScreen()),
    ));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Movement data may be incomplete — the sales cap was reached for this window.'),
        findsOneWidget);
  });
```

- [ ] **Step 2: Run to verify the new expectations fail**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart`
Expected: FAIL — keys not found, `Create 2 purchase orders` not found, `₱715.00` not found, `31` not found.

- [ ] **Step 3: Restyle the screen**

Edits to `new_purchase_order_screen.dart`. `_LineSource`, `_Line`, `_line`, `_buildLines`, `_save`, and (for now) `_showAddProductSheet` stay **unchanged**.

**3a — imports:** add:

```dart
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/po_widgets.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
```

and `import 'dart:async';` (for the debounce `Timer`).

**3b — view-mode enum** (top level, after `_Line`):

```dart
/// Grouping mode — presentation only; selection and quantities carry over.
enum _ViewMode { byStatus, bySupplier }
```

**3c — state fields:** replace `_coverController` + `_coverDays` getter + `_byStatus` with:

```dart
  int _windowDays = 60;

  /// Cover days as displayed (updates per tap, clamped 1–365)…
  int _cover = 30;

  /// …and as applied to the suggestions provider (follows [_cover] after a
  /// short debounce so stepping doesn't refetch per tap).
  int _appliedCover = 30;
  Timer? _coverDebounce;

  _ViewMode _view = _ViewMode.byStatus;
```

(keep `_manual`, `_qty`, `_checkedOverride`, `_saving`, `_searchController` as-is). Update `dispose`:

```dart
  @override
  void dispose() {
    _coverDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
```

Add the setter:

```dart
  void _setCover(int value) {
    final next = value.clamp(1, 365);
    if (next == _cover) return;
    setState(() => _cover = next);
    _coverDebounce?.cancel();
    _coverDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _appliedCover = _cover);
    });
  }
```

In `build`, the params record becomes:

```dart
    final params = (windowDays: _windowDays, coverDays: _appliedCover);
```

**3d — replace `_buildBody`:**

```dart
  Widget _buildBody(ReorderResult result) {
    final lines = _buildLines(result);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: _paramsCard(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _SegmentedCells<_ViewMode>(
            values: _ViewMode.values,
            labels: const {
              _ViewMode.byStatus: 'By status',
              _ViewMode.bySupplier: 'By supplier',
            },
            icons: const {
              _ViewMode.byStatus: LucideIcons.layers,
              _ViewMode.bySupplier: LucideIcons.truck,
            },
            selected: _view,
            keyPrefix: 'po-view',
            radius: 14,
            elevated: true,
            onChanged: (v) => setState(() => _view = v),
          ),
        ),
        if (result.capped)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: PoAmberNote(
              text: 'Movement data may be incomplete — the sales cap was '
                  'reached for this window.',
            ),
          ),
        Expanded(
          child: lines.isEmpty
              ? const EmptyStateView(
                  tiled: true,
                  icon: LucideIcons.packageCheck,
                  title: 'No suggestions — everything is stocked',
                  subtitle: 'Add products manually with the search button',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  children: _sections(lines),
                ),
        ),
        _footer(lines),
      ],
    );
  }
```

**3e — params card:**

```dart
  Widget _paramsCard() {
    final theme = Theme.of(context);
    return AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SegmentedCells<int>(
                  values: const [30, 60, 90],
                  labels: const {30: '30d', 60: '60d', 90: '90d'},
                  selected: _windowDays,
                  keyPrefix: 'po-window',
                  onChanged: (v) => setState(() => _windowDays = v),
                ),
              ),
              const SizedBox(width: 10),
              PoStepperButton(
                key: const Key('po-cover-minus'),
                icon: LucideIcons.minus,
                size: 30,
                radius: 9,
                onTap: _cover > 1 ? () => _setCover(_cover - 1) : null,
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 26),
                    alignment: Alignment.center,
                    child: Text(
                      '$_cover',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    'COVER',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .4,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              PoStepperButton(
                key: const Key('po-cover-plus'),
                icon: LucideIcons.plus,
                size: 30,
                radius: 9,
                onTap: _cover < 365 ? () => _setCover(_cover + 1) : null,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text.rich(
            TextSpan(
              text: 'Suggesting ',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: '$_cover days of stock',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const TextSpan(text: ' from the last '),
                TextSpan(
                  text: '$_windowDays days',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const TextSpan(text: ' of sales — applies as you change it.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
```

**3f — replace `_sections`:** status view keeps bucket order with iconed headers + counts; supplier view groups with checked-subtotal trailing (totals addition).

```dart
  /// Section headers + rows for the active view. Status view walks the
  /// bucket order (recommended → out → low → added); supplier view groups
  /// the same lines by supplier name, no-supplier last, with the checked
  /// count + subtotal (what that supplier's PO will cost) on the right.
  List<Widget> _sections(List<_Line> lines) {
    if (_view == _ViewMode.byStatus) {
      const icons = {
        _LineSource.recommended: LucideIcons.trendingUp,
        _LineSource.outOfStock: LucideIcons.packageX,
        _LineSource.lowStock: LucideIcons.packageMinus,
        _LineSource.added: LucideIcons.circlePlus,
      };
      return [
        for (final source in _LineSource.values) ...[
          if (lines.any((l) => l.source == source)) ...[
            PoSectionHeader(
              icon: icons[source]!,
              label: source.label,
              trailing:
                  '${lines.where((l) => l.source == source).length}',
            ),
            for (final line in lines)
              if (line.source == source) _row(line),
          ],
        ],
      ];
    }

    final groups = <String?, List<_Line>>{};
    for (final line in lines) {
      groups.putIfAbsent(line.product.supplierName, () => []).add(line);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == b) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });
    return [
      for (final key in keys) ...[
        Builder(builder: (context) {
          final checked = groups[key]!.where((l) => l.checked).toList();
          final subtotal = checked.fold<double>(
              0, (sum, l) => sum + l.qty * l.product.cost);
          return PoSectionHeader(
            icon: LucideIcons.truck,
            label: key ?? 'No supplier',
            trailing: '${checked.length} '
                '${checked.length == 1 ? 'item' : 'items'} · '
                '${subtotal.toCurrency()}',
          );
        }),
        for (final line in groups[key]!) _row(line),
      ],
    ];
  }
```

**3g — replace `_row`:** AppCard row with 22px checkbox, mono SKU, caption, dimmed-unchecked, stepper pill.

```dart
  Widget _row(_Line line) {
    final theme = Theme.of(context);
    final p = line.product;
    final caption = switch (line.source) {
      _LineSource.recommended =>
        'Stock ${p.quantity} · ${line.velocityPerDay!.toStringAsFixed(1)}/day',
      _LineSource.outOfStock ||
      _LineSource.lowStock =>
        'Stock ${p.quantity} · reorder at ${p.reorderLevel}',
      _LineSource.added => 'Stock ${p.quantity} · added manually',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        radius: AppRadius.field,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _PoCheckbox(
              key: Key('po-check-${p.id}'),
              checked: line.checked,
              onChanged: (v) =>
                  setState(() => _checkedOverride[p.id] = v),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Opacity(
                opacity: line.checked ? 1 : 0.62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      p.sku,
                      style: TextStyle(
                        fontFamily: AppTextStyles.monoFontFamily,
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      caption,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Opacity(
              opacity: line.checked ? 1 : 0.62,
              child: Row(
                children: [
                  PoStepperButton(
                    icon: LucideIcons.minus,
                    onTap: line.qty > 1
                        ? () => setState(() => _qty[p.id] = line.qty - 1)
                        : null,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    child: Text(
                      '${line.qty}',
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  PoStepperButton(
                    icon: LucideIcons.plus,
                    onTap: () => setState(() => _qty[p.id] = line.qty + 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
```

**3h — footer** (replaces the old bottom `SafeArea`/`FilledButton` block, which `_buildBody` no longer emits):

```dart
  /// Pinned footer: checked summary + running total (totals addition) over
  /// the live-count create button. The count mirrors the `_save` grouping —
  /// checked lines grouped by supplierId, no-supplier its own group.
  Widget _footer(List<_Line> lines) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final checked = lines.where((l) => l.checked).toList();
    final pcs = checked.fold<int>(0, (sum, l) => sum + l.qty);
    final total =
        checked.fold<double>(0, (sum, l) => sum + l.qty * l.product.cost);
    final groupCount =
        checked.map((l) => l.product.supplierId).toSet().length;
    final label = checked.isEmpty
        ? 'Create purchase orders'
        : 'Create $groupCount purchase order${groupCount == 1 ? '' : 's'}';

    return Container(
      decoration: poFooterDecoration(dark),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: '${checked.length} '
                            '${checked.length == 1 ? 'item' : 'items'} '
                            'checked · $pcs pcs',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        children: [
                          TextSpan(
                            text: ' · ${total.toCurrency()}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'One PO per supplier',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('po-create-button'),
                onPressed:
                    checked.isEmpty || _saving ? null : () => _save(lines),
                icon: const Icon(LucideIcons.clipboardPlus, size: 18),
                label: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
```

**3i — `_PoCheckbox` + `_SegmentedCells`** (bottom of the file, above or below the sheet code):

```dart
/// 22px rounded checkbox — checked = solid primary + on-primary check,
/// unchecked = 1.5px border.
class _PoCheckbox extends StatelessWidget {
  const _PoCheckbox({super.key, required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!checked),
      child: Container(
        width: 22,
        height: 22,
        decoration: checked
            ? BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(7),
              )
            : BoxDecoration(
                border: Border.all(
                    color: AppColors.checkboxBorder(dark), width: 1.5),
                borderRadius: BorderRadius.circular(7),
              ),
        child: checked
            ? Icon(LucideIcons.check,
                size: 14, color: theme.colorScheme.onPrimary)
            : null,
      ),
    );
  }
}

/// Bordered segmented control per the mock — equal cells, selected = faint
/// primary wash + 600 primary text. [elevated] fills with the card surface +
/// soft shadow (the view toggle); plain sits recessed on the params card.
class _SegmentedCells<T> extends StatelessWidget {
  const _SegmentedCells({
    super.key,
    required this.values,
    required this.labels,
    required this.selected,
    required this.onChanged,
    required this.keyPrefix,
    this.icons,
    this.radius = 12,
    this.elevated = false,
  });

  final List<T> values;
  final Map<T, String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  final String keyPrefix;
  final Map<T, IconData>? icons;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final border =
        dark ? AppColors.darkInputBorder : AppColors.lightInputBorder;
    return Container(
      decoration: BoxDecoration(
        color: elevated ? (dark ? AppColors.darkCard : Colors.white) : null,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated ? AppShadows.card(dark: dark) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: _cell(context, values[i], first: i == 0, border: border),
            ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, T v,
      {required bool first, required Color border}) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final isSel = v == selected;
    final name = v is Enum ? v.name : v.toString();
    final selectedTint =
        dark ? const Color(0x1FE8B84C) : const Color(0x1A283E46);
    final icon = icons?[v];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(v),
      child: Container(
        key: Key('$keyPrefix-$name'),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: icons == null ? 8 : 10),
        decoration: BoxDecoration(
          color: isSel ? selectedTint : Colors.transparent,
          border: first ? null : Border(left: BorderSide(color: border)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: isSel
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              labels[v]!,
              style: TextStyle(
                fontSize: icons == null ? 13 : 13.5,
                fontWeight: isSel ? FontWeight.w600 : FontWeight.w500,
                color: isSel
                    ? theme.colorScheme.primary
                    : (icons == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart`
Expected: ALL PASS (11 tests). Watch for pending-timer failures — any test that taps the cover stepper must pump ≥350ms afterward (the new test does).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart
git commit -m "feat(po): redesign New PO — params card w/ debounced cover stepper, segmented views, card rows, live-count footer with running total

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Add-products sheet on the Job Orders pattern (+ ProductSearchField options)

**Files:**
- Modify: `lib/presentation/mobile/widgets/pos/product_search_field.dart`
- Modify: `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart` (replace `_showAddProductSheet`, add `_AddProductsSheet`, drop `_searchController`)
- Test (modify): `test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart`

**Interfaces:**
- Consumes: `ProductSearchField` (existing: `controller`, `focusNode`, `inlineResults`, `hintText`, `onProductSelected`, `onBarcodeScanned`), `productByBarcodeProvider` (`lib/presentation/providers/product_provider.dart:109`), `localProductSearchProvider` (watches `productsProvider` — test overrides suffice), `showWarningSnackBar` (navigation_extensions).
- Produces on `ProductSearchField` (backwards-compatible — POS/JO callers unchanged):
  - `bool showPrice = true` — hides the ₱ price on result rows when false
  - `bool allowOutOfStock = false` — when true, zero-stock rows stay enabled (a PO exists to order them)
  - `Set<String> addedIds = const {}` — rows in the set render a tinted "Added" chip instead of the + button and don't re-add

- [ ] **Step 1: Update tests**

In `new_purchase_order_screen_test.dart`:

1. Rewrite `'manually added product keeps its qty when params change'` for the new sheet flow (search-driven, stays open, Done closes):

```dart
  testWidgets('manually added product keeps its qty when params change',
      (tester) async {
    await pump(tester, suggestions: [suggestion(product('p1'), 9)]);

    // Add p2 via the add-products sheet (search → result row → Done).
    await tester.tap(find.byTooltip('Add product'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Item p2');
    await tester.pump(const Duration(milliseconds: 350)); // search debounce
    await tester.pumpAndSettle();
    await tester.tap(find.text('Item p2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Bump its qty 1 → 3 (the p2 row is the last plus-button).
    await tester.tap(find.byIcon(LucideIcons.plus).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.plus).last);
    await tester.pumpAndSettle();

    // Change the movement window — previously this rebuilt lines and reset
    // the manual row.
    await tester.tap(find.byKey(const Key('po-window-30')));
    await tester.pumpAndSettle();

    expect(find.text('Item p2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget,
        reason: 'the manually set quantity must survive a params change');
  });
```

2. Append new sheet tests:

```dart
  testWidgets('sheet stays open, accumulates adds, and chips added rows',
      (tester) async {
    await pump(tester, suggestions: [suggestion(product('p1'), 9)]);

    await tester.tap(find.byTooltip('Add product'));
    await tester.pumpAndSettle();
    expect(find.text('Add products'), findsOneWidget);
    expect(find.text('0 added this session'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Item');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Both overridden products are results; p2 is zero-stock (quantity: 0)
    // and must still be addable on a purchase order.
    await tester.tap(find.text('Item p2'));
    await tester.pumpAndSettle();
    expect(find.text('1 added this session'), findsOneWidget,
        reason: 'sheet stays open after a pick');
    expect(find.text('Added'), findsOneWidget,
        reason: 'the picked row now shows the Added chip');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Item p2'), findsWidgets,
        reason: 'p2 landed in the builder lines');
  });

  testWidgets('sheet result rows hide the sale price', (tester) async {
    await pump(tester, suggestions: [suggestion(product('p1'), 9)]);
    await tester.tap(find.byTooltip('Add product'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Item p2');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.textContaining('₱80'), findsNothing,
        reason: 'the PO sheet is cost/price-free like the CSV');
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart`
Expected: the three sheet tests FAIL (old sheet has no 'Add products' title / 'Done' / 'Added' chip; result rows come from a plain ListTile list). Others still pass.

- [ ] **Step 3a: Extend `ProductSearchField`**

In `product_search_field.dart`:

1. Add fields + constructor params:

```dart
  final bool inlineResults;
  final String hintText;

  /// Show the sale price on result rows (POS/JO default). The PO add sheet
  /// hides it — that surface is deliberately price-free.
  final bool showPrice;

  /// Keep zero-stock rows tappable (purchase orders exist to restock them).
  final bool allowOutOfStock;

  /// Rows whose product id is in this set render a tinted "Added" chip
  /// instead of the + button and cannot be re-added.
  final Set<String> addedIds;

  const ProductSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onProductSelected,
    required this.onBarcodeScanned,
    this.inlineResults = false,
    this.hintText = 'Search products or scan barcode...',
    this.showPrice = true,
    this.allowOutOfStock = false,
    this.addedIds = const {},
  });
```

2. In `_buildResultRow`, replace the first line and the trailing price/+ section:

```dart
  Widget _buildResultRow(ProductEntity product) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline = isDark ? AppColors.darkHairline : AppColors.lightHairline;
    final disabled = !widget.allowOutOfStock && product.isOutOfStock;
    final added = widget.addedIds.contains(product.id);

    void select() {
      widget.onProductSelected(product);
      if (!widget.inlineResults) _removeOverlay();
    }

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: InkWell(
        onTap: disabled || added ? null : select,
```

and further down, replace the fixed price + add-button block (from the `Text` with `AppConstants.currencySymbol` through the closing of the `if (!disabled)` spread) with:

```dart
              if (widget.showPrice) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${AppConstants.currencySymbol}'
                  '${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ],
              if (added)
                Container(
                  margin: const EdgeInsets.only(left: AppSpacing.sm + 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.emphasisTint(isDark),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    'Added',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              else if (!disabled) ...[
                const SizedBox(width: AppSpacing.sm + 2),
                InkWell(
                  onTap: select,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      LucideIcons.plus,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
```

(Everything else in the row — thumb, name, mono `SKU · N in stock` — is unchanged.)

- [ ] **Step 3b: Replace the PO add sheet**

In `new_purchase_order_screen.dart`:

1. Delete the `_searchController` field and its `dispose` line (the sheet now owns its controller; a real `StatefulWidget`'s `dispose` runs after the exit animation, so the old dispose-race workaround is obsolete).

2. Replace `_showAddProductSheet` entirely:

```dart
  void _showAddProductSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => _AddProductsSheet(
        initiallyAdded: _manual.map((p) => p.id).toSet(),
        onProduct: (p) {
          if (_manual.any((m) => m.id == p.id)) return;
          setState(() {
            _manual.add(p);
            // A deliberate add is always checked, even when the product also
            // sits in a low/out bucket.
            _checkedOverride[p.id] = true;
          });
        },
      ),
    );
  }
```

3. Add the sheet widget at the bottom of the file. New imports needed at the top: `import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/product_search_field.dart';` (and `providers.dart` already exposes `productByBarcodeProvider` via `product_provider.dart`, which is already imported).

```dart
/// Add-products sheet — Job Orders add-parts pattern: grab handle · title +
/// session count · ProductSearchField (inline results, barcode scan, no
/// prices, out-of-stock addable) · pinned Done. Stays open so several
/// products accumulate; added rows chip as "Added".
class _AddProductsSheet extends ConsumerStatefulWidget {
  const _AddProductsSheet({
    required this.initiallyAdded,
    required this.onProduct,
  });

  /// Ids already added manually — their rows render the "Added" chip.
  final Set<String> initiallyAdded;
  final void Function(ProductEntity) onProduct;

  @override
  ConsumerState<_AddProductsSheet> createState() => _AddProductsSheetState();
}

class _AddProductsSheetState extends ConsumerState<_AddProductsSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final Set<String> _added = {...widget.initiallyAdded};
  int _session = 0;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add(ProductEntity p) {
    if (_added.contains(p.id)) return;
    widget.onProduct(p);
    setState(() {
      _added.add(p.id);
      _session++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // Fixed-height sheet with an in-flow scrollable results panel, clamped so
    // sheet + keyboard never exceed the screen (JO add-parts pattern).
    final sheetHeight = (screenHeight * 0.62)
        .clamp(0.0, screenHeight - bottomInset - 120)
        .toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Add products',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '$_session added this session',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ProductSearchField(
                  controller: _controller,
                  focusNode: _focusNode,
                  inlineResults: true,
                  showPrice: false,
                  allowOutOfStock: true,
                  addedIds: _added,
                  hintText: 'Search name, SKU, or scan barcode',
                  onProductSelected: _add,
                  onBarcodeScanned: (barcode) async {
                    final p = await ref
                        .read(productByBarcodeProvider(barcode).future);
                    if (!context.mounted) return;
                    if (p != null) {
                      _add(p);
                    } else {
                      context.showWarningSnackBar('Product not found: $barcode');
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

(If `showWarningSnackBar` is unresolved, `navigation_extensions.dart` is already imported at the top of this file.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart test/presentation/mobile/widgets/pos/`
Expected: ALL PASS — including any pre-existing `ProductSearchField`/POS widget tests (the new params default to old behavior).

- [ ] **Step 5: Run the POS/JO consumer tests (regression on the shared widget)**

Run: `flutter test test/presentation/mobile/screens/pos/ test/presentation/mobile/screens/drafts/`
Expected: ALL PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/widgets/pos/product_search_field.dart lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart
git commit -m "feat(po): add-products sheet on the JO pattern — stays open, Added chips, barcode, price-free, out-of-stock addable

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Nav-menu icon, CSV cost-exclusion lock, full verification

**Files:**
- Modify: `lib/config/router/route_guards.dart:255` (the Reorder `MenuItem`)
- Test (modify): `test/config/router/route_guards_purchase_orders_test.dart`
- Test (modify): `test/core/utils/purchase_order_csv_test.dart`

**Interfaces:**
- Consumes: `RouteGuards.getMenuItems`, `MenuItem.icon` (`IconData` — Lucide constants are valid), `buildPurchaseOrderCsv`.
- Produces: nothing new.

- [ ] **Step 1: Write the failing tests**

In `route_guards_purchase_orders_test.dart`, add inside `main` (import `package:lucide_icons_flutter/lucide_icons.dart` at the top):

```dart
  test('Reorder menu item uses the Lucide clipboard-list glyph', () {
    final item = RouteGuards.getMenuItems(UserRole.staff)
        .firstWhere((m) => m.path == RoutePaths.purchaseOrders);
    expect(item.icon, LucideIcons.clipboardList);
  });
```

In `purchase_order_csv_test.dart`, add inside `main`:

```dart
  test('CSV never carries currency or cost columns (totals stay UI-only)', () {
    final csv = buildPurchaseOrderCsv(po);
    expect(csv, isNot(contains('₱')));
    expect(csv.toLowerCase(), isNot(contains('cost')));
    expect(csv.toLowerCase(), isNot(contains('total')));
    expect(csv, contains('SKU,Name,Qty,Unit'));
  });
```

- [ ] **Step 2: Run to verify the icon test fails (CSV test passes already — it's a regression lock)**

Run: `flutter test test/config/router/route_guards_purchase_orders_test.dart test/core/utils/purchase_order_csv_test.dart`
Expected: the icon test FAILS (`Icons.shopping_cart_checkout`); both CSV tests PASS.

- [ ] **Step 3: Swap the icon**

In `route_guards.dart`, add `import 'package:lucide_icons_flutter/lucide_icons.dart';` (if absent) and change line ~255:

```dart
      items.add(const MenuItem(
        title: 'Reorder',
        icon: LucideIcons.clipboardList,
        path: '/reorder',
      ));
```

(Only the nav menu reads this metadata — verified: `Icons.shopping_cart_checkout` has exactly one usage in `lib/`.)

- [ ] **Step 4: Run the targeted tests**

Run: `flutter test test/config/router/ test/core/utils/purchase_order_csv_test.dart`
Expected: ALL PASS.

- [ ] **Step 5: Full gate — analyze + entire suite**

Run: `flutter analyze`
Expected: `No issues found!` (fix any unused-import/lint fallout from Tasks 2–5 before proceeding).

Run: `flutter test`
Expected: ALL PASS (~1080+ tests).

- [ ] **Step 6: Commit**

```bash
git add lib/config/router/route_guards.dart test/config/router/route_guards_purchase_orders_test.dart test/core/utils/purchase_order_csv_test.dart
git commit -m "feat(po): Lucide clipboard-list nav icon + CSV cost-exclusion regression lock

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## After the plan

1. `/code-review` the branch diff.
2. `/verify` — run the app and walk both themes through: list (filters, empty, error-retry), new PO (window/cover/view controls, add sheet incl. barcode path, create N), detail in all four statuses (steppers, staged edits, footer totals, share CSV, receive), cancel/delete dialogs. Confirm CSV output has no costs.
3. `superpowers:finishing-a-development-branch` — merge to main per repo convention (no push unless asked).
