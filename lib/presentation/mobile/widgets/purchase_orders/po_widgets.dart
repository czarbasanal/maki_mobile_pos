import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Small building blocks shared by the redesigned purchase-order screens
/// (list · new · detail). Mock: design/design_handoff_purchase_orders.

/// 40px neutral glyph tile — list card + detail header.
class PoGlyphTile extends StatelessWidget {
  const PoGlyphTile({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.neutralTileFill(dark),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// Bordered square icon button — the 26px stepper-pill cells ([−] [+] [×])
/// and the 30px params cover stepper. Disabled = null [onTap] (glyph fades
/// to hint).
class PoStepperButton extends StatelessWidget {
  const PoStepperButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 26,
    this.radius = 8,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: dark ? AppColors.darkSurfaceMuted : Colors.white,
          border: Border.all(
            color: dark ? AppColors.darkInputBorder : AppColors.lightInputBorder,
          ),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Icon(
          icon,
          size: 14,
          color: onTap != null
              ? theme.colorScheme.onSurfaceVariant
              : (dark ? AppColors.darkTextHint : AppColors.lightTextHint),
        ),
      ),
    );
  }
}

/// 40px quantity badge on detail item rows — primary outline while the PO is
/// editable (draft), neutral tint once locked.
class PoQtyBadge extends StatelessWidget {
  const PoQtyBadge({super.key, required this.quantity, required this.locked});

  final int quantity;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: locked
          ? BoxDecoration(
              color: AppColors.neutralTileFill(dark),
              borderRadius: BorderRadius.circular(10),
            )
          : BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary, width: 1.4),
              borderRadius: BorderRadius.circular(10),
            ),
      child: Text(
        '${quantity}x',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: locked
              ? theme.colorScheme.onSurfaceVariant
              : theme.colorScheme.primary,
        ),
      ),
    );
  }
}

/// Amber inline note (cap warning) — mock-exact palette via AppColors.amberNote*.
class PoAmberNote extends StatelessWidget {
  const PoAmberNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.amberNoteFill(dark),
        border: Border.all(color: AppColors.amberNoteBorder(dark)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(LucideIcons.triangleAlert,
                size: 15, color: AppColors.amberNoteIcon(dark)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.45,
                color: AppColors.amberNoteText(dark),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header row — 16px glyph · 13/600 label · right-aligned trailing.
class PoSectionHeader extends StatelessWidget {
  const PoSectionHeader({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: muted),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    dark ? AppColors.darkTextHint : AppColors.lightTextHint,
              ),
            ),
        ],
      ),
    );
  }
}

/// Pinned-footer surface — white card + soft up-shadow in light, darkCard +
/// hairline top border in dark (mock footer elevation).
BoxDecoration poFooterDecoration(bool dark) => BoxDecoration(
      color: dark ? AppColors.darkCard : Colors.white,
      border: dark
          ? const Border(top: BorderSide(color: AppColors.darkHairline))
          : null,
      boxShadow: [
        BoxShadow(
          color: dark ? const Color(0x66000000) : const Color(0x0F111C1D),
          offset: const Offset(0, -4),
          blurRadius: 16,
        ),
      ],
    );
