// Vercel-airy metric tile. Label + value with a small outlined icon for
// quick visual scanning. No backgrounds, no shadow — visual weight stays in
// the typography. Icon picks up the tonal palette when `tone` is set.

import type { ComponentType, SVGProps } from 'react';
import { cn } from '@/core/utils/cn';
import { toneStrokeClasses, type Tone } from '@/core/theme/tones';

interface SummaryCardProps {
  title: string;
  value: string;
  icon?: ComponentType<SVGProps<SVGSVGElement>>;
  tone?: Tone;
  hint?: string;
  emphasized?: boolean;
  compact?: boolean;
}

export function SummaryCard({
  title,
  value,
  icon: Icon,
  tone,
  hint,
  emphasized = false,
  compact = false,
}: SummaryCardProps) {
  // On the inverted (emphasized) tile, a saturated tone would clash with the
  // dark background — keep the icon white-ish so it inherits the title color.
  const iconClass = cn(
    'h-4 w-4',
    !emphasized && tone ? toneStrokeClasses[tone] : '',
  );

  if (compact) {
    return (
      <div className="flex flex-col rounded-md border border-light-hairline bg-light-card p-tk-sm">
        <div className="flex items-center justify-between text-light-text-hint">
          <span className="text-[11px] uppercase tracking-wider">{title}</span>
          {Icon ? <Icon className={cn('h-3.5 w-3.5', !emphasized && tone ? toneStrokeClasses[tone] : '')} /> : null}
        </div>
        <span className="mt-tk-xs text-bodyLarge font-semibold tabular-nums text-light-text">
          {value}
        </span>
      </div>
    );
  }

  return (
    <div
      className={cn(
        'flex flex-col gap-tk-xs rounded-lg border border-light-hairline bg-light-card p-tk-md',
        emphasized && 'bg-light-text text-light-background',
      )}
    >
      <div
        className={cn(
          'flex items-center justify-between',
          emphasized ? 'text-light-background/70' : 'text-light-text-secondary',
        )}
      >
        <span className="text-bodySmall">{title}</span>
        {Icon ? <Icon className={iconClass} /> : null}
      </div>
      <span className="text-headingMedium font-semibold tracking-tight tabular-nums">
        {value}
      </span>
      {hint ? (
        <span
          className={cn(
            'text-[12px]',
            emphasized ? 'text-light-background/60' : 'text-light-text-hint',
          )}
        >
          {hint}
        </span>
      ) : null}
    </div>
  );
}
