import { useEffect, useState } from 'react';
import { EyeIcon, EyeSlashIcon, PencilIcon, PlusIcon, TrashIcon } from '@heroicons/react/24/outline';
import { useTags } from '@/presentation/hooks/useTags';
import { useCreateTag, useDeleteTag, useUpdateTag } from '@/presentation/hooks/useTagMutations';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Dialog } from '@/presentation/components/common/Dialog';
import type { Tag } from '@/domain/entities';
import { TAG_COLORS, tagChipStyle, type TagColor } from '@/domain/tags/tagColors';
import { cn } from '@/core/utils/cn';
import { PageHeader } from './PageHeader';
import { useAuthStore } from '@/presentation/stores/authStore';
import { hasPermission, Permission } from '@/domain/permissions/Permission';

export function ProductTagsPage() {
  const user = useAuthStore((st) => st.user);
  // editLists holders add + rename; deactivate/reactivate + delete need
  // manageCategories (mobile parity).
  const canManage = !!user && hasPermission(user.role, Permission.manageCategories);
  useEffect(() => {
    document.title = 'Product tags · MAKI POS Admin';
  }, []);

  const { data: tags, isLoading, error } = useTags({ includeInactive: true });

  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Tag | null>(null);
  const [name, setName] = useState('');
  const [color, setColor] = useState<TagColor>('gray');
  const [description, setDescription] = useState('');
  const [active, setActive] = useState(true);

  const create = useCreateTag();
  const update = useUpdateTag();
  const del = useDeleteTag();
  const busy = create.isPending || update.isPending || del.isPending;

  const [deleting, setDeleting] = useState<Tag | null>(null);

  const openAdd = () => {
    setEditing(null);
    setName('');
    setColor('gray');
    setDescription('');
    setActive(true);
    setDialogOpen(true);
  };
  const openEdit = (t: Tag) => {
    setEditing(t);
    setName(t.name);
    setColor(t.color);
    setDescription(t.description ?? '');
    setActive(t.isActive);
    setDialogOpen(true);
  };

  const onSave = async () => {
    const trimmed = name.trim();
    if (!trimmed) return;
    // Optional field: blank collapses to null so we don't persist empty
    // strings (and clearing a previously-set value nulls it out).
    const desc = description.trim() || null;
    if (editing) {
      await update.mutateAsync({
        id: editing.id,
        name: trimmed,
        color,
        description: desc,
        isActive: active,
      });
    } else {
      await create.mutateAsync({ name: trimmed, color, description: desc });
    }
    setDialogOpen(false);
  };

  const toggleActive = async (t: Tag) => {
    await update.mutateAsync({ id: t.id, isActive: !t.isActive });
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
        <ErrorView title="Could not load tags" message={error.message} />
      ) : isLoading || !tags ? (
        <LoadingView label="Loading…" />
      ) : tags.length === 0 ? (
        <EmptyState title="No tags yet" description="Add the first tag." />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <ul className="divide-y divide-light-hairline">
            {tags.map((t) => (
              <li key={t.id} className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm">
                <div className="min-w-0">
                  <span className="flex items-center gap-tk-xs">
                    <span
                      className="h-2.5 w-2.5 shrink-0 rounded-full"
                      style={{ background: tagChipStyle(t.color).fg }}
                    />
                    <span
                      className={cn(
                        'block truncate text-bodySmall',
                        t.isActive ? 'text-light-text' : 'text-light-text-hint line-through',
                      )}
                    >
                      {t.name}
                      {t.isActive ? '' : ' (inactive)'}
                    </span>
                  </span>
                  {t.description ? (
                    <span className="mt-0.5 block truncate text-xs text-light-text-secondary">
                      {t.description}
                    </span>
                  ) : null}
                </div>
                <span className="flex shrink-0 items-center gap-tk-xs">
                  <button
                    type="button"
                    onClick={() => openEdit(t)}
                    disabled={busy}
                    className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
                  >
                    <PencilIcon className="h-3.5 w-3.5" /> Edit
                  </button>
                  {canManage ? (
                    <button
                      type="button"
                      onClick={() => toggleActive(t)}
                      disabled={busy}
                      className="inline-flex items-center gap-1 rounded-md px-tk-sm py-[4px] text-bodySmall text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
                    >
                      {t.isActive ? <EyeSlashIcon className="h-3.5 w-3.5" /> : <EyeIcon className="h-3.5 w-3.5" />}
                      {t.isActive ? 'Deactivate' : 'Reactivate'}
                    </button>
                  ) : null}
                  {!t.isActive && canManage ? (
                    <button
                      type="button"
                      onClick={() => setDeleting(t)}
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
        title={editing ? 'Edit tag' : 'Add tag'}
        dismissable={!busy}
      >
        <div className="space-y-tk-md">
          <div>
            <label htmlFor="tag-name" className="mb-tk-xs block text-bodySmall text-light-text-secondary">
              Name
            </label>
            <input
              id="tag-name"
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              autoFocus
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            />
          </div>
          <div>
            <label className="mb-tk-xs block text-bodySmall text-light-text-secondary">Color</label>
            <div role="radiogroup" className="flex flex-wrap gap-tk-sm">
              {TAG_COLORS.map((c) => (
                <button
                  key={c}
                  type="button"
                  role="radio"
                  aria-checked={color === c}
                  aria-label={c}
                  onClick={() => setColor(c)}
                  className={cn(
                    'h-7 w-7 rounded-full border-2',
                    color === c ? 'border-light-text' : 'border-transparent',
                  )}
                  style={{ background: tagChipStyle(c).bg }}
                >
                  <span className="mx-auto block h-3 w-3 rounded-full" style={{ background: tagChipStyle(c).fg }} />
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="mb-tk-xs block text-bodySmall text-light-text-secondary">
              Description <span className="text-light-text-hint">(optional)</span>
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
              className="w-full resize-none rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            />
          </div>
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
            ? `"${deleting.name}" will be permanently deleted. Products keep the tag id but the chip disappears everywhere. Use Deactivate instead to just hide it.`
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
