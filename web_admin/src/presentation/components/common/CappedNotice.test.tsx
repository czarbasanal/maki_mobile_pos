import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { CappedNotice } from './CappedNotice';

describe('CappedNotice', () => {
  it('renders its message when the sample is capped', () => {
    render(<CappedNotice capped>Showing the most recent 2,000 sales</CappedNotice>);
    expect(screen.getByText(/most recent 2,000 sales/i)).toBeInTheDocument();
  });

  it('renders nothing when not capped', () => {
    const { container } = render(
      <CappedNotice capped={false}>Showing the most recent 2,000 sales</CappedNotice>,
    );
    expect(container).toBeEmptyDOMElement();
  });
});
