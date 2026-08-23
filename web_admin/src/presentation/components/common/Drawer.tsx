// Right-anchored slide-over panel. Same interaction contract as Dialog
// (body-portal, ESC to close, click-outside to close, scroll lock) but sized
// for reading a record beside the list it came from, rather than covering it.
//
// Accessibility: role="dialog" + aria-modal, labelled by its title. Focus trap
// is browser-default, matching Dialog — worth upgrading together, not here.
import { useEffect, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { XMarkIcon } from '@heroicons/react/24/outline';
import { cn } from '@/core/utils/cn';

interface DrawerProps {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children: ReactNode;
  /** Block ESC and backdrop close — use while a mutation is in flight. */
  dismissable?: boolean;
  className?: string;
}

export function Drawer({
  open,
  onClose,
  title,
  description,
  children,
  dismissable = true,
  className,
}: DrawerProps) {
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
    <div className="fixed inset-0 z-50 flex justify-end">
      <div
        data-testid="drawer-backdrop"
        className="absolute inset-0 bg-black/30"
        onMouseDown={() => {
          if (dismissable) onClose();
        }}
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className={cn(
          'relative flex h-full w-full max-w-lg flex-col border-l border-light-hairline bg-light-card shadow-xl',
          className,
        )}
      >
        <header className="flex items-start gap-tk-md border-b border-light-hairline px-tk-lg py-tk-md">
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-bodyMedium font-semibold text-light-text">{title}</h2>
            {description ? (
              <p className="mt-tk-xs text-bodySmall text-light-text-secondary">{description}</p>
            ) : null}
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close"
            className="rounded-md p-tk-xs text-light-text-secondary hover:bg-light-subtle"
          >
            <XMarkIcon className="h-4 w-4" />
          </button>
        </header>
        {/* The record can be taller than the viewport — scroll inside the
            panel, never the page behind it. */}
        <div className="flex-1 overflow-y-auto p-tk-lg">{children}</div>
      </div>
    </div>,
    document.body,
  );
}
