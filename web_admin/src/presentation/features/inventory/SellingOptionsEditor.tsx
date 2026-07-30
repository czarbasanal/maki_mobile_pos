import { useState } from 'react';
import { PlusIcon, TrashIcon } from '@heroicons/react/24/outline';
import type { SellingOption } from '@/domain/entities/SellingOption';
import { sellingOptionPricePerPiece } from '@/domain/entities/SellingOption';
import {
  MAX_SELLING_OPTIONS,
  MAX_SELLING_OPTION_LABEL,
  validateSellingOptions,
} from '@/domain/products/sellingOptions';
import { formatMoney } from '@/core/utils/money';

interface SellingOptionsEditorProps {
  /** The product's current selling options, in display order. */
  value: SellingOption[];
  /** Called with the full next list on every edit, add, or remove. */
  onChange: (next: SellingOption[]) => void;
  /** The product's own per-unit cost — the margin caption on each row is
   *  computed against this, not against the product's selling price. */
  unitCost: number;
  /** The product's stock unit (e.g. "pcs"), shown next to the pieces field. */
  unit: string;
  /** Whether the cost-derived "% margin" segment of each row's caption may
   *  be shown. The per-piece price itself is never cost-derived and is
   *  always shown regardless of this flag.
   *
   *  Callers should pass exactly the same condition the host form already
   *  uses to gate its own cost-derived margin display — an admin who has
   *  chosen to keep the raw cost hidden this session could otherwise
   *  back-solve unitCost from the per-piece price and a visible margin
   *  percentage, defeating that same reveal toggle. Defaults to true. */
  showMargin?: boolean;
}

/**
 * Authoring UI for a product's optional selling options — e.g. a pulley ball
 * packed by 6 sold "By 6" (₱600) or "By 3" (₱330) out of one piece-counted
 * stock pool.
 *
 * Controlled: this component holds no list state itself. Every edit —
 * typing a field, adding a row, removing a row — calls `onChange` with the
 * next full list; the caller owns the state and feeds it back in.
 *
 * Neutral by default: option rows are plain data entry, no color coding.
 * Color in this app carries status semantics only — the sole exception is
 * the validation message below the list, which reuses the app's existing
 * error text treatment.
 */
export function SellingOptionsEditor({
  value,
  onChange,
  unitCost,
  unit,
  showMargin = true,
}: SellingOptionsEditorProps) {
  const error = validateSellingOptions(value);
  // >= rather than === : a defensive superset in case the list ever arrives
  // already over the cap (e.g. legacy data) — the add control should stay
  // hidden rather than allow piling on more.
  const atCap = value.length >= MAX_SELLING_OPTIONS;

  const updateAt = (index: number, patch: Partial<SellingOption>) => {
    onChange(value.map((option, i) => (i === index ? { ...option, ...patch } : option)));
  };

  const add = () => {
    onChange([...value, { id: crypto.randomUUID(), label: '', pieces: 1, price: 0 }]);
  };

  const removeAt = (index: number) => {
    onChange(value.filter((_, i) => i !== index));
  };

  return (
    <div className="space-y-tk-sm">
      {value.map((option, index) => (
        <SellingOptionRow
          key={option.id}
          option={option}
          unitCost={unitCost}
          unit={unit}
          showMargin={showMargin}
          onLabelChange={(label) => updateAt(index, { label })}
          onPiecesChange={(pieces) => updateAt(index, { pieces })}
          onPriceChange={(price) => updateAt(index, { price })}
          onRemove={() => removeAt(index)}
        />
      ))}

      {!atCap ? (
        <button
          type="button"
          onClick={add}
          className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-sm py-[4px] text-[12px] text-light-text-secondary hover:bg-light-subtle"
        >
          <PlusIcon className="h-3.5 w-3.5" /> Add option
        </button>
      ) : null}

      {error ? <p className="text-[12px] text-error">{error}</p> : null}
    </div>
  );
}

/** Digits-only parse with a rejectable fallback. A cleared or unparseable
 *  field must still round-trip through `onChange` as 0 — which
 *  `validateSellingOptions` rejects — rather than being skipped, or the
 *  entity would silently keep its last valid value while the field shows
 *  empty and a save would go through with the stale number. */
function parsePieces(raw: string): number {
  const trimmed = raw.trim();
  if (trimmed === '') return 0;
  const n = Number(trimmed);
  return Number.isInteger(n) && n >= 0 ? n : 0;
}

/** Same reasoning as {@link parsePieces}: a clear must zero the entity, not
 *  silently keep the stale price. */
function parsePrice(raw: string): number {
  const trimmed = raw.trim();
  if (trimmed === '') return 0;
  const n = Number(trimmed);
  return Number.isFinite(n) && n >= 0 ? n : 0;
}

const fieldCls =
  'min-w-0 flex-1 rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px] text-light-text outline-none focus:border-light-text';

function SellingOptionRow({
  option,
  unitCost,
  unit,
  showMargin,
  onLabelChange,
  onPiecesChange,
  onPriceChange,
  onRemove,
}: {
  option: SellingOption;
  unitCost: number;
  unit: string;
  showMargin: boolean;
  onLabelChange: (label: string) => void;
  onPiecesChange: (pieces: number) => void;
  onPriceChange: (price: number) => void;
  onRemove: () => void;
}) {
  // Pieces/price are string-backed locally, mirroring LaborSection's
  // `feeText` pattern — the input's own text is the source of truth for
  // display. It is never re-derived from `option` on every render: doing
  // so would mean that clearing the field, which propagates 0 up, redraws
  // the box as "0" and the very next keystroke ("6") lands as "06" instead
  // of replacing it.
  const [piecesText, setPiecesText] = useState(String(option.pieces));
  const [priceText, setPriceText] = useState(option.price > 0 ? String(option.price) : '');

  // The per-piece price is arithmetic on the option's own fields, never on
  // unitCost — always shown regardless of showMargin. The margin half IS
  // cost-derived (unitCost is back-solvable from perPiece + this
  // percentage), so it alone is gated.
  const perPiece = sellingOptionPricePerPiece(option);
  const marginPercent = perPiece === 0 ? 0 : ((perPiece - unitCost) / perPiece) * 100;
  const caption = showMargin
    ? `${formatMoney(perPiece)}/pc · ${Math.round(marginPercent)}% margin`
    : `${formatMoney(perPiece)}/pc`;

  return (
    <div className="space-y-tk-xs rounded-lg border border-light-hairline bg-light-card p-tk-md">
      <div className="flex items-start gap-tk-sm">
        <input
          type="text"
          value={option.label}
          onChange={(e) => onLabelChange(e.target.value)}
          maxLength={MAX_SELLING_OPTION_LABEL}
          placeholder="e.g. By 6"
          aria-label="Label"
          className={fieldCls}
        />
        <button
          type="button"
          onClick={onRemove}
          aria-label="Remove option"
          className="shrink-0 text-light-text-hint hover:text-error"
        >
          <TrashIcon className="h-4 w-4" />
        </button>
      </div>

      <div className="flex items-center gap-tk-md">
        <div className="flex flex-1 items-center gap-tk-xs">
          <span className="shrink-0 text-[12px] text-light-text-secondary">Pieces</span>
          <input
            type="number"
            min={0}
            step="1"
            value={piecesText}
            onChange={(e) => {
              const raw = e.target.value;
              setPiecesText(raw);
              onPiecesChange(parsePieces(raw));
            }}
            aria-label="Pieces"
            className={fieldCls}
          />
          <span className="shrink-0 text-[11px] text-light-text-hint">{unit}</span>
        </div>
        <div className="flex flex-1 items-center gap-tk-xs">
          <span className="shrink-0 text-[12px] text-light-text-secondary">Price</span>
          <input
            type="number"
            min={0}
            step="0.01"
            value={priceText}
            onChange={(e) => {
              const raw = e.target.value;
              setPriceText(raw);
              onPriceChange(parsePrice(raw));
            }}
            aria-label="Price"
            className={fieldCls}
          />
        </div>
      </div>

      <p className="text-[12px] text-light-text-hint">{caption}</p>
    </div>
  );
}
