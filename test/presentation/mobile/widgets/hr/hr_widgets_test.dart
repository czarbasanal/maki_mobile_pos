// WeekGrid + PayslipReceipt. The receipt's load-bearing assertion: it shows
// the STORED computed figures — the seeded doc's computed disagrees with what
// recomputation would give, and the stored numbers must win (frozen snapshot,
// rules update:false). Rendering also proves the yellow-logo asset is
// registered in pubspec (Image.asset throws in tests otherwise).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/hr/payslip_receipt.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/hr/week_grid.dart';

PayslipEntity payslip() => PayslipEntity(
      id: 'p1',
      employeeId: 'e1',
      employeeName: 'Maybelle Tampos',
      periodStart: '2026-07-20',
      periodEnd: '2026-07-26',
      days: [
        for (var d = 20; d <= 25; d++)
          PayslipDay(date: '2026-07-$d', status: DayStatus.present),
        const PayslipDay(date: '2026-07-26', status: DayStatus.dayOff),
      ],
      inputs: const PayslipInputs(
        hoursWorked: 48,
        dailyRate: 640,
        overtimeHours: 0,
        overtimeRatePerHour: 0,
        regularHolidayDays: 0,
        specialHolidayDays: 0,
        regularHolidayPct: 100,
        specialHolidayPct: 30,
        incentives: 200,
        deductions: PayslipDeductions(
          sss: 45,
          philhealth: 0,
          pagibig: 0,
          late: 0,
          absences: 0,
          cashAdvance: 500,
          others: [OtherDeduction(label: 'Load', amount: 100)],
        ),
      ),
      // Deliberately NOT what computePayslip(inputs) would produce — the
      // receipt must render these stored values, not recompute.
      computed: const PayslipComputed(
        hourlyRate: 80,
        basePay: 9999,
        overtimePay: 0,
        holidayPay: 0,
        gross: 8888,
        totalDeductions: 645,
        net: 7777,
      ),
      createdAt: DateTime(2026, 7, 22),
    );

Widget host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: Center(child: child)),
      ),
    );

void main() {
  group('PayslipReceipt', () {
    testWidgets('renders the design sections from a canned payslip',
        (tester) async {
      await tester.pumpWidget(host(PayslipReceipt(payslip: payslip())));

      expect(find.textContaining('MAKI MOTORCYCLE PARTS'), findsOneWidget);
      expect(find.text('Buanoy, Balamban, Cebu'), findsOneWidget);
      expect(find.text('Maybelle Tampos'), findsOneWidget);
      expect(find.text('Jul 20 – Jul 26, 2026'), findsOneWidget);
      expect(find.text('✓'), findsNWidgets(6));
      expect(find.text('—'), findsOneWidget);
      expect(find.text('SSS'), findsOneWidget);
      expect(find.text('Load'), findsOneWidget);
      expect(find.text('NET PAY'), findsOneWidget);
      expect(
        find.text('This is a System-Generated payslip. No signature required.'),
        findsOneWidget,
      );
      // Zero-value standard deductions are omitted; the 'others' row is not.
      expect(find.text('PhilHealth'), findsNothing);
    });

    testWidgets('shows the STORED computed figures, never recomputing',
        (tester) async {
      await tester.pumpWidget(host(PayslipReceipt(payslip: payslip())));

      expect(find.text('₱7,777.00'), findsOneWidget); // stored net
      expect(find.text('₱8,888.00'), findsOneWidget); // stored gross
      expect(find.text('– ₱645.00'), findsOneWidget); // stored deductions
      // What recomputation would have produced must be absent.
      expect(find.text('₱3,840.00'), findsNothing);
    });

    testWidgets('an absent day renders ✗ in red, distinct from a day off',
        (tester) async {
      final p = payslip();
      final withAbsence = PayslipEntity(
        id: p.id,
        employeeId: p.employeeId,
        employeeName: p.employeeName,
        periodStart: p.periodStart,
        periodEnd: p.periodEnd,
        days: [
          const PayslipDay(date: '2026-07-20', status: DayStatus.absent),
          ...p.days.skip(1),
        ],
        inputs: p.inputs,
        computed: p.computed,
        createdAt: p.createdAt,
      );
      await tester.pumpWidget(host(PayslipReceipt(payslip: withAbsence)));

      expect(find.text('✗'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });
  });

  group('WeekGrid', () {
    testWidgets('renders 7 tappable cells and reports the tapped index',
        (tester) async {
      int? tapped;
      final days = payslip().days;
      await tester.pumpWidget(host(WeekGrid(
        days: days,
        onTapDay: (i) => tapped = i,
      )));

      expect(find.text('Mon 7/20'), findsOneWidget);
      expect(find.text('Sun 7/26'), findsOneWidget);
      expect(find.text('Present'), findsNWidgets(6));
      expect(find.text('Day off'), findsOneWidget);

      await tester.tap(find.text('Wed 7/22'));
      expect(tapped, 2);
    });
  });
}
