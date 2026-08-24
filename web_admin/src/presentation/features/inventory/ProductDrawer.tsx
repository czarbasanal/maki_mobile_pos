// Product view, rendered as a drawer over the inventory list rather than its
// own page — you keep your place in the list instead of navigating away and
// paging back. Still URL-backed at /inventory/:id, so Back closes it, a
// refresh reopens it, and a link to a product stays shareable.
//
// Replaces the former InventoryDetailPage; the cards stack in one column
// because the panel is narrower than a page.
import { useEffect, useState, type ReactNode } from 'react';
import { Link, generatePath, useNavigate, useParams } from 'react-router-dom';
import {
  AdjustmentsHorizontalIcon,
  ArrowPathIcon,
  ClockIcon,
  PencilSquareIcon,
} from '@heroicons/react/24/outline';
import { useProduct } from '@/presentation/hooks/useProduct';
import { useReactivateProduct } from '@/presentation/hooks/useProductMutations';
import { getStockStatus, StockStatus } from '@/domain/entities';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { useAuthStore } from '@/presentation/stores/authStore';
import { displaySku } from '@/domain/products/sku';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { Drawer } from '@/presentation/components/common/Drawer';
import { ProductImage } from '@/presentation/components/common/ProductImage';
import { AdjustStockDialog } from './AdjustStockDialog';
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

export function ProductDrawer() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data: product, isLoading, error } = useProduct(id);
  const [adjustOpen, setAdjustOpen] = useState(false);
  const reactivate = useReactivateProduct();
  const user = useAuthStore((s) => s.user);
  // Cost (and margin, which reveals it) is admin-only — the phone hides it
  // behind a password; the web must not hand it to anyone who can browse.
  const canSeeCost =
    !!user && hasPermission(user.role, Permission.viewProductCost);
  // Stock and activation are in the cashier rules denylist — staff/admin only.
  const canEditStock =
    !!user &&
    (hasPermission(user.role, Permission.editProduct) ||
      hasPermission(user.role, Permission.editProductLimited));

  useEffect(() => {
    document.title = product ? `${product.name} · Inventory` : 'Inventory';
  }, [product]);

  const close = () => navigate(RoutePaths.inventory);

  // A write in flight must not be dismissed out from under itself.
  const busy = reactivate.isPending;

  return (
    <Drawer
      open
      onClose={close}
      title={product?.name ?? 'Product'}
      description={product ? displaySku(product.sku) : undefined}
      dismissable={!busy}
    >
      {error ? (
        <ErrorView title="Could not load product" message={error.message} />
      ) : isLoading ? (
        <LoadingView label="Loading product…" />
      ) : !product ? (
        <EmptyState title="Product not found" description="This product may have been removed." />
      ) : (
        <div className="space-y-tk-lg">
          {/* SKU lives in the drawer header (`description`), so it is not
              repeated here. */}
          <div className="flex items-start gap-tk-md">
            <ProductImage src={product.imageUrl} alt={product.name} size="lg" />
            {!product.isActive && canEditStock ? (
              <span className="inline-block rounded-full bg-light-subtle px-tk-sm py-[2px] text-[11px] font-medium text-light-text-secondary">
                Inactive
              </span>
            ) : null}
          </div>

          {/* The three actions share the drawer's full width equally. */}
          <div className="flex items-stretch gap-tk-sm">
            {canSeeCost ? (
            <Link
              to={`${RoutePaths.priceHistory}?product=${product.id}`}
              className="inline-flex flex-1 items-center justify-center gap-tk-xs whitespace-nowrap rounded-md border border-light-border px-tk-sm py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              <ClockIcon className="h-4 w-4" /> Price history
            </Link>
            ) : null}
            {canEditStock ? (
            <button
              type="button"
              onClick={() => setAdjustOpen(true)}
              className="inline-flex flex-1 items-center justify-center gap-tk-xs whitespace-nowrap rounded-md border border-light-border px-tk-sm py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              <AdjustmentsHorizontalIcon className="h-4 w-4" /> Adjust stock
            </button>
            ) : null}
            <Link
              to={generatePath(RoutePaths.productEdit, { id: product.id })}
              className="inline-flex flex-1 items-center justify-center gap-tk-xs whitespace-nowrap rounded-md border border-light-border px-tk-sm py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              <PencilSquareIcon className="h-4 w-4" /> Edit
            </Link>
            {/* Delete moved into the edit drawer — the read-only view stays
                free of destructive actions. Reactivate stays: it is a recovery
                action you reach for while looking at an inactive product. */}
            {!product.isActive && canEditStock ? (
              <button
                type="button"
                disabled={reactivate.isPending}
                onClick={() => reactivate.mutate({ id: product.id, name: product.name, sku: product.sku })}
                className="inline-flex flex-1 items-center justify-center gap-tk-xs whitespace-nowrap rounded-md border border-light-border px-tk-sm py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
              >
                <ArrowPathIcon className="h-4 w-4" /> Reactivate
              </button>
            ) : null}
          </div>

          {reactivate.error ? (
            <p className="text-bodySmall text-error-dark">{reactivate.error.message}</p>
          ) : null}

          <div className="space-y-tk-md">
            <Card title="Stock">
              <Field label="Quantity" value={`${product.quantity} ${product.unit}`} />
              <Field label="Reorder level" value={String(product.reorderLevel)} />
              <Field label="Status" value={STOCK_LABEL[getStockStatus(product)]} />
            </Card>
            <Card title="Pricing">
              <Field label="Price" value={formatMoney(product.price)} />
              {canSeeCost ? (
                <>
                  <Field label="Cost" value={formatMoney(product.cost)} />
                  <Field
                    label="Margin"
                    value={`${formatMoney(product.price - product.cost)} (${(
                      product.price > 0 ? ((product.price - product.cost) / product.price) * 100 : 0
                    ).toFixed(1)}%)`}
                  />
                </>
              ) : null}
            </Card>
            <Card title="Details">
              <Field label="Category" value={product.category ?? '—'} />
              <Field label="Unit" value={product.unit} />
              <Field label="Supplier" value={product.supplierName ?? '—'} />
              <Field label="Barcodes" value={product.barcodes.length ? product.barcodes.join(', ') : '—'} />
              <Field label="Notes" value={product.notes ?? '—'} />
            </Card>
            <Card title="Audit">
              <Field label="Created by" value={product.createdByName ?? product.createdBy ?? '—'} />
              <Field label="Created at" value={fmtDate(product.createdAt)} />
              <Field label="Updated by" value={product.updatedByName ?? product.updatedBy ?? '—'} />
              <Field label="Updated at" value={fmtDate(product.updatedAt)} />
            </Card>
          </div>

          <AdjustStockDialog
            key={adjustOpen ? product.id : 'closed'}
            product={product}
            open={adjustOpen}
            onClose={() => setAdjustOpen(false)}
          />

        </div>
      )}
    </Drawer>
  );
}

function Card({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="rounded-lg border border-light-hairline bg-light-card p-tk-md">
      <h3 className="mb-tk-sm text-bodyMedium font-semibold text-light-text">{title}</h3>
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
