// Wraps AuthRepository.signOut() with an activity-log entry for genuine,
// user-initiated sign-outs (Sidebar's "Sign out" button, AccessDeniedPage's
// "Sign out"). Deliberately NOT used by AccountDeactivationGuard's forced
// sign-out — that's a system-triggered session end following a deactivation/
// doc-gone event, not a user "logout" action, so it isn't logged as one here.

import { useMutation } from '@tanstack/react-query';
import { useActivityLogRepo, useAuthRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { logActivity } from '@/application/activityLogger';
import { ActivityType } from '@/domain/entities';

export function useSignOut() {
  const authRepo = useAuthRepo();
  const activityLogRepo = useActivityLogRepo();
  return useMutation<void, Error, void>({
    mutationFn: async () => {
      // Read the outgoing user BEFORE signing out — signOut() flips the auth
      // store to signedOut (via the onAuthStateChanged bridge), and logActivity
      // is a no-op once there's no signed-in user to attribute the entry to.
      const user = useAuthStore.getState().user;
      await authRepo.signOut();
      if (user) {
        logActivity(
          activityLogRepo,
          () => ({ type: ActivityType.logout, action: 'User logged out' }),
          user,
        );
      }
    },
  });
}
