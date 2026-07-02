import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dialog.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_dropdown.dart';

/// Pick-or-add dropdown for the motorcycle model on a Job Order. Values are
/// canonical model names (String). Selecting "Add model…" creates/reuses a row
/// via [MotorcycleModelOperationsNotifier.resolveOrCreate] and reports the name.
class MotorcycleModelPicker extends ConsumerStatefulWidget {
  const MotorcycleModelPicker({
    super.key,
    required this.selectedModel,
    required this.onChanged,
  });

  final String? selectedModel;
  final void Function(String? model) onChanged;

  @override
  ConsumerState<MotorcycleModelPicker> createState() =>
      _MotorcycleModelPickerState();
}

class _MotorcycleModelPickerState extends ConsumerState<MotorcycleModelPicker> {
  static const _addNew = '__add_model__';

  /// Bumped after the "Add model…" flow so the underlying [AppDropdown]
  /// rebuilds fresh — resetting its display off the sentinel whether or not a
  /// model was actually added (handles cancel).
  int _rev = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeMotorcycleModelsProvider);
    return async.when(
      data: (models) {
        final names = models.map((m) => m.name).toList();
        // Keep a still-selected but deactivated / not-yet-streamed model visible.
        final extra = (widget.selectedModel != null &&
                !names.contains(widget.selectedModel))
            ? [widget.selectedModel!]
            : const <String>[];
        return AppDropdown<String>(
          key: ValueKey('$_rev|${widget.selectedModel}'),
          initialValue: widget.selectedModel,
          decoration: const InputDecoration(
            labelText: 'Motorcycle model',
            prefixIcon: Icon(LucideIcons.bike),
          ),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('— None —')),
            for (final n in [...extra, ...names])
              DropdownMenuItem<String>(value: n, child: Text(n)),
            const DropdownMenuItem<String>(
              value: _addNew,
              child: Text('➕ Add model…'),
            ),
          ],
          onChanged: (value) {
            if (value == _addNew) {
              _onAddNew();
            } else {
              widget.onChanged(value);
            }
          },
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Text('Failed to load models: $e'),
    );
  }

  Future<void> _onAddNew() async {
    final name = await _showAddDialog();
    if (!mounted) return;
    setState(() => _rev++); // reset the dropdown display off the sentinel
    if (name != null) widget.onChanged(name);
  }

  Future<String?> _showAddDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierColor: AppDialog.scrimColor(
          Theme.of(context).brightness == Brightness.dark),
      builder: (ctx) => AppDialog(
        title: 'Add motorcycle model',
        leadingIcon: LucideIcons.bike,
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Model',
            hintText: 'e.g. Nmax, Click 125i',
          ),
        ),
        actions: [
          appDialogCancel(ctx, 'Cancel', onTap: () => Navigator.pop(ctx)),
          appDialogPrimary(ctx, 'Add', onTap: () async {
            final canonical = await ref
                .read(motorcycleModelOperationsProvider.notifier)
                .resolveOrCreate(controller.text);
            if (ctx.mounted) Navigator.pop(ctx, canonical);
          }),
        ],
      ),
    );
  }
}
