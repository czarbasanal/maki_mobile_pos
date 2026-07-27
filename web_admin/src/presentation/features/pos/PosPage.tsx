import { useEffect, useMemo, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { ArrowPathIcon } from '@heroicons/react/24/outline';
import { useCartStore } from '@/presentation/stores/cartStore';
import { describedLaborLines } from '@/domain/sales/labor';
import { useSaveJobOrder } from '@/presentation/hooks/useJobOrderMutations';
import { useJobOrders } from '@/presentation/hooks/useJobOrders';
import { nextJobOrderNumber } from '@/domain/jobOrders/joNumber';
import { Dialog } from '@/presentation/components/common/Dialog';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';
import { CartBuilder } from './CartBuilder';

export function PosPage() {
  const lines = useCartStore((s) => s.lines);
  const discountType = useCartStore((s) => s.discountType);
  const laborLines = useCartStore((s) => s.laborLines);
  const feeLines = useCartStore((s) => s.feeLines);
  const mechanicId = useCartStore((s) => s.mechanicId);
  const mechanicName = useCartStore((s) => s.mechanicName);
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
  const [confirmReset, setConfirmReset] = useState(false);
  const hasTicket = lines.length > 0 || laborLines.length > 0;

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
        notes: trimmedNotes,
      });
      setSaveOpen(false);
      clear();
    } catch {
      // surfaced via saveJobOrder.error
    }
  };

  return (
    <div className="space-y-tk-md px-tk-xl py-tk-lg">
      <div className="flex items-center justify-between">
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">POS</h1>
        {hasTicket ? (
          <button
            type="button"
            aria-label="Reset sale"
            title="Reset sale"
            onClick={() => setConfirmReset(true)}
            className="rounded-md border border-light-hairline p-tk-sm text-light-text-secondary hover:bg-light-card"
          >
            <ArrowPathIcon className="h-4 w-4" />
          </button>
        ) : null}
      </div>

      {done ? (
        <p className="rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
          Sale <span className="font-mono">{done}</span> completed.
        </p>
      ) : null}
      {saveJobOrder.isSuccess && lines.length === 0 ? (
        <p className="rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
          Saved as Job Order.
        </p>
      ) : null}

      <CartBuilder store={useCartStore} />

      <div className="ml-auto max-w-sm space-y-tk-sm rounded-lg border border-light-hairline bg-light-card p-tk-md">
        <Link
          to={RoutePaths.checkout}
          aria-disabled={lines.length === 0}
          className={cn(
            'block w-full rounded-md bg-light-text px-tk-md py-tk-sm text-center text-bodySmall font-semibold text-light-background hover:bg-primary-dark',
            lines.length === 0 && 'pointer-events-none cursor-not-allowed opacity-60',
          )}
        >
          Checkout
        </Link>
        <button
          type="button"
          disabled={lines.length === 0 || saveJobOrder.isPending}
          onClick={openSave}
          className={cn(
            'w-full rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall font-medium text-light-text hover:bg-light-subtle',
            (lines.length === 0 || saveJobOrder.isPending) && 'cursor-not-allowed opacity-60',
          )}
        >
          {saveJobOrder.isPending ? 'Saving…' : jobOrderId ? 'Update Job Order' : 'Save as Job Order'}
        </button>
      </div>

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
            <span className="text-bodySmall text-light-text-secondary">Job Order #</span>
            <div className="w-full rounded-md border border-light-border bg-light-subtle px-tk-md py-tk-sm font-mono text-bodySmall text-light-text">
              {jobOrderNumber ?? 'Computing…'}
            </div>
          </div>
          <label className="block space-y-tk-xs">
            <span className="text-bodySmall text-light-text-secondary">Notes</span>
            <textarea
              rows={3}
              value={noteDraft}
              onChange={(e) => setNoteDraft(e.target.value)}
              placeholder="Optional — e.g. customer requests"
              disabled={saveJobOrder.isPending}
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            />
          </label>
          <div className="flex justify-end gap-tk-sm">
            <button
              type="button"
              onClick={() => setSaveOpen(false)}
              disabled={saveJobOrder.isPending}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={onSaveJobOrder}
              disabled={saveJobOrder.isPending || !jobOrderNumber}
              className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
            >
              Save
            </button>
          </div>
        </div>
      </Dialog>

      <Dialog
        open={confirmReset}
        onClose={() => setConfirmReset(false)}
        title="Clear this sale?"
      >
        <div className="space-y-tk-md">
          <p className="text-bodySmall text-light-text-secondary">
            This clears the whole sale — items, labor & service, and mechanic.
          </p>
          <div className="flex justify-end gap-tk-sm">
            <button
              type="button"
              onClick={() => setConfirmReset(false)}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={() => {
                clear();
                setConfirmReset(false);
              }}
              className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
            >
              Clear
            </button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
