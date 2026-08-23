import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/data/repositories/job_order_repository_impl.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/job_orders/job_order_edit_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/product_search_field.dart';

/// Firestore-free stand-in: the JO use-cases now write activity logs, and the
/// real activityLoggerProvider chain reaches FirebaseService.
class _NoopActivityLogRepository extends Fake implements ActivityLogRepository {
  @override
  Future<ActivityLogEntity> logActivity(ActivityLogEntity log) async => log;
}

void main() {
  UserEntity admin() => UserEntity(
        id: 'admin-1',
        email: 'a@x.com',
        displayName: 'Admin',
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 7, 1),
      );

  JobOrderEntity buildJobOrder() => JobOrderEntity(
        id: 'jobOrder-1',
        name: 'Plate ABC-123',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 1,
          ),
        ],
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30),
      );

  Widget harness(JobOrderEntity jobOrder) => ProviderScope(
        overrides: [
          jobOrderByIdProvider('jobOrder-1')
              .overrideWith((ref) async => jobOrder),
          activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
          currentUserProvider.overrideWith((ref) => Stream.value(admin())),
          jobOrderRepositoryProvider.overrideWithValue(
            JobOrderRepositoryImpl(firestore: FakeFirebaseFirestore()),
          ),
          activityLoggerProvider
              .overrideWithValue(ActivityLogger(_NoopActivityLogRepository())),
          unsettledBusinessDayProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
            home: JobOrderEditScreen(jobOrderId: 'jobOrder-1')),
      );

  testWidgets('editor has Add parts and no longer has Edit in POS',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(buildJobOrder()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Add parts'), findsOneWidget);
    expect(find.text('Edit in POS'), findsNothing);
  });

  testWidgets('tapping Add parts opens the product-search sheet',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(buildJobOrder()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Add parts'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductSearchField), findsOneWidget);

    // Sheet closes via the X in its upper-right corner (no Done button).
    expect(find.text('Done'), findsNothing);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductSearchField), findsNothing);
  });
}
