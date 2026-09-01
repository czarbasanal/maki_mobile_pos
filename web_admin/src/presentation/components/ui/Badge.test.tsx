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
});
