import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/app_colors.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/job_order_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/job_order_badge_button.dart';

void main() {
  JobOrderEntity jobOrder(String id) => JobOrderEntity(
        id: id,
        name: 'Plate $id',
        items: const [],
        createdBy: 'u-1',
        createdByName: 'User',
        createdAt: DateTime(2026, 7, 1, 9),
      );

  Future<void> pump(
    WidgetTester tester, {
    required Stream<List<JobOrderEntity>> jobOrders,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeJobOrdersProvider.overrideWith((ref) => jobOrders),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [JobOrderBadgeButton(onPressed: () {})],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows clipboard icon with the open job-order count',
      (tester) async {
    await pump(tester, jobOrders: Stream.value([jobOrder('a'), jobOrder('b')]));
    await tester.pump();
    expect(find.byIcon(LucideIcons.clipboardList), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('count pill is red with a white number', (tester) async {
    await pump(tester, jobOrders: Stream.value([jobOrder('a')]));
    await tester.pump();

    final pill = tester.widget<Container>(
      find.ancestor(of: find.text('1'), matching: find.byType(Container)),
    );
    expect((pill.decoration as BoxDecoration?)?.color, AppColors.error);
    expect(tester.widget<Text>(find.text('1')).style?.color, Colors.white);
  });

  testWidgets('shows no count pill when there are no open job orders',
      (tester) async {
    await pump(tester, jobOrders: Stream.value(const []));
    await tester.pump();
    expect(find.byIcon(LucideIcons.clipboardList), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('keeps the clipboard icon while the stream is still loading',
      (tester) async {
    final controller = StreamController<List<JobOrderEntity>>();
    addTearDown(controller.close);
    await pump(tester, jobOrders: controller.stream);
    expect(find.byIcon(LucideIcons.clipboardList), findsOneWidget);
  });
}
