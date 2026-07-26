import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/repositories/void_request_repository.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/sales/void_requests_screen.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/reports/date_range_picker.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/void_request_provider.dart';

/// Hand-written fake over an in-memory list, mirroring the pattern in
/// test/presentation/providers/void_request_paging_provider_test.dart — only
/// the methods the screen's providers call are implemented; everything else
/// throws so an accidental call fails loudly instead of silently no-oping.
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

VoidRequestEntity _req(
  String id, {
  DateTime? createdAt,
  VoidRequestStatus status = VoidRequestStatus.pending,
}) =>
    VoidRequestEntity(
      id: id,
      saleId: 'sale-$id',
      saleNumber: 'SALE-$id',
      saleGrandTotal: 100,
      requestedBy: 'u-cashier',
      requestedByName: 'cashier user',
      requestedByRole: 'cashier',
      reason: 'wrong item',
      status: status,
      createdAt: createdAt ?? DateTime.now(),
    );

Widget _harness(List<VoidRequestEntity> seed) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
        voidRequestRepositoryProvider
            .overrideWithValue(_FakeVoidRequestRepository(seed)),
      ],
      child: const MaterialApp(home: VoidRequestsScreen()),
    );

void main() {
  testWidgets('shows the date filter (Today) and status cards with counts',
      (tester) async {
    final now = DateTime.now();
    final seed = [
      _req('p1', createdAt: now.subtract(const Duration(minutes: 1))),
      _req('p2', createdAt: now.subtract(const Duration(minutes: 2))),
      _req('a1',
          createdAt: now.subtract(const Duration(minutes: 3)),
          status: VoidRequestStatus.approved),
      _req('r1',
          createdAt: now.subtract(const Duration(minutes: 4)),
          status: VoidRequestStatus.rejected),
    ];
    await tester.pumpWidget(_harness(seed));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    // Card label + one status pill per pending tile (2 pending tiles).
    expect(find.text('Pending'), findsNWidgets(3));
    expect(find.text('2'), findsOneWidget);
    // Card label + one status pill for the single approved/rejected tile.
    expect(find.text('Approved'), findsNWidgets(2));
    expect(find.text('Rejected'), findsNWidgets(2));
    // Two "1" counts (approved + rejected).
    expect(find.text('1'), findsNWidgets(2));
    expect(find.textContaining('SALE-'), findsNWidgets(4));
  });

  testWidgets('tapping the Pending card narrows the list to pending only',
      (tester) async {
    final now = DateTime.now();
    final seed = [
      _req('p1', createdAt: now.subtract(const Duration(minutes: 1))),
      _req('a1',
          createdAt: now.subtract(const Duration(minutes: 2)),
          status: VoidRequestStatus.approved),
    ];
    await tester.pumpWidget(_harness(seed));
    await tester.pumpAndSettle();

    expect(find.textContaining('SALE-'), findsNWidgets(2));

    // `.first` — the summary card's 'Pending' label is built before the
    // tile's status pill (also labelled 'Pending'), so it wins the tree
    // pre-order the finder walks.
    await tester.tap(find.text('Pending').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('SALE-'), findsOneWidget);
    expect(find.text('SALE-p1'), findsOneWidget);
  });

  testWidgets('21-item fake shows Load more; tapping appends the 21st item',
      (tester) async {
    // Tall viewport so all list tiles are within the build/paint cache
    // extent — a plain ListView only mounts children near the viewport, and
    // the default test window is too short to fit 20+ request tiles.
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final seed = List.generate(
      21,
      (i) => _req('r$i', createdAt: now.subtract(Duration(minutes: i))),
    );
    await tester.pumpWidget(_harness(seed));
    await tester.pumpAndSettle();

    expect(find.textContaining('SALE-'), findsNWidgets(20));
    expect(find.widgetWithText(OutlinedButton, 'Load more'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Load more'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SALE-'), findsNWidgets(21));
    expect(find.widgetWithText(OutlinedButton, 'Load more'), findsNothing);
  });

  testWidgets(
      'the old full stream no longer drives the list body',
      (tester) async {
    final now = DateTime.now();
    final seed = [
      _req('p1', createdAt: now.subtract(const Duration(minutes: 1))),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(_admin())),
          voidRequestRepositoryProvider
              .overrideWithValue(_FakeVoidRequestRepository(seed)),
          // The old full-stream provider is overridden to an EMPTY list. If
          // the screen still drove its body from this stream, the tile and
          // cards would show nothing; the paged provider (backed by the
          // repository fake above) still has the one seeded request.
          voidRequestsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(home: VoidRequestsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('SALE-'), findsOneWidget);
    expect(find.text('SALE-p1'), findsOneWidget);
  });

  testWidgets(
      'custom date range handler normalizes end to end-of-day and sets preset',
      (tester) async {
    final now = DateTime.now();
    final seed = [
      _req('p1', createdAt: now.subtract(const Duration(minutes: 1))),
    ];
    await tester.pumpWidget(_harness(seed));
    await tester.pumpAndSettle();

    // Grab the DateRangePicker widget and invoke its callback.
    final pickerWidget =
        tester.widget<DateRangePicker>(find.byType(DateRangePicker));
    pickerWidget.onCustomRangeSelected(
        DateTime(2026, 7, 20), DateTime(2026, 7, 22));
    await tester.pumpAndSettle();

    // Access the provider container from the ProviderScope.
    final container = ProviderScope.containerOf(
        tester.element(find.byType(VoidRequestsScreen)));

    // Assert the date range end is normalized to 23:59:59.999 and start is preserved.
    final range = container.read(voidRequestDateRangeProvider);
    expect(range.start, DateTime(2026, 7, 20));
    expect(range.end, DateTime(2026, 7, 22, 23, 59, 59, 999));

    // Assert the preset is set to custom.
    final preset = container.read(voidRequestDatePresetProvider);
    expect(preset, DateRangePreset.custom);
  });
}
