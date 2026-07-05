import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { CappedNotice } from './CappedNotice';

describe('CappedNotice', () => {
  it('renders the warning when the sales sample is capped', () => {
    render(<CappedNotice capped cap={10_000} />);
    expect(screen.getByText(/most recent 10,000 sales/i)).toBeInTheDocument();
  });

  it('renders nothing when not capped', () => {
    const { container } = render(<CappedNotice capped={false} cap={10_000} />);
    expect(container).toBeEmptyDOMElement();
  });
});
