import { useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  saleGrandTotal, saleTotalItemCount, type Sale,
} from '@/domain/entities';
import { paymentMethodDisplayName, saleStatusDisplayName } from '@/domain/enums';
import { formatInShopZone } from '@/domain/time/shopTime';
import { formatMoney } from '@/core/utils/money';
import { Badge } from '@/presentation/components/ui/Badge';
import { Card } from '@/presentation/components/ui/Card';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { DataTable, type Column } from '@/presentation/components/ui/DataTable';
import { EmptyState } from '@/presentation/components/ui/EmptyState';
import { SearchInput } from '@/presentation/components/ui/SearchInput';
import { statusTone } from '@/presentation/components/ui/statusTone';
import { RoutePaths } from '@/presentation/router/routePaths';

const LIMIT = 8;

export function RecentSalesTable({ sales, loading }: { sales: Sale[]; loading: boolean }) {
  const navigate = useNavigate();
  const [query, setQuery] = useState('');

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase();
    const filtered = q ? sales.filter((s) => s.saleNumber.toLowerCase().includes(q)) : sales;
    return filtered.slice(0, LIMIT);
  }, [sales, query]);

  const columns: Array<Column<Sale>> = [
    {
      key: 'saleNo', header: 'Sale no.', mono: true,
      render: (sale) => (
        <span className="flex items-center gap-[7px]">
          {sale.saleNumber}
          <CopyButton value={sale.saleNumber} label="sale number" />
        </span>
      ),
    },
    {
      key: 'time', header: 'Time', mono: true,
      render: (sale) => formatInShopZone(sale.createdAt, { hour: 'numeric', minute: '2-digit', hour12: true }),
    },
    {
      key: 'items', header: 'Items',
      render: (sale) => {
        const n = saleTotalItemCount(sale);
        return `${n} ${n === 1 ? 'item' : 'items'}`;
      },
    },
    { key: 'tender', header: 'Tender', render: (sale) => paymentMethodDisplayName[sale.paymentMethod] },
    {
      key: 'status', header: 'Status',
      render: (sale) => <Badge tone={statusTone(sale.status)}>{saleStatusDisplayName[sale.status]}</Badge>,
    },
    {
      key: 'total', header: 'Total', align: 'right', mono: true,
      render: (sale) => formatMoney(saleGrandTotal(sale)),
    },
  ];

  return (
    <Card
      title="Recent sales"
      headerAction={
        <>
          <SearchInput value={query} onChange={setQuery} placeholder="Search sale no." />
          <Link to={RoutePaths.daySales} className="text-ctl-sm font-medium text-ink-2 hover:text-ink">View all</Link>
        </>
      }
      padding="sm"
    >
      <DataTable
        columns={columns}
        rows={rows}
        rowKey={(sale) => sale.id}
        onRowClick={(sale) => navigate(`/reports/sale/${sale.id}`)}
        loading={loading}
        empty={<EmptyState message={query ? `No sales matching “${query}”` : 'No sales yet today'} />}
      />
    </Card>
  );
}
