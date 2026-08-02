import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/utils/labor_report.dart';
import 'package:maki_mobile_pos/core/utils/mechanic_performance_report.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_report.dart';
import 'package:maki_mobile_pos/core/utils/price_change_report.dart';
import 'package:maki_mobile_pos/core/utils/report_csv.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/repositories.dart';

SaleEntity _sale({
  required String number,
  required double unitPrice,
  required int qty,
  bool voided = false,
  List<FeeLineEntity> feeLines = const [],
  List<LaborLineEntity> laborLines = const [],
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
      laborLines: laborLines,
      feeLines: feeLines,
      discountType: DiscountType.amount,
      paymentMethod: PaymentMethod.cash,
      amountReceived: unitPrice * qty +
          feeLines.fold<double>(0, (s, f) => s + f.amount) +
          laborLines.fold<double>(0, (s, l) => s + l.fee),
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
          'Sale #,Date,Cashier,Subtotal,Discount,Labor,Fees,Total,Payment');
      expect(lines.length, 3); // header + 1 completed + totals
      expect(lines[1], contains('S-1'));
      expect(lines.last, startsWith('TOTAL,'));
      expect(lines.last, contains('200.00'));
    });

    test('breaks out shop fees beside the parts subtotal, without touching '
        'it or the grand total', () {
      final csv = buildSalesReportCsv([
        _sale(
          number: 'S-1',
          unitPrice: 100,
          qty: 2,
          feeLines: const [FeeLineEntity(id: 'f1', name: 'Electric', amount: 50)],
        ),
      ]);
      final lines = csv.trim().split('\n');
      // Subtotal,Discount,Labor,Fees,Total,Payment
      expect(lines[1], contains(',200.00,0.00,0.00,50.00,250.00,Cash'));
      // TOTAL row also carries the fees column.
      expect(lines.last, 'TOTAL,,,200.00,0.00,0.00,50.00,250.00,');
    });

    test('breaks out labor beside fees so Subtotal − Discount + Labor + '
        'Fees reconciles with Total', () {
      final csv = buildSalesReportCsv([
        _sale(
          number: 'S-1',
          unitPrice: 100,
          qty: 2,
          laborLines: const [
            LaborLineEntity(id: 'l1', description: 'Tune-up', fee: 40),
          ],
          feeLines: const [FeeLineEntity(id: 'f1', name: 'Electric', amount: 50)],
        ),
      ]);
      final lines = csv.trim().split('\n');
      // Subtotal,Discount,Labor,Fees,Total,Payment
      expect(lines[1], contains(',200.00,0.00,40.00,50.00,290.00,Cash'));
      expect(lines.last, 'TOTAL,,,200.00,0.00,40.00,50.00,290.00,');
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

    test('formats 8-digit SKU codes as XXXX-XXXX and passes others through', () {
      final csv = buildProfitReportCsv(const [
        ProductSalesData(
            productId: 'p1',
            sku: '00070153',
            name: 'Auto SKU Product',
            quantitySold: 1,
            totalRevenue: 100,
            totalCost: 90),
        ProductSalesData(
            productId: 'p2',
            sku: 'MLK-A3B7',
            name: 'Manual SKU Product',
            quantitySold: 2,
            totalRevenue: 300,
            totalCost: 100),
      ]);
      final lines = csv.trim().split('\n');
      // Sorted by profit desc: Manual (200 profit) first, Auto (10 profit) second
      expect(lines[1], contains('MLK-A3B7')); // Manual SKU passed through
      expect(lines[2], contains('0007-0153')); // 8-digit formatted
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

  group('buildPriceChangeReportCsv', () {
    test('header + one row per change with signed deltas + product label', () {
      final rows = priceChangeRowsInRange([
        PriceChangeEntry(
            id: 'a',
            productId: 'p1',
            price: 120,
            cost: 70,
            changedAt: DateTime(2026, 6, 10, 9),
            changedBy: 'u1',
            reason: 'receiving'),
        PriceChangeEntry(
            id: 'b',
            productId: 'p1',
            price: 100,
            cost: 60,
            changedAt: DateTime(2026, 6, 1, 9),
            changedBy: 'u1'),
      ]);
      final csv = buildPriceChangeReportCsv(rows, {'p1': 'Widget (SKU-1)'});
      final lines = csv.trim().split('\n');
      // Deliberately re-pinned: Option was inserted at index 3, adjacent to
      // SKU, shifting every column after it by one.
      expect(lines.first,
          'Date,Product,SKU,Option,New Price,Price Delta,New Cost,Cost Delta,Reason,Changed By');
      expect(lines.length, 3); // header + 2 changes
      expect(lines[1], contains('Widget (SKU-1)'));
      expect(lines[1], contains('+20.00')); // newest row's price delta
    });

    test('extracts and formats SKU from product label in CSV', () {
      final rows = priceChangeRowsInRange([
        PriceChangeEntry(
            id: 'a',
            productId: 'p1',
            price: 120,
            cost: 70,
            changedAt: DateTime(2026, 6, 10, 9),
            changedBy: 'u1'),
        PriceChangeEntry(
            id: 'b',
            productId: 'p2',
            price: 100,
            cost: 60,
            changedAt: DateTime(2026, 6, 1, 9),
            changedBy: 'u1'),
      ]);
      final csv = buildPriceChangeReportCsv(rows,
          {'p1': 'Brake Shoe (00070153)', 'p2': 'Coupling (MLK-A3B7)'});
      final lines = csv.trim().split('\n');
      // SKU column should contain formatted 8-digit codes and pass-through SKUs
      expect(lines[1], contains('0007-0153')); // 8-digit formatted
      expect(lines[2], contains('MLK-A3B7')); // Manual SKU passed through
    });

    test('Option column: the label for an option row, an empty cell (not '
        '"Base" or a dash) for a base row of the same product', () {
      final rows = priceChangeRowsInRange([
        PriceChangeEntry(
            id: 'a',
            productId: 'p1',
            price: 330,
            cost: 150,
            changedAt: DateTime(2026, 6, 10, 9),
            changedBy: 'u1',
            reason: 'Price update',
            optionId: 'o2',
            optionLabel: 'By 3',
            optionPieces: 3),
        PriceChangeEntry(
            id: 'b',
            productId: 'p1',
            price: 120,
            cost: 70,
            changedAt: DateTime(2026, 6, 1, 9),
            changedBy: 'u1'),
      ]);
      final csv = buildPriceChangeReportCsv(rows, {'p1': 'Pulley Ball (ABC-1)'});
      final lines = csv.trim().split('\n');
      // Newest-first: the By-3 row (Jun 10), then the base row (Jun 1).
      final optionCells = lines[1].split(',');
      final baseCells = lines[2].split(',');
      expect(optionCells[3], 'By 3');
      expect(baseCells[3], '');
      // SKU (index 2) stays put either way.
      expect(optionCells[2], 'ABC-1');
      expect(baseCells[2], 'ABC-1');
    });
  });

  group('job-order report CSVs', () {
    test('buildMotorcycleModelReportCsv: header + row + TOTAL', () {
      final csv = buildMotorcycleModelReportCsv(const MotorcycleModelReportData(
        totalJobs: 1,
        totalRevenue: 100,
        byModel: [
          MotorcycleModelStat(
              model: 'Nmax', jobCount: 1, totalRevenue: 100, laborTotal: 40),
        ],
      ));
      final lines = csv.trim().split('\n');
      expect(lines.first, 'Model,Jobs,Revenue,Labor');
      expect(lines[1], 'Nmax,1,100.00,40.00');
      expect(lines.last, contains('TOTAL'));
    });

    test('buildMechanicPerformanceReportCsv: header + row + TOTAL', () {
      final csv = buildMechanicPerformanceReportCsv(
          const MechanicPerformanceReportData(
        totalRevenue: 150,
        jobCount: 2,
        byMechanic: [
          MechanicPerformanceStat(
              mechanicId: 'm1',
              mechanicName: 'Jun',
              jobCount: 2,
              totalRevenue: 150,
              laborTotal: 40),
        ],
      ));
      final lines = csv.trim().split('\n');
      expect(lines.first, 'Mechanic,Jobs,Total Revenue,Labor');
      expect(lines[1], 'Jun,2,150.00,40.00');
      expect(lines.last, contains('TOTAL'));
    });
  });
}
