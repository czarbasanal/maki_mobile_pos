// /hr/payslips/:id — renders the frozen payslip as a PayslipCard, plus
// Delete (with confirm) and a Download JPG action (html2canvas, via
// downloadElementAsJpg on the PayslipCard container).

import { useEffect, useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { TrashIcon } from '@heroicons/react/24/outline';
import { useActivityLogRepo, usePayslipRepo } from '@/infrastructure/di/container';
import { logActivity } from '@/application/activityLogger';
import { ActivityType } from '@/domain/entities';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Dialog } from '@/presentation/components/common/Dialog';
import { PageHeader } from '@/presentation/features/settings/PageHeader';
import { RoutePaths } from '@/presentation/router/routePaths';
import { downloadElementAsJpg } from '@/core/utils/downloadJpg';
import { PayslipCard } from './PayslipCard';

// Lowercases, strips diacritics to their base letters (ñ→n, é→e — Filipino
// names must not lose characters to the filename), then replaces runs of
// remaining non-alphanumerics with a single dash, trimming the edges.
function slugify(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

export function PayslipDetailPage() {
  const { id = '' } = useParams();
  const repo = usePayslipRepo();
  const activityLogRepo = useActivityLogRepo();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [isRenderingJpg, setIsRenderingJpg] = useState(false);
  const [jpgError, setJpgError] = useState<string | null>(null);
  const cardRef = useRef<HTMLDivElement>(null);

  const {
    data: payslip,
    isLoading,
    error,
  } = useQuery({ queryKey: ['payslips', id], queryFn: () => repo.getById(id) });

  const del = useMutation<void, Error, void>({
    mutationFn: async () => {
      await repo.delete(id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.userManagement,
        action: `Deleted payslip: ${payslip?.employeeName ?? id}`,
        entityId: id,
        entityType: 'payslip',
      }));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payslips'] });
      navigate(RoutePaths.hrPayslips);
    },
  });

  useEffect(() => {
    document.title = payslip ? `${payslip.employeeName} payslip · MAKI POS Admin` : 'Payslip · MAKI POS Admin';
  }, [payslip]);

  if (error) return <ErrorView title="Could not load payslip" message={error.message} />;
  if (isLoading) return <LoadingView label="Loading payslip…" />;
  if (!payslip) {
    return (
      <div className="space-y-tk-lg">
        <PageHeader backTo={RoutePaths.hrPayslips} backLabel="Back" />
        <EmptyState title="Payslip not found" description="It may have been deleted." />
      </div>
    );
  }

  return (
    <div className="space-y-tk-lg">
      <div className="flex flex-wrap items-end justify-between gap-tk-md">
        <PageHeader
          title={payslip.employeeName}
          description={`${payslip.periodStart} – ${payslip.periodEnd}`}
          backTo={RoutePaths.hrPayslips}
          backLabel="Back"
        />
        <div className="flex flex-wrap items-center gap-tk-sm">
          {/* html2canvas can take a beat on a long slip and can fail outright
              (fonts, detached nodes) — silence either way reads as a broken
              button, so the render gets a busy state and a visible error. */}
          <button
            type="button"
            disabled={isRenderingJpg}
            onClick={() => {
              if (!cardRef.current || isRenderingJpg) return;
              setJpgError(null);
              setIsRenderingJpg(true);
              downloadElementAsJpg(
                cardRef.current,
                `payslip-${slugify(payslip.employeeName)}-${payslip.periodStart}.jpg`,
              )
                .catch(() => setJpgError('Could not create the JPG — try again.'))
                .finally(() => setIsRenderingJpg(false));
            }}
            className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
          >
            {isRenderingJpg ? 'Preparing…' : 'Download JPG'}
          </button>
          <button
            type="button"
            onClick={() => setConfirmDelete(true)}
            className="inline-flex items-center gap-tk-xs rounded-md border border-error-light px-tk-md py-tk-sm text-bodySmall text-error-dark hover:bg-error-light/40"
          >
            <TrashIcon className="h-4 w-4" /> Delete payslip
          </button>
        </div>
      </div>

      {del.error ? <p className="text-bodySmall text-error-dark">{del.error.message}</p> : null}
      {jpgError ? <p className="text-bodySmall text-error-dark">{jpgError}</p> : null}

      {/* w-fit, not a bare block: html2canvas captures this element's own
          box, and a full-width wrapper around the 380px card exported the card
          plus a band of white space to its right. */}
      <div ref={cardRef} className="w-fit">
        <PayslipCard payslip={payslip} />
      </div>

      <Dialog
        open={confirmDelete}
        onClose={() => {
          if (!del.isPending) setConfirmDelete(false);
        }}
        title="Delete payslip?"
        dismissable={!del.isPending}
      >
        <div className="space-y-tk-md">
          <p className="text-bodySmall text-light-text-secondary">
            Delete the payslip for “{payslip.employeeName}” ({payslip.periodStart} – {payslip.periodEnd})?
            This can’t be undone.
          </p>
          <div className="flex justify-end gap-tk-sm pt-tk-sm">
            <button
              type="button"
              disabled={del.isPending}
              onClick={() => setConfirmDelete(false)}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={del.isPending}
              onClick={() => del.mutate()}
              className="inline-flex items-center gap-tk-xs rounded-md bg-error-dark px-tk-md py-tk-sm text-bodySmall font-semibold text-white hover:opacity-90 disabled:opacity-60"
            >
              {del.isPending ? <Spinner className="h-3.5 w-3.5" /> : null} Delete
            </button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
