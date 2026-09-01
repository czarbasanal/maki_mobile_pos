import { afterEach, describe, expect, it, vi } from 'vitest';
import { act, renderHook } from '@testing-library/react';
import {
  clearSubscriptionCache,
  useFirestoreSubscription,
  type Subscriber,
} from './useFirestoreSubscription';

afterEach(() => clearSubscriptionCache());

/** A subscriber whose snapshot delivery we control by hand. */
function manualSubscriber<T>() {
  let handlers: { onData: (v: T) => void; onError: (e: Error) => void } | null = null;
  const unsubscribe = vi.fn();
  const subscribe: Subscriber<T> = (onData, onError) => {
    handlers = { onData, onError };
    return unsubscribe;
  };
  return {
    subscribe,
    unsubscribe,
    emit: (v: T) => act(() => handlers?.onData(v)),
    fail: (e: Error) => act(() => handlers?.onError(e)),
  };
}

describe('useFirestoreSubscription cache', () => {
  it('without a cacheKey, every mount starts loading (legacy behavior)', () => {
    const sub = manualSubscriber<string[]>();
    const { result, unmount } = renderHook(() => useFirestoreSubscription(sub.subscribe, []));
    expect(result.current.isLoading).toBe(true);
    sub.emit(['a']);
    expect(result.current.data).toEqual(['a']);
    unmount();

    const second = renderHook(() => useFirestoreSubscription(sub.subscribe, []));
    expect(second.result.current.isLoading).toBe(true);
    expect(second.result.current.data).toBeNull();
  });

  it('with a cacheKey, a remount paints the last snapshot instantly', () => {
    const sub = manualSubscriber<string[]>();
    const first = renderHook(() => useFirestoreSubscription(sub.subscribe, [], 'products'));
    sub.emit(['brake shoe']);
    first.unmount();

    const second = renderHook(() => useFirestoreSubscription(sub.subscribe, [], 'products'));
    expect(second.result.current.data).toEqual(['brake shoe']);
    expect(second.result.current.isLoading).toBe(false);
    // A fresh snapshot still updates the remounted hook.
    sub.emit(['brake shoe', 'bulb']);
    expect(second.result.current.data).toEqual(['brake shoe', 'bulb']);
  });

  it('keys are isolated from each other', () => {
    const products = manualSubscriber<string[]>();
    const sales = manualSubscriber<string[]>();
    const p = renderHook(() => useFirestoreSubscription(products.subscribe, [], 'products'));
    products.emit(['part']);
    p.unmount();

    const s = renderHook(() => useFirestoreSubscription(sales.subscribe, [], 'sales:today'));
    expect(s.result.current.data).toBeNull();
    expect(s.result.current.isLoading).toBe(true);
  });

  it('an error clears the cached snapshot and surfaces with data null', () => {
    const sub = manualSubscriber<string[]>();
    const first = renderHook(() => useFirestoreSubscription(sub.subscribe, [], 'products'));
    sub.emit(['part']);
    sub.fail(new Error('permission-denied'));
    expect(first.result.current.error?.message).toBe('permission-denied');
    expect(first.result.current.data).toBeNull();
    first.unmount();

    const second = renderHook(() => useFirestoreSubscription(sub.subscribe, [], 'products'));
    expect(second.result.current.data).toBeNull();
    expect(second.result.current.isLoading).toBe(true);
  });

  it('clearSubscriptionCache wipes every key (sign-out path)', () => {
    const sub = manualSubscriber<string[]>();
    const first = renderHook(() => useFirestoreSubscription(sub.subscribe, [], 'products'));
    sub.emit(['part']);
    first.unmount();

    clearSubscriptionCache();
    const second = renderHook(() => useFirestoreSubscription(sub.subscribe, [], 'products'));
    expect(second.result.current.data).toBeNull();
    expect(second.result.current.isLoading).toBe(true);
  });
});
