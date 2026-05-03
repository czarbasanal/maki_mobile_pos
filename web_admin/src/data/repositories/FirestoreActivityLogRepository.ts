// Read-side implementation of ActivityLogRepository. The log() write is
// stub-thrown until a later phase needs to emit logs from React (currently
// only the Flutter app writes to user_logs).

import {
  addDoc,
  collection,
  getDocs,
  limit as fsLimit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  Timestamp,
  where,
  type Firestore,
  type QueryConstraint,
} from 'firebase/firestore';
import type {
  ActivityLogQuery,
  ActivityLogRepository,
} from '@/domain/repositories/ActivityLogRepository';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';
import type { ActivityLog } from '@/domain/entities';
import { FirestoreCollections } from '@/infrastructure/firebase/collections';
import { activityLogConverter } from '@/data/converters/activityLogConverter';

export class FirestoreActivityLogRepository implements ActivityLogRepository {
  constructor(private readonly db: Firestore) {}

  private col() {
    return collection(this.db, FirestoreCollections.userLogs).withConverter(
      activityLogConverter,
    );
  }

  private constraints(q: ActivityLogQuery): QueryConstraint[] {
    const out: QueryConstraint[] = [];
    if (q.type) out.push(where('type', '==', q.type));
    if (q.userId) out.push(where('userId', '==', q.userId));
    if (q.start) out.push(where('createdAt', '>=', Timestamp.fromDate(q.start)));
    if (q.end) out.push(where('createdAt', '<=', Timestamp.fromDate(q.end)));
    out.push(orderBy('createdAt', 'desc'));
    if (q.limit) out.push(fsLimit(q.limit));
    return out;
  }

  async list(q: ActivityLogQuery = {}): Promise<ActivityLog[]> {
    const snap = await getDocs(query(this.col(), ...this.constraints(q)));
    return snap.docs.map((d) => d.data());
  }

  watch(q: ActivityLogQuery, callback: (logs: ActivityLog[]) => void): Unsubscribe {
    return onSnapshot(query(this.col(), ...this.constraints(q)), (snap) => {
      callback(snap.docs.map((d) => d.data()));
    });
  }

  async log(input: Omit<ActivityLog, 'id' | 'createdAt'>): Promise<void> {
    // Wired now — useful so any later mutation hook on the React side can
    // emit activity logs without another data-layer revision.
    await addDoc(this.col(), {
      ...input,
      createdAt: serverTimestamp(),
    } as unknown as ActivityLog);
  }
}
