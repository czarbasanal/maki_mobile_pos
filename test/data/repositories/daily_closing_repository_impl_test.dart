import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/business_day.dart';
import 'package:maki_mobile_pos/data/repositories/daily_closing_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/daily_closing_entity.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late DailyClosingRepositoryImpl repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = DailyClosingRepositoryImpl(firestore: fakeFirestore);
  });

  // A PAST business date relative to "today" — pins the closing-writes-a-day
  // that-is-<=-today case (as opposed to always writing today's int).
  DailyClosingEntity pastClosing() => DailyClosingEntity(
        id: DailyClosingRepositoryImpl.docIdFor(DateTime(2026, 5, 28)),
        businessDate: DateTime(2026, 5, 28),
        grossSales: 1000,
        netSales: 1000,
        totalDiscounts: 0,
        cashSales: 700,
        nonCashSales: 300,
        gcashSales: 300,
        mayaSales: 0,
        totalExpenses: 100,
        cashExpenses: 100,
        salmonReceivable: 0,
        openingFloat: 2000,
        expectedCash: 2600,
        countedCash: 2600,
        variance: 0,
        salesCount: 3,
        voidedCount: 0,
        closedBy: 'u-cashier',
        closedByName: 'Cashier User',
        closedAt: DateTime(2026, 5, 28, 20),
      );

  group('DailyClosingRepositoryImpl.saveClosing drawer_state stamping', () {
    test('stamps drawer_state/state.lastClosedDay with the closed day\'s int',
        () async {
      final closing = pastClosing();

      await repository.saveClosing(closing);

      final doc =
          await fakeFirestore.collection('drawer_state').doc('state').get();
      expect(doc.exists, isTrue);
      expect(
        doc.data()!['lastClosedDay'],
        businessDayInt(closing.businessDate),
      );
      expect(doc.data()!['lastClosedDay'], 20260528);
    });

    test('merges lastClosedDay without clobbering lastSaleDay', () async {
      await fakeFirestore.collection('drawer_state').doc('state').set({
        'lastSaleDay': 20260724,
      });

      final closing = pastClosing();
      await repository.saveClosing(closing);

      final doc =
          await fakeFirestore.collection('drawer_state').doc('state').get();
      expect(doc.data()!['lastSaleDay'], 20260724);
      expect(doc.data()!['lastClosedDay'], 20260528);
    });
  });
}
