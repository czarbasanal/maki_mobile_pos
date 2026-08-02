// Task 18b: series selector on the web price-history view. Mirrors the
// mobile suite (test/presentation/mobile/screens/inventory/price_history_screen_test.dart,
// commit e33258b) so both surfaces are held to the same behavior:
//  - no selector at all when a product has only a base series
//  - one control per series once options are present
//  - base series selected by default
//  - selecting an option swaps the rows/sparkline to that series only
//
// The `mixed` fixture is arranged so a delta computed WITHOUT first splitting
// into series (i.e. against the raw newest-first list — 360, 130, 330) lands
// on exactly 230 (360 - 130), the same collision number called out in the
// task brief. Every "exact" assertion below uses the full formatMoney string
// (e.g. '₱30.00'), never a bare '30' substring, since '330'/'230'/'360' all
// contain '30' and would let a broken implementation pass silently.
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { PriceHistoryView } from './PriceHistoryView';
import { sparklinePath } from '@/domain/products/priceHistory';
import { formatMoney } from '@/core/utils/money';
import type { PriceHistoryEntry } from '@/domain/repositories/ProductRepository';

function e(
  price: number,
  cost: number,
  at: Date,
  opts: Partial<PriceHistoryEntry> = {},
): PriceHistoryEntry {
  return { price, cost, changedAt: at, changedBy: 'u1', reason: 'Price update', ...opts };
}

// Newest-first, as usePriceHistory/listPriceHistory returns.
const baseOnly: PriceHistoryEntry[] = [
  e(130, 60, new Date(2026, 6, 2)),
  e(120, 60, new Date(2026, 6, 1)),
];

const mixed: PriceHistoryEntry[] = [
  e(360, 60, new Date(2026, 6, 3), { optionId: 'o2', optionLabel: 'By 3', optionPieces: 3 }),
  e(130, 60, new Date(2026, 6, 2)),
  e(330, 60, new Date(2026, 6, 1), { optionId: 'o2', optionLabel: 'By 3', optionPieces: 3 }),
];

function harness(entries: PriceHistoryEntry[]) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    listPriceHistory: async () => entries,
  };
  const userRepo: Partial<Container['userRepo']> = {
    list: async () => [],
  };
  return render(
    <DiProvider
      override={{
        productRepo: productRepo as Container['productRepo'],
        userRepo: userRepo as Container['userRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <PriceHistoryView productId="p-1" />
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('PriceHistoryView — selling-option series', () => {
  it('renders no selector when there is only a base series', async () => {
    harness(baseOnly);
    await screen.findByText(formatMoney(130));
    expect(screen.queryByText('Base price')).toBeNull();
    expect(screen.queryByRole('button', { name: 'Base price' })).toBeNull();
  });

  it('renders one control per series when options are present', async () => {
    harness(mixed);
    await screen.findByRole('button', { name: 'Base price' });
    expect(screen.getByRole('button', { name: 'Base price' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'By 3' })).toBeInTheDocument();
  });

  it('defaults to the base series', async () => {
    harness(mixed);
    await screen.findByText(formatMoney(130));
    // Base entry (130) is showing; the option's newest price (360) is not —
    // an implementation defaulting to the last/first-option series instead
    // of base would fail this.
    expect(screen.getByText(formatMoney(130))).toBeInTheDocument();
    expect(screen.queryByText(formatMoney(360))).toBeNull();
  });

  it('selecting an option shows that series and not the base', async () => {
    harness(mixed);
    await screen.findByRole('button', { name: 'By 3' });
    await userEvent.click(screen.getByRole('button', { name: 'By 3' }));

    expect(await screen.findByText(formatMoney(360))).toBeInTheDocument();
    expect(screen.getByText(formatMoney(330))).toBeInTheDocument();
    expect(screen.queryByText(formatMoney(130))).toBeNull();
  });

  it('the option series delta is exact — not a base-to-option jump', async () => {
    harness(mixed);
    await screen.findByRole('button', { name: 'By 3' });
    await userEvent.click(screen.getByRole('button', { name: 'By 3' }));
    await screen.findByText(formatMoney(360));

    // Real delta within the option series alone: 360 - 330 = 30.
    expect(screen.getByText(`▲ ${formatMoney(30)}`)).toBeInTheDocument();
    // The bug this task fixes: feeding the raw, unsplit list into
    // buildPriceHistoryRows computes 360 (newest overall) minus 130 (the
    // very next entry in the raw list, which is the base row) = 230. That
    // number must never appear once series are split correctly.
    expect(screen.queryByText(`▲ ${formatMoney(230)}`)).toBeNull();
    expect(screen.queryByText(formatMoney(230))).toBeNull();
  });

  it('the sparkline plots only the selected series', async () => {
    const { container } = harness(mixed);
    await screen.findByRole('button', { name: 'By 3' });
    await userEvent.click(screen.getByRole('button', { name: 'By 3' }));
    await screen.findByText(formatMoney(360));

    // Price sparkline renders before the Cost one and before the table, so
    // it is the first <path> in the document. Chronological (oldest-first)
    // option values are [330, 360] — mirrors the mobile test's
    // `spots.map((s) => s.y)` assertion via the same domain sparklinePath fn.
    const path = container.querySelector('path');
    expect(path?.getAttribute('d')).toBe(sparklinePath([330, 360], 320, 44));
  });
});
