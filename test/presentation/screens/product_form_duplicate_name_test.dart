// Task 8: mobile mirror of the web duplicate-name gate (Task 6). The gate
// fires only on CREATE, before the write — an accidental re-entry of a part
// that already exists offers a choice (variation / separate / cancel)
// instead of silently doubling up the catalog under a fresh auto-SKU.
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
import 'package:maki_mobile_pos/services/product_image_storage_service.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _FakeProductEntity extends Fake implements ProductEntity {}

class _FakeActivityLogEntity extends Fake implements ActivityLogEntity {}

class _FakeImageStorage extends Fake implements ProductImageStorageService {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeProductEntity());
    registerFallbackValue(_FakeActivityLogEntity());
  });

  late _MockProductRepository repo;
  late _MockActivityLogRepository logRepo;

  final seededBelt = ProductEntity(
    id: 'existing-belt',
    sku: '00010001',
    name: 'BANDO BELT',
    costCode: 'NBF',
    cost: 120,
    price: 250,
    quantity: 10,
    reorderLevel: 2,
    unit: 'pcs',
    isActive: true,
    createdAt: DateTime(2024, 1, 1),
  );

  setUp(() {
    repo = _MockProductRepository();
    logRepo = _MockActivityLogRepository();

    when(() => repo.getProductByNameKey(any()))
        .thenAnswer((_) async => seededBelt);
    when(() => repo.createProduct(
          product: any(named: 'product'),
          createdBy: any(named: 'createdBy'),
          createdByName: any(named: 'createdByName'),
          autoSkuCategoryCode: any(named: 'autoSkuCategoryCode'),
        )).thenAnswer((inv) async =>
        (inv.namedArguments[#product] as ProductEntity).copyWith(id: 'p-new'));
    when(() => repo.createVariation(
          originalProduct: any(named: 'originalProduct'),
          newCost: any(named: 'newCost'),
          newCostCode: any(named: 'newCostCode'),
          newPrice: any(named: 'newPrice'),
          createdBy: any(named: 'createdBy'),
          createdByName: any(named: 'createdByName'),
        )).thenAnswer((_) async => seededBelt.copyWith(
          id: 'variation-1',
          sku: '00010001-1',
        ));
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
    when(() => repo.watchProducts())
        .thenAnswer((_) => Stream.value(const <ProductEntity>[]));
    when(() => repo.watchLowStockProducts())
        .thenAnswer((_) => Stream.value(const <ProductEntity>[]));
  });

  UserEntity admin() => UserEntity(
        id: 'u-admin',
        email: 'admin@test',
        displayName: 'Admin User',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2024, 1, 1),
      );

  Future<void> pumpCreate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(admin())),
          productRepositoryProvider.overrideWith((ref) => repo),
          activityLogRepositoryProvider.overrideWith((ref) => logRepo),
          productImageStorageServiceProvider
              .overrideWithValue(_FakeImageStorage()),
          costCodeMappingProvider
              .overrideWith((ref) => CostCodeEntity.defaultMapping()),
        ],
        child: const MaterialApp(home: ProductFormScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> fillForm(WidgetTester tester,
      {String name = 'BANDO BELT', String cost = '130', String price = '300'}) async {
    // Switch off auto-SKU (no categories wired up) so the SKU field is
    // editable, then fill the required fields.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'SKU *'), 'SKU-NEW-1');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Product Name *'), name);
    await tester.enterText(
        find.byKey(const Key('product-price-field')), price);
    await tester.enterText(find.byKey(const Key('product-cost-field')), cost);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantity *'), '5');
    await tester.pump();
  }

  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('product-form-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('product-form-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('ProductFormScreen — duplicate-name gate', () {
    testWidgets('offers a choice instead of saving when the name already exists',
        (tester) async {
      await pumpCreate(tester);
      await fillForm(tester);
      await tapSubmit(tester);

      expect(find.textContaining('already exists'), findsOneWidget);
      verifyNever(() => repo.createProduct(
            product: any(named: 'product'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            autoSkuCategoryCode: any(named: 'autoSkuCategoryCode'),
          ));
    });

    testWidgets('Make it a variation passes the typed cost and price',
        (tester) async {
      await pumpCreate(tester);
      await fillForm(tester, cost: '130', price: '300');
      await tapSubmit(tester);

      await tester.tap(find.text('Make it a variation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final captured = verify(() => repo.createVariation(
            originalProduct: captureAny(named: 'originalProduct'),
            newCost: captureAny(named: 'newCost'),
            newCostCode: any(named: 'newCostCode'),
            newPrice: captureAny(named: 'newPrice'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
          )).captured;
      expect((captured[0] as ProductEntity).id, 'existing-belt');
      expect(captured[1], 130.0);
      expect(captured[2], 300.0);
    });

    testWidgets('Save as a separate product creates normally', (tester) async {
      await pumpCreate(tester);
      await fillForm(tester);
      await tapSubmit(tester);

      await tester.tap(find.text('Save as a separate product'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      verify(() => repo.createProduct(
            product: any(named: 'product'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            autoSkuCategoryCode: any(named: 'autoSkuCategoryCode'),
          )).called(1);
    });

    testWidgets('Cancel writes nothing', (tester) async {
      await pumpCreate(tester);
      await fillForm(tester);
      await tapSubmit(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => repo.createProduct(
            product: any(named: 'product'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            autoSkuCategoryCode: any(named: 'autoSkuCategoryCode'),
          ));
      verifyNever(() => repo.createVariation(
            originalProduct: any(named: 'originalProduct'),
            newCost: any(named: 'newCost'),
            newCostCode: any(named: 'newCostCode'),
            newPrice: any(named: 'newPrice'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
          ));
    });

    testWidgets('a failed lookup does not block a legitimate save',
        (tester) async {
      when(() => repo.getProductByNameKey(any()))
          .thenThrow(Exception('offline'));
      await pumpCreate(tester);
      await fillForm(tester, name: 'GENUINELY NEW PART');
      await tapSubmit(tester);

      expect(find.textContaining('already exists'), findsNothing);
      verify(() => repo.createProduct(
            product: any(named: 'product'),
            createdBy: any(named: 'createdBy'),
            createdByName: any(named: 'createdByName'),
            autoSkuCategoryCode: any(named: 'autoSkuCategoryCode'),
          )).called(1);
    });
  });
}
