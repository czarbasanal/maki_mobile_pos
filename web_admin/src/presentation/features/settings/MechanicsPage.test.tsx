import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { RoutePaths } from '@/presentation/router/routePaths';
import type { Mechanic } from '@/domain/entities';
import { MechanicsPage } from './MechanicsPage';

function mechanic(o: Partial<Mechanic> = {}): Mechanic {
  return {
    id: 'm1',
    name: 'Mang Kanor',
    isActive: true,
    address: null,
    contactNumber: null,
    createdAt: new Date('2026-01-01'),
    updatedAt: null,
    createdBy: null,
    updatedBy: null,
    ...o,
  };
}

function harness(mechanics: Mechanic[]) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const mechanicRepo = {
    watchAll: vi.fn((cb: (m: Mechanic[]) => void) => {
      cb(mechanics);
      return () => {};
    }),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(async () => {}),
  } as unknown as Container['mechanicRepo'];
  render(
    <DiProvider override={{ mechanicRepo }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter>
          <MechanicsPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { mechanicRepo };
}

describe('MechanicsPage — back navigation', () => {
  it('renders a back link to Settings', () => {
    harness([]);

    const back = screen.getByRole('link', { name: /settings/i });
    expect(back).toHaveAttribute('href', RoutePaths.settings);
  });
});

describe('MechanicsPage — delete action (deactivate-first)', () => {
  it('shows no Delete affordance on an active row, but shows it on an inactive row', () => {
    harness([
      mechanic({ id: 'm1', name: 'Active Mang Kanor', isActive: true }),
      mechanic({ id: 'm2', name: 'Retired Mang Kanor', isActive: false }),
    ]);

    const activeRow = screen.getByText('Active Mang Kanor').closest('li') as HTMLElement;
    expect(within(activeRow).queryByRole('button', { name: /^delete$/i })).not.toBeInTheDocument();

    const inactiveRow = screen.getByText(/Retired Mang Kanor/).closest('li') as HTMLElement;
    expect(within(inactiveRow).getByRole('button', { name: /^delete$/i })).toBeInTheDocument();
  });

  it('confirming Delete on an inactive row calls the repo with its id', async () => {
    const { mechanicRepo } = harness([
      mechanic({ id: 'm2', name: 'Retired Mang Kanor', isActive: false }),
    ]);

    await userEvent.click(screen.getByRole('button', { name: /^delete$/i }));
    const dialog = screen.getByRole('dialog');
    expect(dialog).toHaveTextContent('Delete this entry?');
    expect(dialog).toHaveTextContent('Retired Mang Kanor');

    await userEvent.click(within(dialog).getByRole('button', { name: /^delete$/i }));

    await waitFor(() => expect(mechanicRepo.delete).toHaveBeenCalledWith('m2'));
  });

  it('Cancel does not delete', async () => {
    const { mechanicRepo } = harness([
      mechanic({ id: 'm2', name: 'Retired Mang Kanor', isActive: false }),
    ]);

    await userEvent.click(screen.getByRole('button', { name: /^delete$/i }));
    const dialog = screen.getByRole('dialog');
    await userEvent.click(within(dialog).getByRole('button', { name: /cancel/i }));

    expect(mechanicRepo.delete).not.toHaveBeenCalled();
  });
});
