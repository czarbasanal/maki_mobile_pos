// Admin notification bell for pending void requests — the web counterpart of
// mobile's VoidRequestsBell + void_request_notification_sheet.
//
// Until this existed, an admin working only on web had no idea a cashier was
// waiting on a void; the queue lived solely on the admin's phone.

import { useEffect, useRef, useState } from 'react';
import { BellIcon } from '@heroicons/react/24/outline';
import {
  useVoidRequests,
  useResolveVoidRequest,
  useMarkVoidRequestsRead,
} from '@/presentation/hooks/useVoidRequests';
import { useAuthStore } from '@/presentation/stores/authStore';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import type { VoidRequest } from '@/domain/entities';

const dtFmt = new Intl.DateTimeFormat('en-PH', {
  month: 'short',
  day: 'numeric',
  hour: 'numeric',
  minute: '2-digit',
});

export function VoidRequestsBell({ collapsed = false }: { collapsed?: boolean }) {
  const role = useAuthStore((s) => s.user?.role);
  const [open, setOpen] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);
  const { pending, unreadCount } = useVoidRequests();
  const markRead = useMarkVoidRequestsRead();

  // Close on an outside click, like the account menu below it.
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => {
      if (!wrapRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener('mousedown', onDown);
    return () => document.removeEventListener('mousedown', onDown);
  }, [open]);

  if (!role || !hasPermission(role, Permission.voidSale)) return null;

  const toggle = () => {
    const next = !open;
    setOpen(next);
    // Opening is the admin seeing them; the badge is about attention, not
    // about whether anything was actually resolved.
    if (next && unreadCount > 0) markRead.mutate();
  };

  return (
    <div ref={wrapRef} className="relative">
      <button
        type="button"
        onClick={toggle}
        aria-label={`Void requests${unreadCount > 0 ? ` (${unreadCount} unread)` : ''}`}
        title="Void requests"
        className="relative rounded-md p-tk-xs text-light-text-secondary hover:bg-light-subtle hover:text-light-text"
      >
        <BellIcon className="h-4 w-4" />
        {unreadCount > 0 ? (
          <span className="absolute -right-1 -top-1 flex h-4 min-w-[16px] items-center justify-center rounded-full bg-error px-[3px] text-[10px] font-semibold leading-none text-white">
            {unreadCount}
          </span>
        ) : null}
      </button>

      {open ? (
        <div
          className={cn(
            'absolute z-30 mt-tk-xs w-80 rounded-lg border border-light-hairline bg-light-card shadow-lg',
            collapsed ? 'left-0' : 'right-0',
          )}
        >
          <div className="border-b border-light-hairline px-tk-md py-tk-sm">
            <p className="text-bodySmall font-semibold text-light-text">Void requests</p>
          </div>
          {pending.length === 0 ? (
            <p className="px-tk-md py-tk-lg text-center text-bodySmall text-light-text-hint">
              Nothing waiting.
            </p>
          ) : (
            <ul className="max-h-96 divide-y divide-light-hairline overflow-y-auto">
              {pending.map((r) => (
                <li key={r.id}>
                  <RequestRow request={r} />
                </li>
              ))}
            </ul>
          )}
        </div>
      ) : null}
    </div>
  );
}

function RequestRow({ request }: { request: VoidRequest }) {
  const resolve = useResolveVoidRequest();
  const [rejecting, setRejecting] = useState(false);
  const [reason, setReason] = useState('');

  const busy = resolve.isPending;

  return (
    <div className="space-y-tk-xs px-tk-md py-tk-sm">
      <div className="flex items-baseline justify-between gap-tk-sm">
        <span className="font-mono text-bodySmall font-medium text-light-text">
          {request.saleNumber}
        </span>
        <span className="tabular-nums text-bodySmall font-semibold text-light-text">
          {formatMoney(request.saleGrandTotal)}
        </span>
      </div>
      <p className="text-[11px] text-light-text-secondary">
        {request.requestedByName} · {dtFmt.format(request.createdAt)}
      </p>
      <p className="text-bodySmall text-light-text">Reason: {request.reason}</p>
      {request.itemsSummary ? (
        <p className="text-[11px] text-light-text-hint">{request.itemsSummary}</p>
      ) : null}

      {resolve.error ? (
        <p className="text-[11px] text-error-dark">{resolve.error.message}</p>
      ) : null}

      {rejecting ? (
        <div className="space-y-tk-xs">
          <input
            type="text"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="Why is this being rejected?"
            className="w-full rounded-md border border-light-border bg-light-card px-tk-sm py-[6px] text-bodySmall text-light-text outline-none focus:border-light-text"
          />
          <div className="flex gap-tk-xs">
            <button
              type="button"
              disabled={busy || !reason.trim()}
              onClick={() =>
                resolve.mutate({ request, approve: false, rejectionReason: reason.trim() })
              }
              className="rounded-md border border-light-border px-tk-sm py-[4px] text-[11px] font-medium text-light-text hover:bg-light-subtle disabled:opacity-50"
            >
              Confirm reject
            </button>
            <button
              type="button"
              onClick={() => { setRejecting(false); setReason(''); }}
              className="px-tk-xs py-[4px] text-[11px] text-light-text-secondary hover:underline"
            >
              Cancel
            </button>
          </div>
        </div>
      ) : (
        <div className="flex gap-tk-xs pt-[2px]">
          <button
            type="button"
            disabled={busy}
            onClick={() => resolve.mutate({ request, approve: true })}
            className="rounded-md bg-light-text px-tk-sm py-[4px] text-[11px] font-semibold text-light-background hover:bg-primary-dark disabled:opacity-50"
          >
            {busy ? 'Voiding…' : 'Approve'}
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={() => setRejecting(true)}
            className="rounded-md border border-light-border px-tk-sm py-[4px] text-[11px] font-medium text-light-text hover:bg-light-subtle disabled:opacity-50"
          >
            Reject
          </button>
        </div>
      )}
    </div>
  );
}
