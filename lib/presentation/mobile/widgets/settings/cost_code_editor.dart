import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

/// Widget for editing cost code mapping.
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Digit',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    'Letter',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const Divider(),

            // Digit to letter mappings
            ...List.generate(10, (index) {
              final digit = index.toString();
              return _buildMappingRow(theme, digit);
            }),

            const Divider(height: 32),

            // Special codes
            Text(
              'Special Codes',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            _buildSpecialCodeRow(
              theme,
              '00',
              _doubleZeroController,
              'Double Zero',
            ),
            const SizedBox(height: 8),
            _buildSpecialCodeRow(
              theme,
              '000',
              _tripleZeroController,
              'Triple Zero',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMappingRow(ThemeData theme, String digit) {
    final controller = _controllers[digit]!;
    final isDuplicate = _hasDuplicateLetter(digit, controller.text);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.arrow_forward,
              color: theme.colorScheme.primary,
            ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDuplicate ? Colors.red : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDuplicate ? Colors.red : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDuplicate ? Colors.red : theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: isDuplicate
                    ? Colors.red[50]
                    : theme.colorScheme.primary.withOpacity(0.05),
                errorText: isDuplicate ? 'Duplicate' : null,
                errorStyle: const TextStyle(fontSize: 10),
              ),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: isDuplicate ? Colors.red : theme.colorScheme.primary,
              ),
              onChanged: (_) => _updateMapping(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialCodeRow(
    ThemeData theme,
    String digits,
    TextEditingController controller,
    String label,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            digits,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
            ),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: theme.colorScheme.primary,
            ),
            onChanged: (_) => _updateMapping(),
          ),
        ),
        const Spacer(),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
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
