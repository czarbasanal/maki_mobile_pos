import { describe, expect, it, vi } from 'vitest';
import { useState } from 'react';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DataTable, type Column } from './DataTable';

interface Row { id: string; name: string; total: number }
const columns: Array<Column<Row>> = [
  { key: 'name', header: 'Name', render: (r) => r.name },
  { key: 'total', header: 'Total', align: 'right', mono: true, render: (r) => `₱${r.total}` },
];
const rows: Row[] = [
  { id: 'a', name: 'Brake shoe', total: 450 },
  { id: 'b', name: 'Bulb', total: 60 },
];

describe('DataTable', () => {
  it('renders headers and cells; numeric column is right-aligned mono', () => {
    render(<DataTable columns={columns} rows={rows} rowKey={(r) => r.id} />);
    expect(screen.getByText('Name')).toBeInTheDocument();
    const cell = screen.getByText('₱450');
    expect(cell.className).toContain('font-mono');
    expect(cell.className).toContain('text-right');
  });

  it('fires onRowClick with the row', async () => {
    const onRowClick = vi.fn();
    render(<DataTable columns={columns} rows={rows} rowKey={(r) => r.id} onRowClick={onRowClick} />);
    await userEvent.click(screen.getByText('Bulb'));
    expect(onRowClick).toHaveBeenCalledWith(rows[1]);
  });

  it('renders the empty state when there are no rows', () => {
    render(<DataTable columns={columns} rows={[]} rowKey={(r) => r.id} />);
    expect(screen.getByText('Nothing here yet')).toBeInTheDocument();
  });

  it('renders skeleton rows while loading, not the empty state', () => {
    const { container } = render(<DataTable columns={columns} rows={[]} rowKey={(r) => r.id} loading />);
    expect(screen.queryByText('Nothing here yet')).not.toBeInTheDocument();
    expect(container.querySelectorAll('tbody tr').length).toBe(8);
  });

  it('fires onRowClick on keyboard Enter', async () => {
    const onRowClick = vi.fn();
    render(<DataTable columns={columns} rows={rows} rowKey={(r) => r.id} onRowClick={onRowClick} />);
    const row = screen.getByText('Brake shoe').closest('tr') as HTMLElement;
    row.focus();
    await userEvent.keyboard('{Enter}');
    expect(onRowClick).toHaveBeenCalledWith(rows[0]);
  });

  it('fires onRowClick on keyboard Space', async () => {
    const onRowClick = vi.fn();
    render(<DataTable columns={columns} rows={rows} rowKey={(r) => r.id} onRowClick={onRowClick} />);
    const row = screen.getByText('Bulb').closest('tr') as HTMLElement;
    row.focus();
    await userEvent.keyboard(' ');
    expect(onRowClick).toHaveBeenCalledWith(rows[1]);
  });

  it('does not add tabIndex to rows when onRowClick is absent', () => {
    const { container } = render(<DataTable columns={columns} rows={rows} rowKey={(r) => r.id} />);
    const rows_in_tbody = container.querySelectorAll('tbody tr');
    rows_in_tbody.forEach((row) => {
      expect(row).not.toHaveAttribute('tabIndex');
    });
  });

  it('adds tabIndex={0} to rows when onRowClick is present', () => {
    const onRowClick = vi.fn();
    const { container } = render(<DataTable columns={columns} rows={rows} rowKey={(r) => r.id} onRowClick={onRowClick} />);
    const rows_in_tbody = container.querySelectorAll('tbody tr');
    rows_in_tbody.forEach((row) => {
      expect(row).toHaveAttribute('tabIndex', '0');
    });
  });

  it('renders an optional foot row in a <tfoot> when there are rows (Expenses guide §3 "Total shown")', () => {
    const { container } = render(
      <DataTable
        columns={columns}
        rows={rows}
        rowKey={(r) => r.id}
        foot={<tr><td colSpan={2}>Total shown</td></tr>}
      />,
    );
    expect(screen.getByText('Total shown')).toBeInTheDocument();
    expect(container.querySelector('tfoot')).not.toBeNull();
  });

  it('hides the foot row when there are no rows — the empty state renders instead', () => {
    render(
      <DataTable
        columns={columns}
        rows={[]}
        rowKey={(r) => r.id}
        foot={<tr><td colSpan={2}>Total shown</td></tr>}
      />,
    );
    expect(screen.queryByText('Total shown')).not.toBeInTheDocument();
  });

  it('hides the foot row while loading, even when a previous page of rows is still passed in — a stale total must not sit under skeleton rows', () => {
    const { container } = render(
      <DataTable
        columns={columns}
        rows={rows}
        rowKey={(r) => r.id}
        loading
        foot={<tr><td colSpan={2}>Total shown</td></tr>}
      />,
    );
    expect(screen.queryByText('Total shown')).not.toBeInTheDocument();
    expect(container.querySelector('tfoot')).toBeNull();
  });
});

describe('DataTable — expandable rows', () => {
  type Row = { id: string; name: string };
  const columns: Array<Column<Row>> = [{ key: 'name', header: 'Name', render: (r) => r.name }];
  const rows: Row[] = [{ id: 'a', name: 'Alpha' }, { id: 'b', name: 'Beta' }];

  function Host({ onRowClick }: { onRowClick?: (r: Row) => void }) {
    const [open, setOpen] = useState<Set<string>>(new Set());
    return (
      <DataTable
        columns={columns}
        rows={rows}
        rowKey={(r) => r.id}
        onRowClick={onRowClick}
        expansion={{
          isExpanded: (r) => open.has(r.id),
          onToggle: (r) =>
            setOpen((s) => {
              const n = new Set(s);
              if (n.has(r.id)) n.delete(r.id);
              else n.add(r.id);
              return n;
            }),
          render: (r) => <div>Lines of {r.name}</div>,
          label: (r) => `Show lines for ${r.name}`,
        }}
      />
    );
  }

  it('the chevron toggles a full-width band under the row and flips aria-expanded', async () => {
    render(<Host />);
    const toggle = screen.getByRole('button', { name: 'Show lines for Alpha' });
    expect(toggle).toHaveAttribute('aria-expanded', 'false');
    expect(screen.queryByText('Lines of Alpha')).not.toBeInTheDocument();
    await userEvent.click(toggle);
    expect(toggle).toHaveAttribute('aria-expanded', 'true');
    const band = screen.getByText('Lines of Alpha').closest('tr') as HTMLElement;
    expect(band).toHaveAttribute('data-expansion');
    expect((band.querySelector('td') as HTMLTableCellElement).colSpan).toBe(2);
    await userEvent.click(toggle);
    expect(screen.queryByText('Lines of Alpha')).not.toBeInTheDocument();
  });

  it('the chevron never fires the row click', async () => {
    const onRowClick = vi.fn();
    render(<Host onRowClick={onRowClick} />);
    await userEvent.click(screen.getByRole('button', { name: 'Show lines for Beta' }));
    expect(onRowClick).not.toHaveBeenCalled();
    expect(screen.getByText('Lines of Beta')).toBeInTheDocument();
    await userEvent.click(screen.getByText('Beta'));
    expect(onRowClick).toHaveBeenCalledWith(rows[1]);
  });
});
