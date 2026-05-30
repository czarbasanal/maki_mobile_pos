import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/cost_code_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/inventory/product_form_screen.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/cost_code_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _FakeProductEntity extends Fake implements ProductEntity {}

class _FakeActivityLogEntity extends Fake implements ActivityLogEntity {}

const _kSkuFieldKey = Key('product-sku-field');

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeProductEntity());
    registerFallbackValue(_FakeActivityLogEntity());
  });

  late _MockProductRepository repo;
  late _MockActivityLogRepository logRepo;

  final testProduct = ProductEntity(
    id: 'p-1',
    sku: 'SKU-001',
    name: 'Coke',
    costCode: 'NBF',
    cost: 60,
    price: 100,
    quantity: 50,
    reorderLevel: 10,
    unit: 'pcs',
    isActive: true,
    createdAt: DateTime(2024, 1, 1),
  );

  setUp(() {
    repo = _MockProductRepository();
    logRepo = _MockActivityLogRepository();

    when(() => repo.getProductById('p-1'))
        .thenAnswer((_) async => testProduct);
    when(() => repo.skuExists(
          sku: any(named: 'sku'),
          excludeProductId: any(named: 'excludeProductId'),
        )).thenAnswer((_) async => false);
    when(() => repo.getSkuVariations(any()))
        .thenAnswer((_) async => <ProductEntity>[]);
    when(() => repo.updateProduct(
          product: any(named: 'product'),
          updatedBy: any(named: 'updatedBy'),
          updatedByName: any(named: 'updatedByName'),
        )).thenAnswer(
        (inv) async => inv.namedArguments[#product] as ProductEntity);
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
  });

  UserEntity user(UserRole role) => UserEntity(
        id: 'u-${role.value}',
        email: '${role.value}@test',
        displayName: '${role.value} user',
        role: role,
        isActive: true,
        createdAt: DateTime(2024, 1, 1),
      );

  // Pumps the edit form for an existing product as [role]. Backend providers
  // are overridden so the screen renders deterministically without Firebase;
  // suppliers/categories simply resolve to their error state (static text),
  // which is fine — this test only cares about the SKU field and dialog.
  Future<void> pumpForm(WidgetTester tester, UserRole role) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(user(role))),
          productRepositoryProvider.overrideWith((ref) => repo),
          activityLogRepositoryProvider.overrideWith((ref) => logRepo),
          costCodeMappingProvider
              .overrideWith((ref) => CostCodeEntity.defaultMapping()),
        ],
        child: const MaterialApp(
          home: ProductFormScreen(productId: 'p-1'),
        ),
      ),
    );
    // Settles the async product load (the transient load spinner clears once
    // getProductById resolves). Safe because nothing animates indefinitely
    // until a save is in flight.
    await tester.pumpAndSettle();
  }

  TextFormField skuField(WidgetTester tester) =>
      tester.widget<TextFormField>(find.byKey(_kSkuFieldKey));

  group('ProductFormScreen — SKU field gating', () {
    testWidgets('admin CAN edit the SKU', (tester) async {
      await pumpForm(tester, UserRole.admin);
      expect(skuField(tester).enabled, isTrue);
    });

    testWidgets('staff CANNOT edit the SKU', (tester) async {
      await pumpForm(tester, UserRole.staff);
      expect(skuField(tester).enabled, isFalse);
    });

    testWidgets('cashier CANNOT edit the SKU', (tester) async {
      await pumpForm(tester, UserRole.cashier);
      expect(skuField(tester).enabled, isFalse);
    });
  });

  group('ProductFormScreen — SKU change confirmation', () {
    testWidgets('changing the SKU and saving shows a confirm dialog',
        (tester) async {
      await pumpForm(tester, UserRole.admin);

      await tester.enterText(find.byKey(_kSkuFieldKey), 'SKU-NEW');
      await tester.pump();
      // The submit button sits below the fold in the test viewport — scroll
      // it into view before tapping (settle is safe: not saving yet).
      await tester.ensureVisible(find.text('Update Product'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update Product'));
      // NOT pumpAndSettle: once saving, the button shows a perpetual spinner.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Change SKU?'), findsOneWidget);
      expect(find.text('SKU-001  →  SKU-NEW'), findsOneWidget);
      // The product is NOT written until the admin confirms.
      verifyNever(() => repo.updateProduct(
            product: any(named: 'product'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          ));
    });

    testWidgets('cancelling the dialog aborts the save', (tester) async {
      await pumpForm(tester, UserRole.admin);

      await tester.enterText(find.byKey(_kSkuFieldKey), 'SKU-NEW');
      await tester.pump();
      // The submit button sits below the fold in the test viewport — scroll
      // it into view before tapping (settle is safe: not saving yet).
      await tester.ensureVisible(find.text('Update Product'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update Product'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Cancel'));
      // After cancel the save is abandoned (isSaving resets), so the tree
      // settles again.
      await tester.pumpAndSettle();

      expect(find.text('Change SKU?'), findsNothing);
      verifyNever(() => repo.updateProduct(
            product: any(named: 'product'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
          ));
    });
  });
}
