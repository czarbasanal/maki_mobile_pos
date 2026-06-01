import { useQuery } from '@tanstack/react-query';
import { useProductRepo } from '@/infrastructure/di/container';
import type { PriceHistoryEntry } from '@/domain/repositories/ProductRepository';

/** One-shot read of a product's price history (newest-first). Disabled until a
 *  productId is supplied. */
export function usePriceHistory(productId: string | null) {
  const repo = useProductRepo();
  return useQuery<PriceHistoryEntry[]>({
    queryKey: ['price-history', productId],
    queryFn: () => repo.listPriceHistory(productId as string),
    enabled: !!productId,
  });
}
