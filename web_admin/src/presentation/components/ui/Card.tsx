import { clsx } from 'clsx';
import type { ReactNode } from 'react';

export interface CardProps {
  title?: string;
  subtitle?: string;
  headerAction?: ReactNode;
  padding?: 'sm' | 'md';
  children: ReactNode;
}

export function Card({ title, subtitle, headerAction, padding = 'md', children }: CardProps) {
  const pad = padding === 'sm' ? 'p-4' : 'p-5';
  return (
    <section className="flex min-w-0 flex-col rounded-card border border-line bg-surface shadow-card">
      {(title || headerAction) && (
        <header className={clsx('flex items-start justify-between gap-3', pad, 'pb-0')}>
          <div className="min-w-0">
            {title && <h2 className="text-card-title text-ink">{title}</h2>}
            {subtitle && <p className="mt-0.5 text-kpi-label font-normal text-ink-3">{subtitle}</p>}
          </div>
          {headerAction && <div className="flex shrink-0 items-center gap-2">{headerAction}</div>}
        </header>
      )}
      <div className={clsx('min-w-0 flex-1', pad)}>{children}</div>
    </section>
  );
}
