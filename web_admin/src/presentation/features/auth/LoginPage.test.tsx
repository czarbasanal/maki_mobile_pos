// Sign-in per design/maki-pos-signin-redesign: one generic error (never
// which field failed), presence-only validation, disabled button in flight,
// error cleared on any keystroke, and "Keep me signed in" flowing into the
// auth call as the persistence choice.
import { describe, expect, it, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { DiProvider, type Container } from '@/infrastructure/di/container';
import { LoginPage } from './LoginPage';
import { useAuthStore } from '@/presentation/stores/authStore';

function harness(signInFn = vi.fn()) {
  useAuthStore.setState({ status: 'signedOut', user: null } as never);
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const authRepo: Partial<Container['authRepo']> = {
    signInWithEmailAndPassword: signInFn,
  };
  const activityLogRepo: Partial<Container['activityLogRepo']> = {
    log: vi.fn().mockResolvedValue(undefined),
  };
  render(
    <DiProvider
      override={{
        authRepo: authRepo as Container['authRepo'],
        activityLogRepo: activityLogRepo as Container['activityLogRepo'],
      }}
    >
      <QueryClientProvider client={qc}>
        <MemoryRouter initialEntries={['/login']}>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/" element={<div>DASHBOARD</div>} />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </DiProvider>,
  );
  return signInFn;
}

describe('LoginPage (sign-in redesign)', () => {
  beforeEach(() => {
    useAuthStore.setState({ status: 'signedOut', user: null } as never);
  });

  it('empty submit shows the single presence message, never a per-field error', async () => {
    harness();
    await userEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(screen.getByRole('alert')).toHaveTextContent(
      'Enter your email and password to continue.',
    );
    expect(screen.queryByText(/email is required/i)).not.toBeInTheDocument();
  });

  it('a keystroke in either field clears the error', async () => {
    harness();
    await userEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(screen.getByRole('alert')).toBeInTheDocument();
    await userEvent.type(screen.getByLabelText('Email'), 'a');
    expect(screen.queryByRole('alert')).not.toBeInTheDocument();
  });

  it('passes the Keep-me-signed-in choice through to the auth call', async () => {
    const signInFn = harness(
      vi.fn().mockResolvedValue({ id: 'u1', role: 'admin', displayName: 'C' }),
    );
    await userEvent.type(screen.getByLabelText('Email'), 'a@b.co');
    await userEvent.type(screen.getByLabelText('Password'), 'secret');
    // Default ON → toggle it OFF.
    await userEvent.click(screen.getByRole('checkbox', { name: /keep me signed in/i }));
    await userEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    await waitFor(() =>
      expect(signInFn).toHaveBeenCalledWith('a@b.co', 'secret', false),
    );
  });

  it('shows the auth failure in the banner and re-enables the button', async () => {
    harness(vi.fn().mockRejectedValue(new Error("That email and password don't match. Try again.")));
    await userEvent.type(screen.getByLabelText('Email'), 'a@b.co');
    await userEvent.type(screen.getByLabelText('Password'), 'wrong');
    await userEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(
      await screen.findByText("That email and password don't match. Try again."),
    ).toHaveClass('text-neg');
    expect(screen.getByRole('button', { name: 'Sign in' })).toBeEnabled();
  });

  it('the password reveal toggles the input type', async () => {
    harness();
    const password = screen.getByLabelText('Password');
    expect(password).toHaveAttribute('type', 'password');
    await userEvent.click(screen.getByRole('button', { name: /show password/i }));
    expect(password).toHaveAttribute('type', 'text');
  });

});
