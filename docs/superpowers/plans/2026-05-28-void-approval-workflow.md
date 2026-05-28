# Void Approval Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let cashiers/staff request a void that an admin approves in-app (real-time); the actual void runs on the approving admin's device, surfaced via an admin notification bell + approval queue.

**Architecture:** New `void_requests` Firestore collection with entity/model/repository, three use cases (request/approve/reject), Riverpod providers, Firestore rules, a new `requestVoidSale` permission, and UI (sale-detail branching, request dialog, admin bell + approvals screen). The existing `VoidSaleUseCase` is reused on approval and hardened with a permission assert.

**Tech Stack:** Flutter + Riverpod, `mocktail` unit tests (`flutter test`), Firestore rules tests (`@firebase/rules-unit-testing` + emulator, Java 19).

**Spec:** `docs/superpowers/specs/2026-05-28-void-approval-workflow-design.md`

**Conventions:**
- `flutter` is at `~/flutter/bin` — prefix commands with `export PATH="$HOME/flutter/bin:$PATH"`.
- Dart tests: `flutter test <path>`. Analyze: `flutter analyze <path>`.
- Rules tests: from `tools/firestore-rules-test/`, `JAVA_HOME="$(/usr/libexec/java_home -v 19)" npm test`.
- Commit per task. **Do not deploy Firestore rules** — that is a final, separate step requiring the user's go-ahead.
- Pre-existing failing tests on `main` (cart_item_tile, product_list_tile, update_product_usecase "cashier denied") are unrelated — ignore them; just don't add new failures.

---

## File Structure

**New files**
- `lib/domain/entities/void_request_entity.dart` — entity + `VoidRequestStatus` enum
- `lib/data/models/void_request_model.dart` — Firestore (de)serialization
- `lib/domain/repositories/void_request_repository.dart` — contract
- `lib/data/repositories/void_request_repository_impl.dart` — Firestore impl
- `lib/domain/usecases/pos/request_void_sale_usecase.dart`
- `lib/domain/usecases/pos/approve_void_request_usecase.dart`
- `lib/domain/usecases/pos/reject_void_request_usecase.dart`
- `lib/presentation/providers/void_request_provider.dart`
- `lib/presentation/mobile/screens/sales/void_requests_screen.dart` — admin queue (bell target)
- `lib/presentation/mobile/widgets/pos/request_void_dialog.dart` — cashier/staff reason entry
- Tests: `test/domain/usecases/pos/request_void_sale_usecase_test.dart`, `approve_void_request_usecase_test.dart`, `reject_void_request_usecase_test.dart`

**Modified files**
- `lib/core/constants/firestore_collections.dart` — add `voidRequests`
- `lib/core/constants/role_permissions.dart` — add `requestVoidSale`; grant to cashier + staff
- `test/core/constants/role_permissions_test.dart` — assert the new permission
- `lib/domain/entities/entities.dart`, `lib/domain/repositories/repositories.dart`, `lib/data/models/models.dart`, `lib/presentation/providers/providers.dart` — barrel exports
- `lib/domain/usecases/pos/void_sale_usecase.dart` — add `actor` + `assertPermission(voidSale)`
- `lib/presentation/mobile/widgets/pos/void_sale_dialog.dart` — pass `actor` to `VoidSaleUseCase`
- `lib/presentation/mobile/screens/sales/sale_detail_screen.dart` — role-branch the void button + pending indicator
- `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart` — notification bell + badge (admin)
- `lib/config/router/route_names.dart`, `route_paths` (in same file or `app_routes.dart`), `app_routes.dart`, `route_guards.dart` — route + guard for `/void-requests`
- `firestore.rules` + `tools/firestore-rules-test/test/rules.test.js`

---

## Task 1: Collection constant + `requestVoidSale` permission

**Files:**
- Modify: `lib/core/constants/firestore_collections.dart`
- Modify: `lib/core/constants/role_permissions.dart`
- Test: `test/core/constants/role_permissions_test.dart`

- [ ] **Step 1: Add the failing permission tests**

Append inside `main()` in `test/core/constants/role_permissions_test.dart`:

```dart
  group('RolePermissions — requestVoidSale', () {
    test('cashier and staff have requestVoidSale; admin does not', () {
      expect(RolePermissions.hasPermission(
          UserRole.cashier, Permission.requestVoidSale), isTrue);
      expect(RolePermissions.hasPermission(
          UserRole.staff, Permission.requestVoidSale), isTrue);
      expect(RolePermissions.hasPermission(
          UserRole.admin, Permission.requestVoidSale), isFalse);
    });

    test('voidSale stays admin-only', () {
      expect(RolePermissions.hasPermission(
          UserRole.cashier, Permission.voidSale), isFalse);
      expect(RolePermissions.hasPermission(
          UserRole.staff, Permission.voidSale), isFalse);
      expect(RolePermissions.hasPermission(
          UserRole.admin, Permission.voidSale), isTrue);
    });
  });
```

- [ ] **Step 2: Run, verify failure**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/core/constants/role_permissions_test.dart`
Expected: FAIL — `Permission.requestVoidSale` is undefined (compile error).

- [ ] **Step 3: Add the permission enum value**

In `lib/core/constants/role_permissions.dart`, in the `enum Permission` block, add after `voidSale,`:

```dart
  voidSale,
  requestVoidSale, // cashier/staff request a void; admin approves
```

- [ ] **Step 4: Grant to cashier and staff**

In `_cashierPermissions`, after `Permission.applyDiscount,` add:

```dart
    Permission.requestVoidSale,
```

In `_staffPermissions`, after `Permission.applyDiscount,` add:

```dart
    Permission.requestVoidSale,
```

(Leave the `// Note: voidSale is NOT included (admin only)` comments — still true.)

- [ ] **Step 5: Add the collection constant**

In `lib/core/constants/firestore_collections.dart`, after the `voidReasons` constant add:

```dart
  /// Void requests collection - cashier/staff void requests awaiting admin approval
  static const String voidRequests = 'void_requests';
```

- [ ] **Step 6: Run, verify pass**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/core/constants/role_permissions_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core/constants/role_permissions.dart lib/core/constants/firestore_collections.dart test/core/constants/role_permissions_test.dart
git commit -m "feat(permissions): add requestVoidSale + void_requests collection"
```

---

## Task 2: VoidRequestEntity + VoidRequestModel

**Files:**
- Create: `lib/domain/entities/void_request_entity.dart`
- Create: `lib/data/models/void_request_model.dart`
- Modify: `lib/domain/entities/entities.dart`, `lib/data/models/models.dart`

- [ ] **Step 1: Create the entity**

Create `lib/domain/entities/void_request_entity.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Lifecycle status of a void request.
enum VoidRequestStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const VoidRequestStatus(this.value);
  final String value;

  static VoidRequestStatus fromValue(String value) =>
      VoidRequestStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => VoidRequestStatus.pending,
      );
}

/// A cashier/staff request to void a sale, awaiting admin approval.
class VoidRequestEntity extends Equatable {
  final String id;
  final String saleId;
  final String saleNumber;
  final double saleGrandTotal;
  final String requestedBy;
  final String requestedByName;
  final String requestedByRole;
  final String reason;
  final VoidRequestStatus status;
  final bool read;
  final DateTime createdAt;
  final String? resolvedBy;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final String? rejectionReason;

  const VoidRequestEntity({
    required this.id,
    required this.saleId,
    required this.saleNumber,
    required this.saleGrandTotal,
    required this.requestedBy,
    required this.requestedByName,
    required this.requestedByRole,
    required this.reason,
    this.status = VoidRequestStatus.pending,
    this.read = false,
    required this.createdAt,
    this.resolvedBy,
    this.resolvedByName,
    this.resolvedAt,
    this.rejectionReason,
  });

  bool get isPending => status == VoidRequestStatus.pending;

  VoidRequestEntity copyWith({
    String? id,
    VoidRequestStatus? status,
    bool? read,
    String? resolvedBy,
    String? resolvedByName,
    DateTime? resolvedAt,
    String? rejectionReason,
  }) {
    return VoidRequestEntity(
      id: id ?? this.id,
      saleId: saleId,
      saleNumber: saleNumber,
      saleGrandTotal: saleGrandTotal,
      requestedBy: requestedBy,
      requestedByName: requestedByName,
      requestedByRole: requestedByRole,
      reason: reason,
      status: status ?? this.status,
      read: read ?? this.read,
      createdAt: createdAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedByName: resolvedByName ?? this.resolvedByName,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  @override
  List<Object?> get props => [
        id,
        saleId,
        saleNumber,
        saleGrandTotal,
        requestedBy,
        requestedByName,
        requestedByRole,
        reason,
        status,
        read,
        createdAt,
        resolvedBy,
        resolvedByName,
        resolvedAt,
        rejectionReason,
      ];
}
```

- [ ] **Step 2: Create the model**

Create `lib/data/models/void_request_model.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Firestore (de)serialization for [VoidRequestEntity].
class VoidRequestModel {
  static VoidRequestEntity fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return VoidRequestEntity(
      id: doc.id,
      saleId: map['saleId'] as String? ?? '',
      saleNumber: map['saleNumber'] as String? ?? '',
      saleGrandTotal: (map['saleGrandTotal'] as num?)?.toDouble() ?? 0.0,
      requestedBy: map['requestedBy'] as String? ?? '',
      requestedByName: map['requestedByName'] as String? ?? '',
      requestedByRole: map['requestedByRole'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      status: VoidRequestStatus.fromValue(map['status'] as String? ?? 'pending'),
      read: map['read'] as bool? ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedBy: map['resolvedBy'] as String?,
      resolvedByName: map['resolvedByName'] as String?,
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      rejectionReason: map['rejectionReason'] as String?,
    );
  }

  /// Map for creating a new request (server timestamp for createdAt).
  static Map<String, dynamic> toCreateMap(VoidRequestEntity e) {
    return {
      'saleId': e.saleId,
      'saleNumber': e.saleNumber,
      'saleGrandTotal': e.saleGrandTotal,
      'requestedBy': e.requestedBy,
      'requestedByName': e.requestedByName,
      'requestedByRole': e.requestedByRole,
      'reason': e.reason,
      'status': VoidRequestStatus.pending.value,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
```

- [ ] **Step 3: Add barrel exports**

In `lib/domain/entities/entities.dart` add:

```dart
export 'void_request_entity.dart';
```

In `lib/data/models/models.dart` add:

```dart
export 'void_request_model.dart';
```

- [ ] **Step 4: Analyze**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter analyze lib/domain/entities/void_request_entity.dart lib/data/models/void_request_model.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/void_request_entity.dart lib/data/models/void_request_model.dart lib/domain/entities/entities.dart lib/data/models/models.dart
git commit -m "feat(void-requests): add entity + model"
```

---

## Task 3: Repository (contract + Firestore impl)

**Files:**
- Create: `lib/domain/repositories/void_request_repository.dart`
- Create: `lib/data/repositories/void_request_repository_impl.dart`
- Modify: `lib/domain/repositories/repositories.dart`, `lib/data/repositories/repositories.dart`

- [ ] **Step 1: Create the contract**

Create `lib/domain/repositories/void_request_repository.dart`:

```dart
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Contract for void-request persistence.
abstract class VoidRequestRepository {
  /// Creates a new pending request. Returns it with id populated.
  Future<VoidRequestEntity> createRequest(VoidRequestEntity request);

  /// Streams all requests, newest first (admin queue + unread count).
  Stream<List<VoidRequestEntity>> watchRequests({int limit = 50});

  /// Streams pending requests for a given sale (sale-detail indicator).
  Stream<List<VoidRequestEntity>> watchPendingForSale(String saleId);

  /// True if a pending request already exists for the sale (dedupe).
  Future<bool> hasPendingForSale(String saleId);

  /// Resolves a request (approve/reject) — admin only at the rules layer.
  Future<void> resolve({
    required String requestId,
    required VoidRequestStatus status,
    required String resolvedBy,
    required String resolvedByName,
    String? rejectionReason,
  });

  /// Marks a single request read.
  Future<void> markRead(String requestId);

  /// Marks all requests read.
  Future<void> markAllRead();
}
```

- [ ] **Step 2: Create the Firestore impl**

Create `lib/data/repositories/void_request_repository_impl.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';

class VoidRequestRepositoryImpl implements VoidRequestRepository {
  final FirebaseFirestore _firestore;

  VoidRequestRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference get _ref =>
      _firestore.collection(FirestoreCollections.voidRequests);

  @override
  Future<VoidRequestEntity> createRequest(VoidRequestEntity request) async {
    try {
      final docRef = await _ref.add(VoidRequestModel.toCreateMap(request));
      final doc = await docRef.get();
      return VoidRequestModel.fromFirestore(doc);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create void request: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<List<VoidRequestEntity>> watchRequests({int limit = 50}) {
    return _ref
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(VoidRequestModel.fromFirestore).toList());
  }

  @override
  Stream<List<VoidRequestEntity>> watchPendingForSale(String saleId) {
    return _ref
        .where('saleId', isEqualTo: saleId)
        .where('status', isEqualTo: VoidRequestStatus.pending.value)
        .snapshots()
        .map((s) => s.docs.map(VoidRequestModel.fromFirestore).toList());
  }

  @override
  Future<bool> hasPendingForSale(String saleId) async {
    final snap = await _ref
        .where('saleId', isEqualTo: saleId)
        .where('status', isEqualTo: VoidRequestStatus.pending.value)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  @override
  Future<void> resolve({
    required String requestId,
    required VoidRequestStatus status,
    required String resolvedBy,
    required String resolvedByName,
    String? rejectionReason,
  }) async {
    try {
      await _ref.doc(requestId).update({
        'status': status.value,
        'read': true,
        'resolvedBy': resolvedBy,
        'resolvedByName': resolvedByName,
        'resolvedAt': FieldValue.serverTimestamp(),
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to resolve void request: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> markRead(String requestId) async {
    await _ref.doc(requestId).update({'read': true});
  }

  @override
  Future<void> markAllRead() async {
    final snap = await _ref.where('read', isEqualTo: false).get();
    if (snap.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
```

- [ ] **Step 3: Add barrel exports**

In `lib/domain/repositories/repositories.dart` add:

```dart
export 'void_request_repository.dart';
```

In `lib/data/repositories/repositories.dart` add (match the file's existing style):

```dart
export 'void_request_repository_impl.dart';
```

- [ ] **Step 4: Analyze**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter analyze lib/domain/repositories/void_request_repository.dart lib/data/repositories/void_request_repository_impl.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/repositories/void_request_repository.dart lib/data/repositories/void_request_repository_impl.dart lib/domain/repositories/repositories.dart lib/data/repositories/repositories.dart
git commit -m "feat(void-requests): repository contract + Firestore impl"
```

---

## Task 4: Harden VoidSaleUseCase with a permission assert

The existing `VoidSaleUseCase.execute` takes `voidedBy`/`voidedByName` strings and has no permission check. Add an `actor` and assert `voidSale` so it fails loudly for non-admins and is reusable from the approve use case.

**Files:**
- Modify: `lib/domain/usecases/pos/void_sale_usecase.dart`
- Modify: `lib/presentation/mobile/widgets/pos/void_sale_dialog.dart`
- Test: `test/domain/usecases/void_sale_usecase_test.dart`

- [ ] **Step 1: Add a failing test for the permission gate**

Open `test/domain/usecases/void_sale_usecase_test.dart`. It already constructs `VoidSaleUseCase` and calls `execute(...)`. Add a `UserEntity` helper if not present:

```dart
UserEntity _user(UserRole role, {bool isActive = true}) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: isActive,
      createdAt: DateTime(2025, 1, 1),
    );
```

Add this test inside the main group:

```dart
    test('non-admin actor is denied', () async {
      final result = await useCase.execute(
        actor: _user(UserRole.cashier),
        saleId: 's-1',
        password: 'pw',
        reason: 'wrong item rung up',
        voidedBy: 'u-cashier',
        voidedByName: 'cashier user',
      );
      expect(result.success, isFalse);
      expect(result.errorCode, 'permission-denied');
    });
```

Ensure imports include `UserRole`, `UserEntity`. If existing tests call `execute(...)` without `actor`, update them to pass `actor: _user(UserRole.admin)` (admin) so they still pass after the signature change.

- [ ] **Step 2: Run, verify failure**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/domain/usecases/void_sale_usecase_test.dart`
Expected: FAIL — `execute` has no `actor` parameter (compile error).

- [ ] **Step 3: Add the actor + assert**

In `lib/domain/usecases/pos/void_sale_usecase.dart`:

Add imports at top:

```dart
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
```

Change the `execute` signature to add `required UserEntity actor,` as the first named param, and assert at the very start of the `try` block:

```dart
    try {
      assertPermission(actor, Permission.voidSale);

      // 1. Validate inputs
      _validateInputs(reason: reason, voidedBy: voidedBy);
```

`UserEntity` is exported by `domain/entities/entities.dart` (already imported in this file via `entities.dart`). The existing `catch (AppException)` path returns a failure with `e.code` — `PermissionDeniedException.code` is `permission-denied`, so the test's `errorCode` check passes. Verify the use case's catch maps `AppException` to a `VoidSaleResult` with `errorMessage`/`errorCode`; if `VoidSaleResult` lacks `errorCode`, add it mirroring `ProcessSaleResult` (fields `success`, `errorMessage`, `errorCode`, `warnings`) and have the `on AppException` branch set `errorCode: e.code`.

- [ ] **Step 4: Update the dialog call site**

In `lib/presentation/mobile/widgets/pos/void_sale_dialog.dart`, the `_processVoid` method reads `currentUser` and builds `VoidSaleUseCase`. Add `actor: currentUser,` to the `execute(...)` call:

```dart
      final result = await useCase.execute(
        actor: currentUser,
        saleId: widget.sale.id,
        password: password,
        reason: reason,
        voidedBy: currentUser.id,
        voidedByName: currentUser.displayName,
        restoreInventory: _restoreInventory,
      );
```

- [ ] **Step 5: Run tests, verify pass**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/domain/usecases/void_sale_usecase_test.dart`
Expected: PASS (including the new denial test).

- [ ] **Step 6: Analyze**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter analyze lib/domain/usecases/pos/void_sale_usecase.dart lib/presentation/mobile/widgets/pos/void_sale_dialog.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/usecases/pos/void_sale_usecase.dart lib/presentation/mobile/widgets/pos/void_sale_dialog.dart test/domain/usecases/void_sale_usecase_test.dart
git commit -m "feat(void): assert voidSale permission in VoidSaleUseCase"
```

---

## Task 5: RequestVoidSaleUseCase

**Files:**
- Create: `lib/domain/usecases/pos/request_void_sale_usecase.dart`
- Test: `test/domain/usecases/pos/request_void_sale_usecase_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/domain/usecases/pos/request_void_sale_usecase_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/request_void_sale_usecase.dart';

class _MockVoidRequestRepository extends Mock
    implements VoidRequestRepository {}

class _FakeVoidRequest extends Fake implements VoidRequestEntity {}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test',
      displayName: '${role.value} user',
      role: role,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

SaleEntity _sale() => SaleEntity(
      id: 's-1',
      saleNumber: 'SALE-0042',
      items: const [],
      subtotal: 100,
      totalDiscount: 0,
      grandTotal: 100,
      amountReceived: 100,
      changeGiven: 0,
      paymentMethod: PaymentMethod.cash,
      cashierId: 'u-cashier',
      cashierName: 'cashier user',
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  setUpAll(() => registerFallbackValue(_FakeVoidRequest()));

  late _MockVoidRequestRepository repo;
  late RequestVoidSaleUseCase useCase;

  setUp(() {
    repo = _MockVoidRequestRepository();
    useCase = RequestVoidSaleUseCase(repository: repo);
    when(() => repo.hasPendingForSale(any())).thenAnswer((_) async => false);
    when(() => repo.createRequest(any())).thenAnswer(
        (inv) async => (inv.positionalArguments.first as VoidRequestEntity)
            .copyWith(id: 'vr-1'));
  });

  test('cashier creates a pending request', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: _sale(),
      reason: 'wrong item rung up',
    );
    expect(result.success, isTrue);
    expect(result.data?.id, 'vr-1');
    final captured =
        verify(() => repo.createRequest(captureAny())).captured.single
            as VoidRequestEntity;
    expect(captured.saleId, 's-1');
    expect(captured.requestedBy, 'u-cashier');
    expect(captured.status, VoidRequestStatus.pending);
  });

  test('admin is denied (uses direct void, not requests)', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.admin),
      sale: _sale(),
      reason: 'wrong item rung up',
    );
    expect(result.success, isFalse);
    expect(result.errorCode, 'permission-denied');
    verifyNever(() => repo.createRequest(any()));
  });

  test('short reason is rejected', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: _sale(),
      reason: 'no',
    );
    expect(result.success, isFalse);
    verifyNever(() => repo.createRequest(any()));
  });

  test('duplicate pending request is rejected', () async {
    when(() => repo.hasPendingForSale('s-1')).thenAnswer((_) async => true);
    final result = await useCase.execute(
      actor: _user(UserRole.cashier),
      sale: _sale(),
      reason: 'wrong item rung up',
    );
    expect(result.success, isFalse);
    expect(result.errorCode, 'void-already-pending');
    verifyNever(() => repo.createRequest(any()));
  });
}
```

(If the `SaleEntity` constructor params differ, open `lib/domain/entities/sale_entity.dart` and adjust the `_sale()` helper to match — keep `id`, `saleNumber`, `grandTotal`.)

- [ ] **Step 2: Run, verify failure**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/domain/usecases/pos/request_void_sale_usecase_test.dart`
Expected: FAIL — `RequestVoidSaleUseCase` undefined.

- [ ] **Step 3: Implement the use case**

Create `lib/domain/usecases/pos/request_void_sale_usecase.dart`:

```dart
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Creates a void request (cashier/staff). Permission: [Permission.requestVoidSale].
class RequestVoidSaleUseCase {
  final VoidRequestRepository _repository;

  RequestVoidSaleUseCase({required VoidRequestRepository repository})
      : _repository = repository;

  Future<UseCaseResult<VoidRequestEntity>> execute({
    required UserEntity actor,
    required SaleEntity sale,
    required String reason,
  }) async {
    try {
      assertPermission(actor, Permission.requestVoidSale);

      final trimmed = reason.trim();
      if (trimmed.length < 5) {
        return const UseCaseResult.failure(
          message: 'Please provide a more detailed reason (at least 5 characters)',
          code: 'reason-too-short',
        );
      }

      if (await _repository.hasPendingForSale(sale.id)) {
        return const UseCaseResult.failure(
          message: 'A void request for this sale is already pending',
          code: 'void-already-pending',
        );
      }

      final created = await _repository.createRequest(VoidRequestEntity(
        id: '',
        saleId: sale.id,
        saleNumber: sale.saleNumber,
        saleGrandTotal: sale.grandTotal,
        requestedBy: actor.id,
        requestedByName: actor.displayName,
        requestedByRole: actor.role.value,
        reason: trimmed,
        createdAt: DateTime.now(),
      ));

      return UseCaseResult.successData(created);
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to request void: $e');
    }
  }
}
```

- [ ] **Step 4: Run, verify pass**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/domain/usecases/pos/request_void_sale_usecase_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/usecases/pos/request_void_sale_usecase.dart test/domain/usecases/pos/request_void_sale_usecase_test.dart
git commit -m "feat(void-requests): RequestVoidSaleUseCase"
```

---

## Task 6: Approve + Reject use cases

**Files:**
- Create: `lib/domain/usecases/pos/approve_void_request_usecase.dart`
- Create: `lib/domain/usecases/pos/reject_void_request_usecase.dart`
- Test: `test/domain/usecases/pos/approve_void_request_usecase_test.dart`, `reject_void_request_usecase_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/domain/usecases/pos/reject_void_request_usecase_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/reject_void_request_usecase.dart';

class _MockVoidRequestRepository extends Mock
    implements VoidRequestRepository {}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}', email: '${role.value}@test',
      displayName: '${role.value} user', role: role, isActive: true,
      createdAt: DateTime(2025, 1, 1));

VoidRequestEntity _req() => VoidRequestEntity(
      id: 'vr-1', saleId: 's-1', saleNumber: 'SALE-0042', saleGrandTotal: 100,
      requestedBy: 'u-cashier', requestedByName: 'cashier user',
      requestedByRole: 'cashier', reason: 'wrong item', createdAt: DateTime(2025, 1, 1));

void main() {
  late _MockVoidRequestRepository repo;
  late RejectVoidRequestUseCase useCase;

  setUp(() {
    repo = _MockVoidRequestRepository();
    useCase = RejectVoidRequestUseCase(repository: repo);
    when(() => repo.resolve(
          requestId: any(named: 'requestId'),
          status: any(named: 'status'),
          resolvedBy: any(named: 'resolvedBy'),
          resolvedByName: any(named: 'resolvedByName'),
          rejectionReason: any(named: 'rejectionReason'),
        )).thenAnswer((_) async {});
  });

  test('admin rejects with reason', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.admin), request: _req(),
      rejectionReason: 'not authorized');
    expect(result.success, isTrue);
    verify(() => repo.resolve(
          requestId: 'vr-1',
          status: VoidRequestStatus.rejected,
          resolvedBy: 'u-admin',
          resolvedByName: 'admin user',
          rejectionReason: 'not authorized',
        )).called(1);
  });

  test('cashier denied', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier), request: _req(),
      rejectionReason: 'x');
    expect(result.success, isFalse);
    expect(result.errorCode, 'permission-denied');
  });
}
```

Create `test/domain/usecases/pos/approve_void_request_usecase_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/approve_void_request_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/void_sale_usecase.dart';

class _MockVoidRequestRepository extends Mock
    implements VoidRequestRepository {}

class _MockVoidSaleUseCase extends Mock implements VoidSaleUseCase {}

class _FakeUser extends Fake implements UserEntity {}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-${role.value}', email: '${role.value}@test',
      displayName: '${role.value} user', role: role, isActive: true,
      createdAt: DateTime(2025, 1, 1));

VoidRequestEntity _req() => VoidRequestEntity(
      id: 'vr-1', saleId: 's-1', saleNumber: 'SALE-0042', saleGrandTotal: 100,
      requestedBy: 'u-cashier', requestedByName: 'cashier user',
      requestedByRole: 'cashier', reason: 'wrong item', createdAt: DateTime(2025, 1, 1));

void main() {
  setUpAll(() => registerFallbackValue(_FakeUser()));

  late _MockVoidRequestRepository repo;
  late _MockVoidSaleUseCase voidSale;
  late ApproveVoidRequestUseCase useCase;

  setUp(() {
    repo = _MockVoidRequestRepository();
    voidSale = _MockVoidSaleUseCase();
    useCase = ApproveVoidRequestUseCase(repository: repo, voidSaleUseCase: voidSale);
    when(() => repo.resolve(
          requestId: any(named: 'requestId'),
          status: any(named: 'status'),
          resolvedBy: any(named: 'resolvedBy'),
          resolvedByName: any(named: 'resolvedByName'),
          rejectionReason: any(named: 'rejectionReason'),
        )).thenAnswer((_) async {});
  });

  test('admin approval voids the sale then marks approved', () async {
    when(() => voidSale.execute(
          actor: any(named: 'actor'),
          saleId: any(named: 'saleId'),
          password: any(named: 'password'),
          reason: any(named: 'reason'),
          voidedBy: any(named: 'voidedBy'),
          voidedByName: any(named: 'voidedByName'),
        )).thenAnswer((_) async => const VoidSaleResult(success: true));

    final result = await useCase.execute(
      actor: _user(UserRole.admin), request: _req(), password: 'pw');

    expect(result.success, isTrue);
    verify(() => voidSale.execute(
          actor: any(named: 'actor'),
          saleId: 's-1',
          password: 'pw',
          reason: 'wrong item',
          voidedBy: 'u-admin',
          voidedByName: 'admin user',
        )).called(1);
    verify(() => repo.resolve(
          requestId: 'vr-1',
          status: VoidRequestStatus.approved,
          resolvedBy: 'u-admin',
          resolvedByName: 'admin user',
          rejectionReason: null,
        )).called(1);
  });

  test('if the void fails, request is not marked approved', () async {
    when(() => voidSale.execute(
          actor: any(named: 'actor'),
          saleId: any(named: 'saleId'),
          password: any(named: 'password'),
          reason: any(named: 'reason'),
          voidedBy: any(named: 'voidedBy'),
          voidedByName: any(named: 'voidedByName'),
        )).thenAnswer((_) async =>
        const VoidSaleResult(success: false, errorMessage: 'Invalid password'));

    final result = await useCase.execute(
      actor: _user(UserRole.admin), request: _req(), password: 'bad');

    expect(result.success, isFalse);
    verifyNever(() => repo.resolve(
          requestId: any(named: 'requestId'),
          status: any(named: 'status'),
          resolvedBy: any(named: 'resolvedBy'),
          resolvedByName: any(named: 'resolvedByName'),
          rejectionReason: any(named: 'rejectionReason'),
        ));
  });

  test('cashier denied', () async {
    final result = await useCase.execute(
      actor: _user(UserRole.cashier), request: _req(), password: 'pw');
    expect(result.success, isFalse);
    expect(result.errorCode, 'permission-denied');
  });
}
```

NOTE: `VoidSaleResult` currently has no `errorCode` field. Task 4 Step 3 adds `errorCode` to it (mirroring `ProcessSaleResult`). The approve use case surfaces `voidResult.errorMessage` on failure — it does not need `errorCode` from `VoidSaleResult`.

- [ ] **Step 2: Run, verify failure**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/domain/usecases/pos/approve_void_request_usecase_test.dart test/domain/usecases/pos/reject_void_request_usecase_test.dart`
Expected: FAIL — use cases undefined.

- [ ] **Step 3: Implement reject**

Create `lib/domain/usecases/pos/reject_void_request_usecase.dart`:

```dart
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';

/// Rejects a void request (admin). Permission: [Permission.voidSale].
class RejectVoidRequestUseCase {
  final VoidRequestRepository _repository;

  RejectVoidRequestUseCase({required VoidRequestRepository repository})
      : _repository = repository;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required VoidRequestEntity request,
    required String rejectionReason,
  }) async {
    try {
      assertPermission(actor, Permission.voidSale);

      final trimmed = rejectionReason.trim();
      if (trimmed.isEmpty) {
        return const UseCaseResult.failure(
          message: 'A rejection reason is required',
          code: 'reason-required',
        );
      }

      await _repository.resolve(
        requestId: request.id,
        status: VoidRequestStatus.rejected,
        resolvedBy: actor.id,
        resolvedByName: actor.displayName,
        rejectionReason: trimmed,
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to reject request: $e');
    }
  }
}
```

- [ ] **Step 4: Implement approve**

Create `lib/domain/usecases/pos/approve_void_request_usecase.dart`:

```dart
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/permissions/permission_assert.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/base/use_case.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/void_sale_usecase.dart';

/// Approves a void request (admin): runs the void, then marks the request
/// approved. Permission: [Permission.voidSale].
class ApproveVoidRequestUseCase {
  final VoidRequestRepository _repository;
  final VoidSaleUseCase _voidSaleUseCase;

  ApproveVoidRequestUseCase({
    required VoidRequestRepository repository,
    required VoidSaleUseCase voidSaleUseCase,
  })  : _repository = repository,
        _voidSaleUseCase = voidSaleUseCase;

  Future<UseCaseResult<void>> execute({
    required UserEntity actor,
    required VoidRequestEntity request,
    required String password,
  }) async {
    try {
      assertPermission(actor, Permission.voidSale);

      // Run the actual void first (admin is recorded as voidedBy).
      final voidResult = await _voidSaleUseCase.execute(
        actor: actor,
        saleId: request.saleId,
        password: password,
        reason: request.reason,
        voidedBy: actor.id,
        voidedByName: actor.displayName,
      );

      if (!voidResult.success) {
        return UseCaseResult.failure(
          message: voidResult.errorMessage ?? 'Failed to void the sale',
        );
      }

      // Only mark approved once the void succeeded.
      await _repository.resolve(
        requestId: request.id,
        status: VoidRequestStatus.approved,
        resolvedBy: actor.id,
        resolvedByName: actor.displayName,
      );

      return const UseCaseResult.successVoid();
    } on AppException catch (e) {
      return UseCaseResult.fromException(e);
    } catch (e) {
      return UseCaseResult.failure(message: 'Failed to approve request: $e');
    }
  }
}
```

NOTE: `VoidSaleUseCase.execute` returns `VoidSaleResult` (not `UseCaseResult`); this code uses `voidResult.success`/`voidResult.errorMessage`, which exist on `VoidSaleResult`.

- [ ] **Step 5: Run, verify pass**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test test/domain/usecases/pos/approve_void_request_usecase_test.dart test/domain/usecases/pos/reject_void_request_usecase_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/usecases/pos/approve_void_request_usecase.dart lib/domain/usecases/pos/reject_void_request_usecase.dart test/domain/usecases/pos/approve_void_request_usecase_test.dart test/domain/usecases/pos/reject_void_request_usecase_test.dart
git commit -m "feat(void-requests): approve + reject use cases"
```

---

## Task 7: Providers

**Files:**
- Create: `lib/presentation/providers/void_request_provider.dart`
- Modify: `lib/presentation/providers/providers.dart`

- [ ] **Step 1: Create the providers**

Create `lib/presentation/providers/void_request_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/void_request_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/approve_void_request_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/reject_void_request_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/request_void_sale_usecase.dart';
import 'package:maki_mobile_pos/domain/usecases/pos/void_sale_usecase.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// Repository
final voidRequestRepositoryProvider = Provider<VoidRequestRepository>((ref) {
  return VoidRequestRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

// Use cases
final requestVoidSaleUseCaseProvider =
    Provider<RequestVoidSaleUseCase>((ref) {
  return RequestVoidSaleUseCase(
      repository: ref.watch(voidRequestRepositoryProvider));
});

final rejectVoidRequestUseCaseProvider =
    Provider<RejectVoidRequestUseCase>((ref) {
  return RejectVoidRequestUseCase(
      repository: ref.watch(voidRequestRepositoryProvider));
});

final approveVoidRequestUseCaseProvider =
    Provider<ApproveVoidRequestUseCase>((ref) {
  return ApproveVoidRequestUseCase(
    repository: ref.watch(voidRequestRepositoryProvider),
    voidSaleUseCase: VoidSaleUseCase(
      saleRepository: ref.watch(saleRepositoryProvider),
      productRepository: ref.watch(productRepositoryProvider),
      authRepository: ref.watch(authRepositoryProvider),
    ),
  );
});

// Streams
/// All void requests, newest first (admin queue).
final voidRequestsProvider = StreamProvider<List<VoidRequestEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(voidRequestRepositoryProvider).watchRequests();
  });
});

/// Unread void-request count (notification badge).
final unreadVoidRequestCountProvider = Provider<int>((ref) {
  final async = ref.watch(voidRequestsProvider);
  return async.maybeWhen(
    data: (list) => list.where((r) => !r.read).length,
    orElse: () => 0,
  );
});

/// Pending requests for a sale (sale-detail indicator).
final pendingVoidRequestForSaleProvider =
    StreamProvider.family<List<VoidRequestEntity>, String>((ref, saleId) {
  return authGatedStream(ref, (_) {
    return ref
        .watch(voidRequestRepositoryProvider)
        .watchPendingForSale(saleId);
  });
});

// Operations
class VoidRequestOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  VoidRequestOperationsNotifier(this._ref)
      : super(const AsyncValue.data(null));

  UserEntity _requireUser() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) throw const UnauthenticatedException();
    return user;
  }

  Future<String?> requestVoid({
    required SaleEntity sale,
    required String reason,
  }) async {
    final result = await _ref.read(requestVoidSaleUseCaseProvider).execute(
        actor: _requireUser(), sale: sale, reason: reason);
    _ref.invalidate(voidRequestsProvider);
    return result.success ? null : (result.errorMessage ?? 'Failed');
  }

  Future<String?> approve({
    required VoidRequestEntity request,
    required String password,
  }) async {
    final result = await _ref.read(approveVoidRequestUseCaseProvider).execute(
        actor: _requireUser(), request: request, password: password);
    _ref.invalidate(voidRequestsProvider);
    _ref.invalidate(todaysSalesProvider);
    return result.success ? null : (result.errorMessage ?? 'Failed');
  }

  Future<String?> reject({
    required VoidRequestEntity request,
    required String rejectionReason,
  }) async {
    final result = await _ref.read(rejectVoidRequestUseCaseProvider).execute(
        actor: _requireUser(),
        request: request,
        rejectionReason: rejectionReason);
    _ref.invalidate(voidRequestsProvider);
    return result.success ? null : (result.errorMessage ?? 'Failed');
  }

  Future<void> markAllRead() async {
    await _ref.read(voidRequestRepositoryProvider).markAllRead();
    _ref.invalidate(voidRequestsProvider);
  }

  Future<void> markRead(String requestId) async {
    await _ref.read(voidRequestRepositoryProvider).markRead(requestId);
    _ref.invalidate(voidRequestsProvider);
  }
}

final voidRequestOperationsProvider =
    StateNotifierProvider<VoidRequestOperationsNotifier, AsyncValue<void>>(
        (ref) => VoidRequestOperationsNotifier(ref));
```

Verify the referenced provider names exist: `saleRepositoryProvider` (sale_provider), `productRepositoryProvider` (product_provider), `authRepositoryProvider` (auth_provider), `todaysSalesProvider` (sale_provider), `currentUserProvider` (auth_provider), `authGatedStream` (auth_provider), `firestoreProvider` (firebase_service). If a name differs, grep for the correct one and adjust.

- [ ] **Step 2: Add barrel export**

In `lib/presentation/providers/providers.dart` add:

```dart
export 'void_request_provider.dart';
```

- [ ] **Step 3: Analyze**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter analyze lib/presentation/providers/void_request_provider.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/providers/void_request_provider.dart lib/presentation/providers/providers.dart
git commit -m "feat(void-requests): providers"
```

---

## Task 8: Firestore rules + rules tests

**Files:**
- Modify: `firestore.rules`
- Test: `tools/firestore-rules-test/test/rules.test.js`

- [ ] **Step 1: Add the failing rules tests**

In `tools/firestore-rules-test/test/rules.test.js`, add a new describe block (place it after the `/settings` block, before `cross-cutting`):

```js
// ===================================================================
// /void_requests
// ===================================================================
describe("/void_requests", () => {
  beforeEach(async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().collection("void_requests").doc("vr-1").set({
        saleId: "s-1", saleNumber: "SALE-0042", saleGrandTotal: 100,
        requestedBy: USERS.cashier.uid, requestedByName: "cashier user",
        requestedByRole: "cashier", reason: "wrong item", status: "pending",
        read: false, createdAt: new Date(),
      });
    });
  });

  const newReq = (uid) => ({
    saleId: "s-9", saleNumber: "SALE-0099", saleGrandTotal: 50,
    requestedBy: uid, requestedByName: "x", requestedByRole: "cashier",
    reason: "test reason", status: "pending", read: false, createdAt: new Date(),
  });

  it("cashier/staff/admin can create their own pending request", async () => {
    await assertSucceeds(
      as("cashier").collection("void_requests").doc("c-1").set(newReq(USERS.cashier.uid)));
    await assertSucceeds(
      as("staff").collection("void_requests").doc("s-1b").set(newReq(USERS.staff.uid)));
  });

  it("cannot create a request as someone else", async () => {
    await assertFails(
      as("cashier").collection("void_requests").doc("c-2").set(newReq(USERS.staff.uid)));
  });

  it("cannot create a non-pending request", async () => {
    const r = newReq(USERS.cashier.uid);
    r.status = "approved";
    await assertFails(
      as("cashier").collection("void_requests").doc("c-3").set(r));
  });

  it("inactive user cannot create", async () => {
    await assertFails(
      as("inactiveStaff").collection("void_requests").doc("c-4").set(newReq(USERS.inactiveStaff.uid)));
  });

  it("active valid users can read", async () => {
    await assertSucceeds(as("cashier").collection("void_requests").doc("vr-1").get());
    await assertSucceeds(as("admin").collection("void_requests").doc("vr-1").get());
  });

  it("only admin can update (approve/reject/mark-read)", async () => {
    await assertFails(
      as("cashier").collection("void_requests").doc("vr-1").update({ read: true }));
    await assertFails(
      as("staff").collection("void_requests").doc("vr-1").update({ status: "approved" }));
    await assertSucceeds(
      as("admin").collection("void_requests").doc("vr-1").update({ status: "approved", read: true }));
  });

  it("no one can delete", async () => {
    await assertFails(as("admin").collection("void_requests").doc("vr-1").delete());
  });
});
```

(The `inactiveStaff` user was added to `USERS` in the staff-product-creation work. If it's absent, add `inactiveStaff: { uid: "inactive-staff-1", role: "staff", isActive: false }` to the `USERS` map.)

- [ ] **Step 2: Run, verify failure**

Run: `cd tools/firestore-rules-test && JAVA_HOME="$(/usr/libexec/java_home -v 19)" PATH="$JAVA_HOME/bin:$PATH" npm test`
Expected: FAIL — `/void_requests` create/read/update currently denied (no rule yet → all fail).

- [ ] **Step 3: Add the rules**

In `firestore.rules`, add a new block inside `match /databases/{database}/documents {` (e.g., after the `void_reasons` block):

```
    // ==================== VOID REQUESTS COLLECTION ====================

    match /void_requests/{requestId} {
      // Any active valid user can read (pending indicator + admin queue).
      allow read: if isValidUser() && isActiveUser();

      // Requester creates their own pending request.
      allow create: if isValidUser() && isActiveUser() &&
        request.resource.data.requestedBy == request.auth.uid &&
        request.resource.data.status == 'pending';

      // Only admin resolves (approve/reject) or marks read.
      allow update: if isAdmin() && isActiveUser();

      // Audit trail — no deletes.
      allow delete: if false;
    }
```

- [ ] **Step 4: Run, verify pass**

Run: `cd tools/firestore-rules-test && JAVA_HOME="$(/usr/libexec/java_home -v 19)" PATH="$JAVA_HOME/bin:$PATH" npm test`
Expected: PASS — all new `/void_requests` tests green; existing tests still pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/czar/Desktop/MAKI_Mobile_POS/maki_mobile_pos
git add firestore.rules tools/firestore-rules-test/test/rules.test.js
git commit -m "feat(rules): void_requests collection rules"
```

---

## Task 9: Sale-detail UI — request button + pending indicator

No widget-test harness: implement, `flutter analyze`, then manual verification.

**Files:**
- Create: `lib/presentation/mobile/widgets/pos/request_void_dialog.dart`
- Modify: `lib/presentation/mobile/screens/sales/sale_detail_screen.dart`

- [ ] **Step 1: Create the request dialog**

Create `lib/presentation/mobile/widgets/pos/request_void_dialog.dart`. Model it on the existing `VoidSaleDialog` reason UI, but it only collects a reason and calls `voidRequestOperationsProvider.requestVoid` (no password). Minimum:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

class RequestVoidDialog extends ConsumerStatefulWidget {
  final SaleEntity sale;
  final VoidCallback onRequested;

  const RequestVoidDialog({super.key, required this.sale, required this.onRequested});

  static Future<void> show({
    required BuildContext context,
    required SaleEntity sale,
    required VoidCallback onRequested,
  }) {
    return showDialog(
      context: context,
      builder: (_) => RequestVoidDialog(sale: sale, onRequested: onRequested),
    );
  }

  @override
  ConsumerState<RequestVoidDialog> createState() => _RequestVoidDialogState();
}

class _RequestVoidDialogState extends ConsumerState<RequestVoidDialog> {
  final _reasonController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    if (reason.length < 5) {
      setState(() => _error = 'Please provide a more detailed reason (min 5 characters)');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    final err = await ref
        .read(voidRequestOperationsProvider.notifier)
        .requestVoid(sale: widget.sale, reason: reason);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      widget.onRequested();
    } else {
      setState(() { _submitting = false; _error = err; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Request Void'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sale ${widget.sale.saleNumber} will be sent to an admin for approval.'),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason *',
              hintText: 'Why should this sale be voided?',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Sending…' : 'Send Request'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Branch the sale-detail void button**

In `lib/presentation/mobile/screens/sales/sale_detail_screen.dart`:

Add imports if missing:
```dart
import 'package:maki_mobile_pos/core/constants/role_permissions.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/request_void_dialog.dart';
```

Replace the call site (currently `if (!isVoided) _buildVoidButton(context, ref, sale),`) with:

```dart
          if (!isVoided) _buildVoidAction(context, ref, sale),
```

Add a new method that decides what to render based on role and any pending request:

```dart
  Widget _buildVoidAction(BuildContext context, WidgetRef ref, SaleEntity sale) {
    final user = ref.watch(currentUserProvider).value;
    final pendingAsync = ref.watch(pendingVoidRequestForSaleProvider(sale.id));
    final hasPending =
        pendingAsync.maybeWhen(data: (l) => l.isNotEmpty, orElse: () => false);

    if (hasPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.clock, size: 18),
            SizedBox(width: 8),
            Text('Void pending approval'),
          ],
        ),
      );
    }

    final canVoidDirect =
        user?.hasPermission(Permission.voidSale) ?? false;
    final canRequest =
        user?.hasPermission(Permission.requestVoidSale) ?? false;

    if (canVoidDirect) {
      return _buildVoidButton(context, ref, sale); // existing direct flow
    }
    if (canRequest) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => RequestVoidDialog.show(
            context: context,
            sale: sale,
            onRequested: () => context.showSuccessSnackBar(
                'Void request sent — awaiting admin approval'),
          ),
          icon: const Icon(CupertinoIcons.xmark_circle),
          label: const Text('Request Void'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
```

(`context.showSuccessSnackBar` is the existing extension used elsewhere in this file via `common_widgets`/navigation extensions; it's already imported.)

- [ ] **Step 3: Analyze**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter analyze lib/presentation/mobile/widgets/pos/request_void_dialog.dart lib/presentation/mobile/screens/sales/sale_detail_screen.dart`
Expected: No issues.

- [ ] **Step 4: Manual verification**

As **cashier/staff**: open a completed sale → see "Request Void" (not the admin void). Submit a reason → success snackbar; reopening the sale shows "Void pending approval". As **admin**: the sale still shows the direct "Void This Sale".

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/pos/request_void_dialog.dart lib/presentation/mobile/screens/sales/sale_detail_screen.dart
git commit -m "feat(void-requests): request-void button + pending indicator"
```

---

## Task 10: Admin notification bell + approvals screen + route

No widget-test harness: implement, `flutter analyze`, manual verification.

**Files:**
- Create: `lib/presentation/mobile/screens/sales/void_requests_screen.dart`
- Modify: `lib/config/router/route_names.dart` (names + paths), `lib/config/router/app_routes.dart`, `lib/config/router/route_guards.dart`
- Modify: `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart`

- [ ] **Step 1: Add the route name + path**

In `lib/config/router/route_names.dart`, add a name constant (with the others) and a path constant (with the `/...` paths):

```dart
  static const String voidRequests = 'voidRequests';
```
and in the paths section:
```dart
  static const String voidRequests = '/void-requests';
```

(Match the file's two-section layout — names near `saleDetail = 'saleDetail'`, paths near `saleDetail = '/reports/sale/:id'`.)

- [ ] **Step 2: Register the route**

In `lib/config/router/app_routes.dart`, add a `GoRoute` mirroring the `saleDetail` route declaration style (import the screen at the top):

```dart
        GoRoute(
          path: RoutePaths.voidRequests,
          name: RouteNames.voidRequests,
          builder: (context, state) => const VoidRequestsScreen(),
        ),
```

Place it as a top-level app route alongside the others (same nesting level as the reports routes).

- [ ] **Step 3: Guard the route**

In `lib/config/router/route_guards.dart`, add to the `routePermissions` map:

```dart
    '/void-requests': Permission.voidSale,
```

- [ ] **Step 4: Create the approvals screen**

Create `lib/presentation/mobile/screens/sales/void_requests_screen.dart`. It watches `voidRequestsProvider`, lists rows newest-first, has a "Mark all as read" app-bar action, and on row tap marks read + opens an approve/reject sheet:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

class VoidRequestsScreen extends ConsumerWidget {
  const VoidRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(voidRequestsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Void Requests'),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(voidRequestOperationsProvider.notifier).markAllRead(),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(message: 'Error: $e'),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyStateView(
                icon: CupertinoIcons.bell, title: 'No void requests');
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _row(context, ref, list[i]),
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, VoidRequestEntity r) {
    final df = DateFormat('MMM d, h:mm a');
    return ListTile(
      leading: Icon(
        r.isPending ? CupertinoIcons.clock : CupertinoIcons.check_mark_circled,
      ),
      title: Text('${r.saleNumber} • ${AppConstants.currencySymbol}${r.saleGrandTotal.toStringAsFixed(2)}'),
      subtitle: Text('${r.requestedByName} • ${r.reason}\n${df.format(r.createdAt)} • ${r.status.value}'),
      isThreeLine: true,
      trailing: r.read ? null : const Icon(Icons.brightness_1, size: 10, color: Colors.red),
      onTap: () async {
        await ref.read(voidRequestOperationsProvider.notifier).markRead(r.id);
        if (r.isPending && context.mounted) {
          _showResolveSheet(context, ref, r);
        }
      },
    );
  }

  void _showResolveSheet(BuildContext context, WidgetRef ref, VoidRequestEntity r) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Void ${r.saleNumber}?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Requested by ${r.requestedByName}: ${r.reason}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () { Navigator.pop(context); _reject(context, ref, r); },
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () { Navigator.pop(context); _approve(context, ref, r); },
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _approve(BuildContext context, WidgetRef ref, VoidRequestEntity r) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm with password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Your password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final pw = controller.text;
              Navigator.pop(context);
              final err = await ref
                  .read(voidRequestOperationsProvider.notifier)
                  .approve(request: r, password: pw);
              if (context.mounted) {
                err == null
                    ? context.showSuccessSnackBar('Sale voided')
                    : context.showErrorSnackBar(err);
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _reject(BuildContext context, WidgetRef ref, VoidRequestEntity r) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final reason = controller.text;
              Navigator.pop(context);
              final err = await ref
                  .read(voidRequestOperationsProvider.notifier)
                  .reject(request: r, rejectionReason: reason);
              if (context.mounted) {
                err == null
                    ? context.showSuccessSnackBar('Request rejected')
                    : context.showErrorSnackBar(err);
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
```

Verify `LoadingView`, `EmptyStateView`, `ErrorStateView`, `context.showSuccessSnackBar`, `context.showErrorSnackBar` are exported by `common_widgets`/navigation extensions (they are used in `sale_detail_screen.dart`); fix imports if analyze complains.

- [ ] **Step 5: Add the bell to the dashboard**

In `lib/presentation/mobile/screens/dashboard/dashboard_screen.dart`, in the dashboard `AppBar`'s `actions`, add an admin-only bell with a badge. Read the unread count and gate on `voidSale`:

```dart
          if (ref.watch(currentUserProvider).value?.hasPermission(Permission.voidSale) ?? false)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.bell),
                  tooltip: 'Void requests',
                  onPressed: () => context.pushNamed(RouteNames.voidRequests),
                ),
                if (ref.watch(unreadVoidRequestCountProvider) > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${ref.watch(unreadVoidRequestCountProvider)}',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
```

Add imports if missing: `package:flutter/cupertino.dart`, `role_permissions.dart` (for `Permission`), the router (`RouteNames`/navigation), and `providers.dart`. Confirm the dashboard widget has access to `ref` (it's a `ConsumerWidget`/`ConsumerStatefulWidget`); if it's a plain `StatelessWidget`, convert to `ConsumerWidget` or wrap the actions in a `Consumer`.

- [ ] **Step 6: Analyze**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter analyze lib/presentation/mobile/screens/sales/void_requests_screen.dart lib/presentation/mobile/screens/dashboard/dashboard_screen.dart lib/config/router/app_routes.dart lib/config/router/route_guards.dart lib/config/router/route_names.dart`
Expected: No issues.

- [ ] **Step 7: Manual verification**

As **admin**: dashboard shows a bell; after a cashier submits a request the badge count increments live; tapping the bell opens Void Requests; tapping a pending row opens Approve/Reject; Approve asks for password and voids the sale (stock restored); Reject records a reason; "Mark all read" clears the badge. As **cashier/staff**: no bell on the dashboard.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/mobile/screens/sales/void_requests_screen.dart lib/presentation/mobile/screens/dashboard/dashboard_screen.dart lib/config/router/app_routes.dart lib/config/router/route_guards.dart lib/config/router/route_names.dart
git commit -m "feat(void-requests): admin notification bell + approvals screen"
```

---

## Task 11: Full verification

- [ ] **Step 1: Full Dart suite**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter test`
Expected: Only the known pre-existing failures (cart_item_tile, product_list_tile, update_product_usecase "cashier denied") — no new failures.

- [ ] **Step 2: Rules suite**

Run: `cd tools/firestore-rules-test && JAVA_HOME="$(/usr/libexec/java_home -v 19)" PATH="$JAVA_HOME/bin:$PATH" npm test`
Expected: PASS.

- [ ] **Step 3: Project analyze (changed files clean)**

Run: `export PATH="$HOME/flutter/bin:$PATH" && flutter analyze` — confirm no issues in any newly created/modified files (pre-existing project lints elsewhere are acceptable).

- [ ] **Step 4: Deploy rules (REQUIRES USER GO-AHEAD)**

Production change — confirm with the user first, then:

```bash
firebase deploy --only firestore:rules --project maki-mobile-pos
```

Verify the live ruleset contains the `void_requests` block via the Rules API.

---

## Self-Review

**Spec coverage:**
- `void_requests` collection/entity/model/repo → Tasks 1-3 ✓
- Request flow + dedupe + reason validation → Task 5 ✓
- Approve (admin executes void, admin recorded, mark approved) → Task 6 ✓
- Reject with reason → Task 6 ✓
- `VoidSaleUseCase` permission assert → Task 4 ✓
- Pending indicator (non-blocking requester UX) → Tasks 7 (stream) + 9 (UI) ✓
- Notification bell + unread count + list = queue + row detail + mark-all-read → Tasks 7 (providers) + 10 (UI) ✓
- `requestVoidSale` permission (cashier/staff) → Task 1 ✓
- Wire `canVoidSalesProvider` for the admin direct button → handled in Task 9 by gating on `hasPermission(voidSale)` (equivalent; `canVoidSalesProvider` left as-is or can be deleted — note: it stays unused, acceptable) ✓
- Firestore rules + tests → Task 8 ✓
- Audit (admin voidedBy, requester preserved) → Task 6 (voidedBy = admin) + entity keeps requester ✓
- Tests: rules + use-case unit + permission-model → Tasks 1,5,6,8 ✓; UI manual → Tasks 9,10 ✓

**Placeholder scan:** none — all code/edit steps contain full content; UI tasks include complete component code plus exact edit locations.

**Type consistency:** `VoidRequestEntity` fields and `VoidRequestStatus` are used identically across model (Task 2), repository (Task 3), use cases (Tasks 5-6), providers (Task 7), and UI (Tasks 9-10). `VoidSaleUseCase.execute` gains `required UserEntity actor` (Task 4) and is called with `actor:` from the dialog (Task 4) and the approve use case (Task 6). `UseCaseResult.successVoid()`/`failure()`/`successData()`/`fromException()` match `use_case.dart`. Repository method names (`createRequest`, `watchRequests`, `watchPendingForSale`, `hasPendingForSale`, `resolve`, `markRead`, `markAllRead`) are consistent between contract, impl, mocks, and providers.

**Note on `canVoidSalesProvider`:** Task 9 gates the admin direct-void button via `user.hasPermission(Permission.voidSale)` rather than the legacy `canVoidSalesProvider`. That provider remains unused; deleting it is optional cleanup and out of scope.
