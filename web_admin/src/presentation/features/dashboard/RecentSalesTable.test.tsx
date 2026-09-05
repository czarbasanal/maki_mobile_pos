import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { RecentSalesTable } from './RecentSalesTable';

describe('RecentSalesTable — View all', () => {
  it("opens the Sales report scoped to today, not the old day-sales screen", () => {
    render(
      <MemoryRouter>
        <RecentSalesTable sales={[]} loading={false} />
      </MemoryRouter>,
    );
    expect(screen.getByRole('link', { name: 'View all' }).getAttribute('href')).toBe('/reports/sales?range=today');
  });
});
