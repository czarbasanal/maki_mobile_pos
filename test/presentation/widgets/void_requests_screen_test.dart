import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/void_request_provider.dart';
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
}
