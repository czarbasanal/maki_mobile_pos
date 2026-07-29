// Mirror of lib/domain/repositories/activity_log_repository.dart's read
// surface. Reads are one-shot: /admin/logs fetches only when the admin
// submits filters, so there is no live-subscription method here.

import type { ActivityLog, ActivityType } from '../entities';

export interface ActivityLogQuery {
  /** Empty or omitted means "every operation". */
  types?: ActivityType[];
  start?: Date;
  end?: Date;
  limit?: number;
}

export interface ActivityLogRepository {
  list(query?: ActivityLogQuery): Promise<ActivityLog[]>;
  log(input: Omit<ActivityLog, 'id' | 'createdAt'>): Promise<void>;
}
