import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { BarChart } from './BarChart';
import { SegmentedBar } from './SegmentedBar';

describe('BarChart', () => {
  const data = [
    { label: '8 AM', value: 0 },
    { label: '9 AM', value: 3 },
    { label: '12 PM', value: 7 },
  ];

  it('renders a labeled bar per datum and omits zero counts', () => {
    render(<BarChart data={data} highlight={2} />);
    expect(screen.getByText('12 PM')).toBeInTheDocument();
    expect(screen.getByText('7')).toBeInTheDocument();
    expect(screen.getByText('3')).toBeInTheDocument();
    // the 8 AM bucket shows no "0" count label
    expect(screen.queryByText('0')).not.toBeInTheDocument();
  });

  it('gives the highlighted bar the accent fill', () => {
    const { container } = render(<BarChart data={data} highlight={2} />);
    const bars = container.querySelectorAll('[data-bar]');
    expect(bars[2].className).toContain('bg-accent');
    expect(bars[1].className).toContain('bg-surface-3');
  });

  it('renders empty when every value is zero', () => {
    render(<BarChart data={[{ label: '8 AM', value: 0 }]} empty={<p>No sales yet today</p>} />);
    expect(screen.getByText('No sales yet today')).toBeInTheDocument();
  });
});

describe('SegmentedBar', () => {
  it('renders non-zero segments with proportional grow and skips zeros', () => {
    const { container } = render(
      <SegmentedBar
        segments={[
          { label: 'In stock', value: 3, color: 'pos' },
          { label: 'Low', value: 1, color: 'accent' },
          { label: 'Out', value: 0, color: 'neg' },
        ]}
      />,
    );
    const segs = container.querySelectorAll('[data-segment]');
    expect(segs.length).toBe(2);
    expect((segs[0] as HTMLElement).style.flexGrow).toBe('3');
    expect(segs[0].className).toContain('bg-pos');
  });
});
