// Index card (reports guide §1): icon tile, title, sentence, chevron, then a
// foot with TWO live figures for the active range — the index answers the
// common question without opening anything. A Link, so it's keyboard
// reachable and activatable.
import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { ChevronRightIcon } from '@heroicons/react/24/outline';
import { cn } from '@/core/utils/cn';
import { Skeleton } from '@/presentation/components/ui/Skeleton';

export interface NavFigure {
  label: string;
  value: string;
  /** A result rather than a measurement (the profit figure) — --pos. */
  positive?: boolean;
}

export function ReportNavCard({
  to,
  icon,
  title,
  description,
  figures,
  rangeNote,
  loading = false,
}: {
  to: string;
  icon: ReactNode;
  title: string;
  description: string;
  figures: [NavFigure, NavFigure];
  rangeNote: string;
  loading?: boolean;
}) {
  return (
    <Link
      to={to}
      className="flex flex-col gap-3.5 rounded-card border border-line bg-surface px-5 py-[18px] shadow-card hover:border-accent-line focus:outline-none focus-visible:border-accent-line"
    >
      <div className="flex items-start gap-3">
        <div className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-ctl border border-accent-line bg-accent-soft text-accent-text">
          {icon}
        </div>
        <div className="flex min-w-0 flex-col gap-[3px]">
          <span className="text-card-title text-ink">{title}</span>
          <span className="text-ctl-sm text-ink-3 [text-wrap:pretty]">{description}</span>
        </div>
        <ChevronRightIcon className="ml-auto h-[15px] w-[15px] shrink-0 text-ink-3" />
      </div>
      <div className="flex items-end gap-4 border-t border-line-2 pt-[13px]">
        {figures.map((f) => (
          <div key={f.label} className="flex flex-col gap-[3px]">
            <span className="text-[10px] font-semibold uppercase tracking-[0.9px] text-ink-3">{f.label}</span>
            {loading ? (
              <Skeleton width="72px" height="16px" />
            ) : (
              <span
                className={cn(
                  'font-mono text-[16px] font-semibold tracking-[-0.5px]',
                  f.positive ? 'text-pos' : 'text-ink',
                )}
              >
                {f.value}
              </span>
            )}
          </div>
        ))}
        <span className="ml-auto text-[11px] text-ink-3">{rangeNote}</span>
      </div>
    </Link>
  );
}
