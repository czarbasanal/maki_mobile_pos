// The shared modal shell (supplier-modal guide §2) — the ONE dialog chrome
// for every editing overlay: pinned header and footer with a scrolling body
// (a modal that scrolls whole hides its own Save button), scrim click and
// layered Escape to close, focus trapped while open and restored to the
// trigger after, body scroll locked.
import { useEffect, useRef, type ReactNode } from 'react';
import { createPortal } from 'react-dom';
import { XMarkIcon } from '@heroicons/react/24/outline';
import { clsx } from 'clsx';
import { IconButton } from './IconButton';
import { useEscapeLayer } from './escapeLayers';

const SIZES = { sm: 'max-w-[480px]', md: 'max-w-[620px]', lg: 'max-w-[820px]' } as const;

const FOCUSABLE =
  'a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])';

export function Modal({
  open,
  onClose,
  title,
  subtitle,
  icon,
  size = 'md',
  footer,
  children,
}: {
  open: boolean;
  /** Scrim click, Escape (topmost layer only), and the ✕ all land here. */
  onClose: () => void;
  title: string;
  subtitle?: ReactNode;
  /** Small leading tile (e.g. an initials mark). */
  icon?: ReactNode;
  size?: keyof typeof SIZES;
  /** Pinned bar under the scrolling body. */
  footer?: ReactNode;
  children: ReactNode;
}) {
  const panel = useRef<HTMLDivElement>(null);

  useEscapeLayer(open, onClose);

  // Body scroll lock + focus capture/restore.
  useEffect(() => {
    if (!open) return;
    const trigger = document.activeElement as HTMLElement | null;
    document.body.style.overflow = 'hidden';
    const first = panel.current?.querySelector<HTMLElement>('[data-autofocus], input, textarea');
    first?.focus();
    return () => {
      document.body.style.overflow = '';
      trigger?.focus?.();
    };
  }, [open]);

  if (!open) return null;

  const trapTab = (e: React.KeyboardEvent) => {
    if (e.key !== 'Tab' || !panel.current) return;
    const nodes = [...panel.current.querySelectorAll<HTMLElement>(FOCUSABLE)].filter(
      (n) => n.offsetParent !== null,
    );
    if (nodes.length === 0) return;
    const first = nodes[0];
    const last = nodes[nodes.length - 1];
    if (e.shiftKey && document.activeElement === first) {
      e.preventDefault();
      last.focus();
    } else if (!e.shiftKey && document.activeElement === last) {
      e.preventDefault();
      first.focus();
    }
  };

  return createPortal(
    <div
      className="fixed inset-0 z-[60] flex items-center justify-center bg-[rgba(12,16,22,0.36)] px-6 py-8"
      onMouseDown={onClose}
    >
      <div
        ref={panel}
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onMouseDown={(e) => e.stopPropagation()}
        onKeyDown={trapTab}
        className={clsx(
          'flex max-h-full w-full flex-col overflow-hidden rounded-[16px] border border-line bg-surface shadow-[0_32px_72px_-24px_rgba(0,0,0,0.45)]',
          SIZES[size],
        )}
      >
        <div className="flex items-center gap-3 border-b border-line-2 px-5 py-4">
          {icon}
          <div className="min-w-0 flex-1">
            <h2 className="text-[15px] font-semibold text-ink">{title}</h2>
            {subtitle ? <p className="text-[11.5px] text-ink-3">{subtitle}</p> : null}
          </div>
          <IconButton title="Close" size={28} onClick={onClose}>
            <XMarkIcon className="h-4 w-4" />
          </IconButton>
        </div>

        <div className="flex flex-col gap-[18px] overflow-y-auto px-5 py-[18px]">{children}</div>

        {footer ? (
          <div className="flex items-center gap-2.5 border-t border-line bg-surface-2 px-5 py-3">
            {footer}
          </div>
        ) : null}
      </div>
    </div>,
    document.body,
  );
}
