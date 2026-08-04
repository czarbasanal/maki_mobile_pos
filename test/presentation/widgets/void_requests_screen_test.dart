import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/sales/void_requests_screen.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Hand-written fake over an in-memory list — same pattern as
/// test/presentation/providers/void_request_paging_provider_test.dart and
/// test/presentation/mobile/screens/sales/void_requests_screen_filter_test.dart.
/// Only the methods the screen's providers call are implemented.
class _FakeVoidRequestRepository implements VoidRequestRepository {
  final List<VoidRequestEntity> all;
  _FakeVoidRequestRepository(this.all);

  @override
  Future<List<VoidRequestEntity>> getRequestsPage({
    VoidRequestStatus? status,
    required DateTime start,
    required DateTime end,
    int limit = 20,
    String? startAfterId,
  }) async {
    var filtered = all.where((r) =>
        (status == null || r.status == status) &&
        !r.createdAt.isBefore(start) &&
        !r.createdAt.isAfter(end)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (startAfterId != null) {
      final idx = filtered.indexWhere((r) => r.id == startAfterId);
      if (idx != -1) {
        filtered = filtered.sublist(idx + 1);
      }
    }
    return filtered.take(limit).toList();
  }

  @override
  Future<int> countByStatus({
    required VoidRequestStatus status,
    required DateTime start,
    required DateTime end,
  }) async {
    return all
        .where((r) =>
            r.status == status &&
            !r.createdAt.isBefore(start) &&
            !r.createdAt.isAfter(end))
        .length;
  }

  @override
  Stream<List<VoidRequestEntity>> watchRequests({int limit = 50}) =>
      Stream.value(all);

  @override
  Future<void> markRead(String requestId) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<VoidRequestEntity> createRequest(VoidRequestEntity request) =>
      throw UnimplementedError();

  @override
  Stream<List<VoidRequestEntity>> watchPendingForSale(String saleId) =>
      throw UnimplementedError();

  @override
  Future<bool> hasPendingForSale(String saleId) => throw UnimplementedError();

  @override
  Future<void> resolve({
    required String requestId,
    required String saleId,
    required VoidRequestStatus status,
    required String resolvedBy,
    required String resolvedByName,
    String? rejectionReason,
  }) =>
      throw UnimplementedError();
}

UserEntity _admin() => UserEntity(
      id: 'u-admin',
      email: 'admin@test.com',
      displayName: 'Admin User',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    );

VoidRequestEntity _req({
  required String id,
  required String saleNumber,
  required double total,
  required String by,
  required String reason,
  required VoidRequestStatus status,
  required bool read,
  required DateTime at,
}) =>
    VoidRequestEntity(
      id: id,
      saleId: 'sale-$id',
      saleNumber: saleNumber,
      saleGrandTotal: total,
      requestedBy: 'u-$id',
      requestedByName: by,
      requestedByRole: 'cashier',
      reason: reason,
      status: status,
      read: read,
      createdAt: at,
    );

Widget _harness(List<VoidRequestEntity> list) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        voidRequestRepositoryProvider
            .overrideWithValue(_FakeVoidRequestRepository(list)),
      ],
      child: const MaterialApp(home: VoidRequestsScreen()),
    );

void main() {
  testWidgets('renders AppCard rows with status pills for today\'s requests',
      (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(_harness([
      _req(
          id: '1',
          saleNumber: 'SALE-20260627-3',
          total: 980,
          by: 'Juan Dela Cruz',
          reason: 'Wrong item scanned',
          status: VoidRequestStatus.pending,
          read: false,
          at: now.subtract(const Duration(minutes: 5))),
      _req(
          id: '2',
          saleNumber: 'SALE-20260627-1',
          total: 1540,
          by: 'Maria Santos',
          reason: 'Customer changed mind',
          status: VoidRequestStatus.pending,
          read: false,
          at: now.subtract(const Duration(minutes: 10))),
      _req(
          id: '3',
          saleNumber: 'SALE-20260626-8',
          total: 430,
          by: 'Juan Dela Cruz',
          reason: 'Duplicate charge',
          status: VoidRequestStatus.approved,
          read: true,
          at: now.subtract(const Duration(minutes: 15))),
      _req(
          id: '4',
          saleNumber: 'SALE-20260626-2',
          total: 2100,
          by: 'Maria Santos',
          reason: 'Test transaction',
          status: VoidRequestStatus.rejected,
          read: true,
          at: now.subtract(const Duration(minutes: 20))),
    ]));
    await tester.pumpAndSettle();

    // 4 request-row tiles + 3 status summary cards = 7 AppCards, plus the two
    // AppCard pills inside DateRangePicker = 9.
    expect(find.byType(AppCard), findsNWidgets(9));
    expect(find.text('Mark all read'), findsOneWidget);
    // Status summary cards show today's counts (all 4 seeded requests fall
    // in the default "today" window).
    expect(find.text('2'), findsOneWidget); // pending count
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(_harness([]));
    await tester.pumpAndSettle();
    expect(find.text('No void requests'), findsOneWidget);
  });

  group('resolve sheet receipt — selling option (found beyond the brief)', () {
    // The tap-to-resolve sheet renders a receipt-style item list
    // (_Receipt/_lineRow) that is a separate render site from
    // ReceiptWidget/receipt_widget.dart — same bug class, found via search.
    SaleEntity saleWith(SaleItemEntity item) => SaleEntity(
          id: 'sale-opt',
          saleNumber: 'SALE-OPT-1',
          items: [item],
          paymentMethod: PaymentMethod.cash,
          amountReceived: 1000,
          changeGiven: 0,
          cashierId: 'cashier-1',
          cashierName: 'Cashier',
          status: SaleStatus.completed,
          createdAt: DateTime(2026, 7, 29, 9, 0),
        );

    Widget harnessWithSale(VoidRequestEntity request, SaleEntity sale) =>
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
            voidRequestRepositoryProvider
                .overrideWithValue(_FakeVoidRequestRepository([request])),
            saleByIdProvider(request.saleId).overrideWith((ref) async => sale),
          ],
          child: const MaterialApp(home: VoidRequestsScreen()),
        );

    testWidgets('shows the option label beside the name for a single set',
        (tester) async {
      final request = _req(
        id: 'opt1',
        saleNumber: 'SALE-OPT-1',
        total: 330,
        by: 'Juan Dela Cruz',
        reason: 'Wrong item scanned',
        status: VoidRequestStatus.pending,
        read: false,
        at: DateTime.now(),
      );
      final sale = saleWith(const SaleItemEntity(
        id: 'item-1',
        productId: 'prod-1',
        sku: 'ABC-1',
        name: 'Pulley Ball',
        unitPrice: 110.0,
        unitCost: 60.0,
        quantity: 3,
        optionId: 'o2',
        optionLabel: 'By 3',
        optionPieces: 3,
        optionPrice: 330.0,
      ));

      await tester.pumpWidget(harnessWithSale(request, sale));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SALE-OPT-1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('By 3'), findsWidgets);
      expect(find.textContaining('× 2'), findsNothing);
    });

    testWidgets('shows the set count and total pieces for more than one set',
        (tester) async {
      final request = _req(
        id: 'opt2',
        saleNumber: 'SALE-OPT-1',
        total: 660,
        by: 'Juan Dela Cruz',
        reason: 'Wrong item scanned',
        status: VoidRequestStatus.pending,
        read: false,
        at: DateTime.now(),
      );
      final sale = saleWith(const SaleItemEntity(
        id: 'item-1',
        productId: 'prod-1',
        sku: 'ABC-1',
        name: 'Pulley Ball',
        unitPrice: 110.0,
        unitCost: 60.0,
        quantity: 6,
        optionId: 'o2',
        optionLabel: 'By 3',
        optionPieces: 3,
        optionPrice: 330.0,
      ));

      await tester.pumpWidget(harnessWithSale(request, sale));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SALE-OPT-1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('By 3 × 2'), findsOneWidget);
      expect(find.textContaining('6 pcs'), findsOneWidget);
    });

    testWidgets('a plain line renders unchanged', (tester) async {
      final request = _req(
        id: 'opt3',
        saleNumber: 'SALE-OPT-1',
        total: 200,
        by: 'Juan Dela Cruz',
        reason: 'Wrong item scanned',
        status: VoidRequestStatus.pending,
        read: false,
        at: DateTime.now(),
      );
      final sale = saleWith(const SaleItemEntity(
        id: 'item-1',
        productId: 'prod-1',
        sku: 'SKU-1',
        name: 'Brake Pad',
        unitPrice: 100.0,
        unitCost: 60.0,
        quantity: 2,
      ));

      await tester.pumpWidget(harnessWithSale(request, sale));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SALE-OPT-1'));
      await tester.pumpAndSettle();

      expect(find.textContaining('By'), findsNothing);
    });

    testWidgets('rate suffix reads the item unit for a non-pcs product',
        (tester) async {
      final request = _req(
        id: 'opt4',
        saleNumber: 'SALE-OPT-1',
        total: 100,
        by: 'Juan Dela Cruz',
        reason: 'Wrong item scanned',
        status: VoidRequestStatus.pending,
        read: false,
        at: DateTime.now(),
      );
      final sale = saleWith(const SaleItemEntity(
        id: 'item-1',
        productId: 'prod-1',
        sku: 'SKU-BOX',
        name: 'Chain Lube',
        unitPrice: 100.0,
        unitCost: 60.0,
        quantity: 1,
        unit: 'box',
      ));

      await tester.pumpWidget(harnessWithSale(request, sale));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SALE-OPT-1'));
      await tester.pumpAndSettle();

      // Discriminator: a hardcoded "/pc" suffix renders this too, so this
      // only passes when the sub-line reads item.unit via the helper.
      expect(find.text('SKU-BOX · ₱100.00/box'), findsOneWidget);
      expect(find.textContaining('/pc'), findsNothing);
    });

    testWidgets('rate suffix stays /pc for a pcs product (regression)',
        (tester) async {
      final request = _req(
        id: 'opt5',
        saleNumber: 'SALE-OPT-1',
        total: 200,
        by: 'Juan Dela Cruz',
        reason: 'Wrong item scanned',
        status: VoidRequestStatus.pending,
        read: false,
        at: DateTime.now(),
      );
      final sale = saleWith(const SaleItemEntity(
        id: 'item-1',
        productId: 'prod-1',
        sku: 'SKU-1',
        name: 'Brake Pad',
        unitPrice: 100.0,
        unitCost: 60.0,
        quantity: 2,
      ));

      await tester.pumpWidget(harnessWithSale(request, sale));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SALE-OPT-1'));
      await tester.pumpAndSettle();

      expect(find.text('SKU-1 · ₱100.00/pc'), findsOneWidget);
    });
  });
}
