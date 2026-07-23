import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { ForgotPasswordPage } from './ForgotPasswordPage';

function harness(
  authRepo: Partial<Container['authRepo']>,
  state?: { email?: string },
) {
  const qc = new QueryClient({ defaultOptions: { mutations: { retry: false } } });
  return render(
    <DiProvider override={{ authRepo: authRepo as Container['authRepo'] }}>
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={[{ pathname: '/forgot-password', state }]}>
          <Routes>
            <Route path="/forgot-password" element={<ForgotPasswordPage />} />
            <Route path="/login" element={<div>LOGIN PAGE</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
}

describe('ForgotPasswordPage', () => {
  it('prefills the email from router state', () => {
    harness({ sendPasswordResetEmail: vi.fn() }, { email: 'shop@maki.ph' });
    expect(screen.getByLabelText(/email/i)).toHaveValue('shop@maki.ph');
  });

  it('blocks an empty email without calling the repo', async () => {
    const send = vi.fn();
    harness({ sendPasswordResetEmail: send });
    await userEvent.click(screen.getByRole('button', { name: /send reset link/i }));
    expect(await screen.findByText('Email is required')).toBeInTheDocument();
    expect(send).not.toHaveBeenCalled();
  });

  it('sends and shows the success state', async () => {
    const send = vi.fn().mockResolvedValue(undefined);
    harness({ sendPasswordResetEmail: send }, { email: 'shop@maki.ph' });
    await userEvent.click(screen.getByRole('button', { name: /send reset link/i }));
    await waitFor(() => expect(send).toHaveBeenCalledWith('shop@maki.ph'));
    expect(await screen.findByText(/reset email sent to/i)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /back to login/i })).toBeInTheDocument();
  });

  it('surfaces a send failure in the error banner', async () => {
    const send = vi.fn().mockRejectedValue(new Error('No account found for that email'));
    harness({ sendPasswordResetEmail: send }, { email: 'shop@maki.ph' });
    await userEvent.click(screen.getByRole('button', { name: /send reset link/i }));
    expect(
      await screen.findByText('No account found for that email'),
    ).toBeInTheDocument();
    expect(screen.queryByText(/reset email sent to/i)).not.toBeInTheDocument();
  });
});
