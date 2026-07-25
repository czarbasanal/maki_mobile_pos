import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/void_request_entity.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/sales/void_status_summary_cards.dart';

void main() {
  Widget harness({
    required int pending,
    required int approved,
    required int rejected,
    VoidRequestStatus? selected,
    required ValueChanged<VoidRequestStatus?> onSelect,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: VoidStatusSummaryCards(
            pendingCount: pending,
            approvedCount: approved,
            rejectedCount: rejected,
            selected: selected,
            onSelect: onSelect,
          ),
        ),
      );

  testWidgets('renders three cards with labels and counts', (tester) async {
    await tester.pumpWidget(harness(
      pending: 2,
      approved: 5,
      rejected: 1,
      selected: null,
      onSelect: (_) {},
    ));

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('tapping an unselected card fires onSelect with that status',
      (tester) async {
    VoidRequestStatus? fired;
    var called = false;
    await tester.pumpWidget(harness(
      pending: 2,
      approved: 5,
      rejected: 1,
      selected: VoidRequestStatus.pending,
      onSelect: (s) {
        called = true;
        fired = s;
      },
    ));

    await tester.tap(find.text('Approved'));
    await tester.pump();

    expect(called, isTrue);
    expect(fired, VoidRequestStatus.approved);
  });

  testWidgets('tapping the already-selected card fires onSelect(null)',
      (tester) async {
    VoidRequestStatus? fired = VoidRequestStatus.rejected; // sentinel
    var called = false;
    await tester.pumpWidget(harness(
      pending: 2,
      approved: 5,
      rejected: 1,
      selected: VoidRequestStatus.pending,
      onSelect: (s) {
        called = true;
        fired = s;
      },
    ));

    await tester.tap(find.text('Pending'));
    await tester.pump();

    expect(called, isTrue);
    expect(fired, isNull);
  });
}
