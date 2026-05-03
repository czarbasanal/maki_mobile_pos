// Mirror of lib/domain/repositories/activity_log_repository.dart's read
// surface. Phase 5 only needs read methods; the log() write is deferred
// alongside whichever later phase first emits activity logs.

import type { ActivityLog, ActivityType } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface ActivityLogQuery {
  type?: ActivityType;
  userId?: string;
  start?: Date;
  end?: Date;
  limit?: number;
}

export interface ActivityLogRepository {
  list(query?: ActivityLogQuery): Promise<ActivityLog[]>;
  // Live stream of recent logs. Filters as composite where-clauses; Firestore
  // requires composite indexes for non-trivial combinations — capture them in
  // firestore.indexes.json as new filters land.
  watch(query: ActivityLogQuery, callback: (logs: ActivityLog[]) => void): Unsubscribe;
  log(input: Omit<ActivityLog, 'id' | 'createdAt'>): Promise<void>;
}
