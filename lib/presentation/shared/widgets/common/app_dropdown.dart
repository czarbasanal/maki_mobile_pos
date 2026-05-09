import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Project-wide dropdown wrapper.
///
/// Replaces [DropdownButtonFormField]. Renders an input-decoration-styled
/// button whose tap opens a Material 3 [MenuAnchor] popup. The popup is
/// width-capped (default: button width minus a margin per side, hard-capped
/// at 360 px on tablets) and centered under the button — which is the
/// behavior the legacy widget cannot provide because its popup width is
/// always anchored to the button.
///
/// Migration from [DropdownButtonFormField] is mechanical: the public API
/// (initialValue / items / onChanged / decoration / validator) matches.
/// The same [DropdownMenuItem] children are accepted; their `child` is
/// rendered both in the closed selection display and in each menu row.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    this.initialValue,
    required this.items,
    this.onChanged,
    this.decoration,
    this.validator,
    this.menuMaxWidth = 360,
    this.menuHorizontalMargin = 16,
  });

  /// Initial selected value. May be null for "no selection".
  final T? initialValue;

  /// Items to show in the menu. Reuses [DropdownMenuItem] for migration
  /// compatibility — only `value` and `child` are used.
  final List<DropdownMenuItem<T>> items;

  /// Selection callback. When null, the dropdown is read-only/disabled.
  final ValueChanged<T?>? onChanged;

  /// Input decoration for the closed button (label, prefix icon, etc.).
  final InputDecoration? decoration;

  /// Optional validator integrated via [FormField].
  final FormFieldValidator<T>? validator;

  /// Hard cap on popup width — applied on tablets / wide screens so the
  /// popup never feels oversized. Default 360.
  final double menuMaxWidth;

  /// Horizontal inset (per side) between the button's left/right edges and
  /// the popup's left/right edges. Default 16.
  final double menuHorizontalMargin;

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      initialValue: initialValue,
      validator: validator,
      builder: (state) {
        void handleSelect(T? newValue) {
          state.didChange(newValue);
          onChanged?.call(newValue);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final buttonWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.of(context).size.width;
            final menuWidth = math.min<double>(
              math.max<double>(buttonWidth - 2 * menuHorizontalMargin, 0),
              menuMaxWidth,
            );
            return _AppDropdownButton<T>(
              state: state,
              items: items,
              decoration: decoration ?? const InputDecoration(),
              menuWidth: menuWidth,
              enabled: onChanged != null,
              onSelect: handleSelect,
            );
          },
        );
      },
    );
  }
}

class _AppDropdownButton<T> extends StatefulWidget {
  const _AppDropdownButton({
    required this.state,
    required this.items,
    required this.decoration,
    required this.menuWidth,
    required this.enabled,
    required this.onSelect,
  });

  final FormFieldState<T> state;
  final List<DropdownMenuItem<T>> items;
  final InputDecoration decoration;
  final double menuWidth;
  final bool enabled;
  final ValueChanged<T?> onSelect;

  @override
  State<_AppDropdownButton<T>> createState() => _AppDropdownButtonState<T>();
}

class _AppDropdownButtonState<T> extends State<_AppDropdownButton<T>> {
  final MenuController _controller = MenuController();
  bool _menuOpen = false;

  Widget? _selectedChild() {
    for (final item in widget.items) {
      if (item.value == widget.state.value) return item.child;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decoration = widget.decoration.copyWith(
      errorText: widget.state.errorText,
    );
    final selected = _selectedChild();

    return MenuAnchor(
      controller: _controller,
      style: MenuStyle(
        alignment: Alignment.bottomCenter,
        minimumSize: WidgetStatePropertyAll(Size(widget.menuWidth, 0)),
        maximumSize:
            WidgetStatePropertyAll(Size(widget.menuWidth, double.infinity)),
      ),
      onOpen: () => setState(() => _menuOpen = true),
      onClose: () => setState(() => _menuOpen = false),
      menuChildren: widget.items.map((item) {
        return MenuItemButton(
          onPressed: widget.enabled ? () => widget.onSelect(item.value) : null,
          child: SizedBox(
            width: widget.menuWidth,
            child: item.child,
          ),
        );
      }).toList(),
      child: InkWell(
        onTap: widget.enabled
            ? () {
                if (_controller.isOpen) {
                  _controller.close();
                } else {
                  _controller.open();
                }
              }
            : null,
        borderRadius: BorderRadius.circular(8),
        child: InputDecorator(
          decoration: decoration,
          // The field is "empty" only when no item matches the current
          // value — including null-valued items (e.g. "All categories").
          // Otherwise the label must float up to make room for the
          // selected child, or it overlaps with the value text.
          isEmpty: selected == null,
          isFocused: _menuOpen,
          child: Row(
            children: [
              Expanded(
                child: selected ?? const SizedBox.shrink(),
              ),
              Icon(
                _menuOpen
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
