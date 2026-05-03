// Mutation hooks for user CRUD. Each one runs the same business guards used
// by the Flutter use cases (UserGuards.ts) before hitting Firestore.

import { useMutation } from '@tanstack/react-query';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useUserRepo } from '@/infrastructure/di/container';
import {
  assertDeactivateAllowed,
  assertUpdateAllowed,
} from '@/application/use-cases/userGuards';
import type { User } from '@/domain/entities';
import type { UserRole } from '@/domain/enums';

interface CreateInput {
  email: string;
  displayName: string;
  role: UserRole;
  password: string;
}

export function useCreateUser() {
  const repo = useUserRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<User, Error, CreateInput>({
    mutationFn: async (input) => {
      if (!actor) throw new Error('Not signed in');
      return repo.create(input, actor.id);
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
      return repo.update(
        { id: target.id, displayName, role, isActive },
        actor.id,
      );
    },
  });
}

export function useDeactivateUser() {
  const repo = useUserRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, User>({
    mutationFn: async (target) => {
      if (!actor) throw new Error('Not signed in');
      await assertDeactivateAllowed(actor, target, repo);
      await repo.deactivate(target.id, actor.id);
    },
  });
}

export function useReactivateUser() {
  const repo = useUserRepo();
  const actor = useAuthStore((s) => s.user);
  return useMutation<void, Error, User>({
    mutationFn: async (target) => {
      if (!actor) throw new Error('Not signed in');
      await repo.reactivate(target.id, actor.id);
    },
  });
}
