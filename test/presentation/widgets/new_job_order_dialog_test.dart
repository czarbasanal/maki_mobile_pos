import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/new_job_order_dialog.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/motorcycle_model_provider.dart';

void main() {
  testWidgets('requires a label and returns the entered input', (tester) async {
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
                  onPressed: () async => result = await showNewJobOrderDialog(ctx),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Empty label → blocked (dialog stays open, no result yet).
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('New Job Order'), findsOneWidget);
    expect(result, isNull);

    // Enter a label → Create returns the input.
    await tester.enterText(find.byType(TextField).first, 'ABC-123');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.label, 'ABC-123');
  });
}
