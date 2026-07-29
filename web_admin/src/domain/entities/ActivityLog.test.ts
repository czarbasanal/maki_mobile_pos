import { describe, expect, it } from 'vitest';
import {
  ALL_ACTIVITY_TYPES,
  ActivityType,
  activityTypeDisplayName,
  activityTypeFromString,
} from './ActivityLog';

describe('ActivityType', () => {
  it('mirrors the Dart enum value for a closed business day', () => {
    expect(ActivityType.dayClosed).toBe('day_closed');
    expect(activityTypeFromString('day_closed')).toBe(ActivityType.dayClosed);
  });

  it('gives every type a display name', () => {
    for (const t of ALL_ACTIVITY_TYPES) {
      expect(activityTypeDisplayName[t], `missing name for ${t}`).toBeTruthy();
    }
  });

  it('lists every enum value in ALL_ACTIVITY_TYPES', () => {
    // Hardcoded count (not derived from ActivityType) so deletions trip this assertion.
    // Current canonical members: authentication, login, logout, sale, voidSale, refund,
    // inventory, stockAdjustment, receiving, userManagement, userCreated, userUpdated,
    // userDeactivated, roleChanged, security, passwordVerified, passwordFailed, costViewed,
    // settings, costCodeChanged, expense, supplier, dayClosed, other = 24 total.
    expect(ALL_ACTIVITY_TYPES).toHaveLength(24);
    expect(ALL_ACTIVITY_TYPES).toContain(ActivityType.dayClosed);
  });
});
