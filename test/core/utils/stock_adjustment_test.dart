// test/core/utils/stock_adjustment_test.dart
//
// Pure helper — mirrors web_admin's resolveStockChange.ts /
// adjustmentValidity exactly, same messages, same rule order.
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/stock_adjustment.dart';

void main() {
  group('resolveAdjustment', () {
    test('add: after = before + qty, delta = qty', () {
      final r = resolveAdjustment(AdjustmentMode.add, 8, 5);
      expect(r.before, 8);
      expect(r.after, 13);
      expect(r.delta, 5);
    });

    test('remove: after = before - qty, delta = -qty', () {
      final r = resolveAdjustment(AdjustmentMode.remove, 8, 5);
      expect(r.before, 8);
      expect(r.after, 3);
      expect(r.delta, -5);
    });

    test('set: after = qty (ignores before), delta = after - before', () {
      final r = resolveAdjustment(AdjustmentMode.set, 8, 20);
      expect(r.before, 8);
      expect(r.after, 20);
      expect(r.delta, 12);
    });

    test('set to a lower value than before produces a negative delta', () {
      final r = resolveAdjustment(AdjustmentMode.set, 8, 2);
      expect(r.before, 8);
      expect(r.after, 2);
      expect(r.delta, -6);
    });
  });

  group('adjustmentValidity', () {
    test('qty null -> Enter a quantity', () {
      expect(
        adjustmentValidity(
          mode: AdjustmentMode.add,
          qty: null,
          onHand: 8,
          reasonId: 'r1',
          requiresNote: false,
          note: '',
        ),
        'Enter a quantity',
      );
    });

    test('add with qty <= 0 -> Quantity must be greater than 0', () {
      expect(
        adjustmentValidity(
          mode: AdjustmentMode.add,
          qty: 0,
          onHand: 8,
          reasonId: 'r1',
          requiresNote: false,
          note: '',
        ),
        'Quantity must be greater than 0',
      );
    });

    test('remove with qty <= 0 -> Quantity must be greater than 0', () {
      expect(
        adjustmentValidity(
          mode: AdjustmentMode.remove,
          qty: -1,
          onHand: 8,
          reasonId: 'r1',
          requiresNote: false,
          note: '',
        ),
        'Quantity must be greater than 0',
      );
    });

    test('set with qty <= 0 is NOT rejected by the positive-qty rule', () {
      // set's qty is the target quantity, not a delta — 0 is a legal target.
      expect(
        adjustmentValidity(
          mode: AdjustmentMode.set,
          qty: 0,
          onHand: 8,
          reasonId: 'r1',
          requiresNote: false,
          note: '',
        ),
        isNull,
      );
    });

    test(
        'remove leaving a negative result uses the guide sentence with qty and after',
        () {
      expect(
        adjustmentValidity(
          mode: AdjustmentMode.remove,
          qty: 10,
          onHand: 8,
          reasonId: 'r1',
          requiresNote: false,
          note: '',
        ),
        'Removing 10 would leave -2. Stock cannot go negative.',
      );
    });

    test('set to a negative target -> plain Stock cannot go negative.', () {
      expect(
        adjustmentValidity(
          mode: AdjustmentMode.set,
          qty: -5,
          onHand: 8,
          reasonId: 'r1',
          requiresNote: false,
          note: '',
        ),
        'Stock cannot go negative.',
      );
    });

    test('no reason selected -> Pick a reason', () {
      expect(
        adjustmentValidity(
          mode: AdjustmentMode.add,
          qty: 5,
          onHand: 8,
          reasonId: null,
          requiresNote: false,
          note: '',
        ),
        'Pick a reason',
      );
    });

    test('requiresNote with a blank note -> A note is required for this reason', () {
      expect(
        adjustmentValidity(
          mode: AdjustmentMode.add,
          qty: 5,
          onHand: 8,
          reasonId: 'r1',
          requiresNote: true,
          note: '   ',
        ),
        'A note is required for this reason',
      );
    });

    test('requiresNote with a non-blank note -> valid (null)', () {
      expect(
        adjustmentValidity(
          mode: AdjustmentMode.add,
          qty: 5,
          onHand: 8,
          reasonId: 'r1',
          requiresNote: true,
          note: 'Damaged in transit',
        ),
        isNull,
      );
    });

    test('fully valid add adjustment -> null', () {
      expect(
        adjustmentValidity(
          mode: AdjustmentMode.add,
          qty: 5,
          onHand: 8,
          reasonId: 'r1',
          requiresNote: false,
          note: '',
        ),
        isNull,
      );
    });

    test('fully valid remove adjustment -> null', () {
      expect(
        adjustmentValidity(
          mode: AdjustmentMode.remove,
          qty: 3,
          onHand: 8,
          reasonId: 'r1',
          requiresNote: false,
          note: '',
        ),
        isNull,
      );
    });

    test('fully valid set adjustment -> null', () {
      expect(
        adjustmentValidity(
          mode: AdjustmentMode.set,
          qty: 20,
          onHand: 8,
          reasonId: 'r1',
          requiresNote: false,
          note: '',
        ),
        isNull,
      );
    });
  });
}
