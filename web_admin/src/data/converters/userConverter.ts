// Mirror of lib/data/models/user_model.dart fromFirestore/toMap behaviour.
// Field names must stay exactly aligned with the Dart side.

import {
  serverTimestamp,
  type DocumentData,
  type FirestoreDataConverter,
  type QueryDocumentSnapshot,
} from 'firebase/firestore';
import type { User } from '@/domain/entities';
import { userRoleFromString } from '@/domain/enums';
import { requireDate, toDate } from './timestamps';

export const userConverter: FirestoreDataConverter<User> = {
  toFirestore(user) {
    return {
      email: user.email,
      displayName: user.displayName,
      role: user.role,
      isActive: user.isActive,
      phoneNumber: user.phoneNumber ?? null,
      photoUrl: user.photoUrl ?? null,
      createdBy: user.createdBy ?? null,
      updatedBy: user.updatedBy ?? null,
    };
  },
  fromFirestore(snapshot: QueryDocumentSnapshot<DocumentData>): User {
    const d = snapshot.data();
    return {
      id: snapshot.id,
      email: d.email ?? '',
      displayName: d.displayName ?? '',
      role: userRoleFromString(d.role),
      isActive: d.isActive ?? true,
      phoneNumber: d.phoneNumber ?? null,
      photoUrl: d.photoUrl ?? null,
      createdAt: requireDate(d.createdAt, 'createdAt'),
      updatedAt: toDate(d.updatedAt),
      createdBy: d.createdBy ?? null,
      updatedBy: d.updatedBy ?? null,
      lastLoginAt: toDate(d.lastLoginAt),
    };
  },
};

// Helper for write paths that need server-side timestamps. The converter
// can't inject these because `toFirestore` is called for every set/update.
export function userWriteFields(extra: Record<string, unknown> = {}) {
  return {
    ...extra,
    updatedAt: serverTimestamp(),
  };
}
