// TanStack mutation that wraps AuthRepository.signInWithEmailAndPassword.
// Components consume this rather than the repo directly, so retries, error
// mapping, and devtools support all flow through Query.

import { useMutation } from '@tanstack/react-query';
import { useAuthRepo } from '@/infrastructure/di/container';
import type { User } from '@/domain/entities';

export interface SignInInput {
  email: string;
  password: string;
}

export function useSignIn() {
  const authRepo = useAuthRepo();
  return useMutation<User, Error, SignInInput>({
    mutationFn: ({ email, password }) =>
      authRepo.signInWithEmailAndPassword(email, password),
  });
}
