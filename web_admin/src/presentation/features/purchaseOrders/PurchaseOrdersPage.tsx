// Purchase orders list — per design/maki-pos-purchase-orders-redesign §A,
// assembled from the shared library: ViewChips over the three statuses, the
// amber primary, DataTable, and a teaching empty state per view. No summary
// cards — three views and a table is the whole screen.
//
// Our data has no trip-name field yet (the guide's open question §E) — a PO
// spans suppliers with the supplier decided per line, so the Trip column is
// omitted until the field exists.
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { PlusIcon } from '@heroicons/react/24/outline';
import { usePurchaseOrders } from '@/presentation/hooks/usePurchaseOrders';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { RoutePaths } from '@/presentation/router/routePaths';
import { formatMoney } from '@/core/utils/money';
import { formatInShopZone } from '@/domain/time/shopTime';
import { isPendingPurchaseOrder, type PurchaseOrder } from '@/domain/entities';
import { Badge } from '@/presentation/components/ui/Badge';
import { Button } from '@/presentation/components/ui/Button';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { FirstRunState } from '@/presentation/components/ui/TableEmptyStates';
import { ViewChips } from '@/presentation/components/ui/ViewChips';
import { statusTone } from '@/presentation/components/ui/statusTone';

type View = 'pending' | 'completed' | 'cancelled';

const STATUS_LABEL: Record<PurchaseOrder['status'], string> = {
  draft: 'Draft',
  ordered: 'Out buying',
  received: 'Completed',
  cancelled: 'Cancelled',
};

// Each view teaches what belongs in it — never one shared "nothing here".
const EMPTY_COPY: Record<View, { title: string; body: string }> = {
  pending: { title: 'Nothing pending', body: 'Start a purchase order to plan a buying trip.' },
  completed: {
    title: 'No completed orders',
    body: 'Orders you have finished buying against will land here.',
  },
  cancelled: { title: 'No cancelled orders', body: 'Orders you abandon keep their trail here.' },
};

const createdFmt = (d: Date) =>
  `${formatInShopZone(d, { month: 'short', day: 'numeric' })}, ${formatInShopZone(d, {
    year: 'numeric',
  })}`;

export function PurchaseOrdersPage() {
  const { data: orders, isLoading, error } = usePurchaseOrders();
  const [view, setView] = useState<View>('pending');
  const navigate = useNavigate();

  useEffect(() => {
    document.title = 'Purchase Orders · MAKI POS Admin';
  }, []);

  const byView = useMemo(() => {
    const all = orders ?? [];
    return {
      // Draft and ordered together: both are unfinished business — one still
      // being written, one out being bought.
      pending: all.filter(isPendingPurchaseOrder),
      completed: all.filter((o) => o.status === 'received'),
      cancelled: all.filter((o) => o.status === 'cancelled'),
    };
  }, [orders]);

  const rows = byView[view];

  const columns: Array<Column<PurchaseOrder>> = [
    {
      key: 'reference', header: 'Reference', mono: true,
      render: (po) => (
        <span className="flex items-center gap-1.5 font-medium">
          {po.referenceNumber}
          <CopyButton value={po.referenceNumber} label="reference" />
        </span>
      ),
    },
    {
      key: 'status', header: 'Status',
      render: (po) => <Badge tone={statusTone(po.status)}>{STATUS_LABEL[po.status]}</Badge>,
    },
    {
      key: 'created', header: 'Created',
      render: (po) => (
        <span className="flex flex-col gap-[2px]">
          <span className="font-mono text-micro text-ink-2">{createdFmt(po.createdAt)}</span>
          <span className="text-[10.5px] text-ink-3">by {po.createdByName || '—'}</span>
        </span>
      ),
    },
    {
      key: 'lines', header: 'Lines', align: 'right', width: '86px', mono: true,
      render: (po) => <span className="text-micro text-ink-2">{po.items.length}</span>,
    },
    {
      key: 'units', header: 'Units', align: 'right', width: '86px', mono: true,
      render: (po) => po.totalQuantity,
    },
    {
      key: 'cost', header: 'Est. cost', align: 'right', width: '126px', mono: true,
      render: (po) => (
        <span className="text-[13px] font-semibold tracking-[-0.3px]">
          {formatMoney(po.totalCost)}
        </span>
      ),
    },
  ];

  if (error) return <ErrorView title="Could not load purchase orders" message={error.message} />;

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-2">
        <ViewChips
          options={[
            { value: 'pending' as const, label: 'Pending', count: byView.pending.length },
            { value: 'completed' as const, label: 'Completed', count: byView.completed.length },
            { value: 'cancelled' as const, label: 'Cancelled', count: byView.cancelled.length },
          ]}
          value={view}
          onChange={setView}
        />
        <div className="ml-auto">
          <Button
            variant="primary"
            icon={<PlusIcon className="h-3.5 w-3.5" />}
            onClick={() => navigate(RoutePaths.purchaseOrderNew)}
          >
            New purchase order
          </Button>
        </div>
      </div>

      <section className="overflow-hidden rounded-card border border-line bg-surface shadow-card">
        <DataTable
          columns={columns}
          rows={rows}
          rowKey={(po) => po.id}
          onRowClick={(po) => navigate(`${RoutePaths.purchaseOrders}/${po.id}`)}
          loading={isLoading}
          minWidth="720px"
          empty={
            <FirstRunState
              icon={
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--accent-text)" strokeWidth="1.6">
                  <rect x="4.5" y="3.5" width="15" height="17" rx="2.6" />
                  <line x1="8.4" y1="8.6" x2="15.6" y2="8.6" />
                  <line x1="8.4" y1="12.4" x2="15.6" y2="12.4" />
                  <line x1="8.4" y1="16.2" x2="12.6" y2="16.2" />
                </svg>
              }
              title={EMPTY_COPY[view].title}
              description={EMPTY_COPY[view].body}
            >
              <Button
                variant="primary"
                icon={<PlusIcon className="h-3.5 w-3.5" />}
                onClick={() => navigate(RoutePaths.purchaseOrderNew)}
              >
                New purchase order
              </Button>
            </FirstRunState>
          }
        />
      </section>
    </div>
  );
}
