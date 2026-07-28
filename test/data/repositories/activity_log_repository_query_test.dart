import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/data/repositories/activity_log_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  Future<FakeFirebaseFirestore> seeded() async {
    final db = FakeFirebaseFirestore();
    Future<void> add(String id, ActivityType type, DateTime at) =>
        db.collection('user_logs').doc(id).set({
          'type': type.value,
          'action': id,
          'userId': 'u1',
          'userName': 'Tester',
          'userRole': 'admin',
          'createdAt': Timestamp.fromDate(at),
        });

    await add('sale-early', ActivityType.sale, DateTime(2026, 7, 28, 8, 30));
    await add('void-mid', ActivityType.voidSale, DateTime(2026, 7, 28, 12, 0));
    await add('login-late', ActivityType.login, DateTime(2026, 7, 28, 20, 0));
    await add('sale-other-day', ActivityType.sale, DateTime(2026, 7, 27, 9, 0));
    return db;
  }

  test('no types selected returns everything in the window', () async {
    final repo = ActivityLogRepositoryImpl(firestore: await seeded());

    final logs = await repo.getActivityLogs(
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );

    expect(logs.map((l) => l.action),
        containsAll(<String>['sale-early', 'void-mid', 'login-late']));
    expect(logs.map((l) => l.action), isNot(contains('sale-other-day')));
  });

  test('selected types restrict the result', () async {
    final repo = ActivityLogRepositoryImpl(firestore: await seeded());

    final logs = await repo.getActivityLogs(
      types: const [ActivityType.sale, ActivityType.voidSale],
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );

    expect(logs.map((l) => l.action).toSet(), {'sale-early', 'void-mid'});
  });

  test('the time window excludes records outside it', () async {
    final repo = ActivityLogRepositoryImpl(firestore: await seeded());

    final logs = await repo.getActivityLogs(
      startDate: DateTime(2026, 7, 28, 9, 0),
      endDate: DateTime(2026, 7, 28, 17, 0, 59, 999),
    );

    expect(logs.map((l) => l.action).toSet(), {'void-mid'});
  });

  test('selecting every type behaves like no filter', () async {
    final repo = ActivityLogRepositoryImpl(firestore: await seeded());

    final logs = await repo.getActivityLogs(
      types: ActivityType.values,
      startDate: DateTime(2026, 7, 28),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );

    expect(logs.length, 3);
  });

  test('results come back newest first', () async {
    final repo = ActivityLogRepositoryImpl(firestore: await seeded());

    final logs = await repo.getActivityLogs(
      startDate: DateTime(2026, 7, 27),
      endDate: DateTime(2026, 7, 28, 23, 59, 59, 999),
    );

    expect(logs.first.action, 'login-late');
    expect(logs.last.action, 'sale-other-day');
  });
}
