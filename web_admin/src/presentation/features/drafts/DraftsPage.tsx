import { useEffect, useMemo } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { TrashIcon } from '@heroicons/react/24/outline';
import { useDrafts } from '@/presentation/hooks/useDrafts';
import { useDeleteDraft } from '@/presentation/hooks/useDraftMutations';
import { useCartStore } from '@/presentation/stores/cartStore';
import { cartGrandTotal } from '@/domain/sales/cart';
import { formatMoney } from '@/core/utils/money';
import { RoutePaths } from '@/presentation/router/routePaths';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import type { Draft } from '@/domain/entities';

export function DraftsPage() {
  useEffect(() => {
    document.title = 'Drafts · MAKI POS Admin';
  }, []);

  const { data: drafts, isLoading, error } = useDrafts();
  const lines = useCartStore((s) => s.lines);
  const loadDraft = useCartStore((s) => s.loadDraft);
  const deleteDraft = useDeleteDraft();
  const navigate = useNavigate();

  const open = useMemo(() => (drafts ?? []).filter((d) => !d.isConverted), [drafts]);

  const onResume = (draft: Draft) => {
    if (lines.length > 0 && !window.confirm('Replace the current cart with this draft?')) return;
    loadDraft(draft);
    navigate(RoutePaths.pos);
  };
  const onDelete = (draft: Draft) => {
    if (!window.confirm(`Delete draft "${draft.name}"?`)) return;
    deleteDraft.mutate(draft.id);
  };

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Drafts</h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Held orders — resume one into the POS or delete it.
        </p>
      </header>

      {deleteDraft.error ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          Could not delete the draft: {deleteDraft.error.message}
        </p>
      ) : null}

      {error ? (
        <ErrorView title="Could not load drafts" message={error.message} />
      ) : isLoading || !drafts ? (
        <LoadingView label="Loading…" />
      ) : open.length === 0 ? (
        <EmptyState title="No drafts" description="Hold a cart from the POS with “Save as draft”." />
      ) : (
        <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <ul className="divide-y divide-light-hairline">
            {open.map((d) => {
              const count = d.items.reduce((s, i) => s + i.quantity, 0);
              const total = cartGrandTotal(d.items, d.laborLines, d.discountType);
              return (
                <li key={d.id} className="flex items-center justify-between gap-tk-md px-tk-md py-tk-sm">
                  <div className="min-w-0">
                    <div className="text-bodySmall font-medium text-light-text">{d.name}</div>
                    <div className="text-[12px] text-light-text-hint">
                      {count} item{count === 1 ? '' : 's'} · {formatMoney(total)}
                      {d.mechanicName ? ` · ${d.mechanicName}` : ''} ·{' '}
                      {d.createdAt.toLocaleDateString()}
                    </div>
                  </div>
                  <div className="flex items-center gap-tk-sm">
                    <Link
                      to={`/drafts/${d.id}`}
                      className="rounded-md border border-light-border px-tk-md py-[6px] text-[12px] font-medium text-light-text hover:bg-light-subtle"
                    >
                      Edit
                    </Link>
                    <button
                      type="button"
                      onClick={() => onResume(d)}
                      className="rounded-md bg-light-text px-tk-md py-[6px] text-[12px] font-semibold text-light-background hover:bg-primary-dark"
                    >
                      Resume
                    </button>
                    <button
                      type="button"
                      onClick={() => onDelete(d)}
                      className="text-light-text-hint hover:text-error"
                    >
                      <TrashIcon className="h-4 w-4" />
                    </button>
                  </div>
                </li>
              );
            })}
          </ul>
        </div>
      )}
    </div>
  );
}
