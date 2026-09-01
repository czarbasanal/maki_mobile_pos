// Labor & mechanic on the cart (POS guide §2): labor rows (description +
// ₱ amount + remove), then the mechanic as a CHIP row — a handful of names
// is one tap, not three. Inline "+ Add" keeps mobile mechanic_picker parity:
// reuse an active case-insensitive twin, refuse an archived exact name.
import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { PlusIcon, XMarkIcon } from '@heroicons/react/24/outline';
import type { CartStore } from '@/presentation/stores/cartStore';
import { useActiveMechanics } from '@/presentation/hooks/useMechanics';
import { useMechanicRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { MotorcycleModelPicker } from './MotorcycleModelPicker';
import type { LaborLine, Mechanic } from '@/domain/entities';
import { Chip } from '@/presentation/components/ui/Chip';
import { IconButton } from '@/presentation/components/ui/IconButton';
import { Button } from '@/presentation/components/ui/Button';

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

  // Keep a deactivated-but-assigned mechanic visible so the store's id
  // isn't silently orphaned behind a "None" chip.
  const selectedMissing = !!mechanicId && !active.some((m) => m.id === mechanicId);

  return (
    <div className="space-y-tk-sm border-t border-line-2 px-[18px] py-3">
      <div className="flex items-center justify-between">
        <span className="text-cell font-semibold text-ink">Labor</span>
        <Button size="sm" icon={<PlusIcon className="h-3.5 w-3.5" />} onClick={addLaborLine}>
          Add labor
        </Button>
      </div>

      {laborLines.map((l) => (
        <LaborRow key={l.id} line={l} onChange={setLaborLine} onRemove={removeLaborLine} />
      ))}

      <div className="space-y-tk-xs">
        <span className="block text-micro-caps uppercase text-ink-3">Mechanic</span>
        <div className="flex flex-wrap items-center gap-tk-xs" aria-label="Mechanic">
          <Chip active={mechanicId === null} onClick={() => setMechanic(null, null)}>
            None
          </Chip>
          {selectedMissing ? (
            <Chip active onClick={() => {}}>
              {mechanicName ?? 'Mechanic'} (inactive)
            </Chip>
          ) : null}
          {active.map((m) => (
            <Chip
              key={m.id}
              active={m.id === mechanicId}
              onClick={() => setMechanic(m.id, m.name)}
            >
              {m.name}
            </Chip>
          ))}
          <Chip active={addingMechanic} onClick={() => setAddingMechanic(true)}>
            ＋ Add
          </Chip>
        </div>
        {addingMechanic ? (
          <div className="flex items-center gap-tk-sm">
            <input
              type="text"
              value={mechanicDraft}
              onChange={(e) => setMechanicDraft(e.target.value)}
              placeholder="Mechanic name"
              autoFocus
              className="min-w-0 flex-1 rounded-field border border-line bg-surface-2 px-2.5 py-1.5 text-ctl-sm text-ink outline-none placeholder:text-ink-3"
            />
            <Button
              variant="primary"
              size="sm"
              disabled={mechanicDraft.trim().length < 2}
              loading={addMechanic.isPending}
              onClick={() => addMechanic.mutate(mechanicDraft)}
            >
              Add
            </Button>
            <Button
              size="sm"
              onClick={() => {
                setAddingMechanic(false);
                setMechanicDraft('');
                addMechanic.reset();
              }}
            >
              Cancel
            </Button>
          </div>
        ) : null}
        {addMechanic.error ? (
          <p className="text-ctl-sm text-neg">{addMechanic.error.message}</p>
        ) : null}
      </div>

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
  const needsDescription = line.fee > 0 && line.description.trim() === '';

  return (
    <div className="space-y-tk-xs">
      <div className="flex items-center gap-tk-sm">
        <input
          type="text"
          value={line.description}
          onChange={(e) => onChange(line.id, { description: e.target.value })}
          placeholder="Description"
          className="min-w-0 flex-1 rounded-field border border-line bg-surface-2 px-2.5 py-1.5 text-ctl-sm text-ink outline-none placeholder:text-ink-3"
        />
        <input
          type="text"
          inputMode="decimal"
          value={feeText}
          onChange={(e) => {
            setFeeText(e.target.value);
            onChange(line.id, { fee: parseFloat(e.target.value) || 0 });
          }}
          placeholder="₱"
          className="w-[64px] rounded-field border border-line bg-surface-2 px-2 py-1.5 text-right font-mono text-ctl-sm text-ink outline-none placeholder:text-ink-3"
        />
        <IconButton title="Remove labor line" tone="danger" onClick={() => onRemove(line.id)}>
          <XMarkIcon className="h-3.5 w-3.5" />
        </IconButton>
      </div>
      {needsDescription ? (
        <p className="text-micro text-accent-text">Add a description to include this charge.</p>
      ) : null}
    </div>
  );
}
