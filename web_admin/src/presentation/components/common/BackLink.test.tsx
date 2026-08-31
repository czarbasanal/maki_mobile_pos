import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { BackLink } from './BackLink';

function harness(entries: string[]) {
  render(
    <MemoryRouter initialEntries={entries} initialIndex={entries.length - 1}>
      <Routes>
        <Route path="/origin" element={<div>origin page</div>} />
        <Route path="/fallback" element={<div>fallback page</div>} />
        <Route
          path="/detail"
          element={<BackLink fallback="/fallback" />}
        />
      </Routes>
    </MemoryRouter>,
  );
}

describe('BackLink', () => {
  it('returns to the page you came from', async () => {
    harness(['/origin', '/detail']);
    await userEvent.click(screen.getByRole('button', { name: '← Back' }));
    expect(await screen.findByText('origin page')).toBeInTheDocument();
  });

  it('uses the fallback when there is no history — a deep link or a refresh', async () => {
    harness(['/detail']);
    await userEvent.click(screen.getByRole('button', { name: '← Back' }));
    expect(await screen.findByText('fallback page')).toBeInTheDocument();
  });
});
