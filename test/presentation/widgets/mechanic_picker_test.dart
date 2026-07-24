import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/mechanic_picker.dart';

MechanicEntity _mech(String id, String name) =>
    MechanicEntity(id: id, name: name, isActive: true, createdAt: DateTime(2026, 1, 1));

class _FakeMechanicOps extends MechanicOperationsNotifier {
  _FakeMechanicOps(super.ref);

  MechanicEntity? createdWith;

  @override
  Future<MechanicEntity?> create({required MechanicEntity mechanic}) async {
    createdWith = mechanic;
    return MechanicEntity(
      id: 'new-1',
      name: mechanic.name,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );
  }
}

void main() {
  Widget host({
    String? selectedId,
    required void Function(MechanicEntity?) onChanged,
    List<MechanicEntity>? mechanics,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        activeMechanicsProvider.overrideWith(
          (ref) => Stream.value(
            mechanics ?? [_mech('m1', 'Juan Dela Cruz'), _mech('m2', 'Pedro Santos')],
          ),
        ),
        ...extraOverrides,
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

  group('MechanicPicker — inline add', () {
    testWidgets('menu offers Add mechanic…', (tester) async {
      await tester.pumpWidget(host(onChanged: (_) {}));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MechanicPicker));
      await tester.pumpAndSettle();
      expect(find.text('➕ Add mechanic…'), findsWidgets);
    });

    testWidgets('existing name (case-insensitive) is reused, not recreated',
        (tester) async {
      _FakeMechanicOps? fake;
      MechanicEntity? picked;
      await tester.pumpWidget(host(
        onChanged: (m) => picked = m,
        extraOverrides: [
          mechanicOperationsProvider.overrideWith((ref) {
            fake = _FakeMechanicOps(ref);
            return fake!;
          }),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MechanicPicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('➕ Add mechanic…').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'juan dela cruz');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(picked?.id, 'm1'); // existing Juan Dela Cruz reused
      expect(fake?.createdWith, isNull); // no create call
    });

    testWidgets('new name is created and selected', (tester) async {
      _FakeMechanicOps? fake;
      MechanicEntity? picked;
      await tester.pumpWidget(host(
        onChanged: (m) => picked = m,
        extraOverrides: [
          mechanicOperationsProvider.overrideWith((ref) {
            fake = _FakeMechanicOps(ref);
            return fake!;
          }),
        ],
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MechanicPicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('➕ Add mechanic…').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Mang Kanor');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(fake?.createdWith?.name, 'Mang Kanor');
      expect(picked?.id, 'new-1');
    });

    testWidgets('cancelling the add dialog fires no onChanged and resets '
        'the dropdown off the sentinel', (tester) async {
      var changedCalls = 0;
      await tester.pumpWidget(host(onChanged: (_) => changedCalls++));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MechanicPicker));
      await tester.pumpAndSettle();
      await tester.tap(find.text('➕ Add mechanic…').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(changedCalls, 0);
      // Dropdown display is back on the placeholder, not stuck on the sentinel.
      expect(find.text('— None —'), findsOneWidget);
      expect(find.text('➕ Add mechanic…'), findsNothing);
    });
  });
}
