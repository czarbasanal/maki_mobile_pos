import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/activity_log_entity.dart';
import 'package:maki_mobile_pos/domain/entities/category_entity.dart';
import 'package:maki_mobile_pos/domain/entities/cost_code_entity.dart';
import 'package:maki_mobile_pos/domain/entities/product_entity.dart';
import 'package:maki_mobile_pos/domain/entities/user_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/category_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/inventory/product_form_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/product_image_uploader.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/category_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/cost_code_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dropdown.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:maki_mobile_pos/services/product_image_storage_service.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _MockCategoryRepository extends Mock implements CategoryRepository {}

class _FakeProductEntity extends Fake implements ProductEntity {}

class _FakeActivityLogEntity extends Fake implements ActivityLogEntity {}

/// In-memory stand-in for the Storage service so save flows can run in
/// widget tests (no Firebase). Records uploads and hands back a stable URL.
class _FakeImageStorage extends Fake implements ProductImageStorageService {
  final uploads = <String>[];

  @override
  Future<String> upload({
    required String productId,
    required Uint8List bytes,
  }) async {
    uploads.add(productId);
    return 'https://fake.test/$productId/main.jpg';
  }

  @override
  Future<void> delete({required String productId}) async {}
}

// The SKU field's widget key is now a GlobalKey<FormFieldState<String>>
// (product_form_screen.dart, so _applyCategoryForSku can scope-revalidate
// just this field), and GlobalKeys can't be reconstructed from outside the
// State that owns them. Find the field by its label instead, same pattern
// already used for Name below.
final _skuFieldFinder = find.widgetWithText(TextFormField, 'SKU *');

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeProductEntity());
    registerFallbackValue(_FakeActivityLogEntity());
  });

  late _MockProductRepository repo;
  late _MockActivityLogRepository logRepo;
  late _FakeImageStorage storage;

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
    storage = _FakeImageStorage();

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
          includeSellingOptions: any(named: 'includeSellingOptions'),
        )).thenAnswer(
        (inv) async => inv.namedArguments[#product] as ProductEntity);
    when(() => logRepo.logActivity(any()))
        .thenAnswer((inv) async => inv.positionalArguments.first);
    // A completed save invalidates the product list providers — give the
    // mock harmless streams so post-save rebuilds don't throw.
    when(() => repo.watchProducts())
        .thenAnswer((_) => Stream.value(const <ProductEntity>[]));
    when(() => repo.watchLowStockProducts())
        .thenAnswer((_) => Stream.value(const <ProductEntity>[]));
  });

  // Smallest valid image: 1x1 transparent PNG (the uploader previews the
  // picked bytes with Image.memory, which decodes them for real in tests).
  final onePxPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

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
          productImageStorageServiceProvider.overrideWithValue(storage),
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
      tester.widget<TextFormField>(_skuFieldFinder);

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

  group('ProductFormScreen — image uploader gating', () {
    ProductImageUploader uploader(WidgetTester tester) =>
        tester.widget<ProductImageUploader>(
            find.byType(ProductImageUploader));

    // Regression (2026-07-02): staff editing an existing product had the
    // uploader disabled ("cannot attach or capture image"), even though the
    // rules allow staff imageUrl updates.
    testWidgets('staff CAN manage the image when editing', (tester) async {
      await pumpForm(tester, UserRole.staff);
      expect(uploader(tester).enabled, isTrue);
    });

    testWidgets('cashier CAN manage the image when editing', (tester) async {
      await pumpForm(tester, UserRole.cashier);
      expect(uploader(tester).enabled, isTrue);
    });

    testWidgets('admin CAN manage the image when editing', (tester) async {
      await pumpForm(tester, UserRole.admin);
      expect(uploader(tester).enabled, isTrue);
    });

    // Pins the other half of the staff fix: the staff SAVE branch must carry
    // the picked image through to updateProduct (it used to drop the bytes).
    testWidgets('staff save uploads the picked image and writes its URL',
        (tester) async {
      await pumpForm(tester, UserRole.staff);

      // Simulate a completed pick+crop via the uploader's callback (the
      // picker itself needs a platform channel, so we invoke the contract).
      uploader(tester).onChanged(onePxPng, removed: false);
      await tester.pump();

      await tester.ensureVisible(find.text('Update Product'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update Product'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(storage.uploads, hasLength(1));
      final captured = verify(() => repo.updateProduct(
            product: captureAny(named: 'product'),
            updatedBy: any(named: 'updatedBy'),
            updatedByName: any(named: 'updatedByName'),
            includeSellingOptions: any(named: 'includeSellingOptions'),
          )).captured;
      expect((captured.single as ProductEntity).imageUrl,
          'https://fake.test/p-1/main.jpg');
    });
  });

  group('ProductFormScreen — SKU change confirmation', () {
    testWidgets('changing the SKU and saving shows a confirm dialog',
        (tester) async {
      await pumpForm(tester, UserRole.admin);

      await tester.enterText(_skuFieldFinder, 'SKU-NEW');
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
            includeSellingOptions: any(named: 'includeSellingOptions'),
          ));
    });

    testWidgets('cancelling the dialog aborts the save', (tester) async {
      await pumpForm(tester, UserRole.admin);

      await tester.enterText(_skuFieldFinder, 'SKU-NEW');
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
            includeSellingOptions: any(named: 'includeSellingOptions'),
          ));
    });
  });

  // Pumps the *create* form (no productId) so the cost field + margin line
  // are always shown (admin).
  Future<void> pumpCreate(WidgetTester tester, UserRole role) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(user(role))),
          productRepositoryProvider.overrideWith((ref) => repo),
          activityLogRepositoryProvider.overrideWith((ref) => logRepo),
          productImageStorageServiceProvider.overrideWithValue(storage),
          costCodeMappingProvider
              .overrideWith((ref) => CostCodeEntity.defaultMapping()),
        ],
        child: const MaterialApp(home: ProductFormScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  // Same as pumpCreate, but with product categories (and their code repo)
  // wired up, for the category-coded auto-SKU tests below.
  Future<void> pumpCreateWithCategories(
    WidgetTester tester,
    UserRole role,
    List<CategoryEntity> categories,
    CategoryRepository categoryRepo,
  ) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(user(role))),
          productRepositoryProvider.overrideWith((ref) => repo),
          activityLogRepositoryProvider.overrideWith((ref) => logRepo),
          productImageStorageServiceProvider.overrideWithValue(storage),
          costCodeMappingProvider
              .overrideWith((ref) => CostCodeEntity.defaultMapping()),
          activeCategoriesProvider(CategoryKind.product)
              .overrideWith((ref) => Stream.value(categories)),
          categoryRepositoryProvider(CategoryKind.product)
              .overrideWith((ref) => categoryRepo),
        ],
        child: const MaterialApp(home: ProductFormScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  group('ProductFormScreen — bundle 04 layout', () {
    testWidgets('groups fields under uppercase section headers',
        (tester) async {
      await pumpForm(tester, UserRole.admin);
      expect(find.text('IDENTITY'), findsOneWidget);
      expect(find.text('PRICING'), findsOneWidget);
      expect(find.text('STOCK'), findsOneWidget);
      expect(find.text('CLASSIFICATION'), findsOneWidget);
    });

    testWidgets('uses the shortened Selling label and a keyed pinned submit',
        (tester) async {
      await pumpForm(tester, UserRole.admin);
      expect(find.text('Selling (₱) *'), findsOneWidget);
      expect(find.byKey(const Key('product-form-submit')), findsOneWidget);
    });

    testWidgets('shows a live margin line from the price/cost pair',
        (tester) async {
      await pumpCreate(tester, UserRole.admin);
      await tester.enterText(
          find.byKey(const Key('product-price-field')), '250');
      await tester.enterText(
          find.byKey(const Key('product-cost-field')), '180');
      await tester.pump();
      // (250-180)/250 = 28%; unit profit ₱70.00.
      expect(find.textContaining('28%'), findsOneWidget);
      expect(find.textContaining('₱70.00 per unit'), findsOneWidget);
    });

    testWidgets('audit is a clean AppCard and price-history shows on admin edit',
        (tester) async {
      await pumpForm(tester, UserRole.admin);
      // Section header present; audit rows render inside the card.
      expect(find.text('AUDIT'), findsOneWidget);
      expect(find.text('Created'), findsOneWidget);
      // The old bordered card's inner "Audit info" header is gone.
      expect(find.text('Audit info'), findsNothing);
      // Price-history link shows for any admin on edit (no cost-eye gate).
      expect(find.text('View price history'), findsOneWidget);
    });
  });

  group('ProductFormScreen — category-coded auto-SKU (create)', () {
    CategoryEntity cat(String name, {String? code}) => CategoryEntity(
          id: 'cat-$name',
          name: name,
          isActive: true,
          code: code,
          createdAt: DateTime(2024, 1, 1),
        );

    late _MockCategoryRepository categoryRepo;

    setUp(() {
      categoryRepo = _MockCategoryRepository();
      when(() => categoryRepo.peekNextSequence('0007'))
          .thenAnswer((_) async => 1);
      when(() => categoryRepo.peekNextSequence('0009'))
          .thenAnswer((_) async => 5);
    });

    // Auto-generate SKU defaults ON for new products, so selecting a
    // category is enough to trigger the peek — no switch toggle needed.
    Future<void> selectCategory(WidgetTester tester, String name) async {
      await tester
          .tap(find.widgetWithText(AppDropdown<String>, 'Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    testWidgets('selecting a coded category fills the peeked SKU',
        (tester) async {
      await pumpCreateWithCategories(
        tester,
        UserRole.admin,
        [cat('Bolts', code: '0007'), cat('Filters', code: '0009')],
        categoryRepo,
      );

      await selectCategory(tester, 'Bolts');

      expect(skuField(tester).controller!.text, '00070001');
    });

    testWidgets('switching to a second coded category re-peeks',
        (tester) async {
      await pumpCreateWithCategories(
        tester,
        UserRole.admin,
        [cat('Bolts', code: '0007'), cat('Filters', code: '0009')],
        categoryRepo,
      );

      await selectCategory(tester, 'Bolts');
      expect(skuField(tester).controller!.text, '00070001');

      await selectCategory(tester, 'Filters');
      expect(skuField(tester).controller!.text, '00090005');
    });

    // Updated for task-3: a code-less category used to fall back to a
    // name-based SKU; it now leaves the field empty (ratified deviation).
    testWidgets('selecting a code-less category leaves the SKU empty',
        (tester) async {
      await pumpCreateWithCategories(
        tester,
        UserRole.admin,
        [cat('Bolts', code: '0007'), cat('Misc')],
        categoryRepo,
      );

      await selectCategory(tester, 'Misc');

      expect(skuField(tester).controller!.text, isEmpty);
    });

    testWidgets(
        'manual typing over the SKU field survives an unrelated rebuild',
        (tester) async {
      await pumpCreateWithCategories(
        tester,
        UserRole.admin,
        [cat('Bolts', code: '0007')],
        categoryRepo,
      );

      await selectCategory(tester, 'Bolts');
      expect(skuField(tester).controller!.text, '00070001');

      // Flip to manual mode (this is also what enables direct edits — the
      // SKU field is disabled while auto-generate drives it) and type a
      // value of the user's own choosing.
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.enterText(_skuFieldFinder, 'MANUAL-1');
      await tester.pump();

      // Unrelated rebuild: editing price triggers a setState via the
      // _onPriceOrCostChanged listener, unrelated to category/SKU state.
      await tester.enterText(
          find.byKey(const Key('product-price-field')), '99');
      await tester.pump();

      expect(skuField(tester).controller!.text, 'MANUAL-1');
    });

    testWidgets(
        'toggling auto-generate OFF cancels a stalled peekNextSequence',
        (tester) async {
      // Make peekNextSequence hang so we can toggle the switch while it's
      // in flight.
      final peekCompleter = Completer<int>();
      when(() => categoryRepo.peekNextSequence('0007'))
          .thenAnswer((_) => peekCompleter.future);

      await pumpCreateWithCategories(
        tester,
        UserRole.admin,
        [cat('Bolts', code: '0007')],
        categoryRepo,
      );

      // Select the category — this starts a peek that will hang.
      await selectCategory(tester, 'Bolts');
      // The SKU field is disabled while auto-generate is ON, so it shouldn't
      // show the peeked value yet (and can't be edited).
      expect(skuField(tester).enabled, isFalse);

      // Toggle auto-generate OFF (this is also what enables direct edits).
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      // Now manually type a SKU while the peek is still in flight.
      await tester.enterText(_skuFieldFinder, 'MANUAL-1');
      await tester.pump();
      expect(skuField(tester).controller!.text, 'MANUAL-1');

      // Complete the stalled peek — it should be ignored because
      // auto-generate is now OFF.
      peekCompleter.complete(1);
      await tester.pump();

      // The field should still read MANUAL-1, not the peeked SKU.
      expect(skuField(tester).controller!.text, 'MANUAL-1');
    });
  });

  testWidgets('name and SKU fields uppercase as you type', (tester) async {
    await pumpForm(tester, UserRole.admin);

    final nameField = find.widgetWithText(TextFormField, 'Product Name *');
    await tester.enterText(nameField, 'brake pad');
    expect(
      (tester.widget<TextFormField>(nameField).controller)!.text,
      'BRAKE PAD',
    );

    await tester.enterText(_skuFieldFinder, 'abc123x');
    expect(
      tester
          .widget<TextFormField>(_skuFieldFinder)
          .controller!
          .text,
      'ABC123X',
    );
  });
}
