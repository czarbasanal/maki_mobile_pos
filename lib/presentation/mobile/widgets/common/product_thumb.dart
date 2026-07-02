import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/app_colors.dart';

/// 40px product thumbnail: the product image when [imageUrl] is set,
/// otherwise a neutral rounded tile with the name's first letter.
/// Mirrors the leading-visual treatment used across the elevated theme.
class ProductThumb extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;

  const ProductThumb({
    super.key,
    required this.name,
    required this.imageUrl,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      // Decode at display size — web-admin uploads can be 1000–2000px.
      final cachePx = (size * MediaQuery.devicePixelRatioOf(context)).round();
      return ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Image.network(
          url,
          width: size,
          height: size,
          cacheWidth: cachePx,
          cacheHeight: cachePx,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(context),
        ),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Neutral tile in both themes — a thumbnail is not a primary
        // affordance, so it must not go gold in dark.
        color: AppColors.neutralTileFill(
          theme.brightness == Brightness.dark,
        ),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
