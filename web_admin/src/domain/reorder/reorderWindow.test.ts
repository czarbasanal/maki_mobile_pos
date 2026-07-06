import { describe, expect, it } from 'vitest';
import { reorderWindow } from './reorderWindow';

describe('reorderWindow', () => {
  it('ends at yesterday end-of-day, excluding today', () => {
    const now = new Date(2026, 6, 5, 9, 30); // Jul 5, 09:30
    const { end } = reorderWindow(now, 30);
    expect(end).toEqual(new Date(2026, 6, 4, 23, 59, 59, 999));
  });

  it('starts windowDays full days before today', () => {
    const now = new Date(2026, 6, 5, 9, 30);
    const { start } = reorderWindow(now, 7);
    expect(start).toEqual(new Date(2026, 5, 28, 0, 0, 0, 0)); // Jun 28 00:00
  });

  it('spans exactly windowDays complete days', () => {
    const { start, end } = reorderWindow(new Date(2026, 6, 5, 12, 0), 14);
    const days = Math.round((end.getTime() + 1 - start.getTime()) / 86_400_000);
    expect(days).toBe(14);
  });

  it('crosses a month boundary correctly', () => {
    const now = new Date(2026, 6, 1, 8, 0); // Jul 1
    const { start, end } = reorderWindow(now, 30);
    expect(start).toEqual(new Date(2026, 5, 1, 0, 0, 0, 0)); // Jun 1
    expect(end).toEqual(new Date(2026, 5, 30, 23, 59, 59, 999)); // Jun 30
  });
});
