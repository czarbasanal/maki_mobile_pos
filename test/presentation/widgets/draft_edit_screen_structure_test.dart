import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/drafts/draft_edit_screen.dart';

void main() {
  DraftEntity buildDraft() => DraftEntity(
        id: 'draft-1',
        name: 'JO-072326-001',
        items: const [
          SaleItemEntity(
            id: 'item-1',
            productId: 'prod-1',
            sku: 'SKU-001',
            name: 'Brake Pad',
            unitPrice: 100.0,
            unitCost: 60.0,
            quantity: 2,
          ),
        ],
        createdBy: 'cashier-1',
        createdByName: 'John Doe',
        createdAt: DateTime(2026, 5, 30, 10, 0),
      );

  Widget harness(DraftEntity draft) => ProviderScope(
        overrides: [
          draftByIdProvider('draft-1').overrideWith((ref) async => draft),
          activeMechanicsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(home: DraftEditScreen(draftId: 'draft-1')),
      );

  testWidgets('one scroll region; summary + Bill out pinned outside it',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(harness(buildDraft()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Header, parts and labor all live INSIDE the single scroll region.
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('Parts'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('Labor & Service'),
      ),
      findsOneWidget,
    );
    // The Bill-out footer is pinned OUTSIDE any scrollable.
    expect(find.text('Bill out'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('Bill out'),
      ),
      findsNothing,
    );
    // The parts list no longer scrolls on its own.
    final partsList = tester.widget<ListView>(find.byType(ListView).first);
    expect(partsList.physics, isA<NeverScrollableScrollPhysics>());
  });
}
