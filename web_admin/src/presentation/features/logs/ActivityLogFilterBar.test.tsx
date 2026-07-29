import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ActivityLogFilterBar } from './ActivityLogFilterBar';
import { ActivityType } from '@/domain/entities';

function harness(overrides: Partial<Parameters<typeof ActivityLogFilterBar>[0]> = {}) {
  const props = {
    types: [] as ActivityType[],
    onTypes: vi.fn(),
    onRange: vi.fn(),
    startTime: '00:00',
    endTime: '23:59',
    onStartTime: vi.fn(),
    onEndTime: vi.fn(),
    dirty: false,
    disabled: false,
    onSearch: vi.fn(),
    ...overrides,
  };
  render(<ActivityLogFilterBar {...props} />);
  return props;
}

describe('ActivityLogFilterBar', () => {
  it('summarises an empty selection as all operations', () => {
    harness();
    expect(screen.getByRole('button', { name: /All operations/ })).toBeInTheDocument();
  });

  it('reports a ticked operation in canonical enum order', async () => {
    const props = harness({ types: [ActivityType.sale] });
    await userEvent.click(screen.getByRole('button', { name: /1 operation/ }));
    await userEvent.click(screen.getByLabelText('Login'));

    // 'login' is declared BEFORE 'sale' in the enum, but 'sale' was already
    // selected and 'login' is clicked second — so a click-order-append
    // implementation would produce [sale, login]. Only a canonical-order
    // (filter over ALL_ACTIVITY_TYPES) implementation produces this order.
    expect(props.onTypes).toHaveBeenCalledWith([ActivityType.login, ActivityType.sale]);
  });

  it('fires onSearch when Search is clicked', async () => {
    const props = harness();
    await userEvent.click(screen.getByRole('button', { name: 'Search' }));
    expect(props.onSearch).toHaveBeenCalledTimes(1);
  });

  it('disables Search when the range is invalid and explains why', () => {
    harness({ disabled: true });
    expect(screen.getByRole('button', { name: 'Search' })).toBeDisabled();
    expect(screen.getByText('Start must be before end.')).toBeInTheDocument();
  });

  it('shows no invalid-range note when the range is valid', () => {
    harness({ disabled: false });
    expect(screen.queryByText('Start must be before end.')).not.toBeInTheDocument();
  });

  it('shows the stale hint when dirty', () => {
    harness({ dirty: true });
    expect(screen.getByText('Filters changed — tap Search.')).toBeInTheDocument();
  });
});
