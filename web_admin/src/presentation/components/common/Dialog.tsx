// Minimal modal dialog. Body-portal, ESC to close, click-outside to close.
// Not a full Radix/Headless replacement — just enough for forms in modals.
//
// Accessibility: render with role="dialog" and aria-modal. Focus trap is
// browser-default for now (keyboard lands on the first focusable element);
// upgrade to a real focus-trap when we add forms with destructive actions.

import { useEffect, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
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
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && dismissable) onClose();
    };
    document.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      document.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [open, dismissable, onClose]);

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
          'w-full max-w-md rounded-lg border border-light-hairline bg-light-card shadow-xl',
          className,
        )}
        onMouseDown={(e) => e.stopPropagation()}
      >
        <header className="flex items-start gap-tk-md border-b border-light-hairline px-tk-lg py-tk-md">
          <div className="min-w-0 flex-1">
            <h2 className="text-bodyMedium font-semibold text-light-text">{title}</h2>
            {description ? (
              <p className="mt-tk-xs text-bodySmall text-light-text-secondary">{description}</p>
            ) : null}
          </div>
          {dismissable ? (
            <button
              type="button"
              onClick={onClose}
              aria-label="Close"
              className="rounded-md p-tk-xs text-light-text-secondary hover:bg-light-subtle"
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
