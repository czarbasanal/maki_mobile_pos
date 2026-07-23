import 'dart:async';

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

  group('CurrentReceivingNotifier.loadReceiving — error handling', () {
    test(
        'when the fetch throws, clears isLoading and surfaces an errorMessage '
        'instead of pinning the loading skeleton forever', () async {
      final repo = _MockReceivingRepository();
      when(() => repo.getReceivingById(any()))
          .thenThrow(Exception('network down'));

      final c = ProviderContainer(
        overrides: [
          receivingRepositoryProvider.overrideWith((ref) => repo),
          productRepositoryProvider
              .overrideWith((ref) => _MockProductRepository()),
        ],
      );
      addTearDown(c.dispose);
      final n = c.read(currentReceivingProvider.notifier);

      // Must not rethrow — the screen has no error UI in the skeleton branch.
      await n.loadReceiving('r1');

      final state = c.read(currentReceivingProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNotNull);
    });

    test(
        'a failed load after viewing a COMPLETED receiving resets to a clean '
        'editable error state — no stale read-only data hiding the banner',
        () async {
      // currentReceivingProvider is global (never autoDispose), so a prior
      // completed (read-only) receiving lingers. A naive copyWith on the
      // error path would keep its read-only status, and the screen hides the
      // error banner when isReadOnly — so the failure must reset the state.
      final repo = _MockReceivingRepository();
      final completed = ReceivingEntity(
        id: 'r-done',
        referenceNumber: 'RCV-001',
        items: [_line(productId: 'p1', quantity: 2, unitCost: 50, id: 'li-1')],
        totalCost: 100,
        totalQuantity: 2,
        status: ReceivingStatus.completed,
        createdAt: DateTime(2026, 1, 1),
        completedAt: DateTime(2026, 1, 1, 1),
        createdBy: 'u-admin',
        createdByName: 'admin user',
        completedBy: 'u-admin',
      );
      when(() => repo.getReceivingById('r-done'))
          .thenAnswer((_) async => completed);
      when(() => repo.getReceivingById('r-bad'))
          .thenThrow(Exception('boom'));

      final c = ProviderContainer(
        overrides: [
          receivingRepositoryProvider.overrideWith((ref) => repo),
          productRepositoryProvider
              .overrideWith((ref) => _MockProductRepository()),
        ],
      );
      addTearDown(c.dispose);
      final n = c.read(currentReceivingProvider.notifier);

      // Seed prior read-only state.
      await n.loadReceiving('r-done');
      expect(c.read(currentReceivingProvider).isReadOnly, isTrue);

      // Now a load that fails must not leave the stale read-only data.
      await n.loadReceiving('r-bad');

      final state = c.read(currentReceivingProvider);
      expect(state.errorMessage, isNotNull);
      expect(state.isLoading, isFalse);
      expect(state.isReadOnly, isFalse,
          reason: 'stale completed status would hide the error banner');
      expect(state.items, isEmpty);
      expect(state.id, isNull);
    });
  });

  group('CurrentReceivingNotifier.loadReceiving — success', () {
    test('a successful fetch clears isLoading and populates the receiving',
        () async {
      final repo = _MockReceivingRepository();
      final draft = ReceivingEntity(
        id: 'r-1',
        referenceNumber: 'RCV-042',
        items: [_line(productId: 'p1', quantity: 2, unitCost: 50, id: 'li-1')],
        totalCost: 100,
        totalQuantity: 2,
        status: ReceivingStatus.draft,
        createdAt: DateTime(2026, 1, 1),
        createdBy: 'u-admin',
        createdByName: 'admin user',
      );
      when(() => repo.getReceivingById('r-1'))
          .thenAnswer((_) async => draft);

      final c = ProviderContainer(
        overrides: [
          receivingRepositoryProvider.overrideWith((ref) => repo),
          productRepositoryProvider
              .overrideWith((ref) => _MockProductRepository()),
        ],
      );
      addTearDown(c.dispose);
      final n = c.read(currentReceivingProvider.notifier);

      await n.loadReceiving('r-1');

      final state = c.read(currentReceivingProvider);
      expect(state.isLoading, isFalse,
          reason: 'skeleton must clear once the data lands');
      expect(state.id, 'r-1');
      expect(state.referenceNumber, 'RCV-042');
      expect(state.items, hasLength(1));
      expect(state.errorMessage, isNull);
    });

    test(
        'a fetch that never returns times out, clears isLoading and surfaces '
        'a recoverable error instead of pinning the skeleton forever',
        () async {
      final repo = _MockReceivingRepository();
      // A future that never completes — models a stuck network read.
      final stuck = Completer<ReceivingEntity?>();
      addTearDown(() {
        if (!stuck.isCompleted) stuck.complete(null);
      });
      when(() => repo.getReceivingById('r-hang'))
          .thenAnswer((_) => stuck.future);

      final c = ProviderContainer(
        overrides: [
          receivingRepositoryProvider.overrideWith((ref) => repo),
          productRepositoryProvider
              .overrideWith((ref) => _MockProductRepository()),
          receivingLoadTimeoutProvider
              .overrideWithValue(const Duration(milliseconds: 50)),
        ],
      );
      addTearDown(c.dispose);
      final n = c.read(currentReceivingProvider.notifier);

      await n.loadReceiving('r-hang');

      final state = c.read(currentReceivingProvider);
      expect(state.isLoading, isFalse);
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('timed out'));
    });
  });

  group('initNewReceiving — stale-state guard', () {
    test(
        'clears the previous state and flags loading for the whole '
        'ref-number fetch window, then lands on a fresh receiving', () async {
      final receivingRepo = _MockReceivingRepository();
      final productRepo = _MockProductRepository();
      final refNumber = Completer<String>();
      when(() => receivingRepo.generateReferenceNumber())
          .thenAnswer((_) => refNumber.future);

      final c = ProviderContainer(
        overrides: [
          receivingRepositoryProvider.overrideWith((ref) => receivingRepo),
          productRepositoryProvider.overrideWith((ref) => productRepo),
        ],
      );
      addTearDown(c.dispose);
      final n = c.read(currentReceivingProvider.notifier);

      // A previous session's abandoned in-progress receiving.
      n.addItem(_line(productId: 'p1', quantity: 2, unitCost: 50));
      expect(c.read(currentReceivingProvider).items, isNotEmpty);

      final init = n.initNewReceiving();

      // Mid-fetch: the old items must be gone and the screen must be on the
      // loading skeleton — NOT rendering the previous user's receiving.
      final mid = c.read(currentReceivingProvider);
      expect(mid.items, isEmpty);
      expect(mid.isLoading, isTrue);

      refNumber.complete('RCV-100');
      await init;

      final done = c.read(currentReceivingProvider);
      expect(done.referenceNumber, 'RCV-100');
      expect(done.isLoading, isFalse);
      expect(done.items, isEmpty);
    });
  });
}
