// Zustand store mirroring the Riverpod `currentUserProvider` + auth status.
// Data lives here so the router and shell can subscribe synchronously without
// pulling React Query into the render path for auth checks.

import { create } from 'zustand';
import type { User } from '@/domain/entities';
import { clearSubscriptionCache } from '@/presentation/hooks/useFirestoreSubscription';
import { useCartStore } from './cartStore';
import { useJobOrderEditStore } from './jobOrderEditStore';

function clearUserScopedState(): void {
  clearSubscriptionCache();
  // The next login must never inherit the previous cashier's ticket.
  useCartStore.getState().clear();
  useJobOrderEditStore.getState().clear();
}

export type AuthStatus = 'loading' | 'signedIn' | 'signedOut';

interface AuthState {
  status: AuthStatus;
  user: User | null;
  setUser: (user: User | null) => void;
  setLoading: () => void;
  reset: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  status: 'loading',
  user: null,
  setUser: (user) =>
    set((prev) => {
      // Sign-out or a user switch must not replay the previous user's
      // cached snapshots — or their cart — on the next screens.
      if (prev.user && prev.user.id !== user?.id) clearUserScopedState();
      return { user, status: user ? 'signedIn' : 'signedOut' };
    }),
  setLoading: () => set({ status: 'loading' }),
  reset: () => {
    clearUserScopedState();
    return set({ status: 'signedOut', user: null });
  },
}));
