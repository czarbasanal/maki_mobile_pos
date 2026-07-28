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
    const props = harness({ types: [ActivityType.login] });
    await userEvent.click(screen.getByRole('button', { name: /1 operation/ }));
    await userEvent.click(screen.getByLabelText('Sale'));

    // 'login' is declared before 'sale' in the enum, so order is preserved
    // regardless of click order.
    expect(props.onTypes).toHaveBeenCalledWith([ActivityType.login, ActivityType.sale]);
  });

  it('fires onSearch when Search is clicked', async () => {
    const props = harness();
    await userEvent.click(screen.getByRole('button', { name: 'Search' }));
    expect(props.onSearch).toHaveBeenCalledTimes(1);
  });

  it('disables Search when the range is invalid', () => {
    harness({ disabled: true });
    expect(screen.getByRole('button', { name: 'Search' })).toBeDisabled();
  });

  it('shows the stale hint when dirty', () => {
    harness({ dirty: true });
    expect(screen.getByText('Filters changed — tap Search.')).toBeInTheDocument();
  });
});
