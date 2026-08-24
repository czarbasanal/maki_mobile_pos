import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/core/constants/firestore_collections.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/data/models/models.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/employee_repository.dart';

/// Firestore implementation of [EmployeeRepository] — the `employees`
/// collection shared with the web admin. Mirrors the mechanic repository's
/// conventions: injectable Firestore, FirebaseException → DatabaseException,
/// client-side A→Z sort (no index for a small registry).
class EmployeeRepositoryImpl implements EmployeeRepository {
  final FirebaseFirestore _firestore;

  EmployeeRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(FirestoreCollections.employees);

  List<EmployeeEntity> _sorted(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs
        .map((d) => EmployeeModel.fromFirestore(d).toEntity())
        .toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Stream<List<EmployeeEntity>> watchActive() =>
      _ref.where('isActive', isEqualTo: true).snapshots().map(_sorted);

  @override
  Stream<List<EmployeeEntity>> watchAll() => _ref.snapshots().map(_sorted);

  @override
  Future<EmployeeEntity?> getById(String id) async {
    try {
      final doc = await _ref.doc(id).get();
      if (!doc.exists) return null;
      return EmployeeModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to get employee: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<EmployeeEntity> create(EmployeeEntity employee) async {
    try {
      final map = EmployeeModel.fromEntity(employee).toMap(forCreate: true);
      final ref = await _ref.add(map);
      final doc = await ref.get();
      return EmployeeModel.fromFirestore(doc).toEntity();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to create employee: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> update(EmployeeEntity employee) async {
    try {
      // Sparse patch, web parity: the editable registry fields plus a fresh
      // updatedAt. payslipDefaults is deliberately NOT part of this patch —
      // only saveDefaults writes it, so a registry edit can't clobber a
      // profile saved from the payroll form in the meantime.
      await _ref.doc(employee.id).update({
        'name': employee.name,
        'dailyRate': employee.dailyRate,
        'isActive': employee.isActive,
        'weekStartDay': employee.weekStartDay,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to update employee: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> saveDefaults(String id, PayslipDefaults defaults) async {
    try {
      await _ref.doc(id).update({
        'payslipDefaults': EmployeeModel.defaultsToMap(defaults),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to save defaults: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _ref.doc(id).delete();
    } on FirebaseException catch (e) {
      throw DatabaseException(
        message: 'Failed to delete employee: ${e.message}',
        code: e.code,
        originalError: e,
      );
    }
  }
}
