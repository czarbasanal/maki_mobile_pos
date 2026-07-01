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

  testWidgets('creating a mechanic persists contact number + address',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Open the add dialog.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Fields render in order: name, contact number, address.
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'Pedro Penduko');
    await tester.enterText(fields.at(1), '0917 123 4567');
    await tester.enterText(fields.at(2), '123 Rizal St, Cebu');

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final saved = await repo.watchAll().first;
    expect(saved, hasLength(1));
    expect(saved.first.name, 'Pedro Penduko');
    expect(saved.first.contactNumber, '0917 123 4567');
    expect(saved.first.address, '123 Rizal St, Cebu');
  });

  testWidgets('edit dialog pre-fills contact + address from the mechanic',
      (tester) async {
    await repo.createMechanic(
      mechanic: MechanicEntity(
        id: '',
        name: 'Juan Dela Cruz',
        isActive: true,
        address: '456 Mabini St',
        contactNumber: '0999 000 1111',
        createdAt: DateTime(2026, 5, 30),
      ),
      createdBy: 'admin-1',
    );

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Tap the row to open the edit dialog.
    await tester.tap(find.text('Juan Dela Cruz'));
    await tester.pumpAndSettle();

    expect(find.text('456 Mabini St'), findsOneWidget);
    expect(find.text('0999 000 1111'), findsOneWidget);
  });
}
