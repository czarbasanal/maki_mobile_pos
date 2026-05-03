// Business guards for user mutations. Mirrors the rules in
// lib/domain/usecases/user/update_user_usecase.dart and create_user_usecase.dart.
//
// These run client-side before the Firestore write. Firestore rules should
// independently enforce the same invariants — these guards just give the UI
// fast feedback and a friendlier error message.

import type { User } from '@/domain/entities';
import { UserRole } from '@/domain/enums';
import type { UserRepository } from '@/domain/repositories/UserRepository';

export class UserGuardError extends Error {
  constructor(
    message: string,
    public readonly code: string,
  ) {
    super(message);
    this.name = 'UserGuardError';
  }
}

interface UpdateContext {
  actor: User;
  original: User;
  next: { displayName?: string; role?: UserRole; isActive?: boolean };
  repo: UserRepository;
}

export async function assertUpdateAllowed(ctx: UpdateContext): Promise<void> {
  const { actor, original, next, repo } = ctx;
  const isSelf = original.id === actor.id;
  const isRoleChange = next.role !== undefined && next.role !== original.role;
  const isDeactivating = original.isActive && next.isActive === false;

  if (isSelf && isRoleChange) {
    throw new UserGuardError('You cannot change your own role.', 'self-role-change');
  }
  if (isSelf && isDeactivating) {
    throw new UserGuardError('You cannot deactivate yourself.', 'self-deactivate');
  }

  // Last-admin guard: trips when the change would leave zero active admins.
  const wasActiveAdmin = original.role === UserRole.admin && original.isActive;
  const losingAdminStatus =
    wasActiveAdmin &&
    ((isRoleChange && next.role !== UserRole.admin) || isDeactivating);
  if (losingAdminStatus) {
    const admins = await repo.listByRole(UserRole.admin);
    if (admins.filter((u) => u.isActive).length <= 1) {
      throw new UserGuardError(
        'Cannot demote or deactivate the last active admin.',
        'last-admin',
      );
    }
  }
}

export async function assertDeactivateAllowed(
  actor: User,
  target: User,
  repo: UserRepository,
): Promise<void> {
  if (target.id === actor.id) {
    throw new UserGuardError('You cannot deactivate yourself.', 'self-deactivate');
  }
  if (target.role === UserRole.admin && target.isActive) {
    const admins = await repo.listByRole(UserRole.admin);
    if (admins.filter((u) => u.isActive).length <= 1) {
      throw new UserGuardError(
        'Cannot deactivate the last active admin.',
        'last-admin',
      );
    }
  }
}
