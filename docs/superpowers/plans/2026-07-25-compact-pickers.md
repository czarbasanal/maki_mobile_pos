# Compact Pickers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mechanic and motorcycle-model dropdowns render dense (~40px, 13px text) everywhere via one `AppDropdown.compact` flag.

**Architecture:** `AppDropdown` gains `compact: bool = false` (isDense + tighter padding merged into the decoration, 13px `DefaultTextStyle.merge` around the closed value and every menu item, 14px chevron); the two pickers opt in and shrink their prefix icons. All four hosting surfaces inherit; every other dropdown is untouched.

**Tech Stack:** Flutter.

**Spec:** `docs/superpowers/specs/2026-07-25-compact-pickers-design.md`

## Global Constraints

- Branch: create `feat/compact-pickers` off current `main`.
- Non-compact `AppDropdown` behavior byte-identical (default false; one default-size pinning assertion required).
- Caller-set decoration values win over compact defaults (`contentPadding`/`isDense` only injected when the caller left them unset); caller-set item text styles win (merge semantics).
- Only `app_dropdown.dart`, the two picker files, and tests change.

---

### Task 1: `AppDropdown.compact` + picker opt-in

**Files:**
- Modify: `lib/presentation/shared/widgets/common/app_dropdown.dart`
- Modify: `lib/presentation/mobile/widgets/pos/mechanic_picker.dart` (add `compact: true` to its `AppDropdown`, and `size: 18` on the wrench prefix `Icon`)
- Modify: `lib/presentation/mobile/widgets/pos/motorcycle_model_picker.dart` (same: `compact: true`, bike prefix `Icon` `size: 18`)
- Test: create `test/presentation/shared/widgets/common/app_dropdown_compact_test.dart`; extend `test/presentation/widgets/mechanic_picker_test.dart` + `test/presentation/widgets/motorcycle_model_picker_test.dart` (READ each harness)

**Interfaces:**
- Produces: `AppDropdown({..., bool compact = false})`.

- [ ] **Step 1: Write the failing tests**

New `app_dropdown_compact_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dropdown.dart';

Widget _host({bool compact = false}) => MaterialApp(
      home: Scaffold(
        body: AppDropdown<int>(
          compact: compact,
          initialValue: 1,
          decoration: const InputDecoration(labelText: 'Pick'),
          items: const [
            DropdownMenuItem(value: 1, child: Text('One')),
            DropdownMenuItem(value: 2, child: Text('Two')),
          ],
          onChanged: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('compact renders 13px value text and a dense decoration',
      (tester) async {
    await tester.pumpWidget(_host(compact: true));
    // Closed-button value text inherits the compact DefaultTextStyle.
    final valueStyle =
        DefaultTextStyle.of(tester.element(find.text('One'))).style;
    expect(valueStyle.fontSize, 13);
    final decorator =
        tester.widget<InputDecorator>(find.byType(InputDecorator));
    expect(decorator.decoration.isDense, isTrue);
  });

  testWidgets('compact menu items render 13px', (tester) async {
    await tester.pumpWidget(_host(compact: true));
    await tester.tap(find.byType(AppDropdown<int>));
    await tester.pumpAndSettle();
    final itemStyle =
        DefaultTextStyle.of(tester.element(find.text('Two').last)).style;
    expect(itemStyle.fontSize, 13);
  });

  testWidgets('non-compact stays default (no dense injection)',
      (tester) async {
    await tester.pumpWidget(_host());
    final decorator =
        tester.widget<InputDecorator>(find.byType(InputDecorator));
    expect(decorator.decoration.isDense, isNot(isTrue));
    final valueStyle =
        DefaultTextStyle.of(tester.element(find.text('One'))).style;
    expect(valueStyle.fontSize, isNot(13));
  });
}
```

(If `find.text('Two').last` needs adjusting for the closed-button copy of the unselected item — it does not render — verify with the failing run and fix finders, keeping the assertions.)

Picker tests: in each picker test file, add one test asserting the rendered selected/label text is 13px after selection (reuse the harness; find the selected mechanic/model name Text and assert its effective `DefaultTextStyle` fontSize == 13).

- [ ] **Step 2: Run to verify failures**

`flutter test test/presentation/shared/widgets/common/app_dropdown_compact_test.dart test/presentation/widgets/mechanic_picker_test.dart test/presentation/widgets/motorcycle_model_picker_test.dart`
Expected: compact tests FAIL (`compact` param missing → compile error).

- [ ] **Step 3: Implement**

(a) `app_dropdown.dart`:
- Constructor + field:

```dart
  /// Dense variant for space-tight hosts (mechanic / motorcycle-model
  /// pickers): isDense + tighter padding (~40px closed height) and 13px
  /// text for the closed value and menu items. Caller-set decoration
  /// values and explicit item text styles always win.
  final bool compact;
```

(`this.compact = false` in the constructor; pass through to `_AppDropdownButton` as a new required field.)
- In `_AppDropdownButtonState.build`, adjust the decoration merge:

```dart
    var decoration = widget.decoration.copyWith(
      errorText: widget.state.errorText,
    );
    if (widget.compact) {
      decoration = decoration.copyWith(
        isDense: widget.decoration.isDense ?? true,
        contentPadding: widget.decoration.contentPadding ??
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      );
    }
```

- Wrap the closed value: `Expanded(child: _compactText(selected ?? const SizedBox.shrink()))` where

```dart
  Widget _compactText(Widget child) => widget.compact
      ? DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 13), child: child)
      : child;
```

- Wrap each menu item's `SizedBox(width: …, child: item.child)` child in the same `_compactText(...)`.
- Chevron: `size: widget.compact ? 14 : 16`.

(b) Each picker: add `compact: true,` to the `AppDropdown` call and `size: 18` to the prefix `Icon` in its `InputDecoration`.

- [ ] **Step 4: Verify**

Re-run the three test files → PASS (all pre-existing picker tests must stay green). `flutter analyze` → clean.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/shared/widgets/common/app_dropdown.dart lib/presentation/mobile/widgets/pos/ test/
git commit -m "feat(mobile): compact mechanic and motorcycle-model dropdowns (AppDropdown.compact)"
```

---

### Task 2: Full verification

- [ ] `flutter test` → ALL pass (~1378+). `flutter analyze` → clean. `git status --short` clean apart from the two pre-existing untracked scripts.

After Task 2: review, then finish per `superpowers:finishing-a-development-branch`. Ships with the next APK (+16 bundle).
