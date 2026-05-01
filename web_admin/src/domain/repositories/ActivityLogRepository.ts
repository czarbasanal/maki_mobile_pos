import type { ActivityLog, ActivityType } from '../entities';
import type { Unsubscribe } from './AuthRepository';

export interface ActivityLogQuery {
  start?: Date;
  end?: Date;
  userId?: string;
  type?: ActivityType;
  limit?: number;
  cursor?: ActivityLog;
}

export interface ActivityLogRepository {
  list(query?: ActivityLogQuery): Promise<ActivityLog[]>;
  watch(query: ActivityLogQuery, callback: (logs: ActivityLog[]) => void): Unsubscribe;
  log(input: Omit<ActivityLog, 'id' | 'createdAt'>): Promise<void>;
}
