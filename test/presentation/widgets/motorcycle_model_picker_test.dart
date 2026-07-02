import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/motorcycle_model_picker.dart';
import 'package:maki_mobile_pos/presentation/providers/motorcycle_model_provider.dart';

MotorcycleModelEntity _m(String id, String name) => MotorcycleModelEntity(
      id: id,
      name: name,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  Widget host({
    String? selected,
    required void Function(String?) onChanged,
    List<MotorcycleModelEntity>? models,
  }) {
    return ProviderScope(
      overrides: [
        activeMotorcycleModelsProvider.overrideWith(
          (ref) => Stream.value(models ?? [_m('1', 'Nmax'), _m('2', 'Aerox')]),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MotorcycleModelPicker(
            selectedModel: selected,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  group('MotorcycleModelPicker', () {
    testWidgets('renders label + active model names + Add item',
        (tester) async {
      await tester.pumpWidget(host(onChanged: (_) {}));
      await tester.pumpAndSettle();
      expect(find.text('Motorcycle model'), findsOneWidget);

      await tester.tap(find.byType(MotorcycleModelPicker));
      await tester.pumpAndSettle();
      expect(find.text('Nmax'), findsWidgets);
      expect(find.text('Aerox'), findsWidgets);
      expect(find.text('➕ Add model…'), findsWidgets);
    });

    testWidgets('selecting a model reports its name', (tester) async {
      String? picked;
      await tester.pumpWidget(host(onChanged: (v) => picked = v));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MotorcycleModelPicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aerox').last);
      await tester.pumpAndSettle();
      expect(picked, 'Aerox');
    });

    testWidgets('selecting — None — reports null', (tester) async {
      String? picked = 'x';
      var called = false;
      await tester.pumpWidget(host(
        selected: 'Nmax',
        onChanged: (v) {
          picked = v;
          called = true;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MotorcycleModelPicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('— None —').last);
      await tester.pumpAndSettle();
      expect(called, true);
      expect(picked, isNull);
    });
  });
}
