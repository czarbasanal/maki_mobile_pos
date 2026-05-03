// Mirror of lib/data/models/activity_log_model.dart.

import type {
  DocumentData,
  FirestoreDataConverter,
  QueryDocumentSnapshot,
} from 'firebase/firestore';
import { activityTypeFromString, type ActivityLog } from '@/domain/entities';
import { requireDate } from './timestamps';

export const activityLogConverter: FirestoreDataConverter<ActivityLog> = {
  toFirestore(log) {
    return {
      type: log.type,
      action: log.action,
      details: log.details,
      userId: log.userId,
      userName: log.userName,
      userRole: log.userRole,
      entityId: log.entityId,
      entityType: log.entityType,
      metadata: log.metadata,
      deviceInfo: log.deviceInfo,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): ActivityLog {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      type: activityTypeFromString(d.type),
      action: d.action ?? '',
      details: d.details ?? null,
      userId: d.userId ?? '',
      userName: d.userName ?? '',
      userRole: d.userRole ?? '',
      entityId: d.entityId ?? null,
      entityType: d.entityType ?? null,
      metadata: d.metadata ?? null,
      deviceInfo: d.deviceInfo ?? null,
      createdAt: requireDate(d.createdAt, 'createdAt'),
    };
  },
};
