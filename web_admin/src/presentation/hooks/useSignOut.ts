// Wraps AuthRepository.signOut() with an activity-log entry for genuine,
// user-initiated sign-outs (Sidebar's "Sign out" button, AccessDeniedPage's
// "Sign out"). Deliberately NOT used by AccountDeactivationGuard's forced
// sign-out — that's a system-triggered session end following a deactivation/
// doc-gone event, not a user "logout" action, so it isn't logged as one here.

import { useMutation } from '@tanstack/react-query';
import { useActivityLogRepo, useAuthRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivityAndWait } from '@/application/activityLogger';
import { ActivityType } from '@/domain/entities';

export function useSignOut() {
  const authRepo = useAuthRepo();
  const activityLogRepo = useActivityLogRepo();
  return useMutation<void, Error, void>({
    mutationFn: async () => {
      // The log write must complete BEFORE signOut(): once the token is gone
      // the addDoc goes out unauthenticated, the `user_logs` rules deny it,
      // and the swallow hides that forever — web logouts would never appear
      // in the activity log. Awaited (not fire-and-forget) so the write
      // flushes while still signed in; mobile's sign_out_usecase does the
      // same. logActivityAndWait never rejects, so a denied/offline log
      // still can't block the actual sign-out.
      const user = useAuthStore.getState().user;
      if (user) {
        await logActivityAndWait(
          activityLogRepo,
          () => ({ type: ActivityType.logout, action: 'User logged out' }),
          user,
        );
      }
      await authRepo.signOut();
    },
  });
}
