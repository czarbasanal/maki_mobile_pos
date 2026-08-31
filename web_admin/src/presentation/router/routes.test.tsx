// Job Orders replaced Drafts (routes/list rename). Old /drafts bookmarks must
// keep working — redirected to their /job-orders equivalents, preserving any
// :id param — mirroring the existing /hr/* → /settings/hr/* redirect pattern.
import { describe, expect, it } from 'vitest';
import { act, render, waitFor } from '@testing-library/react';
import { RouterProvider } from 'react-router-dom';
import { router } from './routes';

describe('router — /drafts → /job-orders redirects', () => {
  it('redirects /drafts to /job-orders', async () => {
    render(<RouterProvider router={router} />);
    await act(async () => {
      await router.navigate('/drafts');
    });
    await waitFor(() => expect(router.state.location.pathname).toBe('/job-orders'));
  });

  it('redirects /drafts/:id to /job-orders/:id, preserving the id', async () => {
    render(<RouterProvider router={router} />);
    await act(async () => {
      await router.navigate('/drafts/abc123');
    });
    await waitFor(() => expect(router.state.location.pathname).toBe('/job-orders/abc123'));
  });
});

describe('router — HR moved back to top-level /hr/*', () => {
  it('redirects the bare /hr group link to Employees', async () => {
    render(<RouterProvider router={router} />);
    await act(async () => {
      await router.navigate('/hr');
    });
    await waitFor(() => expect(router.state.location.pathname).toBe('/hr/employees'));
  });

  it('redirects the interim /settings/hr/* bookmarks, preserving any :id', async () => {
    render(<RouterProvider router={router} />);
    await act(async () => {
      await router.navigate('/settings/hr/payslips/abc123');
    });
    await waitFor(() =>
      expect(router.state.location.pathname).toBe('/hr/payslips/abc123'),
    );
    await act(async () => {
      await router.navigate('/settings/hr/config');
    });
    await waitFor(() => expect(router.state.location.pathname).toBe('/hr/settings'));
  });
});

describe('router — product view is a drawer over the inventory list', () => {
  const paths = () => router.state.matches.map((m) => m.route.path);

  it('keeps the inventory list matched underneath /inventory/:id', async () => {
    // The drawer is a CHILD of the list route, so the list stays mounted
    // behind it — that is what preserves your place in the table.
    render(<RouterProvider router={router} />);
    await act(async () => {
      await router.navigate('/inventory/p9');
    });
    await waitFor(() => expect(paths()).toContain('/inventory'));
    expect(paths()).toContain(':id');
  });

  it('redirects the legacy /inventory/edit/:id bookmark into the drawer', async () => {
    render(<RouterProvider router={router} />);
    await act(async () => {
      await router.navigate('/inventory/edit/p9');
    });
    await waitFor(() =>
      expect(router.state.location.pathname).toBe('/inventory/p9/edit'),
    );
  });

  it('keeps the list matched underneath the edit drawer too', async () => {
    render(<RouterProvider router={router} />);
    await act(async () => {
      await router.navigate('/inventory/p9/edit');
    });
    await waitFor(() => expect(paths()).toContain('/inventory'));
    expect(paths()).toContain(':id/edit');
  });

  it('does not mistake /inventory/add for a product id', async () => {
    // ':id' would happily match the literal 'add'; static segments must win.
    render(<RouterProvider router={router} />);
    await act(async () => {
      await router.navigate('/inventory/add');
    });
    await waitFor(() => expect(paths()).toContain('/inventory/add'));
    expect(paths()).not.toContain(':id');
  });

  it('sends the retired /inventory/reorder to the buying list', async () => {
    render(<RouterProvider router={router} />);
    await act(async () => {
      await router.navigate('/inventory/reorder');
    });
    // Redirected, not treated as a product called "reorder".
    await waitFor(() => expect(paths()).toContain('/purchase-orders/new'));
    expect(paths()).not.toContain(':id');
  });
});
