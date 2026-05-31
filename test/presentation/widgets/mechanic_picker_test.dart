import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';

MechanicEntity _mech(String id, String name) =>
    MechanicEntity(id: id, name: name, isActive: true, createdAt: DateTime(2026, 1, 1));

void main() {
  Widget host({
    String? selectedId,
    required void Function(MechanicEntity?) onChanged,
    List<MechanicEntity>? mechanics,
  }) {
    return ProviderScope(
      overrides: [
        activeMechanicsProvider.overrideWith(
          (ref) => Stream.value(
            mechanics ?? [_mech('m1', 'Juan Dela Cruz'), _mech('m2', 'Pedro Santos')],
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MechanicPicker(selectedMechanicId: selectedId, onChanged: onChanged),
        ),
      ),
    );
  }

  group('MechanicPicker', () {
    testWidgets('renders the label and active mechanic names in the menu',
        (tester) async {
      await tester.pumpWidget(host(onChanged: (_) {}));
      await tester.pumpAndSettle();

      expect(find.text('Mechanic'), findsOneWidget); // decoration label

      await tester.tap(find.byType(MechanicPicker));
      await tester.pumpAndSettle();
      expect(find.text('Juan Dela Cruz'), findsWidgets);
      expect(find.text('Pedro Santos'), findsWidgets);
      expect(find.text('— None —'), findsWidgets);
    });

    testWidgets('selecting a mechanic reports it via onChanged', (tester) async {
      MechanicEntity? picked;
      var called = false;
      await tester.pumpWidget(host(onChanged: (m) {
        picked = m;
        called = true;
      }));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MechanicPicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Juan Dela Cruz').last);
      await tester.pumpAndSettle();

      expect(called, true);
      expect(picked, isNotNull);
      expect(picked!.id, 'm1');
      expect(picked!.name, 'Juan Dela Cruz');
    });

    testWidgets('selecting "— None —" reports null', (tester) async {
      MechanicEntity? picked = _mech('x', 'x');
      var called = false;
      await tester.pumpWidget(host(selectedId: 'm1', onChanged: (m) {
        picked = m;
        called = true;
      }));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MechanicPicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('— None —').last);
      await tester.pumpAndSettle();

      expect(called, true);
      expect(picked, isNull);
    });

    testWidgets('builds without crashing when no active mechanics exist',
        (tester) async {
      await tester.pumpWidget(host(onChanged: (_) {}, mechanics: const []));
      await tester.pumpAndSettle();
      expect(find.byType(MechanicPicker), findsOneWidget);
      expect(find.text('Mechanic'), findsOneWidget);
    });
  });
}
