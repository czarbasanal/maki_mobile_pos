// /hr/payslips — history list. Row click opens the detail page, which
// renders the PayslipCard and offers Delete + Download JPG.

import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { usePayslipRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from '@/presentation/hooks/useFirestoreSubscription';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Pager } from '@/presentation/components/common/Pager';
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize } from '@/presentation/hooks/usePageSize';
import { formatMoney } from '@/core/utils/money';
import { RoutePaths } from '@/presentation/router/routePaths';
import { PageHeader } from '@/presentation/features/settings/PageHeader';
import type { Payslip } from '@/domain/hr/types';

function parseIsoLocal(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function periodLabel(periodStart: string, periodEnd: string): string {
  const start = parseIsoLocal(periodStart).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
  });
  const end = parseIsoLocal(periodEnd).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
  return `${start} – ${end}`;
}

export function PayslipsPage() {
  useEffect(() => {
    document.title = 'Payslips · MAKI POS Admin';
  }, []);

  const repo = usePayslipRepo();
  const navigate = useNavigate();
  const {
    data: payslips,
    isLoading,
    error,
  } = useFirestoreSubscription<Payslip[]>((onData, onError) => repo.watchAll(onData, onError), [repo]);

  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = usePageSize('payslips');
  usePageClamp(page, setPage, payslips?.length ?? 0, pageSize);
  const paged = useMemo(
    () => (payslips ?? []).slice((page - 1) * pageSize, page * pageSize),
    [payslips, page, pageSize],
  );

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <PageHeader
        title="Payslips"
        description="Generated payslips, most recent pay period first."
      />

      {error ? (
        <ErrorView title="Could not load payslips" message={error.message} />
      ) : isLoading || !payslips ? (
        <LoadingView label="Loading payslips…" />
      ) : payslips.length === 0 ? (
        <EmptyState
          title="No payslips yet"
          description="Generate the first one from the Payroll page."
        />
      ) : (
        <section className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
          <table className="w-full text-bodySmall">
            <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
              <tr>
                <th className="px-tk-md py-tk-sm text-left font-medium">Period</th>
                <th className="px-tk-md py-tk-sm text-left font-medium">Employee</th>
                <th className="px-tk-md py-tk-sm text-right font-medium">Gross</th>
                <th className="px-tk-md py-tk-sm text-right font-medium">Net</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-light-hairline">
              {paged.map((p) => (
                <tr
                  key={p.id}
                  onClick={() => navigate(`${RoutePaths.hrPayslips}/${p.id}`)}
                  className="cursor-pointer hover:bg-light-subtle"
                >
                  <td className="px-tk-md py-tk-sm text-light-text">
                    {periodLabel(p.periodStart, p.periodEnd)}
                  </td>
                  <td className="px-tk-md py-tk-sm font-medium text-light-text">{p.employeeName}</td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums text-light-text">
                    {formatMoney(p.computed.gross)}
                  </td>
                  <td className="px-tk-md py-tk-sm text-right tabular-nums font-semibold text-light-text">
                    {formatMoney(p.computed.net)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <Pager total={payslips.length} page={page} onPage={setPage} pageSize={pageSize}
            onPageSize={(n) => { setPageSize(n); setPage(1); }} />
        </section>
      )}
    </div>
  );
}
