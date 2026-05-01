// Mirror of lib/domain/entities/user_entity.dart. Domain entity — no Firestore
// types here; converters in data/converters/userConverter.ts handle the
// Timestamp <-> Date translation.

import { hasPermission, type Permission } from '../permissions/Permission';
import { userRoleDisplayName, type UserRole } from '../enums';

export interface User {
  id: string;
  email: string;
  displayName: string;
  role: UserRole;
  isActive: boolean;
  phoneNumber: string | null;
  photoUrl: string | null;
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string | null;
  updatedBy: string | null;
  lastLoginAt: Date | null;
}

export function userHasPermission(user: User, permission: Permission): boolean {
  if (!user.isActive) return false;
  return hasPermission(user.role, permission);
}

export function userIsAdmin(user: User): boolean {
  return user.role === 'admin';
}

export function userRoleDisplay(user: User): string {
  return userRoleDisplayName[user.role];
}
