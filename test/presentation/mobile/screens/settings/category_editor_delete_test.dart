import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/category_editor_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/category_provider.dart';

/// Recording fake — same subclass technique as `_FakeExpenseOps` in
/// test/presentation/widgets/end_of_day_review_test.dart.
class _FakeCategoryOps extends CategoryOperationsNotifier {
  _FakeCategoryOps(super.ref, super.kind);
  final deleted = <String>[];

  @override
  Future<bool> delete(String categoryId) async {
    deleted.add(categoryId);
    return true;
  }
}

UserEntity _staff() => UserEntity(
      id: 'u-staff',
      email: 'staff@x.com',
      displayName: 'Staff',
      role: UserRole.staff,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

CategoryEntity _category(String id, String name) => CategoryEntity(
      id: id,
      name: name,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  const kind = CategoryKind.product;

  Widget harness({required List<Override> extraOverrides}) => ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(_staff())),
          allCategoriesProvider(kind).overrideWith(
            (ref) => Stream.value([_category('c1', 'Brakes')]),
          ),
          ...extraOverrides,
        ],
        child: const MaterialApp(
          home: CategoryEditorScreen(kind: kind),
        ),
      );

  testWidgets(
      'staff: tapping trash then confirm deletes the category',
      (tester) async {
    _FakeCategoryOps? ops;
    await tester.pumpWidget(harness(extraOverrides: [
      categoryOperationsProvider(kind)
          .overrideWith((ref) => ops = _FakeCategoryOps(ref, kind)),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();

    expect(find.text('Delete this entry?'), findsOneWidget);
    // Nothing deleted before confirm — the ops notifier hasn't even been
    // instantiated yet (it's created lazily on first read at delete time).
    expect(ops?.deleted ?? const [], isEmpty);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(ops!.deleted, ['c1']);
    expect(find.text('Deleted'), findsOneWidget); // success snackbar
  });

  testWidgets('staff: cancelling the delete confirmation deletes nothing',
      (tester) async {
    _FakeCategoryOps? ops;
    await tester.pumpWidget(harness(extraOverrides: [
      categoryOperationsProvider(kind)
          .overrideWith((ref) => ops = _FakeCategoryOps(ref, kind)),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();

    expect(find.text('Delete this entry?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(ops?.deleted ?? const [], isEmpty);
  });
}
