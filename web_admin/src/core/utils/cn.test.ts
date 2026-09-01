import { describe, expect, it } from 'vitest';
import { cn } from './cn';

describe('cn — custom token classification', () => {
  it('keeps a custom font-size token next to a custom text color', () => {
    // The original bug: tailwind-merge read text-ctl-sm as a COLOR and
    // deleted it in favor of text-ink-2.
    expect(cn('text-ctl-sm text-ink-2')).toContain('text-ctl-sm');
    expect(cn('text-ctl-sm', 'text-ink-2')).toContain('text-ctl-sm');
    expect(cn('text-cell text-ink')).toContain('text-cell');
    expect(cn('text-ctl-lg font-semibold text-accent-ink')).toContain('text-ctl-lg');
    expect(cn('text-bodySmall text-light-text-secondary')).toContain('text-bodySmall');
  });

  it('still dedupes two sizes and two colors correctly', () => {
    expect(cn('text-ctl-sm', 'text-ctl-lg')).toBe('text-ctl-lg');
    expect(cn('text-ink-2', 'text-neg')).toBe('text-neg');
  });
});
