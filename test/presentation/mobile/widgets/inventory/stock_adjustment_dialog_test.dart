// Manual stock corrections are exactly what an audit trail exists for, and
// this dialog wrote nothing to user_logs — the same correction made on the
// web admin was logged. The dialog is the right layer to log from: the repo's
// updateStock is also called by void-restores, which must not double-log.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/stock_adjustment_dialog.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

class _MockProductRepository extends Mock implements ProductRepository {}

class _MockActivityLogRepository extends Mock
    implements ActivityLogRepository {}

class _FakeActivityLog extends Fake implements ActivityLogEntity {}

UserEntity _admin() => UserEntity(
      id: 'admin-1',
      email: 'a@test',
      displayName: 'Admin User',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

ProductEntity _product({int quantity = 8}) => ProductEntity(
      id: 'p1',
      sku: 'ABC123',
      name: 'Brake shoe',
      costCode: 'NBF',
      cost: 170,
      price: 250,
      quantity: quantity,
      reorderLevel: 3,
      unit: 'set',
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivityLog());
  });

  late _MockProductRepository productRepo;
  late _MockActivityLogRepository logRepo;

  Future<void> pumpDialog(WidgetTester tester) async {
    productRepo = _MockProductRepository();
    logRepo = _MockActivityLogRepository();
    when(() => logRepo.logActivity(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ActivityLogEntity);
    when(() => productRepo.updateStock(
          productId: any(named: 'productId'),
          quantityChange: any(named: 'quantityChange'),
          updatedBy: any(named: 'updatedBy'),
          updatedByName: any(named: 'updatedByName'),
        )).thenAnswer((_) async => _product(quantity: 13));
    // Invalidated after a successful adjustment; the rebuilt provider watches
    // this stream, so the mock must answer it.
    when(() => productRepo.watchLowStockProducts())
        .thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
          productRepositoryProvider.overrideWithValue(productRepo),
          activityLoggerProvider
              .overrideWithValue(ActivityLogger(logRepo)),
        ],
        child: MaterialApp(
          home: Scaffold(body: StockAdjustmentDialog(product: _product())),
        ),
      ),
    );
    // Warm the auth stream: the dialog reads currentUserProvider only at tap
    // time (ref.read), and an unwatched StreamProvider is still loading then.
    // In the real app the shell watches it long before any dialog opens.
    final container = ProviderScope.containerOf(
        tester.element(find.byType(StockAdjustmentDialog)));
    container.listen(currentUserProvider, (_, __) {});
    await tester.pumpAndSettle();
  }

  testWidgets('applying an adjustment writes a stock_adjustment log entry',
      (tester) async {
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField).first, '5');
    await tester.enterText(find.byType(TextField).last, 'Damaged items');
    await tester.tap(find.text('Apply Adjustment'));
    await tester.pumpAndSettle();

    final logged = verify(() => logRepo.logActivity(captureAny()))
        .captured
        .cast<ActivityLogEntity>()
        .where((e) => e.type == ActivityType.stockAdjustment)
        .toList();
    expect(logged, hasLength(1));
    expect(logged.single.action, contains('Brake shoe'));
    // 8 + 5 = 13 — the entry records the movement, not just that one happened.
    expect(logged.single.details, contains('8 → 13'));
    expect(logged.single.entityId, 'p1');
  });

  testWidgets('the typed reason ends up in the log instead of being discarded',
      (tester) async {
    // The dialog has always ASKED for a reason and then thrown it away — the
    // log entry is where it belongs.
    await pumpDialog(tester);

    await tester.enterText(find.byType(TextField).first, '5');
    await tester.enterText(find.byType(TextField).last, 'Damaged items');
    await tester.tap(find.text('Apply Adjustment'));
    await tester.pumpAndSettle();

    final logged = verify(() => logRepo.logActivity(captureAny()))
        .captured
        .cast<ActivityLogEntity>()
        .where((e) => e.type == ActivityType.stockAdjustment)
        .toList();
    expect(logged.single.details, contains('Damaged items'));
  });
}
