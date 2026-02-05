import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

void main() {
  group('CostCodeEntity', () {
    late CostCodeEntity costCode;

    setUp(() {
      costCode = CostCodeEntity.defaultMapping();
    });

    group('encode', () {
      test('should encode single digits correctly', () {
        expect(costCode.encode(1), 'N');
        expect(costCode.encode(2), 'B');
        expect(costCode.encode(3), 'Q');
        expect(costCode.encode(4), 'M');
        expect(costCode.encode(5), 'F');
        expect(costCode.encode(6), 'Z');
        expect(costCode.encode(7), 'V');
        expect(costCode.encode(8), 'L');
        expect(costCode.encode(9), 'J');
      });

      test('should encode zero correctly', () {
        expect(costCode.encode(0), 'S');
      });

      test('should encode multi-digit numbers', () {
        expect(costCode.encode(12), 'NB');
        expect(costCode.encode(125), 'NBF');
        expect(costCode.encode(999), 'JJJ');
        expect(costCode.encode(123), 'NBQ');
        expect(costCode.encode(456), 'MFZ');
        expect(costCode.encode(789), 'VLJ');
      });

      test('should encode numbers with single zero', () {
        expect(costCode.encode(10), 'NS');
        expect(costCode.encode(20), 'BS');
        expect(costCode.encode(101), 'NSN');
        expect(costCode.encode(105), 'NSF');
        expect(costCode.encode(1050), 'NSFS');
      });

      test('should encode with double zeros', () {
        expect(costCode.encode(100), 'NSC'); // 1-00
        expect(costCode.encode(200), 'BSC'); // 2-00
        expect(costCode.encode(500), 'FSC'); // 5-00
        expect(costCode.encode(1200), 'NBSC'); // 12-00
        expect(costCode.encode(1001), 'NSCN'); // 1-00-1
        expect(costCode.encode(2005), 'BSCF'); // 2-00-5
      });

      test('should encode with triple zeros', () {
        expect(costCode.encode(1000), 'NSCS'); // 1-000
        expect(costCode.encode(2000), 'BSCS'); // 2-000
        expect(costCode.encode(5000), 'FSCS'); // 5-000
        expect(costCode.encode(12000), 'NBSCS'); // 12-000
        expect(costCode.encode(10001), 'NSCSN'); // 1-000-1
      });

      test('should encode large numbers with mixed zeros', () {
        // Greedy left-to-right encoding:
        // 10000 = "10000" -> 1-000-0 -> N-SCS-S = NSCSS
        expect(costCode.encode(10000), 'NSCSS');

        // 100000 = "100000" -> 1-000-00 -> N-SCS-SC = NSCSSC
        expect(costCode.encode(100000), 'NSCSSC');

        // 20500 = "20500" -> 2-0-5-00 -> B-S-F-SC = BSFSC
        expect(costCode.encode(20500), 'BSFSC');

        // 1000000 = "1000000" -> 1-000-000 -> N-SCS-SCS = NSCSSCS
        expect(costCode.encode(1000000), 'NSCSSCS');

        // 50000 = "50000" -> 5-000-0 -> F-SCS-S = FSCSS
        expect(costCode.encode(50000), 'FSCSS');

        // 30050 = "30050" -> 3-00-5-0 -> Q-SC-F-S = QSCFS
        expect(costCode.encode(30050), 'QSCFS');
      });

      test('should truncate decimals', () {
        expect(costCode.encode(125.99), 'NBF');
        expect(costCode.encode(125.01), 'NBF');
        expect(costCode.encode(125.5), 'NBF');
      });

      test('should handle negative as zero', () {
        expect(costCode.encode(-1), 'S');
        expect(costCode.encode(-100), 'S');
      });
    });

    group('decode', () {
      test('should decode single letters correctly', () {
        expect(costCode.decode('N'), 1);
        expect(costCode.decode('B'), 2);
        expect(costCode.decode('Q'), 3);
        expect(costCode.decode('M'), 4);
        expect(costCode.decode('F'), 5);
        expect(costCode.decode('Z'), 6);
        expect(costCode.decode('V'), 7);
        expect(costCode.decode('L'), 8);
        expect(costCode.decode('J'), 9);
        expect(costCode.decode('S'), 0);
      });

      test('should decode multi-letter codes', () {
        expect(costCode.decode('NB'), 12);
        expect(costCode.decode('NBF'), 125);
        expect(costCode.decode('JJJ'), 999);
        expect(costCode.decode('NBQ'), 123);
        expect(costCode.decode('MFZ'), 456);
      });

      test('should decode codes with single zero', () {
        expect(costCode.decode('NS'), 10);
        expect(costCode.decode('BS'), 20);
        expect(costCode.decode('NSN'), 101);
        expect(costCode.decode('NSF'), 105);
      });

      test('should decode double zero codes', () {
        expect(costCode.decode('NSC'), 100);
        expect(costCode.decode('BSC'), 200);
        expect(costCode.decode('NBSC'), 1200);
        expect(costCode.decode('NSCN'), 1001);
      });

      test('should decode triple zero codes', () {
        expect(costCode.decode('NSCS'), 1000);
        expect(costCode.decode('BSCS'), 2000);
        expect(costCode.decode('NBSCS'), 12000);
        expect(costCode.decode('NSCSN'), 10001);
      });

      test('should decode large numbers with mixed zeros', () {
        expect(costCode.decode('NSCSS'), 10000);
        expect(costCode.decode('NSCSSC'), 100000);
        expect(costCode.decode('BSFSC'), 20500);
        expect(costCode.decode('NSCSSCS'), 1000000);
        expect(costCode.decode('FSCSS'), 50000);
        expect(costCode.decode('QSCFS'), 30050);
      });

      test('should return null for invalid codes', () {
        expect(costCode.decode('X'), isNull);
        expect(costCode.decode('ABC'), isNull);
        expect(costCode.decode('123'), isNull);
        expect(costCode.decode('NX'), isNull);
      });

      test('should return null for empty string', () {
        expect(costCode.decode(''), isNull);
      });
    });

    group('round trip (encode then decode)', () {
      test('should return original value for common prices', () {
        final testValues = [
          // Single digits
          1, 2, 3, 4, 5, 6, 7, 8, 9,
          // Two digits
          10, 12, 20, 25, 50, 99,
          // Three digits (common retail prices)
          100, 101, 110, 125, 150, 199, 200, 250, 500, 750, 999,
          // Four digits
          1000, 1001, 1010, 1100, 1200, 1500, 2000, 2500, 5000, 9999,
          // Five digits
          10000, 10001, 10010, 10100, 12000, 12500, 20000, 20500, 25000, 30050,
          50000, 99999,
          // Six digits
          100000, 100001, 500000, 999999,
          // Seven digits
          1000000,
        ];

        for (final value in testValues) {
          final encoded = costCode.encode(value.toDouble());
          final decoded = costCode.decode(encoded);
          expect(
            decoded,
            value,
            reason:
                'Failed for value: $value, encoded: $encoded, decoded: $decoded',
          );
        }
      });
    });

    group('isValidCode', () {
      test('should return true for valid codes', () {
        expect(costCode.isValidCode('N'), true);
        expect(costCode.isValidCode('NBF'), true);
        expect(costCode.isValidCode('NSC'), true);
        expect(costCode.isValidCode('NSCS'), true);
        expect(costCode.isValidCode('NSCSNBF'), true);
        expect(costCode.isValidCode('NSCSS'), true);
        expect(costCode.isValidCode('NSCSSC'), true);
      });

      test('should return false for invalid codes', () {
        expect(costCode.isValidCode('X'), false);
        expect(costCode.isValidCode('XYZ'), false);
        expect(costCode.isValidCode('123'), false);
        expect(costCode.isValidCode(''), false);
        expect(costCode.isValidCode('NAX'), false);
      });
    });

    group('letterToDigit reverse mapping', () {
      test('should have correct reverse mapping', () {
        final reverse = costCode.letterToDigit;

        expect(reverse['N'], '1');
        expect(reverse['B'], '2');
        expect(reverse['Q'], '3');
        expect(reverse['M'], '4');
        expect(reverse['F'], '5');
        expect(reverse['Z'], '6');
        expect(reverse['V'], '7');
        expect(reverse['L'], '8');
        expect(reverse['J'], '9');
        expect(reverse['S'], '0');
        expect(reverse['SC'], '00');
        expect(reverse['SCS'], '000');
      });
    });

    group('custom mapping', () {
      test('should work with custom mapping', () {
        final customCode = CostCodeEntity(
          digitToLetter: {
            '1': 'A',
            '2': 'B',
            '3': 'C',
            '4': 'D',
            '5': 'E',
            '6': 'F',
            '7': 'G',
            '8': 'H',
            '9': 'I',
            '0': 'O',
          },
          doubleZeroCode: 'OO',
          tripleZeroCode: 'OOO',
        );

        expect(customCode.encode(123), 'ABC');
        expect(customCode.encode(100), 'AOO');
        expect(customCode.encode(1000), 'AOOO');

        expect(customCode.decode('ABC'), 123);
        expect(customCode.decode('AOO'), 100);
        expect(customCode.decode('AOOO'), 1000);
      });
    });

    group('edge cases', () {
      test('should handle very large numbers', () {
        final value = 9999999;
        final encoded = costCode.encode(value.toDouble());
        final decoded = costCode.decode(encoded);
        expect(decoded, value);
      });

      test('should handle all same digits', () {
        expect(costCode.encode(111), 'NNN');
        expect(costCode.encode(555), 'FFF');
        expect(costCode.encode(999), 'JJJ');

        expect(costCode.decode('NNN'), 111);
        expect(costCode.decode('FFF'), 555);
        expect(costCode.decode('JJJ'), 999);
      });

      test('should handle alternating zeros', () {
        // 10101 = 1-0-1-0-1 → N-S-N-S-N
        expect(costCode.encode(10101), 'NSNSN');
        expect(costCode.decode('NSNSN'), 10101);

        // 20202 = 2-0-2-0-2 → B-S-B-S-B
        expect(costCode.encode(20202), 'BSBSB');
        expect(costCode.decode('BSBSB'), 20202);
      });
    });
  });
}
