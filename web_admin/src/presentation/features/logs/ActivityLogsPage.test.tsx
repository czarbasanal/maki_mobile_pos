import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ActivityLogsPage } from './ActivityLogsPage';
import { ActivityType, type ActivityLog } from '@/domain/entities';
import type { ActivityLogQuery } from '@/domain/repositories/ActivityLogRepository';
import { shopTimeOf } from '@/domain/time/shopTime';

const log = (o: Partial<ActivityLog> = {}): ActivityLog => ({
  id: 'l1',
  type: ActivityType.login,
  action: 'Signed in',
  details: null,
  userId: 'u1',
  userName: 'Tester',
  userRole: 'admin',
  entityId: null,
  entityType: null,
  metadata: null,
  deviceInfo: null,
  createdAt: new Date(2026, 6, 20, 9, 0),
  ...o,
});

// 15 logs on day 1 (July 20) and 15 on day 2 (July 21), newest first — 30
// total, spanning two date groups, so page 1 (first 25) covers all of day 2
// (15) plus 10 of day 1, and page 2 (last 5) covers the remaining 5 of day 1.
const logs: ActivityLog[] = [
  ...Array.from({ length: 15 }, (_, i) =>
    log({ id: `d2-${i + 1}`, action: `Day2 action ${i + 1}`, createdAt: new Date(2026, 6, 21, 9, i) }),
  ),
  ...Array.from({ length: 15 }, (_, i) =>
    log({ id: `d1-${i + 1}`, action: `Day1 action ${i + 1}`, createdAt: new Date(2026, 6, 20, 9, i) }),
  ),
];

// The stub ignores the query and always returns the fixture, so the date
// filter's real value doesn't matter to these assertions — only that a
// search was issued at all.
function harness(list: ActivityLog[] = logs) {
  // The parameter is declared (and ignored) purely so `mock.calls[0][0]` is
  // typed as the query the page sent — the stub never reads it.
  const listFn = vi.fn(async (_query: ActivityLogQuery) => list);
  const activityLogRepo = { list: listFn } as unknown as Container['activityLogRepo'];
  const utils = render(
    <DiProvider override={{ activityLogRepo }}>
      <ActivityLogsPage />
    </DiProvider>,
  );
  return { ...utils, listFn };
}

async function search() {
  await userEvent.click(screen.getByRole('button', { name: 'Search' }));
}

describe('ActivityLogsPage search gating', () => {
  it('fetches nothing on mount', () => {
    const { listFn } = harness();
    expect(listFn).not.toHaveBeenCalled();
    expect(screen.getByText('Pick your filters and tap Search.')).toBeInTheDocument();
  });

  it('fetches exactly once when Search is clicked', async () => {
    const { listFn } = harness();
    await search();
    expect(listFn).toHaveBeenCalledTimes(1);
    expect(screen.getByText('Day2 action 1')).toBeInTheDocument();
  });

  it('sends the search cap and a date window', async () => {
    const { listFn } = harness();
    await search();
    const query = listFn.mock.calls[0][0];
    expect(query.limit).toBe(500);
    expect(query.start).toBeInstanceOf(Date);
    expect(query.end).toBeInstanceOf(Date);
    expect(query.start!.getTime()).toBeLessThanOrEqual(query.end!.getTime());
    // Nothing selected means "every operation" — the page still forwards the
    // (empty) selection rather than silently dropping the field.
    expect(query.types).toEqual([]);
  });

  it('pads the window so an inclusive <= keeps the last minute', async () => {
    const { listFn } = harness();
    await search();
    const query = listFn.mock.calls[0][0];
    // Default 00:00–23:59 SHOP time. The end bound must reach :59.999 of the
    // chosen minute, or a log written at 23:59:30 falls outside an inclusive
    // <=. The bounds are instants, so read them through the shop clock.
    const startWall = shopTimeOf(query.start!);
    const endWall = shopTimeOf(query.end!);
    expect([startWall.getUTCSeconds(), startWall.getUTCMilliseconds()]).toEqual([0, 0]);
    expect([endWall.getUTCSeconds(), endWall.getUTCMilliseconds()]).toEqual([59, 999]);
    expect([startWall.getUTCHours(), startWall.getUTCMinutes()]).toEqual([0, 0]);
    expect([endWall.getUTCHours(), endWall.getUTCMinutes()]).toEqual([23, 59]);
  });

  it('does not refetch when a filter changes after a search', async () => {
    const { listFn } = harness();
    await search();
    await userEvent.click(screen.getByLabelText('End time'));
    await userEvent.clear(screen.getByLabelText('End time'));
    await userEvent.type(screen.getByLabelText('End time'), '17:00');

    expect(listFn).toHaveBeenCalledTimes(1);
    expect(screen.getByText('Filters changed — tap Search.')).toBeInTheDocument();
  });

  it('re-runs the SUBMITTED query when Refresh is clicked, not the edited filters', async () => {
    const { listFn } = harness();
    await search();

    // Edit a filter after searching. Refresh means "same search, fresh rows",
    // so it must replay the 23:59 window that was actually submitted — not
    // silently adopt the 17:00 the admin is still typing.
    await userEvent.clear(screen.getByLabelText('End time'));
    await userEvent.type(screen.getByLabelText('End time'), '17:00');
    // Pins the precondition: without a real edit landing, comparing the two
    // calls would be vacuous.
    expect(screen.getByLabelText('End time')).toHaveValue('17:00');

    await userEvent.click(screen.getByRole('button', { name: 'Refresh' }));

    expect(listFn).toHaveBeenCalledTimes(2);
    expect(listFn.mock.calls[1][0]).toEqual(listFn.mock.calls[0][0]);
    // Read through the shop clock — the bound is an instant now.
    expect(shopTimeOf(listFn.mock.calls[1][0].end!).getUTCHours()).toBe(23);
    // The pending edit is still pending — Refresh is not a second Search, so
    // it must not clear the "tap Search" prompt.
    expect(screen.getByText('Filters changed — tap Search.')).toBeInTheDocument();
  });

  it('disables Search when the end time precedes the start time', async () => {
    const { listFn } = harness();
    await userEvent.clear(screen.getByLabelText('Start time'));
    await userEvent.type(screen.getByLabelText('Start time'), '18:00');
    await userEvent.clear(screen.getByLabelText('End time'));
    await userEvent.type(screen.getByLabelText('End time'), '09:00');
    expect(screen.getByLabelText('Start time')).toHaveValue('18:00');
    expect(screen.getByLabelText('End time')).toHaveValue('09:00');

    const button = screen.getByRole('button', { name: 'Search' });
    // The real `disabled` attribute, not just disabled-looking styling.
    expect(button).toBeDisabled();

    await userEvent.click(button);
    expect(listFn).not.toHaveBeenCalled();
  });

  it('disables Search and issues no read when End time is cleared', async () => {
    const { listFn } = harness();
    await userEvent.clear(screen.getByLabelText('End time'));
    expect(screen.getByLabelText('End time')).toHaveValue('');

    const button = screen.getByRole('button', { name: 'Search' });
    expect(button).toBeDisabled();
    expect(screen.getByText('Start must be before end.')).toBeInTheDocument();

    // A disabled button already blocks the click in real DOM, but exercise
    // the handler directly too — the fix adds a guard inside onSearch itself
    // so the invariant doesn't depend solely on the child's `disabled` wiring.
    await userEvent.click(button);
    expect(listFn).not.toHaveBeenCalled();
  });

  it('shows the no-match message for an empty result', async () => {
    harness([]);
    await search();
    expect(screen.getByText('No activity matched these filters')).toBeInTheDocument();
  });

  it('warns when the result hits the cap', async () => {
    harness(Array.from({ length: 500 }, (_, i) => log({ id: `c${i}`, action: `Capped ${i}` })));
    await search();
    expect(
      screen.getByText('Showing the newest 500 — narrow your range.'),
    ).toBeInTheDocument();
  });

  // The negative case: CappedNotice renders nothing when `capped` is false,
  // so without this an always-on `capped` would sail through.
  it('shows no cap warning for a result under the cap', async () => {
    harness(); // 30 rows
    await search();
    expect(
      screen.queryByText('Showing the newest 500 — narrow your range.'),
    ).not.toBeInTheDocument();
  });
});

describe('ActivityLogsPage pagination', () => {
  it('groups only its own 25 rows on page 1, leaving the rest for page 2', async () => {
    harness();
    await search();

    expect(screen.getByText('Day2 action 1')).toBeInTheDocument();
    expect(screen.getByText('Day1 action 10')).toBeInTheDocument();
    expect(screen.queryByText('Day1 action 11')).not.toBeInTheDocument();
    expect(screen.getByText('1–25 of 30')).toBeInTheDocument();
  });

  it('shows the remaining rows on page 2', async () => {
    harness();
    await search();
    await userEvent.click(screen.getByRole('button', { name: /next/i }));

    expect(screen.getByText('Day1 action 11')).toBeInTheDocument();
    expect(screen.queryByText('Day2 action 1')).not.toBeInTheDocument();
  });
});
