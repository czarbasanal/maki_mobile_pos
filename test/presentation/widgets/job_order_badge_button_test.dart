import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/draft_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/widgets/pos/job_order_badge_button.dart';

void main() {
  DraftEntity draft(String id) => DraftEntity(
        id: id,
        name: 'Plate $id',
        items: const [],
        createdBy: 'u-1',
        createdByName: 'User',
        createdAt: DateTime(2026, 7, 1, 9),
      );

  Future<void> pump(
    WidgetTester tester, {
    required Stream<List<DraftEntity>> drafts,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeDraftsProvider.overrideWith((ref) => drafts),
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
    await pump(tester, drafts: Stream.value([draft('a'), draft('b')]));
    await tester.pump();
    expect(find.byIcon(LucideIcons.clipboardList), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows no count pill when there are no open job orders',
      (tester) async {
    await pump(tester, drafts: Stream.value(const []));
    await tester.pump();
    expect(find.byIcon(LucideIcons.clipboardList), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('keeps the clipboard icon while the stream is still loading',
      (tester) async {
    final controller = StreamController<List<DraftEntity>>();
    addTearDown(controller.close);
    await pump(tester, drafts: controller.stream);
    expect(find.byIcon(LucideIcons.clipboardList), findsOneWidget);
  });
}
