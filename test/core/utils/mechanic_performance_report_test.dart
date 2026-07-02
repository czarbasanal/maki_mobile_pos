import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/utils/mechanic_performance_report.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

SaleEntity _sale({
  String? mechId,
  String? mechName,
  double parts = 0,
  double labor = 0,
  bool voided = false,
}) =>
    SaleEntity(
      id: 'x',
      saleNumber: 's',
      items: parts > 0
          ? [
              SaleItemEntity(
                id: 'i',
                productId: 'p',
                sku: 's',
                name: 'n',
                unitPrice: parts,
                unitCost: 0,
                quantity: 1,
              ),
            ]
          : const [],
      laborLines:
          labor > 0 ? [LaborLineEntity(id: 'l', description: 'd', fee: labor)] : const [],
      mechanicId: mechId,
      mechanicName: mechName,
      paymentMethod: PaymentMethod.cash,
      amountReceived: parts + labor,
      changeGiven: 0,
      status: voided ? SaleStatus.voided : SaleStatus.completed,
      cashierId: 'c',
      cashierName: 'C',
      createdAt: DateTime(2026, 7, 1),
    );

void main() {
  test(
      'groups by mechanic, ranks by total revenue desc, excludes no-mechanic + voided',
      () {
    final sales = [
      _sale(mechId: 'm1', mechName: 'Jun', parts: 60, labor: 40), // 100
      _sale(mechId: 'm1', mechName: 'Jun', parts: 50), // 50
      _sale(mechId: 'm2', mechName: 'Ray', parts: 300), // 300
      _sale(parts: 999), // no mechanic → excluded
      _sale(mechId: 'm2', mechName: 'Ray', parts: 10, voided: true), // excluded
    ];
    final r = mechanicPerformanceReportFromSales(sales);

    expect(r.byMechanic.map((m) => m.mechanicName).toList(), ['Ray', 'Jun']);
    expect(r.byMechanic.last.jobCount, 2);
    expect(r.byMechanic.last.totalRevenue, 150);
    expect(r.byMechanic.last.laborTotal, 40);
    expect(r.jobCount, 3);
    expect(r.totalRevenue, 450);
  });
}
