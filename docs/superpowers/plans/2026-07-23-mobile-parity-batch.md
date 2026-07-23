# Mobile Parity Batch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the 7-item mobile parity batch: shared labor row/dialog (Job Order style wins), auto JO numbers in the drafts-list create flow, ranked/bar Top Selling on the dashboard, EOD Add Expense in the section header, persisted itemized Plate No amounts, draft-edit single-scroll + sticky Bill-out footer + keyboard-dismiss unfocus, and an unpinned dashboard header.

**Architecture:** Presentation-layer refactors extract two shared widgets (labor row+dialog, rank row) consumed by both existing surfaces; the only data change is additive `List<double>` plate-amount fields on `DailyClosingEntity`/`DailyClosingModel` flowing through `CloseDayUseCase` → `DailyClosingOperationsNotifier` (scalars remain the single source for cash math, always equal to the list sums). Everything is Flutter-mobile-only; no shared Firestore write shapes change beyond the additive closing fields.

**Tech Stack:** Flutter + Riverpod + mocktail/fake_cloud_firestore

**Spec:** docs/superpowers/specs/2026-07-23-mobile-parity-batch-design.md
**Scout report (exact anchors):** .superpowers/sdd/scout-mobile-batch2.md

## Global Constraints

- **Branch:** all work on `feat/mobile-parity-batch` (already created and checked out). Do not commit to main; do not push unless asked.
- **JO number reuse:** the drafts-list flow reuses `nextJobOrderNumber(now, names)` / `jobOrderPrefixFor(now)` from `lib/core/utils/job_order_number.dart` — no new numbering scheme. Today's drafts are fetched with `getDraftsByDateRange(startDate: now, endDate: now, includeConverted: true)` under `context.runWithWaiting`, mirroring `pos_screen._showSaveDraftDialog` verbatim, including the error path (snackbar `'Could not prepare a job order number'` + abort).
- **Shared labor widgets:** exactly ONE labor row widget and ONE add/edit labor dialog shared by POS and draft-edit. The Job Order style wins: whole-card `AppCard(onTap: edit)`, wrench icon, description, fee, trailing ✕ `IconButton` remove; dialog title flips Add/Edit; validators: description required, fee > 0. `LaborLineTile` and both private dialogs (`LaborLineTile._showEditDialog`, `_LaborLineDialog` in draft_edit_screen) are retired. Callback-shape reconciliation happens at call sites; the shared row exposes `onEdited(description, fee)` + `onRemove`.
- **Shared rank row:** exactly ONE rank-row widget (extracted from `TopProductsCard._RankRow`) used by both `TopProductsCard` (no visual change on reports screens) and `TopSellingTodayWidget`.
- **Plate amounts persisted itemized:** `DailyClosingEntity` + `DailyClosingModel` gain `plateNoDpAmounts` and `plateNoDeliveryAmounts` (`List<double>`, default `const []`), round-tripped to Firestore arrays. The scalar `plateNoDp`/`plateNoDelivery` REMAIN and always equal the sum of their list (single source for `expectedCashFor` math). Old docs have scalars only and read back with empty lists (back-compat in `fromMap`).
- **Dashboard Top Selling:** keeps its EXISTING live `topSellingTodayProvider` data (no provider/data change, no permission gate), keeps the 5/10 See-more collapse and the section header + "View All" link. NO profit pill on the dashboard.
- **Draft-edit sticky footer:** summary + Bill-out block becomes the sticky bottom footer with `AppShadows.pinnedFooter`; AppBar stays; ONE `SingleChildScrollView` holds header + parts + labor; the parts list becomes shrinkWrap non-scrolling.
- **Out of scope:** web_admin untouched; firestore.rules untouched; no reports/CSV changes; no labor/cart/draft data-model changes (the labor item is presentation-only).
- **Verification commands** (run from the repo root `/Users/czar/Desktop/MAKI_Mobile_POS/maki_mobile_pos`): `flutter test` and `flutter analyze`. Final validation = full suite green + analyze clean; user device-smokes the batch on the A71 with the next APK.
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Shared labor row widget + shared labor dialog

Create `LaborLineRow` + `showLaborLineDialog` (the Job Order visual, ported from draft-edit's `_buildLaborLineRow`/`_LaborLineDialog`). Nothing is retired yet — POS and draft-edit still use their old code until Task 2.

**Files:**
- Create: `lib/presentation/mobile/widgets/pos/labor_line_row.dart`
- Test: `test/presentation/widgets/labor_line_row_test.dart`

**Interfaces:**
- Consumes: `LaborLineEntity` (`lib/domain/entities/labor_line_entity.dart` — `const LaborLineEntity({required String id, required String description, double fee = 0})`, has `copyWith`), `AppCard`/`AppDialog`/`appDialogCancel`/`appDialogPrimary` from `common_widgets.dart`, `AppSpacing`/`AppRadius`/`AppTextStyles` from theme, `num_extensions.toCurrency()`.
- Produces (Task 2 relies on these exact signatures):
  - `class LaborLineInput { const LaborLineInput({required this.description, required this.fee}); final String description; final double fee; }`
  - `Future<LaborLineInput?> showLaborLineDialog(BuildContext context, {LaborLineEntity? line})` — title `'Add Labor'` when `line == null`, `'Edit Labor'` otherwise; primary button `'Add'`/`'Save'`; field keys `Key('labor-desc-field')` / `Key('labor-fee-field')`.
  - `class LaborLineRow extends StatelessWidget` with `const LaborLineRow({super.key, required LaborLineEntity line, required void Function(String description, double fee) onEdited, required VoidCallback onRemove})`. Card tap opens the shared dialog prefilled and reports the result via `onEdited`; trailing ✕ calls `onRemove`.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/widgets/labor_line_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_row.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

void main() {
  const line = LaborLineEntity(
    id: 'l1',
    description: 'Engine tune-up',
    fee: 450.0,
  );

  Widget host({
    void Function(String, double)? onEdited,
    VoidCallback? onRemove,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: LaborLineRow(
            line: line,
            onEdited: onEdited ?? (_, __) {},
            onRemove: onRemove ?? () {},
          ),
        ),
      ),
    );
  }

  group('LaborLineRow', () {
    testWidgets('renders description and fee; Job Order style (no swipe, no pencil)',
        (tester) async {
      await tester.pumpWidget(host());

      expect(find.text('Engine tune-up'), findsOneWidget);
      expect(find.text('₱450.00'), findsOneWidget);
      // Job Order style: whole card is the tap target, trailing ✕ removes.
      expect(find.byType(Dismissible), findsNothing);
      expect(find.byIcon(LucideIcons.pencil), findsNothing);
      expect(find.byIcon(LucideIcons.x), findsOneWidget);
    });

    testWidgets('tapping the card opens the edit dialog and reports edits',
        (tester) async {
      String? newDesc;
      double? newFee;
      await tester.pumpWidget(host(onEdited: (d, f) {
        newDesc = d;
        newFee = f;
      }));

      await tester.tap(find.byType(AppCard));
      await tester.pumpAndSettle();

      expect(find.text('Edit Labor'), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('labor-desc-field')), 'Brake bleed');
      await tester.enterText(find.byKey(const Key('labor-fee-field')), '300');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(newDesc, 'Brake bleed');
      expect(newFee, 300.0);
    });

    testWidgets('the trailing x calls onRemove without opening the dialog',
        (tester) async {
      var removed = false;
      await tester.pumpWidget(host(onRemove: () => removed = true));

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      expect(removed, true);
      expect(find.text('Edit Labor'), findsNothing);
    });
  });

  group('showLaborLineDialog', () {
    Widget dialogHost(void Function(LaborLineInput?) onResult) {
      return ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async =>
                      onResult(await showLaborLineDialog(ctx)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('add mode titles Add Labor and validates both fields',
        (tester) async {
      LaborLineInput? result;
      await tester.pumpWidget(dialogHost((r) => result = r));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Add Labor'), findsOneWidget);

      // Empty description + empty fee → blocked, dialog stays open.
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Fee must be greater than 0'), findsOneWidget);
      expect(result, isNull);

      await tester.enterText(
          find.byKey(const Key('labor-desc-field')), 'Tune-up');
      await tester.enterText(find.byKey(const Key('labor-fee-field')), '450');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.description, 'Tune-up');
      expect(result!.fee, 450.0);
    });

    testWidgets('zero fee is rejected', (tester) async {
      LaborLineInput? result;
      await tester.pumpWidget(dialogHost((r) => result = r));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('labor-desc-field')), 'Tune-up');
      await tester.enterText(find.byKey(const Key('labor-fee-field')), '0');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Fee must be greater than 0'), findsOneWidget);
      expect(result, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/widgets/labor_line_row_test.dart`
Expected: FAIL — compile error, `Target of URI doesn't exist: 'package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_row.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/presentation/mobile/widgets/pos/labor_line_row.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Result of the shared add/edit labor dialog — plain values so each call
/// site reconciles into its own mutation shape (CartNotifier id-based
/// updates vs DraftEntity whole-line updates).
class LaborLineInput {
  const LaborLineInput({required this.description, required this.fee});
  final String description;
  final double fee;
}

/// The ONE add/edit dialog for labor lines (POS register + Job Order
/// editor). Title flips Add/Edit on [line]; validators: description
/// required, fee > 0. Returns the entered values, or null if cancelled.
Future<LaborLineInput?> showLaborLineDialog(
  BuildContext context, {
  LaborLineEntity? line,
}) {
  return showDialog<LaborLineInput>(
    context: context,
    barrierColor:
        AppDialog.scrimColor(Theme.of(context).brightness == Brightness.dark),
    builder: (_) => _LaborLineDialog(line: line),
  );
}

class _LaborLineDialog extends StatefulWidget {
  const _LaborLineDialog({this.line});
  final LaborLineEntity? line;

  @override
  State<_LaborLineDialog> createState() => _LaborLineDialogState();
}

class _LaborLineDialogState extends State<_LaborLineDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descCtrl;
  late final TextEditingController _feeCtrl;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.line?.description ?? '');
    _feeCtrl = TextEditingController(
      text: (widget.line?.fee ?? 0) > 0
          ? widget.line!.fee.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      LaborLineInput(
        description: _descCtrl.text.trim(),
        fee: double.parse(_feeCtrl.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: widget.line == null ? 'Add Labor' : 'Edit Labor',
      leadingIcon: LucideIcons.wrench,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              style: AppTextStyles.fieldInput,
              key: const Key('labor-desc-field'),
              controller: _descCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Engine tune-up',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              style: AppTextStyles.fieldInput,
              key: const Key('labor-fee-field'),
              controller: _feeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Fee',
                prefixText: '${AppConstants.currencySymbol} ',
              ),
              validator: (v) {
                final parsed = double.tryParse(v?.trim() ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Fee must be greater than 0';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        appDialogCancel(context, 'Cancel',
            onTap: () => Navigator.pop(context)),
        appDialogPrimary(context, widget.line == null ? 'Add' : 'Save',
            onTap: _submit),
      ],
    );
  }
}

/// The ONE labor row (POS register + Job Order editor) — the Job Order
/// style: whole-card tap opens the shared edit dialog, trailing ✕ removes.
/// No swipe-to-dismiss, no pencil.
class LaborLineRow extends StatelessWidget {
  const LaborLineRow({
    super.key,
    required this.line,
    required this.onEdited,
    required this.onRemove,
  });

  final LaborLineEntity line;
  final void Function(String description, double fee) onEdited;
  final VoidCallback onRemove;

  Future<void> _edit(BuildContext context) async {
    final result = await showLaborLineDialog(context, line: line);
    if (result == null) return;
    onEdited(result.description, result.fee);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: AppCard(
        radius: AppRadius.md,
        onTap: () => _edit(context),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm + 4, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
        child: Row(
          children: [
            Icon(LucideIcons.wrench, size: 14, color: muted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                line.description.isEmpty ? 'Service' : line.description,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              line.fee.toCurrency(),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
            IconButton(
              icon: const Icon(LucideIcons.x, size: 16),
              visualDensity: VisualDensity.compact,
              color: muted,
              onPressed: onRemove,
              tooltip: 'Remove labor line',
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/widgets/labor_line_row_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/pos/labor_line_row.dart test/presentation/widgets/labor_line_row_test.dart
git commit -m "$(cat <<'EOF'
feat(mobile): shared LaborLineRow + labor dialog (Job Order style)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: POS + draft-edit adopt the shared row/dialog; retire LaborLineTile

**Files:**
- Modify: `lib/presentation/mobile/screens/pos/pos_screen.dart` (labor list ~line 375-394, `_showAddLaborDialog` ~line 439-506, imports)
- Modify: `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart` (`_addOrEditLabor` ~line 91-104, `_buildLaborSection` list ~line 426-434, `_buildLaborLineRow` ~line 440-479, `_LaborLineDialog` ~line 642-736, imports)
- Delete: `lib/presentation/mobile/widgets/pos/labor_line_tile.dart`
- Delete: `test/presentation/widgets/labor_line_tile_test.dart`
- Test: `test/presentation/widgets/pos_labor_section_test.dart`, `test/presentation/widgets/draft_edit_screen_labor_test.dart`

**Interfaces:**
- Consumes: `LaborLineRow`, `showLaborLineDialog`, `LaborLineInput` from Task 1; `CartNotifier.addLaborLine({required String description, required double fee})`, `.updateLaborLine(String id, {String? description, double? fee})`, `.removeLaborLine(String id)`; `DraftEntity.addLaborLine(LaborLineEntity)`, `.updateLaborLine(LaborLineEntity)`, `.removeLaborLine(String lineId)`; `LaborLineEntity.copyWith({String? id, String? description, double? fee})`.
- Produces: no new interfaces — `LaborLineTile` no longer exists anywhere.

- [ ] **Step 1: Write the failing tests (adopt assertions)**

In `test/presentation/widgets/pos_labor_section_test.dart`, add the import and extend the second test (`'shows the labor validation banner when a mechanic is missing'`). Add import at the top:

```dart
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_row.dart';
```

and add these two lines right after `expect(find.textContaining('Assign a mechanic'), findsOneWidget);`:

```dart
    // Labor lines render with the shared Job Order-style row.
    expect(find.byType(LaborLineRow), findsOneWidget);
    expect(find.byType(Dismissible), findsNothing);
```

In `test/presentation/widgets/draft_edit_screen_labor_test.dart`, add the same import:

```dart
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_row.dart';
```

and in the test `'shows labor subtotal and grand total includes labor'`, add after `expect(find.text('Engine tune-up'), findsOneWidget);`:

```dart
    expect(find.byType(LaborLineRow), findsOneWidget);
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/presentation/widgets/pos_labor_section_test.dart test/presentation/widgets/draft_edit_screen_labor_test.dart`
Expected: FAIL — `find.byType(LaborLineRow)` finds nothing (both screens still use the old widgets).

- [ ] **Step 3: Adopt in pos_screen.dart**

a) Replace the import `package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_tile.dart` with:

```dart
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_row.dart';
```

b) In `_buildLaborSection`, replace the `LaborLineTile` mapping inside the `ConstrainedBox`/`ListView` with:

```dart
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView(
              shrinkWrap: true,
              children: cart.laborLines
                  .map(
                    (line) => LaborLineRow(
                      line: line,
                      onEdited: (description, fee) => ref
                          .read(cartProvider.notifier)
                          .updateLaborLine(line.id,
                              description: description, fee: fee),
                      onRemove: () => ref
                          .read(cartProvider.notifier)
                          .removeLaborLine(line.id),
                    ),
                  )
                  .toList(),
            ),
          ),
```

c) Replace the entire `_showAddLaborDialog` method (currently ~68 lines building its own `AppDialog`) with:

```dart
  Future<void> _showAddLaborDialog() async {
    final result = await showLaborLineDialog(context);
    if (result == null || !mounted) return;
    ref.read(cartProvider.notifier).addLaborLine(
          description: result.description,
          fee: result.fee,
        );
  }
```

Note: the POS add dialog's title changes from `'Add Labor / Service'` to the shared `'Add Labor'` — deliberate (one dialog, Job Order copy wins).

d) Remove imports that become unused (run `flutter analyze` — `app_constants.dart` and `flutter/services.dart` are likely still used elsewhere in this file via `HapticFeedback`; only remove what the analyzer flags).

- [ ] **Step 4: Adopt in draft_edit_screen.dart**

a) Add the import:

```dart
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/labor_line_row.dart';
```

b) Replace `_addOrEditLabor` (lines ~91-104) with an add-only helper (edits now flow through `LaborLineRow`'s own dialog):

```dart
  Future<void> _addLabor(DraftEntity draft) async {
    final result = await showLaborLineDialog(context);
    if (result == null) return;
    await _persist(draft.addLaborLine(LaborLineEntity(
      id: const Uuid().v4(),
      description: result.description,
      fee: result.fee,
    )));
  }
```

c) In `_buildLaborSection`, point the header button at it:

```dart
              TextButton.icon(
                onPressed: () => _addLabor(draft),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add Labor'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
```

and replace the labor list mapping with the shared row:

```dart
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView(
              shrinkWrap: true,
              children: draft.laborLines
                  .map(
                    (line) => LaborLineRow(
                      line: line,
                      onEdited: (description, fee) => _persist(
                        draft.updateLaborLine(
                          line.copyWith(description: description, fee: fee),
                        ),
                      ),
                      onRemove: () => _removeLabor(draft, line.id),
                    ),
                  )
                  .toList(),
            ),
          ),
```

d) Delete the entire `_buildLaborLineRow` method and the entire `_LaborLineDialog` + `_LaborLineDialogState` classes at the bottom of the file. Remove imports the analyzer flags as unused (likely `app_constants.dart`; keep `uuid` — still used by `_saleItemFromProduct` and `_addLabor`).

e) Delete the retired widget and its test:

```bash
git rm lib/presentation/mobile/widgets/pos/labor_line_tile.dart test/presentation/widgets/labor_line_tile_test.dart
```

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test test/presentation/widgets/pos_labor_section_test.dart test/presentation/widgets/draft_edit_screen_labor_test.dart test/presentation/widgets/labor_line_row_test.dart && flutter analyze`
Expected: PASS, analyze clean (fix any unused-import infos it reports in the two screens).

Also confirm nothing else references the deleted widget: `grep -rn "LaborLineTile" lib test` → no matches.

- [ ] **Step 6: Commit**

```bash
git add -A lib/presentation/mobile test/presentation/widgets
git commit -m "$(cat <<'EOF'
refactor(mobile): POS + draft-edit adopt shared labor row/dialog; retire LaborLineTile

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Auto JO number in the drafts-list "New Job Order" flow

**Files:**
- Modify: `lib/presentation/mobile/widgets/drafts/new_job_order_dialog.dart` (drop the free-text field, add the read-only number row)
- Modify: `lib/presentation/mobile/screens/drafts/drafts_list_screen.dart` (`_createJobOrder`, ~line 48-75)
- Test: rewrite `test/presentation/widgets/new_job_order_dialog_test.dart`; update `test/presentation/widgets/drafts_list_load_test.dart`

**Interfaces:**
- Consumes: `nextJobOrderNumber(DateTime now, Iterable<String> existingNames)` + `jobOrderPrefixFor(DateTime now)` from `lib/core/utils/job_order_number.dart`; `DraftRepository.getDraftsByDateRange({required DateTime startDate, required DateTime endDate, bool includeConverted = false})` via `draftRepositoryProvider`; `context.runWithWaiting(action, {required String message})`; `context.showErrorSnackBar(String)`.
- Produces: `Future<NewJobOrderInput?> showNewJobOrderDialog(BuildContext context, {required String jobOrderNo})` — `NewJobOrderInput` shape unchanged (`label`, `model`, `mechanicId`, `mechanicName`), Save returns `label = jobOrderNo`.

- [ ] **Step 1: Rewrite the dialog test (failing first)**

Replace the full contents of `test/presentation/widgets/new_job_order_dialog_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/new_job_order_dialog.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/motorcycle_model_provider.dart';

void main() {
  Future<NewJobOrderInput? Function()> harness(WidgetTester tester) async {
    NewJobOrderInput? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeMotorcycleModelsProvider
              .overrideWith((ref) => Stream.value(const [])),
          activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => result = await showNewJobOrderDialog(
                    ctx,
                    jobOrderNo: 'JO-072326-005',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return () => result;
  }

  testWidgets('shows the number read-only with no label field', (tester) async {
    await harness(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The auto-generated number is displayed read-only — no text input.
    expect(find.text('JO-072326-005'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    // Mechanic stays optional at create.
    expect(find.text('— Optional —'), findsOneWidget);
  });

  testWidgets('creates immediately under the generated number (no label gate)',
      (tester) async {
    final getResult = await harness(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final result = getResult();
    expect(result, isNotNull);
    expect(result!.label, 'JO-072326-005');
    expect(result.model, isNull);
    expect(result.mechanicId, isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/widgets/new_job_order_dialog_test.dart`
Expected: FAIL — compile error: `showNewJobOrderDialog` doesn't accept a `jobOrderNo` named parameter yet.

- [ ] **Step 3: Rewrite new_job_order_dialog.dart**

Replace the full contents of `lib/presentation/mobile/widgets/drafts/new_job_order_dialog.dart` (drops the TextField + label gate; the read-only row is the exact one from `save_job_order_dialog.dart:83-108`):

```dart
import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/motorcycle_model_picker.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

/// Details collected when opening a new Job Order (cart-independent).
class NewJobOrderInput {
  const NewJobOrderInput({
    required this.label,
    this.model,
    this.mechanicId,
    this.mechanicName,
  });
  final String label;
  final String? model;
  final String? mechanicId;
  final String? mechanicName;
}

/// Prompts for a new Job Order's motorcycle model + mechanic under the
/// auto-generated [jobOrderNo] (shown read-only — numbering is sequential
/// per day, mirroring the POS Save-as-Job-Order dialog). Returns the input
/// (label = [jobOrderNo]), or null if cancelled. Does not touch the cart.
Future<NewJobOrderInput?> showNewJobOrderDialog(
  BuildContext context, {
  required String jobOrderNo,
}) {
  return showDialog<NewJobOrderInput>(
    context: context,
    barrierColor: AppDialog.scrimColor(
        Theme.of(context).brightness == Brightness.dark),
    builder: (_) => _NewJobOrderDialog(jobOrderNo: jobOrderNo),
  );
}

class _NewJobOrderDialog extends ConsumerStatefulWidget {
  const _NewJobOrderDialog({required this.jobOrderNo});
  final String jobOrderNo;
  @override
  ConsumerState<_NewJobOrderDialog> createState() => _NewJobOrderDialogState();
}

class _NewJobOrderDialogState extends ConsumerState<_NewJobOrderDialog> {
  String? _model;
  String? _mechanicId;
  String? _mechanicName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return AppDialog(
      title: 'New Job Order',
      leadingIcon: LucideIcons.clipboardList,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Auto-generated daily-sequential number replaces the old
          // customer/plate label — read-only by design (same row as the
          // POS Save-as-Job-Order dialog).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.hash, size: 15, color: muted),
                const SizedBox(width: 8),
                Text(
                  'Job Order No.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: muted, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  widget.jobOrderNo,
                  style: AppTextStyles.fieldInput
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MotorcycleModelPicker(
            selectedModel: _model,
            onChanged: (m) => setState(() => _model = m),
          ),
          const SizedBox(height: 12),
          MechanicPicker(
            nonePlaceholder: '— Optional —',
            selectedMechanicId: _mechanicId,
            onChanged: (m) => setState(() {
              _mechanicId = m?.id;
              _mechanicName = m?.name;
            }),
          ),
        ],
      ),
      actions: [
        appDialogCancel(context, 'Cancel', onTap: () => Navigator.pop(context)),
        appDialogPrimary(context, 'Create', onTap: () {
          Navigator.pop(
            context,
            NewJobOrderInput(
              label: widget.jobOrderNo,
              model: _model,
              mechanicId: _mechanicId,
              mechanicName: _mechanicName,
            ),
          );
        }),
      ],
    );
  }
}
```

- [ ] **Step 4: Update drafts_list_screen._createJobOrder**

Add the import to `lib/presentation/mobile/screens/drafts/drafts_list_screen.dart`:

```dart
import 'package:maki_mobile_pos/core/utils/job_order_number.dart';
```

Replace the `_createJobOrder` method with (number-prep block mirrors `pos_screen._showSaveDraftDialog` verbatim, adapted `mounted` → `context.mounted`):

```dart
  Future<void> _createJobOrder(BuildContext context, WidgetRef ref) async {
    // Sequential per-day number derived from today's existing job orders
    // (converted ones included so billed-out numbers are never reissued) —
    // mirrors pos_screen._showSaveDraftDialog.
    final now = DateTime.now();
    final String jobOrderNo;
    try {
      final todaysDrafts = await context.runWithWaiting(
        () => ref.read(draftRepositoryProvider).getDraftsByDateRange(
              startDate: now,
              endDate: now,
              includeConverted: true,
            ),
        message: 'Preparing…',
      );
      jobOrderNo =
          nextJobOrderNumber(now, todaysDrafts.map((d) => d.name));
    } catch (_) {
      if (context.mounted) {
        context.showErrorSnackBar('Could not prepare a job order number');
      }
      return;
    }
    if (!context.mounted) return;

    final input = await showNewJobOrderDialog(context, jobOrderNo: jobOrderNo);
    if (input == null) return;
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    final draft = DraftEntity(
      id: '',
      name: input.label,
      items: const [],
      motorcycleModel: input.model,
      mechanicId: input.mechanicId,
      mechanicName: input.mechanicName,
      createdBy: user.id,
      createdByName: user.displayName,
      createdAt: DateTime.now(),
    );
    if (!context.mounted) return;
    final created = await context.runWithWaiting(
      () => ref
          .read(draftOperationsProvider.notifier)
          .createDraft(actor: user, draft: draft),
      message: 'Creating…',
    );
    if (created != null && context.mounted) {
      context.pushNamed(RouteNames.draftEdit,
          pathParameters: {'id': created.id});
    }
  }
```

- [ ] **Step 5: Update drafts_list_load_test.dart**

The create flow now reads `draftRepositoryProvider` — the test harness needs a fake repo or the dialog test dies before opening. In `test/presentation/widgets/drafts_list_load_test.dart` add imports:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:maki_mobile_pos/core/utils/job_order_number.dart';
import 'package:maki_mobile_pos/data/repositories/draft_repository_impl.dart';
```

add this override to the `overrides:` list inside `pump`:

```dart
          draftRepositoryProvider.overrideWithValue(
            DraftRepositoryImpl(firestore: FakeFirebaseFirestore()),
          ),
```

and extend the `'app-bar plus opens the New Job Order dialog'` test:

```dart
  testWidgets('app-bar plus opens the New Job Order dialog', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(LucideIcons.plus));
    await tester.pumpAndSettle();
    expect(find.text('New Job Order'), findsOneWidget);
    // Read-only number derived from today's drafts (empty repo → -001);
    // no free-text label field remains.
    expect(
      find.text('${jobOrderPrefixFor(DateTime.now())}001'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });
```

(`draftRepositoryProvider` is already exported through `package:maki_mobile_pos/presentation/providers/draft_provider.dart`, which the test imports.)

- [ ] **Step 6: Run tests**

Run: `flutter test test/presentation/widgets/new_job_order_dialog_test.dart test/presentation/widgets/drafts_list_load_test.dart test/core/utils/job_order_number_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/mobile/widgets/drafts/new_job_order_dialog.dart lib/presentation/mobile/screens/drafts/drafts_list_screen.dart test/presentation/widgets/new_job_order_dialog_test.dart test/presentation/widgets/drafts_list_load_test.dart
git commit -m "$(cat <<'EOF'
feat(mobile): auto JO number in the drafts-list New Job Order flow

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Shared RankRow extracted from TopProductsCard

No visual change on the reports screens; `TopProductsCard` keeps its card shell, header, empty state, and provider wiring.

**Files:**
- Create: `lib/presentation/shared/widgets/common/rank_row.dart`
- Modify: `lib/presentation/shared/widgets/common/common_widgets.dart` (add barrel export)
- Modify: `lib/presentation/mobile/widgets/reports/top_products_card.dart` (replace `_RankRow`/`_RankColors` with the shared widget)
- Test: `test/presentation/widgets/rank_row_test.dart` (new); keep `test/presentation/mobile/screens/reports/top_selling_screen_test.dart` green

**Interfaces:**
- Consumes: `AppColors.hairline(bool dark)`, `AppColors.successFill/successText`, `AppColors.darkInputBorder/lightHairline/darkTextSecondary/lightTextMuted`, `AppTextStyles.productName`, `AppRadius.md/.pill`, `AppConstants.currencySymbol`, `num.toCurrency()`.
- Produces (Task 5 relies on this exact signature):

```dart
class RankRow extends StatelessWidget {
  const RankRow({
    super.key,
    required int index,        // 0-based rank: 0 gold, 1 silver, 2 bronze, 3+ neutral
    required String name,
    required String subtitle,  // SKU on every current call site (mono-styled)
    required int quantitySold,
    required double revenue,
    required int maxQuantity,  // rank-1 quantity, scales the share bar
    VoidCallback? onTap,
    double? profit,            // non-null → green profit pill renders
  });
}
```

**Assumption/latitude:** the spec allows subtitle = "SKU or 'N sold'". Both call sites pass the SKU (`TopSellingItem` carries `sku`), because the right-hand column already shows "N sold" — duplicating it as the subtitle would be noise. The subtitle keeps the RobotoMono styling from the reports card.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/widgets/rank_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/rank_row.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders rank, name, subtitle, qty, revenue and share bar',
      (tester) async {
    await tester.pumpWidget(host(const RankRow(
      index: 0,
      name: 'Brake Pad',
      subtitle: 'SKU-001',
      quantitySold: 8,
      revenue: 500,
      maxQuantity: 10,
    )));

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Brake Pad'), findsOneWidget);
    expect(find.text('SKU-001'), findsOneWidget);
    expect(find.text('8 sold'), findsOneWidget);
    expect(find.text('₱500.00'), findsOneWidget);

    final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(bar.value, 0.8);
  });

  testWidgets('profit pill renders only when profit is provided',
      (tester) async {
    await tester.pumpWidget(host(const RankRow(
      index: 1,
      name: 'Chain',
      subtitle: 'SKU-002',
      quantitySold: 5,
      revenue: 500,
      maxQuantity: 10,
      profit: 250,
    )));
    expect(find.text('+₱250'), findsOneWidget);

    await tester.pumpWidget(host(const RankRow(
      index: 1,
      name: 'Chain',
      subtitle: 'SKU-002',
      quantitySold: 5,
      revenue: 500,
      maxQuantity: 10,
    )));
    expect(find.textContaining('+₱'), findsNothing);
  });

  testWidgets('onTap fires when the row is tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(host(RankRow(
      index: 3,
      name: 'Bulb',
      subtitle: 'SKU-003',
      quantitySold: 1,
      revenue: 50,
      maxQuantity: 10,
      onTap: () => tapped = true,
    )));

    await tester.tap(find.text('Bulb'));
    expect(tapped, true);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/widgets/rank_row_test.dart`
Expected: FAIL — compile error, `rank_row.dart` doesn't exist.

- [ ] **Step 3: Create the shared widget**

Create `lib/presentation/shared/widgets/common/rank_row.dart` (body is the verbatim port of `TopProductsCard._RankRow` with `product.*` → params, `canViewProfit` → `profit != null`):

```dart
import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// One ranked product line — medal circle + name/subtitle + "N sold"/revenue,
/// then a share bar scaled to [maxQuantity] and an optional profit pill.
/// Extracted from the reports TopProductsCard so the dashboard's Top Selling
/// list shares the exact visual.
class RankRow extends StatelessWidget {
  const RankRow({
    super.key,
    required this.index,
    required this.name,
    required this.subtitle,
    required this.quantitySold,
    required this.revenue,
    required this.maxQuantity,
    this.onTap,
    this.profit,
  });

  /// 0-based rank (0 = gold, 1 = silver, 2 = bronze, 3+ = neutral).
  final int index;
  final String name;

  /// Second line under the name — the SKU on every current call site
  /// (mono-styled).
  final String subtitle;
  final int quantitySold;
  final double revenue;

  /// Quantity of the rank-1 row — scales the share bar.
  final int maxQuantity;
  final VoidCallback? onTap;

  /// When non-null, renders the green profit pill (admin-gated surfaces
  /// pass it; the dashboard never does).
  final double? profit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final isDark = theme.brightness == Brightness.dark;
    final hairline = AppColors.hairline(isDark);
    final progress = maxQuantity > 0 ? quantitySold / maxQuantity : 0.0;
    final medal = _rankColors(index, isDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Rank medal.
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: medal.ring,
                    width: index < 3 ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: medal.number,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style:
                          AppTextStyles.productName.copyWith(fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: muted,
                        fontSize: 11.5,
                        fontFamily: 'RobotoMono',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$quantitySold sold',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  Text(
                    revenue.toCurrency(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: muted, fontSize: 11.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              const SizedBox(width: 28),
              const SizedBox(width: 11),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: hairline,
                    valueColor: AlwaysStoppedAnimation<Color>(medal.bar),
                    minHeight: 6,
                  ),
                ),
              ),
              if (profit != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    color: AppColors.successFill(isDark),
                  ),
                  child: Text(
                    '+${AppConstants.currencySymbol}${profit!.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.successText(isDark),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Medal palette per 0-based rank — amber / silver / bronze for the top
  /// three, neutral after. Rank-1 leads gold in dark to match the primary
  /// flip.
  _RankColors _rankColors(int index, bool dark) {
    switch (index) {
      case 0:
        return _RankColors(
          ring: const Color(0xFFE8B84C),
          number: dark ? const Color(0xFFE8B84C) : const Color(0xFFB07A12),
          bar: const Color(0xFFE8B84C),
        );
      case 1:
        return _RankColors(
          ring: const Color(0xFF90A4AE),
          number: dark ? const Color(0xFFAEC0C6) : const Color(0xFF5E7079),
          bar: const Color(0xFF90A4AE),
        );
      case 2:
        return _RankColors(
          ring: const Color(0xFFB08D6F),
          number: dark ? const Color(0xFFCBA890) : const Color(0xFF8A6244),
          bar: const Color(0xFFB08D6F),
        );
      default:
        return _RankColors(
          ring: dark ? AppColors.darkInputBorder : AppColors.lightHairline,
          number:
              dark ? AppColors.darkTextSecondary : AppColors.lightTextMuted,
          bar: dark ? const Color(0xFF5E7A84) : const Color(0xFF283E46),
        );
    }
  }
}

class _RankColors {
  const _RankColors({
    required this.ring,
    required this.number,
    required this.bar,
  });
  final Color ring;
  final Color number;
  final Color bar;
}
```

Add the export to `lib/presentation/shared/widgets/common/common_widgets.dart` (alphabetical position after `password_dialog.dart`):

```dart
export 'rank_row.dart';
```

- [ ] **Step 4: Run the new test**

Run: `flutter test test/presentation/widgets/rank_row_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Switch TopProductsCard to the shared row**

In `lib/presentation/mobile/widgets/reports/top_products_card.dart`:

a) Delete the entire `_RankRow` and `_RankColors` classes (everything from `/// One ranked product line…` to the end of the file).

b) Replace the row construction in `_buildProductsList` with:

```dart
    return Column(
      children: [
        for (var i = 0; i < products.length; i++)
          Padding(
            padding: EdgeInsets.only(
                bottom: i == products.length - 1 ? 0 : 14),
            child: RankRow(
              index: i,
              name: products[i].name,
              subtitle: products[i].sku,
              quantitySold: products[i].quantitySold,
              revenue: products[i].totalRevenue,
              maxQuantity: maxQuantity,
              onTap: () => context
                  .push('${RoutePaths.inventory}/${products[i].productId}'),
              profit: canViewProfit ? products[i].totalProfit : null,
            ),
          ),
      ],
    );
```

c) `RankRow` arrives via the existing `common_widgets.dart` import. Remove imports the analyzer now flags as unused (likely `app_constants.dart` and `num_extensions.dart` — the pill/revenue formatting moved into RankRow).

- [ ] **Step 6: Run reports tests + analyze**

Run: `flutter test test/presentation/mobile/screens/reports/top_selling_screen_test.dart test/presentation/widgets/rank_row_test.dart && flutter analyze`
Expected: PASS, analyze clean.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/shared/widgets/common/rank_row.dart lib/presentation/shared/widgets/common/common_widgets.dart lib/presentation/mobile/widgets/reports/top_products_card.dart test/presentation/widgets/rank_row_test.dart
git commit -m "$(cat <<'EOF'
refactor(mobile): extract shared RankRow from TopProductsCard

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Dashboard TopSellingTodayWidget adopts the ranked/bar rows

Live `topSellingTodayProvider` data unchanged; 5/10 See-more collapse unchanged; no profit pill; no onTap on dashboard rows (they were not tappable before).

**Files:**
- Modify: `lib/presentation/shared/widgets/dashboard/top_selling_today_widget.dart` (replace `_Row` + `_Thumb` with `RankRow`)
- Test: `test/presentation/widgets/top_selling_today_widget_test.dart`

**Interfaces:**
- Consumes: `RankRow` from Task 4 (exact signature above); `TopSellingItem` (`productId`, `sku`, `name`, `quantitySold`, `totalRevenue`) from `lib/core/utils/top_selling.dart`.
- Produces: nothing new.

- [ ] **Step 1: Write the failing test**

Add to `test/presentation/widgets/top_selling_today_widget_test.dart` — new import at the top:

```dart
import 'package:maki_mobile_pos/presentation/shared/widgets/common/rank_row.dart';
```

and a new test inside the existing group (after `'product name and qty-sold render correctly'`):

```dart
    testWidgets('rows use the shared ranked/bar visual with no profit pill',
        (tester) async {
      await _pump(tester, _salesWithProducts(3));
      await tester.pumpAndSettle();

      expect(find.byType(RankRow), findsNWidgets(3));
      // Medal rank numbers 1–3 render.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      // One share bar per row.
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
      // The dashboard never shows the profit pill.
      expect(find.textContaining('+₱'), findsNothing);
    });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/widgets/top_selling_today_widget_test.dart`
Expected: FAIL — `find.byType(RankRow)` finds nothing (old `_Row` still renders).

- [ ] **Step 3: Adopt RankRow**

In `lib/presentation/shared/widgets/dashboard/top_selling_today_widget.dart`:

a) Add the import:

```dart
import 'package:maki_mobile_pos/presentation/shared/widgets/common/rank_row.dart';
```

b) Replace the row construction inside the `DashboardListCard` (the `for` loop) with:

```dart
        return DashboardListCard(
          child: Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                if (i > 0) divider,
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: RankRow(
                    index: i,
                    name: visible[i].name,
                    subtitle: visible[i].sku,
                    quantitySold: visible[i].quantitySold,
                    revenue: visible[i].totalRevenue,
                    maxQuantity: ranked.first.quantitySold,
                  ),
                ),
              ],
              if (canExpand) ...[
                divider,
                TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 16,
                  ),
                  label: Text(_expanded ? 'See less' : 'See more'),
                ),
              ],
            ],
          ),
        );
```

(`maxQuantity` = `ranked.first.quantitySold`: the list is sorted by units desc, so rank 1 anchors the share bar even in the collapsed view.)

c) Delete the `_Row` and `_Thumb` classes entirely (keep `_EmptyState`). Remove imports the analyzer flags as unused (likely `num_extensions.dart`; `AppColors`/`AppSpacing` from theme are still used by the divider/empty/loading states).

- [ ] **Step 4: Run the widget tests**

Run: `flutter test test/presentation/widgets/top_selling_today_widget_test.dart && flutter analyze`
Expected: PASS — all pre-existing tests (empty state, top-5 collapse, See more/less, cap at 10, name + "N sold") still hold because `RankRow` renders the same `'N sold'` text; analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/shared/widgets/dashboard/top_selling_today_widget.dart test/presentation/widgets/top_selling_today_widget_test.dart
git commit -m "$(cat <<'EOF'
feat(mobile): dashboard Top Selling adopts ranked/bar rows

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: ClosingSectionCard trailing slot + EOD Add Expense in the header row

**Files:**
- Modify: `lib/presentation/mobile/widgets/reports/closing_widgets.dart` (`ClosingSectionCard`, lines ~13-54)
- Modify: `lib/presentation/mobile/screens/reports/end_of_day_screen.dart` (Expenses card, lines ~155-218)
- Test: `test/presentation/widgets/closing_section_card_test.dart` (new)

**Interfaces:**
- Consumes: existing `ClosingSectionCard({required IconData icon, required String title, required List<Widget> children, Color? iconColor})` — ~10 call sites in end_of_day_screen (all keep working: the new param is optional).
- Produces: `ClosingSectionCard` gains `final Widget? trailing;` — appended to the header Row after a `Spacer`.

- [ ] **Step 1: Write the failing test**

Create `test/presentation/widgets/closing_section_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_widgets.dart';

void main() {
  testWidgets('trailing widget renders in the header row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClosingSectionCard(
            icon: LucideIcons.arrowDownCircle,
            title: 'Expenses',
            trailing: OutlinedButton(
              onPressed: () {},
              child: const Text('Add Expense'),
            ),
            children: const [Text('body')],
          ),
        ),
      ),
    );

    expect(find.text('Add Expense'), findsOneWidget);
    // The trailing sits in the same Row as the title (OutlinedButton has no
    // internal Row, so the nearest Row ancestor is the header).
    final headerRow = find
        .ancestor(of: find.text('Add Expense'), matching: find.byType(Row))
        .first;
    expect(
      find.descendant(of: headerRow, matching: find.text('Expenses')),
      findsOneWidget,
    );
  });

  testWidgets('omitting trailing keeps the plain header', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ClosingSectionCard(
            icon: LucideIcons.receipt,
            title: 'Sales',
            children: [Text('body')],
          ),
        ),
      ),
    );
    expect(find.text('Sales'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/widgets/closing_section_card_test.dart`
Expected: FAIL — compile error, `No named parameter with the name 'trailing'`.

- [ ] **Step 3: Add the trailing slot**

In `lib/presentation/mobile/widgets/reports/closing_widgets.dart`, change `ClosingSectionCard` to:

```dart
/// `AppCard` section with a Lucide icon header — the closing-flow card shell.
/// [trailing] (optional) renders right-aligned in the header row, e.g. the
/// Expenses card's compact Add Expense button.
class ClosingSectionCard extends StatelessWidget {
  const ClosingSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: iconColor ?? theme.colorScheme.primary),
              const SizedBox(width: 9),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Move the EOD Add Expense button**

In `lib/presentation/mobile/screens/reports/end_of_day_screen.dart`, in `_buildReview()`'s Expenses card: add `trailing:` and delete the `const SizedBox(height: 16),` + the whole `Align(...)` block from the end of `children`. The card becomes:

```dart
                ClosingSectionCard(
                  icon: LucideIcons.arrowDownCircle,
                  title: 'Expenses',
                  trailing: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => context.push(RoutePaths.expenseAdd),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: const Text('Add Expense'),
                  ),
                  children: [
                    if (data.expenses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          'No expenses today',
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else ...[
                      ClosingExpenseList(
                        expenses: data.expenses,
                        excludedIds: _excludedIds,
                        enabled: !_busy,
                        onToggle: (id) => setState(() {
                          _excludedIds.contains(id)
                              ? _excludedIds.remove(id)
                              : _excludedIds.add(id);
                        }),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(
                          height: 1,
                          color: AppColors.hairline(
                              Theme.of(context).brightness == Brightness.dark),
                        ),
                      ),
                      ClosingKvRow(
                          label: 'Total expenses',
                          value: _peso(draft.totalExpenses)),
                      ClosingKvRow(
                          label: 'Cash expenses',
                          value: _peso(draft.cashExpenses)),
                    ],
                  ],
                ),
```

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test test/presentation/widgets/closing_section_card_test.dart && flutter analyze`
Expected: PASS, analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/widgets/reports/closing_widgets.dart lib/presentation/mobile/screens/reports/end_of_day_screen.dart test/presentation/widgets/closing_section_card_test.dart
git commit -m "$(cat <<'EOF'
feat(mobile): EOD Add Expense joins the Expenses header row

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7a: Plate amounts persisted — entity, model, use case, notifier

Data layer only. The EOD screen keeps compiling via a minimal shim (its single typed amount is wrapped in a one-element list); Task 7b replaces the UI.

**Files:**
- Modify: `lib/domain/entities/daily_closing_entity.dart` (`DailyClosingEntity`, lines ~171-262)
- Modify: `lib/data/models/daily_closing_model.dart`
- Modify: `lib/domain/usecases/daily_closing/close_day_usecase.dart` (`execute` params ~line 40-41, entity stamp ~line 105-106)
- Modify: `lib/presentation/providers/daily_closing_provider.dart` (`closeDay` params ~line 131-132)
- Modify: `lib/presentation/mobile/screens/reports/end_of_day_screen.dart` (`_submit` call-site shim only)
- Test: `test/data/models/daily_closing_model_test.dart`, `test/domain/usecases/daily_closing/close_day_usecase_test.dart`

**Interfaces:**
- Consumes: existing `DailyClosingDraft.expectedCashFor(double openingFloat, {double plateNoDp = 0, double plateNoDelivery = 0})` (UNCHANGED — the scalar sums keep feeding it).
- Produces (Task 7b relies on these):
  - `DailyClosingEntity`/`DailyClosingModel` gain `final List<double> plateNoDpAmounts;` and `final List<double> plateNoDeliveryAmounts;` (constructor default `const []`, in `props`, round-tripped as Firestore arrays; `fromMap` back-compat → missing field reads `const []`).
  - `CloseDayUseCase.execute({required UserEntity actor, required DateTime date, required double openingFloat, required double countedCash, List<double> plateNoDpAmounts = const [], List<double> plateNoDeliveryAmounts = const [], Set<String> excludedExpenseIds = const {}, String? notes})` — the scalar `plateNoDp`/`plateNoDelivery` params are REMOVED; sums are computed once inside the use case and stamped alongside the lists.
  - `DailyClosingOperationsNotifier.closeDay({required DateTime date, required double openingFloat, required double countedCash, List<double> plateNoDpAmounts = const [], List<double> plateNoDeliveryAmounts = const [], Set<String> excludedExpenseIds = const {}, String? notes})` mirrors it.

- [ ] **Step 1: Write the failing tests**

In `test/data/models/daily_closing_model_test.dart`, update the fixture and tests. Add to the `entity` constructor arguments (right after `plateNoDelivery: 50,`):

```dart
      plateNoDpAmounts: const [100, 200],
      plateNoDeliveryAmounts: const [50],
```

Add to the `'round-trips entity -> map -> entity'` test body (after the `plateNoDelivery` expect):

```dart
      expect(back.plateNoDpAmounts, [100, 200]);
      expect(back.plateNoDeliveryAmounts, [50]);
```

Add to the `'defaults numeric fields to 0 when missing'` test body (old docs → empty lists):

```dart
      expect(model.plateNoDpAmounts, isEmpty);
      expect(model.plateNoDeliveryAmounts, isEmpty);
```

(Note: the fixture's `plateNoDp: 300` already equals `100 + 200` and `plateNoDelivery: 50` equals the list sum — keep it that way; scalars = sum is the invariant.)

In `test/domain/usecases/daily_closing/close_day_usecase_test.dart`, replace the whole test `'plate-no DP adds and delivery subtracts from expected cash'` with:

```dart
  test('plate lists are summed into scalars and persisted itemized', () async {
    final captured = <DailyClosingEntity>[];
    when(() => closings.saveClosing(any())).thenAnswer((inv) async {
      final c = inv.positionalArguments.first as DailyClosingEntity;
      captured.add(c);
      return c;
    });

    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      date: DateTime(2026, 5, 28),
      openingFloat: 2000,
      countedCash: 0,
      plateNoDpAmounts: const [100, 200],
      plateNoDeliveryAmounts: const [50],
    );

    expect(result.success, true);
    final saved = captured.single;
    // Scalars are the sums of their lists — single source for cash math.
    expect(saved.plateNoDp, 300);
    expect(saved.plateNoDelivery, 50);
    expect(saved.plateNoDpAmounts, [100, 200]);
    expect(saved.plateNoDeliveryAmounts, [50]);
    // 2000 float + 700 cash - 100 cash exp + 300 dp - 50 delivery = 2850
    expect(saved.expectedCash, 2850);
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/data/models/daily_closing_model_test.dart test/domain/usecases/daily_closing/close_day_usecase_test.dart`
Expected: FAIL — compile errors (`plateNoDpAmounts` named parameter doesn't exist).

- [ ] **Step 3: Implement the data changes**

a) `lib/domain/entities/daily_closing_entity.dart`, in `DailyClosingEntity`: after the `plateNoDelivery` field declaration add:

```dart
  /// Itemized Plate-No amounts (one entry per order), persisted so the
  /// closed-day view can show each amount. [plateNoDp]/[plateNoDelivery]
  /// always equal the sum of their list; docs saved before itemization
  /// carry scalars only and read back with empty lists.
  final List<double> plateNoDpAmounts;
  final List<double> plateNoDeliveryAmounts;
```

In the constructor, after `this.plateNoDelivery = 0,` add:

```dart
    this.plateNoDpAmounts = const [],
    this.plateNoDeliveryAmounts = const [],
```

In `props`, after `plateNoDelivery,` add:

```dart
        plateNoDpAmounts,
        plateNoDeliveryAmounts,
```

b) `lib/data/models/daily_closing_model.dart`: add the same two `final List<double>` fields and constructor defaults (after `plateNoDelivery`). In `fromMap`, add a list helper next to `d`/`i` and the two fields:

```dart
    List<double> dl(String k) =>
        (map[k] as List?)?.map((e) => (e as num).toDouble()).toList() ??
        const [];
```

```dart
      plateNoDpAmounts: dl('plateNoDpAmounts'),
      plateNoDeliveryAmounts: dl('plateNoDeliveryAmounts'),
```

In `fromEntity`: `plateNoDpAmounts: e.plateNoDpAmounts, plateNoDeliveryAmounts: e.plateNoDeliveryAmounts,`. In `toMap()` after `'plateNoDelivery': plateNoDelivery,`:

```dart
      'plateNoDpAmounts': plateNoDpAmounts,
      'plateNoDeliveryAmounts': plateNoDeliveryAmounts,
```

In `toEntity()`: `plateNoDpAmounts: plateNoDpAmounts, plateNoDeliveryAmounts: plateNoDeliveryAmounts,`.

c) `lib/domain/usecases/daily_closing/close_day_usecase.dart`: replace the two scalar params in `execute` with:

```dart
    List<double> plateNoDpAmounts = const [],
    List<double> plateNoDeliveryAmounts = const [],
```

After the `draft` is built (before `expectedCash`), compute the sums once:

```dart
      // Sums are computed ONCE here; the scalars remain the single source
      // for expected-cash math and back-compat reads.
      final plateNoDp =
          plateNoDpAmounts.fold(0.0, (total, amount) => total + amount);
      final plateNoDelivery =
          plateNoDeliveryAmounts.fold(0.0, (total, amount) => total + amount);
```

(`expectedCash` and the entity stamp below keep using the local `plateNoDp`/`plateNoDelivery` names unchanged.) In the entity construction, after `plateNoDelivery: plateNoDelivery,` add:

```dart
        plateNoDpAmounts: List.of(plateNoDpAmounts),
        plateNoDeliveryAmounts: List.of(plateNoDeliveryAmounts),
```

d) `lib/presentation/providers/daily_closing_provider.dart`, `closeDay`: replace `double plateNoDp = 0, double plateNoDelivery = 0,` with:

```dart
    List<double> plateNoDpAmounts = const [],
    List<double> plateNoDeliveryAmounts = const [],
```

and pass them through to `execute` (replacing `plateNoDp: plateNoDp, plateNoDelivery: plateNoDelivery,`):

```dart
            plateNoDpAmounts: plateNoDpAmounts,
            plateNoDeliveryAmounts: plateNoDeliveryAmounts,
```

e) `lib/presentation/mobile/screens/reports/end_of_day_screen.dart`, `_submit` shim (temporary until Task 7b — one typed amount becomes a one-entry list, sum identical):

```dart
              plateNoDpAmounts: _plateDp > 0 ? [_plateDp] : const <double>[],
              plateNoDeliveryAmounts:
                  _plateDelivery > 0 ? [_plateDelivery] : const <double>[],
```

(replacing `plateNoDp: _plateDp, plateNoDelivery: _plateDelivery,`).

- [ ] **Step 4: Run the tests**

Run: `flutter test test/data/models/daily_closing_model_test.dart test/domain/usecases/daily_closing/close_day_usecase_test.dart test/domain/entities/ test/presentation/providers/daily_closing_draft_live_test.dart && flutter analyze`
Expected: PASS, analyze clean. (`daily_closing_draft_test.dart` touches `DailyClosingDraft` only — unchanged — but run the entities dir to be sure.)

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/daily_closing_entity.dart lib/data/models/daily_closing_model.dart lib/domain/usecases/daily_closing/close_day_usecase.dart lib/presentation/providers/daily_closing_provider.dart lib/presentation/mobile/screens/reports/end_of_day_screen.dart test/data/models/daily_closing_model_test.dart test/domain/usecases/daily_closing/close_day_usecase_test.dart
git commit -m "$(cat <<'EOF'
feat(mobile): persist itemized Plate No DP/Delivery amounts (data + use case)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 7b: EOD add-a-row plate amounts UI + itemized closed-day view

**Files:**
- Modify: `lib/presentation/mobile/widgets/reports/closing_widgets.dart` (new `ClosingAmountList` widget)
- Modify: `lib/presentation/mobile/screens/reports/end_of_day_screen.dart` (controllers → lists, Plate No Orders card, `_submit`, `_ClosedView` itemization)
- Test: `test/presentation/widgets/closing_amount_list_test.dart` (new), `test/presentation/widgets/end_of_day_closed_view_test.dart` (new)

**Interfaces:**
- Consumes: `ClosingField`, `ClosingKvRow`, `ClosingSectionCard` (with Task 6's `trailing`); `DailyClosingOperationsNotifier.closeDay(... plateNoDpAmounts/plateNoDeliveryAmounts ...)` from Task 7a; `DailyClosingEntity.plateNoDpAmounts/.plateNoDeliveryAmounts`; providers `dailyClosingForDateProvider(date)` / `dailyClosingDataProvider(date)` (both `FutureProvider.family<_, DateTime>`).
- Produces:

```dart
class ClosingAmountList extends StatefulWidget {
  const ClosingAmountList({
    super.key,
    required String label,
    required List<double> amounts,
    required ValueChanged<List<double>> onChanged,
    bool enabled = true,
  });
}
```

Add button key: `Key('add-amount-<label>')`; remove buttons carry `tooltip: 'Remove amount'`. Only ADDED rows feed the sums — a typed-but-not-added amount does not count (deliberate: the add-a-row list is the source of truth).

- [ ] **Step 1: Write the failing widget test**

Create `test/presentation/widgets/closing_amount_list_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/closing_widgets.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<double> amounts,
    required ValueChanged<List<double>> onChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClosingAmountList(
              label: 'Plate No DP',
              amounts: amounts,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('adding an amount reports the appended list', (tester) async {
    List<double>? changed;
    await pump(tester, amounts: const [100], onChanged: (v) => changed = v);

    await tester.enterText(find.byType(TextFormField), '250');
    await tester.tap(find.byKey(const Key('add-amount-Plate No DP')));
    await tester.pump();

    expect(changed, [100, 250]);
  });

  testWidgets('invalid or zero input is ignored', (tester) async {
    List<double>? changed;
    await pump(tester, amounts: const [], onChanged: (v) => changed = v);

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.byKey(const Key('add-amount-Plate No DP')));
    await tester.pump();
    expect(changed, isNull);

    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.tap(find.byKey(const Key('add-amount-Plate No DP')));
    await tester.pump();
    expect(changed, isNull);
  });

  testWidgets('rows are removable and the sum line totals the entries',
      (tester) async {
    List<double>? changed;
    await pump(tester,
        amounts: const [100, 250], onChanged: (v) => changed = v);

    expect(find.text('Entry 1'), findsOneWidget);
    expect(find.text('Entry 2'), findsOneWidget);
    // Live sum line: label carries the entry count, value the total.
    expect(find.textContaining('2 entries'), findsOneWidget);
    expect(find.text('₱350.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove amount').first);
    await tester.pump();
    expect(changed, [250]);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/widgets/closing_amount_list_test.dart`
Expected: FAIL — compile error, `ClosingAmountList` doesn't exist.

- [ ] **Step 3: Implement ClosingAmountList**

Append to `lib/presentation/mobile/widgets/reports/closing_widgets.dart` (a plain-peso helper next to the existing `_signedPeso`, plus the widget):

```dart
String _plainPeso(double v) =>
    '${AppConstants.currencySymbol}${v.toCurrencyWithoutSymbol()}';

/// Add-a-row peso amount list (Plate No DP / Delivery on the EOD form).
/// The amount input + Add appends to [amounts]; each row is removable while
/// the day is open; a live sum line totals the entries. The parent owns the
/// list state — only ADDED rows count toward the sums.
class ClosingAmountList extends StatefulWidget {
  const ClosingAmountList({
    super.key,
    required this.label,
    required this.amounts,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final List<double> amounts;
  final ValueChanged<List<double>> onChanged;
  final bool enabled;

  @override
  State<ClosingAmountList> createState() => _ClosingAmountListState();
}

class _ClosingAmountListState extends State<ClosingAmountList> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final parsed = double.tryParse(_controller.text.trim());
    if (parsed == null || parsed <= 0) return;
    widget.onChanged([...widget.amounts, parsed]);
    _controller.clear();
  }

  void _removeAt(int index) {
    final next = List<double>.of(widget.amounts)..removeAt(index);
    widget.onChanged(next);
  }

  double get _sum => widget.amounts.fold(0.0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ClosingField(
                label: widget.label,
                controller: _controller,
                enabled: widget.enabled,
                hintText: '0',
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                key: Key('add-amount-${widget.label}'),
                onPressed: widget.enabled ? _add : null,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(LucideIcons.plus, size: 14),
                label: const Text('Add'),
              ),
            ),
          ],
        ),
        for (var i = 0; i < widget.amounts.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Entry ${i + 1}',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                ),
                Text(
                  _plainPeso(widget.amounts[i]),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: Icon(LucideIcons.x, size: 15, color: muted),
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.enabled ? () => _removeAt(i) : null,
                  tooltip: 'Remove amount',
                ),
              ],
            ),
          ),
        if (widget.amounts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ClosingKvRow(
              label: '${widget.label} total (${widget.amounts.length} '
                  '${widget.amounts.length == 1 ? 'entry' : 'entries'})',
              value: _plainPeso(_sum),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the widget test**

Run: `flutter test test/presentation/widgets/closing_amount_list_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Write the failing closed-view test**

Create `test/presentation/widgets/end_of_day_closed_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/end_of_day_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/daily_closing_provider.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  const emptySummary = SalesSummary(
    totalSalesCount: 0,
    voidedSalesCount: 0,
    grossAmount: 0,
    totalDiscounts: 0,
    netAmount: 0,
    totalCost: 0,
    totalProfit: 0,
    byPaymentMethod: {},
  );

  // Live data matching the closing → no post-close drift banner.
  final liveData = DailyClosingData(
    businessDate: today,
    summary: emptySummary,
    expenses: const [],
  );

  DailyClosingEntity closing({
    double plateNoDp = 0,
    double plateNoDelivery = 0,
    List<double> plateNoDpAmounts = const [],
    List<double> plateNoDeliveryAmounts = const [],
  }) =>
      DailyClosingEntity(
        id: 'closing-1',
        businessDate: today,
        grossSales: 0,
        netSales: 0,
        totalDiscounts: 0,
        cashSales: 0,
        nonCashSales: 0,
        gcashSales: 0,
        mayaSales: 0,
        totalExpenses: 0,
        cashExpenses: 0,
        salmonReceivable: 0,
        plateNoDp: plateNoDp,
        plateNoDelivery: plateNoDelivery,
        plateNoDpAmounts: plateNoDpAmounts,
        plateNoDeliveryAmounts: plateNoDeliveryAmounts,
        openingFloat: 1000,
        expectedCash: 1000 + plateNoDp - plateNoDelivery,
        countedCash: 1000 + plateNoDp - plateNoDelivery,
        variance: 0,
        salesCount: 0,
        voidedCount: 0,
        closedBy: 'u1',
        closedByName: 'Ada',
        closedAt: today.add(const Duration(hours: 20)),
      );

  Future<void> pump(WidgetTester tester, DailyClosingEntity saved) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailyClosingForDateProvider(today)
              .overrideWith((ref) async => saved),
          dailyClosingDataProvider(today)
              .overrideWith((ref) async => liveData),
        ],
        child: const MaterialApp(home: EndOfDayScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('itemizes each plate amount when lists are persisted',
      (tester) async {
    await pump(
      tester,
      closing(
        plateNoDp: 350,
        plateNoDelivery: 50,
        plateNoDpAmounts: const [100, 250],
        plateNoDeliveryAmounts: const [50],
      ),
    );

    expect(find.text('Plate No DP · 2 entries'), findsOneWidget);
    expect(find.text('₱100.00'), findsOneWidget);
    expect(find.text('₱250.00'), findsOneWidget);
    expect(find.text('Plate No Delivery · 1 entry'), findsOneWidget);
    // ₱50.00 appears twice: the delivery total AND its single entry row.
    expect(find.text('₱50.00'), findsNWidgets(2));
  });

  testWidgets('old docs (scalars only) keep the single KV rows',
      (tester) async {
    await pump(tester, closing(plateNoDp: 300));

    expect(find.text('Plate No DP'), findsOneWidget);
    expect(find.text('₱300.00'), findsOneWidget);
    expect(find.textContaining('entries'), findsNothing);
    expect(find.textContaining('Entry'), findsNothing);
  });
}
```

- [ ] **Step 6: Run to verify it fails**

Run: `flutter test test/presentation/widgets/end_of_day_closed_view_test.dart`
Expected: FAIL — `'Plate No DP · 2 entries'` not found (closed view still renders single KV rows).

- [ ] **Step 7: Rewire the EOD screen**

In `lib/presentation/mobile/screens/reports/end_of_day_screen.dart`:

a) Delete `_plateDpController` / `_plateDeliveryController` (fields + the two `dispose()` lines) and replace the getters:

```dart
  List<double> _plateDpAmounts = const [];
  List<double> _plateDeliveryAmounts = const [];

  double get _plateDp => _plateDpAmounts.fold(0.0, (a, b) => a + b);
  double get _plateDelivery =>
      _plateDeliveryAmounts.fold(0.0, (a, b) => a + b);
```

b) Replace the two `ClosingField`s in the Plate No Orders card with:

```dart
                ClosingSectionCard(
                  icon: LucideIcons.clipboardList,
                  title: 'Plate No Orders',
                  children: [
                    ClosingAmountList(
                      label: 'Plate No DP',
                      amounts: _plateDpAmounts,
                      enabled: !_busy,
                      onChanged: (next) =>
                          setState(() => _plateDpAmounts = next),
                    ),
                    const SizedBox(height: 12),
                    ClosingAmountList(
                      label: 'Plate No Delivery',
                      amounts: _plateDeliveryAmounts,
                      enabled: !_busy,
                      onChanged: (next) =>
                          setState(() => _plateDeliveryAmounts = next),
                    ),
                  ],
                ),
```

(The `setState` in `onChanged` re-runs `_buildReview`, so the existing expected-cash preview keeps updating from the `_plateDp`/`_plateDelivery` sum getters — no change needed there.)

c) In `_submit`, replace the Task 7a shim with the real lists:

```dart
              plateNoDpAmounts: List.of(_plateDpAmounts),
              plateNoDeliveryAmounts: List.of(_plateDeliveryAmounts),
```

d) In `_ClosedView`, replace the Plate No Orders section (the `if (closing.plateNoDp > 0 || closing.plateNoDelivery > 0) ...` block) with:

```dart
          if (closing.plateNoDp > 0 || closing.plateNoDelivery > 0) ...[
            const SizedBox(height: 12),
            ClosingSectionCard(
              icon: LucideIcons.clipboardList,
              title: 'Plate No Orders',
              children: [
                ..._plateRows('Plate No DP', closing.plateNoDp,
                    closing.plateNoDpAmounts),
                ..._plateRows('Plate No Delivery', closing.plateNoDelivery,
                    closing.plateNoDeliveryAmounts),
              ],
            ),
          ],
```

and add this helper method to `_ClosedView` (next to `_peso`):

```dart
  /// Itemized rows when the closing carries per-order amounts; the single
  /// KV row for docs saved before itemization (scalars only).
  List<Widget> _plateRows(String label, double total, List<double> amounts) {
    if (amounts.isEmpty) {
      return [ClosingKvRow(label: label, value: _peso(total))];
    }
    return [
      ClosingKvRow(
        label:
            '$label · ${amounts.length} ${amounts.length == 1 ? 'entry' : 'entries'}',
        value: _peso(total),
      ),
      for (var i = 0; i < amounts.length; i++)
        ClosingKvRow(
          label: 'Entry ${i + 1}',
          value: _peso(amounts[i]),
          indented: true,
        ),
    ];
  }
```

- [ ] **Step 8: Run tests + analyze**

Run: `flutter test test/presentation/widgets/end_of_day_closed_view_test.dart test/presentation/widgets/closing_amount_list_test.dart test/presentation/widgets/closing_section_card_test.dart && flutter analyze`
Expected: PASS, analyze clean.

- [ ] **Step 9: Commit**

```bash
git add lib/presentation/mobile/widgets/reports/closing_widgets.dart lib/presentation/mobile/screens/reports/end_of_day_screen.dart test/presentation/widgets/closing_amount_list_test.dart test/presentation/widgets/end_of_day_closed_view_test.dart
git commit -m "$(cat <<'EOF'
feat(mobile): EOD add-a-row plate amounts + itemized closed-day view

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Draft-edit single scroll + sticky Bill-out footer; keyboard-dismiss unfocus

**Files:**
- Modify: `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart` (`_buildDraftContent` body ~line 217-322, `_buildSummarySection` decoration ~line 486-491)
- Modify: `lib/presentation/mobile/widgets/pos/product_search_field.dart` (`_ProductSearchFieldState` gains `WidgetsBindingObserver`)
- Test: `test/presentation/widgets/draft_edit_screen_structure_test.dart` (new), `test/presentation/widgets/product_search_field_unfocus_test.dart` (new); keep `draft_edit_screen_{items,header,addparts,labor}_test.dart` + `product_search_field_inline_test.dart` green

**Interfaces:**
- Consumes: `AppShadows.pinnedFooter({bool dark = false})`; POS's cart pattern (`pos_screen._buildCartSection`: one `SingleChildScrollView`, inner `ListView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics())`, fixed footer).
- Produces: no API change. `ProductSearchField` gains internal `didChangeMetrics` unfocus behavior (covers POS search AND the add-parts sheet's inline field — both use this widget).

- [ ] **Step 1: Write the failing structure test**

Create `test/presentation/widgets/draft_edit_screen_structure_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/drafts/draft_edit_screen.dart';

void main() {
  DraftEntity buildDraft() => DraftEntity(
        id: 'draft-1',
        name: 'JO-072326-001',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
          ),
        ],
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30, 10, 0),
      );

  Widget harness(DraftEntity draft) => ProviderScope(
        overrides: [
          draftByIdProvider('draft-1').overrideWith((ref) async => draft),
          activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: DraftEditScreen(draftId: 'draft-1')),
      );

  testWidgets('one scroll region; summary + Bill out pinned outside it',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(buildDraft()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Header, parts and labor all live INSIDE the single scroll region.
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('Parts'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('Labor & Service'),
      ),
      findsOneWidget,
    );
    // The Bill-out footer is pinned OUTSIDE any scrollable.
    expect(find.text('Bill out'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('Bill out'),
      ),
      findsNothing,
    );
    // The parts list no longer scrolls on its own.
    final partsList = tester.widget<ListView>(find.byType(ListView).first);
    expect(partsList.physics, isA<NeverScrollableScrollPhysics>());
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/widgets/draft_edit_screen_structure_test.dart`
Expected: FAIL — `'Parts'` is not inside a `SingleChildScrollView` (current layout has no outer scroll view; the items `ListView` is the only scroll region).

- [ ] **Step 3: Restructure _buildDraftContent**

In `lib/presentation/mobile/screens/drafts/draft_edit_screen.dart`, replace the `body:` of `_buildDraftContent`'s `Scaffold` so the Column becomes `[Expanded(SingleChildScrollView(...)), footer]`. The header Builder block, Parts-header Padding block, and `_buildLaborSection(draft)` move INSIDE the scroll view unchanged; only the items list changes shape:

```dart
      body: Column(
        children: [
          // ONE scroll region — header, parts and labor scroll together
          // (POS cart pattern); the summary + Bill out stay pinned below.
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                children: [
                  // Draft info header  ← existing Builder(...) block, verbatim
                  // Parts header + Add action  ← existing Padding(...) block, verbatim

                  // Items list — inline, not separately scrollable.
                  draft.items.isEmpty
                      ? SizedBox(height: 220, child: _buildEmptyItems())
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: draft.items.length,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemBuilder: (context, index) {
                            return _buildDraftItem(draft, draft.items[index]);
                          },
                        ),

                  // Labor & Service (mechanic + labor lines).
                  _buildLaborSection(draft),
                ],
              ),
            ),
          ),

          // Sticky footer: summary + Bill out.
          _buildSummarySection(draft),
        ],
      ),
```

(The empty state gets a fixed 220px box because `Center` has no height inside a scroll view. The labor section's own `ConstrainedBox(maxHeight: 260)` + `shrinkWrap` ListView is already scroll-safe inside the outer scroll view — same as POS.)

In `_buildSummarySection`, replace the container decoration (border-top → pinned-footer shadow, matching POS's `_buildActionButtons`):

```dart
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        boxShadow: AppShadows.pinnedFooter(dark: isDark),
      ),
```

(the `hairline` local in that method becomes unused only if the inner Total row's border also used it — it doesn't; the Total row uses its own colors. Remove the `hairline` local if the analyzer flags it.)

- [ ] **Step 4: Run structure + existing draft-edit tests**

Run: `flutter test test/presentation/widgets/draft_edit_screen_structure_test.dart test/presentation/widgets/draft_edit_screen_items_test.dart test/presentation/widgets/draft_edit_screen_header_test.dart test/presentation/widgets/draft_edit_screen_addparts_test.dart test/presentation/widgets/draft_edit_screen_labor_test.dart`
Expected: PASS. If an existing test fails on a tap target now off-screen, insert `await tester.ensureVisible(finder);` before the tap — do not change assertions.

- [ ] **Step 5: Write the failing unfocus test**

Create `test/presentation/widgets/product_search_field_unfocus_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/product_search_field.dart';

void main() {
  testWidgets('drops focus when the software keyboard collapses',
      (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ProductSearchField(
              controller: controller,
              focusNode: focusNode,
              onProductSelected: (_) {},
              onBarcodeScanned: (_) {},
            ),
          ),
        ),
      ),
    );

    // Focus the field, then simulate the keyboard opening…
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    // …then closing (system back / swipe-down). Focus must drop so the
    // cursor and any results overlay dismiss with the keyboard.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
  });
}
```

**Assumption/latitude:** setting `tester.view.viewInsets` on `TestFlutterView` dispatches `onMetricsChanged`, which reaches `WidgetsBindingObserver.didChangeMetrics`. If the second phase of the test fails because the observer never fires, add `tester.binding.handleMetricsChanged();` immediately after each `tester.view.viewInsets = …;` line. If it is still not simulatable in this Flutter version, DELETE this test file, keep the implementation, and record "unfocus-on-keyboard-dismiss: manual smoke on device" in the final task's notes — the spec explicitly allows documenting manual smoke for this behavior.

- [ ] **Step 6: Run to verify it fails**

Run: `flutter test test/presentation/widgets/product_search_field_unfocus_test.dart`
Expected: FAIL on the final assertion — `focusNode.hasFocus` is still true (no observer yet).

- [ ] **Step 7: Implement the unfocus observer**

In `lib/presentation/mobile/widgets/pos/product_search_field.dart`:

a) Change the state class declaration and add the inset tracking:

```dart
class _ProductSearchFieldState extends ConsumerState<ProductSearchField>
    with WidgetsBindingObserver {
```

b) Add a field next to `_debouncedQuery`:

```dart
  double _lastBottomInset = 0;
```

c) Register/unregister the observer (first line of `initState` after `super.initState();`, first line of `dispose`):

```dart
    WidgetsBinding.instance.addObserver(this);
```

```dart
    WidgetsBinding.instance.removeObserver(this);
```

d) Add the metrics hook to the state class:

```dart
  /// Keyboard-dismiss → unfocus: when the software keyboard collapses to
  /// ~0 while this field still holds focus (system back / swipe-down),
  /// drop the focus so the cursor and any results overlay dismiss with it.
  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final view = View.of(context);
    final bottomInset = view.viewInsets.bottom / view.devicePixelRatio;
    final collapsed = _lastBottomInset > 1 && bottomInset <= 1;
    _lastBottomInset = bottomInset;
    if (collapsed && widget.focusNode.hasFocus) {
      widget.focusNode.unfocus();
    }
  }
```

- [ ] **Step 8: Run the field tests**

Run: `flutter test test/presentation/widgets/product_search_field_unfocus_test.dart test/presentation/widgets/product_search_field_inline_test.dart && flutter analyze`
Expected: PASS, analyze clean. (Apply the Step 5 latitude if the metrics simulation doesn't fire.)

- [ ] **Step 9: Commit**

```bash
git add lib/presentation/mobile/screens/drafts/draft_edit_screen.dart lib/presentation/mobile/widgets/pos/product_search_field.dart test/presentation/widgets/draft_edit_screen_structure_test.dart test/presentation/widgets/product_search_field_unfocus_test.dart
git commit -m "$(cat <<'EOF'
feat(mobile): draft-edit single scroll + sticky Bill-out footer; unfocus on keyboard dismiss

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: Dashboard unpin (date header + QuickActions into the scroll) + full-suite verification

**Files:**
- Modify: `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart` (`build` body ~line 184-199, `_buildScrollableSections` ~line 273-341; delete `_buildPinnedHeader` ~line 237-271)
- Test: `test/presentation/widgets/dashboard_screen_test.dart` (new — no dashboard structure test exists)

**Interfaces:**
- Consumes: `QuickActions({required VoidCallback onNewSale, VoidCallback? onReceiving, VoidCallback? onInventory, VoidCallback? onReorder, VoidCallback? onExpenses, VoidCallback? onReports, VoidCallback? onCloseDay})`; providers `currentUserProvider` (StreamProvider), `todaysSalesProvider` (StreamProvider), `todaysSalesSummaryProvider` + `monthToDateSummaryProvider` (FutureProviders) for the test harness.
- Produces: nothing new — `_buildPinnedHeader` and its `AppShadows.pinnedHeader` container are gone; body = `SafeArea > RefreshIndicator > CustomScrollView` directly.

- [ ] **Step 1: Write the failing structure test**

Create `test/presentation/widgets/dashboard_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/dashboard/dashboard_screen.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/quick_actions.dart';

void main() {
  // Cashier: renders the full dashboard without the admin-only
  // VoidRequestsBell (avoids overriding the void-request providers).
  UserEntity cashier() => UserEntity(
        id: 'u-1',
        email: 'c@x.com',
        displayName: 'Cash Ier',
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  const emptySummary = SalesSummary(
    totalSalesCount: 0,
    voidedSalesCount: 0,
    grossAmount: 0,
    totalDiscounts: 0,
    netAmount: 0,
    totalCost: 0,
    totalProfit: 0,
    byPaymentMethod: {},
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(cashier())),
          todaysSalesProvider
              .overrideWith((ref) => Stream.value(const <SaleEntity>[])),
          todaysSalesSummaryProvider.overrideWith((ref) async => emptySummary),
          monthToDateSummaryProvider.overrideWith((ref) async => emptySummary),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('date header and QuickActions scroll with the dashboard body',
      (tester) async {
    await pump(tester);

    // Both live INSIDE the CustomScrollView — not in a pinned container.
    expect(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(QuickActions),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byIcon(LucideIcons.calendar),
      ),
      findsOneWidget,
    );
    // Body is the refresh + scroll view directly.
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/presentation/widgets/dashboard_screen_test.dart`
Expected: FAIL — `QuickActions` is not a descendant of `CustomScrollView` (it sits in the pinned header Column).

- [ ] **Step 3: Unpin the header**

In `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart`:

a) Replace the `body:` of the Scaffold in `_DashboardContentState.build`:

```dart
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _handleRefresh,
          child: _buildScrollableSections(),
        ),
      ),
```

b) Delete the entire `_buildPinnedHeader()` method.

c) In `_buildScrollableSections`, prepend the date header + QuickActions as the first sliver-list children (everything after stays byte-identical):

```dart
  Widget _buildScrollableSections() {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Date strip + role-based QuickActions — scroll with the page
              // (unpinned; only the AppBar stays fixed).
              _buildDateHeader(),
              const SizedBox(height: 16),
              QuickActions(
                onNewSale: () => context.go(RoutePaths.pos),
                onReceiving: _canAccessReceiving
                    ? () => context.go(RoutePaths.receiving)
                    : null,
                onInventory: _canViewInventory
                    ? () => context.go(RoutePaths.inventory)
                    : null,
                onReorder: _canAccessReceiving
                    ? () => context.go(RoutePaths.purchaseOrders)
                    : null,
                onExpenses: _canViewExpenses
                    ? () => context.go(RoutePaths.expenses)
                    : null,
                onReports: _canViewReports
                    ? () => context.go(RoutePaths.reports)
                    : null,
                onCloseDay: _canCloseDay
                    ? () => context.push(RoutePaths.endOfDay)
                    : null,
              ),
              const SizedBox(height: 24),

              // Sales summary section - all roles can see today's sales
              _buildSectionHeader('Today\'s Sales'),
              // …(everything from here down is unchanged)…
```

(Spacing note: the old pinned container contributed 16px bottom padding + the sliver's 12px top = 28px before "Today's Sales"; the new `SizedBox(height: 24)` matches the dashboard's standard 24px section gap — a deliberate, tiny normalization.)

- [ ] **Step 4: Run the test + analyze**

Run: `flutter test test/presentation/widgets/dashboard_screen_test.dart && flutter analyze`
Expected: PASS, analyze clean (remove any now-unused imports, e.g. nothing is expected to break — `AppShadows` may still be used by `_buildAvatarTile`'s `newSalePill`).

- [ ] **Step 5: Full-suite verification**

Run: `flutter analyze && flutter test`
Expected: analyze clean; ALL tests pass (baseline was green before this batch; every earlier task left its slice green).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/mobile/screens/dashboard/dashboard_screen.dart test/presentation/widgets/dashboard_screen_test.dart
git commit -m "$(cat <<'EOF'
feat(mobile): unpin dashboard date header + QuickActions into the scroll

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Finish the branch**

1. Request a whole-branch code review (`/code-review` over `git diff main...feat/mobile-parity-batch`) and fix findings before merging.
2. Use the `superpowers:finishing-a-development-branch` skill to merge `feat/mobile-parity-batch` (or open a PR, per the user's choice). Do not push without asking.
3. APK note: this batch is mobile-only — NO web deploy, NO firestore.rules deploy, nothing to publish. The changes ride the next `flutter build apk --release` + manual `adb install` on the shop A71 (per the standing mobile release process). Remind the user that device smoke for this batch (labor rows on both screens, JO number in drafts list, dashboard top-selling + unpinned header, EOD plate amounts + Add Expense placement, draft-edit scroll/footer, keyboard-dismiss unfocus — plus any test that was downgraded to manual smoke in Task 8) happens on that install.

---

## Self-review notes (already applied)

- Spec §1 → Tasks 1-2; §2 → Task 3; §3 → Tasks 4-5; §4 → Task 6; §5 → Tasks 7a-7b; §6 → Task 8; §7 → Task 9. Out-of-scope items: no task touches web_admin, firestore.rules, CSV, or the labor/cart/draft models.
- `CloseDayUseCase` loses its scalar plate params (breaking) — the only production caller is the EOD screen, shimmed in 7a and rewired in 7b; the only test caller is updated in 7a.
- POS add-labor dialog title changes `'Add Labor / Service'` → shared `'Add Labor'`; POS row loses swipe-to-dismiss — both deliberate ("Job Order style wins").
- `RankRow.subtitle` = SKU on both surfaces (dashboard duplicate-"N sold" avoided); latitude noted in Task 4.
- Keyboard-unfocus test carries explicit fallback latitude (Task 8 Step 5).
