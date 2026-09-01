import { clsx } from 'clsx';
import type { ReactNode } from 'react';

export interface BarDatum {
  label: string;
  value: number;
}

export interface BarChartProps {
  data: BarDatum[];
  highlight?: number;
  height?: number;
  empty?: ReactNode;
}

export function BarChart({ data, highlight, height = 110, empty = null }: BarChartProps) {
  const max = Math.max(...data.map((d) => d.value), 0);
  if (max === 0) return <>{empty}</>;

  return (
    <div className="flex items-end gap-1.5">
      {data.map((datum, index) => (
        <div key={index} className="flex min-w-0 flex-1 flex-col items-center gap-1">
          <span className="font-mono text-axis text-ink-3">{datum.value > 0 ? datum.value : ' '}</span>
          <div className="flex w-full items-end" style={{ height }}>
            <div
              data-bar
              className={clsx('w-full', index === highlight ? 'bg-accent' : 'bg-surface-3')}
              style={{ height: `${(datum.value / max) * 100}%`, borderRadius: 'var(--radius-bar)' }}
            />
          </div>
          <span className="truncate font-mono text-axis text-ink-3">{datum.label}</span>
        </div>
      ))}
    </div>
  );
}
