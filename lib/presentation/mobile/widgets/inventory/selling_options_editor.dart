import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:maki_mobile_pos/core/constants/app_constants.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/selling_options.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

const _uuid = Uuid();

/// Authoring UI for a product's optional selling options — e.g. a pulley
/// ball packed by 6 sold "By 6" (₱600) or "By 3" (₱330) out of one
/// piece-counted stock pool.
///
/// Controlled: this widget never holds [value] itself. Every edit — typing
/// a field, adding a row, removing a row — calls [onChanged] with the next
/// full list; the caller owns the state and feeds it back in.
///
/// Neutral by default: each row is a plain [AppCard], no color coding. Color
/// in this app carries status semantics only, and an option row is plain
/// data entry — the sole exception is the validation message below the
/// list, which reuses the app's existing error text style.
class SellingOptionsEditor extends StatefulWidget {
  const SellingOptionsEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.unitCost,
    required this.unit,
    this.showMargin = true,
  });

  /// The product's current selling options, in display order.
  final List<SellingOptionEntity> value;

  /// Called with the full next list on every edit, add, or remove.
  final ValueChanged<List<SellingOptionEntity>> onChanged;

  /// The product's own per-unit cost — the margin caption on each row is
  /// computed against this, not against the product's selling price.
  final double unitCost;

  /// The product's stock unit (e.g. "pcs"), shown as the pieces field's
  /// suffix so the count reads unambiguously.
  final String unit;

  /// Whether the cost-derived "% margin" segment of each row's caption may
  /// be shown. The per-piece price itself is never cost-derived and is
  /// always shown regardless of this flag.
  ///
  /// Callers should pass exactly the same condition the host form already
  /// uses to gate its own cost-derived margin display (`_marginLine`'s
  /// `showCostField`) — an admin who has chosen to keep the raw cost hidden
  /// this session can back-solve `unitCost` from the per-piece price and a
  /// visible margin percentage, defeating that same reveal toggle.
  final bool showMargin;

  @override
  State<SellingOptionsEditor> createState() => _SellingOptionsEditorState();
}

class _SellingOptionsEditorState extends State<SellingOptionsEditor> {
  late List<_RowControllers> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.value.map(_RowControllers.fromOption).toList();
  }

  @override
  void didUpdateWidget(covariant SellingOptionsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reconcileControllers();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  /// Keeps exactly one [_RowControllers] per option id, reusing the existing
  /// controller set whenever an id survives between builds so an in-progress
  /// edit's cursor/focus is never disturbed by a rebuild triggered by our own
  /// [widget.onChanged] call. Only ids that appeared (a new row) or
  /// disappeared (a removed row) cause a controller to be created/disposed —
  /// an existing controller's text is never overwritten, since every field
  /// edit round-trips through [widget.onChanged] and back down as the same
  /// value.
  void _reconcileControllers() {
    final byId = {for (final row in _rows) row.id: row};
    _rows = widget.value.map((option) {
      final existing = byId.remove(option.id);
      return existing ?? _RowControllers.fromOption(option);
    }).toList();
    for (final leftover in byId.values) {
      leftover.dispose();
    }
  }

  void _updateAt(
    int index,
    SellingOptionEntity Function(SellingOptionEntity) update,
  ) {
    final next = [...widget.value];
    next[index] = update(next[index]);
    widget.onChanged(next);
  }

  void _add() {
    widget.onChanged([
      ...widget.value,
      SellingOptionEntity(id: _uuid.v4(), label: '', pieces: 1, price: 0),
    ]);
  }

  void _removeAt(int index) {
    final next = [...widget.value]..removeAt(index);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final error = validateSellingOptions(widget.value);
    // >= rather than == : a deliberate defensive superset in case the list
    // ever arrives already over the cap (e.g. legacy data) — the add button
    // should stay hidden rather than allow piling on more.
    final atCap = widget.value.length >= kMaxSellingOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.value.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _OptionRow(
            key: Key('selling-option-row-$i'),
            index: i,
            option: widget.value[i],
            controllers: _rows[i],
            unitCost: widget.unitCost,
            unit: widget.unit,
            showMargin: widget.showMargin,
            onLabelChanged: (v) => _updateAt(i, (o) => o.copyWith(label: v)),
            onPiecesChanged: (v) => _updateAt(i, (o) => o.copyWith(pieces: v)),
            onPriceChanged: (v) => _updateAt(i, (o) => o.copyWith(price: v)),
            onRemove: () => _removeAt(i),
          ),
        ],
        if (!atCap) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const Key('add-selling-option'),
            onPressed: _add,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Add selling option'),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(error, style: AppTextStyles.error),
        ],
      ],
    );
  }
}

/// Bundles the three [TextEditingController]s for one row, keyed by the
/// option's stable [id] so [_SellingOptionsEditorState._reconcileControllers]
/// can match rows across rebuilds instead of recreating them (and losing
/// focus/cursor) on every keystroke.
class _RowControllers {
  _RowControllers({
    required this.id,
    required this.label,
    required this.pieces,
    required this.price,
  });

  factory _RowControllers.fromOption(SellingOptionEntity option) {
    return _RowControllers(
      id: option.id,
      label: TextEditingController(text: option.label),
      pieces: TextEditingController(text: option.pieces.toString()),
      price: TextEditingController(
        text: option.price > 0 ? option.price.toStringAsFixed(2) : '',
      ),
    );
  }

  final String id;
  final TextEditingController label;
  final TextEditingController pieces;
  final TextEditingController price;

  void dispose() {
    label.dispose();
    pieces.dispose();
    price.dispose();
  }
}

/// One selling-option row: label, pieces, price, a remove button, and a
/// derived caption. Fields are locally controlled ([controllers]) but the
/// values shown for the per-piece price / margin caption always come from
/// [option] (the source of truth passed down by the parent), so the caption
/// updates the moment a keystroke round-trips through [onChanged].
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.index,
    required this.option,
    required this.controllers,
    required this.unitCost,
    required this.unit,
    required this.showMargin,
    required this.onLabelChanged,
    required this.onPiecesChanged,
    required this.onPriceChanged,
    required this.onRemove,
  });

  final int index;
  final SellingOptionEntity option;
  final _RowControllers controllers;
  final double unitCost;
  final String unit;
  final bool showMargin;
  final ValueChanged<String> onLabelChanged;
  final ValueChanged<int> onPiecesChanged;
  final ValueChanged<double> onPriceChanged;
  final VoidCallback onRemove;

  /// Margin of the option's per-piece price over the product's own unit
  /// cost, in the same "(price - cost) / price * 100" shape as
  /// [ProductEntity.profitMargin]. Zero when the per-piece price is zero
  /// (an incomplete row) so the caption never divides by zero.
  double get _marginPercent {
    final perPiece = option.pricePerPiece;
    if (perPiece == 0) return 0;
    return ((perPiece - unitCost) / perPiece) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return AppCard(
      radius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: Key('selling-option-label-$index'),
                  style: AppTextStyles.fieldInput,
                  controller: controllers.label,
                  maxLength: kMaxSellingOptionLabel,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    hintText: 'e.g. By 6',
                    counterText: '',
                  ),
                  onChanged: onLabelChanged,
                ),
              ),
              IconButton(
                key: Key('remove-selling-option-$index'),
                icon: const Icon(LucideIcons.x, size: 18),
                color: muted,
                tooltip: 'Remove option',
                onPressed: onRemove,
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: Key('selling-option-pieces-$index'),
                  style: AppTextStyles.fieldInput,
                  controller: controllers.pieces,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Pieces',
                    suffixText: unit,
                  ),
                  onChanged: (v) {
                    // A cleared field must still round-trip through
                    // onChanged (as 0, which validateSellingOptions rejects)
                    // rather than being skipped — otherwise the entity keeps
                    // its last valid value while the field shows empty, and
                    // an admin who thinks they cleared it silently saves the
                    // stale number. Mirrors the label field's unconditional
                    // propagation just above.
                    final parsed = int.tryParse(v.trim()) ?? 0;
                    onPiecesChanged(parsed);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  key: Key('selling-option-price-$index'),
                  style: AppTextStyles.fieldInput,
                  controller: controllers.price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    prefixText: '${AppConstants.currencySymbol} ',
                  ),
                  onChanged: (v) {
                    // Same reasoning as the pieces field above: a clear must
                    // zero the entity, not silently keep the stale price.
                    final parsed = double.tryParse(v.trim()) ?? 0;
                    onPriceChanged(parsed);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            // The per-piece price is arithmetic on the option's own fields,
            // never on unitCost — always shown. The margin half IS
            // cost-derived (unitCost is back-solvable from perPiece + this
            // percentage), so it's gated on [showMargin], mirroring the
            // host form's own `showCostField` gate on its margin line.
            showMargin
                ? '${option.pricePerPiece.toCurrency()}/$unit · '
                    '${_marginPercent.toStringAsFixed(0)}% margin'
                : '${option.pricePerPiece.toCurrency()}/$unit',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}
