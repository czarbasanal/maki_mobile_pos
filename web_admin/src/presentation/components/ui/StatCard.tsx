import { clsx } from 'clsx';
import { formatMoney } from '@/core/utils/money';
import { Badge, type Tone } from './Badge';
import { Skeleton } from './Skeleton';

export type StatFormat = 'currency' | 'number' | 'percent';

export interface StatCardProps {
  label: string;
  value: number;
  format: StatFormat;
  /** Signed fraction vs the prior business day; null/undefined hides the chip. */
  delta?: number | null;
  /** Explicit chip (neutral ratios like "58.7% of gross") — overrides delta. */
  chip?: { label: string; tone: Tone };
  note?: string;
  loading?: boolean;
  /** The screen's headline metric (reports guide §1): accent tint + accent-line
   *  border, label and note in accent-text. Replaces the old solid-black card. */
  lead?: boolean;
}

function formatValue(value: number, format: StatFormat): string {
  if (format === 'currency') return formatMoney(value);
  if (format === 'percent') return `${(value * 100).toFixed(1)}%`;
  return value.toLocaleString('en-PH');
}

function deltaChip(delta: number): { label: string; tone: Tone } {
  const rounded = Math.round(delta * 1000) / 10; // one-decimal percent
  if (rounded > 0) return { label: `+${rounded.toFixed(1)}%`, tone: 'positive' };
  if (rounded < 0) return { label: `${rounded.toFixed(1)}%`, tone: 'negative' };
  return { label: '0.0%', tone: 'neutral' };
}

export function StatCard({ label, value, format, delta, chip, note, loading = false, lead = false }: StatCardProps) {
  const resolvedChip = chip ?? (delta != null ? deltaChip(delta) : null);
  return (
    <section
      className={clsx(
        'rounded-card border p-4 shadow-card',
        lead ? 'border-accent-line bg-accent-soft' : 'border-line bg-surface',
      )}
    >
      <div className="flex items-start justify-between gap-2">
        <span className={clsx('text-kpi-label', lead ? 'text-accent-text' : 'text-ink-2')}>{label}</span>
        {!loading && resolvedChip && (
          <Badge tone={resolvedChip.tone} shape="chip">
            {resolvedChip.label}
          </Badge>
        )}
      </div>
      <div className="tnum mt-1.5 font-mono text-kpi text-ink">
        {loading ? <Skeleton width="90px" height="23px" /> : formatValue(value, format)}
      </div>
      {note && !loading && (
        <p className={clsx('mt-1 text-micro', lead ? 'text-accent-text' : 'text-ink-3')}>{note}</p>
      )}
    </section>
  );
}
