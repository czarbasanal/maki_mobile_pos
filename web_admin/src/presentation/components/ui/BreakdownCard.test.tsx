import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { BreakdownCard } from './BreakdownCard';

describe('BreakdownCard', () => {
  it('renders an optional footer slot under the rows (Sales "Revenue split")', () => {
    render(
      <BreakdownCard
        label="By payment method"
        total="₱1.00"
        rows={[{ key: 'cash', label: 'Cash', color: 'var(--accent)', count: 1 }]}
        footer={<span>Revenue split</span>}
      />,
    );
    expect(screen.getByText('Cash')).toBeInTheDocument();
    expect(screen.getByText('Revenue split')).toBeInTheDocument();
  });

  it('keeps the footer even when the rows are empty', () => {
    render(<BreakdownCard label="x" total="—" rows={[]} emptyText="Nothing" footer={<span>Foot</span>} />);
    expect(screen.getByText('Nothing')).toBeInTheDocument();
    expect(screen.getByText('Foot')).toBeInTheDocument();
  });
});
