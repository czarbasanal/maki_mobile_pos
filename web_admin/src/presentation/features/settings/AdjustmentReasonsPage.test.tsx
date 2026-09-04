import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { AdjustmentReasonsPage } from './AdjustmentReasonsPage';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import type { AdjustmentReason } from '@/domain/entities';

const reason = (o: Partial<AdjustmentReason> = {}): AdjustmentReason => ({
  id: 'r1', name: 'Damaged', requiresNote: true,
  isActive: true, createdAt: new Date('2026-09-01'), updatedAt: null,
  createdBy: null, updatedBy: null, ...o,
});

function signIn(role: UserRole) {
  useAuthStore.setState({
    user: { id: 'u1', email: 'a@b.co', displayName: 'Tester', role, isActive: true } as never,
  });
}

function harness(
  reasons: AdjustmentReason[] = [reason()],
  repoOver: Partial<Container['adjustmentReasonRepo']> = {},
) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const adjustmentReasonRepo: Partial<Container['adjustmentReasonRepo']> = {
    watchAll: (cb: (reasons: AdjustmentReason[]) => void) => { cb(reasons); return () => {}; },
    create: vi.fn().mockResolvedValue(reason({ id: 'new1' })),
    update: vi.fn().mockResolvedValue(undefined),
    delete: vi.fn().mockResolvedValue(undefined),
    seedDefaults: vi.fn().mockResolvedValue(undefined),
    ...repoOver,
  };
  const activityLogRepo = { log: vi.fn().mockResolvedValue(undefined) } as unknown as Container['activityLogRepo'];
  render(
    <DiProvider override={{ adjustmentReasonRepo: adjustmentReasonRepo as Container['adjustmentReasonRepo'], activityLogRepo }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/settings/adjustment-reasons']}>
          <AdjustmentReasonsPage />
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return adjustmentReasonRepo;
}

describe('AdjustmentReasonsPage', () => {
  it('lists reasons with a "Note required" chip on flagged rows', () => {
    signIn(UserRole.admin);
    harness([reason(), reason({ id: 'r2', name: 'Delivery', requiresNote: false })]);
    expect(screen.getByText('Damaged')).toBeInTheDocument();
    expect(screen.getByText('Delivery')).toBeInTheDocument();
    expect(screen.getByText('Note required')).toBeInTheDocument();
  });

  it('creates a reason with the note-required checkbox unticked', async () => {
    signIn(UserRole.cashier); // editLists holders can add
    const repo = harness([]);
    await userEvent.click(screen.getByRole('button', { name: /add/i }));
    await userEvent.type(screen.getByLabelText('Name'), 'Delivery');
    await userEvent.click(screen.getByRole('button', { name: 'Save' }));
    expect(repo.create).toHaveBeenCalledWith(
      { name: 'Delivery', requiresNote: false },
      'u1',
    );
  });

  it('cashier sees no Deactivate/Delete and no note-required toggle on edit', async () => {
    signIn(UserRole.cashier);
    harness([reason(), reason({ id: 'r2', name: 'Old', isActive: false })]);
    expect(screen.queryByRole('button', { name: /deactivate/i })).toBeNull();
    expect(screen.queryByRole('button', { name: /delete/i })).toBeNull();
    await userEvent.click(screen.getAllByRole('button', { name: /edit/i })[0]);
    expect(screen.queryByLabelText('Note required')).toBeNull();
  });

  it('staff sees deactivate, delete, and the note-required toggle on edit', async () => {
    signIn(UserRole.staff);
    harness([reason(), reason({ id: 'r2', name: 'Old', isActive: false })]);
    expect(screen.getByRole('button', { name: /deactivate/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /delete/i })).toBeInTheDocument();
    await userEvent.click(screen.getAllByRole('button', { name: /edit/i })[0]);
    expect(screen.getByLabelText('Note required')).toBeInTheDocument();
  });

  it('empty list shows a Seed defaults button that calls seedDefaults', async () => {
    signIn(UserRole.cashier);
    const repo = harness([]);
    await userEvent.click(screen.getByRole('button', { name: /seed defaults/i }));
    expect(repo.seedDefaults).toHaveBeenCalledWith('u1');
  });
});
