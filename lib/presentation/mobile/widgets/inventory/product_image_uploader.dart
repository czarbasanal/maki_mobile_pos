import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Square 96x96 product-image control. Renders the existing URL (or a
/// freshly picked preview) and exposes pick/replace/remove actions.
///
/// The widget is *display + picker only*. It hands the parent the
/// compressed JPEG bytes via [onChanged]; the parent is responsible for
/// uploading them to storage at save time (so we don't burn Storage
/// writes on a form the user might cancel).
///
/// State semantics for the parent:
/// - `existingUrl` non-null + `pendingBytes` null → show remote image.
/// - `pendingBytes` non-null → show the freshly cropped local preview;
///   parent should upload these on save.
/// - Both null → show empty placeholder.
/// - To "remove", parent calls `onChanged(null, removed: true)`. The
///   widget itself just toggles preview/empty; persistence is the
///   parent's job.
class ProductImageUploader extends StatelessWidget {
  const ProductImageUploader({
    super.key,
    required this.existingUrl,
    required this.pendingBytes,
    required this.onChanged,
    this.cropMaxEdge = 400,
    this.jpegQuality = 80,
    this.enabled = true,
  });

  /// URL of the already-uploaded image, if any.
  final String? existingUrl;

  /// Local bytes from a fresh pick (after crop + compress). When set,
  /// these take precedence over [existingUrl] in the preview.
  final Uint8List? pendingBytes;

  /// Called whenever the user picks a new image (`bytes` non-null) or
  /// asks to remove the current image (`bytes` null and `removed` true).
  final void Function(Uint8List? bytes, {required bool removed}) onChanged;

  /// Max edge of the cropped + compressed image, in pixels.
  final int cropMaxEdge;

  /// JPEG quality (0-100) used by [FlutterImageCompress].
  final int jpegQuality;

  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    // Action sheet picks the *source* only; removal is handled by an
    // explicit button in the main UI (avoids ambiguity between
    // sheet-dismissed and remove-tapped).
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.photo_camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.photo),
              title: const Text('Pick from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked == null || !context.mounted) return;

    // Compress to a temp file before cropping so the native crop Activity
    // loads a small file — prevents the silent OS kill caused by memory
    // pressure when the original full-resolution image is large.
    // Must use getTemporaryDirectory() (app's sandboxed cache dir) not
    // Directory.systemTemp (/tmp) — image_cropper's FileProvider is only
    // authorised to serve paths inside the app's own directories.
    final cacheDir = await getTemporaryDirectory();
    final tempPath =
        '${cacheDir.path}/maki_pre_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
    XFile? smallFile;
    try {
      smallFile = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        tempPath,
        minWidth: cropMaxEdge,
        minHeight: cropMaxEdge,
        quality: jpegQuality,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      // Non-fatal: fall back to the original file if pre-compression fails.
    }

    final sourcePath = smallFile?.path ?? picked.path;

    CroppedFile? cropped;
    try {
      cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop image',
            lockAspectRatio: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Crop image',
            aspectRatioLockEnabled: true,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
        ],
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not process image. Please try again.'),
          ),
        );
      }
    } finally {
      // Clean up temp file regardless of crop outcome.
      if (smallFile != null) {
        try {
          File(tempPath).deleteSync();
        } catch (_) {}
      }
    }

    if (cropped == null) return;

    // The cropped file is already small (source was pre-compressed to
    // cropMaxEdge). Read bytes directly — no second compression needed.
    final bytes = await File(cropped.path).readAsBytes();
    onChanged(Uint8List.fromList(bytes), removed: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final hasPreview = pendingBytes != null || existingUrl != null;

    final preview = pendingBytes != null
        ? Image.memory(pendingBytes!, fit: BoxFit.cover)
        : (existingUrl != null
            ? Image.network(
                existingUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Icon(CupertinoIcons.cube_box, color: muted, size: 32),
              )
            : Icon(CupertinoIcons.camera, color: muted, size: 28));

    return Row(
      children: [
        InkWell(
          onTap: enabled ? () => _pick(context) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? AppColors.darkSurfaceMuted
                  : AppColors.lightSurfaceMuted,
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            clipBehavior: Clip.antiAlias,
            child: Center(child: preview),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasPreview ? 'Product image' : 'No image',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hasPreview
                    ? 'Tap the thumbnail to replace.'
                    : 'Tap to add (cropped to $cropMaxEdge px).',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              if (hasPreview && enabled) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => onChanged(null, removed: true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(CupertinoIcons.delete, size: 14),
                    label: const Text('Remove'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
