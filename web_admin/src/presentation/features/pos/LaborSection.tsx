import { useState } from 'react';
import { PlusIcon, TrashIcon } from '@heroicons/react/24/outline';
import { useCartStore } from '@/presentation/stores/cartStore';
import { useActiveMechanics } from '@/presentation/hooks/useMechanics';
import type { LaborLine } from '@/domain/entities/LaborLine';

export function LaborSection() {
  const laborLines = useCartStore((s) => s.laborLines);
  const addLaborLine = useCartStore((s) => s.addLaborLine);
  const setLaborLine = useCartStore((s) => s.setLaborLine);
  const removeLaborLine = useCartStore((s) => s.removeLaborLine);
  const mechanicId = useCartStore((s) => s.mechanicId);
  const setMechanic = useCartStore((s) => s.setMechanic);

  const { data: mechanics } = useActiveMechanics();
  const active = mechanics ?? [];

  const onMechanicChange = (id: string) => {
    if (!id) return setMechanic(null, null);
    const m = active.find((x) => x.id === id);
    setMechanic(id, m?.name ?? null);
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
          value={mechanicId ?? ''}
          onChange={(e) => onMechanicChange(e.target.value)}
          className="rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-[12px]"
        >
          <option value="">None</option>
          {active.map((m) => (
            <option key={m.id} value={m.id}>
              {m.name}
            </option>
          ))}
        </select>
      </label>
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

  return (
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
          setFeeText(e.target.value);
          onChange(line.id, { fee: Number(e.target.value) || 0 });
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
  );
}
