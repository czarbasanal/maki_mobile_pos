// The confirm step the reference deliberately lacks (void-requests guide §4):
// approving reverses money and moves stock from a table row, so it shows
// what is about to be voided and asks; rejecting collects the required note
// the screen's own copy promises the cashier.
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { RoutePaths } from '@/presentation/router/routePaths';
import { Modal } from '@/presentation/components/ui/Modal';
import { Button } from '@/presentation/components/ui/Button';
import { Badge } from '@/presentation/components/ui/Badge';
import { CopyButton } from '@/presentation/components/ui/CopyButton';
import { Field, inputCls } from '@/presentation/components/ui/formKit';
import { toast } from '@/presentation/components/ui/toast';
import { useResolveVoidRequest } from '@/presentation/hooks/useVoidRequests';
import { voidReasonTone } from '@/domain/voidRequests/voidRequestQueue';
import { formatMoney } from '@/core/utils/money';
import { cn } from '@/core/utils/cn';
import type { VoidRequest } from '@/domain/entities';

export type VoidDecision = { mode: 'approve' | 'reject'; request: VoidRequest };

export function VoidDecisionModal({ decision, onClose }: { decision: VoidDecision | null; onClose: () => void }) {
  const resolve = useResolveVoidRequest();
  const [note, setNote] = useState('');
  const busy = resolve.isPending;
  const open = decision !== null;
  const approve = decision?.mode === 'approve';
  const r = decision?.request;
  const canCommit = approve ? true : note.trim().length > 0;

  const close = () => {
    if (busy) return;
    setNote('');
    resolve.reset();
    onClose();
  };

  const commit = async () => {
    if (!r || !canCommit) return;
    try {
      await resolve.mutateAsync(
        approve ? { request: r, approve: true } : { request: r, approve: false, rejectionReason: note.trim() },
      );
      if (approve) toast.success('Sale voided, stock returned', r.saleNumber);
      else toast.info('Request rejected', r.saleNumber);
      setNote('');
      onClose();
    } catch {
      // surfaced via resolve.error below
    }
  };

  return (
    <Modal
      open={open}
      onClose={close}
      size="sm"
      title={approve ? 'Approve void' : 'Reject request'}
      subtitle={
        approve
          ? "Voiding returns these items to stock and removes the sale from reports. This can't be undone."
          : 'The sale stays as it stands. Your note goes back to the cashier.'
      }
      initialFocus={approve ? 'none' : 'first-input'}
      footer={
        <div className="flex justify-end gap-2">
          <Button variant="secondary" onClick={close} disabled={busy}>
            Cancel
          </Button>
          <Button
            variant={approve ? 'primary' : 'danger'}
            onClick={commit}
            disabled={!canCommit}
            loading={busy}
          >
            {approve ? 'Approve void' : 'Reject request'}
          </Button>
        </div>
      }
    >
      {r ? (
        <div className="flex flex-col gap-3.5">
          <div className="flex flex-col gap-2 rounded-ctl border border-line bg-surface-2 px-3.5 py-3">
            <div className="flex items-center gap-1.5">
              <Link
                to={`${RoutePaths.reports}/sale/${r.saleId}`}
                className="font-mono text-ctl-md font-medium text-ink hover:text-accent-text"
              >
                {r.saleNumber}
              </Link>
              <CopyButton value={r.saleNumber} label="sale number" />
              <span className="ml-auto font-mono text-[15px] font-semibold tracking-[-0.3px] text-ink">
                {formatMoney(r.saleGrandTotal)}
              </span>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <Badge tone={voidReasonTone(r.reason)} shape="tag" wrap>{r.reason}</Badge>
              <span className="text-ctl-sm text-ink-2">requested by {r.requestedByName}</span>
            </div>
            {r.itemsSummary ? (
              <p className="text-ctl-sm text-ink-2 [text-wrap:pretty]">{r.itemsSummary}</p>
            ) : null}
          </div>

          {!approve ? (
            <Field label="Note to the cashier">
              <textarea
                rows={3}
                value={note}
                onChange={(e) => setNote(e.target.value)}
                placeholder="Why the sale stands — the cashier sees this"
                className={cn(inputCls(false), 'h-auto resize-y leading-relaxed')}
              />
            </Field>
          ) : null}

          {resolve.error ? <p className="text-ctl-sm text-neg">{resolve.error.message}</p> : null}
        </div>
      ) : null}
    </Modal>
  );
}
