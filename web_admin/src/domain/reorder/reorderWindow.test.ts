import { describe, expect, it } from 'vitest';
import { reorderWindow } from './reorderWindow';
import { instantOf, shopWall } from '@/domain/time/shopTime';

describe('reorderWindow', () => {
  it('ends at yesterday end-of-day, excluding today', () => {
    const now = instantOf(shopWall(2026, 7, 5, 9, 30)); // Jul 5, 09:30 PHT
    const { end } = reorderWindow(now, 30);
    expect(end).toEqual(instantOf(shopWall(2026, 7, 4, 23, 59, 59, 999)));
  });

  it('starts windowDays full days before today', () => {
    const now = instantOf(shopWall(2026, 7, 5, 9, 30));
    const { start } = reorderWindow(now, 7);
    expect(start).toEqual(instantOf(shopWall(2026, 6, 28))); // Jun 28 00:00 PHT
  });

  it('spans exactly windowDays complete days', () => {
    const { start, end } = reorderWindow(instantOf(shopWall(2026, 7, 5, 12, 0)), 14);
    const days = Math.round((end.getTime() + 1 - start.getTime()) / 86_400_000);
    expect(days).toBe(14);
  });

  it('crosses a month boundary correctly', () => {
    const now = instantOf(shopWall(2026, 7, 1, 8, 0)); // Jul 1 PHT
    const { start, end } = reorderWindow(now, 30);
    expect(start).toEqual(instantOf(shopWall(2026, 6, 1))); // Jun 1 PHT
    expect(end).toEqual(instantOf(shopWall(2026, 6, 30, 23, 59, 59, 999))); // Jun 30 PHT
  });
});
