import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';

/// Destructive "Delete draft?" confirm, built on the shared [AppDialog] shell.
///
/// Red leading chip (`trash-2`) + a recessed preview box showing the draft's
/// item count and grand total + the "cannot be undone" warning line. Delete
/// stays red (`#F44336`) in both themes; [onConfirm] fires after the dialog
/// pops on the primary action.
Future<void> showDeleteDraftDialog(
  BuildContext context,
  DraftEntity draft,
  VoidCallback onConfirm,
) async {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: AppDialog.scrimColor(dark),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final muted = theme.colorScheme.onSurfaceVariant;
      final hairline =
          dark ? AppColors.darkInputBorder : AppColors.lightHairline;
      final mutedFill = dark ? AppColors.darkCanvas : AppColors.lightSurfaceMuted;
      final errorColor = dark ? AppColors.errorOnDark : AppColors.error;

      return AppDialog(
        title: 'Delete draft?',
        intent: AppDialogIntent.destructive,
        leadingIcon: LucideIcons.trash2,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delete "${draft.name}"?',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: appDialogBodyColor(dark),
              ),
            ),
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: mutedFill,
                border: Border.all(color: hairline),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.totalItemCount == 1
                        ? '1 item'
                        : '${draft.totalItemCount} items',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total ${draft.grandTotal.toCurrency()}',
                    style: TextStyle(fontSize: 12.5, color: muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: errorColor,
              ),
            ),
          ],
        ),
        actions: [
          appDialogCancel(ctx, 'Cancel',
              onTap: () => Navigator.of(ctx).pop(false)),
          // Delete stays red in both themes.
          appDialogPrimary(ctx, 'Delete',
              color: AppColors.error,
              onTap: () => Navigator.of(ctx).pop(true)),
        ],
      );
    },
  );

  if (confirmed == true) onConfirm();
}
