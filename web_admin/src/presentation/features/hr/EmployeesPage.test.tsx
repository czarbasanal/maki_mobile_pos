import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { EmployeesPage } from './EmployeesPage';
import { formatMoney } from '@/core/utils/money';
import type { Employee } from '@/domain/hr/types';

const employee = (o: Partial<Employee> = {}): Employee => ({
  id: 'e1',
  name: 'Juan',
  dailyRate: 640,
  isActive: true,
  createdAt: null,
  updatedAt: null,
  ...o,
});

function harness(opts?: {
  employees?: Employee[];
  create?: ReturnType<typeof vi.fn>;
  update?: ReturnType<typeof vi.fn>;
}) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const employeeRepo: Partial<Container['employeeRepo']> = {
    watchAll: vi.fn((cb: (employees: Employee[]) => void) => {
      cb(opts?.employees ?? []);
      return () => {};
    }),
    create:
      opts?.create ??
      vi.fn(async (input: { name: string; dailyRate: number }) => ({
        id: 'e-new',
        name: input.name,
        dailyRate: input.dailyRate,
        isActive: true,
        createdAt: null,
        updatedAt: null,
      })),
    update: opts?.update ?? vi.fn(async () => {}),
  };

  return render(
    <DiProvider override={{ employeeRepo: employeeRepo as Container['employeeRepo'] }}>
      <QueryClientProvider client={qc}>
        <EmployeesPage />
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('EmployeesPage', () => {
  it('renders rows from watchAll with names and formatted daily rates', () => {
    harness({
      employees: [
        employee({ id: 'e1', name: 'Juan', dailyRate: 640 }),
        employee({ id: 'e2', name: 'Maria', dailyRate: 750.5 }),
      ],
    });

    expect(screen.getByText('Juan')).toBeInTheDocument();
    expect(screen.getByText(formatMoney(640))).toBeInTheDocument();
    expect(screen.getByText('Maria')).toBeInTheDocument();
    expect(screen.getByText(formatMoney(750.5))).toBeInTheDocument();
  });

  it('submits {name, dailyRate} from the create dialog', async () => {
    const create = vi.fn(async (input: { name: string; dailyRate: number }) => ({
      id: 'e-new',
      name: input.name,
      dailyRate: input.dailyRate,
      isActive: true,
      createdAt: null,
      updatedAt: null,
    }));
    harness({ create });

    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    await userEvent.type(screen.getByLabelText(/name/i), 'Pedro');
    await userEvent.type(screen.getByLabelText(/daily rate/i), '500');
    await userEvent.click(screen.getByRole('button', { name: /^save$/i }));

    await waitFor(() => expect(create).toHaveBeenCalledWith({ name: 'Pedro', dailyRate: 500 }));
  });

  it('blocks save when name is empty', async () => {
    const create = vi.fn();
    harness({ create });

    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    await userEvent.type(screen.getByLabelText(/daily rate/i), '500');

    expect(screen.getByRole('button', { name: /^save$/i })).toBeDisabled();
    expect(create).not.toHaveBeenCalled();
  });

  it('blocks save when daily rate is non-positive', async () => {
    const create = vi.fn();
    harness({ create });

    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    await userEvent.type(screen.getByLabelText(/name/i), 'Pedro');
    await userEvent.type(screen.getByLabelText(/daily rate/i), '0');

    expect(screen.getByRole('button', { name: /^save$/i })).toBeDisabled();
    expect(create).not.toHaveBeenCalled();
  });

  it('blocks save when daily rate is non-numeric', async () => {
    const create = vi.fn();
    harness({ create });

    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    await userEvent.type(screen.getByLabelText(/name/i), 'Pedro');
    await userEvent.type(screen.getByLabelText(/daily rate/i), 'abc');

    expect(screen.getByRole('button', { name: /^save$/i })).toBeDisabled();
    expect(create).not.toHaveBeenCalled();
  });

  it('toggles active state via the deactivate action', async () => {
    const update = vi.fn(async () => {});
    harness({ employees: [employee({ id: 'e1', name: 'Juan', isActive: true })], update });

    await userEvent.click(screen.getByRole('button', { name: /deactivate/i }));

    await waitFor(() => expect(update).toHaveBeenCalledWith('e1', { isActive: false }));
  });
});
