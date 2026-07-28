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
    expect(new Set(ALL_ACTIVITY_TYPES)).toEqual(new Set(Object.values(ActivityType)));
  });
});
