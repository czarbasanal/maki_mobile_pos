// Mutation hooks for user CRUD. Each one runs the same business guards used
// by the Flutter use cases (UserGuards.ts) before hitting Firestore.

import { useMutation } from '@tanstack/react-query';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useActivityLogRepo, useUserRepo } from '@/infrastructure/di/container';
import {
  assertDeactivateAllowed,
  assertDeleteAllowed,
  assertUpdateAllowed,
} from '@/application/use-cases/userGuards';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, type User } from '@/domain/entities';
import { userRoleDisplayName, type UserRole } from '@/domain/enums';

interface CreateInput {
  email: string;
  displayName: string;
  role: UserRole;
  password: string;
}

export function useCreateUser() {
  const repo = useUserRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<User, Error, CreateInput>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      const created = await repo.create(input, actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.userCreated,
        action: `Created user: ${created.displayName}`,
        details: `Role: ${userRoleDisplayName[created.role]}`,
        entityId: created.id,
        entityType: 'user',
        metadata: { newUserName: created.displayName, newUserRole: created.role },
      }));
      return created;
    },
  });
}

interface UpdateInput {
  target: User;
  displayName?: string;
  role?: UserRole;
  isActive?: boolean;
}

export function useUpdateUser() {
  const repo = useUserRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<User, Error, UpdateInput>({
    mutationFn: async ({ target, displayName, role, isActive }) => {
      if (!actor) throw new Error('Not signed in');
      await assertUpdateAllowed({
        actor,
        original: target,
        next: { displayName, role, isActive },
        repo,
      });
      const updated = await repo.update(
        { id: target.id, displayName, role, isActive },
        actor.id,
      );

      logActivity(activityLogRepo, () => {
        const changes: string[] = [];
        if (target.displayName !== updated.displayName) changes.push(`Name: ${updated.displayName}`);
        if (target.isActive !== updated.isActive) changes.push(updated.isActive ? 'Reactivated' : 'Deactivated');
        return {
          type: ActivityType.userUpdated,
          action: `Updated user: ${updated.displayName}`,
          details: changes.length ? changes.join(', ') : null,
          entityId: updated.id,
          entityType: 'user',
        };
      });

      const isRoleChange = role !== undefined && role !== target.role;
      if (isRoleChange) {
        logActivity(activityLogRepo, () => ({
          type: ActivityType.roleChanged,
          action: `Changed role for: ${updated.displayName}`,
          details: `${userRoleDisplayName[target.role]} → ${userRoleDisplayName[updated.role]}`,
          entityId: updated.id,
          entityType: 'user',
          metadata: {
            targetUserName: updated.displayName,
            oldRole: target.role,
            newRole: updated.role,
          },
        }));
      }

      return updated;
    },
  });
}

export function useDeactivateUser() {
  const repo = useUserRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, User>({
    mutationFn: async (target) => {
      if (!actor) throw new Error('Not signed in');
      await assertDeactivateAllowed(actor, target, repo);
      await repo.deactivate(target.id, actor.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.userDeactivated,
        action: `Deactivated user: ${target.displayName}`,
        details: target.email,
        entityId: target.id,
        entityType: 'user',
      }));
    },
  });
}

export function useReactivateUser() {
  const repo = useUserRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, User>({
    mutationFn: async (target) => {
      if (!actor) throw new Error('Not signed in');
      await repo.reactivate(target.id, actor.id);
      // No dedicated "reactivated" type exists on either surface (mobile
      // logs plain user_updated + a "Reactivated" detail for this) — mirror
      // that here rather than overloading user_deactivated.
      logActivity(activityLogRepo, () => ({
        type: ActivityType.userUpdated,
        action: `Updated user: ${target.displayName}`,
        details: 'Reactivated',
        entityId: target.id,
        entityType: 'user',
      }));
    },
  });
}

export function useDeleteUser() {
  const repo = useUserRepo();
  const activityLogRepo = useActivityLogRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, User>({
    mutationFn: async (target) => {
      if (!actor) throw new Error('Not signed in');
      assertDeleteAllowed(actor, target);
      await repo.delete(target.id);
      logActivity(activityLogRepo, () => ({
        type: ActivityType.userManagement,
        action: `Deleted user: ${target.displayName}`,
        details: target.email,
        entityId: target.id,
        entityType: 'user',
      }));
    },
  });
}
