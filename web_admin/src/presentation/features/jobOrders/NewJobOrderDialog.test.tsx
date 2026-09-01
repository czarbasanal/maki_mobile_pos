import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { NewJobOrderDialog } from './NewJobOrderDialog';
import { Toaster } from '@/presentation/components/ui/Toaster';
import type { Mechanic, MotorcycleModel } from '@/domain/entities';

function harness(onClose = vi.fn()) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'C', role: 'cashier', isActive: true } as never,
    status: 'signedIn',
  });
  const create = vi.fn().mockResolvedValue({ id: 'jo9', name: 'JO-090126-004' });
  const jobOrderRepo = { create } as unknown as Container['jobOrderRepo'];
  const activityLogRepo = { log: vi.fn().mockResolvedValue(undefined) } as unknown as Container['activityLogRepo'];
  const motorcycleModelRepo = {
    watchActive: (cb: (v: MotorcycleModel[]) => void) => {
      cb([{ id: 'm1', name: 'Nmax 155', isActive: true }]);
      return () => {};
    },
  } as unknown as Container['motorcycleModelRepo'];
  const mechanicRepo = {
    watchAll: (cb: (v: Mechanic[]) => void) => {
      cb([{ id: 'mek1', name: 'Berto', isActive: true } as Mechanic]);
      return () => {};
    },
  } as unknown as Container['mechanicRepo'];
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  render(
    <DiProvider override={{ jobOrderRepo, activityLogRepo, motorcycleModelRepo, mechanicRepo }}>
      <QueryClientProvider client={qc}>
        <NewJobOrderDialog open jobOrderNumber="JO-090126-004" onClose={onClose} />
        <Toaster />
      </QueryClientProvider>
    </DiProvider>,
  );
  return { create, onClose };
}

describe('NewJobOrderDialog', () => {
  it('creates an empty-items JO with the picked model and mechanic', async () => {
    const { create, onClose } = harness();
    expect(screen.getByText('JO-090126-004')).toBeInTheDocument();
    await userEvent.selectOptions(screen.getByLabelText(/motorcycle model/i), 'Nmax 155');
    await userEvent.selectOptions(screen.getByLabelText(/mechanic/i), 'mek1');
    await userEvent.click(screen.getByRole('button', { name: /^create$/i }));
    await waitFor(() => expect(create).toHaveBeenCalled());
    const input = create.mock.calls[0][0];
    expect(input).toMatchObject({
      name: 'JO-090126-004',
      items: [],
      motorcycleModel: 'Nmax 155',
      mechanicId: 'mek1',
      mechanicName: 'Berto',
    });
    expect(onClose).toHaveBeenCalled();
  });

  it('model and mechanic are optional', async () => {
    const { create } = harness();
    await userEvent.click(screen.getByRole('button', { name: /^create$/i }));
    await waitFor(() => expect(create).toHaveBeenCalled());
    expect(create.mock.calls[0][0]).toMatchObject({
      motorcycleModel: null,
      mechanicId: null,
    });
  });
});
