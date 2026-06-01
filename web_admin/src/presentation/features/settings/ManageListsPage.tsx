import { useEffect, useState } from 'react';
import { EyeIcon, EyeSlashIcon, PencilIcon, PlusIcon } from '@heroicons/react/24/outline';
import { CategoryKind, labelForKind } from '@/domain/categories/categoryKind';
import { useCategories } from '@/presentation/hooks/useCategories';
import { useCreateCategory, useUpdateCategory } from '@/presentation/hooks/useCategoryMutations';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Dialog } from '@/presentation/components/common/Dialog';
import type { Category } from '@/domain/entities';
import { cn } from '@/core/utils/cn';

const KINDS: CategoryKind[] = [
  CategoryKind.product,
  CategoryKind.unit,
  CategoryKind.expense,
  CategoryKind.voidReason,
];

export function ManageListsPage() {
  useEffect(() => {
    document.title = 'Manage Lists · MAKI POS Admin';
  }, []);

  const [kind, setKind] = useState<CategoryKind>(CategoryKind.product);
  const { data: categories, isLoading, error } = useCategories(kind, { includeInactive: true });

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Category | null>(null);
  const [name, setName] = useState('');
  const [active, setActive] = useState(true);

  const create = useCreateCategory(kind);
  const update = useUpdateCategory(kind);
  const busy = create.isPending || update.isPending;

  const openAdd = () => {
    setEditing(null);
    setName('');
    setActive(true);
    setDialogOpen(true);
  };
  const openEdit = (c: Category) => {
    setEditing(c);
    setName(c.name);
    setActive(c.isActive);
    setDialogOpen(true);
  };

  const onSave = async () => {
    const trimmed = name.trim();
    if (!trimmed) return;
    if (editing) {
      await update.mutateAsync({ id: editing.id, name: trimmed, isActive: active });
    } else {
      await create.mutateAsync({ name: trimmed });
    }
    setDialogOpen(false);
  };

  const toggleActive = async (c: Category) => {
    await update.mutateAsync({ id: c.id, isActive: !c.isActive });
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Manage Lists</h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Admin-managed dropdown values used across the app.
          </p>
        </div>
        <button
          type="button"
          onClick={openAdd}
          className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
        >
          <PlusIcon className="h-3.5 w-3.5" /> Add
        </button>
      </header>

      <div className="inline-flex flex-wrap rounded-md border border-light-hairline p-[2px]">
        {KINDS.map((k) => (
          <button
            key={k}
            type="button"
            onClick={() => setKind(k)}
            className={cn(
              'rounded px-tk-md py-[4px] text-bodySmall transition-colors',
              kind === k
                ? 'bg-light-subtle font-semibold text-light-text'
                : 'text-light-text-secondary hover:text-light-text',
            )}
          >
            {labelForKind(k)}
          </button>
        ))}
      </div>

      {error ? (
        <ErrorView title="Could not load list" message={error.message} />
      ) : isLoading || !categories ? (
        <LoadingView label="Loading…" />
      ) : categories.length === 0 ? (
        <EmptyState title="No entries yet" description="Add the first entry for this list." />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <ul className="divide-y divide-light-hairline">
            {categories.map((c) => (
              <li key={c.id} className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm">
                <span
                  className={cn(
                    'text-bodySmall',
                    c.isActive ? 'text-light-text' : 'text-light-text-hint line-through',
                  )}
                >
                  {c.name}
                  {c.isActive ? '' : ' (inactive)'}
                </span>
                <span className="flex items-center gap-tk-xs">
                  <button
                    type="button"
                    onClick={() => openEdit(c)}
                    disabled={busy}
                    className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
                  >
                    <PencilIcon className="h-3.5 w-3.5" /> Edit
                  </button>
                  <button
                    type="button"
                    onClick={() => toggleActive(c)}
                    disabled={busy}
                    className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
                  >
                    {c.isActive ? (
                      <EyeSlashIcon className="h-3.5 w-3.5" />
                    ) : (
                      <EyeIcon className="h-3.5 w-3.5" />
                    )}
                    {c.isActive ? 'Deactivate' : 'Reactivate'}
                  </button>
                </span>
              </li>
            ))}
          </ul>
        </div>
      )}

      <Dialog
        open={dialogOpen}
        onClose={() => {
          if (!busy) setDialogOpen(false);
        }}
        title={editing ? 'Edit entry' : 'Add entry'}
        dismissable={!busy}
      >
        <div className="space-y-tk-md">
          <div>
            <label className="mb-tk-xs block text-bodySmall text-light-text-secondary">Name</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              autoFocus
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            />
          </div>
          {editing ? (
            <label className="flex items-center gap-tk-sm text-bodySmall text-light-text">
              <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />
              Active
            </label>
          ) : null}
          <div className="flex justify-end gap-tk-sm pt-tk-sm">
            <button
              type="button"
              onClick={() => setDialogOpen(false)}
              disabled={busy}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              onClick={onSave}
              disabled={busy || !name.trim()}
              className="inline-flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
            >
              {busy ? <Spinner className="h-3.5 w-3.5" /> : null} Save
            </button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
