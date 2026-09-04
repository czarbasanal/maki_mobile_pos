import { describe, expect, it, vi } from 'vitest';
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
});
