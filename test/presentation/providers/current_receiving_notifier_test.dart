import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:maki_mobile_pos/domain/repositories/product_repository.dart';
import 'package:maki_mobile_pos/domain/repositories/receiving_repository.dart';
import 'package:maki_mobile_pos/presentation/providers/product_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';

class _MockReceivingRepository extends Mock implements ReceivingRepository {}

class _MockProductRepository extends Mock implements ProductRepository {}

ReceivingItemEntity _line({
  required String productId,
  required int quantity,
  required double unitCost,
  String? id,
}) {
  return ReceivingItemEntity(
    id: id ?? '',
    productId: productId,
    sku: 'SKU-$productId',
    name: 'Item $productId',
    quantity: quantity,
    unit: 'pcs',
    unitCost: unitCost,
    costCode: 'NBF',
  );
}

void main() {
  late CurrentReceivingNotifier notifier;
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        receivingRepositoryProvider.overrideWith((ref) {
          return _MockReceivingRepository();
        }),
        productRepositoryProvider.overrideWith((ref) {
          return _MockProductRepository();
        }),
      ],
    );
    notifier = container.read(currentReceivingProvider.notifier);
  });

  tearDown(() => container.dispose());

  group('CurrentReceivingNotifier.addItem — duplicate handling', () {
    test('first add appends a line with a fresh id', () {
      notifier.addItem(_line(productId: 'p1', quantity: 2, unitCost: 50));

      final state = container.read(currentReceivingProvider);
      expect(state.items, hasLength(1));
      expect(state.items.first.productId, 'p1');
      expect(state.items.first.quantity, 2);
      expect(state.items.first.id, isNotEmpty);
    });

    test(
        'second add of the same productId + same unitCost merges quantity '
        'into the existing line instead of creating a duplicate',
        () {
      notifier.addItem(_line(productId: 'p1', quantity: 2, unitCost: 50));
      notifier.addItem(_line(productId: 'p1', quantity: 3, unitCost: 50));

      final state = container.read(currentReceivingProvider);
      expect(state.items, hasLength(1));
      expect(state.items.first.quantity, 5);
    });

    test('different unitCost stays as a separate line — variations downstream',
        () {
      notifier.addItem(_line(productId: 'p1', quantity: 2, unitCost: 50));
      notifier.addItem(_line(productId: 'p1', quantity: 3, unitCost: 60));

      final state = container.read(currentReceivingProvider);
      expect(state.items, hasLength(2));
      expect(state.items.map((i) => i.unitCost), [50, 60]);
    });

    test('different productId never merges', () {
      notifier.addItem(_line(productId: 'p1', quantity: 2, unitCost: 50));
      notifier.addItem(_line(productId: 'p2', quantity: 3, unitCost: 50));

      final state = container.read(currentReceivingProvider);
      expect(state.items, hasLength(2));
    });

    test(
        'merge ignores tiny floating-point cost wobble (within 0.0001)',
        () {
      notifier.addItem(_line(productId: 'p1', quantity: 1, unitCost: 50.0));
      notifier.addItem(
        _line(productId: 'p1', quantity: 4, unitCost: 50.00005),
      );

      final state = container.read(currentReceivingProvider);
      expect(state.items, hasLength(1));
      expect(state.items.first.quantity, 5);
    });

    test('lines with null productId never merge — placeholder rows stay split',
        () {
      // New-product lines (no productId yet) shouldn't collapse onto
      // each other even if other fields match — they represent distinct
      // products awaiting product creation.
      final l1 = ReceivingItemEntity(
        id: '',
        productId: null,
        sku: 'NEW-1',
        name: 'New A',
        quantity: 1,
        unit: 'pcs',
        unitCost: 50,
        costCode: 'NBF',
      );
      final l2 = ReceivingItemEntity(
        id: '',
        productId: null,
        sku: 'NEW-2',
        name: 'New B',
        quantity: 1,
        unit: 'pcs',
        unitCost: 50,
        costCode: 'NBF',
      );

      notifier.addItem(l1);
      notifier.addItem(l2);

      final state = container.read(currentReceivingProvider);
      expect(state.items, hasLength(2));
    });
  });
}
