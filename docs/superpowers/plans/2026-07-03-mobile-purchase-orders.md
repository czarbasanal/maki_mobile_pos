# Mobile Purchase Orders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A staff/admin mobile Purchase Orders feature — velocity-based reorder suggestions (adjustable window/cover) drafted into per-supplier POs that flow into the existing Receiving pipeline.

**Architecture:** New `purchase_orders` Firestore collection with entity → model → repository → Riverpod providers → three screens under `/receiving/purchase-orders`, mirroring the receiving feature's layering exactly. Receiving integration: `startReceiving` creates a prefilled receiving draft linked by a new `ReceivingEntity.purchaseOrderId`; `completeReceiving` marks the PO received in the same `WriteBatch` as the receiving's completion write.

**Tech Stack:** Flutter + Riverpod 2 + cloud_firestore + go_router; tests with flutter_test + fake_cloud_firestore + mocktail.

**Spec:** `docs/superpowers/specs/2026-07-03-mobile-purchase-orders-design.md`

## Global Constraints

- Flutter surface only (`lib/`, `test/`); `web_admin/` untouched.
- Work on branch `feat/mobile-purchase-orders` (already created).
- TDD every task: failing test → implement → pass → commit. Verify with `flutter test <file>`; full `flutter analyze` + `flutter test` in the final task.
- Tests mirror `lib/` structure under `test/`.
- **Do NOT run `firebase deploy` for rules — writing the rules block is Task 15; deploying requires explicit user confirmation.**
- Do not push to origin.
- Icons: `package:lucide_icons_flutter/lucide_icons.dart`. Cards: `AppCard` (`lib/presentation/shared/widgets/common/app_card.dart`). Colors/spacing: `package:maki_mobile_pos/core/theme/theme.dart` tokens — neutral by default, color only for status semantics.
- Suggestion math must match web (`web_admin/src/domain/reorder/computeReorderSuggestions.ts`): `velocity = unitsSold/windowDays`, `target = ceil(velocity × coverDays)`, `suggest = max(0, target − stock)`; active products only; zero suggestions excluded; supplier-name asc (nulls last), qty desc.
- PO lifecycle: `draft ⇄ ordered → received`; `cancelled` from draft/ordered; received/cancelled terminal; edits draft-only; Receive from ordered only; one delivery per PO (no partial fulfillment).

---

### Task 1: PurchaseOrderEntity

**Files:**
- Create: `lib/domain/entities/purchase_order_entity.dart`
- Modify: `lib/domain/entities/entities.dart` (add export)
- Test: `test/domain/entities/purchase_order_entity_test.dart`

**Interfaces:**
- Produces: `PurchaseOrderStatus { draft, ordered, received, cancelled }` (each with `displayName`), `PurchaseOrderItemEntity` (`id, productId, sku, name, quantity, unit, unitCost, costCode`, getter `totalCost`), `PurchaseOrderEntity` (fields below, `copyWith` with clear-flags, `recalculateTotals()`, getters `isDraft`, `canEdit`, `canReceive`).

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/entities/purchase_order_entity_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

void main() {
  PurchaseOrderItemEntity item({String id = 'p1', int qty = 2, double cost = 50}) =>
      PurchaseOrderItemEntity(
        id: id,
        productId: id,
        sku: 'SKU-$id',
        name: 'Item $id',
        quantity: qty,
        unit: 'pcs',
        unitCost: cost,
        costCode: 'AB',
      );

  PurchaseOrderEntity po({PurchaseOrderStatus status = PurchaseOrderStatus.draft}) =>
      PurchaseOrderEntity(
        id: 'po1',
        referenceNumber: 'PO-20260703-001',
        supplierId: 'sup-1',
        supplierName: 'Acme',
        items: [item(), item(id: 'p2', qty: 3, cost: 10)],
        totalCost: 0,
        totalQuantity: 0,
        status: status,
        createdAt: DateTime(2026, 7, 3),
        createdBy: 'u1',
        createdByName: 'Admin',
      );

  test('recalculateTotals sums cost and quantity from items', () {
    final r = po().recalculateTotals();
    expect(r.totalCost, 2 * 50 + 3 * 10);
    expect(r.totalQuantity, 5);
  });

  test('item totalCost is unitCost × quantity', () {
    expect(item(qty: 3, cost: 12.5).totalCost, 37.5);
  });

  test('status helpers: draft edits, ordered receives, terminal states do neither', () {
    expect(po().isDraft, isTrue);
    expect(po().canEdit, isTrue);
    expect(po().canReceive, isFalse);
    expect(po(status: PurchaseOrderStatus.ordered).canReceive, isTrue);
    expect(po(status: PurchaseOrderStatus.ordered).canEdit, isFalse);
    expect(po(status: PurchaseOrderStatus.received).canReceive, isFalse);
    expect(po(status: PurchaseOrderStatus.cancelled).canEdit, isFalse);
  });

  test('copyWith clear flags null out optional fields', () {
    final linked = po().copyWith(receivingId: 'r1', orderedAt: DateTime(2026, 7, 4));
    expect(linked.receivingId, 'r1');
    final cleared = linked.copyWith(clearReceivingId: true, clearOrderedAt: true);
    expect(cleared.receivingId, isNull);
    expect(cleared.orderedAt, isNull);
    expect(cleared.referenceNumber, 'PO-20260703-001');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/entities/purchase_order_entity_test.dart`
Expected: FAIL — `purchase_order_entity.dart` does not exist.

- [ ] **Step 3: Write the entity**

Model it on `lib/domain/entities/receiving_entity.dart` (same Equatable + clear-flag conventions):

```dart
// lib/domain/entities/purchase_order_entity.dart
import 'package:equatable/equatable.dart';

/// Status of a purchase order.
///
/// draft ⇄ ordered → received; cancelled allowed from draft/ordered.
/// received and cancelled are terminal.
enum PurchaseOrderStatus {
  draft('Draft'),
  ordered('Ordered'),
  received('Received'),
  cancelled('Cancelled');

  final String displayName;
  const PurchaseOrderStatus(this.displayName);
}

/// A planned stock purchase, drafted from reorder suggestions or manual picks.
///
/// One supplier and one delivery per PO: receiving it creates a single linked
/// receiving draft ([receivingId]); completing that receiving marks this PO
/// received. Ordered-vs-received audit = diff of this PO's items against the
/// linked receiving's items.
class PurchaseOrderEntity extends Equatable {
  final String id;
  final String referenceNumber;
  final String? supplierId;
  final String? supplierName;
  final List<PurchaseOrderItemEntity> items;
  final double totalCost;
  final int totalQuantity;
  final PurchaseOrderStatus status;
  final String? notes;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final DateTime? orderedAt;
  final DateTime? receivedAt;

  /// The receiving draft/record fulfilling this PO, once Receive was tapped.
  final String? receivingId;

  const PurchaseOrderEntity({
    required this.id,
    required this.referenceNumber,
    this.supplierId,
    this.supplierName,
    required this.items,
    required this.totalCost,
    required this.totalQuantity,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    this.orderedAt,
    this.receivedAt,
    this.receivingId,
  });

  bool get isDraft => status == PurchaseOrderStatus.draft;
  bool get canEdit => status == PurchaseOrderStatus.draft;
  bool get canReceive => status == PurchaseOrderStatus.ordered;
  bool get canCancel =>
      status == PurchaseOrderStatus.draft || status == PurchaseOrderStatus.ordered;
  int get uniqueProductCount => items.length;

  PurchaseOrderEntity copyWith({
    String? id,
    String? referenceNumber,
    String? supplierId,
    String? supplierName,
    List<PurchaseOrderItemEntity>? items,
    double? totalCost,
    int? totalQuantity,
    PurchaseOrderStatus? status,
    String? notes,
    DateTime? createdAt,
    String? createdBy,
    String? createdByName,
    DateTime? orderedAt,
    DateTime? receivedAt,
    String? receivingId,
    bool clearSupplierId = false,
    bool clearSupplierName = false,
    bool clearNotes = false,
    bool clearOrderedAt = false,
    bool clearReceivedAt = false,
    bool clearReceivingId = false,
  }) {
    return PurchaseOrderEntity(
      id: id ?? this.id,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      supplierId: clearSupplierId ? null : (supplierId ?? this.supplierId),
      supplierName: clearSupplierName ? null : (supplierName ?? this.supplierName),
      items: items ?? this.items,
      totalCost: totalCost ?? this.totalCost,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      status: status ?? this.status,
      notes: clearNotes ? null : (notes ?? this.notes),
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      orderedAt: clearOrderedAt ? null : (orderedAt ?? this.orderedAt),
      receivedAt: clearReceivedAt ? null : (receivedAt ?? this.receivedAt),
      receivingId: clearReceivingId ? null : (receivingId ?? this.receivingId),
    );
  }

  /// Recalculates totals from items.
  PurchaseOrderEntity recalculateTotals() {
    double cost = 0;
    int qty = 0;
    for (final item in items) {
      cost += item.totalCost;
      qty += item.quantity;
    }
    return copyWith(totalCost: cost, totalQuantity: qty);
  }

  @override
  List<Object?> get props => [
        id,
        referenceNumber,
        supplierId,
        supplierName,
        items,
        totalCost,
        totalQuantity,
        status,
        notes,
        createdAt,
        createdBy,
        createdByName,
        orderedAt,
        receivedAt,
        receivingId,
      ];
}

/// A line on a purchase order. Always references an existing product
/// (suggestions and search-to-add both pick from inventory).
class PurchaseOrderItemEntity extends Equatable {
  final String id;
  final String productId;
  final String sku;
  final String name;

  /// Quantity ordered.
  final int quantity;
  final String unit;

  /// Expected cost, prefilled from the product; the real cost is set on the
  /// receiving at delivery time.
  final double unitCost;
  final String costCode;

  const PurchaseOrderItemEntity({
    required this.id,
    required this.productId,
    required this.sku,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.costCode,
  });

  double get totalCost => unitCost * quantity;

  PurchaseOrderItemEntity copyWith({
    String? id,
    String? productId,
    String? sku,
    String? name,
    int? quantity,
    String? unit,
    double? unitCost,
    String? costCode,
  }) {
    return PurchaseOrderItemEntity(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
      costCode: costCode ?? this.costCode,
    );
  }

  @override
  List<Object?> get props =>
      [id, productId, sku, name, quantity, unit, unitCost, costCode];
}
```

In `lib/domain/entities/entities.dart`, add (alphabetical with the existing exports):

```dart
export 'purchase_order_entity.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/entities/purchase_order_entity_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/purchase_order_entity.dart lib/domain/entities/entities.dart test/domain/entities/purchase_order_entity_test.dart
git commit -m "feat(po): PurchaseOrderEntity with draft/ordered/received/cancelled lifecycle"
```

---

### Task 2: PurchaseOrderModel (Firestore serialization)

**Files:**
- Create: `lib/data/models/purchase_order_model.dart`
- Test: `test/data/models/purchase_order_model_test.dart`

**Interfaces:**
- Consumes: `PurchaseOrderEntity`, `PurchaseOrderItemEntity`, `PurchaseOrderStatus` (Task 1).
- Produces: `PurchaseOrderModel.fromFirestore(doc)`, `.fromMap(map, id)`, `.fromEntity(entity)`, `.toMap({bool forCreate = false})`, `.toEntity()`; `PurchaseOrderItemModel` with the same quartet. `toMap(forCreate: true)` writes `createdAt: FieldValue.serverTimestamp()`; otherwise concrete `Timestamp`s for `createdAt`/`orderedAt`/`receivedAt` when set.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/models/purchase_order_model_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/purchase_order_model.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

void main() {
  PurchaseOrderEntity entity() => PurchaseOrderEntity(
        id: 'po1',
        referenceNumber: 'PO-20260703-001',
        supplierId: 'sup-1',
        supplierName: 'Acme',
        items: const [
          PurchaseOrderItemEntity(
            id: 'p1',
            productId: 'p1',
            sku: 'SKU-1',
            name: 'Brake Pad',
            quantity: 4,
            unit: 'pcs',
            unitCost: 55,
            costCode: 'NBF',
          ),
        ],
        totalCost: 220,
        totalQuantity: 4,
        status: PurchaseOrderStatus.ordered,
        notes: 'rush',
        createdAt: DateTime(2026, 7, 3, 10),
        createdBy: 'u1',
        createdByName: 'Admin',
        orderedAt: DateTime(2026, 7, 3, 11),
        receivingId: 'r1',
      );

  test('entity -> map -> entity round-trips every field', () {
    final map = PurchaseOrderModel.fromEntity(entity()).toMap();
    final back = PurchaseOrderModel.fromMap(map, 'po1').toEntity();
    expect(back, entity());
  });

  test('toMap(forCreate) uses a server timestamp for createdAt', () {
    final map = PurchaseOrderModel.fromEntity(entity()).toMap(forCreate: true);
    expect(map['createdAt'], isA<FieldValue>());
    expect(map['status'], 'ordered');
  });

  test('fromMap tolerates missing optionals and unknown status', () {
    final back = PurchaseOrderModel.fromMap({
      'referenceNumber': 'PO-X',
      'items': <dynamic>[],
      'createdAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
    }, 'po2').toEntity();
    expect(back.status, PurchaseOrderStatus.draft);
    expect(back.supplierId, isNull);
    expect(back.orderedAt, isNull);
    expect(back.receivingId, isNull);
    expect(back.items, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/models/purchase_order_model_test.dart`
Expected: FAIL — model file does not exist.

- [ ] **Step 3: Write the model**

Mirror `lib/data/models/receiving_model.dart` exactly in shape:

```dart
// lib/data/models/purchase_order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

/// Data model for PurchaseOrder with Firestore serialization.
class PurchaseOrderModel {
  final String id;
  final String referenceNumber;
  final String? supplierId;
  final String? supplierName;
  final List<PurchaseOrderItemModel> items;
  final double totalCost;
  final int totalQuantity;
  final PurchaseOrderStatus status;
  final String? notes;
  final DateTime createdAt;
  final String createdBy;
  final String createdByName;
  final DateTime? orderedAt;
  final DateTime? receivedAt;
  final String? receivingId;

  const PurchaseOrderModel({
    required this.id,
    required this.referenceNumber,
    this.supplierId,
    this.supplierName,
    required this.items,
    required this.totalCost,
    required this.totalQuantity,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.createdBy,
    required this.createdByName,
    this.orderedAt,
    this.receivedAt,
    this.receivingId,
  });

  factory PurchaseOrderModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PurchaseOrderModel.fromMap(doc.data()!, doc.id);
  }

  factory PurchaseOrderModel.fromMap(
      Map<String, dynamic> map, String documentId) {
    final itemsList = (map['items'] as List<dynamic>?) ?? [];
    return PurchaseOrderModel(
      id: documentId,
      referenceNumber: map['referenceNumber'] as String? ?? '',
      supplierId: map['supplierId'] as String?,
      supplierName: map['supplierName'] as String?,
      items: itemsList
          .map((item) =>
              PurchaseOrderItemModel.fromMap(item as Map<String, dynamic>))
          .toList(),
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0.0,
      totalQuantity: (map['totalQuantity'] as num?)?.toInt() ?? 0,
      status: _parseStatus(map['status'] as String?),
      notes: map['notes'] as String?,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String? ?? '',
      orderedAt: _parseTimestamp(map['orderedAt']),
      receivedAt: _parseTimestamp(map['receivedAt']),
      receivingId: map['receivingId'] as String?,
    );
  }

  Map<String, dynamic> toMap({bool forCreate = false}) {
    final map = <String, dynamic>{
      'referenceNumber': referenceNumber,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': items.map((item) => item.toMap()).toList(),
      'totalCost': totalCost,
      'totalQuantity': totalQuantity,
      'status': status.name,
      'notes': notes,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'orderedAt': orderedAt != null ? Timestamp.fromDate(orderedAt!) : null,
      'receivedAt': receivedAt != null ? Timestamp.fromDate(receivedAt!) : null,
      'receivingId': receivingId,
    };
    map['createdAt'] =
        forCreate ? FieldValue.serverTimestamp() : Timestamp.fromDate(createdAt);
    return map;
  }

  PurchaseOrderEntity toEntity() {
    return PurchaseOrderEntity(
      id: id,
      referenceNumber: referenceNumber,
      supplierId: supplierId,
      supplierName: supplierName,
      items: items.map((item) => item.toEntity()).toList(),
      totalCost: totalCost,
      totalQuantity: totalQuantity,
      status: status,
      notes: notes,
      createdAt: createdAt,
      createdBy: createdBy,
      createdByName: createdByName,
      orderedAt: orderedAt,
      receivedAt: receivedAt,
      receivingId: receivingId,
    );
  }

  factory PurchaseOrderModel.fromEntity(PurchaseOrderEntity entity) {
    return PurchaseOrderModel(
      id: entity.id,
      referenceNumber: entity.referenceNumber,
      supplierId: entity.supplierId,
      supplierName: entity.supplierName,
      items: entity.items
          .map((item) => PurchaseOrderItemModel.fromEntity(item))
          .toList(),
      totalCost: entity.totalCost,
      totalQuantity: entity.totalQuantity,
      status: entity.status,
      notes: entity.notes,
      createdAt: entity.createdAt,
      createdBy: entity.createdBy,
      createdByName: entity.createdByName,
      orderedAt: entity.orderedAt,
      receivedAt: entity.receivedAt,
      receivingId: entity.receivingId,
    );
  }

  static PurchaseOrderStatus _parseStatus(String? value) {
    if (value == null) return PurchaseOrderStatus.draft;
    return PurchaseOrderStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PurchaseOrderStatus.draft,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

/// Data model for PurchaseOrderItem.
class PurchaseOrderItemModel {
  final String id;
  final String productId;
  final String sku;
  final String name;
  final int quantity;
  final String unit;
  final double unitCost;
  final String costCode;

  const PurchaseOrderItemModel({
    required this.id,
    required this.productId,
    required this.sku,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitCost,
    required this.costCode,
  });

  factory PurchaseOrderItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItemModel(
      id: map['id'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      name: map['name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? 'pcs',
      unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0.0,
      costCode: map['costCode'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'sku': sku,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'unitCost': unitCost,
      'costCode': costCode,
    };
  }

  PurchaseOrderItemEntity toEntity() {
    return PurchaseOrderItemEntity(
      id: id,
      productId: productId,
      sku: sku,
      name: name,
      quantity: quantity,
      unit: unit,
      unitCost: unitCost,
      costCode: costCode,
    );
  }

  factory PurchaseOrderItemModel.fromEntity(PurchaseOrderItemEntity entity) {
    return PurchaseOrderItemModel(
      id: entity.id,
      productId: entity.productId,
      sku: entity.sku,
      name: entity.name,
      quantity: entity.quantity,
      unit: entity.unit,
      unitCost: entity.unitCost,
      costCode: entity.costCode,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/models/purchase_order_model_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/models/purchase_order_model.dart test/data/models/purchase_order_model_test.dart
git commit -m "feat(po): PurchaseOrderModel Firestore serialization"
```

---

### Task 3: Repository interface + impl (CRUD, watch, reference numbers)

**Files:**
- Create: `lib/domain/repositories/purchase_order_repository.dart`
- Create: `lib/data/repositories/purchase_order_repository_impl.dart`
- Modify: `lib/core/constants/firestore_collections.dart` (add constant)
- Test: `test/data/repositories/purchase_order_repository_impl_test.dart`

**Interfaces:**
- Consumes: `PurchaseOrderEntity`/`Model` (Tasks 1–2), `DatabaseException` (`lib/core/errors/exceptions.dart`), `FirestoreCollections`.
- Produces:

```dart
abstract class PurchaseOrderRepository {
  Future<PurchaseOrderEntity> createPurchaseOrder(PurchaseOrderEntity po);
  Future<PurchaseOrderEntity?> getPurchaseOrderById(String id);
  Stream<PurchaseOrderEntity?> watchPurchaseOrderById(String id);
  Stream<List<PurchaseOrderEntity>> watchPurchaseOrders({int limit = 100});
  Future<PurchaseOrderEntity> updatePurchaseOrder(PurchaseOrderEntity po); // draft-only
  Future<void> markOrdered(String id);        // Task 4
  Future<void> revertToDraft(String id);      // Task 4
  Future<void> cancelPurchaseOrder(String id); // Task 4
  Future<void> deletePurchaseOrder(String id); // Task 4
  Future<String> generateReferenceNumber();   // PO-YYYYMMDD-NNN
  Future<String> startReceiving({             // Task 7
    required String purchaseOrderId,
    required String receivingReferenceNumber,
    required String createdBy,
    required String createdByName,
  });
}
```

In this task implement create/get/watch×2/update/generateReferenceNumber; declare the rest in the interface and implement them in Tasks 4 and 7 (impl may `throw UnimplementedError()` for them until their task).

- [ ] **Step 1: Add the collection constant**

In `lib/core/constants/firestore_collections.dart`, after the `receivings` constant:

```dart
  /// Purchase orders collection - planned stock purchases
  static const String purchaseOrders = 'purchase_orders';
```

- [ ] **Step 2: Write the failing test**

Mirror `test/data/repositories/receiving_repository_roundtrip_test.dart` (fake_cloud_firestore, no mocks needed — this repo has no product dependency):

```dart
// test/data/repositories/purchase_order_repository_impl_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late PurchaseOrderRepositoryImpl repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = PurchaseOrderRepositoryImpl(firestore: fake);
  });

  PurchaseOrderItemEntity item() => const PurchaseOrderItemEntity(
        id: 'p1',
        productId: 'p1',
        sku: 'SKU-1',
        name: 'Brake Pad',
        quantity: 4,
        unit: 'pcs',
        unitCost: 55,
        costCode: 'NBF',
      );

  PurchaseOrderEntity draft({String ref = 'PO-20260703-001'}) =>
      PurchaseOrderEntity(
        id: '',
        referenceNumber: ref,
        supplierId: 'sup-1',
        supplierName: 'Acme',
        items: [item()],
        totalCost: 220,
        totalQuantity: 4,
        status: PurchaseOrderStatus.draft,
        createdAt: DateTime(2026, 7, 3),
        createdBy: 'u1',
        createdByName: 'Admin',
      );

  test('createPurchaseOrder -> getPurchaseOrderById round-trips items', () async {
    final created = await repo.createPurchaseOrder(draft());
    expect(created.id, isNotEmpty);

    final loaded = await repo.getPurchaseOrderById(created.id);
    expect(loaded, isNotNull);
    expect(loaded!.referenceNumber, 'PO-20260703-001');
    expect(loaded.items, hasLength(1));
    expect(loaded.items.first.name, 'Brake Pad');
    expect(loaded.status, PurchaseOrderStatus.draft);
  });

  test('watchPurchaseOrders emits newest first', () async {
    await repo.createPurchaseOrder(draft());
    await repo.createPurchaseOrder(draft(ref: 'PO-20260703-002'));

    final list = await repo.watchPurchaseOrders().first;
    expect(list, hasLength(2));
  });

  test('watchPurchaseOrderById emits the doc and null for missing', () async {
    final created = await repo.createPurchaseOrder(draft());
    final po = await repo.watchPurchaseOrderById(created.id).first;
    expect(po!.referenceNumber, 'PO-20260703-001');

    final missing = await repo.watchPurchaseOrderById('nope').first;
    expect(missing, isNull);
  });

  test('updatePurchaseOrder rewrites items on a draft', () async {
    final created = await repo.createPurchaseOrder(draft());
    final updated = await repo.updatePurchaseOrder(
      created.copyWith(items: [item().copyWith(quantity: 9)]).recalculateTotals(),
    );
    expect(updated.items.first.quantity, 9);
    expect(updated.totalQuantity, 9);
  });

  test('updatePurchaseOrder rejects non-draft POs', () async {
    final created = await repo.createPurchaseOrder(draft());
    await fake
        .collection('purchase_orders')
        .doc(created.id)
        .update({'status': 'ordered'});

    expect(
      () => repo.updatePurchaseOrder(created.copyWith(notes: 'x')),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('generateReferenceNumber is PO-YYYYMMDD-NNN and increments', () async {
    final first = await repo.generateReferenceNumber();
    expect(first, matches(RegExp(r'^PO-\d{8}-001$')));

    await repo.createPurchaseOrder(draft().copyWith(createdAt: DateTime.now()));
    final second = await repo.generateReferenceNumber();
    expect(second, endsWith('-002'));
  });
}
```

Note: `generateReferenceNumber` counts today's POs via a `createdAt` range query, and `createPurchaseOrder` writes `createdAt` as a server timestamp — so the seeded PO in the last test lands "today" and the count increments. This mirrors the receiving implementation.

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/data/repositories/purchase_order_repository_impl_test.dart`
Expected: FAIL — repository files do not exist.

- [ ] **Step 4: Write interface and impl**

```dart
// lib/domain/repositories/purchase_order_repository.dart
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

/// Repository contract for purchase orders.
abstract class PurchaseOrderRepository {
  /// Creates a purchase order, returning it with its generated id.
  Future<PurchaseOrderEntity> createPurchaseOrder(PurchaseOrderEntity po);

  Future<PurchaseOrderEntity?> getPurchaseOrderById(String id);

  /// Streams a single purchase order (null once deleted / missing).
  Stream<PurchaseOrderEntity?> watchPurchaseOrderById(String id);

  /// Streams recent purchase orders, newest first.
  Stream<List<PurchaseOrderEntity>> watchPurchaseOrders({int limit = 100});

  /// Rewrites a draft purchase order. Throws for non-draft statuses.
  Future<PurchaseOrderEntity> updatePurchaseOrder(PurchaseOrderEntity po);

  /// draft → ordered (stamps orderedAt).
  Future<void> markOrdered(String id);

  /// ordered → draft (clears orderedAt).
  Future<void> revertToDraft(String id);

  /// draft/ordered → cancelled.
  Future<void> cancelPurchaseOrder(String id);

  /// Deletes the purchase order document (admin-gated in UI and rules).
  Future<void> deletePurchaseOrder(String id);

  /// Next `PO-YYYYMMDD-NNN` reference for today.
  Future<String> generateReferenceNumber();

  /// Creates a draft receiving prefilled from an ordered PO's items and links
  /// it (batch: receiving create + PO.receivingId), returning the receiving id.
  /// Idempotent: a still-draft linked receiving is returned instead of
  /// creating a second one.
  Future<String> startReceiving({
    required String purchaseOrderId,
    required String receivingReferenceNumber,
    required String createdBy,
    required String createdByName,
  });
}
```

```dart
// lib/data/repositories/purchase_order_repository_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/purchase_order_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/purchase_order_repository.dart';

/// Firestore implementation of [PurchaseOrderRepository].
class PurchaseOrderRepositoryImpl implements PurchaseOrderRepository {
  final FirebaseFirestore _firestore;

  PurchaseOrderRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      _firestore.collection(FirestoreCollections.purchaseOrders);

  @override
  Future<PurchaseOrderEntity> createPurchaseOrder(PurchaseOrderEntity po) async {
    try {
      final model = PurchaseOrderModel.fromEntity(po);
      final docRef = await _ordersRef.add(model.toMap(forCreate: true));
      return po.copyWith(id: docRef.id);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create purchase order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<PurchaseOrderEntity?> getPurchaseOrderById(String id) async {
    try {
      final doc = await _ordersRef.doc(id).get();
      if (!doc.exists) return null;
      return PurchaseOrderModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get purchase order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Stream<PurchaseOrderEntity?> watchPurchaseOrderById(String id) {
    return _ordersRef.doc(id).snapshots().map((doc) =>
        doc.exists ? PurchaseOrderModel.fromFirestore(doc).toEntity() : null);
  }

  @override
  Stream<List<PurchaseOrderEntity>> watchPurchaseOrders({int limit = 100}) {
    return _ordersRef
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PurchaseOrderModel.fromFirestore(doc).toEntity())
            .toList());
  }

  @override
  Future<PurchaseOrderEntity> updatePurchaseOrder(PurchaseOrderEntity po) async {
    try {
      final current = await getPurchaseOrderById(po.id);
      if (current == null) {
        throw const DatabaseException(message: 'Purchase order not found');
      }
      if (current.status != PurchaseOrderStatus.draft) {
        throw const DatabaseException(
            message: 'Only draft purchase orders can be edited');
      }
      final model = PurchaseOrderModel.fromEntity(po);
      await _ordersRef.doc(po.id).update(model.toMap());
      final updated = await getPurchaseOrderById(po.id);
      if (updated == null) {
        throw const DatabaseException(
            message: 'Purchase order not found after update');
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update purchase order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<String> generateReferenceNumber() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    // Same approach as receivings: count today's docs with a plain range
    // query (aggregation queries need an index and have bitten us before).
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _ordersRef
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    final sequence = snapshot.size + 1;
    return 'PO-$dateStr-${sequence.toString().padLeft(3, '0')}';
  }

  // Implemented in Task 4.
  @override
  Future<void> markOrdered(String id) => throw UnimplementedError();
  @override
  Future<void> revertToDraft(String id) => throw UnimplementedError();
  @override
  Future<void> cancelPurchaseOrder(String id) => throw UnimplementedError();
  @override
  Future<void> deletePurchaseOrder(String id) => throw UnimplementedError();

  // Implemented in Task 7.
  @override
  Future<String> startReceiving({
    required String purchaseOrderId,
    required String receivingReferenceNumber,
    required String createdBy,
    required String createdByName,
  }) =>
      throw UnimplementedError();
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/data/repositories/purchase_order_repository_impl_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/core/constants/firestore_collections.dart lib/domain/repositories/purchase_order_repository.dart lib/data/repositories/purchase_order_repository_impl.dart test/data/repositories/purchase_order_repository_impl_test.dart
git commit -m "feat(po): purchase order repository - CRUD, watch, PO reference numbers"
```

---

### Task 4: Status transitions

**Files:**
- Modify: `lib/data/repositories/purchase_order_repository_impl.dart` (replace the four `UnimplementedError` stubs)
- Test: `test/data/repositories/purchase_order_transitions_test.dart`

**Interfaces:**
- Produces working `markOrdered`, `revertToDraft`, `cancelPurchaseOrder`, `deletePurchaseOrder` with lifecycle guards.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/repositories/purchase_order_transitions_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late PurchaseOrderRepositoryImpl repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = PurchaseOrderRepositoryImpl(firestore: fake);
  });

  Future<PurchaseOrderEntity> seed() => repo.createPurchaseOrder(
        PurchaseOrderEntity(
          id: '',
          referenceNumber: 'PO-20260703-001',
          items: const [
            PurchaseOrderItemEntity(
              id: 'p1',
              productId: 'p1',
              sku: 'SKU-1',
              name: 'Brake Pad',
              quantity: 4,
              unit: 'pcs',
              unitCost: 55,
              costCode: 'NBF',
            ),
          ],
          totalCost: 220,
          totalQuantity: 4,
          status: PurchaseOrderStatus.draft,
          createdAt: DateTime(2026, 7, 3),
          createdBy: 'u1',
          createdByName: 'Admin',
        ),
      );

  test('markOrdered: draft -> ordered with orderedAt', () async {
    final po = await seed();
    await repo.markOrdered(po.id);
    final loaded = await repo.getPurchaseOrderById(po.id);
    expect(loaded!.status, PurchaseOrderStatus.ordered);
    expect(loaded.orderedAt, isNotNull);
  });

  test('markOrdered rejects non-draft', () async {
    final po = await seed();
    await repo.markOrdered(po.id);
    expect(() => repo.markOrdered(po.id), throwsA(isA<DatabaseException>()));
  });

  test('revertToDraft: ordered -> draft clearing orderedAt', () async {
    final po = await seed();
    await repo.markOrdered(po.id);
    await repo.revertToDraft(po.id);
    final loaded = await repo.getPurchaseOrderById(po.id);
    expect(loaded!.status, PurchaseOrderStatus.draft);
    expect(loaded.orderedAt, isNull);
  });

  test('revertToDraft rejects a draft', () async {
    final po = await seed();
    expect(() => repo.revertToDraft(po.id), throwsA(isA<DatabaseException>()));
  });

  test('cancel allowed from draft and ordered, not from cancelled', () async {
    final po = await seed();
    await repo.cancelPurchaseOrder(po.id);
    final loaded = await repo.getPurchaseOrderById(po.id);
    expect(loaded!.status, PurchaseOrderStatus.cancelled);
    expect(() => repo.cancelPurchaseOrder(po.id),
        throwsA(isA<DatabaseException>()));
  });

  test('delete removes the doc', () async {
    final po = await seed();
    await repo.deletePurchaseOrder(po.id);
    expect(await repo.getPurchaseOrderById(po.id), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repositories/purchase_order_transitions_test.dart`
Expected: FAIL — `UnimplementedError`.

- [ ] **Step 3: Implement the transitions**

Replace the four stubs in `purchase_order_repository_impl.dart`:

```dart
  Future<PurchaseOrderEntity> _requireStatus(
    String id,
    Set<PurchaseOrderStatus> allowed,
    String action,
  ) async {
    final po = await getPurchaseOrderById(id);
    if (po == null) {
      throw const DatabaseException(message: 'Purchase order not found');
    }
    if (!allowed.contains(po.status)) {
      throw DatabaseException(
          message: 'Cannot $action a ${po.status.displayName} purchase order');
    }
    return po;
  }

  @override
  Future<void> markOrdered(String id) async {
    try {
      await _requireStatus(id, {PurchaseOrderStatus.draft}, 'order');
      await _ordersRef.doc(id).update({
        'status': PurchaseOrderStatus.ordered.name,
        'orderedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to mark purchase order ordered: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> revertToDraft(String id) async {
    try {
      await _requireStatus(id, {PurchaseOrderStatus.ordered}, 'reopen');
      await _ordersRef.doc(id).update({
        'status': PurchaseOrderStatus.draft.name,
        'orderedAt': null,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to revert purchase order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> cancelPurchaseOrder(String id) async {
    try {
      await _requireStatus(
        id,
        {PurchaseOrderStatus.draft, PurchaseOrderStatus.ordered},
        'cancel',
      );
      await _ordersRef.doc(id).update({
        'status': PurchaseOrderStatus.cancelled.name,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to cancel purchase order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> deletePurchaseOrder(String id) async {
    try {
      await _ordersRef.doc(id).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete purchase order: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/repositories/purchase_order_transitions_test.dart`
Expected: PASS (6 tests). Also run Task 3's file to confirm no regression.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/purchase_order_repository_impl.dart test/data/repositories/purchase_order_transitions_test.dart
git commit -m "feat(po): status transitions with lifecycle guards"
```

---

### Task 5: Reorder suggestion math (port of the web engine)

**Files:**
- Create: `lib/core/utils/reorder_suggestions.dart`
- Test: `test/core/utils/reorder_suggestions_test.dart`

**Interfaces:**
- Consumes: `ProductEntity` (fields `id, sku, name, cost, costCode, quantity, unit, isActive, supplierId, supplierName`), `SaleEntity.items` (`SaleItemEntity.productId/.quantity`).
- Produces:

```dart
typedef ReorderParams = ({int windowDays, int coverDays});
class ReorderSuggestion { ProductEntity product; double velocityPerDay; int targetStock; int suggestedQty; String? get supplierName; }
Map<String, int> unitsSoldByProduct(List<SaleEntity> sales);
List<ReorderSuggestion> computeReorderSuggestions(List<ProductEntity> products, Map<String, int> unitsSold, ReorderParams params);
```

`ReorderParams` is a record so it has value equality (needed as a Riverpod family key in Task 9).

- [ ] **Step 1: Write the failing test** (port of `web_admin/src/domain/reorder/computeReorderSuggestions.test.ts`, plus `unitsSoldByProduct`)

```dart
// test/core/utils/reorder_suggestions_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/reorder_suggestions.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';

void main() {
  ProductEntity product({
    String id = 'p1',
    int quantity = 0,
    bool isActive = true,
    String? supplierName = 'Acme',
  }) =>
      ProductEntity(
        id: id,
        sku: 'SKU-$id',
        name: 'Item $id',
        cost: 100,
        costCode: 'AB',
        price: 150,
        quantity: quantity,
        reorderLevel: 2,
        unit: 'pcs',
        supplierId: supplierName == null ? null : 'sup-1',
        supplierName: supplierName,
        isActive: isActive,
        createdAt: DateTime(2026, 1, 1),
      );

  const params = (windowDays: 30, coverDays: 14);

  test('suggests velocity × cover − stock', () {
    // 30 units / 30 days = 1/day × 14 cover = target 14, stock 5 → suggest 9.
    final out = computeReorderSuggestions(
        [product(quantity: 5)], {'p1': 30}, params);
    expect(out, hasLength(1));
    expect(out.first.velocityPerDay, 1);
    expect(out.first.targetStock, 14);
    expect(out.first.suggestedQty, 9);
  });

  test('rounds the target up (ceil)', () {
    // 10 / 30 = 0.333/day × 14 = 4.66 → ceil 5; stock 0 → 5.
    final out = computeReorderSuggestions([product()], {'p1': 10}, params);
    expect(out.first.targetStock, 5);
    expect(out.first.suggestedQty, 5);
  });

  test('excludes zero-velocity and already-stocked products', () {
    final out = computeReorderSuggestions(
      [product(id: 'dead'), product(id: 'full', quantity: 999)],
      {'full': 30},
      params,
    );
    expect(out, isEmpty);
  });

  test('skips inactive products; sorts supplier asc then qty desc', () {
    final out = computeReorderSuggestions(
      [
        product(id: 'p1', supplierName: 'Beta'),
        product(id: 'p2', supplierName: 'Acme'),
        product(id: 'gone', isActive: false),
      ],
      {'p1': 30, 'p2': 60, 'gone': 60},
      params,
    );
    expect(out.map((s) => s.product.id).toList(), ['p2', 'p1']);
    expect(out.first.supplierName, 'Acme');
  });

  test('null supplier sorts last', () {
    final out = computeReorderSuggestions(
      [
        product(id: 'nosup', supplierName: null),
        product(id: 'acme', supplierName: 'Acme'),
      ],
      {'nosup': 30, 'acme': 30},
      params,
    );
    expect(out.map((s) => s.product.id).toList(), ['acme', 'nosup']);
    expect(out.last.supplierName, isNull);
  });
}
```

If `ProductEntity`'s constructor requires other parameters than shown, open `lib/domain/entities/product_entity.dart` and satisfy them with obvious defaults in the `product()` helper — keep the fields the test asserts on unchanged.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/reorder_suggestions_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/core/utils/reorder_suggestions.dart
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/sale_entity.dart';

/// Movement window and days-of-stock-to-cover for reorder suggestions.
/// A record so it carries value equality (used as a provider-family key).
typedef ReorderParams = ({int windowDays, int coverDays});

/// One suggested order line. Mirrors the web engine
/// (web_admin/src/domain/reorder/computeReorderSuggestions.ts).
class ReorderSuggestion extends Equatable {
  final ProductEntity product;
  final double velocityPerDay;
  final int targetStock;
  final int suggestedQty;

  const ReorderSuggestion({
    required this.product,
    required this.velocityPerDay,
    required this.targetStock,
    required this.suggestedQty,
  });

  String? get supplierName => product.supplierName;

  @override
  List<Object?> get props => [product, velocityPerDay, targetStock, suggestedQty];
}

/// Sums quantity sold per productId across [sales] (pass completed sales only).
Map<String, int> unitsSoldByProduct(List<SaleEntity> sales) {
  final out = <String, int>{};
  for (final sale in sales) {
    for (final item in sale.items) {
      out[item.productId] = (out[item.productId] ?? 0) + item.quantity;
    }
  }
  return out;
}

/// Suggests an order quantity per active product purely from stock movement
/// and remaining stock:
///   velocity = unitsSold(window) / windowDays
///   target   = ceil(velocity × coverDays)
///   suggest  = max(0, target − currentStock)
/// Products with no recent sales (velocity 0) or enough stock are excluded.
/// Grouped/sorted by the product's supplier name (no-supplier last), qty desc.
List<ReorderSuggestion> computeReorderSuggestions(
  List<ProductEntity> products,
  Map<String, int> unitsSold,
  ReorderParams params,
) {
  final out = <ReorderSuggestion>[];

  for (final product in products) {
    if (!product.isActive) continue;
    final velocityPerDay =
        (unitsSold[product.id] ?? 0) / params.windowDays;
    final targetStock = (velocityPerDay * params.coverDays).ceil();
    final suggestedQty = math.max(0, targetStock - product.quantity);
    if (suggestedQty <= 0) continue;
    out.add(ReorderSuggestion(
      product: product,
      velocityPerDay: velocityPerDay,
      targetStock: targetStock,
      suggestedQty: suggestedQty,
    ));
  }

  out.sort((a, b) {
    final sa = a.supplierName ?? '\u{10FFFF}'; // nulls sort last
    final sb = b.supplierName ?? '\u{10FFFF}';
    if (sa != sb) return sa.compareTo(sb);
    return b.suggestedQty - a.suggestedQty;
  });
  return out;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/reorder_suggestions_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/reorder_suggestions.dart test/core/utils/reorder_suggestions_test.dart
git commit -m "feat(po): reorder suggestion math - Dart port of the web engine"
```

---

### Task 6: `ReceivingEntity.purchaseOrderId`

**Files:**
- Modify: `lib/domain/entities/receiving_entity.dart` (field + copyWith + props)
- Modify: `lib/data/models/receiving_model.dart` (field + fromMap/toMap/fromEntity/toEntity)
- Test: `test/data/models/receiving_model_purchase_order_id_test.dart`

**Interfaces:**
- Produces: `ReceivingEntity.purchaseOrderId` (`String?`), `copyWith(purchaseOrderId: …, clearPurchaseOrderId: true)`; serialized as `purchaseOrderId` on the receiving doc.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/models/receiving_model_purchase_order_id_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/receiving_model.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';

void main() {
  ReceivingEntity receiving({String? poId}) => ReceivingEntity(
        id: 'r1',
        referenceNumber: 'RCV-1',
        items: const [],
        totalCost: 0,
        totalQuantity: 0,
        status: ReceivingStatus.draft,
        createdAt: DateTime(2026, 7, 3),
        createdBy: 'u1',
        createdByName: 'Admin',
        purchaseOrderId: poId,
      );

  test('purchaseOrderId round-trips through the model', () {
    final map = ReceivingModel.fromEntity(receiving(poId: 'po1')).toMap();
    expect(map['purchaseOrderId'], 'po1');
    final back = ReceivingModel.fromMap(map, 'r1').toEntity();
    expect(back.purchaseOrderId, 'po1');
  });

  test('absent purchaseOrderId stays null (old docs unaffected)', () {
    final map = ReceivingModel.fromEntity(receiving()).toMap();
    final back = ReceivingModel.fromMap(map, 'r1').toEntity();
    expect(back.purchaseOrderId, isNull);
  });

  test('copyWith carries and clears the link', () {
    final linked = receiving().copyWith(purchaseOrderId: 'po1');
    expect(linked.purchaseOrderId, 'po1');
    expect(linked.copyWith(clearPurchaseOrderId: true).purchaseOrderId, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/models/receiving_model_purchase_order_id_test.dart`
Expected: FAIL — no such named parameter `purchaseOrderId`.

- [ ] **Step 3: Add the field**

In `lib/domain/entities/receiving_entity.dart`, on `ReceivingEntity`:
- Add field + doc after `completedBy`:

```dart
  /// The purchase order this receiving fulfills, when it was started from one.
  final String? purchaseOrderId;
```

- Add `this.purchaseOrderId,` to the constructor.
- In `copyWith`, add parameters `String? purchaseOrderId` and `bool clearPurchaseOrderId = false`, and in the body:

```dart
      purchaseOrderId: clearPurchaseOrderId
          ? null
          : (purchaseOrderId ?? this.purchaseOrderId),
```

- Append `purchaseOrderId` to `props`.

In `lib/data/models/receiving_model.dart`, on `ReceivingModel`:
- Add `final String? purchaseOrderId;` + constructor param `this.purchaseOrderId,`.
- `fromMap`: `purchaseOrderId: map['purchaseOrderId'] as String?,`
- `toMap` (in the always-written map at the top): `'purchaseOrderId': purchaseOrderId,`
- `toEntity`/`fromEntity`: pass it through.

- [ ] **Step 4: Run test + existing receiving tests**

Run: `flutter test test/data/models/receiving_model_purchase_order_id_test.dart test/data/repositories/receiving_repository_roundtrip_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/receiving_entity.dart lib/data/models/receiving_model.dart test/data/models/receiving_model_purchase_order_id_test.dart
git commit -m "feat(po): link field purchaseOrderId on receivings"
```

---

### Task 7: `startReceiving` — PO → receiving draft (batch + idempotence)

**Files:**
- Modify: `lib/data/repositories/purchase_order_repository_impl.dart` (replace the `startReceiving` stub; add imports for `ReceivingModel`)
- Test: `test/data/repositories/purchase_order_start_receiving_test.dart`

**Interfaces:**
- Consumes: `ReceivingEntity`/`ReceivingModel` (with `purchaseOrderId`, Task 6), `FirestoreCollections.receivings`.
- Produces: working `startReceiving(...) → Future<String>` per the interface doc in Task 3.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/repositories/purchase_order_start_receiving_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late PurchaseOrderRepositoryImpl repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = PurchaseOrderRepositoryImpl(firestore: fake);
  });

  Future<PurchaseOrderEntity> orderedPo() async {
    final po = await repo.createPurchaseOrder(
      PurchaseOrderEntity(
        id: '',
        referenceNumber: 'PO-20260703-001',
        supplierId: 'sup-1',
        supplierName: 'Acme',
        items: const [
          PurchaseOrderItemEntity(
            id: 'p1',
            productId: 'p1',
            sku: 'SKU-1',
            name: 'Brake Pad',
            quantity: 4,
            unit: 'pcs',
            unitCost: 55,
            costCode: 'NBF',
          ),
        ],
        totalCost: 220,
        totalQuantity: 4,
        status: PurchaseOrderStatus.draft,
        createdAt: DateTime(2026, 7, 3),
        createdBy: 'u1',
        createdByName: 'Admin',
      ),
    );
    await repo.markOrdered(po.id);
    return (await repo.getPurchaseOrderById(po.id))!;
  }

  Future<String> start(String poId) => repo.startReceiving(
        purchaseOrderId: poId,
        receivingReferenceNumber: 'RCV-20260703-001',
        createdBy: 'u1',
        createdByName: 'Admin',
      );

  test('creates a linked draft receiving prefilled from the PO', () async {
    final po = await orderedPo();
    final receivingId = await start(po.id);

    final receiving =
        await fake.collection('receivings').doc(receivingId).get();
    expect(receiving.exists, isTrue);
    expect(receiving.data()!['status'], 'draft');
    expect(receiving.data()!['purchaseOrderId'], po.id);
    expect(receiving.data()!['supplierName'], 'Acme');
    final items = receiving.data()!['items'] as List<dynamic>;
    expect(items, hasLength(1));
    expect((items.first as Map<String, dynamic>)['quantity'], 4);
    expect((items.first as Map<String, dynamic>)['unitCost'], 55);

    final linked = await repo.getPurchaseOrderById(po.id);
    expect(linked!.receivingId, receivingId);
    expect(linked.status, PurchaseOrderStatus.ordered,
        reason: 'received only when the receiving completes');
  });

  test('is idempotent while the linked receiving is still a draft', () async {
    final po = await orderedPo();
    final first = await start(po.id);
    final second = await start(po.id);
    expect(second, first);
    final receivings = await fake.collection('receivings').get();
    expect(receivings.size, 1);
  });

  test('creates a fresh receiving when the linked one was cancelled', () async {
    final po = await orderedPo();
    final first = await start(po.id);
    await fake
        .collection('receivings')
        .doc(first)
        .update({'status': 'cancelled'});

    final second = await start(po.id);
    expect(second, isNot(first));
  });

  test('rejects draft POs', () async {
    final po = await repo.createPurchaseOrder(
      (await orderedPo()).copyWith(id: '', referenceNumber: 'PO-X'),
    );
    // po is a fresh draft (createPurchaseOrder writes, status stays as given —
    // build one directly in draft):
    expect(() => start(po.id), throwsA(isA<DatabaseException>()));
  });
}
```

Note on the last test: `createPurchaseOrder` persists whatever status the entity carries; copying an ordered PO with a new id keeps `status: ordered`. Adjust it to explicitly build a draft: `copyWith(id: '', referenceNumber: 'PO-X', status: PurchaseOrderStatus.draft, clearOrderedAt: true)`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repositories/purchase_order_start_receiving_test.dart`
Expected: FAIL — `UnimplementedError`.

- [ ] **Step 3: Implement `startReceiving`**

Add imports to `purchase_order_repository_impl.dart`:

```dart
import 'package:maki_mobile_pos/data/models/receiving_model.dart';
```

(`ReceivingEntity` etc. already come via `entities.dart`.) Replace the stub:

```dart
  @override
  Future<String> startReceiving({
    required String purchaseOrderId,
    required String receivingReferenceNumber,
    required String createdBy,
    required String createdByName,
  }) async {
    try {
      final po = await getPurchaseOrderById(purchaseOrderId);
      if (po == null) {
        throw const DatabaseException(message: 'Purchase order not found');
      }
      if (po.status != PurchaseOrderStatus.ordered) {
        throw const DatabaseException(
            message: 'Only ordered purchase orders can be received');
      }

      final receivingsRef =
          _firestore.collection(FirestoreCollections.receivings);

      // Idempotence: if a linked receiving is still an open draft, resume it
      // instead of creating a duplicate.
      if (po.receivingId != null) {
        final existing = await receivingsRef.doc(po.receivingId!).get();
        if (existing.exists &&
            existing.data()?['status'] == ReceivingStatus.draft.name) {
          return po.receivingId!;
        }
      }

      final receivingRef = receivingsRef.doc();
      final receiving = ReceivingEntity(
        id: receivingRef.id,
        referenceNumber: receivingReferenceNumber,
        supplierId: po.supplierId,
        supplierName: po.supplierName,
        items: po.items
            .map((i) => ReceivingItemEntity(
                  id: i.id,
                  productId: i.productId,
                  sku: i.sku,
                  name: i.name,
                  quantity: i.quantity,
                  unit: i.unit,
                  unitCost: i.unitCost,
                  costCode: i.costCode,
                ))
            .toList(),
        totalCost: po.totalCost,
        totalQuantity: po.totalQuantity,
        status: ReceivingStatus.draft,
        notes: 'From ${po.referenceNumber}',
        createdAt: DateTime.now(),
        createdBy: createdBy,
        createdByName: createdByName,
        purchaseOrderId: po.id,
      );

      final batch = _firestore.batch();
      batch.set(receivingRef,
          ReceivingModel.fromEntity(receiving).toMap(forCreate: true));
      batch.update(_ordersRef.doc(po.id), {'receivingId': receivingRef.id});
      await batch.commit();
      return receivingRef.id;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to start receiving: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/repositories/purchase_order_start_receiving_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/purchase_order_repository_impl.dart test/data/repositories/purchase_order_start_receiving_test.dart
git commit -m "feat(po): startReceiving creates a linked receiving draft atomically"
```

---

### Task 8: Receiving completion marks the PO received; cancel/delete clear the link

**Files:**
- Modify: `lib/data/repositories/receiving_repository_impl.dart` (`completeReceiving` tail, `cancelReceiving`, `deleteReceiving`)
- Test: `test/data/repositories/receiving_purchase_order_link_test.dart`

**Interfaces:**
- Consumes: `ReceivingEntity.purchaseOrderId` (Task 6), `PurchaseOrderStatus` / `FirestoreCollections.purchaseOrders`.
- Produces: completing a linked receiving batch-writes `{status: received, receivedAt, receivingId}` on the PO; a missing/already-received PO never blocks completion; cancel/delete of a linked draft receiving clears `PO.receivingId` when it points at that receiving. Receivings without the link behave exactly as before.

- [ ] **Step 1: Write the failing test**

```dart
// test/data/repositories/receiving_purchase_order_link_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/data/repositories/receiving_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

void main() {
  late FakeFirebaseFirestore fake;
  late PurchaseOrderRepositoryImpl poRepo;
  late ReceivingRepositoryImpl receivingRepo;
  late _MockProductRepository productRepo;

  final product = ProductEntity(
    id: 'p1',
    sku: 'SKU-1',
    name: 'Brake Pad',
    cost: 55,
    costCode: 'NBF',
    price: 80,
    quantity: 2,
    reorderLevel: 2,
    unit: 'pcs',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    fake = FakeFirebaseFirestore();
    poRepo = PurchaseOrderRepositoryImpl(firestore: fake);
    productRepo = _MockProductRepository();
    receivingRepo = ReceivingRepositoryImpl(
      firestore: fake,
      productRepository: productRepo,
    );
    when(() => productRepo.getProductById('p1'))
        .thenAnswer((_) async => product);
    when(() => productRepo.updateStock(
          productId: any(named: 'productId'),
          quantityChange: any(named: 'quantityChange'),
          updatedBy: any(named: 'updatedBy'),
          updatedByName: any(named: 'updatedByName'),
        )).thenAnswer((_) async => product);
  });

  Future<({String poId, String receivingId})> linkedPair() async {
    final po = await poRepo.createPurchaseOrder(PurchaseOrderEntity(
      id: '',
      referenceNumber: 'PO-20260703-001',
      items: const [
        PurchaseOrderItemEntity(
          id: 'p1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Brake Pad',
          quantity: 4,
          unit: 'pcs',
          unitCost: 55,
          costCode: 'NBF',
        ),
      ],
      totalCost: 220,
      totalQuantity: 4,
      status: PurchaseOrderStatus.draft,
      createdAt: DateTime(2026, 7, 3),
      createdBy: 'u1',
      createdByName: 'Admin',
    ));
    await poRepo.markOrdered(po.id);
    final receivingId = await poRepo.startReceiving(
      purchaseOrderId: po.id,
      receivingReferenceNumber: 'RCV-20260703-001',
      createdBy: 'u1',
      createdByName: 'Admin',
    );
    return (poId: po.id, receivingId: receivingId);
  }

  test('completing a linked receiving marks the PO received', () async {
    final pair = await linkedPair();
    await receivingRepo.completeReceiving(
      receivingId: pair.receivingId,
      completedBy: 'u1',
      completedByName: 'Admin',
    );

    final po = await poRepo.getPurchaseOrderById(pair.poId);
    expect(po!.status, PurchaseOrderStatus.received);
    expect(po.receivedAt, isNotNull);
    expect(po.receivingId, pair.receivingId);

    final receiving =
        await receivingRepo.getReceivingById(pair.receivingId);
    expect(receiving!.status, ReceivingStatus.completed);
  });

  test('a deleted PO does not block completion', () async {
    final pair = await linkedPair();
    await poRepo.deletePurchaseOrder(pair.poId);

    await receivingRepo.completeReceiving(
      receivingId: pair.receivingId,
      completedBy: 'u1',
    );
    final receiving =
        await receivingRepo.getReceivingById(pair.receivingId);
    expect(receiving!.status, ReceivingStatus.completed);
  });

  test('cancelReceiving clears the PO link so Receive can retry', () async {
    final pair = await linkedPair();
    await receivingRepo.cancelReceiving(
      receivingId: pair.receivingId,
      cancelledBy: 'u1',
    );
    final po = await poRepo.getPurchaseOrderById(pair.poId);
    expect(po!.receivingId, isNull);
    expect(po.status, PurchaseOrderStatus.ordered);
  });

  test('deleteReceiving clears the PO link', () async {
    final pair = await linkedPair();
    await receivingRepo.deleteReceiving(pair.receivingId);
    final po = await poRepo.getPurchaseOrderById(pair.poId);
    expect(po!.receivingId, isNull);
  });

  test('unlinked receivings complete exactly as before', () async {
    final created = await receivingRepo.createReceiving(ReceivingEntity(
      id: '',
      referenceNumber: 'RCV-plain',
      items: const [
        ReceivingItemEntity(
          id: 'li-1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Brake Pad',
          quantity: 3,
          unit: 'pcs',
          unitCost: 55,
          costCode: 'NBF',
        ),
      ],
      totalCost: 165,
      totalQuantity: 3,
      status: ReceivingStatus.draft,
      createdAt: DateTime(2026, 7, 3),
      createdBy: 'u1',
      createdByName: 'Admin',
    ));
    final done = await receivingRepo.completeReceiving(
      receivingId: created.id,
      completedBy: 'u1',
    );
    expect(done.status, ReceivingStatus.completed);
  });
}
```

If `ProductEntity`/`updateStock` signatures differ, open `lib/domain/repositories/product_repository.dart` and match the mock to the real named parameters; keep assertions unchanged.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/repositories/receiving_purchase_order_link_test.dart`
Expected: the two "clears the PO link" tests and the "marks the PO received" test FAIL (link never written/cleared); the unlinked test passes.

- [ ] **Step 3: Implement in `ReceivingRepositoryImpl`**

Add import:

```dart
import 'package:maki_mobile_pos/data/models/purchase_order_model.dart';
```

(only if needed for status names — otherwise use `PurchaseOrderStatus` from `entities.dart`, already imported).

In `completeReceiving`, replace the final `return updateReceiving(completedReceiving);` with:

```dart
      if (receiving.purchaseOrderId == null) {
        return updateReceiving(completedReceiving);
      }
      return _completeLinkedToPurchaseOrder(completedReceiving);
```

Add the private method:

```dart
  /// Completes a receiving that fulfills a purchase order: the receiving's
  /// completion write and the PO's received-mark land in one WriteBatch so
  /// the pair can't diverge. A PO that was deleted or already received must
  /// not block completion — it is simply skipped.
  Future<ReceivingEntity> _completeLinkedToPurchaseOrder(
      ReceivingEntity receiving) async {
    final poRef = _firestore
        .collection(FirestoreCollections.purchaseOrders)
        .doc(receiving.purchaseOrderId!);
    final poSnap = await poRef.get();

    final batch = _firestore.batch();
    batch.update(
      _receivingsRef.doc(receiving.id),
      ReceivingModel.fromEntity(receiving).toMap(forUpdate: true),
    );
    if (poSnap.exists &&
        poSnap.data()?['status'] != PurchaseOrderStatus.received.name) {
      batch.update(poRef, {
        'status': PurchaseOrderStatus.received.name,
        'receivedAt': FieldValue.serverTimestamp(),
        'receivingId': receiving.id,
      });
    }
    await batch.commit();

    final updated = await getReceivingById(receiving.id);
    if (updated == null) {
      throw const DatabaseException(message: 'Receiving not found after update');
    }
    return updated;
  }
```

In `cancelReceiving`, replace the single `await _receivingsRef.doc(receivingId).update({...});` with:

```dart
      final update = {
        'status': ReceivingStatus.cancelled.name,
        'notes': reason != null
            ? '${receiving.notes ?? ''}\nCancelled: $reason'.trim()
            : receiving.notes,
      };
      if (receiving.purchaseOrderId != null) {
        await _writeAndUnlinkPurchaseOrder(
            receivingId, receiving.purchaseOrderId!, update);
      } else {
        await _receivingsRef.doc(receivingId).update(update);
      }
```

In `deleteReceiving`, replace `await _receivingsRef.doc(receivingId).delete();` with:

```dart
      if (receiving.purchaseOrderId != null) {
        await _writeAndUnlinkPurchaseOrder(
            receivingId, receiving.purchaseOrderId!, null);
      } else {
        await _receivingsRef.doc(receivingId).delete();
      }
```

Add the shared helper:

```dart
  /// Applies [update] to the receiving (or deletes it when null) and clears
  /// the owning PO's receivingId in the same batch — but only when the PO
  /// still points at this receiving, so a newer link is never clobbered.
  Future<void> _writeAndUnlinkPurchaseOrder(
    String receivingId,
    String purchaseOrderId,
    Map<String, dynamic>? update,
  ) async {
    final poRef = _firestore
        .collection(FirestoreCollections.purchaseOrders)
        .doc(purchaseOrderId);
    final poSnap = await poRef.get();

    final batch = _firestore.batch();
    if (update == null) {
      batch.delete(_receivingsRef.doc(receivingId));
    } else {
      batch.update(_receivingsRef.doc(receivingId), update);
    }
    if (poSnap.exists && poSnap.data()?['receivingId'] == receivingId) {
      batch.update(poRef, {'receivingId': null});
    }
    await batch.commit();
  }
```

- [ ] **Step 4: Run the new test plus every existing receiving test**

Run: `flutter test test/data/repositories/receiving_purchase_order_link_test.dart test/data/repositories/receiving_repository_roundtrip_test.dart && flutter test test/ --name receiving`
Expected: PASS. This touches the shared receiving write path — any regression here is a stop-and-fix, not a skip.

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/receiving_repository_impl.dart test/data/repositories/receiving_purchase_order_link_test.dart
git commit -m "feat(po): receiving completion marks linked PO received; cancel/delete unlink"
```

---

### Task 9: Riverpod providers

**Files:**
- Create: `lib/presentation/providers/purchase_order_provider.dart`
- Modify: `lib/presentation/providers/providers.dart` (add export)
- Test: `test/presentation/providers/purchase_order_provider_test.dart`

**Interfaces:**
- Consumes: `firestoreProvider` (`lib/services/firebase_service.dart`, re-exported via `providers.dart`), `productsProvider` (`product_provider.dart`), `saleRepositoryProvider` (`sale_provider.dart`), `SaleStatus` (`lib/core/enums/`), Task 3/5 outputs.
- Produces:

```dart
final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>(...);
final purchaseOrdersProvider = StreamProvider.autoDispose<List<PurchaseOrderEntity>>(...);
final purchaseOrderProvider = StreamProvider.autoDispose.family<PurchaseOrderEntity?, String>(...);
const int reorderSalesCap = 10000;
class ReorderResult { final List<ReorderSuggestion> suggestions; final bool capped; }
final reorderSuggestionsProvider = FutureProvider.autoDispose.family<ReorderResult, ReorderParams>(...);
```

- [ ] **Step 1: Write the failing test**

```dart
// test/presentation/providers/purchase_order_provider_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/sale_status.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/sale_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

class _MockSaleRepository extends Mock implements SaleRepository {}

void main() {
  final product = ProductEntity(
    id: 'p1',
    sku: 'SKU-1',
    name: 'Brake Pad',
    cost: 55,
    costCode: 'NBF',
    price: 80,
    quantity: 0,
    reorderLevel: 2,
    unit: 'pcs',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  test('purchaseOrdersProvider streams from Firestore', () async {
    final fake = FakeFirebaseFirestore();
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    await container.read(purchaseOrderRepositoryProvider).createPurchaseOrder(
          PurchaseOrderEntity(
            id: '',
            referenceNumber: 'PO-20260703-001',
            items: const [],
            totalCost: 0,
            totalQuantity: 0,
            status: PurchaseOrderStatus.draft,
            createdAt: DateTime(2026, 7, 3),
            createdBy: 'u1',
            createdByName: 'Admin',
          ),
        );

    final list = await container.read(purchaseOrdersProvider.future);
    expect(list, hasLength(1));
    expect(list.first.referenceNumber, 'PO-20260703-001');
  });

  test('reorderSuggestionsProvider computes suggestions and cap flag',
      () async {
    final saleRepo = _MockSaleRepository();
    // 60 units over the window → suggestions for p1.
    final sale = SaleEntity(
      id: 's1',
      saleNumber: 'S-1',
      items: [
        SaleItemEntity(
          id: 'i1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Brake Pad',
          quantity: 60,
          price: 80,
          unitCost: 55,
        ),
      ],
      // satisfy remaining required SaleEntity fields with obvious defaults —
      // see lib/domain/entities/sale_entity.dart
      status: SaleStatus.completed,
      createdAt: DateTime(2026, 7, 1),
      createdBy: 'u1',
    );
    when(() => saleRepo.getSalesByDateRange(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          status: SaleStatus.completed,
          limit: reorderSalesCap,
        )).thenAnswer((_) async => [sale]);

    final container = ProviderContainer(overrides: [
      productsProvider.overrideWith((ref) => Stream.value([product])),
      saleRepositoryProvider.overrideWithValue(saleRepo),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    ]);
    addTearDown(container.dispose);

    final result = await container
        .read(reorderSuggestionsProvider((windowDays: 60, coverDays: 30)).future);
    // velocity 1/day × 30 cover − 0 stock = 30
    expect(result.suggestions, hasLength(1));
    expect(result.suggestions.first.suggestedQty, 30);
    expect(result.capped, isFalse);
  });
}
```

`SaleEntity`/`SaleItemEntity` constructors: open `lib/domain/entities/sale_entity.dart` / `sale_item_entity.dart` and fill any other required fields with literal defaults (amounts consistent with one 60-unit line). The assertions must stay as written.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/providers/purchase_order_provider_test.dart`
Expected: FAIL — provider file does not exist.

- [ ] **Step 3: Implement the providers**

```dart
// lib/presentation/providers/purchase_order_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/sale_status.dart';
import 'package:maki_mobile_pos/core/utils/reorder_suggestions.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/purchase_order_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/sale_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

final purchaseOrderRepositoryProvider = Provider<PurchaseOrderRepository>((ref) {
  return PurchaseOrderRepositoryImpl(firestore: ref.watch(firestoreProvider));
});

/// Recent purchase orders, newest first. Status filtering is client-side —
/// shop volume is small and this avoids a composite index.
final purchaseOrdersProvider =
    StreamProvider.autoDispose<List<PurchaseOrderEntity>>((ref) {
  return ref.watch(purchaseOrderRepositoryProvider).watchPurchaseOrders();
});

final purchaseOrderProvider = StreamProvider.autoDispose
    .family<PurchaseOrderEntity?, String>((ref, id) {
  return ref.watch(purchaseOrderRepositoryProvider).watchPurchaseOrderById(id);
});

/// Sales fetched for the movement window are capped; past the cap the
/// suggestions may under-count, so the UI shows an incompleteness note.
const int reorderSalesCap = 10000;

class ReorderResult {
  final List<ReorderSuggestion> suggestions;
  final bool capped;
  const ReorderResult({required this.suggestions, required this.capped});
}

final reorderSuggestionsProvider = FutureProvider.autoDispose
    .family<ReorderResult, ReorderParams>((ref, params) async {
  final products = await ref.watch(productsProvider.future);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: params.windowDays - 1));
  final sales = await ref.watch(saleRepositoryProvider).getSalesByDateRange(
        startDate: start,
        endDate: now,
        status: SaleStatus.completed,
        limit: reorderSalesCap,
      );
  return ReorderResult(
    suggestions:
        computeReorderSuggestions(products, unitsSoldByProduct(sales), params),
    capped: sales.length >= reorderSalesCap,
  );
});
```

Add to `lib/presentation/providers/providers.dart`:

```dart
export 'purchase_order_provider.dart';
```

If `getSalesByDateRange` has different named parameters (check `lib/domain/repositories/sale_repository.dart:55`), match them exactly and mirror in the test.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/providers/purchase_order_provider_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/providers/purchase_order_provider.dart lib/presentation/providers/providers.dart test/presentation/providers/purchase_order_provider_test.dart
git commit -m "feat(po): purchase order + reorder suggestion providers"
```

---

### Task 10: CSV export

**Files:**
- Create: `lib/core/utils/purchase_order_csv.dart`
- Test: `test/core/utils/purchase_order_csv_test.dart`

**Interfaces:**
- Produces: `String buildPurchaseOrderCsv(PurchaseOrderEntity po)` — header block (reference / supplier / date), blank line, `SKU,Name,Qty,Unit` rows. **No costs** (user decision).

- [ ] **Step 1: Write the failing test**

```dart
// test/core/utils/purchase_order_csv_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/purchase_order_csv.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

void main() {
  final po = PurchaseOrderEntity(
    id: 'po1',
    referenceNumber: 'PO-20260703-001',
    supplierName: 'Acme, Inc.',
    items: const [
      PurchaseOrderItemEntity(
        id: 'p1',
        productId: 'p1',
        sku: 'SKU-1',
        name: 'Brake "HD" Pad',
        quantity: 4,
        unit: 'pcs',
        unitCost: 55,
        costCode: 'NBF',
      ),
    ],
    totalCost: 220,
    totalQuantity: 4,
    status: PurchaseOrderStatus.ordered,
    createdAt: DateTime(2026, 7, 3),
    createdBy: 'u1',
    createdByName: 'Admin',
  );

  test('builds header block and item rows without costs', () {
    final lines = buildPurchaseOrderCsv(po).trim().split('\n');
    expect(lines[0], 'Purchase Order,PO-20260703-001');
    expect(lines[1], 'Supplier,"Acme, Inc."');
    expect(lines[2], 'Date,2026-07-03');
    expect(lines[3], '');
    expect(lines[4], 'SKU,Name,Qty,Unit');
    expect(lines[5], 'SKU-1,"Brake ""HD"" Pad",4,pcs');
    expect(buildPurchaseOrderCsv(po), isNot(contains('55')),
        reason: 'costs must not leak into the shared file');
  });

  test('null supplier renders as No supplier', () {
    final noSup = po.copyWith(clearSupplierName: true);
    expect(buildPurchaseOrderCsv(noSup), contains('Supplier,No supplier'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/utils/purchase_order_csv_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/core/utils/purchase_order_csv.dart
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

/// Order list to send to a supplier: items and quantities only — costs stay
/// private by design.
String buildPurchaseOrderCsv(PurchaseOrderEntity po) {
  String esc(String v) =>
      v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;
  String row(List<String> cells) => cells.map(esc).join(',');

  final d = po.createdAt;
  final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  final b = StringBuffer()
    ..writeln(row(['Purchase Order', po.referenceNumber]))
    ..writeln(row(['Supplier', po.supplierName ?? 'No supplier']))
    ..writeln(row(['Date', date]))
    ..writeln()
    ..writeln(row(['SKU', 'Name', 'Qty', 'Unit']));
  for (final item in po.items) {
    b.writeln(row([item.sku, item.name, '${item.quantity}', item.unit]));
  }
  return b.toString();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/utils/purchase_order_csv_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/purchase_order_csv.dart test/core/utils/purchase_order_csv_test.dart
git commit -m "feat(po): supplier-safe purchase order CSV (no costs)"
```

---

### Task 11: Routes and guards

**Files:**
- Modify: `lib/config/router/route_names.dart` (names + paths)
- Modify: `lib/config/router/route_guards.dart` (static map + dynamic prefix)
- Modify: `lib/config/router/app_routes.dart` (GoRoute nesting — screens land in Tasks 12–14; register with placeholder-free builders by creating the three screen files as minimal `Scaffold`s in Task 12; **defer the app_routes edit to Task 12** so this task stays compilable)
- Test: `test/config/router/route_guards_purchase_orders_test.dart`

**Interfaces:**
- Produces: `RoutePaths.purchaseOrders = '/receiving/purchase-orders'`, `RoutePaths.purchaseOrderNew = '/receiving/purchase-orders/new'`; `RouteNames.purchaseOrders / purchaseOrderNew / purchaseOrderDetail`; guard: staff + admin (via `Permission.accessReceiving`), cashier denied, including the dynamic `/:id` and `/new` paths.

- [ ] **Step 1: Write the failing test** (mirror `test/config/router/route_guards_job_orders_test.dart`)

```dart
// test/config/router/route_guards_purchase_orders_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  UserEntity user(UserRole role) => UserEntity(
        id: 'u1',
        email: 'u@x.com',
        displayName: 'U',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

  test('paths and names', () {
    expect(RoutePaths.purchaseOrders, '/receiving/purchase-orders');
    expect(RoutePaths.purchaseOrderNew, '/receiving/purchase-orders/new');
    expect(RouteNames.purchaseOrders, 'purchaseOrders');
    expect(RouteNames.purchaseOrderNew, 'purchaseOrderNew');
    expect(RouteNames.purchaseOrderDetail, 'purchaseOrderDetail');
  });

  test('list route: staff and admin yes, cashier no', () {
    for (final role in [UserRole.admin, UserRole.staff]) {
      expect(RouteGuards.canAccess(RoutePaths.purchaseOrders, user(role)),
          isTrue, reason: '$role');
    }
    expect(RouteGuards.canAccess(RoutePaths.purchaseOrders, user(UserRole.cashier)),
        isFalse);
  });

  test('dynamic child routes are gated the same', () {
    expect(
        RouteGuards.canAccess(
            RoutePaths.purchaseOrderNew, user(UserRole.staff)),
        isTrue);
    expect(
        RouteGuards.canAccess(
            '/receiving/purchase-orders/abc123', user(UserRole.staff)),
        isTrue);
    expect(
        RouteGuards.canAccess(
            '/receiving/purchase-orders/abc123', user(UserRole.cashier)),
        isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/config/router/route_guards_purchase_orders_test.dart`
Expected: FAIL — `RoutePaths.purchaseOrders` undefined.

- [ ] **Step 3: Add names, paths, guards**

`lib/config/router/route_names.dart` — in the names class near the receiving names:

```dart
  /// Purchase orders list — `/receiving/purchase-orders`.
  static const String purchaseOrders = 'purchaseOrders';

  /// New purchase order (reorder suggestions) — `/receiving/purchase-orders/new`.
  static const String purchaseOrderNew = 'purchaseOrderNew';

  /// Purchase order detail — `/receiving/purchase-orders/:id`.
  static const String purchaseOrderDetail = 'purchaseOrderDetail';
```

…and in the paths class near the receiving paths:

```dart
  static const String purchaseOrders = '/receiving/purchase-orders';
  static const String purchaseOrderNew = '/receiving/purchase-orders/new';
```

`lib/config/router/route_guards.dart`:
- In the static route→permission map (near `'/receiving/drafts'`):

```dart
    '/receiving/purchase-orders': Permission.accessReceiving,
```

- In the dynamic-route method, next to the `/receiving/bulk/` block:

```dart
    // Purchase orders — new + detail live under the list path; same gate as
    // /receiving/purchase-orders (staff + admin).
    if (path.startsWith('/receiving/purchase-orders/')) {
      return user.hasPermission(Permission.accessReceiving);
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/config/router/route_guards_purchase_orders_test.dart && flutter test test/config/router/`
Expected: PASS, existing guard tests unaffected.

- [ ] **Step 5: Commit**

```bash
git add lib/config/router/route_names.dart lib/config/router/route_guards.dart test/config/router/route_guards_purchase_orders_test.dart
git commit -m "feat(po): purchase order routes gated to staff+admin"
```

---

### Task 12: Status pill, list screen, router registration, Receiving entry point

**Files:**
- Create: `lib/presentation/mobile/widgets/purchase_orders/purchase_order_status_style.dart`
- Create: `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart`
- Create: `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart` (minimal shell this task; real UI Task 13)
- Create: `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart` (minimal shell this task; real UI Task 14)
- Modify: `lib/config/router/app_routes.dart` (register the three routes)
- Modify: `lib/presentation/mobile/screens/receiving/receiving_screen.dart` (app-bar entry)
- Test: `test/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen_test.dart`

**Interfaces:**
- Consumes: `purchaseOrdersProvider` (Task 9), `RoutePaths` (Task 11), `AppCard`, theme tokens, `PurchaseOrderStatus`.
- Produces: `PurchaseOrdersScreen` (const ctor), `NewPurchaseOrderScreen` (const ctor), `PurchaseOrderDetailScreen({required String purchaseOrderId})`, `PurchaseOrderStatusStyle.of(status, dark: bool)` with `label`, `textColor`, `tint`, `icon`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';

void main() {
  PurchaseOrderEntity po(String ref, PurchaseOrderStatus status) =>
      PurchaseOrderEntity(
        id: ref,
        referenceNumber: ref,
        supplierName: 'Acme',
        items: const [],
        totalCost: 0,
        totalQuantity: 3,
        status: status,
        createdAt: DateTime(2026, 7, 3),
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

  testWidgets('lists purchase orders with status pills', (tester) async {
    await pump(tester, [
      po('PO-20260703-001', PurchaseOrderStatus.draft),
      po('PO-20260703-002', PurchaseOrderStatus.ordered),
    ]);
    expect(find.text('PO-20260703-001'), findsOneWidget);
    expect(find.text('PO-20260703-002'), findsOneWidget);
    expect(find.text('Draft'), findsWidgets);
    expect(find.text('Ordered'), findsWidgets);
  });

  testWidgets('status chip filters the list', (tester) async {
    await pump(tester, [
      po('PO-20260703-001', PurchaseOrderStatus.draft),
      po('PO-20260703-002', PurchaseOrderStatus.ordered),
    ]);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ordered'));
    await tester.pumpAndSettle();
    expect(find.text('PO-20260703-001'), findsNothing);
    expect(find.text('PO-20260703-002'), findsOneWidget);
  });

  testWidgets('shows empty state and a new-PO FAB', (tester) async {
    await pump(tester, []);
    expect(find.text('No purchase orders yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen_test.dart`
Expected: FAIL — screen does not exist.

- [ ] **Step 3: Implement style + screens + registration**

Status style (mirror `lib/presentation/mobile/widgets/sales/void_status_style.dart` — same class shape, PO semantics: draft = neutral, ordered = amber like "pending", received = green success, cancelled = red error):

```dart
// lib/presentation/mobile/widgets/purchase_orders/purchase_order_status_style.dart
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';

/// Status color/icon language for purchase orders — draft = neutral,
/// ordered = amber (in flight), received = green, cancelled = red.
class PurchaseOrderStatusStyle {
  const PurchaseOrderStatusStyle({
    required this.icon,
    required this.textColor,
    required this.tint,
    required this.label,
  });

  final IconData icon;
  final Color textColor;
  final Color tint;
  final String label;

  static PurchaseOrderStatusStyle of(PurchaseOrderStatus status,
      {required bool dark}) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        final c = AppColors.textSecondary(dark);
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.pencilLine,
          textColor: c,
          tint: dark ? const Color(0x1FFFFFFF) : const Color(0x14000000),
          label: 'Draft',
        );
      case PurchaseOrderStatus.ordered:
        final c = dark ? AppColors.warningOnDark : const Color(0xFFC8881A);
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.send,
          textColor: c,
          tint: dark ? const Color(0x24F5B547) : const Color(0x1FF57C00),
          label: 'Ordered',
        );
      case PurchaseOrderStatus.received:
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.packageCheck,
          textColor: dark ? AppColors.successOnDark : AppColors.successDark,
          tint: dark ? const Color(0x294CAF50) : AppColors.successLight,
          label: 'Received',
        );
      case PurchaseOrderStatus.cancelled:
        final c = dark ? AppColors.errorOnDark : AppColors.error;
        return PurchaseOrderStatusStyle(
          icon: LucideIcons.ban,
          textColor: c,
          tint: dark ? const Color(0x24FF6B5E) : const Color(0x1AF44336),
          label: 'Cancelled',
        );
    }
  }
}
```

If `AppColors.textSecondary(dark)` / `successDark` / `warningOnDark` / `errorOnDark` don't exist under those names, open `lib/core/theme/app_colors.dart` and substitute the closest existing tokens (they are used by `VoidStatusStyle`, so most exist verbatim).

List screen:

```dart
// lib/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/purchase_order_status_style.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

/// Purchase orders list with status filter chips.
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
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Purchase Orders'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RoutePaths.purchaseOrderNew),
        child: const Icon(LucideIcons.plus),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
                for (final status in PurchaseOrderStatus.values) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(status.displayName),
                    selected: _filter == status,
                    onSelected: (_) => setState(() => _filter = status),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load: $e')),
              data: (orders) {
                final visible = _filter == null
                    ? orders
                    : orders.where((o) => o.status == _filter).toList();
                if (visible.isEmpty) {
                  return const Center(child: Text('No purchase orders yet'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _OrderCard(
                    order: visible[i],
                    dark: dark,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.dark});

  final PurchaseOrderEntity order;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final style = PurchaseOrderStatusStyle.of(order.status, dark: dark);
    final d = order.createdAt;
    final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    return AppCard(
      onTap: () =>
          context.push('${RoutePaths.purchaseOrders}/${order.id}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.referenceNumber,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${order.supplierName ?? 'No supplier'} • '
                  '${order.totalQuantity} pcs • $date',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: style.tint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(style.icon, size: 12, color: style.textColor),
                const SizedBox(width: 4),
                Text(style.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: style.textColor,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

If `AppCard` doesn't take `onTap`/`child` with those names, open `lib/presentation/shared/widgets/common/app_card.dart` and match its actual API (other receiving list rows already use it — copy their usage shape).

Shell screens (fleshed out in Tasks 13–14):

```dart
// lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reorder-suggestions screen; drafts one PO per supplier. Built in Task 13.
class NewPurchaseOrderScreen extends ConsumerStatefulWidget {
  const NewPurchaseOrderScreen({super.key});

  @override
  ConsumerState<NewPurchaseOrderScreen> createState() =>
      NewPurchaseOrderScreenState();
}

class NewPurchaseOrderScreenState
    extends ConsumerState<NewPurchaseOrderScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase Order')),
      body: const SizedBox.shrink(),
    );
  }
}
```

```dart
// lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Purchase order detail + lifecycle actions. Built in Task 14.
class PurchaseOrderDetailScreen extends ConsumerWidget {
  const PurchaseOrderDetailScreen({super.key, required this.purchaseOrderId});

  final String purchaseOrderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Order')),
      body: const SizedBox.shrink(),
    );
  }
}
```

Router registration — `lib/config/router/app_routes.dart`, inside the receiving `GoRoute`'s `routes:` list (after the `'import'` entry). `'new'` must be declared before `':id'`:

```dart
          GoRoute(
            path: 'purchase-orders',
            name: RouteNames.purchaseOrders,
            builder: (context, state) => const PurchaseOrdersScreen(),
            routes: [
              GoRoute(
                path: 'new',
                name: RouteNames.purchaseOrderNew,
                builder: (context, state) => const NewPurchaseOrderScreen(),
              ),
              GoRoute(
                path: ':id',
                name: RouteNames.purchaseOrderDetail,
                builder: (context, state) => PurchaseOrderDetailScreen(
                  purchaseOrderId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
```

…with the three imports added at the top alongside the other receiving screen imports.

Receiving entry point — `lib/presentation/mobile/screens/receiving/receiving_screen.dart`, in the `AppBar` `actions:` next to the existing upload/import `IconButton`:

```dart
          IconButton(
            icon: const Icon(LucideIcons.clipboardList),
            tooltip: 'Purchase Orders',
            onPressed: () => context.push(RoutePaths.purchaseOrders),
          ),
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/purchase_orders_screen_test.dart && flutter analyze`
Expected: PASS (3 tests), analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/widgets/purchase_orders/ lib/presentation/mobile/screens/receiving/purchase_orders/ lib/config/router/app_routes.dart lib/presentation/mobile/screens/receiving/receiving_screen.dart test/presentation/mobile/screens/receiving/purchase_orders/
git commit -m "feat(po): purchase orders list screen + routes + receiving entry"
```

---

### Task 13: New Purchase Order screen (suggestions + search-to-add + save)

**Files:**
- Rewrite: `lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart`
- Test: `test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart`

**Interfaces:**
- Consumes: `reorderSuggestionsProvider` / `ReorderResult` / `reorderSalesCap` (Task 9), `computeReorderSuggestions` types (Task 5), `purchaseOrderRepositoryProvider`, `productsProvider`, `currentUserProvider` (`auth_provider.dart`, `StreamProvider<UserEntity?>`), `runWithWaiting` (`lib/presentation/shared/widgets/common/app_waiting_dialog.dart`).
- Produces: saving creates one **draft** PO per supplier group among selected lines via `generateReferenceNumber()` + `createPurchaseOrder()` sequentially, then pops with a snackbar.

**Behavior spec:**
- Window preset chips 30/60/90 (default **60**); cover-days numeric field (default **30**, min 1). Changing either re-reads `reorderSuggestionsProvider((windowDays: _windowDays, coverDays: _coverDays))`.
- Suggestion rows grouped by supplier (header per group, `'No supplier'` last — the compute output is already sorted). Row: checkbox (default checked), product name + SKU, `Stock {qty} • {velocity}/day` caption (velocity 1 decimal), qty stepper (− / value / +, min 1) initialized to `suggestedQty`.
- "Add product" button opens a bottom sheet with a search field filtering `productsProvider` data client-side on name/SKU (active products not already listed); tapping adds a checked manual row (qty 1) under its supplier group.
- `capped == true` → show a one-line note above the list: `Movement data may be incomplete (sales cap reached)`.
- Save button (disabled while nothing is checked or while saving — double-submit lock): groups checked rows by `(supplierId, supplierName)`, builds `PurchaseOrderItemEntity(id: product.id, productId: product.id, sku, name, quantity: chosenQty, unit, unitCost: product.cost, costCode: product.costCode)`, creates each PO as `PurchaseOrderStatus.draft` with `recalculateTotals()`, `createdBy/createdByName` from `currentUserProvider`; wraps the whole save in `context.runWithWaiting(message: 'Saving purchase orders…')`; on success `context.pop()` + snackbar `Created N purchase order(s)`; on error snackbar with the message and re-enable.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/reorder_suggestions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

void main() {
  ProductEntity product(String id, {String? supplier = 'Acme'}) =>
      ProductEntity(
        id: id,
        sku: 'SKU-$id',
        name: 'Item $id',
        cost: 55,
        costCode: 'NBF',
        price: 80,
        quantity: 0,
        reorderLevel: 2,
        unit: 'pcs',
        supplierId: supplier == null ? null : 'sup-$supplier',
        supplierName: supplier,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  final user = UserEntity(
    id: 'u1',
    email: 'u@x.com',
    displayName: 'Admin',
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  Future<FakeFirebaseFirestore> pump(WidgetTester tester,
      {required List<ReorderSuggestion> suggestions}) async {
    final fake = FakeFirebaseFirestore();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(fake),
        productsProvider.overrideWith(
            (ref) => Stream.value([product('p1'), product('p2')])),
        currentUserProvider.overrideWith((ref) => Stream.value(user)),
        reorderSuggestionsProvider.overrideWith((ref, params) async =>
            ReorderResult(suggestions: suggestions, capped: false)),
      ],
      child: const MaterialApp(home: NewPurchaseOrderScreen()),
    ));
    await tester.pumpAndSettle();
    return fake;
  }

  ReorderSuggestion suggestion(ProductEntity p, int qty) => ReorderSuggestion(
        product: p,
        velocityPerDay: 1,
        targetStock: qty,
        suggestedQty: qty,
      );

  testWidgets('renders suggestion rows grouped by supplier', (tester) async {
    await pump(tester, suggestions: [
      suggestion(product('p1'), 9),
      suggestion(product('p2', supplier: null), 4),
    ]);
    expect(find.text('Item p1'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('No supplier'), findsOneWidget);
  });

  testWidgets('save creates one draft PO per supplier', (tester) async {
    final fake = await pump(tester, suggestions: [
      suggestion(product('p1'), 9),
      suggestion(product('p2', supplier: null), 4),
    ]);

    await tester.tap(find.text('Save drafts'));
    await tester.pumpAndSettle();

    final orders = await fake.collection('purchase_orders').get();
    expect(orders.size, 2);
    final statuses =
        orders.docs.map((d) => d.data()['status']).toSet();
    expect(statuses, {'draft'});
    final suppliers =
        orders.docs.map((d) => d.data()['supplierName']).toSet();
    expect(suppliers, {'Acme', null});
  });

  testWidgets('unchecking a row excludes it from the save', (tester) async {
    final fake = await pump(tester, suggestions: [
      suggestion(product('p1'), 9),
      suggestion(product('p2', supplier: null), 4),
    ]);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save drafts'));
    await tester.pumpAndSettle();

    final orders = await fake.collection('purchase_orders').get();
    expect(orders.size, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart`
Expected: FAIL — shell screen has no rows/save button.

- [ ] **Step 3: Implement the screen**

```dart
// lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/utils/reorder_suggestions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';

/// One selectable order line on the draft — either a velocity suggestion or a
/// manually added product.
class _Line {
  _Line({required this.product, required this.qty, this.velocityPerDay});
  final ProductEntity product;
  int qty;
  final double? velocityPerDay; // null = manually added
  bool checked = true;
}

/// Drafts purchase orders from stock movement: adjustable window/cover,
/// per-supplier grouping, search-to-add, one draft PO per supplier on save.
class NewPurchaseOrderScreen extends ConsumerStatefulWidget {
  const NewPurchaseOrderScreen({super.key});

  @override
  ConsumerState<NewPurchaseOrderScreen> createState() =>
      NewPurchaseOrderScreenState();
}

class NewPurchaseOrderScreenState
    extends ConsumerState<NewPurchaseOrderScreen> {
  int _windowDays = 60;
  final _coverController = TextEditingController(text: '30');
  final List<_Line> _manual = [];
  // Suggestion adjustments keyed by productId; suggestions themselves reload
  // when params change, manual lines persist.
  final Map<String, int> _qtyOverride = {};
  final Set<String> _unchecked = {};
  bool _saving = false;

  int get _coverDays =>
      int.tryParse(_coverController.text)?.clamp(1, 365) ?? 30;

  @override
  void dispose() {
    _coverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final params = (windowDays: _windowDays, coverDays: _coverDays);
    final resultAsync = ref.watch(reorderSuggestionsProvider(params));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Purchase Order'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.search),
            tooltip: 'Add product',
            onPressed: _showAddProductSheet,
          ),
        ],
      ),
      body: resultAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (result) => _buildBody(result),
      ),
    );
  }

  Widget _buildBody(ReorderResult result) {
    final lines = <_Line>[
      for (final s in result.suggestions)
        _Line(
          product: s.product,
          qty: _qtyOverride[s.product.id] ?? s.suggestedQty,
          velocityPerDay: s.velocityPerDay,
        )..checked = !_unchecked.contains(s.product.id),
      ..._manual
          .where((m) => !result.suggestions
              .any((s) => s.product.id == m.product.id))
          .toList(),
    ];
    // Group by supplier, suggestions are pre-sorted; manual lines join their
    // supplier's group or 'No supplier'.
    final groups = <String?, List<_Line>>{};
    for (final line in lines) {
      groups.putIfAbsent(line.product.supplierName, () => []).add(line);
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });
    final checkedCount = lines.where((l) => l.checked).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              for (final days in const [30, 60, 90]) ...[
                ChoiceChip(
                  label: Text('${days}d'),
                  selected: _windowDays == days,
                  onSelected: (_) => setState(() => _windowDays = days),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              SizedBox(
                width: 88,
                child: TextField(
                  controller: _coverController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cover days',
                    isDense: true,
                  ),
                  onSubmitted: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        if (result.capped)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Movement data may be incomplete (sales cap reached)'),
          ),
        Expanded(
          child: lines.isEmpty
              ? const Center(
                  child: Text('No suggestions — everything is stocked'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: [
                    for (final key in keys) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 4),
                        child: Text(key ?? 'No supplier',
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      for (final line in groups[key]!) _row(line),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(_Line line) {
    final p = line.product;
    final caption = line.velocityPerDay != null
        ? 'Stock ${p.quantity} • ${line.velocityPerDay!.toStringAsFixed(1)}/day'
        : 'Stock ${p.quantity} • added manually';
    return Row(
      children: [
        Checkbox(
          value: line.checked,
          onChanged: (v) => setState(() {
            if (line.velocityPerDay != null) {
              v == true ? _unchecked.remove(p.id) : _unchecked.add(p.id);
            } else {
              line.checked = v ?? false;
            }
          }),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${p.sku} • $caption',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(LucideIcons.minus, size: 16),
          onPressed: line.qty > 1 ? () => _setQty(line, line.qty - 1) : null,
        ),
        Text('${line.qty}'),
        IconButton(
          icon: const Icon(LucideIcons.plus, size: 16),
          onPressed: () => _setQty(line, line.qty + 1),
        ),
      ],
    );
  }

  void _setQty(_Line line, int qty) => setState(() {
        if (line.velocityPerDay != null) {
          _qtyOverride[line.product.id] = qty;
        } else {
          line.qty = qty;
        }
      });

  Future<void> _showAddProductSheet() async {
    final products = ref.read(productsProvider).valueOrNull ?? [];
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final query = controller.text.trim().toLowerCase();
          final matches = products
              .where((p) =>
                  p.isActive &&
                  !_manual.any((m) => m.product.id == p.id) &&
                  (query.isEmpty ||
                      p.name.toLowerCase().contains(query) ||
                      p.sku.toLowerCase().contains(query)))
              .take(30)
              .toList();
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
            child: SizedBox(
              height: 420,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                          hintText: 'Search name or SKU'),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(matches[i].name),
                        subtitle: Text(matches[i].sku),
                        onTap: () {
                          setState(() => _manual
                              .add(_Line(product: matches[i], qty: 1)));
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    controller.dispose();
  }

  Future<void> _save(List<_Line> lines) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || _saving) return;
    final checked = lines.where((l) => l.checked).toList();
    if (checked.isEmpty) return;
    setState(() => _saving = true);

    final repo = ref.read(purchaseOrderRepositoryProvider);
    final groups = <String?, List<_Line>>{};
    for (final line in checked) {
      groups.putIfAbsent(line.product.supplierId, () => []).add(line);
    }
    try {
      final created = await context.runWithWaiting(() async {
        var count = 0;
        for (final group in groups.values) {
          final ref = await repo.generateReferenceNumber();
          final first = group.first.product;
          final po = PurchaseOrderEntity(
            id: '',
            referenceNumber: ref,
            supplierId: first.supplierId,
            supplierName: first.supplierName,
            items: [
              for (final line in group)
                PurchaseOrderItemEntity(
                  id: line.product.id,
                  productId: line.product.id,
                  sku: line.product.sku,
                  name: line.product.name,
                  quantity: line.qty,
                  unit: line.product.unit,
                  unitCost: line.product.cost,
                  costCode: line.product.costCode,
                ),
            ],
            totalCost: 0,
            totalQuantity: 0,
            status: PurchaseOrderStatus.draft,
            createdAt: DateTime.now(),
            createdBy: user.id,
            createdByName: user.displayName,
          ).recalculateTotals();
          await repo.createPurchaseOrder(po);
          count++;
        }
        return count;
      }, message: 'Saving purchase orders…');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created $created purchase order(s)')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
```

Wire the save button: add to `_buildBody`'s `Column` (below `Expanded`) a bottom bar:

```dart
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    checkedCount == 0 || _saving ? null : () => _save(lines),
                child: Text('Save drafts'
                    '${checkedCount > 0 ? ' ($checkedCount items)' : ''}'),
              ),
            ),
          ),
        ),
```

Note the test taps `find.text('Save drafts')` — with items checked the label is `Save drafts (2 items)`, so in the test use `find.textContaining('Save drafts')` OR keep the label constant `'Save drafts'`. **Keep the label constant `'Save drafts'`** and show the count separately above the button if desired; the test stays as written.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen.dart test/presentation/mobile/screens/receiving/purchase_orders/new_purchase_order_screen_test.dart
git commit -m "feat(po): new purchase order screen - suggestions, search-to-add, per-supplier drafts"
```

---

### Task 14: Purchase Order detail screen

**Files:**
- Rewrite: `lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart`
- Test: `test/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen_test.dart`

**Interfaces:**
- Consumes: `purchaseOrderProvider(id)`, `purchaseOrderRepositoryProvider`, `receivingRepositoryProvider` (`receiving_provider.dart`, for `generateReferenceNumber`), `currentUserProvider`, `buildPurchaseOrderCsv` + `saveReportCsv`, `runWithWaiting`, `PurchaseOrderStatusStyle`, `RoutePaths.bulkReceiving`.
- Produces: detail screen with lifecycle actions.

**Behavior spec:**
- Header card: reference number, status pill, supplier, created date/by, `orderedAt`/`receivedAt` when set, notes.
- Items list: each row name, SKU, `qty × unit` and (draft only) − / + steppers and a remove icon; every edit immediately persists via `updatePurchaseOrder(po.copyWith(items: …).recalculateTotals())` behind `runWithWaiting(message: 'Updating…')`. Removing the last item is blocked with a snackbar (`Delete the purchase order instead`).
- Bottom action bar by status:
  - **draft:** `Mark ordered` (filled) + `Share CSV` + overflow menu: `Cancel`, `Delete` (admin only).
  - **ordered:** `Receive` (filled) + `Back to draft` + `Share CSV` + overflow: `Cancel`, `Delete` (admin only).
  - **received:** `Share CSV` + `View receiving` (when `receivingId != null`, pushes `'${RoutePaths.bulkReceiving}/${po.receivingId}'`) + overflow: `Delete` (admin only).
  - **cancelled:** overflow: `Delete` (admin only).
- `Receive` handler: `runWithWaiting`: `final refNum = await ref.read(receivingRepositoryProvider).generateReferenceNumber(); final rid = await repo.startReceiving(purchaseOrderId: po.id, receivingReferenceNumber: refNum, createdBy: user.id, createdByName: user.displayName);` then `context.push('${RoutePaths.bulkReceiving}/$rid')`.
- `Cancel` and `Delete` confirm with an `AlertDialog` first; `Delete` pops back to the list on success.
- `Share CSV`: `saveReportCsv(context, buildPurchaseOrderCsv(po), '${po.referenceNumber}.csv')`.
- Admin check: `ref.watch(currentUserProvider).valueOrNull?.role == UserRole.admin`.
- All action buttons disable while an action is in flight (single `_busy` flag — double-submit lock).

- [ ] **Step 1: Write the failing widget test**

```dart
// test/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/purchase_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late PurchaseOrderRepositoryImpl repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = PurchaseOrderRepositoryImpl(firestore: fake);
  });

  UserEntity user(UserRole role) => UserEntity(
        id: 'u1',
        email: 'u@x.com',
        displayName: 'U',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      );

  Future<PurchaseOrderEntity> seed(
      {PurchaseOrderStatus status = PurchaseOrderStatus.draft}) async {
    final po = await repo.createPurchaseOrder(PurchaseOrderEntity(
      id: '',
      referenceNumber: 'PO-20260703-001',
      supplierName: 'Acme',
      items: const [
        PurchaseOrderItemEntity(
          id: 'p1',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Brake Pad',
          quantity: 4,
          unit: 'pcs',
          unitCost: 55,
          costCode: 'NBF',
        ),
      ],
      totalCost: 220,
      totalQuantity: 4,
      status: PurchaseOrderStatus.draft,
      createdAt: DateTime(2026, 7, 3),
      createdBy: 'u1',
      createdByName: 'Admin',
    ));
    if (status == PurchaseOrderStatus.ordered) {
      await repo.markOrdered(po.id);
    }
    return (await repo.getPurchaseOrderById(po.id))!;
  }

  Future<void> pump(WidgetTester tester, String id, UserRole role) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(fake),
        currentUserProvider.overrideWith((ref) => Stream.value(user(role))),
      ],
      child: MaterialApp(home: PurchaseOrderDetailScreen(purchaseOrderId: id)),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('draft shows items and Mark ordered', (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    expect(find.text('PO-20260703-001'), findsOneWidget);
    expect(find.text('Brake Pad'), findsOneWidget);
    expect(find.text('Mark ordered'), findsOneWidget);
    expect(find.text('Receive'), findsNothing);
  });

  testWidgets('Mark ordered transitions to ordered with Receive', (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.text('Mark ordered'));
    await tester.pumpAndSettle();
    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Back to draft'), findsOneWidget);
  });

  testWidgets('Receive creates a linked draft receiving', (tester) async {
    final po = await seed(status: PurchaseOrderStatus.ordered);
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.text('Receive'));
    await tester.pumpAndSettle();

    final receivings = await fake.collection('receivings').get();
    expect(receivings.size, 1);
    expect(receivings.docs.first.data()['purchaseOrderId'], po.id);
  });

  testWidgets('Delete is admin-only', (tester) async {
    final po = await seed();
    await pump(tester, po.id, UserRole.staff);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
  });
}
```

Note: the Receive test navigates via `context.push` after creating the receiving — under `MaterialApp(home: …)` there is no GoRouter, so guard navigation with a `mounted`/try-catch or assert only the Firestore effect. **Wrap the post-receive `context.push` in a `try { … } catch (_) {}`?** No — instead use `if (!mounted) return;` and let the test's missing router throw be avoided by pushing with `GoRouter.of(context)` only when available:

```dart
      // Navigation is best-effort in tests without a router.
      if (!mounted) return;
      try {
        context.push('${RoutePaths.bulkReceiving}/$rid');
      } on GoError catch (_) {
        // No GoRouter in widget tests — the receiving draft still exists.
      }
```

If `GoError` isn't the thrown type, catch the actual exception seen when running the test (run once, read the error type, catch that specific type). Alternative: wrap the test's `MaterialApp` in a minimal `GoRouter` with the detail route as home and a `/receiving/bulk/:id` stub route — prefer this if the catch feels wrong; both are acceptable, pick one and keep the assertions.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen_test.dart`
Expected: FAIL — shell screen renders nothing.

- [ ] **Step 3: Implement the screen**

```dart
// lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/enums/user_role.dart';
import 'package:maki_mobile_pos/core/utils/purchase_order_csv.dart';
import 'package:maki_mobile_pos/core/utils/report_export.dart';
import 'package:maki_mobile_pos/domain/entities/purchase_order_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/purchase_orders/purchase_order_status_style.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/purchase_order_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_waiting_dialog.dart';

/// Purchase order detail: items (editable while draft) + lifecycle actions.
class PurchaseOrderDetailScreen extends ConsumerStatefulWidget {
  const PurchaseOrderDetailScreen({super.key, required this.purchaseOrderId});

  final String purchaseOrderId;

  @override
  ConsumerState<PurchaseOrderDetailScreen> createState() =>
      PurchaseOrderDetailScreenState();
}

class PurchaseOrderDetailScreenState
    extends ConsumerState<PurchaseOrderDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final poAsync = ref.watch(purchaseOrderProvider(widget.purchaseOrderId));
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.role == UserRole.admin;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text('Purchase Order'),
        actions: [
          poAsync.maybeWhen(
            data: (po) => po == null
                ? const SizedBox.shrink()
                : PopupMenuButton<String>(
                    onSelected: (v) => _onMenu(v, po),
                    itemBuilder: (_) => [
                      if (po.canCancel)
                        const PopupMenuItem(
                            value: 'cancel', child: Text('Cancel')),
                      if (isAdmin)
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                    ],
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: poAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (po) => po == null
            ? const Center(child: Text('Purchase order not found'))
            : _buildBody(po, dark),
      ),
    );
  }

  Widget _buildBody(PurchaseOrderEntity po, bool dark) {
    final style = PurchaseOrderStatusStyle.of(po.status, dark: dark);
    String date(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(po.referenceNumber,
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: style.tint,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(style.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: style.textColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(po.supplierName ?? 'No supplier'),
                    Text(
                        'Created ${date(po.createdAt)} by ${po.createdByName}',
                        style: Theme.of(context).textTheme.bodySmall),
                    if (po.orderedAt != null)
                      Text('Ordered ${date(po.orderedAt!)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    if (po.receivedAt != null)
                      Text('Received ${date(po.receivedAt!)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    if (po.notes != null && po.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(po.notes!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('${po.items.length} items • ${po.totalQuantity} pcs',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final item in po.items) _itemRow(po, item),
            ],
          ),
        ),
        SafeArea(child: _actionBar(po)),
      ],
    );
  }

  Widget _itemRow(PurchaseOrderEntity po, PurchaseOrderItemEntity item) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(item.sku, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (po.canEdit) ...[
          IconButton(
            icon: const Icon(LucideIcons.minus, size: 16),
            onPressed: _busy || item.quantity <= 1
                ? null
                : () => _updateItem(po, item.copyWith(quantity: item.quantity - 1)),
          ),
          Text('${item.quantity}'),
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 16),
            onPressed: _busy
                ? null
                : () => _updateItem(po, item.copyWith(quantity: item.quantity + 1)),
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2, size: 16),
            onPressed: _busy ? null : () => _removeItem(po, item),
          ),
        ] else
          Text('${item.quantity} ${item.unit}'),
      ],
    );
  }

  Widget _actionBar(PurchaseOrderEntity po) {
    final buttons = <Widget>[];
    if (po.status == PurchaseOrderStatus.draft) {
      buttons.add(FilledButton(
        onPressed: _busy ? null : () => _run(() =>
            ref.read(purchaseOrderRepositoryProvider).markOrdered(po.id),
            'Marking ordered…'),
        child: const Text('Mark ordered'),
      ));
    }
    if (po.status == PurchaseOrderStatus.ordered) {
      buttons.add(FilledButton(
        onPressed: _busy ? null : () => _receive(po),
        child: const Text('Receive'),
      ));
      buttons.add(OutlinedButton(
        onPressed: _busy ? null : () => _run(() =>
            ref.read(purchaseOrderRepositoryProvider).revertToDraft(po.id),
            'Reopening…'),
        child: const Text('Back to draft'),
      ));
    }
    if (po.status != PurchaseOrderStatus.cancelled) {
      buttons.add(OutlinedButton.icon(
        onPressed: _busy ? null : () => _shareCsv(po),
        icon: const Icon(LucideIcons.share2, size: 16),
        label: const Text('Share CSV'),
      ));
    }
    if (po.status == PurchaseOrderStatus.received && po.receivingId != null) {
      buttons.add(OutlinedButton(
        onPressed: () =>
            context.push('${RoutePaths.bulkReceiving}/${po.receivingId}'),
        child: const Text('View receiving'),
      ));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(spacing: 8, runSpacing: 8, children: buttons),
    );
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _busy = true);
    try {
      await context.runWithWaiting(action, message: message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _updateItem(
      PurchaseOrderEntity po, PurchaseOrderItemEntity updated) {
    final items = po.items
        .map((i) => i.id == updated.id ? updated : i)
        .toList();
    return _run(
      () async => ref
          .read(purchaseOrderRepositoryProvider)
          .updatePurchaseOrder(po.copyWith(items: items).recalculateTotals()),
      'Updating…',
    );
  }

  Future<void> _removeItem(
      PurchaseOrderEntity po, PurchaseOrderItemEntity item) {
    if (po.items.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Last item — delete the purchase order instead')));
      return Future.value();
    }
    final items = po.items.where((i) => i.id != item.id).toList();
    return _run(
      () async => ref
          .read(purchaseOrderRepositoryProvider)
          .updatePurchaseOrder(po.copyWith(items: items).recalculateTotals()),
      'Updating…',
    );
  }

  Future<void> _receive(PurchaseOrderEntity po) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      final rid = await context.runWithWaiting(() async {
        final refNum = await ref
            .read(receivingRepositoryProvider)
            .generateReferenceNumber();
        return ref.read(purchaseOrderRepositoryProvider).startReceiving(
              purchaseOrderId: po.id,
              receivingReferenceNumber: refNum,
              createdBy: user.id,
              createdByName: user.displayName,
            );
      }, message: 'Preparing receiving…');
      if (!mounted) return;
      // Navigation is best-effort in widget tests without a router.
      try {
        context.push('${RoutePaths.bulkReceiving}/$rid');
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareCsv(PurchaseOrderEntity po) =>
      saveReportCsv(context, buildPurchaseOrderCsv(po),
          '${po.referenceNumber}.csv');

  Future<void> _onMenu(String value, PurchaseOrderEntity po) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(value == 'cancel'
            ? 'Cancel this purchase order?'
            : 'Delete this purchase order?'),
        content: Text(value == 'cancel'
            ? '${po.referenceNumber} will be marked cancelled.'
            : '${po.referenceNumber} will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(value == 'cancel' ? 'Cancel order' : 'Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (value == 'cancel') {
      await _run(
          () => ref
              .read(purchaseOrderRepositoryProvider)
              .cancelPurchaseOrder(po.id),
          'Cancelling…');
    } else {
      await _run(
          () => ref
              .read(purchaseOrderRepositoryProvider)
              .deletePurchaseOrder(po.id),
          'Deleting…');
      if (mounted) context.pop();
    }
  }
}
```

The bare `catch (_)` around the post-receive push exists only for router-less widget tests; if `flutter analyze` flags `avoid_catches_without_on_clauses` or similar, switch the test to a minimal GoRouter harness (Step 1 note) and drop the catch.

- [ ] **Step 4: Run tests**

Run: `flutter test test/presentation/mobile/screens/receiving/purchase_orders/ && flutter analyze`
Expected: PASS (all PO widget tests), analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen.dart test/presentation/mobile/screens/receiving/purchase_orders/purchase_order_detail_screen_test.dart
git commit -m "feat(po): purchase order detail with lifecycle actions and CSV share"
```

---

### Task 15: Firestore rules + full verification

**Files:**
- Modify: `firestore.rules` (new block; **do not deploy**)

- [ ] **Step 1: Add the rules block**

In `firestore.rules`, directly after the `match /receivings/{receivingId} { … }` block (around line 200), add:

```
    match /purchase_orders/{purchaseOrderId} {
      // Staff and admin can read purchase orders
      allow read: if isStaffOrAdmin() && isActiveUser();

      // Staff and admin can create/update purchase orders
      allow create, update: if isStaffOrAdmin() && isActiveUser();

      // Only admin can delete purchase orders
      allow delete: if isAdmin() && isActiveUser();
    }
```

- [ ] **Step 2: Full verification**

Run: `flutter analyze`
Expected: No issues found.

Run: `flutter test`
Expected: ALL tests pass (roughly 990+ pre-existing + ~35 new). Any pre-existing failure unrelated to this work: report it, don't hide it.

- [ ] **Step 3: Commit**

```bash
git add firestore.rules
git commit -m "feat(po): firestore rules for purchase_orders (staff+admin write, admin delete)"
```

- [ ] **Step 4: STOP — do not deploy**

Rules deployment (`firebase deploy --only firestore:rules`) is production-affecting. Surface to the user that the branch is ready and that:
1. Rules must be deployed before the feature can write to `purchase_orders`.
2. The feature ships to phones only via a new APK build + manual `adb install` (no CI).

---

## Plan Self-Review (completed)

- **Spec coverage:** data model + lifecycle (Tasks 1–4), suggestion engine + params (5, 9), receiving integration incl. atomic pair + unlink guards (6–8), screens/routes/permissions (11–14), CSV (10), rules + no-deploy gate (15), error handling (cap note Task 13, waiting dialog + double-submit locks Tasks 13–14, idempotent Receive Task 7). ✔
- **Placeholders:** Task 12 ships real minimal shells for the Task 13/14 screens so the router compiles at every commit — intentional stepping stone, not a TBD. Two "open the file and match the real signature" notes (SaleEntity ctor, AppCard API) are verification instructions with the assertion set pinned, not missing design. ✔
- **Type consistency:** `startReceiving` named params match across Tasks 3/7/14; `ReorderParams` record shape matches across 5/9/13; `purchaseOrderId` field name matches across 6/7/8; route constants match across 11/12/14. ✔
