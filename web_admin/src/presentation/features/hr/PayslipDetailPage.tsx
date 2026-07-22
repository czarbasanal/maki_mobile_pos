// /hr/payslips/:id — renders the frozen payslip as a PayslipCard, plus
// Delete (with confirm) and a Download JPG action. Download JPG is wired in
// a later task (html2canvas); the button is a disabled placeholder here.

import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { TrashIcon } from '@heroicons/react/24/outline';
import { usePayslipRepo } from '@/infrastructure/di/container';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Dialog } from '@/presentation/components/common/Dialog';
import { RoutePaths } from '@/presentation/router/routePaths';
import { PayslipCard } from './PayslipCard';

export function PayslipDetailPage() {
  const { id = '' } = useParams();
  const repo = usePayslipRepo();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [confirmDelete, setConfirmDelete] = useState(false);

  const {
    data: payslip,
    isLoading,
    error,
  } = useQuery({ queryKey: ['payslips', id], queryFn: () => repo.getById(id) });

  const del = useMutation<void, Error, void>({
    mutationFn: () => repo.delete(id),
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
      <div className="space-y-tk-lg px-tk-xl py-tk-lg">
        <BackLink />
        <EmptyState title="Payslip not found" description="It may have been deleted." />
      </div>
    );
  }

  return (
    <div className="space-y-tk-lg px-tk-xl py-tk-lg">
      <BackLink />

      <header className="flex flex-wrap items-center justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            {payslip.employeeName}
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            {payslip.periodStart} – {payslip.periodEnd}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-tk-sm">
          <button
            type="button"
            disabled
            className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text-hint opacity-60"
          >
            Download JPG
          </button>
          <button
            type="button"
            onClick={() => setConfirmDelete(true)}
            className="inline-flex items-center gap-tk-xs rounded-md border border-error-light px-tk-md py-tk-sm text-bodySmall text-error-dark hover:bg-error-light/40"
          >
            <TrashIcon className="h-4 w-4" /> Delete payslip
          </button>
        </div>
      </header>

      {del.error ? <p className="text-bodySmall text-error-dark">{del.error.message}</p> : null}

      <PayslipCard payslip={payslip} />

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

function BackLink() {
  return (
    <Link
      to={RoutePaths.hrPayslips}
      className="text-bodySmall text-light-text-secondary hover:underline"
    >
      ← Back to payslips
    </Link>
  );
}
