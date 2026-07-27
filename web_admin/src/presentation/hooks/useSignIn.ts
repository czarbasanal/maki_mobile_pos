// TanStack mutation that wraps AuthRepository.signInWithEmailAndPassword.
// Components consume this rather than the repo directly, so retries, error
// mapping, and devtools support all flow through Query.

import { useMutation } from '@tanstack/react-query';
import { useActivityLogRepo, useAuthRepo } from '@/infrastructure/di/container';
import { logActivity } from '@/application/activityLogger';
import { ActivityType, type User } from '@/domain/entities';

export interface SignInInput {
  email: string;
  password: string;
}

export function useSignIn() {
  const authRepo = useAuthRepo();
  const activityLogRepo = useActivityLogRepo();
  return useMutation<User, Error, SignInInput>({
    mutationFn: async ({ email, password }) => {
      const user = await authRepo.signInWithEmailAndPassword(email, password);
      // Passed explicitly (not read off the store): the Zustand auth store
      // only updates later via the onAuthStateChanged bridge
      // (useAuthBootstrap), which may not have run yet at this point.
      logActivity(
        activityLogRepo,
        () => ({ type: ActivityType.login, action: 'User logged in' }),
        user,
      );
      return user;
    },
  });
}
