import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Void-reason picker shared by the admin Void Sale dialog and the
/// cashier/staff Request Void dialog: a dropdown of the admin-managed void
/// reasons, with a free-text detail field revealed when "Other" is picked.
///
/// When the reason list is empty or fails to load, the field falls back to
/// plain free text so a void/request is never blocked on the admin list —
/// the old free-text behavior of the request dialog.
///
/// Parents own the selection state and the detail controller, wrap the field
/// in a [Form], and resolve the submitted reason via [resolveReason].
class VoidReasonField extends ConsumerWidget {
  const VoidReasonField({
    super.key,
    required this.selectedReason,
    required this.onChanged,
    required this.detailController,
  });

  final String? selectedReason;
  final ValueChanged<String?> onChanged;
  final TextEditingController detailController;

  /// Free-text detail is revealed only when this option is picked.
  /// Admin must keep this entry in the void-reasons list (seeded by default).
  static const String otherSentinel = 'Other';

  static bool isOther(String? reason) => reason == otherSentinel;

  /// The reason string to submit: the picked name, or the trimmed free-text
  /// detail when "Other" is picked — or when nothing is picked, which only
  /// passes validation in the free-text fallback (empty/unloadable list).
  static String resolveReason(String? selected, String detailText) =>
      (selected == null || isOther(selected))
          ? detailText.trim()
          : selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reasonsAsync =
        ref.watch(activeCategoriesProvider(CategoryKind.voidReason));
    return reasonsAsync.when(
      data: (reasons) {
        final names = reasons.map((c) => c.name).toList();
        // Guard against duplicate names (Firestore allows it; dropdowns
        // don't).
        final uniqueNames = <String>{...names}.toList();
        if (uniqueNames.isEmpty) {
          return _freeTextFallback(
            theme,
            'No void reasons configured yet — type the reason below. An '
            'admin can seed the list under Settings → Manage Lists → Void.',
          );
        }
        return _dropdown(uniqueNames);
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => _freeTextFallback(
        theme,
        'Could not load the void-reason list — type the reason below.',
      ),
    );
  }

  Widget _dropdown(List<String> uniqueNames) {
    // Reset selection if a previously-picked reason was removed/deactivated.
    final currentValue =
        (selectedReason != null && uniqueNames.contains(selectedReason))
            ? selectedReason
            : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdown<String>(
          initialValue: currentValue,
          decoration: const InputDecoration(
            labelText: 'Reason',
            prefixIcon: Icon(LucideIcons.tag),
          ),
          items: uniqueNames
              .map(
                (name) => DropdownMenuItem<String>(
                  value: name,
                  child: Text(name),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (!isOther(value)) {
              detailController.clear();
            }
            onChanged(value);
          },
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Please pick a reason' : null,
        ),
        if (isOther(selectedReason)) ...[
          const SizedBox(height: 16),
          _detailField(
            labelText: 'Reason details',
            hintText: 'Enter detailed reason...',
          ),
        ],
      ],
    );
  }

  Widget _freeTextFallback(ThemeData theme, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _detailField(
          labelText: 'Reason',
          hintText: 'Why should this sale be voided?',
        ),
      ],
    );
  }

  Widget _detailField({required String labelText, required String hintText}) {
    return TextFormField(
      style: AppTextStyles.fieldInput,
      controller: detailController,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: const Icon(LucideIcons.squarePen),
      ),
      maxLines: 2,
      maxLength: 200,
      validator: (value) {
        final v = value?.trim() ?? '';
        if (v.isEmpty) return 'Please provide a reason';
        if (v.length < 5) return 'Reason must be at least 5 characters';
        return null;
      },
    );
  }
}
