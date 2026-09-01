import '@testing-library/jest-dom/vitest';
import { afterEach } from 'vitest';
import { clearSubscriptionCache } from '@/presentation/hooks/useFirestoreSubscription';

// The subscription snapshot cache is module-level state — wipe it between
// tests so one test's data can never satisfy another's loading state.
afterEach(() => clearSubscriptionCache());
