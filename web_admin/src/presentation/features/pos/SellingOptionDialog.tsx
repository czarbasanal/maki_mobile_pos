// Must-pick-one selling-option picker. Every path that puts a product on a
// ticket calls this whenever productHasSellingOptions(product) is true — the
// base Product.price is not directly sellable once a product carries options.
// Always shown even for a single option: this dialog is the only surface
// where the whole-set price is visible before it lands on the ticket.
//
// Mirrors lib/presentation/mobile/widgets/pos/selling_option_sheet.dart.

import { Dialog } from '@/presentation/components/common/Dialog';
import type { Product } from '@/domain/entities/Product';
import type { SellingOption } from '@/domain/entities/SellingOption';
import { sellingOptionPricePerPiece, sellingOptionRateSuffix } from '@/domain/entities/SellingOption';
import { formatMoney } from '@/core/utils/money';

export function SellingOptionDialog({
  product,
  onPick,
  onClose,
}: {
  product: Product;
  onPick: (option: SellingOption) => void;
  onClose: () => void;
}) {
  return (
    <Dialog
      open
      onClose={onClose}
      title={product.name}
      description={`${product.sku} · ${product.quantity} ${product.unit} on hand`}
    >
      {/* The shared Dialog locks body scroll while open, and this panel has
          no scroll of its own — with enough options (cap is 10) rows past
          the fold would be unreachable without this cap + its own scroll. */}
      <div className="max-h-[70vh] space-y-tk-sm overflow-y-auto">
        {product.sellingOptions.map((option) => {
          // The POS warns rather than blocks on low stock (see lowStockLines
          // elsewhere in the register) — this row stays clickable either way.
          const shortOnStock = option.pieces > product.quantity;
          return (
            <button
              key={option.id}
              type="button"
              onClick={() => onPick(option)}
              className="flex w-full items-center justify-between gap-tk-md rounded-md border border-light-hairline bg-light-subtle px-tk-md py-tk-sm text-left hover:bg-light-card"
            >
              <span>
                <span className="block text-bodySmall font-semibold text-light-text">{option.label}</span>
                <span className="mt-tk-xs flex items-center gap-tk-xs text-[12px] text-light-text-hint">
                  <span>
                    {option.pieces} {product.unit}
                  </span>
                  {shortOnStock ? <span className="text-warning-dark">⚠ Low stock</span> : null}
                </span>
              </span>
              <span className="text-right">
                <span className="block text-bodySmall font-semibold text-light-text">
                  {formatMoney(option.price)}
                </span>
                <span className="block text-[12px] text-light-text-hint">
                  {formatMoney(sellingOptionPricePerPiece(option))}/{sellingOptionRateSuffix(product.unit)}
                </span>
              </span>
            </button>
          );
        })}
      </div>

      <div className="mt-tk-md flex justify-end">
        <button
          type="button"
          onClick={onClose}
          className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
        >
          Cancel
        </button>
      </div>
    </Dialog>
  );
}
