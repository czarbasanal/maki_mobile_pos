import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { createCartStore } from '@/presentation/stores/cartStore';
import { LaborSection } from './LaborSection';
import type { Mechanic } from '@/domain/entities';

const berto = { id: 'm1', name: 'Berto', isActive: true } as Mechanic;

function harness(repoOver: Partial<Container['mechanicRepo']> = {}) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'C', role: 'cashier', isActive: true } as never,
    status: 'signedIn',
  });
  const mechanicRepo = {
    watchAll: (cb: (m: Mechanic[]) => void) => {
      cb([berto]);
      return () => {};
    },
    nameExists: vi.fn(async () => false),
    create: vi.fn(async (input: { name: string }) => ({ id: 'new', name: input.name, isActive: true } as Mechanic)),
    ...repoOver,
  } as Container['mechanicRepo'];
  const motorcycleModelRepo = {
    watchActive: (cb: (v: never[]) => void) => {
      cb([]);
      return () => {};
    },
  } as unknown as Container['motorcycleModelRepo'];
  const store = createCartStore();
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  render(
    <DiProvider override={{ mechanicRepo, motorcycleModelRepo }}>
      <QueryClientProvider client={qc}>
        <LaborSection store={store} />
      </QueryClientProvider>
    </DiProvider>,
  );
  return { store, mechanicRepo };
}

describe('LaborSection — inline mechanic add', () => {
  it('reuses an active mechanic on a case-insensitive name match', async () => {
    const { store, mechanicRepo } = harness();
    await userEvent.click(screen.getByRole('button', { name: '＋ Add' }));
    await userEvent.type(screen.getByPlaceholderText(/mechanic name/i), '  bErTo ');
    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    expect(mechanicRepo.create).not.toHaveBeenCalled();
    expect(store.getState().mechanicId).toBe('m1');
    expect(store.getState().mechanicName).toBe('Berto');
  });

  it('refuses an archived-name duplicate with the staff message', async () => {
    const { store, mechanicRepo } = harness({ nameExists: vi.fn(async () => true) });
    await userEvent.click(screen.getByRole('button', { name: '＋ Add' }));
    await userEvent.type(screen.getByPlaceholderText(/mechanic name/i), 'Islaw');
    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    await waitFor(() =>
      expect(screen.getByText(/archived — ask staff to reactivate/i)).toBeInTheDocument(),
    );
    expect(mechanicRepo.create).not.toHaveBeenCalled();
    expect(store.getState().mechanicId).toBeNull();
  });

  it('creates and assigns a brand-new mechanic', async () => {
    const { store, mechanicRepo } = harness();
    await userEvent.click(screen.getByRole('button', { name: '＋ Add' }));
    await userEvent.type(screen.getByPlaceholderText(/mechanic name/i), 'Islaw');
    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    await waitFor(() => expect(store.getState().mechanicId).toBe('new'));
    expect(mechanicRepo.create).toHaveBeenCalledWith({ name: 'Islaw' }, 'u1');
    expect(store.getState().mechanicName).toBe('Islaw');
  });

  it('needs at least 2 characters', async () => {
    harness();
    await userEvent.click(screen.getByRole('button', { name: '＋ Add' }));
    await userEvent.type(screen.getByPlaceholderText(/mechanic name/i), 'X');
    expect(screen.getByRole('button', { name: /^add$/i })).toBeDisabled();
  });
});
