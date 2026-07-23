import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/new_job_order_dialog.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/motorcycle_model_provider.dart';

void main() {
  Future<NewJobOrderInput? Function()> harness(WidgetTester tester) async {
    NewJobOrderInput? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeMotorcycleModelsProvider
              .overrideWith((ref) => Stream.value(const [])),
          activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => result = await showNewJobOrderDialog(
                    ctx,
                    jobOrderNo: 'JO-072326-005',
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return () => result;
  }

  testWidgets('shows the number read-only with no label field', (tester) async {
    await harness(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The auto-generated number is displayed read-only — no text input.
    expect(find.text('JO-072326-005'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    // Mechanic stays optional at create.
    expect(find.text('— Optional —'), findsOneWidget);
  });

  testWidgets('creates immediately under the generated number (no label gate)',
      (tester) async {
    final getResult = await harness(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final result = getResult();
    expect(result, isNotNull);
    expect(result!.label, 'JO-072326-005');
    expect(result.model, isNull);
    expect(result.mechanicId, isNull);
  });
}
