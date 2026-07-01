import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { ArrowLeftIcon } from '@heroicons/react/24/outline';
import { RoutePaths } from '@/presentation/router/routePaths';
import { resolvePreset, type DateRange } from '@/domain/reports/dateRange';
import { useReportData } from '@/presentation/hooks/useReportData';
import { summarizeLabor } from '@/domain/sales/laborReport';
import { formatMoney } from '@/core/utils/money';
import { DateRangePicker } from '@/presentation/components/common/DateRangePicker';
import { SummaryCard } from '@/presentation/features/dashboard/SummaryCard';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';

export function LaborReportPage() {
  const [range, setRange] = useState<DateRange>(() => resolvePreset('last7'));
  const { sales, isLoading, error } = useReportData(range);
  const report = useMemo(() => summarizeLabor(sales), [sales]);

  useEffect(() => {
    document.title = 'Labor report · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <Link
            to={RoutePaths.reports}
            className="mb-tk-xs inline-flex items-center gap-tk-xs text-bodySmall text-light-text-secondary hover:text-light-text"
          >
            <ArrowLeftIcon className="h-3.5 w-3.5" /> Reports
          </Link>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            Labor report
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Service revenue and per-mechanic breakdown for the selected range.
          </p>
        </div>
        <DateRangePicker onChange={setRange} />
      </header>

      {error ? (
        <ErrorView title="Could not load labor" message={error.message} />
      ) : isLoading ? (
        <div className="h-32">
          <LoadingView label="Loading…" />
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2 lg:grid-cols-4">
            <SummaryCard title="Total Labor" value={formatMoney(report.totalLabor)} emphasized />
            <SummaryCard title="Service Sales" value={String(report.serviceSaleCount)} />
          </div>

          <section className="rounded-lg border border-light-hairline bg-light-card p-tk-lg">
            <h2 className="mb-tk-md text-bodyMedium font-semibold text-light-text">
              Labor by mechanic
            </h2>
            {report.byMechanic.length === 0 ? (
              <p className="text-bodySmall text-light-text-hint">
                No labor recorded in this range.
              </p>
            ) : (
              <table className="w-full text-bodySmall">
                <thead className="text-light-text-secondary">
                  <tr>
                    <th className="py-tk-xs text-left font-medium">Mechanic</th>
                    <th className="py-tk-xs text-right font-medium">Jobs</th>
                    <th className="py-tk-xs text-right font-medium">Labor</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-light-hairline">
                  {report.byMechanic.map((m) => (
                    <tr key={m.mechanicId ?? '__unassigned__'}>
                      <td className="py-tk-xs">{m.mechanicName}</td>
                      <td className="py-tk-xs text-right tabular-nums">{m.jobCount}</td>
                      <td className="py-tk-xs text-right tabular-nums">{formatMoney(m.laborTotal)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </section>
        </>
      )}
    </div>
  );
}
