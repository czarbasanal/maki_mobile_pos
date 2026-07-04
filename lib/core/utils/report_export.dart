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
) {
  return saveBytesFile(
    context,
    Uint8List.fromList(utf8.encode(csv)),
    fileName,
    dialogTitle: 'Save CSV',
    allowedExtensions: const ['csv'],
    successMessage: 'Exported $fileName',
    cancelledMessage: 'Export cancelled',
    failedPrefix: 'Export failed',
  );
}

/// Saves [bytes] to a user-chosen file named [fileName] via the file save
/// dialog. Shows a success / cancelled / failed snackbar. Safe to call after
/// awaits (guards mounted).
Future<void> saveBytesFile(
  BuildContext context,
  Uint8List bytes,
  String fileName, {
  required String dialogTitle,
  required List<String> allowedExtensions,
  required String successMessage,
  String cancelledMessage = 'Save cancelled',
  String failedPrefix = 'Save failed',
}) async {
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      bytes: bytes,
    );
    if (!context.mounted) return;
    if (path == null) {
      context.showSnackBar(cancelledMessage);
      return;
    }
    // On mobile, saveFile(bytes:) already wrote the file; on desktop it only
    // returns the chosen path, so write the bytes ourselves.
    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(path).writeAsBytes(bytes);
    }
    if (!context.mounted) return;
    context.showSuccessSnackBar(successMessage);
  } catch (e) {
    if (context.mounted) context.showErrorSnackBar('$failedPrefix: $e');
  }
}
