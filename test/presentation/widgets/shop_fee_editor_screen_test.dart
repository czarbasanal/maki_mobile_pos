import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/data/repositories/shop_fee_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/shop_fee_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/shop_fee_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/settings/shop_fee_editor_screen.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ShopFeeRepository repo;

  UserEntity currentUser(UserRole role) => UserEntity(
        id: 'admin-1',
        email: 'admin@x.com',
        displayName: 'Admin',
        role: role,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      );

  Widget harness({UserRole role = UserRole.admin}) => ProviderScope(
        overrides: [
          shopFeeRepositoryProvider.overrideWithValue(repo),
          currentUserProvider
              .overrideWith((ref) => Stream.value(currentUser(role))),
        ],
        child: const MaterialApp(home: ShopFeeEditorScreen()),
      );

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = ShopFeeRepositoryImpl(firestore: fakeFirestore);
  });

  testWidgets('shows empty state when there are no shop fees',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Shop Fees'), findsWidgets);
    expect(find.text('No shop fees yet'), findsOneWidget);
  });

  testWidgets('renders a shop fee row with its default amount from the repo',
      (tester) async {
    await repo.createShopFee(
      shopFee: ShopFeeEntity(
        id: '',
        name: 'Disposal Fee',
        defaultAmount: 20,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
      createdBy: 'admin-1',
    );

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Disposal Fee'), findsOneWidget);
    expect(find.text('₱20.00'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets(
      'a shop fee with no default amount shows the entered-at-register subtitle',
      (tester) async {
    await repo.createShopFee(
      shopFee: ShopFeeEntity(
        id: '',
        name: 'Misc Fee',
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
      createdBy: 'admin-1',
    );

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Misc Fee'), findsOneWidget);
    expect(find.text('No default — entered at register'), findsOneWidget);
  });

  testWidgets('creating a shop fee persists the name and default amount',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Open the add dialog.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Fields render in order: name, default amount.
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'Battery Fee');
    await tester.enterText(fields.at(1), '15');

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final saved = await repo.watchAll().first;
    expect(saved, hasLength(1));
    expect(saved.first.name, 'Battery Fee');
    expect(saved.first.defaultAmount, 15);
  });

  testWidgets('creating a shop fee with a blank default amount saves null',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Air Fee');

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final saved = await repo.watchAll().first;
    expect(saved, hasLength(1));
    expect(saved.first.name, 'Air Fee');
    expect(saved.first.defaultAmount, isNull);
  });

  testWidgets('cashier sees edit but no deactivate toggle', (tester) async {
    await repo.createShopFee(
      shopFee: ShopFeeEntity(
        id: '',
        name: 'Disposal Fee',
        defaultAmount: 20,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
      createdBy: 'admin-1',
    );

    await tester.pumpWidget(harness(role: UserRole.cashier));
    await tester.pumpAndSettle();

    // Edit affordance still present on every row…
    expect(find.byIcon(LucideIcons.squarePen), findsWidgets);
    // …but the archive (deactivate) affordance is gone.
    expect(find.byIcon(LucideIcons.archive), findsNothing);
    expect(find.byIcon(LucideIcons.rotateCcw), findsNothing);
  });

  testWidgets('cashier edit dialog has no Active switch', (tester) async {
    await repo.createShopFee(
      shopFee: ShopFeeEntity(
        id: '',
        name: 'Disposal Fee',
        defaultAmount: 20,
        isActive: true,
        createdAt: DateTime(2026, 5, 30),
      ),
      createdBy: 'admin-1',
    );

    await tester.pumpWidget(harness(role: UserRole.cashier));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(LucideIcons.squarePen).first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Shop Fee'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
  });
}
