// Labor report (reports guide §1): "Jobs with labor" is a COUNT (the old
// "Service Sales 42" read like money), plus a derived Avg per job. The
// mechanic table carries a share-of-labor bar, and a one-row breakdown says
// why it is one row.
import { useEffect, useMemo } from 'react';
import { WrenchIcon } from '@heroicons/react/24/outline';
import { useReportData } from '@/presentation/hooks/useReportData';
import { deriveReportFigures } from '@/domain/reports/reportFigures';
import type { LaborByMechanic } from '@/domain/sales/laborReport';
import { toCsv, downloadCsv } from '@/core/utils/csv';
import { formatMoney } from '@/core/utils/money';
import { useAuthStore } from '@/presentation/stores/authStore';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { StatCard } from '@/presentation/components/ui/StatCard';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { MiniBar } from '@/presentation/components/ui/MiniBar';
import { ErrorState } from '@/presentation/components/ui/ErrorState';
import { ReportHeader } from './ReportHeader';
import { ReportTableCard } from './ReportTableCard';
import { EmptyRangeState } from './EmptyRangeState';
import { useReportRange } from './useReportRange';
import { csvFileName, pctLabel } from './reportFormat';

export function LaborReportPage() {
  const user = useAuthStore((st) => st.user);
  const dailyOnly = !!user && hasPermission(user.role, Permission.viewDailySalesOnly);
  const range = useReportRange('last7', dailyOnly);
  const { sales, isLoading, error, refetch } = useReportData(range.effectiveRange);
  const f = useMemo(() => deriveReportFigures(sales), [sales]);
  const report = f.laborReport;
  const mechanics = report.byMechanic.length;
  const share = (m: LaborByMechanic) => (report.totalLabor > 0 ? m.laborTotal / report.totalLabor : null);

  useEffect(() => {
    document.title = 'Labor report · MAKI POS Admin';
  }, []);

  const exportCsv = () =>
    downloadCsv(
      csvFileName('labor', range.effectiveRange),
      toCsv(
        ['Mechanic', 'Jobs', 'Labor', 'Avg per job', 'Share %'],
        report.byMechanic.map((m) => [
          m.mechanicName, m.jobCount, m.laborTotal.toFixed(2),
          (m.laborTotal / m.jobCount).toFixed(2), ((share(m) ?? 0) * 100).toFixed(1),
        ]),
      ),
    );

  const columns: Array<Column<LaborByMechanic>> = [
    { key: 'name', header: 'Mechanic', render: (m) => <span className="text-ctl-md font-medium text-ink">{m.mechanicName}</span> },
    {
      key: 'share', header: 'Share of labor', width: '44%',
      render: (m) => (
        <div className="flex items-center gap-2.5 pr-4">
          <MiniBar pct={(share(m) ?? 0) * 100} color="var(--accent)" />
          <span className="font-mono text-[11px] text-ink-3">{pctLabel(share(m))}</span>
        </div>
      ),
    },
    { key: 'jobs', header: 'Jobs', align: 'right', width: '80px', mono: true, render: (m) => <span className="text-ctl-md text-ink">{m.jobCount}</span> },
    { key: 'avg', header: 'Avg / job', align: 'right', width: '112px', mono: true, render: (m) => <span className="text-ctl-md text-ink-2">{formatMoney(m.laborTotal / m.jobCount)}</span> },
    { key: 'labor', header: 'Labor', align: 'right', width: '126px', mono: true, render: (m) => <span className="text-[13px] font-semibold text-ink">{formatMoney(m.laborTotal)}</span> },
  ];

  const footnote =
    mechanics !== 1 || isLoading
      ? null
      : report.byMechanic[0].mechanicId === null
        ? 'No mechanic is recorded on these jobs. Assign mechanics on the job order to break this down.'
        : 'One mechanic is recorded on every job in this range. Assign mechanics on the job order to break this down.';

  if (error) return <ErrorState message="Could not load labor." onRetry={refetch} />;

  return (
    <div className="flex flex-col gap-3">
      <ReportHeader
        range={range}
        lock={dailyOnly ? "Showing today's labor only. Contact an admin for historical reports." : undefined}
        onExport={exportCsv}
        exportDisabled={mechanics === 0}
      />

      <div className="grid grid-cols-[repeat(auto-fit,minmax(200px,1fr))] gap-3">
        <StatCard lead label="Total labor" value={report.totalLabor} format="currency" note={range.rangeNote} loading={isLoading} />
        <StatCard label="Jobs with labor" value={report.serviceSaleCount} format="number" note="service tickets billed" loading={isLoading} />
        <StatCard label="Avg per job" format="currency" loading={isLoading}
          value={report.serviceSaleCount > 0 ? report.totalLabor / report.serviceSaleCount : 0}
          note={`across ${mechanics} ${mechanics === 1 ? 'mechanic' : 'mechanics'}`} />
      </div>

      <ReportTableCard title="Labor by mechanic" note={range.rangeNote}>
        <DataTable
          columns={columns}
          rows={report.byMechanic}
          rowKey={(m) => m.mechanicId ?? '__unassigned__'}
          loading={isLoading}
          minWidth="640px"
          empty={
            <EmptyRangeState
              icon={<WrenchIcon className="h-[22px] w-[22px] text-ink-3" />}
              title="No labor in this range"
              description={`No service was billed ${range.rangeNote}. Labor is recorded when a job order with labor lines is billed out.`}
              onWiden={range.widen}
              widenLabel={range.widenLabel}
            />
          }
        />
        {footnote ? (
          <div className="flex items-center gap-2.5 border-t border-line bg-surface-2 px-5 py-[13px]">
            <span className="text-[11.5px] text-ink-3 [text-wrap:pretty]">{footnote}</span>
          </div>
        ) : null}
      </ReportTableCard>
    </div>
  );
}
