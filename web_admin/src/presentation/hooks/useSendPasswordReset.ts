import { useMutation } from '@tanstack/react-query';
import { useAuthRepo } from '@/infrastructure/di/container';

export function useSendPasswordReset() {
  const authRepo = useAuthRepo();
  return useMutation<void, Error, string>({
    mutationFn: (email) => authRepo.sendPasswordResetEmail(email),
  });
}
