import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useDraft } from '@/presentation/hooks/useDraft';
import { useDraftEditStore } from '@/presentation/stores/draftEditStore';
import { useSaveDraft } from '@/presentation/hooks/useDraftMutations';
import { describedLaborLines } from '@/domain/sales/labor';
import { CartBuilder } from '@/presentation/features/pos/CartBuilder';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';

export function DraftEditPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const { data: draft, isLoading, error } = useDraft(id);
  const save = useSaveDraft();

  const loadDraft = useDraftEditStore((s) => s.loadDraft);
  const clear = useDraftEditStore((s) => s.clear);
  const lines = useDraftEditStore((s) => s.lines);
  const discountType = useDraftEditStore((s) => s.discountType);
  const laborLines = useDraftEditStore((s) => s.laborLines);
  const mechanicId = useDraftEditStore((s) => s.mechanicId);
  const mechanicName = useDraftEditStore((s) => s.mechanicName);

  const [name, setName] = useState('');
  const hydrated = useRef(false);

  useEffect(() => {
    document.title = 'Edit draft';
  }, []);
  useEffect(() => {
    if (draft && !draft.isConverted && !hydrated.current) {
      loadDraft(draft);
      setName(draft.name);
      hydrated.current = true;
    }
    return () => clear();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [draft]);

  if (error) return <ErrorView title="Could not load draft" message={error.message} />;
  if (isLoading || !draft) {
    if (!isLoading && !draft) {
      return (
        <div className="px-tk-xl py-tk-lg">
          <EmptyState title="Draft not found" description="It may have been deleted or already billed out." />
          <Link to={RoutePaths.drafts} className="mt-tk-md inline-block text-bodySmall text-light-text-secondary hover:text-light-text">← Drafts</Link>
        </div>
      );
    }
    return <LoadingView label="Loading draft…" />;
  }
  if (draft.isConverted) {
    return (
      <div className="px-tk-xl py-tk-lg">
        <EmptyState title="Can't edit this draft" description="This draft was already billed out and can't be edited." />
        <Link to={RoutePaths.drafts} className="mt-tk-md inline-block text-bodySmall text-light-text-secondary hover:text-light-text">← Drafts</Link>
      </div>
    );
  }

  const onSave = async () => {
    const trimmed = name.trim();
    if (!trimmed) return;
    try {
      await save.mutateAsync({
        draftId: id,
        name: trimmed,
        items: lines,
        discountType,
        laborLines: describedLaborLines(laborLines),
        mechanicId,
        mechanicName,
      });
      navigate(RoutePaths.drafts);
    } catch {
      // surfaced via save.error
    }
  };

  return (
    <div className="space-y-tk-md px-tk-xl py-tk-lg">
      <Link to={RoutePaths.drafts} className="text-bodySmall text-light-text-secondary hover:text-light-text">← Drafts</Link>
      <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Edit draft</h1>

      {save.error ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {save.error.message}
        </p>
      ) : null}

      <label className="block max-w-sm space-y-tk-xs">
        <span className="text-bodySmall text-light-text-secondary">Draft name</span>
        <input type="text" value={name} onChange={(e) => setName(e.target.value)}
          className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text" />
      </label>

      <CartBuilder store={useDraftEditStore} />

      <div className="flex justify-end gap-tk-sm">
        <Link to={RoutePaths.drafts} className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">Cancel</Link>
        <button type="button" onClick={onSave} disabled={save.isPending || !name.trim()}
          className={cn('rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark',
            (save.isPending || !name.trim()) && 'cursor-not-allowed opacity-60')}>
          {save.isPending ? 'Saving…' : 'Save changes'}
        </button>
      </div>
    </div>
  );
}
