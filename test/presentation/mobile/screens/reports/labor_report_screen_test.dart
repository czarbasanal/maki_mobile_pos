import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/labor_report.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/labor_report_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';

void main() {
  testWidgets('renders per-mechanic labor rows from the provider',
      (tester) async {
    final data = LaborReportData(
      totalLabor: 500,
      serviceSaleCount: 3,
      byMechanic: const [
        LaborByMechanic(
            mechanicId: 'm2', mechanicName: 'Pedro', laborTotal: 300, jobCount: 1),
        LaborByMechanic(
            mechanicId: 'm1', mechanicName: 'Juan', laborTotal: 200, jobCount: 2),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        laborReportProvider.overrideWith((ref, params) async => data),
      ],
      child: const MaterialApp(home: LaborReportScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Labor by Mechanic'), findsOneWidget);
    expect(find.text('Pedro'), findsOneWidget);
    expect(find.text('Juan'), findsOneWidget);
    expect(find.text('2 jobs'), findsOneWidget);
    expect(find.text('1 job'), findsOneWidget);
    expect(find.text('Service Sales'), findsOneWidget);
  });

  testWidgets('shows an empty state when there is no labor', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        laborReportProvider
            .overrideWith((ref, params) async => LaborReportData.empty()),
      ],
      child: const MaterialApp(home: LaborReportScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No labor recorded'), findsOneWidget);
  });
}
