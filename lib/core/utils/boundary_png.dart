// Renders a RepaintBoundary subtree to PNG bytes and hands them to the app's
// established export mechanism (saveBytesFile → file-save dialog + its own
// snackbars). RepaintBoundary.toImage paints the boundary's FULL child even
// when part of it is scrolled off-screen, so wrapping the receipt inside the
// scrollable captures the whole slip.
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:maki_mobile_pos/core/utils/report_export.dart';

/// Captures [boundaryKey]'s RepaintBoundary at 3× pixel ratio (crisp enough
/// to read on a phone screenshot viewer) and saves it as [fileName].
/// Returns false when the boundary isn't ready or encoding fails —
/// saveBytesFile surfaces its own success/cancel/failure snackbars after that.
///
/// PNG rather than JPEG: these captures are receipts — small text, hairlines
/// and figures — and JPEG blurs exactly that. Flutter also encodes PNG
/// natively, so no extra dependency is carried for it.
Future<bool> saveBoundaryPng(
  BuildContext context,
  GlobalKey boundaryKey,
  String fileName, {
  String dialogTitle = 'Save image',
  String successPrefix = 'Saved',
}) async {
  final render =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (render == null) return false;

  final image = await render.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (bytes == null) return false;

  if (!context.mounted) return false;
  await saveBytesFile(
    context,
    bytes.buffer.asUint8List(),
    fileName,
    dialogTitle: dialogTitle,
    allowedExtensions: const ['png'],
    successMessage: '$successPrefix $fileName',
    cancelledMessage: 'Save cancelled',
    failedPrefix: 'Save failed',
  );
  return true;
}
