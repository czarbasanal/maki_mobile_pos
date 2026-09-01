// POS screen (design/MAKI-POS-Handoff "POS Register"): the CartBuilder
// register surface plus the screen-level actions (Checkout · ₱total, Save as
// Job Order), gate banners, the save-JO dialog and the F2/F4 keyboard map.
// Reset lives in the cart card's header (CartBuilder).
import { useEffect, useMemo, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useCartStore } from '@/presentation/stores/cartStore';
import { describedLaborLines, laborValidationError } from '@/domain/sales/labor';
import { cartGrandTotal, cartHasBillableContent } from '@/domain/sales/cart';
import { useRegisterStatus } from '@/presentation/hooks/useRegisterStatus';
import { useSaveJobOrder } from '@/presentation/hooks/useJobOrderMutations';
import { useJobOrders } from '@/presentation/hooks/useJobOrders';
import { nextJobOrderNumber } from '@/domain/jobOrders/joNumber';
import { Dialog } from '@/presentation/components/common/Dialog';
import { toast } from '@/presentation/components/ui/toast';
import { RoutePaths } from '@/presentation/router/routePaths';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { CartBuilder } from './CartBuilder';

function GateBanner({ children }: { children: React.ReactNode }) {
  return (
    <p className="rounded-ctl border border-accent-text/40 bg-accent-soft px-tk-md py-tk-sm text-cell text-accent-text">
      {children}
    </p>
  );
}

export function PosPage() {
  const lines = useCartStore((s) => s.lines);
  const discountType = useCartStore((s) => s.discountType);
  const laborLines = useCartStore((s) => s.laborLines);
  const feeLines = useCartStore((s) => s.feeLines);
  const mechanicId = useCartStore((s) => s.mechanicId);
  const mechanicName = useCartStore((s) => s.mechanicName);
  const motorcycleModel = useCartStore((s) => s.motorcycleModel);
  const jobOrderId = useCartStore((s) => s.jobOrderId);
  const jobOrderName = useCartStore((s) => s.jobOrderName);
  const notes = useCartStore((s) => s.notes);
  const clear = useCartStore((s) => s.clear);
  const saveJobOrder = useSaveJobOrder();
  const jobOrders = useJobOrders();
  const location = useLocation();
  const navigate = useNavigate();

  const [done, setDone] = useState<string | null>(
    (location.state as { completedSaleNumber?: string } | null)?.completedSaleNumber ?? null,
  );
  const [saveOpen, setSaveOpen] = useState(false);
  const [noteDraft, setNoteDraft] = useState('');
  const { previousDayUnsettled } = useRegisterStatus();
  // Labor-only / fee-only tickets are billable (mobile parity); labor money
  // must be complete and attributed before it can leave the register.
  const hasBillable = cartHasBillableContent(lines, laborLines, feeLines);
  const laborError = laborValidationError(laborLines, mechanicId);
  // Mobile's bill-out rule: a job order can't convert to a sale without its
  // motorcycle model (job_order_bill_out.dart). Walk-ins are unaffected.
  const billOutNeedsModel = jobOrderId !== null && !motorcycleModel;
  const checkoutBlocked =
    !hasBillable || laborError !== null || previousDayUnsettled || billOutNeedsModel;
  const canSaveJobOrder = hasBillable && laborError === null && !saveJobOrder.isPending;
  const grandTotal = cartGrandTotal(lines, laborLines, discountType, feeLines);

  // Updating an existing Job Order keeps its current name (no renumber).
  // A brand-new one gets the next number for today, computed from the live
  // job orders list — while that list is still loading, `jobOrderNumber` stays
  // null so the dialog can't confirm against a stale/empty name set (which
  // would otherwise risk minting a number that collides with one already on
  // the server).
  const jobOrderNumber = useMemo(() => {
    if (jobOrderId) return jobOrderName ?? '';
    if (jobOrders.isLoading || !jobOrders.data) return null;
    return nextJobOrderNumber(
      new Date(),
      jobOrders.data.map((d) => d.name),
    );
  }, [jobOrderId, jobOrderName, jobOrders.isLoading, jobOrders.data]);

  useEffect(() => {
    document.title = 'POS';
  }, []);

  useEffect(() => {
    if ((location.state as { completedSaleNumber?: string } | null)?.completedSaleNumber) {
      navigate(RoutePaths.pos, { replace: true, state: null });
    }
    // run once — `done` is already captured from location.state in the useState
    // initializer above, so clearing router state here doesn't affect the banner.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Dismiss the previous sale's success banner once a new cart is started.
  useEffect(() => {
    if (lines.length > 0) setDone(null);
  }, [lines.length]);

  // Auto-dismiss the success banner a few seconds after a completed sale.
  useEffect(() => {
    if (!done) return;
    const t = setTimeout(() => setDone(null), 4000);
    return () => clearTimeout(t);
  }, [done]);

  const openSave = () => {
    // Seed the dialog's notes buffer from the cart (a resumed JO carries its
    // saved notes; a fresh cart starts blank). Edits only land on the cart —
    // and the JO — on Save, so Cancel discards them.
    setNoteDraft(notes ?? '');
    setSaveOpen(true);
  };

  // Register keyboard map (POS guide §5): F2 = Checkout, F4 = Save as JO.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'F2') {
        e.preventDefault();
        if (!checkoutBlocked) navigate(RoutePaths.checkout);
      } else if (e.key === 'F4') {
        e.preventDefault();
        if (canSaveJobOrder && !saveOpen) openSave();
      }
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  });

  const onSaveJobOrder = async () => {
    const name = jobOrderNumber;
    if (!name) return;
    const trimmedNotes = noteDraft.trim() || null;
    try {
      await saveJobOrder.mutateAsync({
        jobOrderId,
        name,
        items: lines,
        discountType,
        laborLines: describedLaborLines(laborLines),
        feeLines,
        mechanicId,
        mechanicName,
        motorcycleModel,
        notes: trimmedNotes,
      });
      setSaveOpen(false);
      clear();
      toast.success('Saved as Job Order', name);
    } catch {
      // surfaced via saveJobOrder.error
    }
  };

  const actions = (
    <div className="space-y-tk-sm">
      {laborError ? <GateBanner>{laborError}</GateBanner> : null}
      {billOutNeedsModel ? (
        <GateBanner>Set the motorcycle model before billing out this Job Order.</GateBanner>
      ) : null}
      <div className="flex flex-col gap-2">
        <Link
          to={RoutePaths.checkout}
          aria-disabled={checkoutBlocked}
          className={cn(
            'block w-full rounded-[12px] bg-accent px-tk-md py-3 text-center text-ctl-lg font-semibold text-accent-ink shadow-[0_6px_18px_-8px_var(--accent-line)] hover:brightness-95',
            checkoutBlocked && 'pointer-events-none cursor-not-allowed opacity-60',
          )}
        >
          Checkout · {formatMoney(grandTotal)}
        </Link>
        <button
          type="button"
          disabled={!canSaveJobOrder}
          onClick={openSave}
          className={cn(
            'w-full rounded-[12px] border border-line bg-surface px-tk-md py-2.5 text-nav text-ink-2 transition-[color] hover:text-ink',
            !canSaveJobOrder && 'cursor-not-allowed opacity-60',
          )}
        >
          {saveJobOrder.isPending ? 'Saving…' : jobOrderId ? 'Update Job Order' : 'Save as Job Order'}
        </button>
      </div>
    </div>
  );

  return (
    <div className="space-y-tk-md">
      {done ? (
        <p className="rounded-ctl border border-pos/40 bg-pos-soft px-tk-md py-tk-sm text-cell text-pos">
          Sale <span className="font-mono">{done}</span> completed.
        </p>
      ) : null}
      {saveJobOrder.isSuccess && lines.length === 0 ? (
        <p className="rounded-ctl border border-pos/40 bg-pos-soft px-tk-md py-tk-sm text-cell text-pos">
          Saved as Job Order.
        </p>
      ) : null}

      {previousDayUnsettled ? (
        <GateBanner>
          Yesterday's sales haven't been closed yet. Close the day on the register phone before
          completing new sales.
        </GateBanner>
      ) : null}

      <CartBuilder store={useCartStore} actions={actions} />

      <Dialog
        open={saveOpen}
        onClose={() => {
          if (!saveJobOrder.isPending) setSaveOpen(false);
        }}
        title={jobOrderId ? 'Update Job Order' : 'Save as Job Order'}
        dismissable={!saveJobOrder.isPending}
      >
        <div className="space-y-tk-md">
          <div className="space-y-tk-xs">
            <span className="text-cell text-ink-2">Job Order #</span>
            <div className="w-full rounded-ctl border border-line bg-surface-2 px-tk-md py-tk-sm font-mono text-cell text-ink">
              {jobOrderNumber ?? 'Computing…'}
            </div>
          </div>
          <label className="block space-y-tk-xs">
            <span className="text-cell text-ink-2">Notes</span>
            <textarea
              rows={3}
              value={noteDraft}
              onChange={(e) => setNoteDraft(e.target.value)}
              placeholder="Optional — e.g. customer requests"
              disabled={saveJobOrder.isPending}
              className="w-full rounded-ctl border border-line bg-surface px-tk-md py-tk-sm text-cell text-ink outline-none placeholder:text-ink-3 focus:border-ink"
            />
          </label>
          {saveJobOrder.error ? (
            <p className="text-ctl-sm text-neg">{saveJobOrder.error.message}</p>
          ) : null}
          <div className="flex justify-end gap-tk-sm">
            <button
              type="button"
              onClick={() => setSaveOpen(false)}
              disabled={saveJobOrder.isPending}
              className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-md text-ink-2 hover:bg-surface-2"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={onSaveJobOrder}
              disabled={saveJobOrder.isPending || !jobOrderNumber}
              className="rounded-ctl bg-accent px-tk-md py-tk-sm text-ctl-md font-semibold text-accent-ink hover:brightness-95 disabled:opacity-60"
            >
              Save
            </button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
