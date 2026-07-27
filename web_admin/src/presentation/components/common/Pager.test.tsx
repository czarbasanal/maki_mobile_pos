import { useState } from 'react';
import { describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { Pager } from './Pager';

const ITEMS = Array.from({ length: 30 }, (_, i) => `item-${i + 1}`);

function Harness({ items, pageSize = 25 }: { items: string[]; pageSize?: number }) {
  const [page, setPage] = useState(1);
  const slice = items.slice((page - 1) * pageSize, page * pageSize);
  return (
    <div>
      <ul>
        {slice.map((it) => (
          <li key={it}>{it}</li>
        ))}
      </ul>
      <Pager total={items.length} page={page} onPage={setPage} pageSize={pageSize} />
    </div>
  );
}

describe('Pager', () => {
  it('renders nothing when total is at or under pageSize', () => {
    const { container } = render(<Pager total={25} page={1} onPage={vi.fn()} pageSize={25} />);
    expect(container).toBeEmptyDOMElement();
  });

  it('renders nothing when total is under pageSize', () => {
    const { container } = render(<Pager total={10} page={1} onPage={vi.fn()} pageSize={25} />);
    expect(container).toBeEmptyDOMElement();
  });

  it('shows the range summary and disables Prev on page 1', () => {
    render(<Pager total={30} page={1} onPage={vi.fn()} pageSize={25} />);
    expect(screen.getByText('1–25 of 30')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Prev' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Next' })).toBeEnabled();
  });

  it('disables Next on the last page and shows the trailing partial range', () => {
    render(<Pager total={30} page={2} onPage={vi.fn()} pageSize={25} />);
    expect(screen.getByText('26–30 of 30')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Next' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Prev' })).toBeEnabled();
  });

  it('fires onPage with the next/prev page number', async () => {
    const onPage = vi.fn();
    render(<Pager total={30} page={1} onPage={onPage} pageSize={25} />);
    await userEvent.click(screen.getByRole('button', { name: 'Next' }));
    expect(onPage).toHaveBeenCalledWith(2);
  });

  it('slices items correctly via a parent harness: page 1 shows 25 rows, page 2 shows 5', async () => {
    render(<Harness items={ITEMS} />);
    expect(screen.getAllByRole('listitem')).toHaveLength(25);
    expect(screen.getByText('item-1')).toBeInTheDocument();
    expect(screen.queryByText('item-26')).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole('button', { name: 'Next' }));

    expect(screen.getAllByRole('listitem')).toHaveLength(5);
    expect(screen.getByText('item-26')).toBeInTheDocument();
    expect(screen.getByText('item-30')).toBeInTheDocument();
  });
});
