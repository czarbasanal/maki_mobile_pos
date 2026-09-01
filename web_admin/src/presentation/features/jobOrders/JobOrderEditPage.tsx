import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useJobOrder } from '@/presentation/hooks/useJobOrder';
import { useJobOrderEditStore } from '@/presentation/stores/jobOrderEditStore';
import { useSaveJobOrder } from '@/presentation/hooks/useJobOrderMutations';
import { describedLaborLines } from '@/domain/sales/labor';
import { CartBuilder } from '@/presentation/features/pos/CartBuilder';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';

export function JobOrderEditPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const { data: jobOrder, isLoading, error } = useJobOrder(id);
  const save = useSaveJobOrder();

  const loadJobOrder = useJobOrderEditStore((s) => s.loadJobOrder);
  const clear = useJobOrderEditStore((s) => s.clear);
  const lines = useJobOrderEditStore((s) => s.lines);
  const discountType = useJobOrderEditStore((s) => s.discountType);
  const laborLines = useJobOrderEditStore((s) => s.laborLines);
  const feeLines = useJobOrderEditStore((s) => s.feeLines);
  const mechanicId = useJobOrderEditStore((s) => s.mechanicId);
  const mechanicName = useJobOrderEditStore((s) => s.mechanicName);
  const notes = useJobOrderEditStore((s) => s.notes);
  const motorcycleModel = useJobOrderEditStore((s) => s.motorcycleModel);
  const setNotes = useJobOrderEditStore((s) => s.setNotes);

  const [name, setName] = useState('');
  const hydratedId = useRef<string | null>(null);

  useEffect(() => {
    document.title = 'Edit Job Order';
  }, []);
  useEffect(() => {
    if (jobOrder && !jobOrder.isConverted && hydratedId.current !== jobOrder.id) {
      loadJobOrder(jobOrder);
      setName(jobOrder.name);
      hydratedId.current = jobOrder.id;
    }
  }, [jobOrder, loadJobOrder]);
  useEffect(() => () => clear(), [clear]);

  if (error) return <ErrorView title="Could not load Job Order" message={error.message} />;
  if (isLoading) return <LoadingView label="Loading Job Order…" />;
  if (!jobOrder) {
    return (
      <div>
        <EmptyState title="Job Order not found" description="It may have been deleted or already billed out." />
        <Link to={RoutePaths.jobOrders} className="mt-tk-md inline-block text-bodySmall text-light-text-secondary hover:text-light-text">← Job Orders</Link>
      </div>
    );
  }
  if (jobOrder.isConverted) {
    return (
      <div>
        <EmptyState title="Can't edit this Job Order" description="This Job Order is already billed out and can't be edited." />
        <Link to={RoutePaths.jobOrders} className="mt-tk-md inline-block text-bodySmall text-light-text-secondary hover:text-light-text">← Job Orders</Link>
      </div>
    );
  }

  const onSave = async () => {
    const trimmed = name.trim();
    if (!trimmed) return;
    try {
      await save.mutateAsync({
        jobOrderId: id,
        name: trimmed,
        items: lines,
        discountType,
        laborLines: describedLaborLines(laborLines),
        feeLines,
        mechanicId,
        mechanicName,
        motorcycleModel,
        notes: (notes ?? '').trim() || null,
      });
      navigate(RoutePaths.jobOrders);
    } catch {
      // surfaced via save.error
    }
  };

  return (
    <div className="space-y-tk-md">
      <Link to={RoutePaths.jobOrders} className="text-bodySmall text-light-text-secondary hover:text-light-text">← Job Orders</Link>

      {save.error ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {save.error.message}
        </p>
      ) : null}

      <label className="block max-w-sm space-y-tk-xs">
        <span className="text-bodySmall text-light-text-secondary">Job Order #</span>
        <input type="text" value={name} onChange={(e) => setName(e.target.value)}
          className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm font-mono text-bodySmall text-light-text outline-none focus:border-light-text" />
      </label>

      <label className="block max-w-sm space-y-tk-xs">
        <span className="text-bodySmall text-light-text-secondary">Notes</span>
        <textarea rows={3} value={notes ?? ''} onChange={(e) => setNotes(e.target.value)}
          placeholder="Optional"
          className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text" />
      </label>

      <CartBuilder store={useJobOrderEditStore} />

      <div className="flex justify-end gap-tk-sm">
        <Link to={RoutePaths.jobOrders} className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">Cancel</Link>
        <button type="button" onClick={onSave} disabled={save.isPending || !name.trim()}
          className={cn('rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark',
            (save.isPending || !name.trim()) && 'cursor-not-allowed opacity-60')}>
          {save.isPending ? 'Saving…' : 'Save changes'}
        </button>
      </div>
    </div>
  );
}
