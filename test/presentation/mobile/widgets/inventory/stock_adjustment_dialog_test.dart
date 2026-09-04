// Audit-grade stock adjustment (spec 2026-09-04): preview strip, three mode
// chips (Set to admin-only), a stepper-driven quantity field, a REQUIRED
// reason chip, and a note that's required when the reason demands one. The
// write goes through ProductRepository.adjustStockAudited (optimistic-
// concurrency guarded by expectedOnHand) and every apply logs the real
// reason/note — this dialog used to ask for a reason and throw it away.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/core/errors/exceptions.dart';
import 'package:maki_mobile_pos/core/utils/stock_adjustment.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/activity_log_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/inventory/stock_adjustment_dialog.dart';
import 'package:maki_mobile_pos/presentation/providers/adjustment_reason_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/services/activity_logger.dart';

/// One captured call to [ProductRepository.adjustStockAudited].
class _AdjustCall {
  _AdjustCall({
    required this.productId,
    required this.mode,
    required this.quantity,
    required this.expectedOnHand,
    required this.reasonId,
    required this.reasonName,
    required this.note,
    required this.updatedBy,
    required this.updatedByName,
  });

  final String productId;
  final AdjustmentMode mode;
  final int quantity;
  final int expectedOnHand;
  final String reasonId;
  final String reasonName;
  final String? note;
  final String updatedBy;
  final String? updatedByName;
}

/// Records every `adjustStockAudited` call. Everything else routes through
/// `noSuchMethod` — the dialog under test never touches it.
class _RecordingProductRepository implements ProductRepository {
  final calls = <_AdjustCall>[];

  /// When set, the next call throws this instead of returning a result.
  Object? nextError;

  @override
  Future<AdjustmentResult> adjustStockAudited({
    required String productId,
    required AdjustmentMode mode,
    required int quantity,
    required int expectedOnHand,
    required String reasonId,
    required String reasonName,
    String? note,
    required String updatedBy,
    String? updatedByName,
  }) async {
    calls.add(_AdjustCall(
      productId: productId,
      mode: mode,
      quantity: quantity,
      expectedOnHand: expectedOnHand,
      reasonId: reasonId,
      reasonName: reasonName,
      note: note,
      updatedBy: updatedBy,
      updatedByName: updatedByName,
    ));
    final error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    return resolveAdjustment(mode, expectedOnHand, quantity);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Records every logged activity. Everything else is unused by the dialog.
class _RecordingActivityLogRepository implements ActivityLogRepository {
  final logs = <ActivityLogEntity>[];

  @override
  Future<ActivityLogEntity> logActivity(ActivityLogEntity log) async {
    logs.add(log);
    return log;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

UserEntity _user({required UserRole role, String name = 'Rico Cruz'}) =>
    UserEntity(
      id: 'u-${role.value}',
      email: '${role.value}@test.com',
      displayName: name,
      role: role,
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

AdjustmentReasonEntity _reason(
  String id,
  String name, {
  bool requiresNote = false,
}) =>
    AdjustmentReasonEntity(
      id: id,
      name: name,
      requiresNote: requiresNote,
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late _RecordingProductRepository productRepo;
  late _RecordingActivityLogRepository logRepo;
  late Future<bool?> result;

  Future<void> pumpDialog(
    WidgetTester tester, {
    required UserEntity user,
    List<AdjustmentReasonEntity> reasons = const [],
    ProductEntity? product,
    int seedCallCount = 0,
  }) async {
    productRepo = _RecordingProductRepository();
    logRepo = _RecordingActivityLogRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(user)),
          productRepositoryProvider.overrideWithValue(productRepo),
          activityLoggerProvider.overrideWithValue(ActivityLogger(logRepo)),
          activeAdjustmentReasonsProvider
              .overrideWith((ref) => Stream.value(reasons)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () {
                  result = StockAdjustmentDialog.show(
                    context: context,
                    product: product ?? _product(),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> enterQuantity(WidgetTester tester, String value) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Enter quantity').hitTestable(),
      value,
    );
    await tester.pump();
  }

  group('preview strip + apply', () {
    testWidgets(
        'applying an add writes adjustStockAudited with expectedOnHand and logs the reason',
        (tester) async {
      final admin = _user(role: UserRole.admin);
      await pumpDialog(
        tester,
        user: admin,
        reasons: [_reason('r1', 'Damaged'), _reason('r2', 'Recount')],
        product: _product(quantity: 8),
      );

      await enterQuantity(tester, '5');
      await tester.tap(find.text('Damaged'));
      await tester.pump();

      expect(find.text('13'), findsOneWidget); // preview: new quantity
      expect(find.text('+5'), findsOneWidget); // delta chip

      await tester.tap(find.text('Apply adjustment'));
      await tester.pumpAndSettle();

      expect(productRepo.calls, hasLength(1));
      final call = productRepo.calls.single;
      expect(call.productId, 'p1');
      expect(call.mode, AdjustmentMode.add);
      expect(call.quantity, 5);
      expect(call.expectedOnHand, 8);
      expect(call.reasonId, 'r1');
      expect(call.reasonName, 'Damaged');
      expect(call.updatedBy, admin.id);
      expect(call.updatedByName, admin.displayName);

      final logged = logRepo.logs
          .where((e) => e.type == ActivityType.stockAdjustment)
          .toList();
      expect(logged, hasLength(1));
      expect(logged.single.metadata?['reasonName'], 'Damaged');
      expect(logged.single.metadata?['oldQuantity'], 8);
      expect(logged.single.metadata?['newQuantity'], 13);

      expect(await result, isTrue);
      expect(find.textContaining('Stock adjusted · +5 → 13 set'),
          findsOneWidget);
    });

    testWidgets('the typed note ends up in the log', (tester) async {
      await pumpDialog(
        tester,
        user: _user(role: UserRole.admin),
        reasons: [_reason('r1', 'Damaged')],
      );

      await enterQuantity(tester, '5');
      await tester.tap(find.text('Damaged'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, 'Fell off shelf');
      await tester.tap(find.text('Apply adjustment'));
      await tester.pumpAndSettle();

      expect(productRepo.calls.single.note, 'Fell off shelf');
      expect(logRepo.logs.single.metadata?['note'], 'Fell off shelf');
    });

    testWidgets('delta chip reads negative for a Remove', (tester) async {
      await pumpDialog(
        tester,
        user: _user(role: UserRole.admin),
        reasons: [_reason('r1', 'Damaged')],
        product: _product(quantity: 8),
      );

      await tester.tap(find.text('Remove'));
      await tester.pump();
      await enterQuantity(tester, '3');

      expect(find.text('-3'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // 8 - 3
    });

    testWidgets('the +/- steppers adjust the quantity field and floor at 0',
        (tester) async {
      await pumpDialog(
        tester,
        user: _user(role: UserRole.admin),
        reasons: [_reason('r1', 'Damaged')],
      );

      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pump();
      expect(find.text('2'), findsWidgets);

      await tester.tap(find.byIcon(LucideIcons.minus));
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.minus));
      await tester.pump();
      await tester.tap(find.byIcon(LucideIcons.minus));
      await tester.pump();
      // Floors at 0 — never goes negative.
      expect(
        tester
            .widget<TextField>(find.byType(TextField).first)
            .controller!
            .text,
        '0',
      );
    });
  });

  group('role gating', () {
    testWidgets('staff sees only Add / Remove, no Set to chip',
        (tester) async {
      await pumpDialog(tester, user: _user(role: UserRole.staff));

      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      expect(find.text('Set to'), findsNothing);
    });

    testWidgets('admin sees Set to, and picking it relabels the quantity field',
        (tester) async {
      await pumpDialog(tester, user: _user(role: UserRole.admin));

      expect(find.text('Set to'), findsOneWidget);
      expect(find.text('Quantity'), findsWidgets);
      expect(find.text('Counted quantity'), findsNothing);

      await tester.tap(find.text('Set to'));
      await tester.pump();

      expect(find.text('Counted quantity'), findsWidgets);
    });
  });

  group('apply gating', () {
    testWidgets('Apply is disabled with no quantity or reason entered',
        (tester) async {
      await pumpDialog(
        tester,
        user: _user(role: UserRole.admin),
        reasons: [_reason('r1', 'Damaged')],
      );

      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Apply adjustment'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('Apply stays disabled until a note is entered for a reason that requires one',
        (tester) async {
      await pumpDialog(
        tester,
        user: _user(role: UserRole.admin),
        reasons: [_reason('r1', 'Recount', requiresNote: true)],
      );

      await enterQuantity(tester, '5');
      await tester.tap(find.text('Recount'));
      await tester.pump();

      var button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Apply adjustment'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'Physical recount');
      await tester.pump();

      button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Apply adjustment'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Remove past on-hand keeps Apply disabled', (tester) async {
      await pumpDialog(
        tester,
        user: _user(role: UserRole.admin),
        reasons: [_reason('r1', 'Damaged')],
        product: _product(quantity: 3),
      );

      await tester.tap(find.text('Remove'));
      await tester.pump();
      await enterQuantity(tester, '10');
      await tester.tap(find.text('Damaged'));
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Apply adjustment'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('stale on-hand', () {
    testWidgets(
        'a StaleOnHandException rebases the preview and keeps the typed quantity',
        (tester) async {
      await pumpDialog(
        tester,
        user: _user(role: UserRole.admin),
        reasons: [_reason('r1', 'Damaged')],
        product: _product(quantity: 8),
      );

      productRepo.nextError = const StaleOnHandException(11);

      await enterQuantity(tester, '5');
      await tester.tap(find.text('Damaged'));
      await tester.pump();
      await tester.tap(find.text('Apply adjustment'));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'Someone else moved this stock — on hand is now 11. Review and apply again.'),
        findsOneWidget,
      );
      // Quantity is preserved and on hand is rebased: 11 + 5 = 16.
      expect(find.text('5'), findsWidgets); // still in the quantity field
      expect(find.text('16'), findsOneWidget);
      expect(productRepo.calls, hasLength(1)); // no auto-retry
      expect(logRepo.logs, isEmpty);

      // Retrying now sends the rebased on-hand.
      await tester.tap(find.text('Apply adjustment'));
      await tester.pumpAndSettle();
      expect(productRepo.calls, hasLength(2));
      expect(productRepo.calls.last.expectedOnHand, 11);
    });
  });

  group('reason auto-seed', () {
    testWidgets('an empty active-reasons stream triggers seedDefaults once',
        (tester) async {
      final admin = _user(role: UserRole.admin);
      final seedCalls = <void>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Stream.value(admin)),
            productRepositoryProvider
                .overrideWithValue(_RecordingProductRepository()),
            activityLoggerProvider.overrideWithValue(
                ActivityLogger(_RecordingActivityLogRepository())),
            activeAdjustmentReasonsProvider
                .overrideWith((ref) => Stream.value(const [])),
            adjustmentReasonOperationsProvider.overrideWith((ref) {
              return _RecordingSeedNotifier(ref, seedCalls);
            }),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => StockAdjustmentDialog.show(
                    context: context,
                    product: _product(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(seedCalls, hasLength(1));
    });
  });

  group('cache invalidation', () {
    testWidgets(
        'a successful apply invalidates productByIdProvider and lowStockProductsProvider',
        (tester) async {
      final admin = _user(role: UserRole.admin);
      final repo = _RecordingProductRepository();
      final logs = _RecordingActivityLogRepository();
      var productByIdCalls = 0;
      var lowStockCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Stream.value(admin)),
            productRepositoryProvider.overrideWithValue(repo),
            activityLoggerProvider.overrideWithValue(ActivityLogger(logs)),
            activeAdjustmentReasonsProvider
                .overrideWith((ref) => Stream.value([_reason('r1', 'Damaged')])),
            // Counting fakes stand in for the real streams so an
            // `ref.invalidate` can be observed as a second creation.
            productByIdProvider.overrideWith((ref, id) async {
              productByIdCalls++;
              return null;
            }),
            lowStockProductsProvider.overrideWith((ref) {
              lowStockCalls++;
              return const Stream<List<ProductEntity>>.empty();
            }),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => StockAdjustmentDialog.show(
                    context: context,
                    product: _product(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Keep both providers alive — like a screen elsewhere in the app
      // watching this product / the low-stock list — so an invalidate is
      // observable as a fresh call instead of silently going unread.
      final container =
          ProviderScope.containerOf(tester.element(find.text('open')));
      container.listen(productByIdProvider('p1'), (_, __) {});
      container.listen(lowStockProductsProvider, (_, __) {});
      await tester.pump();
      expect(productByIdCalls, 1);
      expect(lowStockCalls, 1);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter quantity').hitTestable(),
        '5',
      );
      await tester.pump();
      await tester.tap(find.text('Damaged'));
      await tester.pump();
      await tester.tap(find.text('Apply adjustment'));
      await tester.pumpAndSettle();

      expect(productByIdCalls, 2);
      expect(lowStockCalls, 2);
    });
  });

  group('footer', () {
    testWidgets('shows the acting user display name', (tester) async {
      await pumpDialog(
        tester,
        user: _user(role: UserRole.admin, name: 'Rico Cruz'),
      );

      expect(find.textContaining('Recorded against Rico Cruz'), findsOneWidget);
    });
  });
}

class _RecordingSeedNotifier extends AdjustmentReasonOperationsNotifier {
  _RecordingSeedNotifier(super.ref, this.seedCalls);
  final List<void> seedCalls;

  @override
  Future<bool> seedDefaults() async {
    seedCalls.add(null);
    return true;
  }
}
