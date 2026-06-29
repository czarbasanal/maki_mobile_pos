import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

/// Widget for editing cost code mapping. Mirrors the read-only display
/// (recessed mono digit cells · `arrow-right` · slate/gold-outlined code
/// cells) with the code cell swapped for an editable mono field.
class CostCodeEditor extends StatefulWidget {
  final CostCodeEntity mapping;
  final ValueChanged<CostCodeEntity> onMappingChanged;

  const CostCodeEditor({
    super.key,
    required this.mapping,
    required this.onMappingChanged,
  });

  @override
  State<CostCodeEditor> createState() => _CostCodeEditorState();
}

class _CostCodeEditorState extends State<CostCodeEditor> {
  static const String _mono = AppTextStyles.monoFontFamily;

  late Map<String, TextEditingController> _controllers;
  late TextEditingController _doubleZeroController;
  late TextEditingController _tripleZeroController;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _controllers = {};
    for (int i = 0; i < 10; i++) {
      final digit = i.toString();
      _controllers[digit] = TextEditingController(
        text: widget.mapping.digitToLetter[digit] ?? '',
      );
    }
    _doubleZeroController = TextEditingController(
      text: widget.mapping.doubleZeroCode,
    );
    _tripleZeroController = TextEditingController(
      text: widget.mapping.tripleZeroCode,
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _doubleZeroController.dispose();
    _tripleZeroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          ...List.generate(10, (index) {
            final digit = index.toString();
            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : 9),
              child: _buildMappingRow(theme, muted, digit),
            );
          }),
          const SizedBox(height: 14),
          _buildSpecialCodeRow(theme, muted, '00', _doubleZeroController,
              'Double Zero'),
          const SizedBox(height: 9),
          _buildSpecialCodeRow(theme, muted, '000', _tripleZeroController,
              'Triple Zero'),
        ],
      ),
    );
  }

  Widget _digitCell(ThemeData theme, String text, {bool expand = true}) {
    final dark = theme.brightness == Brightness.dark;
    final fill = dark ? AppColors.darkCanvas : AppColors.lightSurfaceMuted;
    final border = dark ? AppColors.darkInputBorder : AppColors.lightHairline;
    final cell = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: _mono,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
    return expand ? Expanded(child: cell) : cell;
  }

  Widget _buildMappingRow(ThemeData theme, Color muted, String digit) {
    final controller = _controllers[digit]!;
    final isDuplicate = _hasDuplicateLetter(digit, controller.text);
    final accent = isDuplicate ? theme.colorScheme.error : theme.colorScheme.primary;

    return Row(
      children: [
        _digitCell(theme, digit),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(LucideIcons.arrowRight, size: 16, color: muted),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            maxLength: 1,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
              UpperCaseTextFormatter(),
            ],
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 7),
              filled: false,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent, width: 1.3),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent, width: 1.3),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: accent, width: 1.6),
              ),
              errorText: isDuplicate ? 'Dup' : null,
              errorStyle: const TextStyle(fontSize: 10),
            ),
            style: TextStyle(
              fontFamily: _mono,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
            onChanged: (_) => _updateMapping(),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialCodeRow(
    ThemeData theme,
    Color muted,
    String digits,
    TextEditingController controller,
    String label,
  ) {
    return Row(
      children: [
        _digitCell(theme, digits, expand: false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(LucideIcons.arrowRight, size: 16, color: muted),
        ),
        SizedBox(
          width: 84,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
              UpperCaseTextFormatter(),
            ],
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 7),
              filled: false,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 1.3),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 1.3),
              ),
            ),
            style: TextStyle(
              fontFamily: _mono,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
            onChanged: (_) => _updateMapping(),
          ),
        ),
        const Spacer(),
        Text(label, style: TextStyle(fontSize: 12.5, color: muted)),
      ],
    );
  }

  bool _hasDuplicateLetter(String currentDigit, String letter) {
    if (letter.isEmpty) return false;

    for (final entry in _controllers.entries) {
      if (entry.key != currentDigit &&
          entry.value.text.toUpperCase() == letter.toUpperCase()) {
        return true;
      }
    }
    return false;
  }

  void _updateMapping() {
    final newMapping = <String, String>{};
    for (int i = 0; i < 10; i++) {
      final digit = i.toString();
      newMapping[digit] = _controllers[digit]!.text.toUpperCase();
    }

    final updated = widget.mapping.copyWith(
      digitToLetter: newMapping,
      doubleZeroCode: _doubleZeroController.text.toUpperCase(),
      tripleZeroCode: _tripleZeroController.text.toUpperCase(),
    );

    widget.onMappingChanged(updated);
    setState(() {}); // Trigger rebuild to update duplicate detection
  }
}

/// Text formatter that converts input to uppercase.
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
