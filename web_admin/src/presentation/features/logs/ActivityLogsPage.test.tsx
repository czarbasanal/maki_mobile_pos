import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ActivityLogsPage, COMMON_TYPES } from './ActivityLogsPage';
import { ActivityType, type ActivityLog } from '@/domain/entities';

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

function harness(list: ActivityLog[] = logs) {
  const activityLogRepo: Partial<Container['activityLogRepo']> = {
    watch: vi.fn((_query, cb: (logs: ActivityLog[]) => void) => {
      cb(list);
      return () => {};
    }),
  };
  return render(
    <DiProvider override={{ activityLogRepo: activityLogRepo as Container['activityLogRepo'] }}>
      <ActivityLogsPage />
    </DiProvider>,
  );
}

describe('ActivityLogsPage pagination', () => {
  it('groups only its own 25 rows on page 1, leaving the rest for page 2', async () => {
    harness();

    // Page 1 = first 25 of the flat (newest-first) list: all 15 Day2 items
    // plus the first 10 Day1 items (Day1 action 1..10) — Day1 action 11..15
    // must NOT appear on page 1.
    expect(screen.getByText('Day2 action 1')).toBeInTheDocument();
    expect(screen.getByText('Day1 action 10')).toBeInTheDocument();
    expect(screen.queryByText('Day1 action 11')).not.toBeInTheDocument();
    expect(screen.getByText('1–25 of 30')).toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Next' }));

    // Page 2 = the remaining 5 (Day1 action 11..15), grouped under a single
    // Day1 section — no Day2 rows leak onto this page.
    expect(screen.getByText('Day1 action 11')).toBeInTheDocument();
    expect(screen.getByText('Day1 action 15')).toBeInTheDocument();
    expect(screen.queryByText('Day2 action 1')).not.toBeInTheDocument();
    expect(screen.getByText('26–30 of 30')).toBeInTheDocument();
  });

  it('hides the pager when there are 25 or fewer logs', () => {
    harness(logs.slice(0, 25));
    expect(screen.queryByRole('button', { name: 'Next' })).not.toBeInTheDocument();
  });
});

describe('ActivityLogsPage — filter coverage (task-10)', () => {
  // Every type a web mutation site now emits (task-10) must be filterable
  // from the type dropdown — a type left out of COMMON_TYPES would still be
  // written and shown in the plain "All activities" list, but an admin could
  // never filter down to just that type.
  const webEmittedTypes: ActivityType[] = [
    ActivityType.login,
    ActivityType.logout,
    ActivityType.sale,
    ActivityType.voidSale,
    ActivityType.inventory,
    ActivityType.stockAdjustment,
    ActivityType.receiving,
    ActivityType.expense,
    ActivityType.userCreated,
    ActivityType.userUpdated,
    ActivityType.userDeactivated,
    ActivityType.roleChanged,
    ActivityType.userManagement,
    ActivityType.settings,
    ActivityType.costCodeChanged,
    ActivityType.other,
  ];

  it.each(webEmittedTypes)('COMMON_TYPES includes %s', (type) => {
    expect(COMMON_TYPES).toContain(type);
  });
});
