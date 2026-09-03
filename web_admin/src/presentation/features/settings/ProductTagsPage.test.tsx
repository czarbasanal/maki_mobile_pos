import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ProductTagsPage } from './ProductTagsPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { Tag } from '@/domain/entities';

const tag = (o: Partial<Tag> = {}): Tag => ({
  id: 't1', name: 'Intact', color: 'green', description: 'Count verified',
  isActive: true, createdAt: new Date('2026-09-01'), updatedAt: null,
  createdBy: null, updatedBy: null, ...o,
});

function signIn(role: UserRole) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
  });
}

function harness(tags: Tag[] = [tag()], repoOver: Partial<Container['tagRepo']> = {}) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const tagRepo: Partial<Container['tagRepo']> = {
    watchAll: (cb: (tags: Tag[]) => void) => { cb(tags); return () => {}; },
    create: vi.fn().mockResolvedValue(tag({ id: 'new1' })),
    update: vi.fn().mockResolvedValue(undefined),
    delete: vi.fn().mockResolvedValue(undefined),
    ...repoOver,
  };
  const activityLogRepo = { log: vi.fn().mockResolvedValue(undefined) } as unknown as Container['activityLogRepo'];
  render(
    <DiProvider override={{ tagRepo: tagRepo as Container['tagRepo'], activityLogRepo }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/settings/tags']}>
          <ProductTagsPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return tagRepo;
}

describe('ProductTagsPage', () => {
  it('lists tags with their description', () => {
    signIn(UserRole.admin);
    harness();
    expect(screen.getByText('Intact')).toBeInTheDocument();
    expect(screen.getByText('Count verified')).toBeInTheDocument();
  });

  it('creates a tag with the selected color', async () => {
    signIn(UserRole.cashier); // editLists holders can add
    const repo = harness([]);
    await userEvent.click(screen.getByRole('button', { name: /add/i }));
    await userEvent.type(screen.getByLabelText('Name'), 'Intact');
    await userEvent.click(screen.getByRole('radio', { name: 'green' }));
    await userEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(repo.create).toHaveBeenCalledWith(
      { name: 'Intact', color: 'green', description: null },
      'u1',
    );
  });

  it('cashier sees no Deactivate or Delete controls', () => {
    signIn(UserRole.cashier);
    harness([tag(), tag({ id: 't2', name: 'Old', isActive: false })]);
    expect(screen.queryByRole('button', { name: /deactivate/i })).toBeNull();
    expect(screen.queryByRole('button', { name: /delete/i })).toBeNull();
  });

  it('staff can deactivate and can delete an inactive tag', () => {
    signIn(UserRole.staff);
    harness([tag(), tag({ id: 't2', name: 'Old', isActive: false })]);
    expect(screen.getByRole('button', { name: /deactivate/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /delete/i })).toBeInTheDocument();
  });
});
