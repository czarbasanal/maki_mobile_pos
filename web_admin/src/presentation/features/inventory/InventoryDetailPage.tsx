import { useEffect, type ReactNode } from 'react';
import { Link, generatePath, useParams } from 'react-router-dom';
import { ArrowLeftIcon, ClockIcon, PencilSquareIcon } from '@heroicons/react/24/outline';
import { useProduct } from '@/presentation/hooks/useProduct';
import { getStockStatus, StockStatus } from '@/domain/entities';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { RoutePaths } from '@/presentation/router/routePaths';
import { formatMoney } from '@/core/utils/money';

const STOCK_LABEL: Record<StockStatus, string> = {
  [StockStatus.inStock]: 'In stock',
  [StockStatus.lowStock]: 'Low stock',
  [StockStatus.outOfStock]: 'Out of stock',
};

function fmtDate(d: Date | null): string {
  if (!d) return '—';
  return d.toLocaleString('en-PH', { dateStyle: 'medium', timeStyle: 'short' });
}

export function InventoryDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { data: product, isLoading, error } = useProduct(id);

  useEffect(() => {
    document.title = product ? `${product.name} · Inventory` : 'Inventory';
  }, [product]);

  if (error) return <ErrorView title="Could not load product" message={error.message} />;
  if (isLoading) return <LoadingView label="Loading product…" />;
  if (!product) {
    return (
      <div className="space-y-tk-lg px-tk-xl py-tk-lg">
        <BackLink />
        <EmptyState title="Product not found" description="This product may have been removed." />
      </div>
    );
  }

  const s = getStockStatus(product);
  const margin = product.price - product.cost;
  const marginPct = product.price > 0 ? (margin / product.price) * 100 : 0;

  return (
    <div className="space-y-tk-lg px-tk-xl py-tk-lg">
      <BackLink />
      <header className="flex items-start justify-between gap-tk-md">
        <div className="flex items-center gap-tk-md">
          {product.imageUrl ? (
            <img src={product.imageUrl} alt="" className="h-16 w-16 rounded-md object-cover" />
          ) : null}
          <div>
            <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">{product.name}</h1>
            <p className="mt-tk-xs text-bodySmall text-light-text-hint">{product.sku}</p>
          </div>
        </div>
        <div className="flex items-center gap-tk-sm">
          {!product.isActive ? (
            <span className="rounded-full bg-light-subtle px-tk-sm py-[2px] text-[11px] font-medium text-light-text-secondary">
              Inactive
            </span>
          ) : null}
          <Link
            to={generatePath(RoutePaths.productEdit, { id: product.id })}
            className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
          >
            <PencilSquareIcon className="h-4 w-4" /> Edit
          </Link>
        </div>
      </header>

      <div className="grid grid-cols-1 gap-tk-lg sm:grid-cols-2">
        <Card title="Stock">
          <Field label="Quantity" value={`${product.quantity} ${product.unit}`} />
          <Field label="Reorder level" value={String(product.reorderLevel)} />
          <Field label="Status" value={STOCK_LABEL[s]} />
        </Card>
        <Card title="Pricing">
          <Field label="Price" value={formatMoney(product.price)} />
          <Field label="Cost" value={formatMoney(product.cost)} />
          <Field label="Margin" value={`${formatMoney(margin)} (${marginPct.toFixed(1)}%)`} />
        </Card>
        <Card title="Details">
          <Field label="Category" value={product.category ?? '—'} />
          <Field label="Unit" value={product.unit} />
          <Field label="Supplier" value={product.supplierName ?? '—'} />
          <Field label="Barcode" value={product.barcode ?? '—'} />
          <Field label="Notes" value={product.notes ?? '—'} />
        </Card>
        <Card title="Audit">
          <Field label="Created by" value={product.createdByName ?? product.createdBy ?? '—'} />
          <Field label="Created at" value={fmtDate(product.createdAt)} />
          <Field label="Updated by" value={product.updatedByName ?? product.updatedBy ?? '—'} />
          <Field label="Updated at" value={fmtDate(product.updatedAt)} />
        </Card>
      </div>

      <Link
        to={`${RoutePaths.priceHistory}?product=${product.id}`}
        className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
      >
        <ClockIcon className="h-4 w-4" />
        View price history
      </Link>
    </div>
  );
}

function BackLink() {
  return (
    <Link
      to={RoutePaths.inventory}
      className="inline-flex items-center gap-tk-xs text-bodySmall text-light-text-secondary hover:text-light-text"
    >
      <ArrowLeftIcon className="h-4 w-4" /> Back to inventory
    </Link>
  );
}

function Card({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="rounded-lg border border-light-hairline bg-light-card p-tk-lg">
      <h2 className="mb-tk-md text-bodyMedium font-semibold text-light-text">{title}</h2>
      <dl className="space-y-tk-sm">{children}</dl>
    </div>
  );
}
function Field({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between gap-tk-md">
      <dt className="text-bodySmall text-light-text-hint">{label}</dt>
      <dd className="text-right text-bodySmall text-light-text">{value}</dd>
    </div>
  );
}
