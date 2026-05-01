// Dependency injection container. Holds repository instances so use cases /
// hooks consume contracts, not concrete Firestore code. Tests can override by
// passing a different container value to <DiProvider>.

import { createContext, useContext, useMemo, type ReactNode } from 'react';
import { auth } from '@/infrastructure/firebase/auth';
import { db } from '@/infrastructure/firebase/firestore';
import { FirebaseAuthRepository } from '@/data/repositories/FirebaseAuthRepository';
import type { AuthRepository } from '@/domain/repositories/AuthRepository';

export interface Container {
  authRepo: AuthRepository;
  // Other repositories slot in here as their phases land:
  // userRepo, productRepo, supplierRepo, ...
}

function buildDefaultContainer(): Container {
  return {
    authRepo: new FirebaseAuthRepository(auth, db),
  };
}

const DiContext = createContext<Container | null>(null);

export function DiProvider({
  children,
  override,
}: {
  children: ReactNode;
  override?: Partial<Container>;
}) {
  const value = useMemo<Container>(
    () => ({ ...buildDefaultContainer(), ...(override ?? {}) }),
    [override],
  );
  return <DiContext.Provider value={value}>{children}</DiContext.Provider>;
}

export function useContainer(): Container {
  const c = useContext(DiContext);
  if (!c) throw new Error('useContainer must be used inside <DiProvider>');
  return c;
}

export function useAuthRepo(): AuthRepository {
  return useContainer().authRepo;
}
