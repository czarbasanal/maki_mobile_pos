import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/enums/enums.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/auth_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/receiving/receiving_screen.dart';

ReceivingItemEntity _item(String id, int qty) => ReceivingItemEntity(
      id: id,
      sku: 'SKU-$id',
      name: 'Item $id',
      quantity: qty,
      unit: 'pcs',
      unitCost: 10,
      costCode: 'AB',
    );

// 3 lines, 12 pieces — so "12" can never be mistaken for a line count.
ReceivingEntity _receiving() => ReceivingEntity(
      id: 'r1',
      referenceNumber: 'RCV-20260805-001',
      items: [_item('a', 5), _item('b', 4), _item('c', 3)],
      totalCost: 120,
      totalQuantity: 12,
      status: ReceivingStatus.completed,
      createdAt: DateTime(2026, 8, 5),
      createdBy: 'u1',
      createdByName: 'Admin',
    );

final _admin = UserEntity(
  id: 'u1',
  email: 'a@test',
  displayName: 'Alice Admin',
  role: UserRole.admin,
  isActive: true,
  createdAt: DateTime(2024, 1, 1),
);

void main() {
  testWidgets('labels the quantity sum "units", not "items"', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        // currentWeekReceivingsProvider is a plain Provider<AsyncValue<...>>
        // derived from recentReceivingsProvider (not a StreamProvider),
        // so it's overridden with an AsyncValue directly.
        currentWeekReceivingsProvider
            .overrideWith((ref) => AsyncValue.data([_receiving()])),
        currentUserProvider.overrideWith((ref) => Stream.value(_admin)),
        // ReceivingScreen also composes ReceivingSummaryCardsRow, which watches
        // receivingCountsProvider and monthToDateReceivingTotalProvider — both
        // derive from the real recentReceivingsProvider, which reaches
        // Firestore. Without this override that chain throws (no Firebase app
        // in tests); the row swallows it into an error banner, so the failure
        // is silent rather than loud. Overriding recentReceivingsProvider here
        // isolates it deliberately instead of relying on that swallow.
        recentReceivingsProvider
            .overrideWith((ref) => Stream.value([_receiving()])),
      ],
      child: const MaterialApp(home: ReceivingScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('12 units'), findsOneWidget);
    expect(find.textContaining('12 items'), findsNothing);
  });
}
