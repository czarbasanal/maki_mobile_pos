import { useEffect, useState } from 'react';
import { EyeIcon, EyeSlashIcon, PencilIcon, PlusIcon, TrashIcon } from '@heroicons/react/24/outline';
import { useAdjustmentReasons } from '@/presentation/hooks/useAdjustmentReasons';
import {
  useCreateAdjustmentReason,
  useDeleteAdjustmentReason,
  useSeedAdjustmentReasons,
  useUpdateAdjustmentReason,
} from '@/presentation/hooks/useAdjustmentReasonMutations';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Dialog } from '@/presentation/components/common/Dialog';
import type { AdjustmentReason } from '@/domain/entities';
import { cn } from '@/core/utils/cn';
import { PageHeader } from './PageHeader';
import { useAuthStore } from '@/presentation/stores/authStore';
import { hasPermission, Permission } from '@/domain/permissions/Permission';

export function AdjustmentReasonsPage() {
  const user = useAuthStore((st) => st.user);
  // editLists holders add + rename; deactivate/reactivate + delete + the
  // note-required flag need manageCategories (rules guard the flag).
  const canManage = !!user && hasPermission(user.role, Permission.manageCategories);
  useEffect(() => {
    document.title = 'Adjustment reasons · MAKI POS Admin';
  }, []);

  const { data: reasons, isLoading, error } = useAdjustmentReasons({ includeInactive: true });

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<AdjustmentReason | null>(null);
  const [name, setName] = useState('');
  const [requiresNote, setRequiresNote] = useState(false);
  const [active, setActive] = useState(true);

  const create = useCreateAdjustmentReason();
  const update = useUpdateAdjustmentReason();
  const del = useDeleteAdjustmentReason();
  const seed = useSeedAdjustmentReasons();
  const busy = create.isPending || update.isPending || del.isPending;

  const [deleting, setDeleting] = useState<AdjustmentReason | null>(null);

  const openAdd = () => {
    setEditing(null);
    setName('');
    setRequiresNote(false);
    setActive(true);
    setDialogOpen(true);
  };
  const openEdit = (r: AdjustmentReason) => {
    setEditing(r);
    setName(r.name);
    setRequiresNote(r.requiresNote);
    setActive(r.isActive);
    setDialogOpen(true);
  };

  const onSave = async () => {
    const trimmed = name.trim();
    if (!trimmed) return;
    if (editing) {
      await update.mutateAsync({
        id: editing.id,
        name: trimmed,
        // Only an editor with manageCategories can change the flag — the
        // checkbox isn't rendered for anyone else, so this stays the
        // reason's existing value for them.
        requiresNote: canManage ? requiresNote : editing.requiresNote,
        isActive: active,
      });
    } else {
      await create.mutateAsync({ name: trimmed, requiresNote });
    }
    setDialogOpen(false);
  };

  const toggleActive = async (r: AdjustmentReason) => {
    await update.mutateAsync({ id: r.id, isActive: !r.isActive });
  };

  const confirmDelete = async () => {
    if (!deleting) return;
    await del.mutateAsync({ id: deleting.id, name: deleting.name });
    setDeleting(null);
  };

  return (
    <div className="space-y-tk-xl">
      <div className="flex flex-wrap items-end justify-between gap-tk-md">
        <PageHeader />
        <button
          type="button"
          onClick={openAdd}
          className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
        >
          <PlusIcon className="h-3.5 w-3.5" /> Add
        </button>
      </div>

      {error ? (
        <ErrorView title="Could not load adjustment reasons" message={error.message} />
      ) : isLoading || !reasons ? (
        <LoadingView label="Loading…" />
      ) : reasons.length === 0 ? (
        <EmptyState
          title="No adjustment reasons yet"
          description="Seed the default set, or add the first reason."
          action={
            <button
              type="button"
              onClick={() => seed.mutate()}
              disabled={seed.isPending}
              className="inline-flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
            >
              {seed.isPending ? <Spinner className="h-3.5 w-3.5" /> : null} Seed defaults
            </button>
          }
        />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <ul className="divide-y divide-light-hairline">
            {reasons.map((r) => (
              <li key={r.id} className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm">
                <div className="min-w-0">
                  <span className="flex items-center gap-tk-xs">
                    <span
                      className={cn(
                        'block truncate text-bodySmall',
                        r.isActive ? 'text-light-text' : 'text-light-text-hint line-through',
                      )}
                    >
                      {r.name}
                      {r.isActive ? '' : ' (inactive)'}
                    </span>
                    {r.requiresNote ? (
                      <span className="shrink-0 rounded-full bg-light-subtle px-tk-sm py-[1px] text-xs text-light-text-secondary">
                        Note required
                      </span>
                    ) : null}
                  </span>
                </div>
                <span className="flex shrink-0 items-center gap-tk-xs">
                  <button
                    type="button"
                    onClick={() => openEdit(r)}
                    disabled={busy}
                    className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
                  >
                    <PencilIcon className="h-3.5 w-3.5" /> Edit
                  </button>
                  {canManage ? (
                    <button
                      type="button"
                      onClick={() => toggleActive(r)}
                      disabled={busy}
                      className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
                    >
                      {r.isActive ? <EyeSlashIcon className="h-3.5 w-3.5" /> : <EyeIcon className="h-3.5 w-3.5" />}
                      {r.isActive ? 'Deactivate' : 'Reactivate'}
                    </button>
                  ) : null}
                  {!r.isActive && canManage ? (
                    <button
                      type="button"
                      onClick={() => setDeleting(r)}
                      disabled={busy}
                      className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-error-dark hover:bg-error-light/40"
                    >
                      <TrashIcon className="h-3.5 w-3.5" /> Delete
                    </button>
                  ) : null}
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
        title={editing ? 'Edit adjustment reason' : 'Add adjustment reason'}
        dismissable={!busy}
      >
        <div className="space-y-tk-md">
          <div>
            <label htmlFor="reason-name" className="mb-tk-xs block text-bodySmall text-light-text-secondary">
              Name
            </label>
            <input
              id="reason-name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              autoFocus
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            />
          </div>
          {!editing || canManage ? (
            <label htmlFor="reason-requires-note" className="flex items-center gap-tk-sm text-bodySmall text-light-text">
              <input
                id="reason-requires-note"
                type="checkbox"
                checked={requiresNote}
                onChange={(e) => setRequiresNote(e.target.checked)}
              />
              Note required
            </label>
          ) : null}
          {editing && canManage ? (
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

      <Dialog
        open={deleting !== null}
        onClose={() => {
          if (!busy) setDeleting(null);
        }}
        title="Delete this entry?"
        description={
          deleting
            ? `"${deleting.name}" will be permanently deleted. Past adjustments keep the reason id but it disappears from the picker. Use Deactivate instead to just hide it.`
            : undefined
        }
        dismissable={!busy}
      >
        {del.error ? (
          <p className="mb-tk-md text-bodySmall text-error-dark">{del.error.message}</p>
        ) : null}
        <div className="flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => setDeleting(null)}
            disabled={busy}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={confirmDelete}
            disabled={busy}
            className="inline-flex items-center gap-tk-xs rounded-md bg-error px-tk-md py-tk-sm text-bodySmall font-semibold text-white hover:bg-error-dark disabled:opacity-60"
          >
            {del.isPending ? <Spinner className="h-3.5 w-3.5" /> : null} Delete
          </button>
        </div>
      </Dialog>
    </div>
  );
}
