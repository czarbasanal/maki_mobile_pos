import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/adjustment_reason_editor_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/adjustment_reason_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';

class _FakeAdjustmentReasonOps extends AdjustmentReasonOperationsNotifier {
  _FakeAdjustmentReasonOps(super.ref);
  final created = <AdjustmentReasonEntity>[];
  bool seedCalled = false;

  @override
  Future<AdjustmentReasonEntity?> create({
    required AdjustmentReasonEntity reason,
  }) async {
    created.add(reason);
    return reason.copyWith(id: 'new-1');
  }

  @override
  Future<bool> seedDefaults() async {
    seedCalled = true;
    return true;
  }
}

UserEntity _user(UserRole role) => UserEntity(
      id: 'u-1',
      email: 'u@x.com',
      displayName: 'U',
      role: role,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

AdjustmentReasonEntity _reason(
  String id,
  String name, {
  bool requiresNote = false,
  bool isActive = true,
}) =>
    AdjustmentReasonEntity(
      id: id,
      name: name,
      requiresNote: requiresNote,
      isActive: isActive,
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  Widget harness(UserRole role, {List<Override> extraOverrides = const []}) =>
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(_user(role))),
          allAdjustmentReasonsProvider.overrideWith((ref) => Stream.value([
                _reason('r1', 'Damaged', requiresNote: true),
                _reason('r2', 'Recount', requiresNote: false),
              ])),
          ...extraOverrides,
        ],
        child: const MaterialApp(home: AdjustmentReasonEditorScreen()),
      );

  testWidgets('rows show Note required subtitle for flagged reasons only',
      (tester) async {
    await tester.pumpWidget(harness(UserRole.staff));
    await tester.pumpAndSettle();

    expect(find.text('Damaged'), findsOneWidget);
    expect(find.text('Recount'), findsOneWidget);
    expect(find.text('Note required'), findsOneWidget);
  });

  testWidgets('cashier: no archive or delete buttons', (tester) async {
    await tester.pumpWidget(harness(UserRole.cashier));
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.archive), findsNothing);
    expect(find.byIcon(LucideIcons.trash2), findsNothing);
  });

  testWidgets('staff: archive + delete buttons present', (tester) async {
    await tester.pumpWidget(harness(UserRole.staff));
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.archive), findsNWidgets(2));
    expect(find.byIcon(LucideIcons.trash2), findsNWidgets(2));
  });

  testWidgets('create dialog saves requiresNote from the switch',
      (tester) async {
    _FakeAdjustmentReasonOps? ops;
    await tester.pumpWidget(harness(UserRole.cashier, extraOverrides: [
      adjustmentReasonOperationsProvider.overrideWith((ref) {
        ops = _FakeAdjustmentReasonOps(ref);
        return ops!;
      }),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Spoilage');
    await tester.tap(find.widgetWithText(SwitchListTile, 'Note required'));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(ops!.created.single.name, 'Spoilage');
    expect(ops!.created.single.requiresNote, true);
  });

  testWidgets('seed default reasons action is visible', (tester) async {
    await tester.pumpWidget(harness(UserRole.staff));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.moreVertical));
    await tester.pumpAndSettle();
    expect(find.text('Seed default reasons'), findsOneWidget);
  });
}
