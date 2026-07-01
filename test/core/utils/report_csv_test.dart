import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/utils/labor_report.dart';
import 'package:maki_mobile_pos/core/utils/report_csv.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

SaleEntity _sale({
  required String number,
  required double unitPrice,
  required int qty,
  bool voided = false,
}) =>
    SaleEntity(
      id: number,
      saleNumber: number,
      items: [
        SaleItemEntity(
          id: 'i-$number',
          productId: 'p1',
          sku: 'SKU-1',
          name: 'Widget',
          unitPrice: unitPrice,
          unitCost: 5,
          quantity: qty,
        ),
      ],
      discountType: DiscountType.amount,
      paymentMethod: PaymentMethod.cash,
      amountReceived: unitPrice * qty,
      changeGiven: 0,
      cashierId: 'c1',
      cashierName: 'Cashier',
      status: voided ? SaleStatus.voided : SaleStatus.completed,
      createdAt: DateTime(2026, 7, 1, 9, 30),
    );

void main() {
  group('buildSalesReportCsv', () {
    test('header + one row per non-voided sale + totals row', () {
      final csv = buildSalesReportCsv([
        _sale(number: 'S-1', unitPrice: 100, qty: 2),
        _sale(number: 'S-2', unitPrice: 50, qty: 1, voided: true),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.first,
          'Sale #,Date,Cashier,Subtotal,Discount,Total,Payment');
      expect(lines.length, 3); // header + 1 completed + totals
      expect(lines[1], contains('S-1'));
      expect(lines.last, startsWith('TOTAL,'));
      expect(lines.last, contains('200.00'));
    });
  });

  group('buildProfitReportCsv', () {
    test('ranks by profit desc, header + rows + totals', () {
      final csv = buildProfitReportCsv(const [
        ProductSalesData(
            productId: 'p1',
            sku: 'A',
            name: 'Low',
            quantitySold: 1,
            totalRevenue: 100,
            totalCost: 90),
        ProductSalesData(
            productId: 'p2',
            sku: 'B',
            name: 'High',
            quantitySold: 2,
            totalRevenue: 300,
            totalCost: 100),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.first, 'Product,SKU,Qty Sold,Revenue,Cost,Profit,Margin %');
      expect(lines[1], startsWith('High,')); // 200 profit ranks first
      expect(lines[2], startsWith('Low,'));
      expect(lines.last, startsWith('TOTAL,'));
    });
  });

  group('buildLaborReportCsv', () {
    test('header + row per mechanic + totals', () {
      const report = LaborReportData(
        totalLabor: 500,
        serviceSaleCount: 3,
        byMechanic: [
          LaborByMechanic(
              mechanicId: 'm1',
              mechanicName: 'Juan',
              laborTotal: 200,
              jobCount: 2),
          LaborByMechanic(
              mechanicId: 'm2',
              mechanicName: 'Pedro',
              laborTotal: 300,
              jobCount: 1),
        ],
      );
      final csv = buildLaborReportCsv(report);
      final lines = csv.trim().split('\n');
      expect(lines.first, 'Mechanic,Jobs,Labor Total');
      expect(lines.length, 4); // header + 2 + totals
      expect(lines.last, 'TOTAL,3,500.00');
    });
  });
}
