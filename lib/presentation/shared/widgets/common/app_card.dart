import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Soft-shadow surface for the refreshed theme.
///
/// Light: white fill + [AppShadows.card] (no border). Dark: [AppColors.darkCard]
/// fill + 1px [AppColors.darkHairline] border (no shadow — the border carries
/// the separation). Centralizes the light=shadow / dark=border duality so
/// callers never re-derive `isDark`/hairline. Replaces Material [Card] and
/// hand-rolled soft-shadow Containers across the sale flow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppRadius.lg,
    this.onTap,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;

  /// Clip the child to the rounded rect (e.g. a list whose rows must not
  /// bleed past the corners). The shadow is drawn on the outer container so
  /// it is never clipped.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);

    Widget inner = child;
    if (padding != null) {
      inner = Padding(padding: padding!, child: inner);
    }
    if (clipBehavior != Clip.none) {
      inner = ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: clipBehavior,
        child: inner,
      );
    }
    if (onTap != null) {
      inner = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: borderRadius, child: inner),
      );
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: borderRadius,
        border: isDark ? Border.all(color: AppColors.darkHairline) : null,
        boxShadow: AppShadows.card(dark: isDark),
      ),
      child: inner,
    );
  }
}
