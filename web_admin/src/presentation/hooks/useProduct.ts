import { useQuery } from '@tanstack/react-query';
import { useProductRepo } from '@/infrastructure/di/container';
import type { Product } from '@/domain/entities';

/** One-shot read of a single product by id. Disabled until an id is supplied. */
export function useProduct(id: string | undefined) {
  const repo = useProductRepo();
  return useQuery<Product | null>({
    queryKey: ['product', id],
    queryFn: () => repo.getById(id as string),
    enabled: !!id,
  });
}
