import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { HrSettingsPage } from './HrSettingsPage';
import { DEFAULT_HR_SETTINGS, type HrSettings } from '@/domain/hr/types';

function harness(opts?: {
  settings?: HrSettings;
  save?: ReturnType<typeof vi.fn>;
}) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const hrSettingsRepo: Partial<Container['hrSettingsRepo']> = {
    get: vi.fn(async () => opts?.settings ?? { ...DEFAULT_HR_SETTINGS }),
    save: opts?.save ?? vi.fn(async () => {}),
  };

  return render(
    <DiProvider override={{ hrSettingsRepo: hrSettingsRepo as Container['hrSettingsRepo'] }}>
      <QueryClientProvider client={qc}>
        <HrSettingsPage />
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('HrSettingsPage', () => {
  it('loads and displays DEFAULT_HR_SETTINGS', async () => {
    harness();

    await waitFor(() =>
      expect(screen.getByLabelText(/week starts on/i)).toHaveValue(String(DEFAULT_HR_SETTINGS.weekStartDay)),
    );
    expect(screen.getByLabelText(/regular holiday/i)).toHaveValue(DEFAULT_HR_SETTINGS.regularHolidayPct);
    expect(screen.getByLabelText(/special holiday/i)).toHaveValue(DEFAULT_HR_SETTINGS.specialHolidayPct);
  });

  it('calls repo.save with the edited values', async () => {
    const save = vi.fn(async () => {});
    harness({ save });

    await waitFor(() => expect(screen.getByLabelText(/week starts on/i)).toHaveValue('1'));

    await userEvent.selectOptions(screen.getByLabelText(/week starts on/i), '2');

    const regularInput = screen.getByLabelText(/regular holiday/i);
    await userEvent.clear(regularInput);
    await userEvent.type(regularInput, '120');

    const specialInput = screen.getByLabelText(/special holiday/i);
    await userEvent.clear(specialInput);
    await userEvent.type(specialInput, '50');

    await userEvent.click(screen.getByRole('button', { name: /save changes/i }));

    await waitFor(() =>
      expect(save).toHaveBeenCalledWith({
        weekStartDay: 2,
        regularHolidayPct: 120,
        specialHolidayPct: 50,
      }),
    );
  });

  it('blocks save when a holiday percentage is negative', async () => {
    const save = vi.fn(async () => {});
    harness({ save });

    await waitFor(() => expect(screen.getByLabelText(/week starts on/i)).toHaveValue('1'));

    const regularInput = screen.getByLabelText(/regular holiday/i);
    await userEvent.clear(regularInput);
    await userEvent.type(regularInput, '-5');

    expect(screen.getByRole('button', { name: /save changes/i })).toBeDisabled();
    expect(save).not.toHaveBeenCalled();
  });
});
