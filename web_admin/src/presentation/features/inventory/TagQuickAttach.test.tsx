import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { TagQuickAttachButton } from './TagQuickAttach';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Product, Tag } from '@/domain/entities';

const tags: Tag[] = [
  { id: 't1', name: 'Intact', color: 'green', description: null, isActive: true,
    createdAt: new Date('2026-09-01'), updatedAt: null, createdBy: null, updatedBy: null },
  { id: 't2', name: 'Recheck', color: 'amber', description: null, isActive: true,
    createdAt: new Date('2026-09-01'), updatedAt: null, createdBy: null, updatedBy: null },
];

const product = { id: 'p1', name: 'Brake shoe', tagIds: ['t2'] } as Product;

function harness() {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role: UserRole.cashier, isActive: true } as never,
  });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    updateTags: vi.fn().mockResolvedValue(undefined),
  };
  const activityLogRepo = { log: vi.fn().mockResolvedValue(undefined) } as unknown as Container['activityLogRepo'];
  render(
    <DiProvider override={{ productRepo: productRepo as Container['productRepo'], activityLogRepo }}>
      <QueryClientProvider client={qc}>
        <TagQuickAttachButton product={product} tags={tags} />
      </QueryClientProvider>
    </DiProvider>,
  );
  return productRepo;
}

describe('TagQuickAttachButton', () => {
  it('toggling tags writes the composed array each tap (add, then remove)', async () => {
    const repo = harness();
    await userEvent.click(screen.getByRole('button', { name: /edit tags/i }));
    // Add t1: component composes from its LOCAL state (seeded from
    // product.tagIds, updated per toggle) so successive toggles stack.
    await userEvent.click(screen.getByRole('checkbox', { name: 'Intact' }));
    expect(repo.updateTags).toHaveBeenLastCalledWith('p1', ['t2', 't1'], 'u1', 'Tester');
    // Remove t2: the earlier t1 addition must survive.
    await userEvent.click(screen.getByRole('checkbox', { name: 'Recheck' }));
    expect(repo.updateTags).toHaveBeenLastCalledWith('p1', ['t1'], 'u1', 'Tester');
  });
});
