import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/utils/labor_report.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

SaleEntity _sale({
  required String id,
  required List<LaborLineEntity> labor,
  String? mechanicId,
  String? mechanicName,
  bool voided = false,
}) {
  return SaleEntity(
    id: id,
    saleNumber: id,
    items: const [],
    laborLines: labor,
    mechanicId: mechanicId,
    mechanicName: mechanicName,
    discountType: DiscountType.amount,
    paymentMethod: PaymentMethod.cash,
    amountReceived: 0,
    changeGiven: 0,
    cashierId: 'c1',
    cashierName: 'Cashier',
    status: voided ? SaleStatus.voided : SaleStatus.completed,
    createdAt: DateTime(2026, 6, 1),
  );
}

LaborLineEntity _l(String id, double fee) =>
    LaborLineEntity(id: id, description: 'Job $id', fee: fee);

void main() {
  group('laborReportFromSales', () {
    test('totals labor, counts service sales, and groups by mechanic', () {
      final sales = [
        _sale(id: 's1', mechanicId: 'm1', mechanicName: 'Juan', labor: [_l('a', 150)]),
        _sale(id: 's2', mechanicId: 'm1', mechanicName: 'Juan', labor: [_l('b', 50)]),
        _sale(id: 's3', mechanicId: 'm2', mechanicName: 'Pedro', labor: [_l('c', 300)]),
      ];

      final report = laborReportFromSales(sales);

      expect(report.totalLabor, 500);
      expect(report.serviceSaleCount, 3);
      // Sorted by labor total desc: Pedro (300) then Juan (200).
      expect(report.byMechanic.map((m) => m.mechanicName), ['Pedro', 'Juan']);
      final juan = report.byMechanic.firstWhere((m) => m.mechanicId == 'm1');
      expect(juan.laborTotal, 200);
      expect(juan.jobCount, 2);
      final pedro = report.byMechanic.firstWhere((m) => m.mechanicId == 'm2');
      expect(pedro.laborTotal, 300);
      expect(pedro.jobCount, 1);
    });

    test('excludes voided sales', () {
      final sales = [
        _sale(id: 's1', mechanicId: 'm1', mechanicName: 'Juan', labor: [_l('a', 150)]),
        _sale(
            id: 's2',
            mechanicId: 'm1',
            mechanicName: 'Juan',
            labor: [_l('b', 999)],
            voided: true),
      ];

      final report = laborReportFromSales(sales);

      expect(report.totalLabor, 150);
      expect(report.serviceSaleCount, 1);
      expect(report.byMechanic.single.laborTotal, 150);
      expect(report.byMechanic.single.jobCount, 1);
    });

    test('ignores sales with no labor (parts-only)', () {
      final sales = [
        _sale(id: 's1', mechanicId: 'm1', mechanicName: 'Juan', labor: [_l('a', 150)]),
        _sale(id: 's2', labor: const []), // parts-only, no labor
      ];

      final report = laborReportFromSales(sales);

      expect(report.totalLabor, 150);
      expect(report.serviceSaleCount, 1);
      expect(report.byMechanic, hasLength(1));
    });

    test('labor without a mechanic collapses into an Unassigned bucket', () {
      final sales = [
        _sale(id: 's1', labor: [_l('a', 100)]), // no mechanic
        _sale(id: 's2', mechanicId: 'm1', mechanicName: 'Juan', labor: [_l('b', 40)]),
      ];

      final report = laborReportFromSales(sales);

      expect(report.totalLabor, 140);
      final unassigned =
          report.byMechanic.firstWhere((m) => m.mechanicId == null);
      expect(unassigned.mechanicName, 'Unassigned');
      expect(unassigned.laborTotal, 100);
      expect(unassigned.jobCount, 1);
    });

    test('empty input yields an empty report', () {
      final report = laborReportFromSales(const []);
      expect(report.totalLabor, 0);
      expect(report.serviceSaleCount, 0);
      expect(report.byMechanic, isEmpty);
    });
  });
}
