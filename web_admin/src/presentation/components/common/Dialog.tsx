// Minimal modal dialog. Body-portal, ESC to close, click-outside to close.
// Not a full Radix/Headless replacement — just enough for forms in modals.
//
// Accessibility: render with role="dialog" and aria-modal. Focus trap is
// browser-default for now (keyboard lands on the first focusable element);
// upgrade to a real focus-trap when we add forms with destructive actions.

import { useEffect, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { useEscapeLayer } from '@/presentation/components/ui/escapeLayers';
import { XMarkIcon } from '@heroicons/react/24/outline';
import { cn } from '@/core/utils/cn';

interface DialogProps {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children: ReactNode;
  // Block close-on-overlay-click — useful while a mutation is in-flight so a
  // stray click doesn't dismiss the modal mid-write.
  dismissable?: boolean;
  className?: string;
}

export function Dialog({
  open,
  onClose,
  title,
  description,
  children,
  dismissable = true,
  className,
}: DialogProps) {
  // Layered: a dropdown (or nested dialog) above this one consumes Escape
  // first; this closes on the next press.
  useEscapeLayer(open && dismissable, onClose);
  useEffect(() => {
    if (!open) return;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = '';
    };
  }, [open]);

  if (!open) return null;

  return createPortal(
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/30 p-tk-lg"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget && dismissable) onClose();
      }}
      role="dialog"
      aria-modal="true"
      aria-label={title}
    >
      <div
        className={cn(
          'w-full max-w-md rounded-card border border-line bg-surface shadow-card',
          className,
        )}
        onMouseDown={(e) => e.stopPropagation()}
      >
        <header className="flex items-start gap-tk-md border-b border-line-2 px-tk-lg py-tk-md">
          <div className="min-w-0 flex-1">
            <h2 className="text-card-title text-ink">{title}</h2>
            {description ? (
              <p className="mt-tk-xs text-cell text-ink-2">{description}</p>
            ) : null}
          </div>
          {dismissable ? (
            <button
              type="button"
              onClick={onClose}
              aria-label="Close"
              className="rounded-chip p-tk-xs text-ink-3 hover:bg-surface-3 hover:text-ink-2"
            >
              <XMarkIcon className="h-4 w-4" />
            </button>
          ) : null}
        </header>
        <div className="p-tk-lg">{children}</div>
      </div>
    </div>,
    document.body,
  );
}
