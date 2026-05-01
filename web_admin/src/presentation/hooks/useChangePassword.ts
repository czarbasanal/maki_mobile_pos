import { useMutation } from '@tanstack/react-query';
import { useAuthRepo } from '@/infrastructure/di/container';

export interface ChangePasswordInput {
  currentPassword: string;
  newPassword: string;
}

export function useChangePassword() {
  const authRepo = useAuthRepo();
  return useMutation<void, Error, ChangePasswordInput>({
    mutationFn: ({ currentPassword, newPassword }) =>
      authRepo.updatePassword(currentPassword, newPassword),
  });
}
