// Pick-or-add motorcycle model for the ticket (mobile
// motorcycle_model_picker.dart parity). The ticket snapshots the NAME;
// the canonical list is shared and cashier-extendable.
import { useState } from 'react';
import type { CartStore } from '@/presentation/stores/cartStore';
import { SelectFilter } from '@/presentation/components/ui/SelectFilter';
import {
  useMotorcycleModels,
  useResolveOrCreateModel,
} from '@/presentation/hooks/useMotorcycleModels';

const ADD_SENTINEL = '__add__';

export function MotorcycleModelPicker({ store }: { store: CartStore }) {
  const motorcycleModel = store((s) => s.motorcycleModel);
  const setMotorcycleModel = store((s) => s.setMotorcycleModel);
  const { data: models } = useMotorcycleModels();
  const resolve = useResolveOrCreateModel();
  const [adding, setAdding] = useState(false);
  const [draft, setDraft] = useState('');

  const active = models ?? [];
  // A ticket model missing from the active list (archived, or minted on the
  // phone) stays visible — otherwise the select silently shows None while
  // the store still holds (and would persist) the name.
  const names = active.map((m) => m.name);
  const options =
    motorcycleModel && !names.includes(motorcycleModel) ? [motorcycleModel, ...names] : names;

  const submitDraft = async () => {
    if (!draft.trim() || resolve.isPending) return;
    try {
      const canonical = await resolve.mutateAsync(draft);
      setMotorcycleModel(canonical);
      setAdding(false);
      setDraft('');
    } catch {
      // surfaced via resolve.error below
    }
  };

  return (
    <div className="space-y-tk-xs pt-tk-sm">
      <SelectFilter
        label="Motorcycle"
        value={adding ? ADD_SENTINEL : motorcycleModel ?? ''}
        options={[
          ...options.map((name) => ({ value: name, label: name })),
          { value: ADD_SENTINEL, label: '➕ Add model…' },
        ]}
        allLabel="None"
        onChange={(v) => {
          if (v === ADD_SENTINEL) {
            setAdding(true);
            return;
          }
          setAdding(false);
          setMotorcycleModel(v === '' ? null : v);
        }}
        triggerClassName="bg-surface-2 shadow-none px-tk-sm py-[6px]"
      />
      {adding ? (
        <div className="flex items-center gap-tk-sm">
          <input
            type="text"
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            placeholder="Model name"
            autoFocus
            className="min-w-0 flex-1 rounded-field border border-line bg-surface-2 px-tk-sm py-[6px] text-ctl-sm text-ink outline-none placeholder:text-ink-3"
          />
          <button
            type="button"
            disabled={!draft.trim() || resolve.isPending}
            onClick={submitDraft}
            className="rounded-ctl bg-accent px-tk-md py-[6px] text-ctl-sm font-semibold text-accent-ink hover:brightness-95 disabled:opacity-60"
          >
            {resolve.isPending ? 'Adding…' : 'Add'}
          </button>
          <button
            type="button"
            onClick={() => {
              setAdding(false);
              setDraft('');
            }}
            className="rounded-ctl border border-line px-tk-sm py-[6px] text-ctl-sm text-ink-2 hover:bg-surface-2"
          >
            Cancel
          </button>
        </div>
      ) : null}
      {resolve.error ? (
        <p className="text-ctl-sm text-neg">{resolve.error.message}</p>
      ) : null}
    </div>
  );
}
