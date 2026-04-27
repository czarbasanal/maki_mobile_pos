import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:maki_mobile_pos/domain/entities/receiving_entity.dart';
import 'package:uuid/uuid.dart';

/// Dialog for importing receiving items from CSV.
class CsvImportDialog extends StatefulWidget {
  final void Function(List<ReceivingItemEntity> items) onImport;

  const CsvImportDialog({
    super.key,
    required this.onImport,
  });

  @override
  State<CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends State<CsvImportDialog> {
  bool _isLoading = false;
  String? _errorMessage;
  List<ReceivingItemEntity>? _parsedItems;
  final _uuid = const Uuid();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.upload_file),
          SizedBox(width: 12),
          Text('Import from CSV'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CSV Format Required:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SKU, Name, Quantity, Unit, Unit Cost',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Example:',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    'SKU-001, Product Name, 10, pcs, 50.00',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Select file button
            Center(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : OutlinedButton.icon(
                      onPressed: _selectFile,
                      icon: const Icon(Icons.file_open),
                      label: const Text('Select CSV File'),
                    ),
            ),

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Preview parsed items
            if (_parsedItems != null) ...[
              const SizedBox(height: 16),
              Text(
                'Preview (${_parsedItems!.length} items):',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _parsedItems!.length,
                  itemBuilder: (context, index) {
                    final item = _parsedItems![index];
                    return ListTile(
                      dense: true,
                      title: Text(item.name),
                      subtitle: Text(item.sku),
                      trailing: Text('${item.quantity} ${item.unit}'),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_parsedItems != null && _parsedItems!.isNotEmpty)
          FilledButton(
            onPressed: () {
              widget.onImport(_parsedItems!);
              Navigator.pop(context);
            },
            child: Text('Import ${_parsedItems!.length} Items'),
          ),
      ],
    );
  }

  Future<void> _selectFile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _parsedItems = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final file = File(result.files.first.path!);
      final content = await file.readAsString();

      final items = _parseCsv(content);
      setState(() {
        _parsedItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to parse CSV: $e';
        _isLoading = false;
      });
    }
  }

  List<ReceivingItemEntity> _parseCsv(String content) {
    final lines = const LineSplitter().convert(content);
    final items = <ReceivingItemEntity>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Skip header row if present
      if (i == 0 && line.toLowerCase().contains('sku')) continue;

      final parts = line.split(',').map((p) => p.trim()).toList();

      if (parts.length < 5) {
        throw FormatException(
            'Invalid line $i: expected 5 columns, got ${parts.length}');
      }

      final sku = parts[0];
      final name = parts[1];
      final quantity = int.tryParse(parts[2]) ?? 0;
      final unit = parts[3];
      final unitCost = double.tryParse(parts[4]) ?? 0;

      if (quantity <= 0) {
        throw FormatException('Invalid quantity on line $i');
      }

      items.add(ReceivingItemEntity(
        id: _uuid.v4(),
        sku: sku,
        name: name,
        quantity: quantity,
        unit: unit,
        unitCost: unitCost,
        costCode: '', // Will be encoded later
      ));
    }

    return items;
  }
}
