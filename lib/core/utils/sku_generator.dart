import 'dart:math';
import 'package:maki_mobile_pos/core/constants/constants.dart';

/// Generates unique SKU (Stock Keeping Unit) codes.
///
/// SKUs are generated in Code128-compatible format using
/// alphanumeric characters for barcode scanning compatibility.
abstract class SkuGenerator {
  static final _random = Random();

  /// Characters used in SKU generation (Code128 compatible).
  /// Excludes ambiguous characters: 0/O, 1/I/L
  static const String _chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Generates a random SKU with the default prefix.
  ///
  /// Format: SKU-XXXXXXXX (where X is alphanumeric)
  ///
  /// Example:
  /// ```dart
  /// SkuGenerator.generate() // Returns "SKU-A3B7K9M2"
  /// ```
  static String generate() {
    return generateWithPrefix(AppConstants.skuPrefix);
  }

  /// Generates a random SKU with a custom prefix.
  ///
  /// Example:
  /// ```dart
  /// SkuGenerator.generateWithPrefix('PROD') // Returns "PROD-A3B7K9M2"
  /// ```
  static String generateWithPrefix(String prefix) {
    final randomPart = _generateRandomString(AppConstants.skuRandomLength);
    return '$prefix-$randomPart';
  }

  /// Generates a variation SKU from an existing SKU.
  ///
  /// Used when receiving products with same SKU but different cost.
  /// Appends a variation number to the original SKU.
  ///
  /// Example:
  /// ```dart
  /// SkuGenerator.generateVariation('ABC123', 1) // Returns "ABC123-1"
  /// SkuGenerator.generateVariation('ABC123', 2) // Returns "ABC123-2"
  /// SkuGenerator.generateVariation('ABC123-1', 2) // Returns "ABC123-2"
  /// ```
  static String generateVariation(String baseSku, int variationNumber) {
    // Remove any existing variation number
    final cleanSku = _removeVariationSuffix(baseSku);
    return '$cleanSku${AppConstants.skuVariationSeparator}$variationNumber';
  }

  /// Gets the next variation number for a given SKU.
  ///
  /// Analyzes existing variations and returns the next available number.
  ///
  /// Example:
  /// ```dart
  /// SkuGenerator.getNextVariationNumber('ABC123', ['ABC123', 'ABC123-1', 'ABC123-2'])
  /// // Returns 3
  /// ```
  static int getNextVariationNumber(String baseSku, List<String> existingSkus) {
    final cleanBase = _removeVariationSuffix(baseSku);
    int maxVariation = 0;

    for (final sku in existingSkus) {
      if (sku == cleanBase) {
        // Original SKU exists, so variation starts at 1
        if (maxVariation < 1) maxVariation = 0;
        continue;
      }

      if (sku.startsWith('$cleanBase${AppConstants.skuVariationSeparator}')) {
        final suffix = sku.substring(cleanBase.length + 1);
        final variationNum = int.tryParse(suffix);
        if (variationNum != null && variationNum > maxVariation) {
          maxVariation = variationNum;
        }
      }
    }

    return maxVariation + 1;
  }

  /// Checks if a SKU is a variation of a base SKU.
  ///
  /// Example:
  /// ```dart
  /// SkuGenerator.isVariationOf('ABC123-2', 'ABC123') // Returns true
  /// SkuGenerator.isVariationOf('ABC123', 'ABC123')   // Returns false
  /// SkuGenerator.isVariationOf('XYZ789', 'ABC123')   // Returns false
  /// ```
  static bool isVariationOf(String sku, String baseSku) {
    final cleanBase = _removeVariationSuffix(baseSku);
    if (sku == cleanBase) return false;

    return sku.startsWith('$cleanBase${AppConstants.skuVariationSeparator}');
  }

  /// Gets the base SKU from a variation SKU.
  ///
  /// Example:
  /// ```dart
  /// SkuGenerator.getBaseSku('ABC123-2') // Returns "ABC123"
  /// SkuGenerator.getBaseSku('ABC123')   // Returns "ABC123"
  /// ```
  static String getBaseSku(String sku) {
    return _removeVariationSuffix(sku);
  }

  /// Gets the variation number from a SKU.
  /// Returns null if not a variation.
  ///
  /// Example:
  /// ```dart
  /// SkuGenerator.getVariationNumber('ABC123-2') // Returns 2
  /// SkuGenerator.getVariationNumber('ABC123')   // Returns null
  /// ```
  static int? getVariationNumber(String sku) {
    final separatorIndex = sku.lastIndexOf(AppConstants.skuVariationSeparator);
    if (separatorIndex == -1) return null;

    final suffix = sku.substring(separatorIndex + 1);
    return int.tryParse(suffix);
  }

  /// Validates that a SKU is Code128 compatible.
  ///
  /// Code128 supports ASCII 0-127, but we restrict to alphanumeric
  /// plus hyphen for simplicity and readability.
  static bool isValidSku(String sku) {
    if (sku.isEmpty || sku.length > 50) return false;
    return RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(sku);
  }

  /// Generates a random alphanumeric string of specified length.
  static String _generateRandomString(int length) {
    return List.generate(
      length,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
  }

  /// Removes the variation suffix from a SKU.
  static String _removeVariationSuffix(String sku) {
    final separatorIndex = sku.lastIndexOf(AppConstants.skuVariationSeparator);
    if (separatorIndex == -1) return sku;

    final suffix = sku.substring(separatorIndex + 1);
    // Only remove if suffix is numeric (a variation number)
    if (int.tryParse(suffix) != null) {
      return sku.substring(0, separatorIndex);
    }
    return sku;
  }
}
