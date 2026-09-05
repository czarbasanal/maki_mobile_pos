// Sales report (reports guide §1): KPI strip with Gross sales (parts only —
// labor is its own track, client decision 2026-09-05) leading, the payment
// split as a segmented BreakdownCard with the revenue split beneath, top
// products with a Qty / Revenue / Margin lens and proportional bars, then
// the sales table with its "Total shown" foot. Every figure comes from
// deriveReportFigures over the one scoped fetch; the empty range explains
// itself and offers a way out.
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChartBarIcon } from '@heroicons/react/24/outline';
import { SALES_FETCH_CAP, useReportData } from '@/presentation/hooks/useReportData';
import { deriveReportFigures, PAYMENT_COLOR, topProductsBy, type TopProductLens } from '@/domain/reports/reportFigures';
import { saleGrandTotal, saleIsVoided, saleTotalItemCount, type Sale } from '@/domain/entities';
import { paymentMethodDisplayName } from '@/domain/enums';
import { salesToCsv, downloadCsv } from '@/core/utils/csv';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import { useAuthStore } from '@/presentation/stores/authStore';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize } from '@/presentation/hooks/usePageSize';
import { CappedNotice } from '@/presentation/components/common/CappedNotice';
import { StatCard } from '@/presentation/components/ui/StatCard';
import { Card } from '@/presentation/components/ui/Card';
import { BreakdownCard } from '@/presentation/components/ui/BreakdownCard';
import { MiniBar } from '@/presentation/components/ui/MiniBar';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { TableFooter } from '@/presentation/components/ui/TableFooter';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { Badge } from '@/presentation/components/ui/Badge';
import { Chip } from '@/presentation/components/ui/Chip';
import { Skeleton } from '@/presentation/components/ui/Skeleton';
import { Button } from '@/presentation/components/ui/Button';
import { ErrorState } from '@/presentation/components/ui/ErrorState';
import { ReportHeader } from './ReportHeader';
import { ReportTableCard } from './ReportTableCard';
import { SaleLines } from './SaleLines';
import { EmptyRangeState } from '@/presentation/components/ui/EmptyRangeState';
import { useReportRange } from '@/presentation/hooks/useReportRange';
import { csvFileName, pctLabel, whenLabel } from '@/core/utils/reportFormat';

export function SalesReportPage() {
  const navigate = useNavigate();
  const user = useAuthStore((st) => st.user);
  const dailyOnly = !!user && hasPermission(user.role, Permission.viewDailySalesOnly);
  // Margin derives from product cost — admin-only (viewProductCost).
  const canSeeCost = !!user && hasPermission(user.role, Permission.viewProductCost);
  // Today, not a week: this page is opened to answer "how are we doing today".
  const range = useReportRange('today', dailyOnly);
  const { sales, capped, isLoading, error, refetch } = useReportData(range.effectiveRange);
  const f = useMemo(() => deriveReportFigures(sales), [sales]);

  const [lens, setLens] = useState<TopProductLens>('revenue');
  const effectiveLens: TopProductLens = lens === 'margin' && !canSeeCost ? 'revenue' : lens;
  const top = useMemo(() => topProductsBy(f.products, effectiveLens), [f.products, effectiveLens]);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = usePageSize('salesReport');
  // Lines expanded in place under a sale (DataTable expansion).
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(new Set());
  usePageClamp(page, setPage, sales.length, pageSize);

  useEffect(() => {
    document.title = 'Sales report · MAKI POS Admin';
  }, []);
  // A page number from the previous range may now point past the end.
  useEffect(() => {
    setPage(1);
  }, [range.effectiveRange]);

  const paged = useMemo(() => sales.slice((page - 1) * pageSize, page * pageSize), [sales, page, pageSize]);
  const allOpen = paged.length > 0 && paged.every((s) => expanded.has(s.id));
  const toggleLines = (s: Sale) =>
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(s.id)) next.delete(s.id);
      else next.add(s.id);
      return next;
    });
  // Voided sales stay listed (struck through) for the audit trail but are
  // out of every figure — the chip and the foot say so.
  const voidedCount = sales.length - f.count;

  // Per-lens row treatment: the lens value is the bold figure and drives the
  // bar; the other figure rides beside it dimmed. Margin's bar is absolute
  // (a 90% margin is 90% of the rail), the others are relative to the top row.
  const lensMax = top.reduce((m, p) => Math.max(m, effectiveLens === 'qty' ? p.qty : p.revenue), 0);
  const lensRow = (p: (typeof top)[number]) => {
    if (effectiveLens === 'qty') {
      return { primary: `${p.qty} sold`, secondary: formatMoney(p.revenue), pct: lensMax > 0 ? (p.qty / lensMax) * 100 : 0 };
    }
    if (effectiveLens === 'margin') {
      return { primary: pctLabel(p.margin), secondary: formatMoney(p.profit), pct: (p.margin ?? 0) * 100 };
    }
    return { primary: formatMoney(p.revenue), secondary: `×${p.qty}`, pct: lensMax > 0 ? (p.revenue / lensMax) * 100 : 0 };
  };
  const lenses: Array<{ value: TopProductLens; label: string }> = [
    { value: 'qty', label: 'Qty' },
    { value: 'revenue', label: 'Revenue' },
    ...(canSeeCost ? [{ value: 'margin' as const, label: 'Margin' }] : []),
  ];

  const columns: Array<Column<Sale>> = [
    {
      key: 'no', header: 'Sale no.', mono: true,
      render: (s) => {
        const voided = saleIsVoided(s);
        return (
          <div className="flex items-center gap-[7px]">
            <span className={cn('whitespace-nowrap font-mono text-ctl-md font-medium', voided ? 'text-ink-3 line-through' : 'text-ink')}>
              {s.saleNumber}
            </span>
            <CopyButton value={s.saleNumber} label="sale number" />
            {voided ? <Badge tone="neutral" shape="chip">Void</Badge> : null}
          </div>
        );
      },
    },
    { key: 'when', header: 'When', mono: true, render: (s) => <span className="text-[12px] text-ink-2">{whenLabel(s.createdAt)}</span> },
    { key: 'paid', header: 'Paid via', render: (s) => <span className="text-ink-2">{paymentMethodDisplayName[s.paymentMethod]}</span> },
    { key: 'items', header: 'Items', align: 'right', width: '80px', mono: true, render: (s) => <span className="text-[12px] text-ink-2">{saleTotalItemCount(s)}</span> },
    {
      key: 'total', header: 'Total', align: 'right', width: '126px', mono: true,
      render: (s) => (
        <span className={cn('text-[13px] font-semibold', saleIsVoided(s) ? 'text-ink-3 line-through' : 'text-ink')}>
          {formatMoney(saleGrandTotal(s))}
        </span>
      ),
    },
  ];

  if (error) return <ErrorState message="Could not load sales." onRetry={refetch} />;

  return (
    <div className="flex flex-col gap-3">
      <ReportHeader
        range={range}
        lock={dailyOnly ? "Showing today's sales only. Contact an admin for historical reports." : undefined}
        onExport={() => downloadCsv(csvFileName('sales', range.effectiveRange), salesToCsv(sales))}
        exportDisabled={sales.length === 0}
      />

      <CappedNotice capped={capped}>
        Showing the most recent {SALES_FETCH_CAP.toLocaleString('en-US')} sales — narrow the date range for exact totals.
      </CappedNotice>

      <div className="grid grid-cols-[repeat(auto-fit,minmax(200px,1fr))] gap-3">
        <StatCard lead label="Gross sales" value={f.gross} format="currency" note={`parts ${range.rangeNote}`} loading={isLoading} />
        <StatCard label="Net sales" value={f.net} format="currency" loading={isLoading}
          note={f.discounts > 0 ? `after ${formatMoney(f.discounts)} in discounts` : 'no discounts given'} />
        <StatCard label="Service / labor" value={f.labor} format="currency" loading={isLoading}
          note="reported separately from gross" />
        <StatCard label="Avg order" value={f.avgOrder} format="currency" loading={isLoading}
          note={f.count > 0 ? `net parts across ${f.count} ${f.count === 1 ? 'sale' : 'sales'}` : 'no sales yet'} />
      </div>

      <div className="grid grid-cols-[repeat(auto-fit,minmax(320px,1fr))] items-stretch gap-3">
        {isLoading ? (
          <>
            <Skeleton height="260px" />
            <Skeleton height="260px" />
          </>
        ) : (
          <>
            <BreakdownCard
              testId="by-payment-card"
              label="By payment method"
              total={formatMoney(f.tendered)}
              bar={f.byPaymentMethod.map((m) => ({ key: m.method, color: PAYMENT_COLOR[m.method], pct: (m.share ?? 0) * 100 }))}
              rows={f.byPaymentMethod.map((m) => ({
                key: m.method,
                label: m.label,
                color: PAYMENT_COLOR[m.method],
                value: (
                  <>
                    <span className="font-mono text-[10.5px] text-ink-3">{pctLabel(m.share)}</span>
                    <span className="font-mono text-ctl-md font-semibold text-ink">{formatMoney(m.amount)}</span>
                  </>
                ),
              }))}
              footer={
                <div className="flex flex-col gap-[9px] pt-1">
                  <span className="text-micro-caps uppercase text-ink-3">Revenue split</span>
                  {[
                    ['Parts', f.net],
                    ['Service / Labor', f.labor],
                    ['Shop fees', f.fees],
                  ].map(([name, value]) => (
                    <div key={name} className="flex items-center gap-[9px]">
                      <span className="text-ctl-md text-ink-2">{name}</span>
                      <span className="ml-auto font-mono text-ctl-md font-semibold text-ink">{formatMoney(value as number)}</span>
                    </div>
                  ))}
                </div>
              }
            />

            <Card
              title="Top products"
              headerAction={
                <div className="flex gap-1">
                  {lenses.map((l) => (
                    <Chip key={l.value} active={effectiveLens === l.value} onClick={() => setLens(l.value)}>
                      {l.label}
                    </Chip>
                  ))}
                </div>
              }
            >
              {top.length === 0 ? (
                <div className="flex flex-col gap-[5px] px-3 py-10 text-center">
                  <span className="text-ctl-md font-medium text-ink-2">No products sold in this range</span>
                  <span className="text-kpi-label font-normal text-ink-3">
                    {dailyOnly ? 'Nothing sold yet today.' : 'Widen the range above to see movement.'}
                  </span>
                </div>
              ) : (
                <div data-testid="top-products" className="flex h-full flex-col justify-between gap-[13px]">
                  {top.map((p, i) => {
                    const row = lensRow(p);
                    return (
                      <div key={p.productId} className="flex flex-col gap-1.5">
                        <div className="flex items-baseline gap-[9px]">
                          <span className="w-4 shrink-0 font-mono text-[10.5px] text-ink-3">{String(i + 1).padStart(2, '0')}</span>
                          <span data-testid="top-product-name" className="min-w-0 truncate text-ctl-md font-medium text-ink">{p.name}</span>
                          <span className="ml-auto font-mono text-[10.5px] text-ink-3">{row.secondary}</span>
                          <span className="font-mono text-ctl-md font-semibold text-ink">{row.primary}</span>
                        </div>
                        <div className="flex pl-[25px]">
                          <MiniBar pct={row.pct} color="var(--accent)" />
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </Card>
          </>
        )}
      </div>

      <ReportTableCard
        title="Sales"
        count={isLoading ? undefined : f.count}
        note={!isLoading && voidedCount > 0 ? `${voidedCount} voided` : undefined}
        action={
          paged.length > 0 ? (
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setExpanded(allOpen ? new Set() : new Set(paged.map((s) => s.id)))}
            >
              {allOpen ? 'Collapse all' : 'Expand all'}
            </Button>
          ) : null
        }
      >
        <DataTable
          columns={columns}
          rows={paged}
          rowKey={(s) => s.id}
          onRowClick={(s) => navigate(`/reports/sale/${s.id}`)}
          expansion={{
            isExpanded: (s) => expanded.has(s.id),
            onToggle: toggleLines,
            render: (s) => <SaleLines sale={s} />,
            label: (s) => `Show lines for ${s.saleNumber}`,
          }}
          loading={isLoading}
          minWidth="720px"
          foot={
            <tr className="border-t border-line bg-surface-2">
              <td colSpan={4} className="px-5 py-3 text-[12px] font-semibold text-ink-2">
                Total tendered
                {voidedCount > 0 ? <span className="ml-2 font-normal text-ink-3">excl. {voidedCount} voided</span> : null}
              </td>
              <td data-testid="total-shown" className="px-5 py-3 text-right font-mono text-[15px] font-semibold tracking-[-0.5px] text-ink">
                {formatMoney(f.tendered)}
              </td>
            </tr>
          }
          empty={
            <EmptyRangeState
              icon={<ChartBarIcon className="h-[22px] w-[22px] text-ink-3" />}
              title="No sales in this range"
              description={
                dailyOnly
                  ? 'The register recorded nothing today. Check whether the shift was opened.'
                  : `The register recorded nothing ${range.rangeNote}. Try ${range.widenLabel ? range.widenLabel.replace('Show l', 'L') : 'a wider range'}, or check whether the shift was opened.`
              }
              onWiden={range.widen}
              widenLabel={range.widenLabel}
            />
          }
        />
        {sales.length > 0 && !isLoading ? (
          <TableFooter total={sales.length} page={page} pageSize={pageSize} onPage={setPage}
            onPageSize={(n) => { setPageSize(n); setPage(1); }} />
        ) : null}
      </ReportTableCard>
    </div>
  );
}
