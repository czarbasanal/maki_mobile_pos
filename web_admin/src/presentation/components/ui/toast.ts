// Imperative toast singleton (spec §7 Toast). The Toaster component
// subscribes; anything in the app may fire.
export type ToastTone = 'success' | 'error' | 'info';

export interface ToastPayload {
  tone: ToastTone;
  message: string;
  detail?: string;
}

type Listener = (payload: ToastPayload) => void;

let listener: Listener | null = null;

function emit(tone: ToastTone, message: string, detail?: string): void {
  listener?.({ tone, message, detail });
}

export const toast = {
  success: (message: string, detail?: string) => emit('success', message, detail),
  error: (message: string, detail?: string) => emit('error', message, detail),
  info: (message: string, detail?: string) => emit('info', message, detail),
  /** @internal Toaster only. */
  _subscribe(next: Listener): () => void {
    listener = next;
    return () => {
      if (listener === next) listener = null;
    };
  },
};
