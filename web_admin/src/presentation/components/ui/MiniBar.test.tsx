import { describe, expect, it } from 'vitest';
import { render } from '@testing-library/react';
import { MiniBar } from './MiniBar';

describe('MiniBar', () => {
  it('stretches by default (flex-1 with the 52px floor)', () => {
    const { container } = render(<MiniBar pct={50} color="var(--accent)" />);
    const rail = container.firstElementChild as HTMLElement;
    expect(rail.className).toContain('flex-1');
    expect(rail.style.width).toBe('');
  });

  it('a fixed width pins the rail and drops the stretch (profit-table margin column)', () => {
    const { container } = render(<MiniBar pct={50} color="var(--pos)" width="34px" />);
    const rail = container.firstElementChild as HTMLElement;
    expect(rail.style.width).toBe('34px');
    expect(rail.className).not.toContain('flex-1');
    expect(rail.className).not.toContain('min-w-');
    expect(rail.className).toContain('shrink-0');
  });
});
