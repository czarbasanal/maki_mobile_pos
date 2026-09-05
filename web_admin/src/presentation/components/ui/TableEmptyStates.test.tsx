import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { FirstRunState } from './TableEmptyStates';

describe('FirstRunState tone', () => {
  it('defaults to the accent teach tile', () => {
    render(<FirstRunState icon={<span data-testid="glyph" />} title="No expenses yet" description="d" />);
    const tile = screen.getByTestId('glyph').parentElement as HTMLElement;
    expect(tile.className).toContain('bg-accent-soft');
    expect(tile.className).toContain('border-accent-line');
  });

  it('muted tone is the reports empty-range tile: surface-2 with the plain border', () => {
    render(<FirstRunState tone="muted" icon={<span data-testid="glyph" />} title="No sales in this range" description="d" />);
    const tile = screen.getByTestId('glyph').parentElement as HTMLElement;
    expect(tile.className).toContain('bg-surface-2');
    expect(tile.className).toContain('border-line');
    expect(tile.className).not.toContain('bg-accent-soft');
  });
});

describe('FirstRunState positive tone', () => {
  it('positive tone is the reassurance tile: pos-soft fill with the pos border', () => {
    render(<FirstRunState tone="positive" icon={<span data-testid="glyph" />} title="Nothing waiting" description="d" />);
    const tile = screen.getByTestId('glyph').parentElement as HTMLElement;
    expect(tile.className).toContain('bg-pos-soft');
    expect(tile.className).toContain('border-pos');
  });
});
