import { useEffect, useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useCartStore } from '@/presentation/stores/cartStore';
import { describedLaborLines } from '@/domain/sales/labor';
import { useSaveDraft } from '@/presentation/hooks/useDraftMutations';
import { Dialog } from '@/presentation/components/common/Dialog';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';
import { CartBuilder } from './CartBuilder';

export function PosPage() {
  const lines = useCartStore((s) => s.lines);
  const discountType = useCartStore((s) => s.discountType);
  const laborLines = useCartStore((s) => s.laborLines);
  const mechanicId = useCartStore((s) => s.mechanicId);
  const mechanicName = useCartStore((s) => s.mechanicName);
  const draftId = useCartStore((s) => s.draftId);
  const draftName = useCartStore((s) => s.draftName);
  const clear = useCartStore((s) => s.clear);
  const saveDraft = useSaveDraft();
  const location = useLocation();
  const navigate = useNavigate();

  const [done, setDone] = useState<string | null>(
    (location.state as { completedSaleNumber?: string } | null)?.completedSaleNumber ?? null,
  );
  const [saveOpen, setSaveOpen] = useState(false);
  const [draftNameInput, setDraftNameInput] = useState('');

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
    setDraftNameInput(draftName ?? '');
    setSaveOpen(true);
  };
  const onSaveDraft = async () => {
    const name = draftNameInput.trim();
    if (!name) return;
    try {
      await saveDraft.mutateAsync({
        draftId,
        name,
        items: lines,
        discountType,
        laborLines: describedLaborLines(laborLines),
        mechanicId,
        mechanicName,
      });
      setSaveOpen(false);
      clear();
    } catch {
      // surfaced via saveDraft.error
    }
  };

  return (
    <div className="space-y-tk-md px-tk-xl py-tk-lg">
      <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">POS</h1>

      {done ? (
        <p className="rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
          Sale <span className="font-mono">{done}</span> completed.
        </p>
      ) : null}
      {saveDraft.isSuccess && lines.length === 0 ? (
        <p className="rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
          Saved to drafts.
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
          disabled={lines.length === 0 || saveDraft.isPending}
          onClick={openSave}
          className={cn(
            'w-full rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall font-medium text-light-text hover:bg-light-subtle',
            (lines.length === 0 || saveDraft.isPending) && 'cursor-not-allowed opacity-60',
          )}
        >
          {saveDraft.isPending ? 'Saving…' : draftId ? 'Update draft' : 'Save as draft'}
        </button>
      </div>

      <Dialog
        open={saveOpen}
        onClose={() => {
          if (!saveDraft.isPending) setSaveOpen(false);
        }}
        title={draftId ? 'Update draft' : 'Save as draft'}
        dismissable={!saveDraft.isPending}
      >
        <div className="space-y-tk-md">
          <label className="block space-y-tk-xs">
            <span className="text-bodySmall text-light-text-secondary">Draft name</span>
            <input
              type="text"
              value={draftNameInput}
              onChange={(e) => setDraftNameInput(e.target.value)}
              autoFocus
              placeholder="e.g. Mr Cruz — blue Mio"
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            />
          </label>
          <div className="flex justify-end gap-tk-sm">
            <button
              type="button"
              onClick={() => setSaveOpen(false)}
              disabled={saveDraft.isPending}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={onSaveDraft}
              disabled={saveDraft.isPending || !draftNameInput.trim()}
              className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
            >
              Save
            </button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
