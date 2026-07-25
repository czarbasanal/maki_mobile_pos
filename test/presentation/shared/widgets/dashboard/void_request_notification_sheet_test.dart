import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/dashboard/void_request_notification_sheet.dart';

/// Records `markRead` calls instead of hitting the real repository.
class _FakeVoidRequestOps extends VoidRequestOperationsNotifier {
  _FakeVoidRequestOps(super.ref);
  final markedRead = <String>[];

  @override
  Future<void> markRead(String requestId) async {
    markedRead.add(requestId);
  }
}

VoidRequestEntity _request({
  required String id,
  required String requestedByName,
  required bool read,
  required double saleGrandTotal,
  String? itemsSummary,
  VoidRequestStatus status = VoidRequestStatus.pending,
}) =>
    VoidRequestEntity(
      id: id,
      saleId: 'sale-$id',
      saleNumber: 'SO-00$id',
      saleGrandTotal: saleGrandTotal,
      requestedBy: 'u1',
      requestedByName: requestedByName,
      requestedByRole: 'cashier',
      reason: 'Wrong item',
      status: status,
      read: read,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      itemsSummary: itemsSummary,
    );

void main() {
  Future<_FakeVoidRequestOps> pump(
    WidgetTester tester, {
    required List<VoidRequestEntity> requests,
  }) async {
    final container = ProviderContainer(overrides: [
      voidRequestsProvider.overrideWith((ref) => Stream.value(requests)),
      voidRequestOperationsProvider
          .overrideWith((ref) => _FakeVoidRequestOps(ref)),
    ]);
    addTearDown(container.dispose);
    // Read eagerly: the widget tree only touches this provider when an
    // entry is tapped, so a lazy StateNotifierProvider would otherwise
    // never be instantiated for the tests that don't tap.
    final ops = container.read(voidRequestOperationsProvider.notifier)
        as _FakeVoidRequestOps;

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, __) => Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showVoidRequestNotificationSheet(ctx),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: RoutePaths.voidRequests,
          name: RouteNames.voidRequests,
          builder: (_, __) =>
              const Scaffold(body: Text('Void Requests Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return ops;
  }

  testWidgets(
      'lists entries with detail line (sale number, peso total, items summary) '
      'and an unread indicator', (tester) async {
    final unreadReq = _request(
      id: '1',
      requestedByName: 'Belle',
      read: false,
      saleGrandTotal: 450.5,
      itemsSummary: '2× Brake Shoe',
    );
    final readReq = _request(
      id: '2',
      requestedByName: 'Marco',
      read: true,
      saleGrandTotal: 200,
      status: VoidRequestStatus.approved,
    );

    await pump(tester, requests: [unreadReq, readReq]);

    expect(find.text('Belle sent a void request'), findsOneWidget);
    expect(find.text('Marco sent a void request'), findsOneWidget);
    expect(find.textContaining('SO-001'), findsOneWidget);
    expect(find.textContaining('₱450.50'), findsOneWidget);
    expect(find.textContaining('2× Brake Shoe'), findsOneWidget);
    expect(find.textContaining('SO-002'), findsOneWidget);
    expect(find.textContaining('₱200.00'), findsOneWidget);
    // Header unread-count chip reflects the single unread request.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);
  });

  testWidgets('empty state shows No void requests', (tester) async {
    await pump(tester, requests: []);
    expect(find.text('No void requests'), findsOneWidget);
  });

  testWidgets(
      'tapping an unread entry pops the sheet, marks it read, and navigates '
      'to void requests', (tester) async {
    final req = _request(
      id: '1',
      requestedByName: 'Belle',
      read: false,
      saleGrandTotal: 450.5,
    );
    final ops = await pump(tester, requests: [req]);

    await tester.tap(find.text('Belle sent a void request'));
    await tester.pumpAndSettle();

    expect(ops.markedRead, ['1']);
    expect(find.text('Void Requests Screen'), findsOneWidget);
    expect(find.text('Belle sent a void request'), findsNothing);
  });

  testWidgets("'View all' pops the sheet and navigates to void requests",
      (tester) async {
    final req = _request(
      id: '1',
      requestedByName: 'Belle',
      read: false,
      saleGrandTotal: 450.5,
    );
    await pump(tester, requests: [req]);

    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();

    expect(find.text('Void Requests Screen'), findsOneWidget);
  });
}
