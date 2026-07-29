import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/category_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/cost_code_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dropdown.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:maki_mobile_pos/services/product_image_storage_service.dart';

// ---- Mocks/fakes copied from product_form_screen_test.dart's setUp — see
// that file for the canonical harness this one mirrors. ----

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

const _kSkuFieldKey = Key('product-sku-field');
const _kNameFieldKey = Key('product-name-field');

final _codedCategory = CategoryEntity(
  id: 'cat-bolts',
  name: 'Bolts',
  isActive: true,
  code: '0007',
  createdAt: DateTime(2024, 1, 1),
);

final _uncodedCategory = CategoryEntity(
  id: 'cat-misc',
  name: 'Misc',
  isActive: true,
  code: null,
  createdAt: DateTime(2024, 1, 1),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeProductEntity());
    registerFallbackValue(_FakeActivityLogEntity());
  });

  late _MockProductRepository repo;
  late _MockActivityLogRepository logRepo;
  late _MockCategoryRepository categoryRepo;
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
    categoryRepo = _MockCategoryRepository();
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

  UserEntity user(UserRole role) => UserEntity(
        id: 'u-${role.value}',
        email: '${role.value}@test',
        displayName: '${role.value} user',
        role: role,
        isActive: true,
        createdAt: DateTime(2024, 1, 1),
      );

  // Pumps the *create* form (no productId) as admin, with product categories
  // (and their code repo) wired up — mirrors pumpCreateWithCategories in
  // product_form_screen_test.dart.
  Future<void> pumpCreateScreen(
    WidgetTester tester, {
    required List<CategoryEntity> categories,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider
              .overrideWith((ref) => Stream.value(user(UserRole.admin))),
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

  // Auto-generate SKU defaults ON for new products, so selecting a category
  // is enough to trigger the peek — no switch toggle needed.
  Future<void> selectCategory(WidgetTester tester, String name) async {
    await tester.tap(find.widgetWithText(AppDropdown<String>, 'Category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  TextFormField skuField(WidgetTester tester) =>
      tester.widget<TextFormField>(find.byKey(_kSkuFieldKey));

  group('ProductFormScreen — auto-SKU (create mode)', () {
    testWidgets('opens with an empty SKU and the pick-a-category hint',
        (tester) async {
      await pumpCreateScreen(tester, categories: [_uncodedCategory]);

      expect(skuField(tester).controller!.text, isEmpty);
      expect(find.text('Pick a category to generate the SKU.'), findsOneWidget);
    });

    testWidgets('typing and blurring the name generates nothing',
        (tester) async {
      await pumpCreateScreen(tester, categories: [_uncodedCategory]);

      // A name that WOULD have produced a visible, non-empty SKU under the
      // old name-based generator (a non-trivial slug, not blank/symbols-only).
      await tester.enterText(find.byKey(_kNameFieldKey), 'MILK CHOCOLATE');
      await tester.pumpAndSettle();
      // Move focus away to fire any blur handler. NOT tester.tap on the SKU
      // field: it's disabled while auto-generate is on (skuFieldEnabled is
      // false in create+auto mode), and Flutter wraps a disabled TextField in
      // IgnorePointer with canRequestFocus false — a tap there cannot move
      // focus, and tap-outside doesn't auto-unfocus for touch pointers (the
      // flutter_test default). Unfocus explicitly instead.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(skuField(tester).controller!.text, isEmpty);
    });

    testWidgets('choosing a coded category fills the 8-digit SKU',
        (tester) async {
      when(() => categoryRepo.peekNextSequence('0007'))
          .thenAnswer((_) async => 5);
      await pumpCreateScreen(tester, categories: [_codedCategory]);

      await selectCategory(tester, _codedCategory.name);

      expect(skuField(tester).controller!.text, '00070005');
      expect(find.text('Pick a category to generate the SKU.'), findsNothing);
    });

    testWidgets('choosing an uncoded category leaves it empty and says why',
        (tester) async {
      await pumpCreateScreen(tester, categories: [_uncodedCategory]);

      await selectCategory(tester, _uncodedCategory.name);

      expect(skuField(tester).controller!.text, isEmpty);
      expect(
        find.text('This category has no code — pick another, or turn off '
            'auto-generate and type a SKU.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'a failed peek leaves it empty with a network hint, not the '
        'no-code message',
        (tester) async {
      // thenAnswer((_) async => throw …), not thenThrow: the mocked method
      // returns a Future, and thenThrow makes mocktail throw synchronously at
      // the call site — before .then()/.catchError() ever attach — which
      // crashes the widget's onChanged callback instead of exercising the
      // async rejection path this test means to cover.
      when(() => categoryRepo.peekNextSequence('0007'))
          .thenAnswer((_) async => throw Exception('offline'));
      await pumpCreateScreen(tester, categories: [_codedCategory]);

      await selectCategory(tester, _codedCategory.name);
      await tester.pumpAndSettle();

      expect(skuField(tester).controller!.text, isEmpty);
      // Not the no-code hint: _codedCategory genuinely has a code ('0007'—
      // the peek is what failed), so telling the admin "this category has
      // no code" would be false and would send them hunting for a
      // miscoded category that doesn't exist.
      expect(
        find.text("Couldn't reach the server — try again, or turn off "
            'auto-generate and type a SKU.'),
        findsOneWidget,
      );
      expect(
        find.text('This category has no code — pick another, or turn off '
            'auto-generate and type a SKU.'),
        findsNothing,
      );
    });

    testWidgets('no regenerate button while auto-generate is on',
        (tester) async {
      await pumpCreateScreen(tester, categories: [_codedCategory]);

      expect(find.byIcon(LucideIcons.refreshCw), findsNothing);
    });
  });
}
