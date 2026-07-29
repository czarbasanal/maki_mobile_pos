// test/core/utils/selling_options_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/core/utils/selling_options.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

SellingOptionEntity opt(String id, String label, int pieces, double price) =>
    SellingOptionEntity(id: id, label: label, pieces: pieces, price: price);

void main() {
  group('validateSellingOptions', () {
    test('accepts an empty list', () {
      expect(validateSellingOptions(const []), isNull);
    });

    test('accepts a well-formed list', () {
      expect(
        validateSellingOptions([opt('a', 'By 6', 6, 600), opt('b', 'By 3', 3, 330)]),
        isNull,
      );
    });

    test('rejects a blank label', () {
      expect(validateSellingOptions([opt('a', '   ', 6, 600)]), isNotNull);
    });

    test('rejects a label over 24 characters', () {
      expect(validateSellingOptions([opt('a', 'x' * 25, 6, 600)]), isNotNull);
    });

    test('rejects duplicate labels case-insensitively', () {
      final error =
          validateSellingOptions([opt('a', 'By 6', 6, 600), opt('b', 'by 6', 3, 330)]);
      expect(error, isNotNull);
    });

    test('rejects pieces below 1', () {
      expect(validateSellingOptions([opt('a', 'By 6', 0, 600)]), isNotNull);
    });

    test('rejects a price of zero or less', () {
      expect(validateSellingOptions([opt('a', 'By 6', 6, 0)]), isNotNull);
    });

    test('rejects more than 10 options', () {
      final many = List.generate(11, (i) => opt('$i', 'By $i', i + 1, 100));
      expect(validateSellingOptions(many), isNotNull);
    });

    test('accepts exactly 10 options', () {
      final ten = List.generate(10, (i) => opt('$i', 'By $i', i + 1, 100));
      expect(validateSellingOptions(ten), isNull);
    });
  });

  group('sellingOptionsFromList', () {
    test('returns empty for null', () {
      expect(sellingOptionsFromList(null), isEmpty);
    });

    test('returns empty for a non-list', () {
      expect(sellingOptionsFromList('nope'), isEmpty);
    });

    test('parses well-formed maps', () {
      final parsed = sellingOptionsFromList([
        {'id': 'a', 'label': 'By 6', 'pieces': 6, 'price': 600},
      ]);
      expect(parsed, [opt('a', 'By 6', 6, 600)]);
    });

    test('skips entries missing an id or label', () {
      final parsed = sellingOptionsFromList([
        {'id': '', 'label': 'By 6', 'pieces': 6, 'price': 600},
        {'id': 'b', 'label': '', 'pieces': 3, 'price': 330},
        {'id': 'c', 'label': 'By 3', 'pieces': 3, 'price': 330},
      ]);
      expect(parsed, [opt('c', 'By 3', 3, 330)]);
    });

    test('round-trips through sellingOptionsToList', () {
      final options = [opt('a', 'By 6', 6, 600), opt('b', 'By 3', 3, 330)];
      expect(sellingOptionsFromList(sellingOptionsToList(options)), options);
    });
  });
}
