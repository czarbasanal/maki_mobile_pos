import 'dart:io';
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_bottom_sheet.dart';

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
///
/// Cropping is done in a pure-Flutter widget (`crop_your_image`), not a
/// native Activity — this avoids the OS killing the Flutter process
/// under memory pressure during a separate native crop UI.
class ProductImageUploader extends StatelessWidget {
  const ProductImageUploader({
    super.key,
    required this.existingUrl,
    required this.pendingBytes,
    required this.onChanged,
    this.cropMaxEdge = 200,
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
    final source = await showAppActionSheet<ImageSource>(
      context,
      icon: LucideIcons.image,
      title: 'Product image',
      actions: const [
        AppSheetAction(
          icon: LucideIcons.camera,
          label: 'Take photo',
          value: ImageSource.camera,
        ),
        AppSheetAction(
          icon: LucideIcons.image,
          label: 'Pick from gallery',
          value: ImageSource.gallery,
        ),
      ],
    );
    if (!context.mounted || source == null) return;

    // image_picker resizes client-side before returning the file. Cap at
    // 1024px so the bytes we load into the Flutter crop widget stay
    // reasonable in memory; the final compression to cropMaxEdge happens
    // after the user confirms their crop.
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
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

    if (!context.mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List?>(
      MaterialPageRoute(
        builder: (_) => _CropImageScreen(imageBytes: bytes),
        fullscreenDialog: true,
      ),
    );
    if (cropped == null) return;

    // Final compression — the cropped output is a sub-region of a 1024px
    // image so it may still be larger than our target preview size.
    Uint8List? compressed;
    try {
      compressed = await FlutterImageCompress.compressWithList(
        cropped,
        minWidth: cropMaxEdge,
        minHeight: cropMaxEdge,
        quality: jpegQuality,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      // Non-fatal: fall through to the uncompressed cropped bytes.
    }

    onChanged(compressed ?? cropped, removed: false);
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

/// Full-screen modal that hosts the pure-Flutter [Crop] widget. The user
/// adjusts a square crop region and taps Done; we pop with the cropped
/// JPEG bytes (or null on cancel/error).
class _CropImageScreen extends StatefulWidget {
  const _CropImageScreen({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_CropImageScreen> createState() => _CropImageScreenState();
}

class _CropImageScreenState extends State<_CropImageScreen> {
  final _controller = CropController();
  bool _cropping = false;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not crop image. Please try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Crop image'),
        actions: [
          TextButton(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _controller.crop();
                  },
            child: Text(
              _cropping ? 'Cropping…' : 'Done',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Crop(
        image: widget.imageBytes,
        controller: _controller,
        aspectRatio: 1.0,
        onCropped: _onCropped,
        baseColor: Colors.black,
        maskColor: Colors.black.withValues(alpha: 0.6),
        progressIndicator: const CircularProgressIndicator(),
      ),
    );
  }
}
