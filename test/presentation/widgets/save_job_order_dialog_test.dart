import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/drafts/save_job_order_dialog.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/motorcycle_model_provider.dart';

void main() {
  final mechanic = MechanicEntity(
    id: 'mech-1',
    name: 'Rey',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );
  final nmax = MotorcycleModelEntity(
    id: 'model-1',
    name: 'Nmax',
    isActive: true,
    createdAt: DateTime(2026, 1, 1),
  );

  Future<SaveJobOrderInput? Function()> harness(
    WidgetTester tester, {
    String? initialModel,
    String? initialMechanicId,
  }) async {
    SaveJobOrderInput? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeMotorcycleModelsProvider
              .overrideWith((ref) => Stream.value([nmax])),
          activeMechanicsProvider
              .overrideWith((ref) => Stream.value([mechanic])),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async => result = await showSaveJobOrderDialog(
                    ctx,
                    initialModel: initialModel,
                    initialMechanicId: initialMechanicId,
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

  testWidgets('offers mechanic (optional) and prefills the cart model',
      (tester) async {
    final getResult = await harness(tester, initialModel: 'Nmax');
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Model prefilled from the cart; mechanic offered as optional.
    expect(find.text('Nmax'), findsOneWidget);
    expect(find.text('— Optional —'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Juan / ABC-123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final result = getResult();
    expect(result, isNotNull);
    expect(result!.label, 'Juan / ABC-123');
    expect(result.model, 'Nmax');
    expect(result.mechanicId, isNull);
  });

  testWidgets('prefills the cart mechanic when one is already set',
      (tester) async {
    await harness(tester, initialMechanicId: 'mech-1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Rey'), findsOneWidget);
  });

  testWidgets('requires a label', (tester) async {
    final getResult = await harness(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Save as Job Order'), findsOneWidget); // still open
    expect(getResult(), isNull);
  });
}
