// Ephemeral UI state shared across the shell. Sidebar collapse + offline flag
// for the top-bar banner.

import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface UiState {
  sidebarExtended: boolean;
  offline: boolean;
  toggleSidebar: () => void;
  setOffline: (offline: boolean) => void;
}

export const useUiStore = create<UiState>()(
  persist(
    (set) => ({
      sidebarExtended: true,
      offline: false,
      toggleSidebar: () =>
        set((state) => ({ sidebarExtended: !state.sidebarExtended })),
      setOffline: (offline) => set({ offline }),
    }),
    {
      name: 'maki-admin-ui',
      partialize: (state) => ({ sidebarExtended: state.sidebarExtended }),
    },
  ),
);
