import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Badge } from './Badge';

describe('Badge', () => {
  it('renders its content', () => {
    render(<Badge tone="positive">Completed</Badge>);
    expect(screen.getByText('Completed')).toBeInTheDocument();
  });
  it('chip shape renders mono for counts and deltas', () => {
    render(<Badge tone="neutral" shape="chip">+8.2%</Badge>);
    expect(screen.getByText('+8.2%').className).toContain('font-mono');
  });
  it('applies correct classes for each tone', () => {
    render(<Badge tone="positive">Positive</Badge>);
    const positive = screen.getByText('Positive');
    expect(positive.className).toContain('bg-pos-soft');
    expect(positive.className).toContain('text-pos');

    render(<Badge tone="warning">Warning</Badge>);
    const warning = screen.getByText('Warning');
    expect(warning.className).toContain('bg-accent-soft');
    expect(warning.className).toContain('text-accent-text');

    render(<Badge tone="negative">Negative</Badge>);
    const negative = screen.getByText('Negative');
    expect(negative.className).toContain('bg-neg-soft');
    expect(negative.className).toContain('text-neg');

    render(<Badge tone="neutral">Neutral</Badge>);
    const neutral = screen.getByText('Neutral');
    expect(neutral.className).toContain('bg-surface-3');
    expect(neutral.className).toContain('text-ink-3');
  });
});
