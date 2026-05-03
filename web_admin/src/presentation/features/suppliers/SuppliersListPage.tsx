// /admin/suppliers — supplier directory. Mirrors the Flutter
// suppliers_screen.dart: search, table, deactivate flow.

import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import {
  EllipsisHorizontalIcon,
  EyeIcon,
  EyeSlashIcon,
  MagnifyingGlassIcon,
  PencilIcon,
  PlusIcon,
  TrashIcon,
} from '@heroicons/react/24/outline';
import { useSuppliers } from '@/presentation/hooks/useSuppliers';
import { useDeactivateSupplier } from '@/presentation/hooks/useSupplierMutations';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { Dialog } from '@/presentation/components/common/Dialog';
import { RoutePaths } from '@/presentation/router/routePaths';
import { TransactionType, transactionTypeDisplayName } from '@/domain/enums';
import type { Supplier } from '@/domain/entities';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';

export function SuppliersListPage() {
  const navigate = useNavigate();
  const { data: suppliers, isLoading, error } = useSuppliers();
  const [search, setSearch] = useState('');
  const [showInactive, setShowInactive] = useState(false);

  useEffect(() => {
    document.title = 'Suppliers · MAKI POS Admin';
  }, []);

  const filtered = useMemo(() => {
    if (!suppliers) return [];
    let out = suppliers;
    if (!showInactive) out = out.filter((s) => s.isActive);
    const q = search.trim().toLowerCase();
    if (q) {
      out = out.filter(
        (s) =>
          s.name.toLowerCase().includes(q) ||
          (s.contactPerson?.toLowerCase().includes(q) ?? false) ||
          (s.email?.toLowerCase().includes(q) ?? false) ||
          (s.contactNumber?.includes(q) ?? false),
      );
    }
    return out;
  }, [suppliers, search, showInactive]);

  if (error) return <ErrorView title="Could not load suppliers" message={error.message} />;

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            Suppliers
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Vendor directory used by inventory and receiving.
          </p>
        </div>
        <button
          type="button"
          onClick={() => navigate(RoutePaths.supplierAdd)}
          className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark"
        >
          <PlusIcon className="h-3.5 w-3.5" />
          Add supplier
        </button>
      </header>

      <div className="flex flex-wrap items-center gap-tk-sm">
        <div className="relative flex-1 max-w-md">
          <MagnifyingGlassIcon className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-light-text-hint" />
          <input
            type="text"
            placeholder="Search by name, contact, email, phone…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full rounded-md border border-light-border bg-light-card py-tk-sm pl-9 pr-tk-md text-bodySmall text-light-text outline-none focus:border-light-text focus:outline focus:outline-1 focus:outline-light-text focus:outline-offset-0"
          />
        </div>
        <button
          type="button"
          onClick={() => setShowInactive((v) => !v)}
          className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-sm py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
        >
          {showInactive ? (
            <EyeSlashIcon className="h-3.5 w-3.5" />
          ) : (
            <EyeIcon className="h-3.5 w-3.5" />
          )}
          {showInactive ? 'Hide inactive' : 'Show inactive'}
        </button>
      </div>

      {isLoading || !suppliers ? (
        <LoadingView label="Loading suppliers…" />
      ) : filtered.length === 0 ? (
        <EmptyState
          title="No suppliers found"
          description={search ? 'Try a different search.' : 'Add your first supplier to get started.'}
        />
      ) : (
        <SuppliersTable suppliers={filtered} />
      )}
    </div>
  );
}

function SuppliersTable({ suppliers }: { suppliers: Supplier[] }) {
  const deactivate = useDeactivateSupplier();
  const [confirm, setConfirm] = useState<Supplier | null>(null);

  const onConfirm = async () => {
    if (!confirm) return;
    await deactivate.mutateAsync(confirm.id);
    setConfirm(null);
  };

  return (
    <>
      <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card">
        <table className="w-full text-bodySmall">
          <thead className="border-b border-light-hairline bg-light-subtle text-light-text-secondary">
            <tr>
              <Th>Supplier</Th>
              <Th>Contact</Th>
              <Th>Terms</Th>
              <Th className="text-right">Inventory</Th>
              <Th>Status</Th>
              <Th className="text-right">Actions</Th>
            </tr>
          </thead>
          <tbody className="divide-y divide-light-hairline">
            {suppliers.map((s) => (
              <SupplierRow key={s.id} supplier={s} onDeactivate={() => setConfirm(s)} />
            ))}
          </tbody>
        </table>
      </div>

      <Dialog
        open={confirm !== null}
        onClose={() => {
          if (deactivate.isPending) return;
          setConfirm(null);
          deactivate.reset();
        }}
        title="Deactivate supplier"
        description={
          confirm
            ? `${confirm.name} will be hidden from new product and receiving forms. Existing references stay intact.`
            : undefined
        }
        dismissable={!deactivate.isPending}
      >
        {deactivate.error ? (
          <p className="mb-tk-md text-bodySmall text-error">{deactivate.error.message}</p>
        ) : null}
        <div className="flex justify-end gap-tk-sm">
          <button
            type="button"
            onClick={() => setConfirm(null)}
            disabled={deactivate.isPending}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-60"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={deactivate.isPending}
            className="flex items-center gap-tk-xs rounded-md bg-error px-tk-md py-tk-sm text-bodySmall font-semibold text-white hover:bg-error-dark disabled:opacity-60"
          >
            {deactivate.isPending ? <Spinner className="h-3.5 w-3.5" /> : null}
            Deactivate
          </button>
        </div>
      </Dialog>
    </>
  );
}

function Th({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <th
      className={cn(
        'px-tk-md py-tk-sm text-left text-[11px] font-semibold uppercase tracking-wider',
        className,
      )}
    >
      {children}
    </th>
  );
}

function SupplierRow({
  supplier,
  onDeactivate,
}: {
  supplier: Supplier;
  onDeactivate: () => void;
}) {
  const [menuOpen, setMenuOpen] = useState(false);
  const termsLabel =
    supplier.transactionType === TransactionType.notApplicable
      ? '—'
      : transactionTypeDisplayName[supplier.transactionType];

  return (
    <tr className={cn(!supplier.isActive && 'opacity-60')}>
      <td className="px-tk-md py-tk-sm">
        <div className="text-bodyMedium font-medium text-light-text">{supplier.name}</div>
        {supplier.address ? (
          <div className="truncate text-[12px] text-light-text-hint">{supplier.address}</div>
        ) : null}
      </td>
      <td className="px-tk-md py-tk-sm">
        {supplier.contactPerson ? (
          <div className="text-bodySmall text-light-text">{supplier.contactPerson}</div>
        ) : null}
        {supplier.contactNumber ? (
          <div className="text-[12px] text-light-text-secondary">{supplier.contactNumber}</div>
        ) : null}
        {!supplier.contactPerson && !supplier.contactNumber ? (
          <span className="text-[12px] text-light-text-hint">—</span>
        ) : null}
      </td>
      <td className="px-tk-md py-tk-sm text-bodySmall text-light-text-secondary">
        {termsLabel}
      </td>
      <td className="px-tk-md py-tk-sm text-right tabular-nums text-bodySmall text-light-text">
        <div className="font-semibold">{supplier.productCount}</div>
        <div className="text-[12px] text-light-text-hint">
          {formatMoney(supplier.totalInventoryValue)}
        </div>
      </td>
      <td className="px-tk-md py-tk-sm">
        <span
          className={cn(
            'inline-flex items-center gap-tk-xs text-[12px] font-medium',
            supplier.isActive ? 'text-success-dark' : 'text-light-text-secondary',
          )}
        >
          <span
            className="h-1.5 w-1.5 rounded-full"
            style={{ backgroundColor: supplier.isActive ? '#16a34a' : '#a3a3a3' }}
          />
          {supplier.isActive ? 'Active' : 'Inactive'}
        </span>
      </td>
      <td className="px-tk-md py-tk-sm text-right">
        <div className="relative inline-flex">
          <Link
            to={`/suppliers/edit/${supplier.id}`}
            className="inline-flex items-center gap-tk-xs rounded-md px-tk-sm py-tk-xs text-bodySmall text-light-text hover:bg-light-subtle"
          >
            <PencilIcon className="h-3.5 w-3.5" />
            Edit
          </Link>
          {supplier.isActive ? (
            <>
              <button
                type="button"
                onClick={() => setMenuOpen((v) => !v)}
                aria-label="More actions"
                className="ml-tk-xs rounded-md p-tk-xs text-light-text-secondary hover:bg-light-subtle"
              >
                <EllipsisHorizontalIcon className="h-4 w-4" />
              </button>
              {menuOpen ? (
                <RowMenu
                  onClose={() => setMenuOpen(false)}
                  onDeactivate={() => {
                    setMenuOpen(false);
                    onDeactivate();
                  }}
                />
              ) : null}
            </>
          ) : null}
        </div>
      </td>
    </tr>
  );
}

function RowMenu({
  onClose,
  onDeactivate,
}: {
  onClose: () => void;
  onDeactivate: () => void;
}) {
  useEffect(() => {
    const onClick = () => onClose();
    document.addEventListener('mousedown', onClick);
    return () => document.removeEventListener('mousedown', onClick);
  }, [onClose]);

  return (
    <div
      onMouseDown={(e) => e.stopPropagation()}
      className="absolute right-0 top-full z-10 mt-tk-xs w-44 overflow-hidden rounded-md border border-light-hairline bg-light-card shadow-lg"
    >
      <button
        type="button"
        onClick={onDeactivate}
        className="flex w-full items-center gap-tk-sm px-tk-md py-tk-sm text-left text-bodySmall text-error-dark hover:bg-error-light/40"
      >
        <TrashIcon className="h-4 w-4" />
        Deactivate
      </button>
    </div>
  );
}
