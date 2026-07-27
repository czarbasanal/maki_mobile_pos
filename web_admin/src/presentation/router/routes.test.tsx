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
