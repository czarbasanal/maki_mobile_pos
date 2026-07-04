import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_bottom_sheet.dart';

/// Optional receipt-photo control for the expense form. Shows an add tile
/// when empty, or a tappable preview (tap → full-screen zoom) with
/// Replace / Remove actions.
///
/// Display + picker only, like ProductImageUploader: hands the parent
/// compressed JPEG bytes via [onChanged]; the parent uploads at save time.
/// No crop step — receipts are documents, original aspect is kept. Max edge
/// 1600px so receipt text stays legible (still well under the 2MB rule).
class ReceiptImageField extends StatelessWidget {
  const ReceiptImageField({
    super.key,
    required this.existingUrl,
    required this.pendingBytes,
    required this.onChanged,
    this.enabled = true,
  });

  /// URL of the already-uploaded receipt, if any.
  final String? existingUrl;

  /// Local bytes from a fresh pick (after compress). When set, these take
  /// precedence over [existingUrl] in the preview.
  final Uint8List? pendingBytes;

  /// Called whenever the user picks a new photo (`bytes` non-null) or asks
  /// to remove the current one (`bytes` null and `removed` true).
  final void Function(Uint8List? bytes, {required bool removed}) onChanged;

  final bool enabled;

  static const _maxEdge = 1600;
  static const _jpegQuality = 80;

  Future<void> _pick(BuildContext context) async {
    final source = await showAppActionSheet<ImageSource>(
      context,
      icon: LucideIcons.receipt,
      title: 'Receipt photo',
      actions: const [
        AppSheetAction(
          icon: LucideIcons.camera,
          label: 'Take photo',
          value: ImageSource.camera,
        ),
        AppSheetAction(
          icon: LucideIcons.image,
          label: 'Choose from gallery',
          value: ImageSource.gallery,
        ),
      ],
    );
    if (!context.mounted || source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: _maxEdge.toDouble(),
      maxHeight: _maxEdge.toDouble(),
      imageQuality: 90,
    );
    if (picked == null || !context.mounted) return;

    Uint8List bytes;
    try {
      bytes = await File(picked.path).readAsBytes();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read image. Please try again.'),
          ),
        );
      }
      return;
    }

    Uint8List? compressed;
    try {
      compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _maxEdge,
        minHeight: _maxEdge,
        quality: _jpegQuality,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      // Non-fatal: fall through to the raw picked bytes.
    }

    onChanged(compressed ?? bytes, removed: false);
  }

  void _openViewer(BuildContext context) {
    final image = pendingBytes != null
        ? Image.memory(pendingBytes!, fit: BoxFit.contain)
        : Image.network(existingUrl!, fit: BoxFit.contain);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (viewerContext) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(LucideIcons.x),
              onPressed: () => Navigator.of(viewerContext).pop(),
            ),
            title: const Text('Receipt'),
          ),
          body: Center(
            child: InteractiveViewer(maxScale: 5, child: image),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final hasPreview = pendingBytes != null || existingUrl != null;

    if (!hasPreview) {
      return InkWell(
        onTap: enabled ? () => _pick(context) : null,
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: Container(
          width: double.infinity,
          height: 96,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.darkSurfaceMuted
                : AppColors.lightSurfaceMuted,
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.camera, color: muted, size: 24),
              const SizedBox(height: 6),
              Text(
                'Add receipt photo',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
      );
    }

    final preview = pendingBytes != null
        ? Image.memory(pendingBytes!, fit: BoxFit.contain)
        : Image.network(
            existingUrl!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(LucideIcons.imageOff, color: muted, size: 32),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _openViewer(context),
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 160),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? AppColors.darkSurfaceMuted
                  : AppColors.lightSurfaceMuted,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(AppRadius.field),
            ),
            clipBehavior: Clip.antiAlias,
            child: preview,
          ),
        ),
        if (enabled)
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _pick(context),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: const Text('Replace'),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: () => onChanged(null, removed: true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(LucideIcons.trash2, size: 14),
                label: const Text('Remove'),
              ),
            ],
          ),
      ],
    );
  }
}
