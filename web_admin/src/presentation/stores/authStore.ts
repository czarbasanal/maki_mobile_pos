// Zustand store mirroring the Riverpod `currentUserProvider` + auth status.
// Data lives here so the router and shell can subscribe synchronously without
// pulling React Query into the render path for auth checks.

import { create } from 'zustand';
import type { User } from '@/domain/entities';

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
    set({
      user,
      status: user ? 'signedIn' : 'signedOut',
    }),
  setLoading: () => set({ status: 'loading' }),
  reset: () => set({ status: 'signedOut', user: null }),
}));
