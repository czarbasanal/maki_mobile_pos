import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { PlusIcon, TrashIcon } from '@heroicons/react/24/outline';
import type { CartStore } from '@/presentation/stores/cartStore';
import { useActiveMechanics } from '@/presentation/hooks/useMechanics';
import { useMechanicRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { MotorcycleModelPicker } from './MotorcycleModelPicker';
import type { LaborLine, Mechanic } from '@/domain/entities';

const ADD_MECHANIC_SENTINEL = '__add__';

export function LaborSection({ store }: { store: CartStore }) {
  const laborLines = store((s) => s.laborLines);
  const addLaborLine = store((s) => s.addLaborLine);
  const setLaborLine = store((s) => s.setLaborLine);
  const removeLaborLine = store((s) => s.removeLaborLine);
  const mechanicId = store((s) => s.mechanicId);
  const mechanicName = store((s) => s.mechanicName);
  const setMechanic = store((s) => s.setMechanic);

  const { data: mechanics } = useActiveMechanics();
  const active = mechanics ?? [];

  const mechanicRepo = useMechanicRepo();
  const actor = useAuthStore((s) => s.user);
  const [addingMechanic, setAddingMechanic] = useState(false);
  const [mechanicDraft, setMechanicDraft] = useState('');
  // Mobile mechanic_picker parity: reuse an active case-insensitive twin,
  // refuse an archived exact-name duplicate, else create.
  const addMechanic = useMutation<Mechanic, Error, string>({
    mutationFn: async (rawName) => {
      const name = rawName.trim();
      if (name.length < 2) throw new Error('Enter at least 2 characters');
      const twin = active.find((m) => m.name.toLowerCase() === name.toLowerCase());
      if (twin) return twin;
      if (await mechanicRepo.nameExists(name)) {
        throw new Error(
          'A mechanic with this name is archived — ask staff to reactivate them in Settings',
        );
      }
      if (!actor) throw new Error('Not signed in');
      return mechanicRepo.create({ name }, actor.id);
    },
    onSuccess: (mechanic) => {
      setMechanic(mechanic.id, mechanic.name);
      setAddingMechanic(false);
      setMechanicDraft('');
    },
  });

  // Keep the currently-selected mechanic visible even if it was deactivated
  // after selection — otherwise the <select> would silently show "None" while
  // the store still holds (and would persist) the stale id.
  const selectedMissing = !!mechanicId && !active.some((m) => m.id === mechanicId);
  const options = selectedMissing
    ? [{ id: mechanicId, name: `${mechanicName ?? 'Mechanic'} (inactive)` }, ...active]
    : active;

  const onMechanicChange = (id: string) => {
    if (!id) return setMechanic(null, null);
    const m = options.find((x) => x.id === id);
    setMechanic(id, m?.name ?? mechanicName ?? null);
  };

  return (
    <div className="space-y-tk-sm border-t border-light-hairline px-tk-md py-tk-sm">
      <div className="flex items-center justify-between">
        <span className="text-bodySmall font-medium text-light-text">Labor</span>
        <button
          type="button"
          onClick={addLaborLine}
          className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-sm py-[4px] text-[12px] text-light-text-secondary hover:bg-light-subtle"
        >
          <PlusIcon className="h-3.5 w-3.5" /> Add labor
        </button>
      </div>

      {laborLines.map((l) => (
        <LaborRow key={l.id} line={l} onChange={setLaborLine} onRemove={removeLaborLine} />
      ))}

      <label className="flex items-center gap-tk-sm text-[12px] text-light-text-secondary">
        Mechanic
        <select
          value={addingMechanic ? ADD_MECHANIC_SENTINEL : mechanicId ?? ''}
          onChange={(e) => {
            if (e.target.value === ADD_MECHANIC_SENTINEL) {
              setAddingMechanic(true);
              return;
            }
            setAddingMechanic(false);
            onMechanicChange(e.target.value);
          }}
          className="rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]"
        >
          <option value="">None</option>
          {options.map((m) => (
            <option key={m.id} value={m.id}>
              {m.name}
            </option>
          ))}
          <option value={ADD_MECHANIC_SENTINEL}>➕ Add mechanic…</option>
        </select>
      </label>
      {addingMechanic ? (
        <div className="flex items-center gap-tk-sm">
          <input
            type="text"
            value={mechanicDraft}
            onChange={(e) => setMechanicDraft(e.target.value)}
            placeholder="Mechanic name"
            autoFocus
            className="min-w-0 flex-1 rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]"
          />
          <button
            type="button"
            disabled={mechanicDraft.trim().length < 2 || addMechanic.isPending}
            onClick={() => addMechanic.mutate(mechanicDraft)}
            className="rounded-md bg-light-text px-tk-md py-[6px] text-[12px] font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
          >
            {addMechanic.isPending ? 'Adding…' : 'Add'}
          </button>
          <button
            type="button"
            onClick={() => {
              setAddingMechanic(false);
              setMechanicDraft('');
              addMechanic.reset();
            }}
            className="rounded-md border border-light-border px-tk-sm py-[6px] text-[12px] text-light-text-secondary hover:bg-light-subtle"
          >
            Cancel
          </button>
        </div>
      ) : null}
      {addMechanic.error ? (
        <p className="text-[12px] text-error-dark">{addMechanic.error.message}</p>
      ) : null}

      <MotorcycleModelPicker store={store} />
    </div>
  );
}

function LaborRow({
  line,
  onChange,
  onRemove,
}: {
  line: LaborLine;
  onChange: (id: string, patch: Partial<Pick<LaborLine, 'description' | 'fee'>>) => void;
  onRemove: (id: string) => void;
}) {
  // Fee is string-backed locally so decimals (e.g. 150.50) type cleanly; the
  // store keeps the parsed number for the totals.
  const [feeText, setFeeText] = useState(line.fee ? String(line.fee) : '');
  // A row only counts/writes when it has a description — surface that when a
  // fee was entered without one, so the charge isn't silently dropped.
  const needsDescription = line.fee > 0 && line.description.trim() === '';

  return (
    <div className="space-y-tk-xs">
      <div className="flex items-center gap-tk-sm">
        <input
          type="text"
          value={line.description}
          onChange={(e) => onChange(line.id, { description: e.target.value })}
          placeholder="Description"
          className="min-w-0 flex-1 rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]"
        />
        <input
          type="number"
          min={0}
          step="0.01"
          inputMode="decimal"
          value={feeText}
          onChange={(e) => {
            const raw = e.target.value;
            if (Number(raw) < 0) return; // labor fees are never negative
            setFeeText(raw);
            onChange(line.id, { fee: Number(raw) || 0 });
          }}
          placeholder="Fee"
          className="w-24 rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]"
        />
        <button
          type="button"
          onClick={() => onRemove(line.id)}
          className="text-light-text-hint hover:text-error"
        >
          <TrashIcon className="h-4 w-4" />
        </button>
      </div>
      {needsDescription ? (
        <p className="text-[11px] text-warning-dark">Add a description to include this charge.</p>
      ) : null}
    </div>
  );
}
