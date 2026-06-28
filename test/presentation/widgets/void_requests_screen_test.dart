import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/void_request_entity.dart';
import 'package:maki_mobile_pos/presentation/providers/void_request_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/sales/void_requests_screen.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

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
        voidRequestsProvider.overrideWith((ref) => Stream.value(list)),
      ],
      child: const MaterialApp(home: VoidRequestsScreen()),
    );

void main() {
  testWidgets('renders AppCard rows with status pills + pending count caption',
      (tester) async {
    await tester.pumpWidget(_harness([
      _req(
          id: '1',
          saleNumber: 'SALE-20260627-3',
          total: 980,
          by: 'Juan Dela Cruz',
          reason: 'Wrong item scanned',
          status: VoidRequestStatus.pending,
          read: false,
          at: DateTime(2026, 6, 27, 11, 48)),
      _req(
          id: '2',
          saleNumber: 'SALE-20260627-1',
          total: 1540,
          by: 'Maria Santos',
          reason: 'Customer changed mind',
          status: VoidRequestStatus.pending,
          read: false,
          at: DateTime(2026, 6, 27, 9, 12)),
      _req(
          id: '3',
          saleNumber: 'SALE-20260626-8',
          total: 430,
          by: 'Juan Dela Cruz',
          reason: 'Duplicate charge',
          status: VoidRequestStatus.approved,
          read: true,
          at: DateTime(2026, 6, 26, 17, 30)),
      _req(
          id: '4',
          saleNumber: 'SALE-20260626-2',
          total: 2100,
          by: 'Maria Santos',
          reason: 'Test transaction',
          status: VoidRequestStatus.rejected,
          read: true,
          at: DateTime(2026, 6, 26, 10, 5)),
    ]));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AppCard), findsNWidgets(4));
    expect(find.text('Pending'), findsNWidgets(2));
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.textContaining('2 pending'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await tester.pumpWidget(_harness([]));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('No void requests'), findsOneWidget);
  });
}
