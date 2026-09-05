import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { createCartStore } from '@/presentation/stores/cartStore';
import { MotorcycleModelPicker } from './MotorcycleModelPicker';
import type { MotorcycleModel } from '@/domain/entities';

const models: MotorcycleModel[] = [
  { id: 'm1', name: 'Click 125i', isActive: true },
  { id: 'm2', name: 'Nmax 155', isActive: true },
];

function harness(store = createCartStore(), repoOver: Partial<Container['motorcycleModelRepo']> = {}) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'C', role: 'cashier', isActive: true } as never,
    status: 'signedIn',
  });
  const motorcycleModelRepo = {
    watchActive: (cb: (v: MotorcycleModel[]) => void) => {
      cb(models);
      return () => {};
    },
    findByNormalizedKey: vi.fn(async () => null),
    // The real repo canonicalizes before writing — the fake honors that contract.
    create: vi.fn(async (name: string) => ({ id: 'new', name: name.trim().replace(/\s+/g, ' '), isActive: true })),
    setActive: vi.fn(async () => {}),
    ...repoOver,
  } as Container['motorcycleModelRepo'];
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  render(
    <DiProvider override={{ motorcycleModelRepo }}>
      <QueryClientProvider client={qc}>
        <MotorcycleModelPicker store={store} />
      </QueryClientProvider>
    </DiProvider>,
  );
  return { store, motorcycleModelRepo };
}

/** SelectFilter replaced the native select — open the trigger, pick a row. */
async function pickModel(optionName: RegExp | string) {
  await userEvent.click(screen.getByRole('button', { name: /^Motorcycle/ }));
  await userEvent.click(await screen.findByRole('option', { name: optionName }));
}

describe('MotorcycleModelPicker', () => {
  it('picking an existing model snapshots its name on the ticket', async () => {
    const { store } = harness();
    await pickModel('Nmax 155');
    expect(store.getState().motorcycleModel).toBe('Nmax 155');
  });

  it('None clears the model', async () => {
    const store = createCartStore();
    store.getState().setMotorcycleModel('Nmax 155');
    harness(store);
    await pickModel('None');
    expect(store.getState().motorcycleModel).toBeNull();
  });

  it('Add model resolves through pick-or-add and stores the canonical name', async () => {
    const { store, motorcycleModelRepo } = harness();
    await pickModel(/add model/i);
    await userEvent.type(screen.getByPlaceholderText(/model name/i), '  mio   i125 ');
    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    expect(motorcycleModelRepo.create).toHaveBeenCalledWith('  mio   i125 ', 'u1');
    // canonical name from create lands on the ticket
    expect(store.getState().motorcycleModel).toBe('mio i125');
  });

  it('reuses an existing row case-insensitively instead of creating', async () => {
    const existing = { id: 'm2', name: 'Nmax 155', isActive: true };
    const { store, motorcycleModelRepo } = harness(createCartStore(), {
      findByNormalizedKey: vi.fn(async () => existing),
    });
    await pickModel(/add model/i);
    await userEvent.type(screen.getByPlaceholderText(/model name/i), 'NMAX 155');
    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    expect(motorcycleModelRepo.create).not.toHaveBeenCalled();
    expect(store.getState().motorcycleModel).toBe('Nmax 155');
  });

  it('keeps a ticket model that is missing from the active list selectable', async () => {
    const store = createCartStore();
    store.getState().setMotorcycleModel('Old Archived Model');
    harness(store);
    await userEvent.click(screen.getByRole('button', { name: /^Motorcycle/ }));
    expect(await screen.findByRole('option', { name: /old archived model/i })).toBeInTheDocument();
  });
});
