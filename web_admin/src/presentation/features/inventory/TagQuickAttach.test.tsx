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

function harness(initialProduct: Product) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role: UserRole.cashier, isActive: true } as never,
  });
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const productRepo: Partial<Container['productRepo']> = {
    updateTags: vi.fn().mockResolvedValue(undefined),
  };
  const activityLogRepo = { log: vi.fn().mockResolvedValue(undefined) } as unknown as Container['activityLogRepo'];
  const override = { productRepo: productRepo as Container['productRepo'], activityLogRepo };
  const renderWith = (p: Product) => (
    <DiProvider override={override}>
      <QueryClientProvider client={qc}>
        <TagQuickAttachButton product={p} tags={tags} />
      </QueryClientProvider>
    </DiProvider>
  );
  const utils = render(renderWith(initialProduct));
  const rerenderWithProduct = (p: Product) => utils.rerender(renderWith(p));
  return { productRepo, rerenderWithProduct };
}

describe('TagQuickAttachButton', () => {
  it('toggling tags writes the composed array each tap (add, then remove)', async () => {
    const { productRepo: repo } = harness(product);
    await userEvent.click(screen.getByRole('button', { name: /edit tags/i }));
    // Add t1: component composes from its LOCAL state (seeded from
    // product.tagIds, updated per toggle) so successive toggles stack.
    await userEvent.click(screen.getByRole('button', { name: 'Intact' }));
    expect(repo.updateTags).toHaveBeenLastCalledWith('p1', ['t2', 't1'], 'u1', 'Tester');
    // Remove t2: the earlier t1 addition must survive.
    await userEvent.click(screen.getByRole('button', { name: 'Recheck' }));
    expect(repo.updateTags).toHaveBeenLastCalledWith('p1', ['t1'], 'u1', 'Tester');
  });

  it('re-seeds from the live tagIds prop on open, not the mount-time snapshot', async () => {
    // Row mounts while product.tagIds === ['t2']. Another client then tags
    // the same product with 't1' — the stream update rerenders this row
    // (still mounted, same DataTable key) with the new tagIds before the
    // user opens the dialog.
    const { productRepo: repo, rerenderWithProduct } = harness(product);
    rerenderWithProduct({ ...product, tagIds: ['t1', 't2'] });

    await userEvent.click(screen.getByRole('button', { name: /edit tags/i }));
    // Untoggling 't2' should compose from the freshly-seeded ['t1', 't2'],
    // leaving 't1' (the other client's tag) intact. Composing from the
    // stale mount-time snapshot (['t2']) would instead write [] — silently
    // deleting the tag the other client just added.
    await userEvent.click(screen.getByRole('button', { name: 'Recheck' }));
    expect(repo.updateTags).toHaveBeenLastCalledWith('p1', ['t1'], 'u1', 'Tester');
  });
});
