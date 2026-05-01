import { useProductRepo } from '@/infrastructure/di/container';
import { useFirestoreSubscription } from './useFirestoreSubscription';
import type { Product } from '@/domain/entities';

export function useProducts() {
  const repo = useProductRepo();
  return useFirestoreSubscription<Product[]>(
    (onData) => repo.watchAll(onData),
    [repo],
  );
}
