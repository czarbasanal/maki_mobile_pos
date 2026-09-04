// Audit-grade stock adjustment (spec 2026-09-04 / handoff guide): a preview
// strip shows the resulting on-hand BEFORE the user commits, mode is three
// chips (not a dropdown), quantity is a stepper, and a reason is required —
// the record this modal produces is what makes Receiving, sales and
// adjustments reconcilable. `Set to` is admin-only: it can erase a
// discrepancy without recording what the discrepancy was.
import { useEffect, useRef, useState } from 'react';
import { Dialog } from '@/presentation/components/common/Dialog';
import { Spinner } from '@/presentation/components/common/LoadingView';
import { Chip } from '@/presentation/components/ui/Chip';
import { useActiveAdjustmentReasons } from '@/presentation/hooks/useAdjustmentReasons';
import { useSeedAdjustmentReasons } from '@/presentation/hooks/useAdjustmentReasonMutations';
import { useApplyStockAdjustment } from '@/presentation/hooks/useProductMutations';
import { useAuthStore } from '@/presentation/stores/authStore';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { StaleOnHandError } from '@/domain/products/adjustmentErrors';
import {
  adjustmentValidity,
  parseStockQty,
  resolveStockChange,
  type AdjustmentDraft,
  type StockMode,
} from '@/domain/products/resolveStockChange';
import { displaySku } from '@/domain/products/sku';
import type { Product } from '@/domain/entities';
import { cn } from '@/core/utils/cn';

const MODES: { value: StockMode; label: string }[] = [
  { value: 'add', label: 'Add' },
  { value: 'remove', label: 'Remove' },
  { value: 'set', label: 'Set to' },
];

export interface StockAdjustmentResult {
  before: number;
  after: number;
  delta: number;
}

export function AdjustStockDialog({
  product,
  open,
  onClose,
  onApplied,
}: {
  product: Product;
  open: boolean;
  onClose: () => void;
  /** Fired after a successful apply — the caller closes both modals and toasts. */
  onApplied: (result: StockAdjustmentResult) => void;
}) {
  const authUser = useAuthStore((s) => s.user);
  const isAdmin = !!authUser && hasPermission(authUser.role, Permission.editProduct);
  const availableModes = isAdmin ? MODES : MODES.filter((m) => m.value !== 'set');

  const [mode, setMode] = useState<StockMode>('add');
  const [qtyText, setQtyText] = useState('');
  const [onHand, setOnHand] = useState(product.quantity);
  const [reasonId, setReasonId] = useState<string | null>(null);
  const [note, setNote] = useState('');
  const [staleNotice, setStaleNotice] = useState<string | null>(null);

  const { data: reasons } = useActiveAdjustmentReasons();
  const seed = useSeedAdjustmentReasons();
  const seededRef = useRef(false);
  const apply = useApplyStockAdjustment();
  const qtyRef = useRef<HTMLInputElement>(null);

  // Full reset on every open — a remembered quantity from the last
  // adjustment is how a stray Enter writes the wrong number (guide §3).
  useEffect(() => {
    if (!open) {
      seededRef.current = false;
      return;
    }
    setMode('add');
    setQtyText('');
    setOnHand(product.quantity);
    setReasonId(null);
    setNote('');
    setStaleNotice(null);
    apply.reset();
    qtyRef.current?.focus();
    qtyRef.current?.select();
    // Deliberately keyed on `open` only (see guide §3) — `product` is read
    // fresh at the moment the dialog opens, not tracked as a re-run trigger.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  // First open with an empty reason list: seed the six defaults once and let
  // the live stream repaint the chips.
  useEffect(() => {
    if (!open || !reasons || reasons.length > 0 || seededRef.current) return;
    seededRef.current = true;
    seed.mutate();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, reasons]);

  const busy = apply.isPending;
  const qty = parseStockQty(qtyText);
  const after = qty === null ? onHand : resolveStockChange(mode, onHand, qty);
  const delta = qty === null ? 0 : after - onHand;
  const selectedReason = reasons?.find((r) => r.id === reasonId) ?? null;
  const draft: AdjustmentDraft = {
    mode,
    qty,
    onHand,
    reasonId,
    requiresNote: selectedReason?.requiresNote ?? false,
    note,
  };
  const validityMessage = adjustmentValidity(draft);
  const canApply = validityMessage === null && !busy;
  const negativeMessage = qty !== null && after < 0 ? validityMessage : null;
  const noteRequired = selectedReason?.requiresNote ?? false;
  const noteMissing = noteRequired && note.trim() === '';
  const generalError = apply.error && !(apply.error instanceof StaleOnHandError) ? apply.error.message : null;

  const step = (dir: 1 | -1) => {
    const cur = qty ?? 0;
    setQtyText(String(Math.max(0, cur + dir)));
  };

  const doApply = async () => {
    if (!canApply || qty === null || !selectedReason) return;
    try {
      const result = await apply.mutateAsync({
        id: product.id,
        productName: product.name,
        sku: product.sku,
        input: {
          mode,
          quantity: qty,
          expectedOnHand: onHand,
          reasonId: selectedReason.id,
          reasonName: selectedReason.name,
          note: note.trim() ? note.trim() : null,
        },
      });
      onApplied(result);
    } catch (e) {
      if (e instanceof StaleOnHandError) {
        setOnHand(e.currentOnHand);
        setStaleNotice(
          `Someone else moved this stock — on hand is now ${e.currentOnHand}. Review and apply again.`,
        );
      }
      // other errors surface via `generalError` below; inputs stay as typed
    }
  };

  const deltaLabel = qty === null ? '—' : `${delta >= 0 ? '+' : ''}${delta}`;
  const deltaToneClass =
    qty === null || delta === 0
      ? 'bg-surface-3 text-ink-3'
      : delta > 0
        ? 'bg-pos-soft text-pos'
        : 'bg-neg-soft text-neg';

  return (
    <Dialog
      open={open}
      onClose={() => {
        if (!busy) onClose();
      }}
      title="Adjust stock"
      description={`${product.name} · ${displaySku(product.sku)}`}
      dismissable={!busy}
    >
      <div
        className="space-y-tk-md"
        onKeyDown={(e) => {
          if (e.key === 'Enter' && !(e.target instanceof HTMLTextAreaElement)) {
            e.preventDefault();
            if (canApply) void doApply();
          }
        }}
      >
        {/* Preview strip — the whole point of the modal: show the number the
            user will land on, not the delta they typed. */}
        <div className="rounded-[11px] border border-line bg-surface-2 px-[14px] py-[12px]">
          <div className="flex items-center gap-3">
            <div className="min-w-0">
              <p className="text-[10px] font-semibold uppercase tracking-[1px] text-ink-3">On hand</p>
              <p className="font-mono text-[19px] font-semibold text-ink">
                {onHand} <span className="text-[12px] font-normal text-ink-3">{product.unit}</span>
              </p>
            </div>
            <span aria-hidden className="shrink-0 text-ink-3">→</span>
            <div className="min-w-0 flex-1">
              <p className="text-[10px] font-semibold uppercase tracking-[1px] text-ink-3">New quantity</p>
              <p
                className={cn(
                  'font-mono text-[19px] font-semibold',
                  qty === null ? 'text-ink-3' : after < 0 ? 'text-neg' : 'text-ink',
                )}
              >
                {qty === null ? '—' : after}
                {qty !== null ? <span className="text-[12px] font-normal text-ink-3"> {product.unit}</span> : null}
              </p>
            </div>
            <span
              className={cn(
                'shrink-0 rounded-pill px-2.5 py-[3px] font-mono text-[12px] font-semibold',
                deltaToneClass,
              )}
            >
              {deltaLabel}
            </span>
          </div>
        </div>

        {/* Movement — three (or two, for non-admins) equal chips. */}
        <div className={cn('grid gap-2', availableModes.length === 3 ? 'grid-cols-3' : 'grid-cols-2')}>
          {availableModes.map((m) => (
            <Chip key={m.value} active={mode === m.value} onClick={() => setMode(m.value)}>
              {m.label}
            </Chip>
          ))}
        </div>

        {/* Quantity — stepper, digits-only, unit as static text. */}
        <div className="flex flex-col gap-[6px]">
          <span className="text-[11.5px] font-semibold text-ink-2">
            {mode === 'set' ? 'Counted quantity' : 'Quantity'}
          </span>
          <div className="flex items-center gap-2">
            <button
              type="button"
              aria-label="Decrease quantity"
              disabled={busy}
              onClick={() => step(-1)}
              className="h-10 w-10 shrink-0 rounded-ctl border border-line text-ink hover:bg-surface-2 disabled:opacity-50"
            >
              −
            </button>
            <input
              ref={qtyRef}
              type="text"
              inputMode="numeric"
              aria-label={mode === 'set' ? 'Counted quantity' : 'Quantity'}
              value={qtyText}
              disabled={busy}
              onChange={(e) => setQtyText(e.target.value.replace(/[^0-9]/g, ''))}
              className="h-10 w-full rounded-ctl border border-line bg-surface-2 px-3 text-center font-mono text-[16px] text-ink outline-none focus:border-accent-line"
            />
            <button
              type="button"
              aria-label="Increase quantity"
              disabled={busy}
              onClick={() => step(1)}
              className="h-10 w-10 shrink-0 rounded-ctl border border-line text-ink hover:bg-surface-2 disabled:opacity-50"
            >
              +
            </button>
            <span className="shrink-0 text-[13px] text-ink-2">{product.unit}</span>
          </div>
          {negativeMessage ? <p className="text-[11.5px] text-neg">{negativeMessage}</p> : null}
        </div>

        {/* Reason — required. */}
        <div className="flex flex-col gap-[6px]">
          <span className="text-[11.5px] font-semibold text-ink-2">Reason</span>
          <div className="flex flex-wrap gap-2">
            {(reasons ?? []).map((r) => (
              <Chip key={r.id} active={reasonId === r.id} onClick={() => setReasonId(r.id)}>
                {r.name}
              </Chip>
            ))}
          </div>
        </div>

        {/* Note — required only for reasons that demand one; the requirement
            is visible before submit, not announced by an error. */}
        <div className="flex flex-col gap-[6px]">
          <span className="text-[11.5px] font-semibold text-ink-2">{noteRequired ? 'Note' : 'Note (optional)'}</span>
          <textarea
            rows={2}
            aria-label={noteRequired ? 'Note' : 'Note (optional)'}
            value={note}
            disabled={busy}
            onChange={(e) => setNote(e.target.value)}
            className={cn(
              'w-full resize-y rounded-ctl border bg-surface-2 px-3 py-2.5 text-[13px] text-ink outline-none transition-colors',
              noteMissing ? 'border-accent-line' : 'border-line focus:border-accent-line',
            )}
          />
        </div>

        {staleNotice ? (
          <p className="rounded-ctl border border-accent-line bg-accent-soft px-tk-md py-tk-sm text-ctl-sm text-accent-text">
            {staleNotice}
          </p>
        ) : null}
        {generalError ? (
          <p className="rounded-ctl border border-neg bg-neg-soft px-tk-md py-tk-sm text-ctl-sm text-neg">
            {generalError}
          </p>
        ) : null}

        {/* Footer — attributable-adjustment line, then Cancel / Apply. */}
        <div className="-mx-tk-lg -mb-tk-lg flex items-center gap-tk-sm border-t border-line-2 bg-surface-2 px-tk-lg py-tk-md">
          <span className="min-w-0 truncate text-[11.5px] text-ink-3">
            Recorded against {authUser?.displayName.trim() || 'You'} · today
          </span>
          <span className="ml-auto" />
          <button
            type="button"
            disabled={busy}
            onClick={onClose}
            className="shrink-0 rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-sm text-ink hover:bg-surface-2 disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={!canApply}
            onClick={() => void doApply()}
            className={cn(
              'inline-flex shrink-0 items-center gap-tk-xs rounded-ctl bg-accent px-tk-md py-tk-sm text-ctl-sm font-semibold text-accent-ink hover:brightness-95',
              !canApply && 'cursor-default opacity-[.45]',
            )}
          >
            {busy ? <Spinner className="h-3.5 w-3.5" /> : null} Apply adjustment
          </button>
        </div>
      </div>
    </Dialog>
  );
}
