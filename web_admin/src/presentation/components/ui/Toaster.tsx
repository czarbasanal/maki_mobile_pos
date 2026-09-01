import { useEffect, useRef, useState } from 'react';
import { CheckCircleIcon, InformationCircleIcon, XCircleIcon } from '@heroicons/react/24/outline';
import { toast, type ToastPayload } from './toast';

const DISMISS_MS = 1900;

const toneIcon = {
  success: <CheckCircleIcon className="h-4 w-4 shrink-0 text-pos" />,
  error: <XCircleIcon className="h-4 w-4 shrink-0 text-neg" />,
  info: <InformationCircleIcon className="h-4 w-4 shrink-0 text-ink-2" />,
} as const;

export function Toaster() {
  const [current, setCurrent] = useState<ToastPayload | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const unsubscribe = toast._subscribe((payload) => {
      setCurrent(payload);
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(() => setCurrent(null), DISMISS_MS);
    });
    return () => {
      unsubscribe();
      if (timer.current) clearTimeout(timer.current);
    };
  }, []);

  if (!current) return null;
  return (
    <div
      role="status"
      className="fixed bottom-6 left-1/2 z-50 flex -translate-x-1/2 items-center gap-2 rounded-[12px] border border-line bg-surface px-4 py-2.5 shadow-card"
    >
      {toneIcon[current.tone]}
      <span className="text-ctl-md font-medium text-ink">{current.message}</span>
      {current.detail && <span className="font-mono text-ctl-md text-ink-3">{current.detail}</span>}
    </div>
  );
}
