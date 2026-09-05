// Cart-independent Job Order creation (mobile new_job_order_dialog parity):
// auto-numbered ticket with optional motorcycle model + mechanic, empty
// items — parts get added later by resuming or editing the ticket.
import { useState } from 'react';
import { Dialog } from '@/presentation/components/common/Dialog';
import { SelectFilter } from '@/presentation/components/ui/SelectFilter';
import { toast } from '@/presentation/components/ui/toast';
import { useSaveJobOrder } from '@/presentation/hooks/useJobOrderMutations';
import { useMotorcycleModels } from '@/presentation/hooks/useMotorcycleModels';
import { useActiveMechanics } from '@/presentation/hooks/useMechanics';
import { DiscountType } from '@/domain/enums/DiscountType';

export function NewJobOrderDialog({
  open,
  jobOrderNumber,
  onClose,
}: {
  open: boolean;
  /** Computed from the live list; null while that list is still loading. */
  jobOrderNumber: string | null;
  onClose: () => void;
}) {
  const save = useSaveJobOrder();
  const { data: models } = useMotorcycleModels();
  const { data: mechanics } = useActiveMechanics();
  const [model, setModel] = useState('');
  const [mechanicId, setMechanicId] = useState('');

  const reset = () => {
    setModel('');
    setMechanicId('');
    save.reset();
  };

  const create = async () => {
    if (!jobOrderNumber) return;
    const mechanic = (mechanics ?? []).find((m) => m.id === mechanicId) ?? null;
    try {
      await save.mutateAsync({
        jobOrderId: null,
        name: jobOrderNumber,
        items: [],
        discountType: DiscountType.amount,
        laborLines: [],
        feeLines: [],
        mechanicId: mechanic?.id ?? null,
        mechanicName: mechanic?.name ?? null,
        motorcycleModel: model || null,
        notes: null,
      });
      toast.success('Job Order created', jobOrderNumber);
      reset();
      onClose();
    } catch {
      // surfaced via save.error
    }
  };

  return (
    <Dialog
      open={open}
      onClose={() => {
        if (save.isPending) return;
        reset();
        onClose();
      }}
      title="New Job Order"
      dismissable={!save.isPending}
    >
      <div className="space-y-tk-md">
        <div className="space-y-tk-xs">
          <span className="text-cell text-ink-2">Job Order #</span>
          <div className="w-full rounded-ctl border border-line bg-surface-2 px-tk-md py-tk-sm font-mono text-cell text-ink">
            {jobOrderNumber ?? 'Computing…'}
          </div>
        </div>

        {/* div, not label: a label wrapping the SelectFilter trigger button
            would steal its accessible name (same rule as formKit's Field). */}
        <div className="space-y-tk-xs">
          <span className="text-cell text-ink-2">Motorcycle model</span>
          <SelectFilter
            label="Motorcycle model"
            value={model}
            options={(models ?? []).map((m) => ({ value: m.name, label: m.name }))}
            allLabel="None"
            onChange={setModel}
            triggerClassName="w-full bg-surface-2 shadow-none"
          />
        </div>

        <div className="space-y-tk-xs">
          <span className="text-cell text-ink-2">Mechanic</span>
          <SelectFilter
            label="Mechanic"
            value={mechanicId}
            options={(mechanics ?? []).map((m) => ({ value: m.id, label: m.name }))}
            allLabel="None"
            onChange={setMechanicId}
            triggerClassName="w-full bg-surface-2 shadow-none"
          />
        </div>

        {save.error ? <p className="text-ctl-sm text-neg">{save.error.message}</p> : null}

        <div className="flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => {
              reset();
              onClose();
            }}
            disabled={save.isPending}
            className="rounded-ctl border border-line px-tk-md py-tk-sm text-ctl-md text-ink-2 hover:bg-surface-2"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={create}
            disabled={save.isPending || !jobOrderNumber}
            className="rounded-ctl bg-accent px-tk-md py-tk-sm text-ctl-md font-semibold text-accent-ink hover:brightness-95 disabled:opacity-60"
          >
            {save.isPending ? 'Creating…' : 'Create'}
          </button>
        </div>
      </div>
    </Dialog>
  );
}
