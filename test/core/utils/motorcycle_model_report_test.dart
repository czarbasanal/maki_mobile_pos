import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_report.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

SaleEntity _sale({
  String? model,
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
      motorcycleModel: model,
      paymentMethod: PaymentMethod.cash,
      amountReceived: parts + labor,
      changeGiven: 0,
      status: voided ? SaleStatus.voided : SaleStatus.completed,
      cashierId: 'c',
      cashierName: 'C',
      createdAt: DateTime(2026, 7, 1),
    );

void main() {
  test('groups by model, excludes voided + model-less, sorts by jobCount desc',
      () {
    final sales = [
      _sale(model: 'Nmax', parts: 60, labor: 40), // grandTotal 100
      _sale(model: 'Nmax', parts: 60), // grandTotal 60
      _sale(model: 'Click', parts: 100, labor: 100), // grandTotal 200
      _sale(model: null, parts: 999), // walk-in → excluded
      _sale(model: 'Click', parts: 10, voided: true), // voided → excluded
    ];
    final r = motorcycleModelReportFromSales(sales);

    expect(r.byModel.map((m) => m.model).toList(), ['Nmax', 'Click']);
    expect(r.byModel.first.jobCount, 2);
    expect(r.byModel.first.totalRevenue, 160);
    expect(r.byModel.first.laborTotal, 40);
    expect(r.totalJobs, 3);
    expect(r.totalRevenue, 360);
  });

  test('excludes model-less sales entirely', () {
    final r = motorcycleModelReportFromSales([_sale(model: null, parts: 100)]);
    expect(r.byModel, isEmpty);
    expect(r.totalJobs, 0);
  });
}
