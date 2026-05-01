// Bridges Firebase auth state into the Zustand auth store. Called once from
// <App>; subsequent components read from `useAuthStore`.

import { useEffect } from 'react';
import { ensureAuthReady } from '@/infrastructure/firebase/auth';
import { useAuthStore } from '@/presentation/stores/authStore';
import { useAuthRepo } from '@/infrastructure/di/container';

export function useAuthBootstrap(): void {
  const authRepo = useAuthRepo();
  const setUser = useAuthStore((s) => s.setUser);
  const setLoading = useAuthStore((s) => s.setLoading);

  useEffect(() => {
    let cancelled = false;
    setLoading();

    let unsubscribe: (() => void) | undefined;

    (async () => {
      await ensureAuthReady();
      if (cancelled) return;
      unsubscribe = authRepo.onAuthStateChanged((user) => {
        if (cancelled) return;
        setUser(user);
      });
    })();

    return () => {
      cancelled = true;
      unsubscribe?.();
    };
  }, [authRepo, setLoading, setUser]);
}
