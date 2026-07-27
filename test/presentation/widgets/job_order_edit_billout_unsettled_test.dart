import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/job_orders/job_order_edit_screen.dart';

/// Bill-out has its own readiness gate (motorcycle model set — see
/// job_order_bill_out_test.dart). This file covers the ADDITIONAL rollover
/// gate: Bill-out is blocked while an earlier business day sits unsettled,
/// and unblocked once it's null again — mirroring the POS checkout gate in
/// pos_unsettled_gate_test.dart.
void main() {
  JobOrderEntity buildJobOrder() => JobOrderEntity(
        id: 'jobOrder-1',
        name: 'Plate ABC-123',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 1,
          ),
        ],
        motorcycleModel: 'Yamaha Nmax',
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

  Widget harness({required DateTime? unsettled}) => ProviderScope(
        overrides: [
          jobOrderByIdProvider('jobOrder-1')
              .overrideWith((ref) async => buildJobOrder()),
          activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
          unsettledBusinessDayProvider.overrideWith((ref) async => unsettled),
        ],
        child: const MaterialApp(
            home: JobOrderEditScreen(jobOrderId: 'jobOrder-1')),
      );

  Future<void> pump(WidgetTester tester, {required DateTime? unsettled}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(unsettled: unsettled));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  // FilledButton.icon builds a private FilledButton subtype, so find.byType
  // (exact runtimeType match) can't see it — match by `is` via a predicate.
  Finder billOutButton() => find.ancestor(
        of: find.text('Bill out'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      );

  testWidgets('Bill out is disabled while an earlier day is unsettled',
      (tester) async {
    await pump(tester, unsettled: DateTime(2026, 7, 20));

    final button = tester.widget<FilledButton>(billOutButton());
    expect(button.onPressed, isNull);
  });

  testWidgets('Bill out is enabled once nothing is unsettled', (tester) async {
    await pump(tester, unsettled: null);

    final button = tester.widget<FilledButton>(billOutButton());
    expect(button.onPressed, isNotNull);
  });
}
