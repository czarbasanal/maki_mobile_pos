// Dependency injection container. Holds repository instances so use cases /
// hooks consume contracts, not concrete Firestore code. Tests can override by
// passing a different container value to <DiProvider>.

import { createContext, useContext, useMemo, type ReactNode } from 'react';
import { auth } from '@/infrastructure/firebase/auth';
import { db } from '@/infrastructure/firebase/firestore';
import { FirebaseAuthRepository } from '@/data/repositories/FirebaseAuthRepository';
import { FirestoreSaleRepository } from '@/data/repositories/FirestoreSaleRepository';
import { FirestoreProductRepository } from '@/data/repositories/FirestoreProductRepository';
import { FirestoreCostCodeRepository } from '@/data/repositories/FirestoreCostCodeRepository';
import type { AuthRepository } from '@/domain/repositories/AuthRepository';
import type { SaleRepository } from '@/domain/repositories/SaleRepository';
import type { ProductRepository } from '@/domain/repositories/ProductRepository';
import type { CostCodeRepository } from '@/domain/repositories/CostCodeRepository';

export interface Container {
  authRepo: AuthRepository;
  saleRepo: SaleRepository;
  productRepo: ProductRepository;
  costCodeRepo: CostCodeRepository;
  // Other repositories slot in here as their phases land:
  // userRepo, supplierRepo, expenseRepo, ...
}

function buildDefaultContainer(): Container {
  return {
    authRepo: new FirebaseAuthRepository(auth, db),
    saleRepo: new FirestoreSaleRepository(db),
    productRepo: new FirestoreProductRepository(db),
    costCodeRepo: new FirestoreCostCodeRepository(db),
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

export function useSaleRepo(): SaleRepository {
  return useContainer().saleRepo;
}

export function useProductRepo(): ProductRepository {
  return useContainer().productRepo;
}

export function useCostCodeRepo(): CostCodeRepository {
  return useContainer().costCodeRepo;
}
