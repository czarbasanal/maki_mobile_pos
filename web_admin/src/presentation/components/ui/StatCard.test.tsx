import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { StatCard } from './StatCard';

describe('StatCard', () => {
  it('formats currency in mono with the peso sign', () => {
    render(<StatCard label="Gross Sales" value={8945} format="currency" />);
    expect(screen.getByText('Gross Sales')).toBeInTheDocument();
    const figure = screen.getByText('₱8,945.00');
    expect(figure.className).toContain('font-mono');
  });

  it('renders a signed positive delta chip', () => {
    render(<StatCard label="Sales today" value={27} format="number" delta={0.082} />);
    expect(screen.getByText('+8.2%')).toBeInTheDocument();
  });

  it('renders a negative delta chip', () => {
    render(<StatCard label="Avg order" value={370.37} format="currency" delta={-0.041} />);
    expect(screen.getByText('-4.1%')).toBeInTheDocument();
  });

  it('an explicit neutral ratio chip wins over delta', () => {
    render(
      <StatCard label="Total COGS" value={5246} format="currency" delta={0.5} chip={{ label: '58.7% of gross', tone: 'neutral' }} />,
    );
    expect(screen.getByText('58.7% of gross')).toBeInTheDocument();
    expect(screen.queryByText('+50.0%')).not.toBeInTheDocument();
  });

  it('shows a skeleton while loading', () => {
    render(<StatCard label="Gross Sales" value={0} format="currency" loading />);
    expect(screen.queryByText('₱0.00')).not.toBeInTheDocument();
  });

  it('hides the chip when there is no prior-day baseline', () => {
    render(<StatCard label="Sales today" value={27} format="number" delta={null} />);
    expect(screen.queryByText(/%/)).not.toBeInTheDocument();
  });

  it('rounds very small negative delta to 0.0% neutral', () => {
    render(<StatCard label="Metric" value={100} format="number" delta={-0.0001} />);
    expect(screen.getByText('0.0%')).toBeInTheDocument();
    expect(screen.queryByText('-0.0%')).not.toBeInTheDocument();
  });

  it('renders zero delta as 0.0% neutral', () => {
    render(<StatCard label="Metric" value={100} format="number" delta={0} />);
    expect(screen.getByText('0.0%')).toBeInTheDocument();
  });
});

describe('StatCard — lead variant (reports guide §1)', () => {
  it('a lead card takes the accent tint, accent-line border and accent-text label + note', () => {
    render(<StatCard label="Gross sales" value={20000} format="currency" note="in the last 7 days" lead />);
    const card = screen.getByText('Gross sales').closest('section') as HTMLElement;
    expect(card.className).toContain('bg-accent-soft');
    expect(card.className).toContain('border-accent-line');
    expect(screen.getByText('Gross sales').className).toContain('text-accent-text');
    expect(screen.getByText('in the last 7 days').className).toContain('text-accent-text');
  });

  it('a non-lead card stays on the plain surface', () => {
    render(<StatCard label="Parts" value={1} format="currency" note="x" />);
    const card = screen.getByText('Parts').closest('section') as HTMLElement;
    expect(card.className).not.toContain('bg-accent-soft');
    expect(screen.getByText('x').className).toContain('text-ink-3');
  });
});

describe('StatCard — text and null values', () => {
  it('format "text" renders the string verbatim in the mono figure slot (an age)', () => {
    render(<StatCard label="Oldest request" value="3h" format="text" note="SALE-1" />);
    expect(screen.getByText('3h').className).toContain('font-mono');
  });
  it('a null value is a figure with no denominator: a dash, never 0.0%', () => {
    render(<StatCard label="Approval rate" value={null} format="percent" />);
    expect(screen.getByText('—')).toBeInTheDocument();
    expect(screen.queryByText(/%/)).not.toBeInTheDocument();
  });
});
