import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/core/constants/constants.dart';

/// Currency input formatter for TextField.
///
/// Formats input as Philippine Peso with thousand separators.
class CurrencyInputFormatter extends TextInputFormatter {
  final int decimalPlaces;
  final bool allowNegative;

  CurrencyInputFormatter({
    this.decimalPlaces = AppConstants.currencyDecimalPlaces,
    this.allowNegative = false,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-numeric characters except decimal point and minus
    String newText = newValue.text.replaceAll(RegExp(r'[^\d.\-]'), '');

    // Handle negative sign
    final isNegative = allowNegative && newText.startsWith('-');
    newText = newText.replaceAll('-', '');

    // Handle multiple decimal points
    final parts = newText.split('.');
    if (parts.length > 2) {
      newText = '${parts[0]}.${parts.sublist(1).join()}';
    }

    // Limit decimal places
    if (parts.length == 2 && parts[1].length > decimalPlaces) {
      newText = '${parts[0]}.${parts[1].substring(0, decimalPlaces)}';
    }

    // Add thousand separators to integer part
    if (newText.isNotEmpty) {
      final decimalIndex = newText.indexOf('.');
      String integerPart;
      String decimalPart = '';

      if (decimalIndex != -1) {
        integerPart = newText.substring(0, decimalIndex);
        decimalPart = newText.substring(decimalIndex);
      } else {
        integerPart = newText;
      }

      // Add thousand separators
      if (integerPart.isNotEmpty) {
        final reversed = integerPart.split('').reversed.toList();
        final withSeparators = <String>[];
        for (var i = 0; i < reversed.length; i++) {
          if (i > 0 && i % 3 == 0) {
            withSeparators.add(',');
          }
          withSeparators.add(reversed[i]);
        }
        integerPart = withSeparators.reversed.join();
      }

      newText = '${isNegative ? '-' : ''}$integerPart$decimalPart';
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

/// Uppercase input formatter.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// SKU input formatter (alphanumeric and hyphen only, uppercase).
class SkuInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText =
        newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

/// Phone number formatter for Philippine numbers.
class PhilippinePhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    String formatted = '';

    if (digitsOnly.startsWith('63')) {
      // +63 format
      formatted = '+63 ';
      final remaining = digitsOnly.substring(2);
      formatted += _formatPhoneDigits(remaining);
    } else if (digitsOnly.startsWith('0')) {
      // 09XX format
      formatted = _formatPhoneDigits(digitsOnly);
    } else {
      formatted = digitsOnly;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatPhoneDigits(String digits) {
    if (digits.length <= 4) return digits;
    if (digits.length <= 7) {
      return '${digits.substring(0, 4)} ${digits.substring(4)}';
    }
    return '${digits.substring(0, 4)} ${digits.substring(4, 7)} ${digits.substring(7, digits.length.clamp(0, 11))}';
  }
}

/// Integer-only input formatter.
class IntegerInputFormatter extends TextInputFormatter {
  final bool allowNegative;

  IntegerInputFormatter({this.allowNegative = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final pattern = allowNegative ? r'[^\d\-]' : r'[^\d]';
    String newText = newValue.text.replaceAll(RegExp(pattern), '');

    // Ensure minus sign is only at the beginning
    if (allowNegative && newText.contains('-')) {
      final isNegative = newText.startsWith('-');
      newText = newText.replaceAll('-', '');
      if (isNegative) {
        newText = '-$newText';
      }
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
