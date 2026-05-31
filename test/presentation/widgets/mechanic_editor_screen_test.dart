import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/mechanic_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/mechanic_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/mechanic_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/mechanic_editor_screen.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MechanicRepository repo;

  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'admin@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );

  Widget harness() => ProviderScope(
        overrides: [
          mechanicRepositoryProvider.overrideWithValue(repo),
          currentUserProvider.overrideWith((ref) => Stream.value(admin())),
        ],
        child: const MaterialApp(home: MechanicEditorScreen()),
      );

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = MechanicRepositoryImpl(firestore: fakeFirestore);
  });

  testWidgets('shows empty state when there are no mechanics',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Mechanics'), findsWidgets);
    expect(find.text('No mechanics yet'), findsOneWidget);
  });

  testWidgets('renders a mechanic row from the repository', (tester) async {
    await repo.createMechanic(
      mechanic: MechanicEntity(
        id: '',
        name: 'Juan Dela Cruz',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
      createdBy: 'admin-1',
    );

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
