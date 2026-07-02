import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/providers/draft_provider.dart';

void main() {
  DraftEntity draft(String id) => DraftEntity(
        id: id,
        name: 'Plate $id',
        items: const [
          SaleItemEntity(
            id: 'i-1',
            productId: 'p-1',
            sku: 'SKU-1',
            name: 'Widget',
            unitPrice: 100,
            unitCost: 60,
            quantity: 1,
          ),
        ],
        createdBy: 'u-1',
        createdByName: 'User',
        createdAt: DateTime(2026, 7, 1, 9),
      );

  test('badge count is derived live from the active-drafts stream', () async {
    final controller = StreamController<List<DraftEntity>>();
    final container = ProviderContainer(
      overrides: [
        activeDraftsProvider.overrideWith((ref) => controller.stream),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(controller.close);

    // Subscribe up front (like the POS badge) so the provider is created
    // and listening before the first stream emission.
    container.listen(activeDraftCountProvider, (_, __) {});

    controller.add([draft('a'), draft('b')]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(activeDraftCountProvider).value, 2);

    // A ticket is billed out: the stream emits the shorter list and the
    // badge count must follow with no explicit invalidate.
    controller.add([draft('a')]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(activeDraftCountProvider).value, 1);
  });

  test('badge count reports loading until the stream emits', () {
    final container = ProviderContainer(
      overrides: [
        activeDraftsProvider.overrideWith(
          (ref) => const Stream<List<DraftEntity>>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(activeDraftCountProvider).isLoading, isTrue);
  });
}
