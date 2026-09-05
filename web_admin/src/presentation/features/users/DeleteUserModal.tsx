// Typed confirmation for the soft delete (users guide §3): the email, in a
// second modal. Deletion removes the login; sales, job orders and logs stay,
// still attributed to the person by name.
import { useState } from 'react';
import { Modal } from '@/presentation/components/ui/Modal';
import { Button } from '@/presentation/components/ui/Button';
import { Field, inputCls } from '@/presentation/components/ui/formKit';
import type { User } from '@/domain/entities';

export function DeleteUserModal({
  target,
  busy,
  error,
  onConfirm,
  onClose,
}: {
  target: User | null;
  busy: boolean;
  error: string | null;
  onConfirm: () => void;
  onClose: () => void;
}) {
  const [typed, setTyped] = useState('');
  const matches = !!target && typed.trim().toLowerCase() === target.email.toLowerCase();
  return (
    <Modal
      open={target !== null}
      onClose={() => { if (!busy) { setTyped(''); onClose(); } }}
      size="sm"
      title="Delete account?"
      footer={
        <div className="flex justify-end gap-2">
          <Button variant="secondary" onClick={() => { setTyped(''); onClose(); }} disabled={busy}>Cancel</Button>
          <Button variant="danger" onClick={onConfirm} disabled={!matches} loading={busy}>Delete account</Button>
        </div>
      }
    >
      {target ? (
        <div className="flex flex-col gap-3.5">
          <p className="text-ctl-sm text-ink-2 [text-wrap:pretty]">
            {target.displayName || target.email} loses their login for good. Their sales, job orders,
            receipts and activity logs stay in the system, still attributed to them by name.
          </p>
          <Field label={`Type ${target.email} to confirm`}>
            <input
              type="text"
              value={typed}
              onChange={(e) => setTyped(e.target.value)}
              autoComplete="off"
              className={inputCls(false)}
            />
          </Field>
          {error ? <p className="text-ctl-sm text-neg">{error}</p> : null}
        </div>
      ) : null}
    </Modal>
  );
}
