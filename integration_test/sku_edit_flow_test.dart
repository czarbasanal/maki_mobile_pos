// End-to-end flow test for the admin SKU-edit feature.
//
// Runs the real ProductFormScreen inside a GoRouter (so the post-save
// navigation works), drives the full happy path — edit SKU, confirm the
// dialog, save — and asserts the product is written with the new SKU and the
// old SKU preserved as a scan alias.
//
// Backend providers are overridden with in-memory fakes so the flow is
// deterministic and needs neither Firebase nor a network. This is the
// recommended way to write fast, reliable integration tests; see README.md in
// this directory for how to grow it into a full emulator-backed e2e suite that
// drives the live app from the login screen.
//
// Run headless:        flutter test integration_test/sku_edit_flow_test.dart
// Run on a device:     flutter test integration_test/ -d <device-id>

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:maki_mobile_pos/config/router/router.dart';
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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeProductEntity());
    registerFallbackValue(_FakeActivityLogEntity());
  });

  late _MockProductRepository repo;
  late _MockActivityLogRepository logRepo;

  final product = ProductEntity(
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

    when(() => repo.getProductById('p-1')).thenAnswer((_) async => product);
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
    // After a save the form invalidates the product list providers, which
    // re-subscribe to these streams — stub them so the (unstubbed-by-default)
    // mock doesn't throw during the post-save refresh.
    when(() => repo.watchProducts())
        .thenAnswer((_) => Stream.value(<ProductEntity>[]));
    when(() => repo.watchLowStockProducts())
        .thenAnswer((_) => Stream.value(<ProductEntity>[]));
  });

  testWidgets('admin edits a SKU end-to-end: confirm dialog then save',
      (tester) async {
    final admin = UserEntity(
      id: 'admin-1',
      email: 'admin@test',
      displayName: 'Admin',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2024, 1, 1),
    );

    // GoRouter so the form's post-save `goBackOr(inventory)` has somewhere to
    // go; the form is the initial page and inventory is a stub destination.
    final router = GoRouter(
      initialLocation: '/edit',
      routes: [
        GoRoute(
          path: '/edit',
          builder: (_, __) => const ProductFormScreen(productId: 'p-1'),
        ),
        GoRoute(
          path: RoutePaths.inventory,
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('inventory'))),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(admin)),
          productRepositoryProvider.overrideWith((ref) => repo),
          activityLogRepositoryProvider.overrideWith((ref) => logRepo),
          costCodeMappingProvider
              .overrideWith((ref) => CostCodeEntity.defaultMapping()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // The form loaded the product; the SKU field is editable for an admin.
    final skuField = find.byKey(const Key('product-sku-field'));
    expect(skuField, findsOneWidget);
    expect(tester.widget<TextFormField>(skuField).enabled, isTrue);

    // Change the SKU and submit.
    await tester.enterText(skuField, 'SKU-NEW');
    await tester.pump();
    // Dismiss the keyboard and scroll the submit button fully into view so the
    // tap lands reliably across device sizes — on a real device `ensureVisible`
    // can leave the button at the screen edge / under the keyboard.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Update Product'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Product'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The confirmation dialog appears and nothing is written yet.
    expect(find.text('Change SKU?'), findsOneWidget);
    expect(find.text('SKU-001  →  SKU-NEW'), findsOneWidget);
    verifyNever(() => repo.updateProduct(
          product: any(named: 'product'),
          updatedBy: any(named: 'updatedBy'),
          updatedByName: any(named: 'updatedByName'),
        ));

    // Confirm -> the product is saved and we navigate to inventory.
    await tester.tap(find.text('Change SKU'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final captured = verify(() => repo.updateProduct(
          product: captureAny(named: 'product'),
          updatedBy: 'admin-1',
          updatedByName: 'Admin',
        )).captured;
    final saved = captured.single as ProductEntity;
    expect(saved.sku, 'SKU-NEW');
    // Old SKU kept as a scan alias.
    expect(saved.barcodes, contains('SKU-001'));

    // Settle the post-save navigation + snackbar animation.
    await tester.pumpAndSettle();
    expect(find.text('inventory'), findsOneWidget);
  });
}
