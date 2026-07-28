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

describe('Pager — rows per page', () => {
  it('offers 25/50/100/500/1000 when onPageSize is supplied', () => {
    render(<Pager total={300} page={1} onPage={vi.fn()} pageSize={25} onPageSize={vi.fn()} />);
    const select = screen.getByLabelText(/rows per page/i);
    expect([...select.querySelectorAll('option')].map((o) => o.textContent)).toEqual([
      '25', '50', '100', '500', '1000',
    ]);
  });

  it('reports the newly chosen size', async () => {
    const onPageSize = vi.fn();
    render(<Pager total={300} page={1} onPage={vi.fn()} pageSize={25} onPageSize={onPageSize} />);
    await userEvent.selectOptions(screen.getByLabelText(/rows per page/i), '100');
    expect(onPageSize).toHaveBeenCalledWith(100);
  });

  it('stays visible once every row fits, so the size can be changed back', () => {
    // The trap: pick 500 on a 300-row table and everything fits. If the pager
    // hid itself here the selector would vanish and 25 would be unreachable.
    render(<Pager total={300} page={1} onPage={vi.fn()} pageSize={500} onPageSize={vi.fn()} />);
    expect(screen.getByLabelText(/rows per page/i)).toBeInTheDocument();
    expect(screen.getByText('1–300 of 300')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Next' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Prev' })).toBeDisabled();
  });

  it('still renders nothing when even the smallest size would not paginate', () => {
    const { container } = render(
      <Pager total={20} page={1} onPage={vi.fn()} pageSize={500} onPageSize={vi.fn()} />,
    );
    expect(container).toBeEmptyDOMElement();
  });

  it('omits the selector entirely when the parent does not support resizing', () => {
    render(<Pager total={300} page={1} onPage={vi.fn()} pageSize={25} />);
    expect(screen.queryByLabelText(/rows per page/i)).not.toBeInTheDocument();
  });
});
