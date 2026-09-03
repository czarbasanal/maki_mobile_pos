import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/tag_editor_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/tag_provider.dart';

class _FakeTagOps extends TagOperationsNotifier {
  _FakeTagOps(super.ref);
  final created = <TagEntity>[];

  @override
  Future<TagEntity?> create({required TagEntity tag}) async {
    created.add(tag);
    return tag.copyWith(id: 'new-1');
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

TagEntity _tag(String id, String name, {bool isActive = true}) => TagEntity(
      id: id,
      name: name,
      color: 'green',
      description: 'Count verified',
      isActive: isActive,
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  Widget harness(UserRole role, {List<Override> extraOverrides = const []}) =>
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(_user(role))),
          allTagsProvider.overrideWith((ref) => Stream.value([_tag('t1', 'Intact')])),
          ...extraOverrides,
        ],
        child: const MaterialApp(home: TagEditorScreen()),
      );

  testWidgets('lists tags with description subtitle', (tester) async {
    await tester.pumpWidget(harness(UserRole.staff));
    await tester.pumpAndSettle();
    expect(find.text('Intact'), findsOneWidget);
    expect(find.text('Count verified'), findsOneWidget);
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
    expect(find.byIcon(LucideIcons.archive), findsOneWidget);
    expect(find.byIcon(LucideIcons.trash2), findsOneWidget);
  });

  testWidgets('add dialog creates a tag with the picked color', (tester) async {
    _FakeTagOps? ops;
    await tester.pumpWidget(harness(UserRole.cashier, extraOverrides: [
      tagOperationsProvider.overrideWith((ref) {
        ops = _FakeTagOps(ref);
        return ops!;
      }),
    ]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Recheck');
    await tester.tap(find.byKey(const ValueKey('tag-color-amber')));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(ops!.created.single.name, 'Recheck');
    expect(ops!.created.single.color, 'amber');
  });
}
