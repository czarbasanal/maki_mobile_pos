# Mechanics Admin List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an admin-configurable Mechanics list (name + active) that cashiers can later assign to a service draft.

**Architecture:** Mirror the existing admin name-list pattern (CategoryEntity/Model/Repository/Provider/EditorScreen) as standalone Mechanic* files — clean naming, room to grow (commission %, contact) without entangling category code. Stored in a `mechanics` Firestore collection; surfaced as its own Settings tile + route, gated by the existing `manageCategories` admin permission. Active mechanics stream feeds the cashier picker (built in the labor plan).

**Tech Stack:** Flutter, Riverpod, cloud_firestore; tests use flutter_test + fake_cloud_firestore + mocktail.

**Spec:** docs/superpowers/specs/2026-05-30-pos-labor-mechanics-design.md (§5)

**Prerequisite:** none — this plan ships independently. **Execute it before** the Service-Draft Labor plan, whose mechanic picker consumes `activeMechanicsProvider` and which also edits the `entities.dart` / `models.dart` barrels.

---

### Task 1: Add `FirestoreCollections.mechanics` + `MechanicEntity` + barrel export

**Files:**
- Modify: `lib/core/constants/firestore_collections.dart`
- Create: `lib/domain/entities/mechanic_entity.dart`
- Modify: `lib/domain/entities/entities.dart`
- Test: `test/domain/entities/mechanic_entity_test.dart`

- [ ] **Step 1: Write the failing test** — `test/domain/entities/mechanic_entity_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('MechanicEntity', () {
    late MechanicEntity mechanic;

    setUp(() {
      mechanic = MechanicEntity(
        id: 'mech-1',
        name: 'Juan Dela Cruz',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
        createdBy: 'admin-1',
      );
    });

    test('holds its fields', () {
      expect(mechanic.id, 'mech-1');
      expect(mechanic.name, 'Juan Dela Cruz');
      expect(mechanic.isActive, true);
      expect(mechanic.createdAt, DateTime(2026, 5, 30));
      expect(mechanic.createdBy, 'admin-1');
      expect(mechanic.updatedAt, isNull);
      expect(mechanic.updatedBy, isNull);
    });

    test('copyWith overrides only the given fields', () {
      final updated = mechanic.copyWith(name: 'Pedro', isActive: false);
      expect(updated.name, 'Pedro');
      expect(updated.isActive, false);
      expect(updated.id, 'mech-1');
      expect(updated.createdAt, DateTime(2026, 5, 30));
    });

    test('equality is value-based via props', () {
      final same = MechanicEntity(
        id: 'mech-1',
        name: 'Juan Dela Cruz',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
        createdBy: 'admin-1',
      );
      expect(mechanic, equals(same));
      expect(mechanic, isNot(equals(mechanic.copyWith(name: 'X'))));
    });

    test('empty() produces a blank active mechanic', () {
      final empty = MechanicEntity.empty();
      expect(empty.id, '');
      expect(empty.name, '');
      expect(empty.isActive, true);
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/domain/entities/mechanic_entity_test.dart`. Fails to compile: `MechanicEntity` is not defined / not exported from `entities.dart`.

- [ ] **Step 3: Implement** — add the collection constant to `lib/core/constants/firestore_collections.dart` (after the `voidReasons` constant, before the `voidRequests` block):
```dart
  /// Mechanics collection - admin-managed mechanic list for service drafts
  static const String mechanics = 'mechanics';
```
Create `lib/domain/entities/mechanic_entity.dart`:
```dart
import 'package:equatable/equatable.dart';

/// Domain entity representing an admin-managed mechanic.
///
/// Mechanics are assigned to a service draft/sale. Inactive mechanics drop
/// off the picker but stay valid on historical records via the snapshotted
/// name on the draft/sale.
class MechanicEntity extends Equatable {
  /// Unique identifier.
  final String id;

  /// Mechanic name (display + match key).
  final String name;

  /// Whether this mechanic is active. Soft-deleted mechanics stay in the
  /// collection so historical records keep matching.
  final bool isActive;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const MechanicEntity({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  MechanicEntity copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return MechanicEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  factory MechanicEntity.empty() {
    return MechanicEntity(
      id: '',
      name: '',
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        isActive,
        createdAt,
        updatedAt,
        createdBy,
        updatedBy,
      ];
}
```
Add to `lib/domain/entities/entities.dart` (after the `category_entity.dart` export):
```dart
export 'mechanic_entity.dart';
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/domain/entities/mechanic_entity_test.dart`.

- [ ] **Step 5: Commit** — `git add lib/core/constants/firestore_collections.dart lib/domain/entities/mechanic_entity.dart lib/domain/entities/entities.dart test/domain/entities/mechanic_entity_test.dart && git commit -m "feat(mechanics): add MechanicEntity + mechanics collection constant"`

---

### Task 2: Add `MechanicModel` + barrel export

**Files:**
- Create: `lib/data/models/mechanic_model.dart`
- Modify: `lib/data/models/models.dart`
- Test: `test/data/models/mechanic_model_test.dart`

- [ ] **Step 1: Write the failing test** — `test/data/models/mechanic_model_test.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('MechanicModel', () {
    test('fromMap reads fields and defaults', () {
      final model = MechanicModel.fromMap(
        {
          'name': 'Juan Dela Cruz',
          'isActive': false,
          'createdAt': Timestamp.fromDate(DateTime(2026, 5, 30)),
          'createdBy': 'admin-1',
        },
        'mech-1',
      );
      expect(model.id, 'mech-1');
      expect(model.name, 'Juan Dela Cruz');
      expect(model.isActive, false);
      expect(model.createdAt, DateTime(2026, 5, 30));
      expect(model.createdBy, 'admin-1');
      expect(model.updatedAt, isNull);
    });

    test('fromMap defaults missing name/isActive for legacy docs', () {
      final model = MechanicModel.fromMap(<String, dynamic>{}, 'mech-x');
      expect(model.name, '');
      expect(model.isActive, true);
    });

    test('toMap (plain) emits name + isActive + createdAt', () {
      final model = MechanicModel(
        id: 'mech-1',
        name: 'Pedro',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
        createdBy: 'admin-1',
      );
      final map = model.toMap();
      expect(map['name'], 'Pedro');
      expect(map['isActive'], true);
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['createdBy'], 'admin-1');
    });

    test('toCreateMap stamps server timestamps + createdBy', () {
      final model = MechanicModel(
        id: '',
        name: 'Pedro',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );
      final map = model.toCreateMap('admin-9');
      expect(map['createdBy'], 'admin-9');
      expect(map['updatedBy'], 'admin-9');
      expect(map['createdAt'], isA<FieldValue>());
    });

    test('round-trips entity <-> model', () {
      final entity = MechanicEntity(
        id: 'mech-1',
        name: 'Juan',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
        createdBy: 'admin-1',
      );
      final back = MechanicModel.fromEntity(entity).toEntity();
      expect(back, equals(entity));
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/data/models/mechanic_model_test.dart`. Fails: `MechanicModel` is not defined / not exported.

- [ ] **Step 3: Implement** — create `lib/data/models/mechanic_model.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Data model for [MechanicEntity] with Firestore serialization.
class MechanicModel {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;

  const MechanicModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  factory MechanicModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return MechanicModel.fromMap(data, doc.id);
  }

  factory MechanicModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MechanicModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(map['updatedAt']),
      createdBy: map['createdBy'] as String?,
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap({
    bool forCreate = false,
    bool forUpdate = false,
  }) {
    final map = <String, dynamic>{
      'name': name,
      'isActive': isActive,
    };

    if (forCreate) {
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
      map['createdBy'] = createdBy;
      map['updatedBy'] = createdBy;
    } else if (forUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
      map['updatedBy'] = updatedBy;
    } else {
      map['createdAt'] = Timestamp.fromDate(createdAt);
      if (updatedAt != null) {
        map['updatedAt'] = Timestamp.fromDate(updatedAt!);
      }
      map['createdBy'] = createdBy;
      map['updatedBy'] = updatedBy;
    }

    return map;
  }

  Map<String, dynamic> toCreateMap(String createdByUserId) {
    return copyWith(createdBy: createdByUserId).toMap(forCreate: true);
  }

  Map<String, dynamic> toUpdateMap(String updatedByUserId) {
    return copyWith(updatedBy: updatedByUserId).toMap(forUpdate: true);
  }

  MechanicEntity toEntity() {
    return MechanicEntity(
      id: id,
      name: name,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }

  factory MechanicModel.fromEntity(MechanicEntity entity) {
    return MechanicModel(
      id: entity.id,
      name: entity.name,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
    );
  }

  MechanicModel copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return MechanicModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
```
Add to `lib/data/models/models.dart` (after the `category_model.dart` export):
```dart
export 'mechanic_model.dart';
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/data/models/mechanic_model_test.dart`.

- [ ] **Step 5: Commit** — `git add lib/data/models/mechanic_model.dart lib/data/models/models.dart test/data/models/mechanic_model_test.dart && git commit -m "feat(mechanics): add MechanicModel + Firestore serialization"`

---

### Task 3: Add `MechanicRepository` abstract + `MechanicRepositoryImpl`

**Files:**
- Create: `lib/domain/repositories/mechanic_repository.dart`
- Create: `lib/data/repositories/mechanic_repository_impl.dart`
- Test: `test/data/repositories/mechanic_repository_impl_test.dart`

- [ ] **Step 1: Write the failing test** — `test/data/repositories/mechanic_repository_impl_test.dart`:
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/mechanic_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MechanicRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = MechanicRepositoryImpl(firestore: fakeFirestore);
  });

  MechanicEntity newMechanic({String name = 'Juan'}) => MechanicEntity(
        id: '',
        name: name,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );

  group('MechanicRepositoryImpl', () {
    test('createMechanic assigns an id and stamps createdBy', () async {
      final created = await repository.createMechanic(
        mechanic: newMechanic(),
        createdBy: 'admin-1',
      );
      expect(created.id, isNotEmpty);
      expect(created.name, 'Juan');
      expect(created.createdBy, 'admin-1');
    });

    test('createMechanic throws DuplicateEntryException on existing name',
        () async {
      await repository.createMechanic(
        mechanic: newMechanic(name: 'Pedro'),
        createdBy: 'admin-1',
      );
      expect(
        () => repository.createMechanic(
          mechanic: newMechanic(name: 'Pedro'),
          createdBy: 'admin-1',
        ),
        throwsA(isA<DuplicateEntryException>()),
      );
    });

    test('getMechanicById returns the persisted mechanic', () async {
      final created = await repository.createMechanic(
        mechanic: newMechanic(),
        createdBy: 'admin-1',
      );
      final fetched = await repository.getMechanicById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Juan');
    });

    test('getMechanicById returns null when missing', () async {
      expect(await repository.getMechanicById('nope'), isNull);
    });

    test('watchActive emits only active mechanics, A->Z', () async {
      final pedro = await repository.createMechanic(
        mechanic: newMechanic(name: 'Pedro'),
        createdBy: 'admin-1',
      );
      await repository.createMechanic(
        mechanic: newMechanic(name: 'Andres'),
        createdBy: 'admin-1',
      );
      await repository.setActive(
        mechanicId: pedro.id,
        active: false,
        updatedBy: 'admin-1',
      );

      final active = await repository.watchActive().first;
      expect(active.map((m) => m.name), ['Andres']);
    });

    test('watchAll emits active + inactive sorted A->Z', () async {
      final pedro = await repository.createMechanic(
        mechanic: newMechanic(name: 'Pedro'),
        createdBy: 'admin-1',
      );
      await repository.createMechanic(
        mechanic: newMechanic(name: 'Andres'),
        createdBy: 'admin-1',
      );
      await repository.setActive(
        mechanicId: pedro.id,
        active: false,
        updatedBy: 'admin-1',
      );

      final all = await repository.watchAll().first;
      expect(all.map((m) => m.name), ['Andres', 'Pedro']);
    });

    test('updateMechanic persists the new name', () async {
      final created = await repository.createMechanic(
        mechanic: newMechanic(),
        createdBy: 'admin-1',
      );
      final updated = await repository.updateMechanic(
        mechanic: created.copyWith(name: 'Juanito'),
        updatedBy: 'admin-2',
      );
      expect(updated.name, 'Juanito');
      expect(updated.updatedBy, 'admin-2');
    });

    test('setActive deactivates a mechanic', () async {
      final created = await repository.createMechanic(
        mechanic: newMechanic(),
        createdBy: 'admin-1',
      );
      await repository.setActive(
        mechanicId: created.id,
        active: false,
        updatedBy: 'admin-1',
      );
      final fetched = await repository.getMechanicById(created.id);
      expect(fetched!.isActive, false);
    });

    test('nameExists honours excludeMechanicId', () async {
      final created = await repository.createMechanic(
        mechanic: newMechanic(name: 'Pedro'),
        createdBy: 'admin-1',
      );
      expect(await repository.nameExists(name: 'Pedro'), true);
      expect(
        await repository.nameExists(
          name: 'Pedro',
          excludeMechanicId: created.id,
        ),
        false,
      );
      expect(await repository.nameExists(name: 'Ghost'), false);
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/data/repositories/mechanic_repository_impl_test.dart`. Fails: `MechanicRepositoryImpl` is not defined.

- [ ] **Step 3: Implement** — create `lib/domain/repositories/mechanic_repository.dart`:
```dart
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Abstract repository contract for admin-managed Mechanic operations.
///
/// Backed by the single `mechanics` collection.
abstract class MechanicRepository {
  /// Streams active mechanics ordered A→Z by name.
  Stream<List<MechanicEntity>> watchActive();

  /// Streams all mechanics (active + inactive) for admin management.
  Stream<List<MechanicEntity>> watchAll();

  /// Reads a single mechanic by ID.
  Future<MechanicEntity?> getMechanicById(String mechanicId);

  /// Creates a mechanic. Returns the persisted entity with its assigned ID.
  Future<MechanicEntity> createMechanic({
    required MechanicEntity mechanic,
    required String createdBy,
  });

  /// Updates an existing mechanic.
  Future<MechanicEntity> updateMechanic({
    required MechanicEntity mechanic,
    required String updatedBy,
  });

  /// Soft-deletes (deactivates) or reactivates a mechanic.
  Future<void> setActive({
    required String mechanicId,
    required bool active,
    required String updatedBy,
  });

  /// Checks whether a mechanic name already exists (exact match).
  Future<bool> nameExists({
    required String name,
    String? excludeMechanicId,
  });
}
```
Create `lib/data/repositories/mechanic_repository_impl.dart`:
```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/mechanic_repository.dart';

/// Firestore implementation of [MechanicRepository], bound to the single
/// `mechanics` collection.
class MechanicRepositoryImpl implements MechanicRepository {
  final FirebaseFirestore _firestore;

  MechanicRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(FirestoreCollections.mechanics);

  @override
  Stream<List<MechanicEntity>> watchActive() {
    return _ref
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(_snapshotToSorted);
  }

  @override
  Stream<List<MechanicEntity>> watchAll() {
    return _ref.snapshots().map(_snapshotToSorted);
  }

  @override
  Future<MechanicEntity?> getMechanicById(String mechanicId) async {
    try {
      final doc = await _ref.doc(mechanicId).get();
      if (!doc.exists) return null;
      return MechanicModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get mechanic: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<MechanicEntity> createMechanic({
    required MechanicEntity mechanic,
    required String createdBy,
  }) async {
    try {
      if (await nameExists(name: mechanic.name)) {
        throw DuplicateEntryException(
          field: 'name',
          value: mechanic.name,
          message: 'A mechanic with this name already exists',
        );
      }

      final model = MechanicModel.fromEntity(mechanic);
      final docRef = await _ref.add(model.toCreateMap(createdBy));
      return mechanic.copyWith(id: docRef.id, createdBy: createdBy);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create mechanic: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<MechanicEntity> updateMechanic({
    required MechanicEntity mechanic,
    required String updatedBy,
  }) async {
    try {
      if (await nameExists(
        name: mechanic.name,
        excludeMechanicId: mechanic.id,
      )) {
        throw DuplicateEntryException(
          field: 'name',
          value: mechanic.name,
          message: 'A mechanic with this name already exists',
        );
      }

      final model = MechanicModel.fromEntity(mechanic);
      await _ref.doc(mechanic.id).update(model.toUpdateMap(updatedBy));

      final updated = await getMechanicById(mechanic.id);
      if (updated == null) {
        throw const DatabaseException(
          message: 'Mechanic not found after update',
        );
      }
      return updated;
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update mechanic: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> setActive({
    required String mechanicId,
    required bool active,
    required String updatedBy,
  }) async {
    try {
      await _ref.doc(mechanicId).update({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to ${active ? 'activate' : 'deactivate'} mechanic: '
            '${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<bool> nameExists({
    required String name,
    String? excludeMechanicId,
  }) async {
    try {
      final snapshot =
          await _ref.where('name', isEqualTo: name).limit(2).get();
      if (excludeMechanicId == null) {
        return snapshot.docs.isNotEmpty;
      }
      return snapshot.docs.any((doc) => doc.id != excludeMechanicId);
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to check mechanic name: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  // Sort client-side A→Z (case-insensitive). Avoids a Firestore index and the
  // dataset is small.
  List<MechanicEntity> _snapshotToSorted(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final list = snapshot.docs
        .map((doc) => MechanicModel.fromFirestore(doc).toEntity())
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }
}
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/data/repositories/mechanic_repository_impl_test.dart`.

- [ ] **Step 5: Commit** — `git add lib/domain/repositories/mechanic_repository.dart lib/data/repositories/mechanic_repository_impl.dart test/data/repositories/mechanic_repository_impl_test.dart && git commit -m "feat(mechanics): add MechanicRepository + Firestore impl"`

---

### Task 4: Add `mechanic_provider` (repo + stream + operations notifier) + barrel export

**Files:**
- Create: `lib/presentation/providers/mechanic_provider.dart`
- Modify: `lib/presentation/providers/providers.dart`
- Test: `test/presentation/providers/mechanic_provider_test.dart`

- [ ] **Step 1: Write the failing test** — `test/presentation/providers/mechanic_provider_test.dart`. Uses a real `FakeFirebaseFirestore`-backed repo override, and a fake `currentUserProvider` override so the operations notifier can resolve an actor id:
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/mechanic_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/mechanic_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MechanicRepository repo;

  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'admin@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [
        mechanicRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWith((ref) => Stream.value(admin())),
      ],
    );
  }

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = MechanicRepositoryImpl(firestore: fakeFirestore);
  });

  test('create then deactivate via the operations notifier', () async {
    final container = makeContainer();
    addTearDown(container.dispose);

    // Warm currentUserProvider so the notifier can resolve the actor.
    await container.read(currentUserProvider.future);

    final ops = container.read(mechanicOperationsProvider.notifier);

    final created = await ops.create(
      mechanic: MechanicEntity(
        id: '',
        name: 'Juan',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    expect(created, isNotNull);
    expect(created!.id, isNotEmpty);
    expect(created.createdBy, 'admin-1');

    final ok = await ops.deactivate(created.id);
    expect(ok, true);

    final fetched = await repo.getMechanicById(created.id);
    expect(fetched!.isActive, false);
  });

  test('activeMechanicsProvider emits only active mechanics', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(currentUserProvider.future);

    final ops = container.read(mechanicOperationsProvider.notifier);
    final pedro = await ops.create(
      mechanic: MechanicEntity(
        id: '',
        name: 'Pedro',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    await ops.create(
      mechanic: MechanicEntity(
        id: '',
        name: 'Andres',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
    );
    await ops.deactivate(pedro!.id);

    final active = await container.read(activeMechanicsProvider.future);
    expect(active.map((m) => m.name), ['Andres']);
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/providers/mechanic_provider_test.dart`. Fails: `mechanicRepositoryProvider` / `mechanicOperationsProvider` not defined.

- [ ] **Step 3: Implement** — create `lib/presentation/providers/mechanic_provider.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/repositories/mechanic_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/mechanic_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/services/firebase_service.dart';

// ==================== REPOSITORY PROVIDER ====================

/// Provides the [MechanicRepository] bound to the `mechanics` collection.
final mechanicRepositoryProvider = Provider<MechanicRepository>((ref) {
  return MechanicRepositoryImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

// ==================== MECHANIC QUERIES ====================

/// Streams active mechanics. Auth-gated so it does not emit a
/// permission-denied error before the user's session is warm. Used by the
/// cashier-facing mechanic picker.
final activeMechanicsProvider =
    StreamProvider<List<MechanicEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(mechanicRepositoryProvider).watchActive();
  });
});

/// Streams all mechanics (active + inactive) for the admin editor screen.
final allMechanicsProvider = StreamProvider<List<MechanicEntity>>((ref) {
  return authGatedStream(ref, (_) {
    return ref.watch(mechanicRepositoryProvider).watchAll();
  });
});

// ==================== MECHANIC OPERATIONS ====================

/// Notifier for mechanic mutations. Permission is checked at the route layer;
/// this notifier does not duplicate that gate.
class MechanicOperationsNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  MechanicOperationsNotifier(this._ref)
      : super(const AsyncValue.data(null));

  MechanicRepository get _repository => _ref.read(mechanicRepositoryProvider);

  String _requireUserId() {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null) {
      throw const UnauthenticatedException();
    }
    return user.id;
  }

  Future<MechanicEntity?> create({required MechanicEntity mechanic}) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final created = await _repository.createMechanic(
        mechanic: mechanic,
        createdBy: actorId,
      );
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<MechanicEntity?> update({required MechanicEntity mechanic}) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      final updated = await _repository.updateMechanic(
        mechanic: mechanic,
        updatedBy: actorId,
      );
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> deactivate(String mechanicId) =>
      _setActive(mechanicId: mechanicId, active: false);

  Future<bool> reactivate(String mechanicId) =>
      _setActive(mechanicId: mechanicId, active: true);

  Future<bool> _setActive({
    required String mechanicId,
    required bool active,
  }) async {
    state = const AsyncValue.loading();
    try {
      final actorId = _requireUserId();
      await _repository.setActive(
        mechanicId: mechanicId,
        active: active,
        updatedBy: actorId,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> nameExists(String name, {String? excludeMechanicId}) async {
    try {
      return await _repository.nameExists(
        name: name,
        excludeMechanicId: excludeMechanicId,
      );
    } catch (_) {
      return false;
    }
  }
}

final mechanicOperationsProvider =
    StateNotifierProvider<MechanicOperationsNotifier, AsyncValue<void>>(
        (ref) {
  return MechanicOperationsNotifier(ref);
});
```
Add to `lib/presentation/providers/providers.dart` (after the `category_provider.dart` export):
```dart
export 'mechanic_provider.dart';
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/providers/mechanic_provider_test.dart`.

- [ ] **Step 5: Commit** — `git add lib/presentation/providers/mechanic_provider.dart lib/presentation/providers/providers.dart test/presentation/providers/mechanic_provider_test.dart && git commit -m "feat(mechanics): add mechanic provider (repo, streams, operations notifier)"`

---

### Task 5: Add mechanics route names/paths + nested GoRoute + admin route guard

**Files:**
- Modify: `lib/config/router/route_names.dart`
- Modify: `lib/config/router/app_routes.dart`
- Modify: `lib/config/router/route_guards.dart`
- Test: `test/config/router/route_guards_mechanics_test.dart`

- [ ] **Step 1: Write the failing test** — `test/config/router/route_guards_mechanics_test.dart`. Asserts the admin gate (reusing `Permission.manageCategories`) on `RoutePaths.mechanics`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/config/router/route_guards.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  UserEntity user(UserRole role) => UserEntity(
        id: 'u1',
        email: 'u@x.com',
        displayName: 'U',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );

  group('RouteGuards — mechanics', () {
    test('path constant is /settings/mechanics', () {
      expect(RoutePaths.mechanics, '/settings/mechanics');
      expect(RouteNames.mechanics, 'mechanics');
    });

    test('admin can access mechanics editor', () {
      expect(
        RouteGuards.canAccess(RoutePaths.mechanics, user(UserRole.admin)),
        true,
      );
    });

    test('cashier cannot access mechanics editor', () {
      expect(
        RouteGuards.canAccess(RoutePaths.mechanics, user(UserRole.cashier)),
        false,
      );
    });
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/config/router/route_guards_mechanics_test.dart`. Fails: `RoutePaths.mechanics` / `RouteNames.mechanics` undefined; guard denies the admin (no entry).

- [ ] **Step 3: Implement** — in `lib/config/router/route_names.dart`, add after the `categoryEditor` constant (before `about`):
```dart
  /// Mechanics admin editor — `/settings/mechanics`.
  static const String mechanics = 'mechanics';
```
and in `RoutePaths`, after the `categoryEditor` path (before `about`):
```dart
  static const String mechanics = '/settings/mechanics';
```
In `lib/config/router/app_routes.dart`, add the import next to the other settings-screen imports (after the `category_settings_screen.dart` import):
```dart
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/mechanic_editor_screen.dart';
```
and register the nested route inside the `RoutePaths.settings` `GoRoute`'s `routes:` list (after the `categories` route, before `about`):
```dart
          GoRoute(
            path: 'mechanics',
            name: RouteNames.mechanics,
            builder: (context, state) => const MechanicEditorScreen(),
          ),
```
In `lib/config/router/route_guards.dart`, add the exact-match entry to `protectedRoutes` (after the `'/settings/categories'` line):
```dart
    '/settings/mechanics': Permission.manageCategories,
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/config/router/route_guards_mechanics_test.dart`.

> Note: `MechanicEditorScreen` is created in the next task. If running before that task, this test still passes once the route names/guard are added; the `app_routes.dart` import line should be added together with the editor-screen task so the project compiles. Sequence the editor-screen task immediately after this one (or land both before running the full suite).

- [ ] **Step 5: Commit** — `git add lib/config/router/route_names.dart lib/config/router/route_guards.dart test/config/router/route_guards_mechanics_test.dart && git commit -m "feat(mechanics): add mechanics route names + admin route guard"`

---

### Task 6: Add `MechanicEditorScreen` (standalone copy of CategoryEditorScreen)

**Files:**
- Create: `lib/presentation/mobile/screens/settings/mechanic_editor_screen.dart`
- Test: `test/presentation/widgets/mechanic_editor_screen_test.dart`

- [ ] **Step 1: Write the failing test** — `test/presentation/widgets/mechanic_editor_screen_test.dart`. Pumps the screen inside a `ProviderScope` overriding `mechanicRepositoryProvider` with a fake-Firestore-backed repo and `currentUserProvider` with an admin, then verifies the list renders mechanic names and the empty state:
```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/mechanic_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/mechanic_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/mechanic_editor_screen.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MechanicRepository repo;

  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'admin@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );

  Widget harness() => ProviderScope(
        overrides: [
          mechanicRepositoryProvider.overrideWithValue(repo),
          currentUserProvider.overrideWith((ref) => Stream.value(admin())),
        ],
        child: const MaterialApp(home: MechanicEditorScreen()),
      );

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = MechanicRepositoryImpl(firestore: fakeFirestore);
  });

  testWidgets('shows empty state when there are no mechanics',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Mechanics'), findsWidgets);
    expect(find.text('No mechanics yet'), findsOneWidget);
  });

  testWidgets('renders a mechanic row from the repository', (tester) async {
    await repo.createMechanic(
      mechanic: MechanicEntity(
        id: '',
        name: 'Juan Dela Cruz',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
      createdBy: 'admin-1',
    );

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/mechanic_editor_screen_test.dart`. Fails: `MechanicEditorScreen` not defined.

- [ ] **Step 3: Implement** — create `lib/presentation/mobile/screens/settings/mechanic_editor_screen.dart`:
```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';

/// Admin CRUD editor for the mechanics list.
///
/// Lists active + inactive mechanics; supports add / edit / deactivate /
/// reactivate with name-exists validation. Inactive entries stay (greyed) so
/// admin can reactivate them; deactivating never breaks historical records,
/// which carry a snapshotted mechanic name.
class MechanicEditorScreen extends ConsumerStatefulWidget {
  const MechanicEditorScreen({super.key});

  @override
  ConsumerState<MechanicEditorScreen> createState() =>
      _MechanicEditorScreenState();
}

class _MechanicEditorScreenState extends ConsumerState<MechanicEditorScreen> {
  @override
  Widget build(BuildContext context) {
    final mechanicsAsync = ref.watch(allMechanicsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => context.goBackOr(RoutePaths.settings),
        ),
        title: const Text('Mechanics'),
      ),
      body: mechanicsAsync.when(
        data: (mechanics) => _buildList(context, mechanics),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Failed to load mechanics: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMechanicDialog(context),
        icon: const Icon(CupertinoIcons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<MechanicEntity> mechanics) {
    if (mechanics.isEmpty) {
      return const _EmptyState();
    }

    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl * 2,
      ),
      itemCount: mechanics.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final mechanic = mechanics[index];
        return _MechanicRow(
          mechanic: mechanic,
          theme: theme,
          onEdit: () => _showMechanicDialog(context, existing: mechanic),
          onToggleActive: () => _toggleActive(mechanic),
        );
      },
    );
  }

  Future<void> _toggleActive(MechanicEntity mechanic) async {
    final ops = ref.read(mechanicOperationsProvider.notifier);
    final ok = mechanic.isActive
        ? await ops.deactivate(mechanic.id)
        : await ops.reactivate(mechanic.id);
    if (!mounted) return;
    if (ok) {
      context.showSuccessSnackBar(
        mechanic.isActive ? 'Mechanic deactivated' : 'Mechanic reactivated',
      );
    } else {
      context.showErrorSnackBar('Operation failed');
    }
  }

  Future<void> _showMechanicDialog(
    BuildContext context, {
    MechanicEntity? existing,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _MechanicFormDialog(existing: existing),
    );
    if (!context.mounted || saved != true) return;
    context.showSuccessSnackBar(
      existing == null ? 'Mechanic created' : 'Mechanic updated',
    );
  }
}

class _MechanicRow extends StatelessWidget {
  const _MechanicRow({
    required this.mechanic,
    required this.theme,
    required this.onEdit,
    required this.onToggleActive,
  });

  final MechanicEntity mechanic;
  final ThemeData theme;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final muted = !mechanic.isActive;
    final nameStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      color: muted ? theme.colorScheme.onSurfaceVariant : null,
      decoration: muted ? TextDecoration.lineThrough : null,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        title: Text(mechanic.name, style: nameStyle),
        subtitle: muted
            ? Text(
                'Inactive',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(CupertinoIcons.pencil),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: muted ? 'Reactivate' : 'Deactivate',
              icon: Icon(
                muted
                    ? CupertinoIcons.arrow_clockwise
                    : CupertinoIcons.archivebox,
              ),
              onPressed: onToggleActive,
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.wrench,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No mechanics yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tap Add to create one.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MechanicFormDialog extends ConsumerStatefulWidget {
  const _MechanicFormDialog({this.existing});

  final MechanicEntity? existing;

  @override
  ConsumerState<_MechanicFormDialog> createState() =>
      _MechanicFormDialogState();
}

class _MechanicFormDialogState extends ConsumerState<_MechanicFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _isActive = existing?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Mechanic' : 'New Mechanic'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(CupertinoIcons.wrench),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return 'Name is required';
                if (trimmed.length < 2) {
                  return 'Name must be at least 2 characters';
                }
                return null;
              },
            ),
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: Text(
                  _isActive
                      ? 'Visible in the mechanic picker'
                      : 'Hidden from the picker (existing records keep matching)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final ops = ref.read(mechanicOperationsProvider.notifier);

    // Capture the navigator before any await: pop must not reach for
    // BuildContext after an async gap.
    final navigator = Navigator.of(context);

    setState(() => _isSaving = true);

    final existing = widget.existing;
    MechanicEntity? result;
    if (existing == null) {
      result = await ops.create(
        mechanic: MechanicEntity(
          id: '',
          name: name,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );
    } else {
      result = await ops.update(
        mechanic: existing.copyWith(name: name, isActive: _isActive),
      );
    }

    if (!mounted) return;

    if (result != null) {
      navigator.pop(true);
    } else {
      setState(() => _isSaving = false);
      final err = ref.read(mechanicOperationsProvider).error;
      context.showErrorSnackBar(
        err == null ? 'Failed to save mechanic' : 'Failed: $err',
      );
    }
  }
}
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/mechanic_editor_screen_test.dart`. Also confirm the router compiles now that the import added in the previous task resolves: `flutter test test/config/router/route_guards_mechanics_test.dart`.

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/screens/settings/mechanic_editor_screen.dart lib/config/router/app_routes.dart test/presentation/widgets/mechanic_editor_screen_test.dart && git commit -m "feat(mechanics): add MechanicEditorScreen + wire nested settings route"`

---

### Task 7: Add the Mechanics tile to the Administration section of Settings

**Files:**
- Modify: `lib/presentation/mobile/screens/settings/settings_screen.dart`
- Test: `test/presentation/widgets/settings_mechanics_tile_test.dart`

- [ ] **Step 1: Write the failing test** — `test/presentation/widgets/settings_mechanics_tile_test.dart`. Pumps `SettingsScreen` for an admin and asserts the new tile (title + subtitle) is present:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/theme_mode_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/settings_screen.dart';

void main() {
  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'admin@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );

  testWidgets('Administration section shows a Mechanics tile for admins',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(admin())),
          themeModeProvider.overrideWith((ref) => ThemeModeNotifier()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mechanics'), findsOneWidget);
    expect(
      find.text('Used to assign a mechanic to a service draft'),
      findsOneWidget,
    );
  });
}
```
> If `ThemeModeNotifier`'s constructor differs in the repo, drop the `themeModeProvider` override line — `_buildThemeTile` reads it via the real provider, which is fine in a widget test. Adjust to match the actual `themeModeProvider` definition when writing the test.

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/presentation/widgets/settings_mechanics_tile_test.dart`. Fails: no widget with text "Mechanics".

- [ ] **Step 3: Implement** — in `lib/presentation/mobile/screens/settings/settings_screen.dart`, add a tile inside the `Administration` `_SectionCard` children, immediately after the "Manage Lists" `SettingsTile` (closing `),` on line 85):
```dart
                SettingsTile(
                  icon: CupertinoIcons.wrench,
                  title: 'Mechanics',
                  subtitle: 'Used to assign a mechanic to a service draft',
                  onTap: () => context.push(RoutePaths.mechanics),
                ),
```

- [ ] **Step 4: Run tests, expect PASS** — `flutter test test/presentation/widgets/settings_mechanics_tile_test.dart`.

- [ ] **Step 5: Commit** — `git add lib/presentation/mobile/screens/settings/settings_screen.dart test/presentation/widgets/settings_mechanics_tile_test.dart && git commit -m "feat(mechanics): add Mechanics tile to settings Administration section"`
