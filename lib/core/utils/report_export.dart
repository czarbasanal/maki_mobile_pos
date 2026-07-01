import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';

/// Saves [csv] to a user-chosen `.csv` file named [fileName] using the app's
/// established export mechanism (the file save dialog). Shows a success /
/// cancelled / failed snackbar. Safe to call after awaits (guards mounted).
Future<void> saveReportCsv(
  BuildContext context,
  String csv,
  String fileName,
) async {
  try {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: bytes,
    );
    if (!context.mounted) return;
    if (path == null) {
      context.showSnackBar('Export cancelled');
      return;
    }
    // On mobile, saveFile(bytes:) already wrote the file; on desktop it only
    // returns the chosen path, so write the bytes ourselves.
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(path).writeAsBytes(bytes);
    }
    if (!context.mounted) return;
    context.showSuccessSnackBar('Exported $fileName');
  } catch (e) {
    if (context.mounted) context.showErrorSnackBar('Export failed: $e');
  }
}
