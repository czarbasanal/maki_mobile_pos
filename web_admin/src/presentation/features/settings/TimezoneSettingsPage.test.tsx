import { beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { TimezoneSettingsPage } from './TimezoneSettingsPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities/User';
import {
  DEFAULT_SHOP_OFFSET_MINUTES,
  DEFAULT_SHOP_TIMEZONE_ID,
  type ShopTimezone,
} from '@/domain/time/shopTime';

const admin: User = {
  id: 'u1',
  email: 'admin@shop.test',
  displayName: 'Admin',
  role: UserRole.admin,
  isActive: true,
  phoneNumber: null,
  photoUrl: null,
  createdAt: new Date('2026-01-01'),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  lastLoginAt: null,
};

function harness(opts?: { current?: ShopTimezone; save?: ReturnType<typeof vi.fn> }) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  const save = opts?.save ?? vi.fn(async () => {});
  const shopTimezoneRepo: Partial<Container['shopTimezoneRepo']> = {
    get: vi.fn(async () => opts?.current ?? {
      timezoneId: DEFAULT_SHOP_TIMEZONE_ID,
      offsetMinutes: DEFAULT_SHOP_OFFSET_MINUTES,
    }),
    save,
    watch: () => () => {},
  };

  const utils = render(
    <DiProvider
      override={{ shopTimezoneRepo: shopTimezoneRepo as Container['shopTimezoneRepo'] }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter>
          <TimezoneSettingsPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return { ...utils, save };
}

describe('TimezoneSettingsPage', () => {
  beforeEach(() => {
    useAuthStore.setState({ user: admin });
  });

  it('shows the stored shop timezone as the selection', async () => {
    harness();
    await waitFor(() =>
      expect(screen.getByLabelText(/shop timezone/i)).toHaveValue('Asia/Manila'),
    );
  });

  it('lists the curated timezones', async () => {
    harness();
    await waitFor(() => expect(screen.getByLabelText(/shop timezone/i)).toBeInTheDocument());
    // The label carries the offset, so one option row shows both.
    expect(
      screen.getByRole('option', { name: 'Japan (Tokyo) (+09:00)' }),
    ).toBeInTheDocument();
  });

  it('disables Save until the selection changes', async () => {
    harness();
    await waitFor(() => expect(screen.getByLabelText(/shop timezone/i)).toBeInTheDocument());
    expect(screen.getByRole('button', { name: /save/i })).toBeDisabled();
  });

  it('saves both the id and the offset, stamped with the current user', async () => {
    const { save } = harness();
    await waitFor(() => expect(screen.getByLabelText(/shop timezone/i)).toBeInTheDocument());

    await userEvent.selectOptions(screen.getByLabelText(/shop timezone/i), 'Asia/Tokyo');
    await userEvent.click(screen.getByRole('button', { name: /save/i }));

    await waitFor(() =>
      expect(save).toHaveBeenCalledWith({ timezoneId: 'Asia/Tokyo', offsetMinutes: 540 }, 'u1'),
    );
  });

  it('surfaces a failed save', async () => {
    const save = vi.fn(async () => {
      throw new Error('permission denied');
    });
    harness({ save });
    await waitFor(() => expect(screen.getByLabelText(/shop timezone/i)).toBeInTheDocument());

    await userEvent.selectOptions(screen.getByLabelText(/shop timezone/i), 'Asia/Tokyo');
    await userEvent.click(screen.getByRole('button', { name: /save/i }));

    await waitFor(() => expect(screen.getByText(/permission denied/)).toBeInTheDocument());
  });

  it('warns that the change affects every device', async () => {
    harness();
    await waitFor(() => expect(screen.getByLabelText(/shop timezone/i)).toBeInTheDocument());
    expect(screen.getByText(/every device/i)).toBeInTheDocument();
  });

  it('is read-only for a non-admin', async () => {
    useAuthStore.setState({ user: { ...admin, id: 'u2', role: UserRole.cashier } });
    harness();
    await waitFor(() => expect(screen.getByLabelText(/shop timezone/i)).toBeDisabled());
    expect(screen.queryByRole('button', { name: /save/i })).not.toBeInTheDocument();
  });
});
