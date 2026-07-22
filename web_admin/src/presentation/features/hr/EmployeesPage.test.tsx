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
  weekStartDay: null,
  payslipDefaults: null,
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
      vi.fn(async (input: { name: string; dailyRate: number; weekStartDay: number | null }) => ({
        id: 'e-new',
        name: input.name,
        dailyRate: input.dailyRate,
        isActive: true,
        weekStartDay: input.weekStartDay,
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

  it('shows the week-start override on the row when set, and nothing when null', () => {
    harness({
      employees: [
        employee({ id: 'e1', name: 'Juan', weekStartDay: null }),
        employee({ id: 'e2', name: 'Maria', weekStartDay: 3 }),
      ],
    });

    expect(screen.getByText(/wednesday/i)).toBeInTheDocument();
    // Juan's row has no weekday override text at all.
    const juanRow = screen.getByText('Juan').closest('li');
    expect(juanRow).not.toHaveTextContent(/monday|tuesday|wednesday|thursday|friday|saturday|sunday/i);
  });

  it('submits weekStartDay: null when Default is left selected', async () => {
    const create = vi.fn(async (input: { name: string; dailyRate: number; weekStartDay: number | null }) => ({
      id: 'e-new',
      name: input.name,
      dailyRate: input.dailyRate,
      isActive: true,
      weekStartDay: input.weekStartDay,
      createdAt: null,
      updatedAt: null,
    }));
    harness({ create });

    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    await userEvent.type(screen.getByLabelText(/name/i), 'Pedro');
    await userEvent.type(screen.getByLabelText(/daily rate/i), '500');
    await userEvent.click(screen.getByRole('button', { name: /^save$/i }));

    await waitFor(() =>
      expect(create).toHaveBeenCalledWith({ name: 'Pedro', dailyRate: 500, weekStartDay: null }),
    );
  });

  it('submits weekStartDay: 3 when an override is selected', async () => {
    const create = vi.fn(async (input: { name: string; dailyRate: number; weekStartDay: number | null }) => ({
      id: 'e-new',
      name: input.name,
      dailyRate: input.dailyRate,
      isActive: true,
      weekStartDay: input.weekStartDay,
      createdAt: null,
      updatedAt: null,
    }));
    harness({ create });

    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    await userEvent.type(screen.getByLabelText(/name/i), 'Pedro');
    await userEvent.type(screen.getByLabelText(/daily rate/i), '500');
    await userEvent.selectOptions(screen.getByLabelText(/week starts on/i), '3');
    await userEvent.click(screen.getByRole('button', { name: /^save$/i }));

    await waitFor(() =>
      expect(create).toHaveBeenCalledWith({ name: 'Pedro', dailyRate: 500, weekStartDay: 3 }),
    );
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

  it('surfaces the create error in the dialog and keeps the dialog open with data intact when repo.create rejects', async () => {
    const create = vi.fn(async () => {
      throw new Error('Failed to create employee');
    });
    harness({ create });

    await userEvent.click(screen.getByRole('button', { name: /^add$/i }));
    await userEvent.type(screen.getByLabelText(/name/i), 'Pedro');
    await userEvent.type(screen.getByLabelText(/daily rate/i), '500');
    await userEvent.click(screen.getByRole('button', { name: /^save$/i }));

    expect(await screen.findByText('Failed to create employee')).toBeInTheDocument();
    // Dialog stayed open with the entered data intact.
    expect(screen.getByLabelText(/name/i)).toHaveValue('Pedro');
    expect(screen.getByLabelText(/daily rate/i)).toHaveValue(500);
  });

  it('surfaces the toggle (update) error near the list when repo.update rejects', async () => {
    const update = vi.fn(async () => {
      throw new Error('Failed to update employee');
    });
    harness({ employees: [employee({ id: 'e1', name: 'Juan', isActive: true })], update });

    await userEvent.click(screen.getByRole('button', { name: /deactivate/i }));

    expect(await screen.findByText('Failed to update employee')).toBeInTheDocument();
  });

  it('shows the error view when watchAll invokes its error callback (e.g. permission-denied)', () => {
    const employeeRepo: Partial<Container['employeeRepo']> = {
      watchAll: vi.fn(
        (_cb: (employees: Employee[]) => void, _opts?: unknown, onError?: (e: Error) => void) => {
          onError?.(new Error('Missing or insufficient permissions.'));
          return () => {};
        },
      ),
    };
    const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });

    render(
      <DiProvider override={{ employeeRepo: employeeRepo as Container['employeeRepo'] }}>
        <QueryClientProvider client={qc}>
          <EmployeesPage />
        </QueryClientProvider>
      </DiProvider>,
    );

    expect(screen.getByText(/could not load employees/i)).toBeInTheDocument();
    expect(screen.getByText('Missing or insufficient permissions.')).toBeInTheDocument();
  });
});
