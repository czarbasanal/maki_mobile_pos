# Expenses Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship backlog items #12 (skeletons on all expense loading states), #14 (expense history rows clickable), and #15 (optional receipt image on expenses).

**Architecture:** Three additive slices on one branch. Skeleton primitives (`FieldSkeleton`, `FormSkeleton`) join the existing `app_skeleton.dart`; history tap-through mirrors the dashboard's admin gate; the receipt image adds `receiptImageUrl` to entity/model, a Storage service at `expenses/{id}/receipt.jpg`, and an upload-before-create flow with a pre-allocated doc id (Firestore rules: cashiers create but can't update).

**Tech Stack:** Flutter + Riverpod + Firestore/Storage; `image_picker`, `flutter_image_compress`, `fake_cloud_firestore` (all already in pubspec).

**Spec:** `docs/superpowers/specs/2026-07-04-expenses-polish-design.md`

## Global Constraints

- Work on branch `feat/expenses-polish` (branch from `main` before the first commit).
- Every task: `flutter analyze` clean and the task's tests green before its commit.
- Existing 1103 tests must stay green (run full `flutter test` at the end of Tasks 3 and 7).
- Lucide icons only, stroke defaults; currency `₱1,430.00` style; Figtree is the app default font — no styling forks.
- `storage.rules` is EDITED in Task 4 but NOT deployed — deployment is a separate user-confirmed step after implementation.
- Do not push; merging/pushing is decided by the user at the end.

---

### Task 1: Skeleton primitives + wire expense loading states (#12)

**Files:**
- Modify: `lib/presentation/shared/widgets/common/app_skeleton.dart` (append after `ListSkeleton`)
- Modify: `lib/presentation/shared/widgets/dashboard/summary_card.dart`
- Modify: `lib/presentation/mobile/screens/expenses/expense_form_screen.dart:132-133` (loading body), `:456` (`_ExpenseCategoryDropdown` loading)
- Modify: `lib/presentation/mobile/screens/expenses/expenses_screen.dart:348-352` (`_TotalCard`), `:422` (`_CategoryFilterDropdown` loading)
- Modify: `lib/presentation/mobile/screens/expenses/expense_history_screen.dart:232` (`_HistoryCategoryFilter` loading)
- Test: `test/presentation/shared/widgets/common/app_skeleton_test.dart` (create)

**Interfaces:**
- Produces: `FieldSkeleton({double height = 56})`, `FormSkeleton({int fields = 6})` (exported via the existing `common_widgets.dart` barrel which already exports `app_skeleton.dart`), and `SummaryCard(loading: bool)` (default `false`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/presentation/shared/widgets/common/app_skeleton_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/summary_card.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

void main() {
  testWidgets('FieldSkeleton renders a single field-height SkeletonBox',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FieldSkeleton()),
    ));
    final box = tester.widget<SkeletonBox>(find.byType(SkeletonBox));
    expect(box.height, 56);
  });

  testWidgets('FormSkeleton renders N fields plus a button bar',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FormSkeleton(fields: 4)),
    ));
    expect(find.byType(FieldSkeleton), findsNWidgets(5)); // 4 fields + button
  });

  testWidgets('SummaryCard loading shows a SkeletonBox instead of the value',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SummaryCard(
          title: 'Today',
          value: '₱100.00',
          icon: LucideIcons.sun,
          compact: true,
          loading: true,
        ),
      ),
    ));
    expect(find.byType(SkeletonBox), findsOneWidget);
    expect(find.text('₱100.00'), findsNothing);
    expect(find.text('Today'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/presentation/shared/widgets/common/app_skeleton_test.dart`
Expected: FAIL — `FieldSkeleton` / `FormSkeleton` undefined, `loading` not a parameter.

- [ ] **Step 3: Implement the primitives**

Append to `lib/presentation/shared/widgets/common/app_skeleton.dart`:

```dart
/// A single field-shaped skeleton — placeholder for a text field / dropdown
/// while its data source loads. Replaces bare LinearProgressIndicators.
class FieldSkeleton extends StatelessWidget {
  const FieldSkeleton({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: double.infinity,
      height: height,
      radius: AppRadius.field,
    );
  }
}

/// Skeleton for a form screen while its record loads: [fields] field-shaped
/// bars + a button-shaped bar, inside the standard page padding.
class FormSkeleton extends StatelessWidget {
  const FormSkeleton({super.key, this.fields = 6});

  final int fields;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (var i = 0; i < fields; i++) ...[
          const FieldSkeleton(),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.md),
        const FieldSkeleton(height: 52),
      ],
    );
  }
}
```

In `summary_card.dart`: add the field + constructor param (`this.loading = false` after `this.highlighted = false`), add `final bool loading;`, and in BOTH `_buildFullCard` and `_buildCompactCard` replace the value `Text` with:

```dart
loading
    ? const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SkeletonBox(width: 48, height: 16),
      )
    : Text(
        value,
        // keep the existing style exactly as it is in that card variant
      ),
```

(In `_buildFullCard` the value `Text` is inside a `FittedBox` — put the conditional inside the `FittedBox` child.) Add the import: `import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_skeleton.dart';`

- [ ] **Step 4: Wire the five call sites**

1. `expense_form_screen.dart` body: `_isLoading ? const FormSkeleton() : SingleChildScrollView(...)` (replaces `Center(child: CircularProgressIndicator())`).
2. `expense_form_screen.dart` `_ExpenseCategoryDropdown`: `loading: () => const FieldSkeleton(),`
3. `expenses_screen.dart` `_CategoryFilterDropdown`: `loading: () => const FieldSkeleton(),`
4. `expense_history_screen.dart` `_HistoryCategoryFilter`: `loading: () => const FieldSkeleton(),`
5. `expenses_screen.dart` `_TotalCard.build`:

```dart
final totalAsync = ref.watch(totalExpensesProvider(params));
return SummaryCard(
  title: title,
  value: totalAsync.maybeWhen(
    data: (total) => _ExpenseTotalsRow._currencyFormat.format(total),
    orElse: () => '—',
  ),
  icon: icon,
  compact: true,
  loading: totalAsync.isLoading,
);
```

- [ ] **Step 5: Run tests + analyze**

Run: `flutter test test/presentation/shared/widgets/common/app_skeleton_test.dart && flutter analyze`
Expected: PASS, no analyzer issues.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/shared/widgets/common/app_skeleton.dart lib/presentation/shared/widgets/dashboard/summary_card.dart lib/presentation/mobile/screens/expenses/ test/presentation/shared/widgets/common/app_skeleton_test.dart
git commit -m "feat(expenses): skeletons for form load, totals, and category dropdowns (#12)"
```

---

### Task 2: `receiptImageUrl` on ExpenseEntity + ExpenseModel

**Files:**
- Modify: `lib/domain/entities/expense_entity.dart`
- Modify: `lib/data/models/expense_model.dart`
- Test: `test/data/models/expense_model_receipt_image_test.dart` (create)

**Interfaces:**
- Produces: `ExpenseEntity.receiptImageUrl` (`String?`), `copyWith(receiptImageUrl:, clearReceiptImageUrl:)`; `ExpenseModel` serializes the field as Firestore key `'receiptImageUrl'` in `toMap`, `toCreateMap`, `toUpdateMap`.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/models/expense_model_receipt_image_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  ExpenseEntity entity({String? receiptImageUrl}) => ExpenseEntity(
        id: 'e-1',
        description: 'Diesel',
        amount: 500,
        category: 'Fuel',
        date: DateTime(2026, 7, 4),
        createdAt: DateTime(2026, 7, 4),
        createdBy: 'u-1',
        createdByName: 'Czar',
        receiptImageUrl: receiptImageUrl,
      );

  group('ExpenseEntity.receiptImageUrl', () {
    test('copyWith sets and clears the url', () {
      final withUrl = entity().copyWith(receiptImageUrl: 'https://x/r.jpg');
      expect(withUrl.receiptImageUrl, 'https://x/r.jpg');
      expect(withUrl.copyWith(clearReceiptImageUrl: true).receiptImageUrl,
          isNull);
      // copyWith without the arg preserves the existing value
      expect(withUrl.copyWith(description: 'x').receiptImageUrl,
          'https://x/r.jpg');
    });

    test('participates in equality', () {
      expect(entity(receiptImageUrl: 'a') == entity(receiptImageUrl: 'b'),
          isFalse);
    });
  });

  group('ExpenseModel.receiptImageUrl', () {
    test('round-trips through entity and maps', () {
      final model =
          ExpenseModel.fromEntity(entity(receiptImageUrl: 'https://x/r.jpg'));
      expect(model.toEntity().receiptImageUrl, 'https://x/r.jpg');
      expect(model.toMap()['receiptImageUrl'], 'https://x/r.jpg');
      expect(model.toCreateMap()['receiptImageUrl'], 'https://x/r.jpg');
      expect(model.toUpdateMap()['receiptImageUrl'], 'https://x/r.jpg');
    });

    test('reads from a Firestore map and defaults to null', () {
      final withUrl = ExpenseModel.fromMap(
          {'description': 'd', 'receiptImageUrl': 'https://x/r.jpg'}, 'e-1');
      expect(withUrl.receiptImageUrl, 'https://x/r.jpg');
      final without = ExpenseModel.fromMap({'description': 'd'}, 'e-1');
      expect(without.receiptImageUrl, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/models/expense_model_receipt_image_test.dart`
Expected: FAIL — `receiptImageUrl` is not a defined named parameter.

- [ ] **Step 3: Implement**

`expense_entity.dart` — add after the `receiptNumber` field:

```dart
  /// Optional photo of the physical receipt (Storage download URL).
  final String? receiptImageUrl;
```

Constructor: add `this.receiptImageUrl,` after `this.receiptNumber,`. `copyWith`: add params `String? receiptImageUrl, bool clearReceiptImageUrl = false,` and the assignment `receiptImageUrl: clearReceiptImageUrl ? null : (receiptImageUrl ?? this.receiptImageUrl),`. `props`: add `receiptImageUrl` after `receiptNumber`.

`expense_model.dart` — mirror exactly: field `final String? receiptImageUrl;`, constructor param, `fromMap`: `receiptImageUrl: map['receiptImageUrl'] as String?,`, `fromEntity`: `receiptImageUrl: entity.receiptImageUrl,`, `'receiptImageUrl': receiptImageUrl,` in `toMap`, `toCreateMap`, and `toUpdateMap`, and `receiptImageUrl: receiptImageUrl,` in `toEntity`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/models/ test/domain/ && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/expense_entity.dart lib/data/models/expense_model.dart test/data/models/expense_model_receipt_image_test.dart
git commit -m "feat(expenses): receiptImageUrl on entity + model"
```

---

### Task 3: History rows clickable + paperclip indicator (#14)

**Files:**
- Modify: `lib/presentation/mobile/widgets/expenses/expense_row.dart`
- Modify: `lib/presentation/mobile/screens/expenses/expense_history_screen.dart` (`_buildBody` row builder + role lookup)
- Modify: `lib/presentation/mobile/screens/expenses/expenses_screen.dart:184` (`_buildExpenseCard` — pass `hasReceipt`)
- Test: `test/presentation/mobile/screens/expenses/expense_history_screen_test.dart` (create; also create the directory)

**Interfaces:**
- Consumes: `ExpenseEntity.receiptImageUrl` (Task 2).
- Produces: `ExpenseRow(hasReceipt: bool = false)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/mobile/screens/expenses/expense_history_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/expenses/expense_history_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/expenses/expense_row.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

void main() {
  UserEntity user(UserRole role) => UserEntity(
        id: 'u-1',
        email: 'u@x.com',
        displayName: 'U',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 6, 1),
      );

  ExpenseEntity expense({String? receiptImageUrl}) => ExpenseEntity(
        id: 'e-1',
        description: 'Diesel',
        amount: 500,
        category: 'Fuel',
        date: DateTime(2026, 7, 4),
        createdAt: DateTime(2026, 7, 4),
        createdBy: 'u-1',
        createdByName: 'U',
        receiptImageUrl: receiptImageUrl,
      );

  Future<void> pump(
    WidgetTester tester, {
    required UserRole role,
    String? receiptImageUrl,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(user(role))),
        expensesProvider.overrideWith(
            (ref) => Stream.value([expense(receiptImageUrl: receiptImageUrl)])),
        activeCategoriesProvider(CategoryKind.expense)
            .overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: ExpenseHistoryScreen()),
    ));
    await tester.pump(); // streams emit
    await tester.pump();
  }

  testWidgets('admin rows are tappable', (tester) async {
    await pump(tester, role: UserRole.admin);
    final row = tester.widget<ExpenseRow>(find.byType(ExpenseRow));
    expect(row.onTap, isNotNull);
  });

  testWidgets('cashier rows are not tappable', (tester) async {
    await pump(tester, role: UserRole.cashier);
    final row = tester.widget<ExpenseRow>(find.byType(ExpenseRow));
    expect(row.onTap, isNull);
  });

  testWidgets('paperclip shows only when the expense has a receipt',
      (tester) async {
    await pump(tester, role: UserRole.admin, receiptImageUrl: 'https://x/r.jpg');
    expect(find.byIcon(LucideIcons.paperclip), findsOneWidget);

    await pump(tester, role: UserRole.admin);
    expect(find.byIcon(LucideIcons.paperclip), findsNothing);
  });
}
```

Note: if `activeCategoriesProvider` is not a family `StreamProvider`, check its
declaration in `lib/presentation/providers/` and override accordingly — the test
just needs it to emit an empty list. If the screen's `context.push` requires a
router, none is exercised here (we only inspect `onTap != null`).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/screens/expenses/expense_history_screen_test.dart`
Expected: FAIL — `ExpenseRow` has no `onTap` in history (widget lookup finds `onTap == null` in the admin case) and no `hasReceipt`/paperclip.

- [ ] **Step 3: Implement**

`expense_row.dart` — add the param:

```dart
    this.hasReceipt = false,
```
```dart
  /// Shows a small paperclip when the expense has a receipt photo attached.
  final bool hasReceipt;
```

In the `Row` children, immediately before `const SizedBox(width: 10)` + amount `Text`, insert:

```dart
          if (hasReceipt) ...[
            const SizedBox(width: 6),
            Icon(LucideIcons.paperclip, size: 14, color: muted),
          ],
```

`expense_history_screen.dart` — in `build`, before the Scaffold:

```dart
    final currentUser = ref.watch(currentUserProvider).value;
    final canEdit = RolePermissions.hasPermission(
        currentUser?.role ?? UserRole.cashier, Permission.editExpense);
```

(add imports `package:maki_mobile_pos/core/constants/constants.dart` and `package:maki_mobile_pos/core/enums/enums.dart` if not present; pass `canEdit` into `_buildBody`). In the row builder:

```dart
                  child: ExpenseRow(
                    description: e.description,
                    subtitle: '${_dateFormat.format(e.date)} • ${e.category}',
                    amount: e.amount,
                    hasReceipt: e.receiptImageUrl != null,
                    onTap: canEdit
                        ? () => context
                            .push('${RoutePaths.expenses}/edit/${e.id}')
                        : null,
                  ),
```

(`go_router` import for `context.push` if missing: `package:go_router/go_router.dart`.)

`expenses_screen.dart` `_buildExpenseCard` — add `hasReceipt: expense.receiptImageUrl != null,` to its `ExpenseRow`.

- [ ] **Step 4: Run tests + full suite + analyze**

Run: `flutter test test/presentation/mobile/screens/expenses/ && flutter analyze && flutter test`
Expected: new tests PASS, analyzer clean, full suite green.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/expenses/expense_row.dart lib/presentation/mobile/screens/expenses/ test/presentation/mobile/screens/expenses/
git commit -m "feat(expenses): history rows tap through to edit for admins + receipt paperclip (#14)"
```

---

### Task 4: Receipt storage service + storage.rules

**Files:**
- Create: `lib/services/expense_receipt_storage_service.dart`
- Modify: `storage.rules` (add the expenses match block — DO NOT deploy)

**Interfaces:**
- Produces: `ExpenseReceiptStorageService.upload({required String expenseId, required Uint8List bytes}) → Future<String>` (download URL), `.delete({required String expenseId})`, and `expenseReceiptStorageServiceProvider`.

- [ ] **Step 1: Implement the service (thin wrapper — mirror of the tested-by-use product service; no unit test)**

```dart
// lib/services/expense_receipt_storage_service.dart
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:maki_mobile_pos/services/firebase_service.dart';

/// Thin wrapper around [FirebaseStorage] for expense receipt photos.
///
/// Storage layout: `expenses/{expenseId}/receipt.jpg` (single receipt per
/// expense, overwritten on re-upload). The download URL is what we persist
/// on `ExpenseEntity.receiptImageUrl`.
class ExpenseReceiptStorageService {
  ExpenseReceiptStorageService(this._storage);

  final FirebaseStorage _storage;

  Reference _ref(String expenseId) =>
      _storage.ref().child('expenses').child(expenseId).child('receipt.jpg');

  /// Uploads [bytes] (already compressed JPEG) and returns the public
  /// download URL. Caller persists the URL onto the expense document.
  Future<String> upload({
    required String expenseId,
    required Uint8List bytes,
  }) async {
    final ref = _ref(expenseId);
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  /// Deletes the expense's receipt (if any). No-ops on `object-not-found`.
  Future<void> delete({required String expenseId}) async {
    try {
      await _ref(expenseId).delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }
}

final expenseReceiptStorageServiceProvider =
    Provider<ExpenseReceiptStorageService>((ref) {
  return ExpenseReceiptStorageService(ref.watch(firebaseStorageProvider));
});
```

- [ ] **Step 2: Add the storage.rules block**

In `storage.rules`, after the products match block and BEFORE the default-deny block:

```
    // Expense receipt photos — `expenses/{expenseId}/receipt.jpg` (one
    // receipt per expense, overwritten on re-upload). Same posture as
    // products: any signed-in user reads/writes; role is enforced at the
    // application layer (anyone may create an expense; only admin edits).
    match /expenses/{expenseId}/{file=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && (
                     request.resource == null
                     || (
                       request.resource.size < 2 * 1024 * 1024
                       && request.resource.contentType.matches('image/.*')
                     )
                   );
    }
```

- [ ] **Step 3: Analyze + commit**

Run: `flutter analyze`
Expected: clean.

```bash
git add lib/services/expense_receipt_storage_service.dart storage.rules
git commit -m "feat(expenses): receipt storage service + storage.rules block (deploy deferred)"
```

---

### Task 5: Repo — `newExpenseId()` + preset-id create

**Files:**
- Modify: `lib/domain/repositories/expense_repository.dart`
- Modify: `lib/data/repositories/expense_repository_impl.dart:22-37`
- Test: `test/data/repositories/expense_repository_create_id_test.dart` (create)

**Interfaces:**
- Produces: `ExpenseRepository.newExpenseId() → String`; `createExpense` writes to `doc(expense.id)` when `expense.id` is non-empty (else keeps the `add()` path).

- [ ] **Step 1: Write the failing test**

```dart
// test/data/repositories/expense_repository_create_id_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/expense_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  ExpenseEntity expense({String id = ''}) => ExpenseEntity(
        id: id,
        description: 'Diesel',
        amount: 500,
        category: 'Fuel',
        date: DateTime(2026, 7, 4),
        createdAt: DateTime(2026, 7, 4),
        createdBy: 'u-1',
        createdByName: 'U',
        receiptImageUrl: id.isEmpty ? null : 'https://x/r.jpg',
      );

  test('newExpenseId returns a non-empty unique id', () {
    final repo = ExpenseRepositoryImpl(firestore: FakeFirebaseFirestore());
    final a = repo.newExpenseId();
    final b = repo.newExpenseId();
    expect(a, isNotEmpty);
    expect(a, isNot(b));
  });

  test('createExpense honors a preset id (set, not add)', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ExpenseRepositoryImpl(firestore: firestore);
    final id = repo.newExpenseId();

    final created = await repo.createExpense(expense(id: id));

    expect(created.id, id);
    final doc = await firestore.collection('expenses').doc(id).get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['receiptImageUrl'], 'https://x/r.jpg');
  });

  test('createExpense without id still auto-generates (add path)', () async {
    final firestore = FakeFirebaseFirestore();
    final repo = ExpenseRepositoryImpl(firestore: firestore);

    final created = await repo.createExpense(expense());

    expect(created.id, isNotEmpty);
  });
}
```

Note: if `FirestoreCollections.expenses != 'expenses'`, use that constant in the
test's collection lookup.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repositories/expense_repository_create_id_test.dart`
Expected: FAIL — `newExpenseId` undefined; preset-id doc does not exist (add() generated a different id).

- [ ] **Step 3: Implement**

`expense_repository.dart` — add to the interface (above `createExpense`):

```dart
  /// Pre-allocates a document id, letting callers upload ancillary files
  /// (receipt photo) BEFORE creating the document — required because
  /// non-admin roles can create but not update expenses.
  String newExpenseId();
```

`expense_repository_impl.dart`:

```dart
  @override
  String newExpenseId() => _expensesRef.doc().id;

  @override
  Future<ExpenseEntity> createExpense(ExpenseEntity expense) async {
    try {
      debugPrint('ExpenseRepository: Creating expense');
      final model = ExpenseModel.fromEntity(expense);
      // A preset id means ancillary files (receipt photo) were uploaded
      // under it already — write with set() so the doc lands on that id.
      final DocumentReference docRef;
      if (expense.id.isEmpty) {
        docRef = await _expensesRef.add(model.toCreateMap());
      } else {
        docRef = _expensesRef.doc(expense.id);
        await docRef.set(model.toCreateMap());
      }
      final doc = await docRef.get();
      return ExpenseModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create expense: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/repositories/expense_repository_create_id_test.dart && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/expense_repository.dart lib/data/repositories/expense_repository_impl.dart test/data/repositories/expense_repository_create_id_test.dart
git commit -m "feat(expenses): newExpenseId + preset-id create (upload-before-create support)"
```

---

### Task 6: `ReceiptImageField` widget + full-screen viewer

**Files:**
- Create: `lib/presentation/mobile/widgets/expenses/receipt_image_field.dart`
- Test: `test/presentation/mobile/widgets/expenses/receipt_image_field_test.dart` (create; also create the directory)

**Interfaces:**
- Consumes: nothing project-specific beyond theme/`app_bottom_sheet`.
- Produces:
```dart
ReceiptImageField({
  required String? existingUrl,
  required Uint8List? pendingBytes,
  required void Function(Uint8List? bytes, {required bool removed}) onChanged,
  bool enabled = true,
})
```
State semantics identical to `ProductImageUploader` (pendingBytes → local preview; existingUrl → network; both null → empty tile; remove = `onChanged(null, removed: true)`).

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/mobile/widgets/expenses/receipt_image_field_test.dart
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/expenses/receipt_image_field.dart';

// 1x1 transparent PNG — enough for Image.memory to decode in tests.
final kTinyPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String? existingUrl,
    Uint8List? pendingBytes,
    void Function(Uint8List?, {required bool removed})? onChanged,
  }) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReceiptImageField(
          existingUrl: existingUrl,
          pendingBytes: pendingBytes,
          onChanged: onChanged ?? (_, {required removed}) {},
        ),
      ),
    ));
  }

  testWidgets('empty state shows the add-photo tile', (tester) async {
    await pump(tester);
    expect(find.text('Add receipt photo'), findsOneWidget);
    expect(find.byIcon(LucideIcons.camera), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
  });

  testWidgets('pending bytes show a local preview with Replace/Remove',
      (tester) async {
    await pump(tester, pendingBytes: kTinyPng);
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('remove fires onChanged(null, removed: true)', (tester) async {
    Uint8List? gotBytes = kTinyPng;
    bool? gotRemoved;
    await pump(tester, pendingBytes: kTinyPng,
        onChanged: (bytes, {required removed}) {
      gotBytes = bytes;
      gotRemoved = removed;
    });
    await tester.tap(find.text('Remove'));
    expect(gotBytes, isNull);
    expect(gotRemoved, isTrue);
  });

  testWidgets('tapping the preview opens the full-screen viewer',
      (tester) async {
    await pump(tester, pendingBytes: kTinyPng);
    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/widgets/expenses/receipt_image_field_test.dart`
Expected: FAIL — `receipt_image_field.dart` does not exist.

- [ ] **Step 3: Implement the widget**

```dart
// lib/presentation/mobile/widgets/expenses/receipt_image_field.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_bottom_sheet.dart';

/// Optional receipt-photo control for the expense form. Shows an add tile
/// when empty, or a tappable preview (tap → full-screen zoom) with
/// Replace / Remove actions.
///
/// Display + picker only, like ProductImageUploader: hands the parent
/// compressed JPEG bytes via [onChanged]; the parent uploads at save time.
/// No crop step — receipts are documents, original aspect is kept. Max edge
/// 1600px so receipt text stays legible (still well under the 2MB rule).
class ReceiptImageField extends StatelessWidget {
  const ReceiptImageField({
    super.key,
    required this.existingUrl,
    required this.pendingBytes,
    required this.onChanged,
    this.enabled = true,
  });

  final String? existingUrl;
  final Uint8List? pendingBytes;
  final void Function(Uint8List? bytes, {required bool removed}) onChanged;
  final bool enabled;

  static const _maxEdge = 1600;
  static const _jpegQuality = 80;

  Future<void> _pick(BuildContext context) async {
    final source = await showAppActionSheet<ImageSource>(
      context,
      icon: LucideIcons.receipt,
      title: 'Receipt photo',
      actions: const [
        AppSheetAction(
          icon: LucideIcons.camera,
          label: 'Take photo',
          value: ImageSource.camera,
        ),
        AppSheetAction(
          icon: LucideIcons.image,
          label: 'Choose from gallery',
          value: ImageSource.gallery,
        ),
      ],
    );
    if (!context.mounted || source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: _maxEdge.toDouble(),
      maxHeight: _maxEdge.toDouble(),
      imageQuality: 90,
    );
    if (picked == null || !context.mounted) return;

    Uint8List bytes;
    try {
      bytes = await File(picked.path).readAsBytes();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read image. Please try again.'),
          ),
        );
      }
      return;
    }

    Uint8List? compressed;
    try {
      compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _maxEdge,
        minHeight: _maxEdge,
        quality: _jpegQuality,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      // Non-fatal: fall through to the raw picked bytes.
    }

    onChanged(compressed ?? bytes, removed: false);
  }

  void _openViewer(BuildContext context) {
    final image = pendingBytes != null
        ? Image.memory(pendingBytes!, fit: BoxFit.contain)
        : Image.network(existingUrl!, fit: BoxFit.contain);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(LucideIcons.x),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Receipt'),
          ),
          body: Center(
            child: InteractiveViewer(maxScale: 5, child: image),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final hasPreview = pendingBytes != null || existingUrl != null;

    if (!hasPreview) {
      return InkWell(
        onTap: enabled ? () => _pick(context) : null,
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: Container(
          width: double.infinity,
          height: 96,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.darkSurfaceMuted
                : AppColors.lightSurfaceMuted,
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.camera, color: muted, size: 24),
              const SizedBox(height: 6),
              Text(
                'Add receipt photo',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      );
    }

    final preview = pendingBytes != null
        ? Image.memory(pendingBytes!, fit: BoxFit.contain)
        : Image.network(
            existingUrl!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(LucideIcons.imageOff, color: muted, size: 32),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _openViewer(context),
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? AppColors.darkSurfaceMuted
                  : AppColors.lightSurfaceMuted,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            clipBehavior: Clip.antiAlias,
            child: preview,
          ),
        ),
        if (enabled)
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _pick(context),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: const Text('Replace'),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => onChanged(null, removed: true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(LucideIcons.trash2, size: 14),
                label: const Text('Remove'),
              ),
            ],
          ),
      ],
    );
  }
}
```

Note: if `LucideIcons.receipt` or `LucideIcons.imageOff` don't exist in this Lucide
version, use `LucideIcons.fileText` / `LucideIcons.image` respectively — check with
the analyzer.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/presentation/mobile/widgets/expenses/receipt_image_field_test.dart && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/expenses/receipt_image_field.dart test/presentation/mobile/widgets/expenses/
git commit -m "feat(expenses): ReceiptImageField — camera/gallery pick, preview, zoom viewer"
```

---

### Task 7: Form integration — upload-before-create, edit replace/remove, delete cleanup

**Files:**
- Modify: `lib/presentation/mobile/screens/expenses/expense_form_screen.dart`
- Test: extend `test/presentation/mobile/screens/expenses/` only if a focused test is practical; the flows here are Firebase-coupled (Storage + auth), so the verified contract is: repo preset-id create (Task 5 tests) + widget states (Task 6 tests) + full-suite regression. Manual device smoke covers the camera path.

**Interfaces:**
- Consumes: `ReceiptImageField` (Task 6), `expenseReceiptStorageServiceProvider` (Task 4), `expenseRepositoryProvider.newExpenseId()` (Task 5), `ExpenseEntity.receiptImageUrl` + `clearReceiptImageUrl` (Task 2).

- [ ] **Step 1: Add form state + dirty-signature**

In `_ExpenseFormScreenState`:

```dart
  Uint8List? _pendingReceiptBytes;
  bool _receiptMarkedForRemoval = false;
  String? _existingReceiptUrl;
```

(`import 'dart:typed_data';` and the `ReceiptImageField` + repo/service imports.)

Extend `_sig()` — add to the joined list:

```dart
        (_pendingReceiptBytes != null || _receiptMarkedForRemoval).toString(),
```

In `_loadExpense()` after `_selectedDate = expense.date;`:

```dart
      _existingReceiptUrl = expense.receiptImageUrl;
```

- [ ] **Step 2: Insert the field into the form UI**

Between the Notes field's trailing `const SizedBox(height: 16),` and the submit-button `const SizedBox(height: 32),` (adjust the existing 32 gap to keep rhythm):

```dart
              Text(
                'Receipt (optional)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              ReceiptImageField(
                existingUrl:
                    _receiptMarkedForRemoval ? null : _existingReceiptUrl,
                pendingBytes: _pendingReceiptBytes,
                onChanged: (bytes, {required removed}) {
                  setState(() {
                    if (removed) {
                      _pendingReceiptBytes = null;
                      _receiptMarkedForRemoval = true;
                    } else {
                      _pendingReceiptBytes = bytes;
                      _receiptMarkedForRemoval = false;
                    }
                  });
                },
              ),
              const SizedBox(height: 32),
```

- [ ] **Step 3: Create flow — upload before create**

In `_handleSubmit`, replace the create branch (`else` block) with:

```dart
      } else {
        // Cashiers/staff can create but not update expenses (Firestore
        // rules), so the receipt must be uploaded BEFORE the document is
        // created — pre-allocate the id and carry the URL on the create.
        var presetId = '';
        String? receiptUrl;
        var receiptFailed = false;
        final saved = await context.runWithWaiting(
          () async {
            if (_pendingReceiptBytes != null) {
              presetId = ref.read(expenseRepositoryProvider).newExpenseId();
              try {
                receiptUrl = await ref
                    .read(expenseReceiptStorageServiceProvider)
                    .upload(expenseId: presetId, bytes: _pendingReceiptBytes!);
              } catch (_) {
                receiptFailed = true; // best-effort: save without receipt
              }
            }
            final draft = ExpenseEntity(
              id: receiptUrl != null ? presetId : '',
              description: _descriptionController.text.trim(),
              amount: amount,
              category: _selectedCategory!,
              date: _selectedDate,
              paidVia: _paidVia,
              notes: notes.isEmpty ? null : notes,
              receiptImageUrl: receiptUrl,
              createdAt: now,
              createdBy: '',
              createdByName: '',
            );
            return notifier.createExpense(expense: draft);
          },
          message: 'Saving…',
        );
        if (saved == null) throw _readOperationError();
        if (receiptFailed && mounted) {
          context.showWarningSnackBar(
              'Receipt upload failed — expense saved without receipt');
        }
      }
```

(The old `final draft = ExpenseEntity(...)` block above the `runWithWaiting`
call is subsumed — delete it.)

- [ ] **Step 4: Edit flow — replace / remove**

In `_handleSubmit`'s edit branch, replace the `updated` construction + save with:

```dart
        var receiptFailed = false;
        final saved = await context.runWithWaiting(
          () async {
            String? newUrl;
            if (_pendingReceiptBytes != null) {
              try {
                newUrl = await ref
                    .read(expenseReceiptStorageServiceProvider)
                    .upload(
                        expenseId: existing.id,
                        bytes: _pendingReceiptBytes!);
              } catch (_) {
                receiptFailed = true; // keep whatever URL was there before
              }
            }
            final clearReceipt =
                _receiptMarkedForRemoval && _pendingReceiptBytes == null;
            final updated = existing.copyWith(
              description: _descriptionController.text.trim(),
              amount: amount,
              category: _selectedCategory!,
              date: _selectedDate,
              paidVia: _paidVia,
              notes: notes.isEmpty ? null : notes,
              clearNotes: notes.isEmpty,
              receiptImageUrl: newUrl,
              clearReceiptImageUrl: clearReceipt,
            );
            final result = await notifier.updateExpense(expense: updated);
            if (result != null && clearReceipt) {
              // Best-effort storage cleanup — orphans are harmless.
              try {
                await ref
                    .read(expenseReceiptStorageServiceProvider)
                    .delete(expenseId: existing.id);
              } catch (_) {}
            }
            return result;
          },
          message: 'Updating…',
        );
        if (saved == null) throw _readOperationError();
        if (receiptFailed && mounted) {
          context.showWarningSnackBar(
              'Receipt upload failed — expense saved without new receipt');
        }
```

- [ ] **Step 5: Delete flow — best-effort storage cleanup**

In `_handleDelete`, inside the `runWithWaiting` closure after a successful
delete (`ok == true`):

```dart
      final ok = await context.runWithWaiting(
        () async {
          final deleted = await ref
              .read(expenseOperationsProvider.notifier)
              .deleteExpense(widget.expenseId!);
          if (deleted) {
            try {
              await ref
                  .read(expenseReceiptStorageServiceProvider)
                  .delete(expenseId: widget.expenseId!);
            } catch (_) {} // best-effort
          }
          return deleted;
        },
        message: 'Deleting…',
      );
```

(The list-screen deletes in `expenses_screen.dart` — `_confirmAndDelete` — get the
same best-effort cleanup: after `ok == true`, fire the same try/catch `delete`.)

- [ ] **Step 6: Run analyze + full suite**

Run: `flutter analyze && flutter test`
Expected: clean; full suite green (existing expense form tests unaffected —
the new field is optional and defaults inert).

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/mobile/screens/expenses/
git commit -m "feat(expenses): optional receipt photo — upload-before-create, edit replace/remove, delete cleanup (#15)"
```

---

### Task 8: Wrap-up

- [ ] **Step 1: Full verification**

Run: `flutter analyze && flutter test`
Expected: clean, all green (existing 1103 + new tests).

- [ ] **Step 2: Report**

Do NOT deploy `storage.rules` and do NOT merge/push. Report to the user:
1. The branch is ready for review/merge.
2. `firebase deploy --only storage` is pending their confirmation (receipt
   uploads fail-soft until then).
3. Device smoke (camera pick, upload, zoom viewer, history tap-through,
   skeletons) is their gate.
