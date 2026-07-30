// test/core/utils/selling_options_history_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/selling_options.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

SellingOptionEntity opt(String id, String label, int pieces, double price) =>
    SellingOptionEntity(id: id, label: label, pieces: pieces, price: price);

void main() {
  final by3 = opt('o2', 'By 3', 3, 330);

  group('sellingOptionHistoryEvents', () {
    test('no change yields no events', () {
      expect(sellingOptionHistoryEvents([by3], [by3], 60), isEmpty);
    });

    test('an added option logs Option added with its set cost', () {
      final events = sellingOptionHistoryEvents(const [], [by3], 60);
      expect(events, hasLength(1));
      expect(events.single.reason, 'Option added');
      expect(events.single.price, 330);
      expect(events.single.cost, 180);
      expect(events.single.optionPieces, 3);
    });

    test('a removed option logs Option removed with its last known price', () {
      final events = sellingOptionHistoryEvents([by3], const [], 60);
      expect(events.single.reason, 'Option removed');
      expect(events.single.price, 330);
      expect(events.single.optionLabel, 'By 3');
    });

    test('a price-only change logs Price update', () {
      final events =
          sellingOptionHistoryEvents([by3], [by3.copyWith(price: 360)], 60);
      expect(events.single.reason, 'Price update');
      expect(events.single.price, 360);
    });

    test('a piece-count change logs Option changed', () {
      final events = sellingOptionHistoryEvents(
          [by3], [by3.copyWith(pieces: 4, price: 440)], 60);
      expect(events.single.reason, 'Option changed');
      expect(events.single.optionPieces, 4);
      expect(events.single.cost, 240);
    });

    test(
        'a piece-count change with the SAME price still logs Option changed '
        '(not Price update, not silence)', () {
      final events =
          sellingOptionHistoryEvents([by3], [by3.copyWith(pieces: 4)], 60);
      expect(events.single.reason, 'Option changed');
      expect(events.single.price, 330);
      expect(events.single.cost, 240);
    });

    test('a label-only rename logs nothing', () {
      final events =
          sellingOptionHistoryEvents([by3], [by3.copyWith(label: 'Half box')], 60);
      expect(events, isEmpty);
    });

    test('sub-centavo price drift logs nothing', () {
      final events =
          sellingOptionHistoryEvents([by3], [by3.copyWith(price: 330.005)], 60);
      expect(events, isEmpty);
    });

    test('handles several options changing at once', () {
      final by6 = opt('o1', 'By 6', 6, 600);
      final events = sellingOptionHistoryEvents(
        [by6, by3],
        [by6.copyWith(price: 650)],
        60,
      );
      expect(events.map((e) => e.reason).toSet(),
          {'Price update', 'Option removed'});
    });

    test(
        'a single call can produce every reason at once, and an unchanged '
        'option among the mix still produces nothing', () {
      final a = opt('a', 'A', 2, 200); // unchanged
      final b = opt('b', 'B', 3, 300); // price-only change
      final c = opt('c', 'C', 4, 400); // pieces change (w/ price)
      final e = opt('e', 'E', 5, 500); // removed

      final events = sellingOptionHistoryEvents(
        [a, b, c, e],
        [a, b.copyWith(price: 330), c.copyWith(pieces: 6, price: 600),
          opt('d', 'D', 1, 100)], // d added
        10,
      );

      final byOptionId = {for (final ev in events) ev.optionId: ev.reason};
      expect(byOptionId, {
        'b': 'Price update',
        'c': 'Option changed',
        'd': 'Option added',
        'e': 'Option removed',
      });
      // 'a' is absent entirely — no event for the unchanged option.
      expect(byOptionId.containsKey('a'), isFalse);

      final cEvent = events.firstWhere((ev) => ev.optionId == 'c');
      expect(cEvent.cost, 60); // 6 pieces * 10 unit cost, not 10 itself.
    });
  });
}
