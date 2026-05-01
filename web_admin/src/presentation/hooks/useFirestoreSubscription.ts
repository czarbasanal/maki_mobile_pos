// Bridges a Firestore onSnapshot callback into React state. This is the
// foundational pattern every live-data screen will use — Riverpod's
// StreamProvider rewritten as a hook.
//
// Why not TanStack `useQuery`? Streams are push-based and live forever;
// useQuery's pull/refetch model fights against that. The Query cache is
// great for one-shot reads + mutations, which we keep using elsewhere.

import { useEffect, useRef, useState } from 'react';
import type { Unsubscribe } from '@/domain/repositories/AuthRepository';

export interface SubscriptionState<T> {
  data: T | null;
  error: Error | null;
  isLoading: boolean;
}

export type Subscriber<T> = (
  onData: (value: T) => void,
  onError: (err: Error) => void,
) => Unsubscribe;

export function useFirestoreSubscription<T>(
  subscribe: Subscriber<T>,
  deps: unknown[],
): SubscriptionState<T> {
  const [state, setState] = useState<SubscriptionState<T>>({
    data: null,
    error: null,
    isLoading: true,
  });

  // Keep a ref to the latest subscriber so the effect can re-key on `deps`
  // without retriggering when only the function identity changes.
  const subscribeRef = useRef(subscribe);
  subscribeRef.current = subscribe;

  useEffect(() => {
    setState((prev) => ({ ...prev, isLoading: true, error: null }));
    const unsub = subscribeRef.current(
      (value) => setState({ data: value, error: null, isLoading: false }),
      (err) => setState({ data: null, error: err, isLoading: false }),
    );
    return unsub;
    // deps are an explicit input — eslint can't know they're a re-key.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  return state;
}
