import 'package:equatable/equatable.dart';

/// Represents the cost code mapping configuration.
///
/// This entity defines how numbers are encoded to letters
/// to hide actual product costs from unauthorized users.
///
/// Default mapping:
/// - N → 1
/// - B → 2
/// - Q → 3
/// - M → 4
/// - F → 5
/// - Z → 6
/// - V → 7
/// - L → 8
/// - J → 9
/// - S → 0
/// - SC → 00
/// - SCS → 000
class CostCodeEntity extends Equatable {
  /// Mapping from digit (0-9) to letter code
  final Map<String, String> digitToLetter;

  /// Special codes for repeated zeros
  final String doubleZeroCode; // Default: SC
  final String tripleZeroCode; // Default: SCS

  /// When this mapping was last updated
  final DateTime? updatedAt;

  /// Who last updated this mapping
  final String? updatedBy;

  const CostCodeEntity({
    required this.digitToLetter,
    this.doubleZeroCode = 'SC',
    this.tripleZeroCode = 'SCS',
    this.updatedAt,
    this.updatedBy,
  });

  /// Creates the default cost code mapping.
  factory CostCodeEntity.defaultMapping() {
    return const CostCodeEntity(
      digitToLetter: {
        '1': 'N',
        '2': 'B',
        '3': 'Q',
        '4': 'M',
        '5': 'F',
        '6': 'Z',
        '7': 'V',
        '8': 'L',
        '9': 'J',
        '0': 'S',
      },
      doubleZeroCode: 'SC',
      tripleZeroCode: 'SCS',
    );
  }

  /// Gets the reverse mapping (letter to digit).
  Map<String, String> get letterToDigit {
    final reverse = <String, String>{};
    digitToLetter.forEach((digit, letter) {
      reverse[letter] = digit;
    });
    // Add special codes
    reverse[doubleZeroCode] = '00';
    reverse[tripleZeroCode] = '000';
    return reverse;
  }

  /// Encodes a cost amount to letter code.
  ///
  /// Example with default mapping:
  /// - 125 → "NBF"
  /// - 1000 → "NSCS" (N=1, SCS=000)
  /// - 100 → "NSC" (N=1, SC=00)
  /// - 10000 → "NSSSCS" (N=1, S=0, SCS=000)
  ///
  /// Note: Only encodes whole numbers (decimals are truncated).
  String encode(double cost) {
    // Convert to whole number (no decimals in cost code)
    final wholeCost = cost.truncate();
    if (wholeCost <= 0) return digitToLetter['0'] ?? 'S';

    final costString = wholeCost.toString();
    final result = StringBuffer();

    int i = 0;
    while (i < costString.length) {
      final remaining = costString.length - i;

      // Check for triple zeros (need exactly 3 zeros at current position)
      if (remaining >= 3 &&
          costString[i] == '0' &&
          costString[i + 1] == '0' &&
          costString[i + 2] == '0') {
        result.write(tripleZeroCode);
        i += 3;
        continue;
      }

      // Check for double zeros (need exactly 2 zeros at current position)
      if (remaining >= 2 && costString[i] == '0' && costString[i + 1] == '0') {
        result.write(doubleZeroCode);
        i += 2;
        continue;
      }

      // Single digit
      final digit = costString[i];
      result.write(digitToLetter[digit] ?? '?');
      i++;
    }

    return result.toString();
  }

  /// Decodes a letter code back to cost amount.
  ///
  /// Example with default mapping:
  /// - "NBF" → 125.0
  /// - "NSSC" → 1000.0
  ///
  /// Returns null if the code is invalid.
  double? decode(String code) {
    if (code.isEmpty) return null;

    final reverseMap = letterToDigit;
    final result = StringBuffer();

    int i = 0;
    while (i < code.length) {
      // Check for triple zero code first (longest match)
      if (i + tripleZeroCode.length <= code.length) {
        final possibleTriple = code.substring(i, i + tripleZeroCode.length);
        if (possibleTriple == tripleZeroCode) {
          result.write('000');
          i += tripleZeroCode.length;
          continue;
        }
      }

      // Check for double zero code
      if (i + doubleZeroCode.length <= code.length) {
        final possibleDouble = code.substring(i, i + doubleZeroCode.length);
        if (possibleDouble == doubleZeroCode) {
          result.write('00');
          i += doubleZeroCode.length;
          continue;
        }
      }

      // Single letter
      final letter = code[i];
      final digit = reverseMap[letter];
      if (digit == null) {
        return null; // Invalid code
      }
      result.write(digit);
      i++;
    }

    return double.tryParse(result.toString());
  }

  /// Validates if a code string is valid.
  bool isValidCode(String code) {
    return decode(code) != null;
  }

  /// Creates a copy with updated values.
  CostCodeEntity copyWith({
    Map<String, String>? digitToLetter,
    String? doubleZeroCode,
    String? tripleZeroCode,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return CostCodeEntity(
      digitToLetter: digitToLetter ?? this.digitToLetter,
      doubleZeroCode: doubleZeroCode ?? this.doubleZeroCode,
      tripleZeroCode: tripleZeroCode ?? this.tripleZeroCode,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  List<Object?> get props => [
        digitToLetter,
        doubleZeroCode,
        tripleZeroCode,
        updatedAt,
        updatedBy,
      ];
}
