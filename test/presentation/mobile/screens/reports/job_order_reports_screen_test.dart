import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/utils/mechanic_performance_report.dart';
import 'package:maki_mobile_pos/core/utils/motorcycle_model_report.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/reports/job_order_reports_screen.dart';

void main() {
  testWidgets('renders the Models/Mechanics toggle and a model row',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          motorcycleModelReportProvider.overrideWith(
            (ref, params) async => const MotorcycleModelReportData(
              totalJobs: 1,
              totalRevenue: 100,
              byModel: [
                MotorcycleModelStat(
                    model: 'Nmax',
                    jobCount: 1,
                    totalRevenue: 100,
                    laborTotal: 40),
              ],
            ),
          ),
          mechanicPerformanceReportProvider.overrideWith(
            (ref, params) async => MechanicPerformanceReportData.empty(),
          ),
        ],
        child: const MaterialApp(home: JobOrderReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Models'), findsWidgets); // segment label
    expect(find.text('Mechanics'), findsWidgets); // segment label
    expect(find.text('Nmax'), findsOneWidget); // a model row

    // Elevated redesign: segments carry icons, and each row leads with a
    // glyph tile (bike segment + bike row glyph → at least two).
    expect(find.byIcon(LucideIcons.bike), findsNWidgets(2));
    expect(find.byIcon(LucideIcons.wrench), findsOneWidget); // segment icon
  });
}
