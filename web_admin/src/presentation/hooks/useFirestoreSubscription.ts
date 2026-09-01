// Bridges a Firestore onSnapshot callback into React state. This is the
// foundational pattern every live-data screen will use — Riverpod's
// StreamProvider rewritten as a hook.
//
// Why not TanStack `useQuery`? Streams are push-based and live forever;
// useQuery's pull/refetch model fights against that. The Query cache is
// great for one-shot reads + mutations, which we keep using elsewhere.
//
// Caching: pass a `cacheKey` and the hook remembers the last snapshot for
// the browser session, so a revisited screen paints instantly while its
// subscription re-attaches and refreshes silently (stale-while-revalidate).
// Firestore's own persistent cache makes the re-attach cheap; this layer
// removes the loading flash. The cache is wiped on sign-out (authStore)
// so a user switch can never paint the previous user's data.

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

const lastSnapshot = new Map<string, unknown>();

/** Wipe every remembered snapshot — called on sign-out. */
export function clearSubscriptionCache(): void {
  lastSnapshot.clear();
}

function cachedValue<T>(cacheKey: string | undefined): T | null {
  if (cacheKey === undefined || !lastSnapshot.has(cacheKey)) return null;
  return lastSnapshot.get(cacheKey) as T;
}

export function useFirestoreSubscription<T>(
  subscribe: Subscriber<T>,
  deps: unknown[],
  cacheKey?: string,
): SubscriptionState<T> {
  const [state, setState] = useState<SubscriptionState<T>>(() => {
    const cached = cachedValue<T>(cacheKey);
    return { data: cached, error: null, isLoading: cached === null };
  });

  // Keep a ref to the latest subscriber so the effect can re-key on `deps`
  // without retriggering when only the function identity changes.
  const subscribeRef = useRef(subscribe);
  subscribeRef.current = subscribe;

  useEffect(() => {
    const cached = cachedValue<T>(cacheKey);
    setState({ data: cached, error: null, isLoading: cached === null });
    const unsub = subscribeRef.current(
      (value) => {
        if (cacheKey !== undefined) lastSnapshot.set(cacheKey, value);
        setState({ data: value, error: null, isLoading: false });
      },
      (err) => {
        // A failed subscription may mean the cached value is no longer
        // readable (permissions) — drop it rather than replaying it.
        if (cacheKey !== undefined) lastSnapshot.delete(cacheKey);
        setState({ data: null, error: err, isLoading: false });
      },
    );
    return unsub;
    // deps are an explicit input — eslint can't know they're a re-key.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, cacheKey]);

  return state;
}
